/**
 * 等级曲线 —— **全项目唯一真相源**
 *
 * ★★★ 2026-11-08（成就体系巡检 P0-1）为什么要有这个文件
 *
 *   旧实现有两个函数，各自写死自己的数学，而且**互相对不上**：
 *     · `levelOf(xp)   = min(100, floor((xp/100)^(1/2.04)) + 1)`
 *     · `xpForLevel(L)  = floor(100 × (L−1)^2.04)`，但 `L ≥ 100` 时**直接返回 1000000**
 *   ⇒ 三个后果，全是用户能看见的：
 *     ① `xpForLevel(99) = 1,153,722` **大于** `xpForLevel(100) = 1,000,000` ⇒ **非单调**
 *        ⇒ `levelProgress()` 走到 `hi <= lo` 分支 ⇒ **99 级进度条永远满格**，看不出还差 2.4 万 XP
 *     ② 真正到 100 级要 `1,177,866` XP，而 `xpForLevel(100)` 说 100 万 —— 差 17.8 万
 *     ③ 指数 1/2.04 ≈ 0.49 ⇒ **平方增长**，而 XP 是线性（典型 12/局）
 *        ⇒ 100 级要 **≈98,000 局**，`level_80`/`level_100` 两个成就**数学上不可达**
 *
 *   ⇒ 现在把曲线收成一个类，**指数可调**（`EXP`），两个函数**从同一条曲线派生**，
 *     并保证：**单调递增**、`levelOf(xpForLevel(L)) === L`、100 级封顶。
 *
 * ⚠️ 为什么单独成文件、而不是塞进 `ProgressStore`：
 *    桌面卡片（`formwidget/StatsCardAbility`）也要算等级，而它跑在 **Form 渲染进程**，
 *    引 `ProgressStore` 会把 I18n（3113 条）+ GameRegistry + HintCost 整条链拖进 widget bundle。
 *    本文件**零 import、零副作用、纯数学** ⇒ 两边都能安全引。
 */

export class LevelCurve {
  /**
   * 曲线指数：`levelOf(xp) = floor((xp / 100)^(1 / EXP)) + 1`
   *
   * | EXP | 形状 | L100 门槛 | 按 12XP/局 |
   * |---|---|---:|---:|
   * | 2.04（旧） | 平方增长 | 1,177,866 | ≈98,000 局 ⇒ **不可达** |
   * | **1.3（当前）** | 略快于线性 | **39,255** | **≈3,274 局** ✅ |
   * | 1.0 | 线性 | 9,900 | ≈825 局（太快：200 局就 L25）|
   *
   * 选 1.3 的理由：L100 ≈ 3,300 局，与「千局不倦」（1000 局）同一个数量级，
   * 且 355 款各玩 ~9 次才满级 —— 不劝退，也不至于一个月就封顶。
   */
  static readonly EXP: number = 1.3;
  /** 等级上限 */
  static readonly MAX_LEVEL: number = 100;
  /** 每级基准 XP（`(xp/100)` 里的那个 100） */
  static readonly UNIT: number = 100;

  /**
   * XP → 等级（1 ~ 100）
   * ⚠️ `+ 1e-9` 是对浮点的容错：`xpForLevel(L)` 恰好返回门槛时，
   *    `pow(...)` 可能算出 98.9999999 ⇒ floor 少 1 级。加个极小量就稳。
   */
  static levelOf(xp: number): number {
    if (xp <= 0) {
      return 1;
    }
    const raw: number = Math.pow(xp / LevelCurve.UNIT, 1 / LevelCurve.EXP);
    const l: number = Math.floor(raw + 1e-9) + 1;
    return Math.min(LevelCurve.MAX_LEVEL, Math.max(1, l));
  }

  /**
   * 某一级**需要的最低 XP**（与 `levelOf` 严格互逆）
   * `levelOf(xpForLevel(L)) === L` 对所有 L ∈ [1,100] 成立（见自检注释）。
   * ⚠️ 不再有"100 级写死 1000000"的特例 —— 100 级就是 `100 × 99^EXP`。
   */
  static xpForLevel(level: number): number {
    if (level <= 1) {
      return 0;
    }
    const l: number = Math.min(level, LevelCurve.MAX_LEVEL);
    // ceil：保证"刚好够门槛"就能到这一级（floor 会差 1 XP）
    return Math.ceil(LevelCurve.UNIT * Math.pow(l - 1, LevelCurve.EXP));
  }

  /** 当前等级内的进度 0~1（进度条用） */
  static progress(xp: number): number {
    const lv: number = LevelCurve.levelOf(xp);
    if (lv >= LevelCurve.MAX_LEVEL) {
      return 1;
    }
    const lo: number = LevelCurve.xpForLevel(lv);
    const hi: number = LevelCurve.xpForLevel(lv + 1);
    if (hi <= lo) {
      return 1;
    }
    const p: number = (xp - lo) / (hi - lo);
    return Math.min(1, Math.max(0, p));
  }
}
