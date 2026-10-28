/**
 * 黑在哪（Kuromasu）—— 5×5 🧩
 *
 * 规则（三条，缺一不可）：
 *   ① 每格可涂黑或留白；带数字的格子是白格，数字 = 该格朝上下左右看出去能看见的黑格数
 *      （视线被第一个黑格挡住，不再往后数）
 *   ② 两个黑格不能上下左右相邻
 *   ③ 所有白格必须连成一片
 * 胜负：三条全部满足 ⇒ 通关；步数用尽 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const MAX_MOVES: number = 40;
const MIN_CLUES: number = 3;
const MAX_CLUES: number = 4;
const DR: number[] = [-1, 1, 0, 0];
const DC: number[] = [0, 0, -1, 1];
/** 兜底解：黑格固定在 (0,2)(2,0)(2,4)(4,2)，四个孤立点 ⇒ 白格必然连通 */
const FALLBACK_BLACK: number[] = [2, 10, 14, 22];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

function shuffled(n: number): number[] {
  const a: number[] = range(n);
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GKurodoko {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private black: boolean[] = new Array<boolean>(CELLS).fill(false);
  @State private clue: number[] = new Array<number>(CELLS).fill(0);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点格子涂黑；带数字的格子不能涂');

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  /** 解出来的目标黑格（缓存：同一题只解一次，避免每 320ms 重算） */
  private kuroSol: boolean[] = [];
  private kuroKey: string = '';

  private rowOf(i: number): number {
    return Math.floor(i / N);
  }

  private colOf(i: number): number {
    return i % N;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.rowOf(i);
    const c: number = this.colOf(i);
    if (r > 0) {
      out.push(i - N);
    }
    if (r < N - 1) {
      out.push(i + N);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < N - 1) {
      out.push(i + 1);
    }
    return out;
  }

  /** 从 i 朝四个方向看出去能看见的黑格数 */
  private vis(i: number, b: boolean[]): number {
    let n: number = 0;
    const r0: number = this.rowOf(i);
    const c0: number = this.colOf(i);
    for (let d = 0; d < 4; d++) {
      let r: number = r0;
      let c: number = c0;
      while (true) {
        r += DR[d];
        c += DC[d];
        if (r < 0 || r >= N || c < 0 || c >= N) {
          break;
        }
        if (b[r * N + c]) {
          n++;
          break;
        }
      }
    }
    return n;
  }

  /** 白格是否连成一片（BFS） */
  private connected(b: boolean[]): boolean {
    let start: number = -1;
    let whites: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (!b[i]) {
        whites++;
        if (start < 0) {
          start = i;
        }
      }
    }
    if (start < 0) {
      return true;
    }
    const seen: boolean[] = new Array<boolean>(CELLS).fill(false);
    const q: number[] = [start];
    seen[start] = true;
    let head: number = 0;
    let count: number = 1;
    while (head < q.length) {
      const cur: number = q[head];
      head++;
      const ns: number[] = this.nbrs(cur);
      for (let k = 0; k < ns.length; k++) {
        const nx: number = ns[k];
        if (!b[nx] && !seen[nx]) {
          seen[nx] = true;
          count++;
          q.push(nx);
        }
      }
    }
    return count === whites;
  }

  private noTouch(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (!this.black[i]) {
        continue;
      }
      const ns: number[] = this.nbrs(i);
      for (let k = 0; k < ns.length; k++) {
        if (ns[k] > i && this.black[ns[k]]) {
          return false;
        }
      }
    }
    return true;
  }

  private clueOk(i: number): boolean {
    return this.clue[i] === 0 || this.vis(i, this.black) === this.clue[i];
  }

  private cluesDone(): number {
    let n: number = 0;
    let total: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.clue[i] > 0) {
        total++;
        if (this.clueOk(i)) {
          n++;
        }
      }
    }
    return total === 0 ? 0 : n;
  }

  private clueTotal(): number {
    let total: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.clue[i] > 0) {
        total++;
      }
    }
    return total;
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.black[i]) {
        n++;
      }
    }
    return n;
  }

  // ── 出题：先随机造一个合法解，再把「看得见黑格」的白格标成线索 ──

  private buildClues(): number[] {
    let guard: number = 0;
    while (guard < 400) {
      guard++;
      const b: boolean[] = new Array<boolean>(CELLS).fill(false);
      for (let i = 0; i < CELLS; i++) {
        if (Math.random() < 0.34) {
          b[i] = true;
        }
      }
      for (let i = 0; i < CELLS; i++) {
        if (!b[i]) {
          continue;
        }
        const ns: number[] = this.nbrs(i);
        let bad: boolean = false;
        for (let k = 0; k < ns.length; k++) {
          if (ns[k] < i && b[ns[k]]) {
            bad = true;
          }
        }
        if (bad) {
          b[i] = false;
        }
      }
      let nb: number = 0;
      for (let i = 0; i < CELLS; i++) {
        if (b[i]) {
          nb++;
        }
      }
      if (nb < 3 || nb > 8 || !this.connected(b)) {
        continue;
      }
      const cand: number[] = [];
      for (let i = 0; i < CELLS; i++) {
        if (!b[i] && this.vis(i, b) > 0) {
          cand.push(i);
        }
      }
      if (cand.length < MIN_CLUES) {
        continue;
      }
      const perm: number[] = shuffled(cand.length);
      const cls: number[] = new Array<number>(CELLS).fill(0);
      let cnt: number = 0;
      for (let k = 0; k < perm.length && cnt < MAX_CLUES; k++) {
        const at: number = cand[perm[k]];
        cls[at] = this.vis(at, b);
        cnt++;
      }
      if (cnt >= MIN_CLUES) {
        return cls;
      }
    }
    // 兜底：固定黑格解 ⇒ 至少可玩，不会卡死
    const b2: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let i = 0; i < FALLBACK_BLACK.length; i++) {
      b2[FALLBACK_BLACK[i]] = true;
    }
    const cls2: number[] = new Array<number>(CELLS).fill(0);
    let cnt2: number = 0;
    for (let i = 0; i < CELLS && cnt2 < MAX_CLUES; i++) {
      if (!b2[i] && this.vis(i, b2) > 0) {
        cls2[i] = this.vis(i, b2);
        cnt2++;
      }
    }
    return cls2;
  }

  private reset(): void {
    this.clue = this.buildClues();
    this.black = new Array<boolean>(CELLS).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点格子涂黑；带数字的格子不能涂');
    this.startAt = Date.now();
  }

  /**
   * ★ 2026-10-23 第二期：黑在哪（Kurodoko）提示
   *
   * 规则：数字 = 从该格看出去能看见的白格数（视线被黑格挡住）；
   *       所有白格必须连通；黑格不能相邻、不能 2×2。
   *
   * 用一条严格成立的推理：
   *   **数字为 1** ⇒ 只能看见它自己 ⇒ 四个邻居必须全黑
   *
   * ⚠️ 只推「必须黑」，不推「必须白」。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let i = 0; i < CELLS; i++) {
      if (this.clue[i] !== 1 || this.black[i]) {
        continue;
      }
      const nb: number[] = this.nbrs(i);
      for (let t = 0; t < nb.length; t++) {
        const j: number = nb[t];
        if (this.black[j] || this.clue[j] > 0) {
          continue;                      // 已是黑 / 是数字格（数字格必为白）
        }
        const r: number = this.rowOf(j) + 1;
        const c: number = this.colOf(j) + 1;
        return Hint.make([j],
          TG2('第 {0} 行第 {1} 列必须变黑 —— 旁边那个「1」只能看见自己',
            String(r), String(c)),
          TG2('Row {0}, column {1} must be black — the nearby "1" can only see itself',
            String(r), String(c)), t0);
      }
    }
    // ★ 2026-10-28 补：代打解过一次后 wantBlack 就有缓存（kuroKey / kuroSol）
    //   ⇒ 这时候直接照真值报一格，别再说"看不出哪格必须变黑"。
    //   ⚠️ 只读缓存、不在这里现搜：dfsKuro 是同步 DFS，现搜可能冻界面（Hint.BUDGET 也打断不了）。
    if (this.kuroSol.length === CELLS && this.kuroKey === this.clue.join(',')) {
      for (let i = 0; i < CELLS; i++) {
        if (this.clue[i] > 0 || this.kuroSol[i] === this.black[i]) {
          continue;
        }
        const rr: number = this.rowOf(i) + 1;
        const cc: number = this.colOf(i) + 1;
        return Hint.make([i],
          this.kuroSol[i]
            ? TG2('第 {0} 行第 {1} 列要涂黑', String(rr), String(cc))
            : TG2('第 {0} 行第 {1} 列要留白', String(rr), String(cc)),
          this.kuroSol[i]
            ? TG2('Row {0}, column {1} → black', String(rr), String(cc))
            : TG2('Row {0}, column {1} → white', String(rr), String(cc)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须变黑'));
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'kurodoko',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : this.cluesDone() * 70,
      durationMs: Date.now() - this.startAt,
      levelReached: this.cluesDone()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const cl: number = this.cluesDone();
    const total: number = this.clueTotal();
    if (cl === total && this.noTouch() && this.connected(this.black)) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 线索、相邻、连通三条全对，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    if (!this.noTouch()) {
      this.tip = TG('✗ 有两个黑格挨着了');
    } else if (cl < total) {
      this.tip = TG2('线索 {0}/{1} 已满足', String(cl), String(total));
    } else if (!this.connected(this.black)) {
      this.tip = TG('✗ 白格被切断，没连成一片');
    } else {
      this.tip = TG('就差一点了');
    }
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 线索只有 3~4 条 ⇒ 直接搜一个满足三条规则的合法解（黑不相邻做剪枝）
  private dfsKuro(free: number[], k: number, b: boolean[]): boolean {
    if (k >= free.length) {
      for (let i = 0; i < CELLS; i++) {
        if (this.clue[i] > 0 && this.vis(i, b) !== this.clue[i]) {
          return false;
        }
      }
      return this.connected(b);
    }
    const i: number = free[k];
    b[i] = false;
    if (this.dfsKuro(free, k + 1, b)) {
      return true;
    }
    const nb: number[] = this.nbrs(i);
    let ok: boolean = true;
    for (let t = 0; t < nb.length; t++) {
      if (b[nb[t]]) {
        ok = false;
      }
    }
    if (ok) {
      b[i] = true;
      if (this.dfsKuro(free, k + 1, b)) {
        return true;
      }
      b[i] = false;
    }
    return false;
  }

  /** 一组合法解（true = 该格涂黑）；搜不到返回空数组 */
  private solveKuro(): boolean[] {
    const b: boolean[] = new Array<boolean>(CELLS).fill(false);
    const free: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (this.clue[i] <= 0) {
        free.push(i);
      }
    }
    if (this.dfsKuro(free, 0, b)) {
      return b;
    }
    return [];
  }

  private wantBlack(): boolean[] {
    const key: string = this.clue.join(',');
    if (this.kuroKey === key && this.kuroSol.length === CELLS) {
      return this.kuroSol;
    }
    const sol: boolean[] = this.solveKuro();
    this.kuroKey = key;
    this.kuroSol = sol;
    return sol;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const want: boolean[] = this.wantBlack();
    if (want.length !== CELLS) {
      return false;
    }
    for (let i = 0; i < CELLS; i++) {
      if (this.clue[i] > 0) {
        continue;
      }
      if (want[i] !== this.black[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
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

  private tap(i: number): void {
    if (this.over || this.clue[i] > 0) {
      return;
    }
    const nb: boolean[] = this.black.slice();
    nb[i] = !nb[i];
    this.black = nb;
    this.moves++;
    this.check();
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('线索'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.cluesDone()) + '/' + String(this.clueTotal()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rows, (c: number) => {
              Stack() {
              Text(this.clue[(r * N + c)] > 0 ? String(this.clue[(r * N + c)]) : '')
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.clueOk((r * N + c)) ? Palette.emerald : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.black[(r * N + c)] ? (this.theme.isDark ? '#0B0B0B' : '#1E293B') : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({
              width: this.clue[(r * N + c)] > 0 ? 2 : 1,
              color: this.clue[(r * N + c)] > 0 ? Palette.teal : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'dc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'dr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(TG('数字 = 从这格朝四个方向能看见的黑格数；黑格不能相邻；白格要连成一片'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)

      Button(TG('提示'))

        .fontSize(FontSize.sm)

        .fontColor(this.theme.ink)

        .backgroundColor(this.theme.surfaceAlt)

        .borderRadius(Radius.md)

        .width('100%')
        .height(46)

        .height(44)

        .onClick(() => {

          this.askHint();

        })

      
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.teal)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
