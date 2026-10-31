/**
 * 返回上一页 —— 但先处理「路由栈里只有自己」的情况
 *
 * ★★★ 2026-10-31 真机抓到的 bug：
 *   应用被系统杀掉后**任务快照恢复**，会直接回到当时那一页（不经过 Splash）。
 *   此时路由栈里**只有这一页**，没有 Index。
 *   而 `router.back()` 在栈空时**不是"什么都不做"，是"退出应用"**
 *   ⇒ 玩家看到游戏页，点一下「‹」就回到桌面。
 *
 * ⇒ 修法：栈深 ≤ 1 时用 `replaceUrl` 补回列表页，而不是 back()。
 *
 * 用法（页面里）：
 *   import { Back } from '../core/Back';
 *   Back.go();                       // 默认补回 pages/Index
 *   Back.go('pages/Index');          // 显式指定兜底页
 */
import { router } from '@kit.ArkUI';

export class Back {
  /**
   * 返回上一页；栈空时 replace 到兜底页。
   * @param fallback 栈空时要补回的页面（默认 pages/Index）
   */
  static go(fallback: string = 'pages/Index'): void {
    let depth: number = -1;
    try {
      // getLength() 返回 string（旧 API，但可用）；拿不到就按 -1 处理
      const s: string = router.getLength();
      const n: number = Number(s);
      // ★ 必须用 >= 0：getLength() 返回 "0" 时也要认（否则 depth 停在 -1，
      //   会落到 router.back() 分支 —— 那正是"栈空就退出应用"的老 bug）。
      if (!isNaN(n) && n >= 0) {
        depth = n;
      }
    } catch (e) {
      depth = -1;
    }
    if (depth <= 1) {
      // 只剩这一页（或已经空栈）⇒ back() 会退出应用 ⇒ 换成 replace
      router.replaceUrl({ url: fallback });
      return;
    }
    // depth === -1（拿不到）时走原逻辑，保持旧行为
    router.back();
  }
}
