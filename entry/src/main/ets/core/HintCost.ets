/**
 * HintCost —— 「用过提示」的全局计数器（2026-11-05，第 1393 轮）
 *
 * ★★★ 为什么要有（判据 1314/1315/1319/1320/1321）
 *
 *   审计 355 款的提示文案时发现：
 *   · 文案质量**很高**（具体到「第 3 行第 5 列必须放灯」「先把两边都除以 2」）
 *   · 但**一部分提示直接给答案**：
 *       GAnagramDefinition   「答案是「{0}」」
 *       GAngleFinder         「答案是 {0}」
 *       GAreaPerimeterMatch  「答案是第 {0} 个」
 *       GAlgebraicInequalitySolver「解集是 {0}」
 *   · 而 **355 款里 0 款记录「用过提示」**（`hintUsed` 零命中）
 *   · 而「完美主义 💎」成就的判定只看**得分 ≥ 基准 ×10**
 *
 *   ⇒ 三者合起来是一个真问题：
 *     **点一下提示就能直接拿答案，不扣分、不扣次数，还能拿「完美主义」。**
 *
 *   ⇒ 这个文件只做一件事：**记住「这一局用过几次提示」**，
 *     由 `ProgressStore.finishGame` 在结算时读取并清零。
 *
 * ★ 为什么用全局静态计数器而不是每个游戏加字段
 *   · 355 款各有自己的 `@State`，逐个加字段 = **355 处改动**（判据 ⑥：批量改 ≠ 批量修好）
 *   · 而 `HintBar.onHintTap()` 在组件内部只有 **2 个调用点**（键盘 + 点击）
 *     ⇒ 在那里 `note()` 一次，覆盖全部 355 款（判据 1319）
 *   · `HintBar` 是纯展示组件，`onHintTap` **只服务提示这一个目的**（判据 1320）
 *
 * ★ 为什么不在 `askHint()` 里加
 *   `askHint()` 是**每款自己实现**的（353 处）⇒ 改那里等于改 353 个文件。
 *
 * ★ 边界
 *   · 演示（demoId >= 0）时提示按钮是禁用的 ⇒ 不会 note()
 *   · 联机对战时按钮禁用 ⇒ 不会 note()
 *   · 计数**只管当前这一局**，`finishGame` 读完立刻清零
 *     ⇒ 中途退出不结算也不会有残留影响（下次结算读到的仍是 0 增量）
 */
export class HintCost {
  /** 当前这一局用过几次提示（未结算前累加） */
  private static used: number = 0;

  /** 玩家点了一次「提示」⇒ +1（由 `HintBar` 在唯一的两个调用点调用） */
  static note(): void {
    HintCost.used = HintCost.used + 1;
  }

  /**
   * 结算时读走并清零。
   *
   * ★ 为什么要「读走」而不是「读」：
   *   如果是纯读，下一局会继承上一局的计数 ⇒ 玩家第一局用过提示，
   *   之后**每一局都不算完美**。`take()` 保证计数是**局内**的。
   */
  static take(): number {
    const n: number = HintCost.used;
    HintCost.used = 0;
    return n;
  }

  /** 只读，不清零（给结算界面显示用；结算后一般已 take 过） */
  static peek(): number {
    return HintCost.used;
  }

  /** 强制清零（中途退出、重开时用） */
  static reset(): void {
    HintCost.used = 0;
  }
}
