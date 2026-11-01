/**
 * 演示动画的**节拍器** —— 按「拍」驱动，不按固定间隔
 *
 * ★★★ 2026-10-31 奥森指出（原话）：
 *   「我认为的'演示'不是这样的呀！应该就是一段演示动画」
 *   原实现：`demoStep()` 里一个 tick 就把
 *     `this.tap(a); this.tap(b);` 全做完 ⇒ 玩家只看到格子**瞬间变了**，
 *     没有高亮、没有指向、没有呼吸 —— 那是「AI 代打慢速版」，不是演示动画。
 *
 * ★ 真正的演示动画（参考街机 attract mode / 游戏内教学动画）：
 *   ① **脚本**：演的是「这游戏最好看的那一手」，不是 AI 随手算的一步
 *   ② **视觉引导**：人的眼睛先看「在动的」和「最亮的」⇒ 动作前先高亮目标
 *   ③ **节拍**：引导 → 执行 → 结果，三拍各有各的时长，不是匀速连发
 *   ④ **自解释**：看完要明白玩法，而不是「看见一堆格子自己动」
 *
 * 用法（游戏里）：
 *   this.demoId = Demo.run((phase: number): number => {
 *     if (phase === 0) { 高亮 + 文案; return Demo.GUIDE_MS; }
 *     if (phase === 1) { 执行动作;    return Demo.ACT_MS; }
 *     ...（结果拍）
 *     return -1;                     // 结束
 *   });
 *   Demo.stop(this.demoId);          // 玩家一碰就停
 */
export class Demo {
  /** 第 1 拍 · 引导：高亮目标 + 一句「看这里」*/
  static readonly GUIDE_MS: number = 720;
  /** 第 2 拍 · 执行：真正动作，短促 */
  static readonly ACT_MS: number = 280;
  /** 第 3 拍 · 结果：亮出结果，留够时间看清 */
  static readonly RESULT_MS: number = 1150;
  /** 拍与拍之间的静默（让上一拍"落地"）*/
  static readonly GAP_MS: number = 90;

  private static seq: number = 0;
  private static live: Set<number> = new Set<number>();

  /**
   * 按拍驱动。
   * @param beat 每拍调用一次；返回「这一拍要停留多久（ms）」，返回 < 0 表示结束
   * @returns 句柄（传给 stop）
   */
  static run(beat: (phase: number) => number): number {
    Demo.seq = Demo.seq + 1;
    const id: number = Demo.seq;
    Demo.live.add(id);
    let phase: number = 0;
    const step = (): void => {
      if (!Demo.live.has(id)) { return; }
      let wait: number = -1;
      try {
        wait = beat(phase);
      } catch (e) {
        wait = -1;                 // 演示里出错也要停，绝不能让游戏卡死
      }
      if (wait < 0) {
        Demo.live.delete(id);
        return;
      }
      phase = phase + 1;
      setTimeout(() => { step(); }, wait);
    };
    setTimeout(() => { step(); }, Demo.GAP_MS);
    return id;
  }

  /** 停止（玩家碰屏幕 / 离开页面 / 组件销毁时调用）*/
  static stop(id: number): void {
    if (id >= 0) { Demo.live.delete(id); }
  }

  /** 是否还在演 */
  /**
   * ★★★ 2026-11-01（奥森「演示就是一段动画，不计分」的第三时刻）：
   *   `handleFinish()` 里会写两样东西：
   *     · `ProgressStore.finishGame(...)` —— 加经验、记战绩
   *     · `GameLog.recordResult(...)`     —— 写战绩日志
   *   而它**原来完全不判断是否在演示** ⇒ 演示过程中若达成胜利条件，
   *   **演示会写进战绩、给玩家加经验**。
   *   ⇒ 过程中的 HUD 已经遮挡了（第 675 轮），结束后的状态也恢复了（第 661 轮），
   *     但「回看记录里的玩家」看到的还是被污染的记录 —— 这是第三个时刻。
   *
   *   这里提供全局查询：只要有**任一**演示在跑就返回 true。
   *   ★ 为什么放这里：355 款各有自己的 `demoId`，GameHost 看不到；
   *     而 `Demo.live` 本来就是全局的活跃集合 ⇒ 一处判断覆盖全部。
   */
  static anyRunning(): boolean {
    return Demo.live.size > 0;
  }

  static running(id: number): boolean {
    return id >= 0 && Demo.live.has(id);
  }

  /**
   * ★★★ 2026-11-01（判据 54 的第三个出口）：**一次性停掉所有演示**。
   *
   *   页面销毁时（`aboutToDisappear`）必须停干净 ——
   *   否则 355 款各自的 `demoId` 计时器会在**已销毁的组件**上继续跑，
   *   改 @State、算下一步，后台空跑。
   *
   *   `Demo.live` 本来就是全局活跃集合 ⇒ 清空它 + 让 step 里的 `has(id)` 变假
   *   ⇒ 所有在跑的演示在下一拍就自己退出（不用逐个拿句柄）。
   */
  static stopAll(): void {
    Demo.live.clear();
  }
}
