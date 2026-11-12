/**
 * 数谜（Kakuro）—— 4×4 十字盘 ❓
 *
 * 盘面（B = 黑格提示位，W = 白格）：
 *      B   B↓  B↓  B
 *      B→  W   W   W
 *      B   W   ※   W
 *      B→  W   W   W
 * 规则：白格填 1~9；每条「横串 / 竖串」内数字互不相同，且和等于串首提示数。
 * 胜负：四条串全部满足 ⇒ 通关（solved=true）；步数用尽 ⇒ 失败（solved=false）。
 */

import { Bp } from '../core/Bp';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { DemoBar } from '../components/DemoBar';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const CELLS: number = N * N;
/** 白格下标（r*4+c）—— 中间十字形 */
const WHITE: number[] = [5, 6, 7, 9, 11, 13, 14, 15];
/** 四条串：两条横、两条竖，每条 3 格 */
const H_RUNS: number[][] = [[5, 6, 7], [13, 14, 15]];
const V_RUNS: number[][] = [[5, 9, 13], [7, 11, 15]];
/** 提示格：横串提示写在串首左边，竖串提示写在串首上面 */
const H_CLUE_AT: number[] = [4, 12];
const V_CLUE_AT: number[] = [1, 3];
const RUNS: number = 4;
const MAX_MOVES: number = 30;
const K1: number[] = [1, 2, 3, 4, 5];
const K2: number[] = [6, 7, 8, 9];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GKakuro {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  /** 出题时的完整解 */

  private solCells: number[] = [];
  /** ★ 2026-11-08 代打算出来的解（不依赖出题解）；空 = 未算 */
  private autoSol: number[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/

  @State private tvFocus: string = '';

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用

  @State private vals: number[] = new Array<number>(CELLS).fill(0);
  @State private rowClue: number[] = new Array<number>(CELLS).fill(0);
  @State private colClue: number[] = new Array<number>(CELLS).fill(0);
  @State private sel: number = 5;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点一个白格，再点下面数字填入');

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);
  private k1: number[] = K1;
  private k2: number[] = K2;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKakuro')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  // ── 串的判定 ──

  private isWhite(i: number): boolean {
    return WHITE.indexOf(i) >= 0;
  }

  private runSum(v: number[], run: number[]): number {
    let s: number = 0;
    for (let i = 0; i < run.length; i++) {
      s += v[run[i]];
    }
    return s;
  }

  private runDistinct(v: number[], run: number[]): boolean {
    const seen: number[] = [];
    for (let i = 0; i < run.length; i++) {
      const d: number = v[run[i]];
      if (seen.indexOf(d) >= 0) {
        return false;
      }
      seen.push(d);
    }
    return true;
  }

  private runOk(v: number[], run: number[], clue: number): boolean {
    const seen: number[] = [];
    for (let i = 0; i < run.length; i++) {
      const d: number = v[run[i]];
      if (d === 0 || seen.indexOf(d) >= 0) {
        return false;
      }
      seen.push(d);
    }
    return this.runSum(v, run) === clue;
  }

  private doneRuns(): number {
    let n: number = 0;
    for (let i = 0; i < H_RUNS.length; i++) {
      if (this.runOk(this.vals, H_RUNS[i], this.rowClue[H_CLUE_AT[i]])) {
        n++;
      }
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      if (this.runOk(this.vals, V_RUNS[i], this.colClue[V_CLUE_AT[i]])) {
        n++;
      }
    }
    return n;
  }

  private filled(): number {
    let n: number = 0;
    for (let i = 0; i < WHITE.length; i++) {
      if (this.vals[WHITE[i]] !== 0) {
        n++;
      }
    }
    return n;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'kakuro',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.moves * 20) : this.doneRuns() * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneRuns()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ── 出题：先造一组合法解，再取行/列和当提示 ──

  private reset(): void {
    const sol: number[] = new Array<number>(CELLS).fill(0);
    let tries: number = 0;
    let good: boolean = false;
    while (tries < 500 && !good) {
      tries++;
      for (let i = 0; i < WHITE.length; i++) {
        sol[WHITE[i]] = 1 + Math.floor(Math.random() * 9);
      }
      good = true;
      for (let i = 0; i < H_RUNS.length; i++) {
        if (!this.runDistinct(sol, H_RUNS[i])) {
          good = false;
        }
      }
      for (let i = 0; i < V_RUNS.length; i++) {
        if (!this.runDistinct(sol, V_RUNS[i])) {
          good = false;
        }
      }
    }

    const rc: number[] = new Array<number>(CELLS).fill(0);
    const cc: number[] = new Array<number>(CELLS).fill(0);
    for (let i = 0; i < H_RUNS.length; i++) {
      rc[H_CLUE_AT[i]] = this.runSum(sol, H_RUNS[i]);
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      cc[V_CLUE_AT[i]] = this.runSum(sol, V_RUNS[i]);
    }

    this.rowClue = rc;
    this.colClue = cc;
    // ★ 出题时的完整解留着（提示兜底 + 代打）
    this.solCells = sol.slice();
    this.autoSol = [];   // ★ 新题：代打解作废
    this.vals = new Array<number>(CELLS).fill(0);
    this.sel = WHITE[0];
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点一个白格，再点下面数字填入');
    this.startAt = Date.now();
  }

  // ── 输入 ──

  private setVal(i: number, v: number): void {
    const n: number[] = this.vals.slice();
    n[i] = v;
    this.vals = n;
  }

  private advance(): void {
    const pos: number = WHITE.indexOf(this.sel);
    for (let k = 1; k <= WHITE.length; k++) {
      const i: number = WHITE[(pos + k) % WHITE.length];
      if (this.vals[i] === 0) {
        this.sel = i;
        return;
      }
    }
    this.sel = WHITE[(pos + 1) % WHITE.length];
  }
  // ═══════════ 提示 + 代打（2026-10-24 第三期）═══════════
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let i = 0; i < CELLS; i++) {
      if (this.vals[i] === 0 && this.solCells[i] > 0) {
        const r: number = Math.floor(i / N) + 1;
        const c: number = (i % N) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列应该填 {2}', String(r), String(c), String(this.solCells[i])),
          TG2('Row {0}, column {1} should be {2}', String(r), String(c), String(this.solCells[i])), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一局暂时给不出提示'));
  }

  /** ★ AI 代打：用出题时的完整解，一格一格填 */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01）
  // ★ 旧版 `demoStep()` 一个 tick 直接 `autoStep()`，匀速连发 ⇒ 玩家看不出在演什么。
  // ★ 新版三拍：引导(720) → 执行(280) → 结果(1150)，3 轮 ≈ 6.5 秒。
  // ★ 引导拍的文案用**本游戏自己的 computeHint()** —— 它本来就知道该指哪里。
  // ★ 演示期间按钮置灰（本页 demoId 直传），结束后 reset 回干净开局。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.reset();
  }

  private demoStop(): void {
    this.demoFinish();
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    // ★ 2026-11-08（ai-fixer-a）**不再抄出题解 solCells**：用「每段数字不重复 + 和等于提示」
    //   现场回溯求解，再走一步。
    if (this.autoSol.length !== CELLS) {
      this.autoSol = this.solveKakuro();
    }
    if (this.autoSol.length !== CELLS) {
      return false;
    }
    for (let i = 0; i < CELLS; i++) {
      if (this.vals[i] !== this.autoSol[i]) {
        this.sel = i;
        this.put(this.autoSol[i]);
        return !this.over;
      }
    }
    return false;
  }

  /** ★ 2026-11-08 代打求解：只用盘面线索（不读 solCells） */
  private solveKakuro(): number[] {
    const board: number[] = new Array<number>(CELLS).fill(0);
    const ok: boolean = this.krFill(board, 0);
    return ok ? board : [];
  }

  private krFill(board: number[], w: number): boolean {
    if (w >= WHITE.length) {
      return this.krAllOk(board);
    }
    const idx: number = WHITE[w];
    for (let v = 1; v <= 9; v++) {
      board[idx] = v;
      if (this.krPartialOk(board) && this.krFill(board, w + 1)) {
        return true;
      }
      board[idx] = 0;
    }
    return false;
  }

  /** 部分可行：每段已填的数不重复、和 ≤ 线索；填满的段必须正好等于线索 */
  private krPartialOk(board: number[]): boolean {
    for (let i = 0; i < H_RUNS.length; i++) {
      if (!this.krRunOk(board, H_RUNS[i], this.rowClue[H_CLUE_AT[i]])) {
        return false;
      }
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      if (!this.krRunOk(board, V_RUNS[i], this.colClue[V_CLUE_AT[i]])) {
        return false;
      }
    }
    return true;
  }

  private krRunOk(board: number[], run: number[], clue: number): boolean {
    let sum: number = 0;
    let filled: number = 0;
    for (let k = 0; k < run.length; k++) {
      const v: number = board[run[k]];
      if (v > 0) {
        sum = sum + v;
        filled = filled + 1;
      }
    }
    if (sum > clue) {
      return false;
    }
    for (let a = 0; a < run.length; a++) {
      const va: number = board[run[a]];
      if (va === 0) {
        continue;
      }
      for (let b = a + 1; b < run.length; b++) {
        if (board[run[b]] === va) {
          return false;
        }
      }
    }
    return filled < run.length || sum === clue;
  }

  private krAllOk(board: number[]): boolean {
    for (let i = 0; i < H_RUNS.length; i++) {
      if (!this.runDistinct(board, H_RUNS[i]) || this.runSum(board, H_RUNS[i]) !== this.rowClue[H_CLUE_AT[i]]) {
        return false;
      }
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      if (!this.runDistinct(board, V_RUNS[i]) || this.runSum(board, V_RUNS[i]) !== this.colClue[V_CLUE_AT[i]]) {
        return false;
      }
    }
    return true;
  }

  private askAuto(): void {
    if (LanRace.isRacing()) { return; }   // 联机禁用（奥森硬约束）
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }


  private put(d: number): void {
    if (this.over || !this.isWhite(this.sel)) {
      return;
    }
    this.setVal(this.sel, d);
    this.moves++;
    this.advance();
    this.check();
  }

  private clearSel(): void {
    if (this.over || !this.isWhite(this.sel)) {
      return;
    }
    this.setVal(this.sel, 0);
    this.moves++;
    this.check();
  }

  private tapCell(i: number): void {
    if (this.over || !this.isWhite(i)) {
      return;
    }
    if (this.sel === i) {
      this.setVal(i, 0);
      this.moves++;
      this.check();
      return;
    }
    this.sel = i;
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const done: number = this.doneRuns();
    if (done === RUNS) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 四条串全对，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true; this.won = false;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    this.tip = TG2('已完成 {0} / {1} 条串', String(done),Digits(String(RUNS), this.langCode));
  }

  build() {
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
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
        Text((TG('完成串'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneRuns()) + '/' + String(RUNS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filled()) + '/' + String(WHITE.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              if (this.isWhite((r * N + c))) {
              Stack() {
              Text(this.vals[((r * N + c))] === 0 ? '' : String(this.vals[((r * N + c))]))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.sel === ((r * N + c)) ? Palette.tint('22') : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({ width: this.sel === ((r * N + c)) ? 2 : 1, color: this.sel === ((r * N + c)) ? Palette.primary : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .onFocus(() => { this.tvFocus = 'L501'; })
              .onBlur(() => { if (this.tvFocus === 'L501') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L501', Radius.xs))
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell(((r * N + c))); }); })
              .onClick(() => {
              Haptics.tick();
              this.tapCell(((r * N + c)));
              })
              } else {
              Column({ space: 1 }) {
              Text(this.colClue[((r * N + c))] > 0 ? '↓' + String(this.colClue[((r * N + c))]) : '')
              .fontSize(FontSize.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.teal)
              Text(this.rowClue[((r * N + c))] > 0 ? String(this.rowClue[((r * N + c))]) + '→' : '')
              .fontSize(FontSize.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.teal)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.theme.line)
              .borderRadius(Radius.xs)
              }
            }, (c: number) => 'kc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'kr' + r)
      }
      .width('100%')
      // ★★★ 2026-11-08 **横屏按钮被挤出视口**（verifier-dev 真机实测）：
      //   本款根容器是 `Column`（无 Scroll），按钮行在棋盘之后；
      //   而棋盘是 `width('100%')` + 内部格子 `aspectRatio(1)` ⇒ **853 宽 ⇒ 813 高**
      //   ⇒ 2560×1600 下棋盘线索撑到 `y≈1593`，**「提示 / AI 代打」两个按钮被挤出视口**
      //   （dump 25 个节点里没有任何按钮，玩家和验证器都点不到）。
      //   ⇒ 按判据 1802：**约束加在「棋盘容器」上**，横屏按可用高反推。
      //   ★ 2026-11-08 第二次校准（verifier-dev 真机量）：`-260` 时棋盘 273vp，
      //     但按钮行实际 y = 1613–1727px（屏高 1600）⇒ **超出 13~127px**。
      //     再压 43vp ⇒ `-310`（棋盘 ≈230vp），按钮应落到 ≈1478–1592px（屏内）。
      .constraintSize({ maxWidth: Bp.height < 600 ? Math.min(Bp.width - 2 * Space.lg, Math.max(140, Bp.height - 360)) : 9999 })   // ★ 2026-11-12（判据 1928）：`aspectRatio(1)` 的棋盘 **`maxHeight` 只裁不缩**，必须用 `maxWidth` 才能真缩小
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .layoutWeight(1)
          .height(Cell.of(Bp.isShort() ? 34 : 38))
          // ★★★ 2026-10-31：这个「提示」按钮原来**没有 backgroundColor** ⇒
          //   用 ArkUI 平台默认色，与全项目 HintBar 的 Palette.cyan 不一致。
          .backgroundColor(Palette.cyan)
          .fontColor('#FFFFFF')
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L547'; })
          .onBlur(() => { if (this.tvFocus === 'L547') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L547'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(LanRace.isRacing() ? TG('联机禁用')
          : (this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))))
          .layoutWeight(1)
          .height(Cell.of(Bp.isShort() ? 34 : 38))
                    // ★★★ 2026-11-01 奥森硬约束：**AI 代打在联机对战中不能启用**
          //   这 16 款是自绘按钮行，HintBar 那套保护没走到它们身上
          .enabled(!LanRace.isRacing())
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L560'; })
          .onBlur(() => { if (this.tvFocus === 'L560') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L560'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
          .onClick(() => {
            this.askAuto();
          })
      }
      .width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.k1, (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(Bp.isShort() ? 34 : 40))
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L581'; })
          .onBlur(() => { if (this.tvFocus === 'L581') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L581', Radius.sm))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put((d)); }); })
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'ka' + d)
      }
      .width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.k2, (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(Bp.isShort() ? 34 : 40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L604'; })
          .onBlur(() => { if (this.tvFocus === 'L604') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L604', Radius.sm))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put((d)); }); })
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'kb' + d)
        this.delBtn()
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.berry)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.tap(44))
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L625'; })
          .onBlur(() => { if (this.tvFocus === 'L625') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L625'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }











  @Builder
  delBtn() {
    Text('⌫')
      .accessibilityText(TG('删除'))
      .fontSize(FontSize.lg)
      .fontColor(Palette.rose)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(Cell.of(Bp.isShort() ? 34 : 40))
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L665'; })
      .onBlur(() => { if (this.tvFocus === 'L665') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L665', Radius.sm))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.clearSel(); }); })
      .onClick(() => {
        Haptics.tick();
        this.clearSel();
      })
  }
}
