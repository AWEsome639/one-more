/**
 * GomokuWorker —— 把五子棋搜索挪出 UI 线程（2026-10-23，路线 D 下半）
 *
 * 为什么必须挪：
 *   路线 A 的 α-β 搜索跑在 UI 主线程上，实测 188ms（困难档预算 400ms）。
 *   188ms 已经是"点下去手能感觉到顿"的量级；想再往深处搜（棋力更强）
 *   就必须把这个时间花在别的线程上。
 *
 * 为什么用 TaskPool 而不是 Worker：
 *   Worker 要单独建文件 + 手写消息协议；TaskPool 用 @Concurrent 函数 + Promise，
 *   对「算一次、回一个数」这种活是最省事的。项目里其余地方也没用过 Worker。
 *
 * ★ 关键约束（arkts 的线程模型）：
 *   ① @Concurrent 函数里**不能碰 this、不能碰 UI 状态、不能碰 AppStorage**
 *      ⇒ 所以参数只有 棋盘/尺寸/难度，返回值只有下标
 *   ② 参数与返回值必须可序列化 ⇒ number[] / number 正好
 *   ③ 每次调用都要**自己 new 一个 search 实例** —— 线程间的对象不共享
 *      （这会让置换表每次重置、损失一点剪枝效率，但换来 UI 不冻，值）
 *
 * ★ 失败必须降级：TaskPool 起不来（设备限制/线程池满）⇒ 主线程同步跑，
 *   就是路线 A 原来的行为，绝不返回 -1 让游戏卡死。
 */

import { taskpool } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GomokuSearch } from './GomokuSearch';

const TAG: string = 'GomokuWorker';

/**
 * 在工作线程里跑一次搜索。
 * ⚠️ 这个函数体里只能用「同文件或已导入的纯计算代码」——
 *    不许有界面、不许有状态、不许 await 界面相关的东西。
 */
@Concurrent
export function gomokuPickConcurrent(board: number[], size: number, level: number): number {
  const s: GomokuSearch = new GomokuSearch();
  return s.pick(board, size, level);
}

/** 统计（给诊断用） */
export interface WorkerStat {
  /** 最近一次是否走了工作线程 */
  offloaded: boolean;
  /** 工作线程耗时 ms（没走线程时是主线程耗时） */
  ms: number;
  /** 累计走了多少次工作线程 */
  total: number;
  /** 累计降级了多少次 */
  falls: number;
}

export class GomokuWorker {
  private static stat: WorkerStat = { offloaded: false, ms: 0, total: 0, falls: 0 };

  static lastStat(): WorkerStat {
    return GomokuWorker.stat;
  }

  /**
   * 异步取一手。**永远有返回值**：工作线程失败就主线程算。
   * @returns 棋盘下标；-1 表示连降级都算不出来（调用方回落启发式）
   */
  static async pick(board: number[], size: number, level: number): Promise<number> {
    const t0: number = Date.now();
    try {
      // execute 返回 Promise<Object>，强转成 number
      const r: Object = await taskpool.execute(gomokuPickConcurrent, board, size, level);
      const idx: number = r as number;
      if (idx >= 0) {
        GomokuWorker.stat.offloaded = true;
        GomokuWorker.stat.ms = Date.now() - t0;
        GomokuWorker.stat.total++;
        hilog.info(0x0000, TAG, '工作线程出招 idx=%{public}d 用时=%{public}dms 累计=%{public}d',
          idx, GomokuWorker.stat.ms, GomokuWorker.stat.total);
        return idx;
      }
      // 工作线程算不出（正常：简单档返回 -1）⇒ 不当作失败
      GomokuWorker.stat.offloaded = true;
      GomokuWorker.stat.ms = Date.now() - t0;
      hilog.info(0x0000, TAG, '工作线程返回 -1（正常：简单档不搜）用时=%{public}dms',
        GomokuWorker.stat.ms);
      return -1;
    } catch (e) {
      // 线程池起不来 / 序列化失败 / 设备限制 ⇒ 主线程兜底
      GomokuWorker.stat.offloaded = false;
      GomokuWorker.stat.falls++;
      hilog.warn(0x0000, TAG, 'TaskPool 失败 ⇒ 主线程兜底: %{public}s', JSON.stringify(e));
      try {
        const s: GomokuSearch = new GomokuSearch();
        const idx: number = s.pick(board, size, level);
        GomokuWorker.stat.ms = Date.now() - t0;
        return idx;
      } catch (e2) {
        GomokuWorker.stat.ms = Date.now() - t0;
        return -1;
      }
    }
  }
}
