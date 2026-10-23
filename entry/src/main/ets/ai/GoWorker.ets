/**
 * GoWorker —— 把围棋 MCTS 放到工作线程（2026-10-23 第二期）
 *
 * 为什么要这样：
 *   实测 MCTS 在 400 ms 预算下才打得过现有启发式（100 ms 时是输的：
 *   2 胜 5 负 3 平；400 ms 是 5 胜 2 负 1 平、平均净胜 +2.25）。
 *   但 400 ms 同步跑在 UI 线程上会让界面冻住 —— 这是不许发生的。
 *   ⇒ 走 TaskPool，和五子棋（GomokuWorker）同一个套路。
 *
 * ★ 参数必须可序列化：只传 number[] / number / string，不传函数。
 * ★ 规则与搜索都在 ai/GoCore.ets 与 ai/GoMcts.ets 里（纯函数），
 *   worker 只负责"起个线程跑一下"。
 * ★ 任何失败 ⇒ 返回 -1，调用方回落到原来的启发式（绝不卡死）。
 */

import { taskpool } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { goMctsPick } from './GoMcts';

const TAG: string = 'GoWorker';

/**
 * 工作线程里算一手围棋。
 * ⚠️ 函数体里只能用「同文件或已导入的纯计算代码」——
 *    不许有界面、不许有状态、不许碰 AppStorage。
 */
@Concurrent
export function goMctsConcurrent(board: number[], who: number, n: number,
                                 koStr: string, budgetMs: number): number {
  try {
    return goMctsPick(board, who, n, koStr, budgetMs, 60000);
  } catch (e) {
    return -1;
  }
}

/** 统计（给诊断用） */
export interface GoWorkerStat {
  offloaded: boolean;
  ms: number;
  total: number;
  falls: number;
}

export class GoWorker {
  private static stat: GoWorkerStat = { offloaded: false, ms: 0, total: 0, falls: 0 };

  static lastStat(): GoWorkerStat {
    return GoWorker.stat;
  }

  /**
   * 异步算一手。**永远有返回值**：工作线程失败就主线程算。
   * @returns 着点下标；-1 表示连降级都算不出来（调用方回落启发式）
   */
  static async pick(board: number[], who: number, n: number,
                    koStr: string, budgetMs: number): Promise<number> {
    const t0: number = Date.now();
    try {
      const r: Object = await taskpool.execute(goMctsConcurrent, board, who, n, koStr, budgetMs);
      const idx: number = r as number;
      GoWorker.stat.offloaded = true;
      GoWorker.stat.ms = Date.now() - t0;
      GoWorker.stat.total++;
      hilog.info(0x0000, TAG, '工作线程出招 idx=%{public}d 用时=%{public}dms 累计=%{public}d',
        idx, GoWorker.stat.ms, GoWorker.stat.total);
      return idx;
    } catch (e) {
      // TaskPool 起不来（设备限制/线程池满）⇒ 主线程同步跑，绝不返回 -1 让游戏卡死
      GoWorker.stat.falls++;
      try {
        return goMctsPick(board, who, n, koStr, Math.min(budgetMs, 250), 20000);
      } catch (e2) {
        return -1;
      }
    }
  }
}
