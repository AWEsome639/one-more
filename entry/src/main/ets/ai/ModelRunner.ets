/**
 * ModelRunner —— 端侧推理统一封装（2026-10-23，路线 D）
 *
 * 目的：让「模型」这件事在 One More 里只有一个出口。
 *   路线 B（数独难度）和路线 C（策略网络）将来都接这里，不许各写一份。
 *
 * ★★★ 铁律（写在这里，改代码前先读一遍）：
 *   ① **任何失败都必须降级**，不许让游戏打不开、不许弹窗、不许抛给界面
 *   ② 三条失败路径都得有明确出口：
 *        · 模型文件不存在        → reason='no-model'
 *        · 加载失败（格式/版本） → reason='load-failed'
 *        · 设备不支持 syscap     → reason='no-syscap'
 *   ③ 推理超时/异常 → 返回 null，调用方回落到规则实现
 *   ④ 只做推理，**绝不在端侧训练**
 *
 * 关于 rawfile：
 *   MindSporeLite 的 loadModelFromFile 要的是**真实文件路径**，
 *   而 resources/rawfile 里的东西不是文件路径 ⇒ 必须先用 resourceManager
 *   读成 buffer，写到 filesDir，再从那个路径 load。
 *   （这一步不做的话，loadModelFromFile 一定失败，而且报错很含糊）
 */

import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 一次加载/推理的统计（给设置页诊断与断言用） */
export interface RunnerStat {
  /** 模型是否可用 */
  ready: boolean;
  /** 不可用的原因（ready=true 时是 'ok'） */
  reason: string;
  /** 加载耗时 ms */
  loadMs: number;
  /** 最近一次推理耗时 ms */
  inferMs: number;
  /** 推理次数 */
  calls: number;
}

const TAG: string = 'ModelRunner';

export class ModelRunner {
  private model: mindSporeLite.Model | null = null;
  private stat: RunnerStat = { ready: false, reason: 'idle', loadMs: 0, inferMs: 0, calls: 0 };
  private inShape: number[] = [];
  private outLen: number = 0;

  /** 当前是否可用 */
  isReady(): boolean {
    return this.stat.ready && this.model !== null;
  }

  lastStat(): RunnerStat {
    return this.stat;
  }

  /**
   * 从 rawfile 加载模型。
   * 全都包在 try/catch 里 —— 失败只改 stat，不抛。
   *
   * @param ctx      UIAbilityContext
   * @param rawName  resources/rawfile/models/ 下的文件名，例如 'sudoku.ms'
   * @param inDim    输入维度（一维长度），用于校验
   */
  async loadFromRawfile(ctx: common.UIAbilityContext, rawName: string, inDim: number,
                        outLen: number): Promise<boolean> {
    const t0: number = Date.now();
    this.inShape = [1, inDim];
    this.outLen = outLen;
    this.stat = { ready: false, reason: 'loading', loadMs: 0, inferMs: 0, calls: 0 };

    try {
      // ① syscap 检查：设备不支持就没有必要往下走
      //   （用 canIUse 判断，而不是 try 一把 —— 报错更清楚，也不会触发底层异常）
      if (!canIUse('SystemCapability.AI.MindSporeLite')) {
        this.stat.reason = 'no-syscap';
        this.stat.loadMs = Date.now() - t0;
        hilog.warn(0x0000, TAG, 'MindSporeLite syscap 不支持 ⇒ 降级');
        return false;
      }

      // ② 把 rawfile 读成 buffer（读取失败 = 模型不存在）
      let buf: Uint8Array;
      try {
        const raw: Uint8Array = ctx.resourceManager.getRawFileContentSync('models/' + rawName);
        buf = raw;
      } catch (e) {
        this.stat.reason = 'no-model';
        this.stat.loadMs = Date.now() - t0;
        hilog.warn(0x0000, TAG, '模型文件不存在: %{public}s ⇒ 降级', rawName);
        return false;
      }
      if (buf === undefined || buf.length === 0) {
        this.stat.reason = 'no-model';
        this.stat.loadMs = Date.now() - t0;
        return false;
      }

      // ③ 落到 filesDir（loadModelFromFile 要真实路径）
      const dst: string = ctx.filesDir + '/' + rawName;
      try {
        const f: fileIo.File = fileIo.openSync(dst,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(f.fd, buf.buffer as ArrayBuffer);
        } finally {
          fileIo.closeSync(f);
        }
      } catch (e) {
        this.stat.reason = 'write-failed';
        this.stat.loadMs = Date.now() - t0;
        hilog.error(0x0000, TAG, '模型落地失败 ⇒ 降级');
        return false;
      }

      // ④ 加载（用 CPU 2 线程：模型必然很小，线程多了反而有调度开销）
      // threadNum 在 cpu 子对象里，不是顶层（读 .d.ts 才知道，写错编译直接报类型不符）
      const cpuDev: mindSporeLite.CpuDevice = { threadNum: 2 };
      const c: mindSporeLite.Context = { target: ['cpu'], cpu: cpuDev };
      const m: mindSporeLite.Model = await mindSporeLite.loadModelFromFile(dst, c);
      if (m === null || m === undefined) {
        this.stat.reason = 'load-failed';
        this.stat.loadMs = Date.now() - t0;
        return false;
      }
      // ⑤ 校验输入维度（形状对不上就当作加载失败，别等到推理时崩）
      const inputs: mindSporeLite.MSTensor[] = m.getInputs();
      if (inputs.length === 0) {
        this.stat.reason = 'load-failed';
        this.stat.loadMs = Date.now() - t0;
        return false;
      }
      const shape: number[] = inputs[0].shape;
      let total: number = 1;
      for (let i = 0; i < shape.length; i++) {
        total *= shape[i];
      }
      if (total !== inDim) {
        hilog.warn(0x0000, TAG, '输入维度不符：模型要 %{public}d，配置写 %{public}d',
          total, inDim);
        this.stat.reason = 'shape-mismatch';
        this.stat.loadMs = Date.now() - t0;
        return false;
      }

      this.model = m;
      this.stat.ready = true;
      this.stat.reason = 'ok';
      this.stat.loadMs = Date.now() - t0;
      hilog.info(0x0000, TAG, '模型就绪 %{public}s，%{public}d ms', rawName, this.stat.loadMs);
      return true;
    } catch (e) {
      // 任何没预料到的异常都归到这里 —— 界面上永远看不到崩溃
      this.stat.ready = false;
      this.stat.reason = 'load-failed';
      this.stat.loadMs = Date.now() - t0;
      hilog.error(0x0000, TAG, '加载异常 ⇒ 降级: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  /**
   * 推理。不可用或出错都返回 null —— 调用方必须能接受 null。
   * @param input 一维输入，长度必须等于加载时声明的 inDim
   */
  async infer(input: number[]): Promise<number[] | null> {
    const m: mindSporeLite.Model | null = this.model;
    if (m === null || !this.stat.ready) {
      return null;                      // 没有模型不算错，就是回落
    }
    const t0: number = Date.now();
    try {
      const inputs: mindSporeLite.MSTensor[] = m.getInputs();
      if (inputs.length === 0) {
        return null;
      }
      const t: mindSporeLite.MSTensor = inputs[0];
      const f32: Float32Array = new Float32Array(input.length);
      for (let i = 0; i < input.length; i++) {
        f32[i] = input[i];
      }
      t.setData(f32.buffer as ArrayBuffer);
      const outs: mindSporeLite.MSTensor[] = await m.predict(inputs);
      if (outs === null || outs.length === 0) {
        return null;
      }
      const buf: ArrayBuffer = outs[0].getData();
      const out: Float32Array = new Float32Array(buf);
      this.stat.inferMs = Date.now() - t0;
      this.stat.calls++;
      const res: number[] = [];
      const n: number = this.outLen > 0 && this.outLen < out.length ? this.outLen : out.length;
      for (let i = 0; i < n; i++) {
        res.push(out[i]);
      }
      return res;
    } catch (e) {
      hilog.error(0x0000, TAG, '推理异常 ⇒ 返回 null: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  /** 释放（页面销毁/切游戏时调）。同样不抛。 */
  release(): void {
    try {
      this.model = null;
      this.stat = { ready: false, reason: 'released', loadMs: 0, inferMs: 0, calls: 0 };
    } catch (e) {
    }
  }
}
