import { promptAction } from '@kit.ArkUI';

/**
 * Hint —— 统一的「提示」层（2026-10-23 第二期）
 *
 * 为什么需要它：
 *   355 款里 103 款是解谜类（逻辑 44 + 数字 59），但**只有 1 款（数独）有真求解器**。
 *   解谜类的「聪明」不是「有个对手」，是「我卡住时它能帮我」。
 *   ⇒ 做一个统一出口，游戏只要实现「算下一步」就能接入提示，
 *     算不出来也不会把游戏弄坏。
 *
 * 设计三原则：
 *   ① **算不出是正常状态**，不是错误 —— 用 ok=false + reason 表达，不抛异常
 *   ② **有预算**：单次提示超过 BUDGET_MS 就放弃，宁可说"想不出来"也不许冻界面
 *   ③ **文案走 TG**：提示说什么由游戏给，但必须带中英两版，接进 12 语言机制
 *
 * 用法（游戏里）：
 *   const r: HintResult = Hint.run(() => this.computeHint());
 *   if (r.ok) { 高亮 r.cells；显示 r.zh/r.en }
 *   else { 显示"这局暂时想不出来" }
 */

export interface HintResult {
  /** 是否成功给出提示 */
  ok: boolean;
  /** 原因：'ok' | 'none' | 'unsupported' | 'error' */
  reason: string;
  /** 提示指向的格子下标（含义由游戏定义：数独是格号，扫雷是雷格…） */
  cells: number[];
  /** 中文说明（走 TG） */
  zh: string;
  /** 英文说明（走 TG 的第二参数） */
  en: string;
  /** 计算耗时 ms */
  ms: number;
}

export class Hint {
  /** 单次提示的时间预算。超了就明说想不出来，不许冻界面。 */
  static readonly BUDGET_MS: number = 500;

  /** 算不出来（这是正常状态，不是错误） */
  static none(reason: string): HintResult {
    return { ok: false, reason: reason, cells: [], zh: '', en: '', ms: 0 };
  }

  /** 成功给出提示 */
  static make(cells: number[], zh: string, en: string, t0: number): HintResult {
    return { ok: true, reason: 'ok', cells: cells, zh: zh, en: en, ms: Date.now() - t0 };
  }

  /**
   * 带着预算跑一个提示器。
   * ⚠️ 不做真正的超时中断（ArkTS 里同步算没法打断），
   *    但会**测耗时**并把超预算的结果降级成 none —— 至少界面不会显示一个"过期的提示"。
   *    ⇒ 真实防线是各游戏自己的 node 预算（数独有 SOLVER_BUDGET，跳棋有 search budget）。
   */
  static run(fn: () => HintResult): HintResult {
    const t0: number = Date.now();
    let r: HintResult;
    try {
      r = fn();
    } catch (e) {
      return { ok: false, reason: 'error', cells: [], zh: '', en: '', ms: Date.now() - t0 };
    }
    const ms: number = Date.now() - t0;
    if (ms > Hint.BUDGET_MS) {
      // 太慢了：这次的结果不用（避免玩家看到一个卡了半秒才出现的提示）
      return { ok: false, reason: 'timeout', cells: [], zh: '', en: '', ms: ms };
    }
    r.ms = ms;
    return r;
  }

  /**
   * ★ 2026-10-23：用 toast 显示一条提示。
   *
   * 为什么放进框架：
   *   到第 13 款时，我发现「提示怎么显示」其实有三种做法 ——
   *     ① 有状态栏 → 复用那个 Text（最省，零风险）
   *     ② 没有状态栏 → toast（零布局改动）
   *     ③ 都不适合 → 才新增元素（⚠️ 必须当场截图确认没挤坏别的控件，
   *        管道/黑白和就是在这里把按钮挤出屏幕的）
   *   皇冠用的是 ②，那段 try/catch 写在各游戏里很重复
   *   ⇒ 收到框架里，以后新接游戏只需一行。
   *
   * ⚠️ toast 起不来（设备不支持 / 权限）就算了 —— 提示是附加功能，
   *    绝不能因为它让游戏出问题。
   */
  static toast(msg: string): void {
    if (msg.length === 0) {
      return;
    }
    try {
      promptAction.showToast({ message: msg, duration: 4000 });
    } catch (e) {
      // 静默失败
    }
  }

  /** 结果给不出时，用一句兜底话走 toast */
  static toastResult(r: HintResult, zhFail: string): void {
    Hint.toast(r.ok ? r.zh : zhFail);
  }

  /** 把结果翻译成「给玩家看的一句话」（给不出时也有话说） */
  static describe(r: HintResult, zhFail: string, enFail: string): string {
    if (r.ok) {
      return r.zh.length > 0 ? r.zh : '';
    }
    if (r.reason === 'timeout') {
      return zhFail;
    }
    return zhFail;
  }
}
