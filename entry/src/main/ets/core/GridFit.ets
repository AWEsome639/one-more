/**
 * GridFit —— 「纵向堆叠正方形单元」的宽度反推
 *
 * ═══ 为什么需要它（判据 3098）═══
 * 一晚修了四款同一类缺陷：`Simon Command`(3089) / `Simon Says`(3097) /
 * `Odd Rotation`(3098) / `Silhouette Match`(3084)。共同写法是：
 *
 *     Column {
 *       ForEach(行) { Row { ForEach(列) { Stack().layoutWeight(1).aspectRatio(1) } } }
 *     }.width('100%')            ← ★ 宽度按整屏算
 *
 * `.aspectRatio(1)` 让每块都是**正方形** ⇒ 行宽决定块高 ⇒ **n 行就吃掉 n 倍行宽的高度**。
 * 小屏竖屏上必然装不下，于是最下面一排被切 —— 用户点不到。
 *
 * ═══ 几何关系（可复算）═══
 * 设：n 行、c 列、块间距 g、网格上方 chrome 为 `above`、下方为 `below`。
 *   块边长  s = (W − (c−1)·g) / c
 *   网格总高 H = n·s + (n−1)·g
 *   要求    H + above + below ≤ H_avail
 * ⇒ 解出  W ≤ c·(H_avail − above − below − (n−1)·g)/n + (c−1)·g
 *
 * ═══ 用法 ═══
 *   .width(GridFit.width(3, 3, Space.sm, 201.6, 86, Bp.height))   // 3×3、上方 201.6、下方 86
 * 横屏/大屏不要用本式 —— 那里的瓶颈是宽度不是高度，直接 `'100%'`（用 `Bp.isShort()` 分流）。
 *
 * ⚠️ `above` / `below` **必须逐款实测**（从截图量），不能估。实测教训：
 *    `Simon Says` 我估上方 chrome `201.6vp`，实测 `272vp`，差 `70vp` ⇒ 第一次常数完全错。
 */
export class GridFit {
  /**
   * 反推网格最大宽度（vp）。
   * @param cols  列数（≥1）
   * @param rows  行数（≥1）
   * @param gap   块间距（vp）
   * @param above 网格**上方**的 chrome 总高（vp，实测）
   * @param below 网格**下方**的 chrome 总高（vp，实测）
   * @param avail 可用总高（vp），传 `Bp.height`
   * @param floor 最小宽度下限（vp），默认 `120`，避免算出荒谬的小值
   */
  static width(cols: number, rows: number, gap: number,
               above: number, below: number,
               avail: number, floor: number = 120): number {
    const c: number = Math.max(1, cols);
    const n: number = Math.max(1, rows);
    const g: number = Math.max(0, gap);
    const budget: number = avail - Math.max(0, above) - Math.max(0, below) - (n - 1) * g;
    if (budget <= 0) { return floor; }
    // 每块边长的上界
    const s: number = budget / n;
    const w: number = c * s + (c - 1) * g;
    return Math.max(floor, Math.floor(w));
  }

  /**
   * 自检：把 `width()` 的结果代回几何式，检查总高是否真的装得下。
   * 返回 `[ok, 实算总高, 预算]`。
   * ⚠️ 这是**数学自检**，不能替代真机截图（判据 2605）。
   */
  static check(cols: number, rows: number, gap: number,
               above: number, below: number,
               avail: number): [boolean, number, number] {
    const c: number = Math.max(1, cols);
    const n: number = Math.max(1, rows);
    const g: number = Math.max(0, gap);
    const w: number = GridFit.width(c, n, g, above, below, avail, 0);
    const s: number = (w - (c - 1) * g) / c;
    const total: number = n * s + (n - 1) * g + above + below;
    return [total <= avail + 0.5, total, avail];
  }
}
