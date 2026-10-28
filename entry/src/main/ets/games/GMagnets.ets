/**
 * 磁铁（Magnets）—— 4×4 / 8 组磁铁 🧲
 *
 * 棋盘被切成 8 组「横着相邻的两格」= 一块磁铁的两端。
 * 规则：每块磁铁一端是正极 ＋、另一端是负极 －（不能两端同极）；
 *       最右一列数字 = 该行正极的个数，最下一行数字 = 该列正极的个数。
 * 玩法：点格子循环切换 空 → ＋ → － → 空。
 * 胜负：8 块磁铁都成一正一负 且 行列正极数全部对上 ⇒ 通关；步数用尽 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const CELLS: number = N * N;
/** 8 块磁铁最省也要 8×3=24 下（＋ 一下、－ 两下）⇒ 上限给足，别让手滑的人赢不了 */
const MAX_MOVES: number = 60;
const PLUS: number = 1;
const MINUS: number = 2;
const CLUE_W: number = 44;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GMagnets {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private marks: number[] = new Array<number>(CELLS).fill(0);
  @State private rowClue: number[] = new Array<number>(N).fill(0);
  @State private colClue: number[] = new Array<number>(N).fill(0);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点格子切换 空 → ＋ → －');

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

  /** 每块磁铁的两端下标 */
  private dominoA(r: number, d: number): number {
    return r * N + d * 2;
  }

  private reset(): void {
    const sol: number[] = new Array<number>(CELLS).fill(0);
    const rc: number[] = new Array<number>(N).fill(0);
    const cc: number[] = new Array<number>(N).fill(0);
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const b: number = a + 1;
        if (Math.random() < 0.5) {
          sol[a] = PLUS;
          sol[b] = MINUS;
        } else {
          sol[a] = MINUS;
          sol[b] = PLUS;
        }
      }
    }
    for (let i = 0; i < CELLS; i++) {
      if (sol[i] === PLUS) {
        rc[Math.floor(i / N)]++;
        cc[i % N]++;
      }
    }
    this.rowClue = rc;
    this.colClue = cc;
    this.marks = new Array<number>(CELLS).fill(0);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点格子切换 空 → ＋ → －');
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private plusInRow(r: number): number {
    let n: number = 0;
    for (let c = 0; c < N; c++) {
      if (this.marks[r * N + c] === PLUS) {
        n++;
      }
    }
    return n;
  }

  private plusInCol(c: number): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      if (this.marks[r * N + c] === PLUS) {
        n++;
      }
    }
    return n;
  }

  private dominoesOk(): boolean {
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const b: number = a + 1;
        const x: number = this.marks[a];
        const y: number = this.marks[b];
        if (x === 0 || y === 0 || x === y) {
          return false;
        }
      }
    }
    return true;
  }

  private linesOk(): boolean {
    for (let r = 0; r < N; r++) {
      if (this.plusInRow(r) !== this.rowClue[r]) {
        return false;
      }
    }
    for (let c = 0; c < N; c++) {
      if (this.plusInCol(c) !== this.colClue[c]) {
        return false;
      }
    }
    return true;
  }

  private placed(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.marks[i] !== 0) {
        n++;
      }
    }
    return n;
  }

  private goodDominoes(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const x: number = this.marks[a];
        const y: number = this.marks[a + 1];
        if (x !== 0 && y !== 0 && x !== y) {
          n++;
        }
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
      gameId: 'magnets',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : this.goodDominoes() * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.goodDominoes()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    if (this.dominoesOk() && this.linesOk()) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 磁铁成对、行列正极数全对，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    this.tip = TG2('磁铁成对 {0}/8', String(this.goodDominoes()));
  }

  // ═══════════ 磁铁求解器（2026-10-24 第三期）═══════════
  // 4×4 = 8 对磁铁，每对两种朝向 ⇒ 最多 256 种组合，DFS 秒出。
  // 有了它：提示能兜底，代打能一路做到通关。

  private magDfs(k: number, marks: number[], rowHave: number[], colHave: number[]): boolean {
    if (k >= 2 * N) {
      for (let r = 0; r < N; r++) {
        if (rowHave[r] !== this.rowClue[r]) {
          return false;
        }
      }
      for (let c = 0; c < N; c++) {
        if (colHave[c] !== this.colClue[c]) {
          return false;
        }
      }
      return true;
    }
    const r: number = Math.floor(k / 2);
    const a: number = this.dominoA(r, k % 2);
    const b: number = a + 1;
    // 朝向一：a = ＋，b = －
    if (rowHave[r] + 1 <= this.rowClue[r] && colHave[a % N] + 1 <= this.colClue[a % N]) {
      marks[a] = PLUS;
      marks[b] = MINUS;
      rowHave[r]++;
      colHave[a % N]++;
      if (this.magDfs(k + 1, marks, rowHave, colHave)) {
        return true;
      }
      rowHave[r]--;
      colHave[a % N]--;
      marks[a] = 0;
      marks[b] = 0;
    }
    // 朝向二：a = －，b = ＋
    if (rowHave[r] + 1 <= this.rowClue[r] && colHave[b % N] + 1 <= this.colClue[b % N]) {
      marks[a] = MINUS;
      marks[b] = PLUS;
      rowHave[r]++;
      colHave[b % N]++;
      if (this.magDfs(k + 1, marks, rowHave, colHave)) {
        return true;
      }
      rowHave[r]--;
      colHave[b % N]--;
      marks[a] = 0;
      marks[b] = 0;
    }
    return false;
  }

  /** 求一个完整解；无解返回空数组 */
  private solveMagnets(): number[] {
    const marks: number[] = new Array<number>(CELLS).fill(0);
    const rowHave: number[] = new Array<number>(N).fill(0);
    const colHave: number[] = new Array<number>(N).fill(0);
    if (!this.magDfs(0, marks, rowHave, colHave)) {
      return [];
    }
    return marks;
  }

  /**
   * ★ 2026-10-23 第二期：磁铁提示（计数法第 6 次复用）
   *
   * 判据（见 linesOk）：每行每列的 ＋ 数量必须正好等于该行/列的数字。
   * ⇒ 若某行"还缺的＋数"正好等于"这行的空格数" ⇒ 那些空格必须全填＋。
   *    列同理。
   *
   * 只推「必须是＋」，不推「必须是−」（这款只有三种状态，宁可少给）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    // 按行找
    for (let r = 0; r < N; r++) {
      let have: number = 0;
      let empty: number = 0;
      let last: number = -1;
      for (let c = 0; c < N; c++) {
        const v: number = this.marks[r * N + c];
        if (v === PLUS) {
          have++;
        } else if (v === 0) {
          empty++;
          last = r * N + c;
        }
      }
      const need: number = this.rowClue[r] - have;
      // ★ 2026-10-24 补：还要看**列**。填这个＋会让它所在列也多一个＋，
      //   若那一列已经满了 ⇒ 填了就是违规（单测 3017 组里 1274 例）。
      const lastCol: number = last % N;
      const colFull: boolean = this.plusInCol(lastCol) >= this.colClue[lastCol];
      if (need > 0 && empty > 0 && need === empty && last >= 0 && !colFull) {
        const rr: number = r + 1;
        const cc: number = (last % N) + 1;
        return Hint.make([last],
          TG2('第 {0} 行第 {1} 列必须填＋ —— 这一行还缺 {2} 个＋，正好只剩 {2} 个空格',
            String(rr), String(cc), String(need)),
          TG2('Row {0}, column {1} must be + — this row still needs {2}, exactly the empty cells left',
            String(rr), String(cc), String(need)), t0);
      }
    }
    // 按列找
    for (let c = 0; c < N; c++) {
      let have: number = 0;
      let empty: number = 0;
      let last: number = -1;
      for (let r = 0; r < N; r++) {
        const v: number = this.marks[r * N + c];
        if (v === PLUS) {
          have++;
        } else if (v === 0) {
          empty++;
          last = r * N + c;
        }
      }
      const need: number = this.colClue[c] - have;
      const lastRow: number = Math.floor(last / N);
      const rowFull: boolean = this.plusInRow(lastRow) >= this.rowClue[lastRow];
      if (need > 0 && empty > 0 && need === empty && last >= 0 && !rowFull) {
        const rr: number = Math.floor(last / N) + 1;
        const cc: number = c + 1;
        return Hint.make([last],
          TG2('第 {0} 行第 {1} 列必须填＋ —— 这一列还缺 {2} 个＋，正好只剩 {2} 个空格',
            String(rr), String(cc), String(need)),
          TG2('Row {0}, column {1} must be + — this column still needs {2}, exactly the empty cells left',
            String(rr), String(cc), String(need)), t0);
      }
    }
    // ★ 2026-10-24 第三期：计数规则找不到时，用求解器兜底
    const sol: number[] = this.solveMagnets();
    if (sol.length > 0) {
      for (let i = 0; i < CELLS; i++) {
        if (sol[i] !== 0 && this.marks[i] !== sol[i]) {
          const r: number = Math.floor(i / N) + 1;
          const c: number = (i % N) + 1;
          const want: string = sol[i] === PLUS ? '＋' : '－';
          return Hint.make([i],
            TG2('第 {0} 行第 {1} 列应该是 {2}（求解器算出来的完整解）',
              String(r), String(c), want),
            TG2('Row {0}, column {1} should be {2} (full solution)', String(r), String(c), want), t0);
        }
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第三期：AI 代打（磁铁，一次点一格）
   * 用求解器算出完整解，然后一格一格点到位（tap 是 空→＋→－ 循环）。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    const sol: number[] = this.solveMagnets();
    if (sol.length === 0) {
      return false;
    }
    for (let i = 0; i < CELLS; i++) {
      if (sol[i] !== 0 && this.marks[i] !== sol[i]) {
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须填＋'));
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const nm: number[] = this.marks.slice();
    nm[i] = (nm[i] + 1) % 3;
    this.marks = nm;
    this.moves++;
    this.check();
  }

  build() {
    Column({ space: Space.md }) {
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
        Text((TG('成对磁铁'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.goodDominoes()) + '/8')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已定格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Text(this.marks[(r * N + c)] === PLUS ? '＋' : (this.marks[(r * N + c)] === MINUS ? '－' : ''))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.marks[(r * N + c)] === PLUS ? Palette.rose : Palette.sky)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.marks[(r * N + c)] === PLUS ? '#33F43F5E' : (this.marks[(r * N + c)] === MINUS ? '#330EA5E9' : this.theme.surface))
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'mc' + r + '-' + c)
            Column({ space: 1 }) {
            Text(String(this.rowClue[(r)]) + '＋')
            .fontSize(FontSize.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.plusInRow((r)) === this.rowClue[(r)] ? Palette.emerald : this.theme.inkSoft)
            Text(TG2('现 {0}', String(this.plusInRow((r)))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(CLUE_W)
            .height(CLUE_W)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.xs)
          }
          .width('100%')
        }, (r: number) => 'mr' + r)

        Row({ space: Space.xs }) {
          ForEach(this.rows, (c: number) => {
            Column({ space: 1 }) {
            Text(String(this.colClue[(c)]) + '＋')
            .fontSize(FontSize.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.plusInCol((c)) === this.colClue[(c)] ? Palette.emerald : this.theme.inkSoft)
            Text(TG2('现 {0}', String(this.plusInCol((c)))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.xs)
          }, (c: number) => 'mq' + c)
          Row().width(CLUE_W).height(CLUE_W)
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG('每块磁铁（横向两格）必须一正一负；右侧/下方数字是该行该列 ＋ 的个数'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)

      Row({ space: Space.sm }) {
        Button(TG('提示'))

          .fontSize(FontSize.sm)

          .fontColor(this.theme.ink)

          .backgroundColor(this.theme.surfaceAlt)

          .borderRadius(Radius.md)

          // ★ 2026-10-24 修（同一个坑第二次）：Column 的直接子元素不能用 layoutWeight 当宽度
          .layoutWeight(1)
          .height(46)


          .onClick(() => {

            this.askHint();

          })

        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))

          .layoutWeight(1)

          .height(46)

          .onClick(() => {

            this.askAuto();

          })

        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.rose)
          .borderRadius(Radius.md)
          .layoutWeight(1)
      }
      .layoutWeight(1)
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
