/**
 * LocalLLM —— 端侧「系统本地对话模型」封装（2026-11-08，第八个想法的 LLM 落地）
 *
 * 目的：奥森说的「软件内内置大语言模型」——**不打包任何模型**，
 *   直接调系统自带的本地对话模型（Data Augmentation Kit → localChatModel，API 20+）。
 *   ⇒ 零模型文件、零包体积增长；代价是「模型是否就位」由系统决定。
 *
 * ★★★ 铁律（与 ai/ModelRunner 同一条：**LLM 是锦上添花，规则是保底**）
 *   ① 设备没有该 syscap          → reason='no-syscap'（先用 canIUse 判，不触发底层异常）
 *   ② init() 抛错或返 false      → reason='init-failed'（系统模型没下载是**正常情况**，不算失败）
 *   ③ chat() 报错 / 超时         → reason='chat-failed' / 'timeout'
 *   ④ **任何路径都不抛异常**；调用方拿到 false 就回落到 `ChatFinder.parse()` 的规则版
 *
 * 用法：
 *   const ok: boolean = await LocalLLM.init();        // 只需一次（内部缓存）
 *   if (ok) {
 *     await LocalLLM.chat('想玩个不太难的解谜', (piece: string) => { ... });   // 流式
 *   }
 */
import { localChatModel } from '@kit.DataAugmentationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'LocalLLM';
const SYS_CAP: string = 'SystemCapability.DataAugmentation.LocalChatModel';
/** 单次问答的硬超时（超时按失败回落规则，不让界面干等） */
const TIMEOUT_MS: number = 20000;

/** 一次「初始化 / 问答」的统计（给诊断面板与断言用，照 RunnerStat 的样子） */
export interface LlmStat {
  /** 模型可用（init 成功且至少能答） */
  ready: boolean;
  /** 不可用/最近一次失败的原因：idle / ok / no-syscap / init-false / init-failed / chat-failed / timeout */
  reason: string;
  /** init 耗时 ms */
  initMs: number;
  /** 首 token 延迟 ms（0 = 还没拿到过） */
  firstTokenMs: number;
  /** 最近一次问答总耗时 ms */
  totalMs: number;
  /** 问答次数 */
  calls: number;
}

export class LocalLLM {
  static stat: LlmStat = {
    ready: false, reason: 'idle', initMs: 0, firstTokenMs: 0, totalMs: 0, calls: 0
  };
  private static inited: boolean = false;
  private static seq: number = 0;
  /**
   * ★★★ 2026-11-09 perf-hunter（产品缺陷修复）：**失败不再永久缓存**。
   *
   * 旧行为（缺陷）：`init()` 一旦失败，`inited` 仍是 `true` ⇒ 之后**永远**走规则版，
   *   用户把系统模型装好/修好也**不会自愈**（必须杀进程重启）。
   *   实测证据：第一次问出 `init=false 耗时 1118ms`；第二次问**一条日志都没有**（命中缓存 + 零重试）。
   *
   * 新行为：
   *   ① **失败 ⇒ `inited = false`**（允许下次重试）
   *   ② **但失败后 `RETRY_COOLDOWN_MS` 内不再真 init**（否则每次提问都要拉一次系统模型，实测 1118ms）
   *   ③ `reset()` 会把冷却清掉 ⇒ 诊断卡「点一下刷新」可以立刻重试
   */
  static readonly RETRY_COOLDOWN_MS: number = 60000;
  /** 上次失败时刻（0 = 没失败过）；冷却判据用它 */
  private static lastFailMs: number = 0;

  /**
   * ★★★ 2026-11-09 perf-hunter（AppStorage 终解）：把 `stat` 镜像进 **AppStorage**。
   *
   * 为什么：`stat` 是普通静态对象，**没有观察源** ⇒ 设置页只能手动抄进 `@State`，
   *   而实测「点击 → 手动赋值 → 组件不重建」（`rev` 涨了、标题没变、像素差 0）。
   * ⇒ 改成写 `AppStorage`，界面用 `@StorageProp` 读 ⇒ **框架保证通知**，不依赖手动重建调度。
   * ⚠️ 所有会改 `stat` 的地方都必须调它（`fail` / `init` 成功 / `chat` 结束 / `retry` / `reset`）。
   */
  private static sync(): void {
    AppStorage.setOrCreate('llmReason', LocalLLM.stat.reason);
    AppStorage.setOrCreate('llmInitMs', LocalLLM.stat.initMs);
    AppStorage.setOrCreate('llmFirstMs', LocalLLM.stat.firstTokenMs);
    AppStorage.setOrCreate('llmCalls', LocalLLM.stat.calls);
    AppStorage.setOrCreate('llmReady', LocalLLM.stat.ready);
  }

  /** 失败收尾：**把 inited 放回 false**，并记下失败时刻（判据：失败不能永久缓存） */
  private static fail(reason: string): void {
    LocalLLM.inited = false;
    LocalLLM.lastFailMs = Date.now();
    LocalLLM.stat.ready = false;
    LocalLLM.stat.reason = reason;
    LocalLLM.sync();
  }

  /** 设备是否具备该系统能力（canIUse 自身不抛，仍包一层） */
  static available(): boolean {
    try {
      return canIUse(SYS_CAP);
    } catch (e) {
      return false;
    }
  }

  /** 初始化（会拉起系统的「模型管理应用」）；失败返回 false，**绝不抛** */
  static async init(): Promise<boolean> {
    if (LocalLLM.inited) {
      return LocalLLM.stat.ready;
    }
    // ★ 冷却：刚失败过就先不真 init（返回值仍是 false ⇒ 调用方照常回落规则版）
    if (LocalLLM.lastFailMs > 0 && (Date.now() - LocalLLM.lastFailMs) < LocalLLM.RETRY_COOLDOWN_MS) {
      return false;
    }
    LocalLLM.inited = true;
    if (!LocalLLM.available()) {
      hilog.warn(0x0000, TAG, '设备无 LocalChatModel syscap ⇒ 降级到规则版');
      LocalLLM.fail('no-syscap');
      return false;
    }
    const t0: number = Date.now();
    try {
      const ok: boolean = await localChatModel.init();
      LocalLLM.stat.initMs = Date.now() - t0;
      hilog.info(0x0000, TAG, 'init=%{public}s 耗时 %{public}dms', String(ok), LocalLLM.stat.initMs);
      if (!ok) {
        LocalLLM.fail('init-false');
        return false;
      }
      LocalLLM.stat.ready = true;
      LocalLLM.stat.reason = 'ok';
      LocalLLM.lastFailMs = 0;
      LocalLLM.sync();
      return true;
    } catch (e) {
      const err = e as BusinessError;
      LocalLLM.stat.initMs = Date.now() - t0;
      hilog.warn(0x0000, TAG, 'init 失败 code=%{public}d msg=%{public}s ⇒ 降级到规则版',
        err.code, err.message);
      LocalLLM.fail('init-failed');
      return false;
    }
  }

  /**
   * 流式问答：每来一段就回调一次 onAnswer；返回「是否完整答完」。
   * 失败/超时/未初始化 ⇒ 返回 false（调用方回落规则），**不抛**。
   */
  static chat(question: string, onAnswer: (content: string) => void): Promise<boolean> {
    return new Promise<boolean>((resolve: (v: boolean) => void) => {
      if (!LocalLLM.stat.ready) {
        resolve(false);
        return;
      }
      LocalLLM.seq = (LocalLLM.seq + 1) % 65536;
      const info: localChatModel.QuestionInfo = { questionId: LocalLLM.seq, content: question };
      const cfg: localChatModel.Config = { isStream: true };
      const t0: number = Date.now();
      let settled: boolean = false;
      const finish = (ok: boolean): void => {
        if (settled) {
          return;
        }
        settled = true;
        LocalLLM.stat.calls += 1;
        LocalLLM.stat.totalMs = Date.now() - t0;
        LocalLLM.sync();
        if (!ok) {
          LocalLLM.stat.reason = LocalLLM.stat.reason === 'timeout' ? 'timeout' : 'chat-failed';
        }
        resolve(ok);
      };
      const timer: number = setTimeout(() => {
        LocalLLM.stat.reason = 'timeout';
        hilog.warn(0x0000, TAG, 'chat 超时 %{public}dms ⇒ 降级', TIMEOUT_MS);
        finish(false);
      }, TIMEOUT_MS);
      try {
        localChatModel.chat(info, cfg, (err: BusinessError, ans: localChatModel.Answer) => {
          if (err) {
            clearTimeout(timer);
            hilog.warn(0x0000, TAG, 'chat 回调错误 code=%{public}d', err.code);
            finish(false);
            return;
          }
          if (ans === undefined || ans === null) {
            return;
          }
          if (ans.content !== undefined && ans.content.length > 0) {
            if (LocalLLM.stat.firstTokenMs === 0) {
              LocalLLM.stat.firstTokenMs = Date.now() - t0;
            }
            onAnswer(ans.content);
          }
          if (ans.isFinished) {
            clearTimeout(timer);
            finish(true);
          }
        }).catch((e: BusinessError) => {
          clearTimeout(timer);
          hilog.warn(0x0000, TAG, 'chat promise 拒绝 code=%{public}d', e.code);
          finish(false);
        });
      } catch (e) {
        clearTimeout(timer);
        const err = e as BusinessError;
        hilog.warn(0x0000, TAG, 'chat 调用异常 code=%{public}d', err.code);
        finish(false);
      }
    });
  }

  /**
   * ★ 2026-11-09：**只重置 init 缓存与冷却，保留统计**（`calls` 等）—— 诊断卡「重试」用。
   * 为什么不直接用 `reset()`：`reset()` 会把 `stat.calls` 一起清零，
   *   用户点一下"重试"就丢掉"问答次数"历史，诊断信息反而变少。
   */
  static retry(): void {
    LocalLLM.inited = false;
    LocalLLM.lastFailMs = 0;
    LocalLLM.stat.reason = 'idle';
    LocalLLM.sync();
  }

  /** 重置状态（诊断/测试用；正式流程不需要） */
  static reset(): void {
    LocalLLM.inited = false;
    LocalLLM.lastFailMs = 0;   // ★ 清冷却 ⇒ 诊断卡「点一下刷新」可以立刻重试
    LocalLLM.seq = 0;
    LocalLLM.stat = {
      ready: false, reason: 'idle', initMs: 0, firstTokenMs: 0, totalMs: 0, calls: 0
    };
    LocalLLM.sync();
  }
}
