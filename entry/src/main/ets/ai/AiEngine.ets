/**
 * AiEngine —— 端侧 AI 引擎的单一入口（2026-10-23，路线 D）
 *
 * 为什么需要它（而不是让各游戏自己 new ModelRunner）：
 *   ① 354 款游戏 + 将来路线 B/C 的模型，如果每处各 new 一个，
 *      就会重复加载、重复占内存 ⇒ 必须只有一个实例
 *   ② 「这台设备支不支持、模型在不在」是**启动时就能知道**的事，
 *      应该在启动时探一次、结果缓存下来，而不是每次进游戏都试
 *   ③ 设置页要显示「AI 引擎状态」，需要一个全局可读的地方
 *
 * ★ 铁律：探针失败**不是错误**，是正常的降级状态。
 *   没有模型的应用照样完整可玩 —— 这是 One More 的底线。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ModelRunner, RunnerStat } from './ModelRunner';

const TAG: string = 'AiEngine';

export class AiEngine {
  private static runner: ModelRunner = new ModelRunner();
  private static probed: boolean = false;
  private static stat: RunnerStat = { ready: false, reason: 'not-probed', loadMs: 0, inferMs: 0, calls: 0 };

  /**
   * 启动时探一次（EntryAbility.onCreate 里调）。
   * 这个函数**不 await** —— 启动路径不许被模型拖慢。
   */
  static probe(ctx: common.UIAbilityContext): void {
    if (AiEngine.probed) {
      return;
    }
    AiEngine.probed = true;
    // 不 await：加载失败也好、慢也好，都不该挡住首屏
    AiEngine.runner.loadFromRawfile(ctx, 'sudoku_difficulty.ms', 30, 1).then(() => {
      AiEngine.stat = AiEngine.runner.lastStat();
      hilog.info(0x0000, TAG, 'AI 引擎探针: ready=%{public}s reason=%{public}s %{public}dms',
        AiEngine.stat.ready ? 'Y' : 'N', AiEngine.stat.reason, AiEngine.stat.loadMs);
    }).catch(() => {
      AiEngine.stat = { ready: false, reason: 'probe-failed', loadMs: 0, inferMs: 0, calls: 0 };
    });
  }

  /** 当前状态（设置页显示用） */
  static status(): RunnerStat {
    if (AiEngine.stat.reason === 'not-probed') {
      return AiEngine.runner.lastStat().reason === 'idle' ? AiEngine.stat : AiEngine.runner.lastStat();
    }
    return AiEngine.stat;
  }

  /** 给将来的模型用：拿 runner（没有模型时 infer 会返回 null） */
  static model(): ModelRunner {
    return AiEngine.runner;
  }

  /** 人类可读的一句话（设置页直接显示） */
  static statusText(): string {
    const s: RunnerStat = AiEngine.status();
    if (s.ready) {
      return 'on';                       // 已就绪
    }
    const r: string = s.reason;
    if (r === 'no-syscap') {
      return 'no-syscap';                // 这台设备不支持
    }
    if (r === 'no-model') {
      return 'no-model';                 // 没带模型（正常状态）
    }
    if (r === 'not-probed' || r === 'idle') {
      return 'pending';                  // 还没探
    }
    return 'failed';                     // 其它失败
  }
}
