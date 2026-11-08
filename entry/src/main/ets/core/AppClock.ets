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

  /**
   * ★★★ 2026-11-08 **净时钟**（perf-hunter）：`Date.now()` 扣掉「离开游戏页」的累计时长。
   *
   * 为什么需要：一批游戏（视觉搜索/单词搜索/打字速度… 约 18 款）的剩余时间是**按墙钟**算的：
   *   `this.leftMs = LIMIT_MS - (Date.now() - roundAt)`
   * ⇒ 切后台 30 秒回来，`Date.now()` 照走 ⇒ 直接少 30 秒（10-17 那个 bug 的**另一半**：
   *   当年只给「每秒 tick 型」加了 `isPaused()` 守卫，**墙钟型一款都没修**）。
   *
   * 为什么是「净时钟」而不是「各自减 pausedMs」：
   *   减 `pausedMs` 的写法要求每一局开始额外存一份 `pausedMs` 基线，
   *   **18 款 = 18 个容易漏的失败点**。
   *   而只要把 `roundAt` 也取 `netNow()`，两端同源 ⇒ 基线**自动对齐**，没有可漏的地方：
   *     `gap = netNow() - roundAt = (now - paused) - (start - pausedBase) = 真实活跃时长`
   *
   * ⚠️ **必须与 `isPaused()` 守卫配用**（这是两个不同的问题，缺一不可）：
   *   · 守卫解决「**后台期间**别把这一秒算进去」（否则后台就跑超时、直接判负）
   *   · `netNow()` 解决「**回到前台**后别把刚才那段时间算进去」
   *   只加守卫不加 netNow ⇒ 回来第一次 tick 就跳掉一段；只加 netNow 不加守卫 ⇒ 后台照样判负。
   *
   * ⚠️ 只在**可见时**读才有意义：暂停进行中 `pausedMs` 还没累加，
   *    那一刻的 `netNow()` 会把「当前这一段还没结束的后台时间」算成活跃时间。
   *    配了 `isPaused()` 守卫就不会在后台读到它。
   */
  static netNow(): number {
    return Date.now() - AppClock.pausedMs;
  }

}
