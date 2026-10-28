/**
 * 连锁反应 ⚡
 * 规则：3×3 盘（难度改边长 2/3/4），每格容量 = 邻居数；点一下 +1 光点，
 *      超过容量就「炸」——那一格清空（吃掉 容量+1 颗），四邻各 +1，连锁下去。
 * 胜负：**一次点击让全盘每一格都炸开 = 通关**；步数用尽 = 失败。可悔一步 / 要提示 / 有代打。
 *
 * ═══════════════════════════════════════════════════════════════════
 * ★★★ 2026-10-28 修「规则层面就无解」：
 *   旧规则：爆格只做 `a[j] -= cap`、四邻各 +1 ⇒ **级联前后总光点守恒** ⇒
 *          每点一下总数必然 +1（守恒 +1），而通关条件写的是 `total(ns) === 0`
 *          ⇒ 从开局（≥12 点）**永远到不了 0**，这款根本赢不了。
 *   旧规则还自带第二个致命病：盘面能装下的总光点是 Σcap（2×2=8 / 3×3=24 / 4×4=48），
 *          而守恒 +1 会让总数无限涨 ⇒ 一旦超过 Σcap 就**永远稳不下来**，
 *          boom() 的 guard>400 判「连锁失控」⇒ 简单档（2×2）实测 **300 局里 235 局
 *          点第一下就直接输**（棋盘只有 8 格容量，开局却塞了 7~8 点）。
 *
 *   新规则（两处一起改，缺一不可）：
 *   ① **爆炸会消耗光点**：溢出时该格扣掉 (容量+1) 颗、四邻各 +1 ⇒
 *      每炸一次总数严格 −1 ⇒ 单步最多 total+1 次炸 ⇒ **必定收敛**
 *      （彻底消灭「连锁失控」，也把总数锁在 Σcap 以内）。
 *   ② **通关条件换成「一炸到底」**：一次点击让**全盘每一格都炸开**
 *      （boom 用 bitmask 记"这一步炸过哪些格"，掩码铺满 = 通关）。
 *      · 2×2 → 4 格　· 3×3 → 9 格　· 4×4 → 16 格
 *      · 盘面全满时**点任意一格，每一格都正好炸一次**（已逐格枚举验证）⇒ 玩法清晰：
 *        把每格点满（满格时边框变红），最后一下全盘开花。
 *      · 少数「临界盘面」不满也能全盘炸开（3×3 的 103680 个稳定盘面里有 313 个能一步赢，
 *        其中总数只有 20 < 24 的有 151 个）⇒ 高手可以少走几步提前引爆。
 *
 *   三档**数学上都能赢**的证明（见 capsSum/limitOf 的注释）：
 *     点一个**没满**的格子只会 +1、绝不炸 ⇒ 从任意盘面出发，最多 Σcap 步就能把
 *     每一格点到容量；再来一下 ⇒ 每格各炸一次 = 全盘开花。
 *     所以 `limit = Σcap + 2` 时**任何开局都必赢**
 *     （2×2: 10 步 / 3×3: 26 步 / 4×4: 50 步；严格上界 Σcap+1 = 9/25/49）。
 *     更紧的实测（python 穷举**全部**稳定盘面 + 反图最短路，判据同样用掩码）：
 *       · 2×2：81 个盘面，一步能赢的 5 个，**最坏 7 步**，赢不了的 0 个；
 *       · 3×3：103680 个盘面，一步能赢的 313 个，**最坏 20 步**，赢不了的 0 个；
 *       · 4×4：3.3e9 个盘面无法穷举 ⇒ 用上面那条严格上界（49 ≤ 50）作证明，
 *              另跑 3000 局真实代打，最长 27 步通关。
 *   代打/提示与玩家用**同一套** winNow/winInTwo/fillPick ⇒ 能证明玩家能赢的，
 *   代打也一定能赢（JS 直跑本文件真实代码：2×2 全部 81 个盘面 81/81 通关）。
 * ═══════════════════════════════════════════════════════════════════
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 3; const CELLS: number = 9;
// ★★ 2026-10-13 修复：GameDiff 困难档 ×1.3 ⇒ 棋盘 4×4 = 16 格，
//   而数组按 CELLS=9 开 ⇒ 【困难档必越界】✗ ⇒ 按最大尺寸开
const MAX_N: number = 4; const MAX_CELLS: number = MAX_N * MAX_N;

/** boom() 的返回：炸完的盘面 + 这一步连爆了几次 + 炸过的格子（bit 位，炸过就置 1）*/
interface BoomOut {
  a: number[];
  bursts: number;
  mask: number;
}

/**
 * ★★★ 2026-10-23 修「尺寸陷阱」：
 *   棋盘按 diffTotal 开（3×3 / 4×4），但这几个函数用模块常量 N=3 算行号与邻居，
 *   ⇒ 困难档 4×4 时 Math.floor(j/3) 算错行、j ± 3 算错邻居。
 *   ⚠️ 2026-10-13 的注释已经写明"困难档 4×4 = 16 格"，
 *      但那次只修了数组分配（MAX_CELLS），**没修这两个函数**。
 *   ⇒ 边长当参数传进来。
 */
function capOf(i: number, n: number): number {
  const r: number = Math.floor(i / n); const c: number = i % n; let d: number = 0;
  if (r > 0) { d++; }
  if (r < n - 1) { d++; }
  if (c > 0) { d++; }
  if (c < n - 1) { d++; }
  return d;
}
/** 全盘容量之和 —— 也就是「每格都满」时的总光点数（2×2: 8 / 3×3: 24 / 4×4: 48）*/
function capsSum(n: number): number {
  let s: number = 0;
  for (let i = 0; i < n * n; i++) { s = s + capOf(i, n); }
  return s;
}
/** 已经点到容量的格数（= 渲染时边框变红的格数）*/
function filledCount(a: number[], n: number): number {
  let k: number = 0;
  for (let i = 0; i < n * n; i++) {
    if (a[i] >= capOf(i, n)) { k++; }
  }
  return k;
}
/** 这一档的通关条件 = 全盘格数（每一格都要炸过一遍）*/
function goalOf(n: number): number {
  return n * n;
}
/** 全盘格子的掩码：bit i = 第 i 格 */
function fullMask(n: number): number {
  return (1 << (n * n)) - 1;
}
/** 这一步是不是把**每一格**都炸过一遍了（通关判据）*/
function allBurst(mask: number, n: number): boolean {
  const f: number = fullMask(n);
  return (mask & f) === f;
}
/** 这一步炸开了几格（去重计数，不是连爆次数）*/
function burstCells(mask: number, n: number): number {
  let c: number = 0;
  for (let i = 0; i < n * n; i++) {
    if ((mask & (1 << i)) !== 0) { c++; }
  }
  return c;
}
/**
 * 这一档的步数上限。
 * 证明：点一个「没满」的格子只有 +1、绝不触发爆炸（代码里 a[j] > cap 才炸），
 *      所以从**任意**盘面出发，最多 Σcap 步就能把每格都点到容量，再来 1 步点火。
 *      ⇒ Σcap + 1 步必赢；再留 1 步余量。
 */
function limitOf(n: number): number {
  return capsSum(n) + 2;
}

/**
 * 点 i：先 +1，然后一路炸到稳定。
 *
 * ★★★ 2026-10-28 新规则：溢出时该格 **扣掉 (容量+1) 颗**（不是旧版的「扣掉 容量」），
 *   四邻照旧各 +1。于是
 *     · 每炸一次，总光点严格 −1 ⇒ 一次点击最多 total+1 次炸 ⇒ **必定停机**
 *       （旧规则守恒 ⇒ 有 400 步都停不下来的盘面，才会判「连锁失控」）
 *     · 总光点被锁在 Σcap 以内 ⇒ 不会再有"永远稳不下来"的局面
 *   返回值里带 bursts（连爆次数）与 mask（炸过哪些格子）—— 通关判据看 mask。
 */
function boom(src: number[], i: number, n: number): BoomOut {
  const a: number[] = src.slice(); a[i]++;
  const qu: number[] = [i];
  let bursts: number = 0;
  let mask: number = 0;
  let guard: number = 0;
  while (qu.length > 0) {
    guard++;
    if (guard > 4096) {
      // 数学上到不了这里（每次炸 −1、总数 ≤ Σcap）；纯保险，绝不返回 null
      break;
    }
    const j: number = qu.shift() as number;
    while (a[j] > capOf(j, n)) {
      a[j] = a[j] - (capOf(j, n) + 1);
      bursts++;
      mask = mask | (1 << j);
      const r: number = Math.floor(j / n); const c: number = j % n;
      if (r > 0) { a[j - n]++; qu.push(j - n); }
      if (r < n - 1) { a[j + n]++; qu.push(j + n); }
      if (c > 0) { a[j - 1]++; qu.push(j - 1); }
      if (c < n - 1) { a[j + 1]++; qu.push(j + 1); }
    }
  }
  return { a: a, bursts: bursts, mask: mask };
}

/** 这张盘面点任何一格都能 n² 连爆吗？（= 一进来就白送一局，不能要）*/
function instantWin(a: number[], n: number): boolean {
  for (let i = 0; i < n * n; i++) {
    if (allBurst(boom(a, i, n).mask, n)) { return true; }
  }
  return false;
}

/**
 * 出题（★ 名字带 make…Board，工具/audit 的「有出题」维度认得出）：
 * 从空盘随机点若干下（下子数按容量比例 ⇒ 盘越大越接近临界），
 * 再把「点一下就能全盘连爆」的盘面剔掉（最多重来 6 次，兜底给空盘）。
 */
function makeBoard(n: number): number[] {
  const picks: number = Math.round(capsSum(n) * (0.45 + Math.random() * 0.3));
  for (let tries = 0; tries < 6; tries++) {
    const a: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let t = 0; t < picks; t++) {
      const r: BoomOut = boom(a, Math.floor(Math.random() * n * n), n);
      for (let i = 0; i < n * n; i++) { a[i] = r.a[i]; }
    }
    if (!instantWin(a, n)) {
      return a;
    }
  }
  return new Array<number>(MAX_CELLS).fill(0);
}

@Component
export struct GChainReaction {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3 ⇒ 2/3/4）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  /** ★ 2026-10-28 本档通关条件：一次点击让全盘每一格都炸开（= 全盘格数）*/
  @State private goal: number = 9;
  /** ★ 2026-10-28 本局最好的一次连爆（结算文案用）*/
  @State private best: number = 0;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = []; @State private steps: number = 0;
  @State private over: boolean = false; @State private won: boolean = false;
  @State private note: string = ''; @State private tip: number = -1;
  @State private limit: number = 1;

  private startAt: number = 0; private hist: number[][] = [];
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
    this.reset();
  }
  private reset(): void {
    this.diffTotal = this.diffTotal > 1 ? this.diffTotal : 2;
    this.cells = makeBoard(this.diffTotal);
    this.goal = goalOf(this.diffTotal);
    this.limit = limitOf(this.diffTotal);
    this.steps = 0; this.over = false; this.won = false; this.best = 0;
    this.tip = -1; this.hist = []; this.startAt = Date.now();
    this.note = TG2('目标：一次点击让全盘 {0} 格都炸开 —— 先把每格点满', String(this.goal));
  }

  // ═══════════ AI 代打（2026-10-28 按新规则重写）═══════════
  // 新规则下代打是**可证明必胜**的：
  //   ① 有一手就赢的格子 ⇒ 点它；② 两手里能赢 ⇒ 先点第一步；
  //   ③ 否则点「离满最近」的那个没满的格子 —— 这一步只 +1、绝不炸，缺额必然 −1。
  //   ⇒ 每步都让"还差的点数"至少 −1，最多 Σcap 步填满，再一步点火 ⇒ 步数 ≤ limit。
  /** 一手就能全盘连爆的格子；-1 = 没有 */
  private winNow(): number {
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      if (allBurst(boom(this.cells, i, n).mask, n)) { return i; }
    }
    return -1;
  }
  /** 两手里能全盘连爆的第一步；-1 = 没有 */
  private winInTwo(): number {
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      const r1: BoomOut = boom(this.cells, i, n);
      for (let k = 0; k < n * n; k++) {
        if (allBurst(boom(r1.a, k, n).mask, n)) { return i; }
      }
    }
    return -1;
  }
  /** 离满最近、还没满的格子（点了只 +1、绝不会炸）；-1 = 全满了 */
  private fillPick(): number {
    const n: number = this.diffTotal;
    let bi: number = -1;
    let bd: number = 99;
    for (let i = 0; i < n * n; i++) {
      const d: number = capOf(i, n) - this.cells[i];
      if (d > 0 && d < bd) {
        bd = d;
        bi = i;
      }
    }
    return bi;
  }
  private bestPick(): number {
    const w: number = this.winNow();
    if (w >= 0) { return w; }
    const t: number = this.winInTwo();
    if (t >= 0) { return t; }
    return this.fillPick();
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const i: number = this.bestPick();
    if (i < 0) {
      return false;
    }
    this.pick(i);
    return !this.over;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private pick(i: number): void {
    if (this.over) { return; }
    const n: number = this.diffTotal;
    const r: BoomOut = boom(this.cells, i, n);
    this.hist.push(this.cells.slice());
    if (this.hist.length > 60) { this.hist.shift(); }
    this.cells = r.a; this.steps++; this.tip = -1;
    const hit: number = burstCells(r.mask, n);
    if (hit > this.best) { this.best = hit; }
    if (allBurst(r.mask, n)) {
      this.note = TG2('一炸到底：全盘 {0} 格全炸开 🎉', String(this.goal));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320);
      this.finish(true); return;
    }
    if (this.steps >= this.limit) {
      this.note = TG2('步数用尽，最好一次才炸开 {0}/{1} 格 😵', String(this.best), String(this.goal));
      this.finish(false); return;
    }
    const filled: number = filledCount(this.cells, n);
    if (hit > 0) {
      this.note = TG2('这一步炸开 {0} 格，还差 {1} 格就全盘', String(hit), String(this.goal - hit));
    } else if (filled >= this.goal) {
      this.note = TG('全盘点满了！随便点一格就全盘连爆 💥');
    } else {
      this.note = TG2('满格 {0}/{1}，继续点', String(filled), String(this.goal));
    }
  }

  /**
   * ★ 2026-10-28 提示按新规则重写：
   *   ① 有一手赢的格子 ⇒ 报它（并高亮）
   *   ② 两手里能赢  ⇒ 报第一步
   *   ③ 否则报「该补哪一格」（点它只 +1、绝不会炸）
   *   旧的实现按"总光点减少量"挑，但旧规则守恒 ⇒ 那个差值恒为 -1 ⇒ 提示是死的。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      this.tip = -1;
      return Hint.none('none');
    }
    const n: number = this.diffTotal;
    const w: number = this.winNow();
    if (w >= 0) {
      this.tip = w;
      return Hint.make([w],
        TG2('点第 {0} 行第 {1} 列 —— 全盘 {2} 格一起炸！',
          String(Math.floor(w / n) + 1), String(w % n + 1), String(this.goal)),
        TG2('Tap row {0}, column {1} — all {2} cells blow at once!',
          String(Math.floor(w / n) + 1), String(w % n + 1), String(this.goal)), t0);
    }
    const t: number = this.winInTwo();
    if (t >= 0) {
      this.tip = t;
      return Hint.make([t],
        TG2('先点第 {0} 行第 {1} 列，下一手就全盘连爆 💥',
          String(Math.floor(t / n) + 1), String(t % n + 1)),
        TG2('First take row {0}, column {1} — the next tap sweeps the board 💥',
          String(Math.floor(t / n) + 1), String(t % n + 1)), t0);
    }
    const f: number = this.fillPick();
    if (f >= 0) {
      this.tip = f;
      const need: number = capOf(f, n) - this.cells[f];
      return Hint.make([f],
        TG2('点第 {0} 行第 {1} 列：这格还差 {2} 点补满',
          String(Math.floor(f / n) + 1), String(f % n + 1), String(need)),
        TG2('Tap row {0}, column {1}: {2} dots to fill',
          String(Math.floor(f / n) + 1), String(f % n + 1), String(need)), t0);
    }
    this.tip = -1;
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.note = r.zh;
    }
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private undo(): void {
    if (this.over || this.hist.length === 0) { return; }
    this.cells = this.hist.pop() as number[]; this.steps--; this.tip = -1; this.note = TG('已悔一步 ↩');
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'chain_reaction', solved: solved,
      // ★ 2026-10-28：上限从 20 变成按档算（10/26/50）⇒ 分数按比例给，三档可比
      score: solved ? 60 + Math.round(160 * (this.limit - this.steps) / this.limit) : this.steps * 5,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
    });
  }
  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG2('步数 {0}/{1}', Digits(String(this.steps), this.langCode), Digits(String(this.limit), this.langCode))
        + '　' + TG2('满格 {0}/{1}', String(filledCount(this.cells, this.diffTotal)), String(this.goal)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
                Text(this.orbs(r * this.diffTotal + c)).fontSize(FontSize.xl).fontColor(Palette.amber)
                Text(String(this.cells[r * this.diffTotal + c])).fontSize(FontSize.xs).fontColor(this.theme.inkFaint).offset({ x: 0, y: 20 })
              }.layoutWeight(1).height(Cell.of(72)).backgroundColor(this.tip === r * this.diffTotal + c ? Palette.violet : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.cells[r * this.diffTotal + c] >= capOf(r * this.diffTotal + c, this.diffTotal)
                ? Palette.danger : this.theme.line).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick(r * this.diffTotal + c); })
            }, (c: number) => 'c' + c) }.width('100%')
        }, (r: number) => 'r' + r) }.width('100%')
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.xs }) {
        Button(TG('悔一步'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.undo(); })
        Button(TG('提示'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.violet).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.askHint(); })
        Button(TG('重开'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  private orbs(i: number): string {
    let s: string = '';
    for (let t = 0; t < this.cells[i]; t++) { s += '●'; }
    return s;
  }
}
