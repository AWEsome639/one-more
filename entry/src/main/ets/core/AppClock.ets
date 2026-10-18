/**
 * ★★★ AppClock —— 全局「app 是否在前台」时钟
 *
 * 2026-10-17 13:3x 抓到的真 BUG（奥森第七轮「扩到不能再扩」时实测）：
 *   玩「不等式冲刺」剩 56 秒 → 按 HOME 切后台 30 秒 → 回来只剩 17 秒
 *   ⇒ 25 个倒计时游戏在后台【继续走表】，用户切去看个消息回来就快判负了
 *   ⇒ 根因：setInterval 每秒无条件减 1，没人管 app 是不是在前台
 *
 * 修法（最小侵入）：
 *   ① GameHost 的 onPageHide / onPageShow 里调 AppClock.hide() / .show()
 *   ② 25 个倒计时游戏的 setInterval 回调开头加一行：
 *        if (AppClock.isPaused()) { return; }
 *      ⇒ 后台期间 tick 被跳过，回来接着走
 *
 * 为什么不用「按 Date.now() 补偿」：
 *   那样时间照样流逝，用户切出去 30 秒回来还是少 30 秒 —— 对休闲小游戏不友好。
 *   现在的语义是【离开 = 暂停】，与本 app 的「碎片时间玩一局」定位一致。
 */
export class AppClock {
  /** ★ 是否处于「离开游戏页」状态 */
  private static paused: boolean = false;
  /** ★ 累计被暂停的毫秒数（供需要"净游戏时长"的地方用） */
  private static pausedMs: number = 0;
  private static pauseAt: number = 0;

  /** 离开游戏页（切后台 / 回列表 / 进指南页）—— 由 GameHost.onPageHide 调 */
  static hide(): void {
    if (!AppClock.paused) {
      AppClock.paused = true;
      AppClock.pauseAt = Date.now();
    }
  }

  /** 回到游戏页 —— 由 GameHost.onPageShow 调 */
  static show(): void {
    if (AppClock.paused && AppClock.pauseAt > 0) {
      AppClock.pausedMs = AppClock.pausedMs + (Date.now() - AppClock.pauseAt);
    }
    AppClock.paused = false;
    AppClock.pauseAt = 0;
  }

  /** ★ 倒计时游戏在 setInterval 回调开头问一句：现在该不该跳过这一 tick */
  static isPaused(): boolean {
    return AppClock.paused;
  }


}
