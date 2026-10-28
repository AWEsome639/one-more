/**
 * 聪明格（KenKen）—— 4×4 🧩
 *
 * 规则：每行、每列 1~4 各出现一次；每个「笼」（同色的一组格）里的数字按左上角
 *       标出的运算得到目标值（＋ − × ÷；单格笼就是那个数字本身）。
 * 胜负：行列合法 且 所有笼都满足 ⇒ 通关（solved=true）；步数用尽 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { I18n } from '../core/I18n';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const CELLS: number = N * N;
const MAX_MOVES: number = 40;
const K1: number[] = [1, 2];
const K2: number[] = [3, 4];

interface Cage {
  cells: number[];
  target: number;
  op: string;   // '' 单格 | '+' | '-' | '×' | '÷'
}

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

/** 0..n-1 洗牌 */
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

/** 半透明叠加：'#RRGGBB' + '1F' ⇒ '#1FRRGGBB' */
function tint(hex: string, alpha: string): string {
  return '#' + alpha + hex.substring(1);
}

@Component
export struct GKenken {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  /** 出题时的完整解 */

  private solCells: number[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State */

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private vals: number[] = new Array<number>(CELLS).fill(0);
  @State private cages: Cage[] = [];
  @State private sel: number = 0;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点格子，再点下面数字填入');

  private cageOf: number[] = new Array<number>(CELLS).fill(0);
  private anchor: boolean[] = new Array<boolean>(CELLS).fill(false);
  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);
  private k1: number[] = K1;
  private k2: number[] = K2;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKenken')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private row(i: number): number {
    return Math.floor(i / N);
  }

  private col(i: number): number {
    return i % N;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.row(i);
    const c: number = this.col(i);
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

  // ── 出题：随机拉丁方 + 随机分笼 ──

  private makeCage(cells: number[], sol: number[]): Cage {
    if (cells.length === 1) {
      const one: Cage = { cells: cells, target: sol[cells[0]], op: '' };
      return one;
    }
    const vs: number[] = [];
    for (let i = 0; i < cells.length; i++) {
      vs.push(sol[cells[i]]);
    }
    if (cells.length === 2) {
      const a: number = vs[0];
      const b: number = vs[1];
      const ops: string[] = ['+', '×'];
      const tg: number[] = [a + b, a * b];
      if (a !== b) {
        ops.push('-');
        tg.push(Math.abs(a - b));
      }
      const hi: number = a > b ? a : b;
      const lo: number = a > b ? b : a;
      if (hi % lo === 0) {
        ops.push('÷');
        tg.push(hi / lo);
      }
      const pick: number = Math.floor(Math.random() * ops.length);
      const two: Cage = { cells: cells, target: tg[pick], op: ops[pick] };
      return two;
    }
    let s: number = 0;
    let p: number = 1;
    for (let i = 0; i < vs.length; i++) {
      s += vs[i];
      p *= vs[i];
    }
    if (Math.random() < 0.5) {
      const plus: Cage = { cells: cells, target: s, op: '+' };
      return plus;
    }
    const times: Cage = { cells: cells, target: p, op: '×' };
    return times;
  }

  private reset(): void {
    // 1) 随机拉丁方：基方阵 (r+c)%N 上做行/列/数字三重置换
    const rp: number[] = shuffled(N);
    const cp: number[] = shuffled(N);
    const dm: number[] = shuffled(N);
    const sol: number[] = new Array<number>(CELLS).fill(0);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        sol[r * N + c] = dm[(rp[r] + cp[c]) % N] + 1;
      }
    }

    // 2) 随机分笼：按随机顺序取未用格当笼心，最多再吞 2 个相邻未用格
    const order: number[] = shuffled(CELLS);
    const used: boolean[] = new Array<boolean>(CELLS).fill(false);
    const cages: Cage[] = [];
    const cageOf: number[] = new Array<number>(CELLS).fill(0);
    const anchor: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let k = 0; k < order.length; k++) {
      const start: number = order[k];
      if (used[start]) {
        continue;
      }
      used[start] = true;
      const cells: number[] = [start];
      const want: number = 1 + Math.floor(Math.random() * 3);
      const nb: number[] = this.nbrs(start);
      const perm: number[] = shuffled(nb.length);
      for (let t = 0; t < perm.length && cells.length < want; t++) {
        const cand: number = nb[perm[t]];
        if (!used[cand]) {
          used[cand] = true;
          cells.push(cand);
        }
      }
      const ci: number = cages.length;
      for (let t = 0; t < cells.length; t++) {
        cageOf[cells[t]] = ci;
      }
      anchor[start] = true;
      cages.push(this.makeCage(cells, sol));
    }

    this.cages = cages;
    this.cageOf = cageOf;
    this.anchor = anchor;
    // ★ 出题时的完整解留着（提示兜底 + 代打）
    this.solCells = sol.slice();
    this.vals = new Array<number>(CELLS).fill(0);
    this.sel = 0;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点格子，再点下面数字填入');
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private cageValue(c: Cage): number {
    let s: number = 0;
    let p: number = 1;
    let hi: number = 0;
    let lo: number = 9;
    for (let i = 0; i < c.cells.length; i++) {
      const v: number = this.vals[c.cells[i]];
      s += v;
      p *= v;
      if (v > hi) {
        hi = v;
      }
      if (v < lo) {
        lo = v;
      }
    }
    if (c.op === '+') {
      return s;
    }
    if (c.op === '×') {
      return p;
    }
    if (c.op === '-') {
      return hi - lo;
    }
    if (c.op === '÷') {
      return lo > 0 && hi % lo === 0 ? hi / lo : -1;
    }
    return this.vals[c.cells[0]];
  }

  private cageOk(c: Cage): boolean {
    for (let i = 0; i < c.cells.length; i++) {
      if (this.vals[c.cells[i]] === 0) {
        return false;
      }
    }
    return this.cageValue(c) === c.target;
  }

  private cagesDone(): number {
    let n: number = 0;
    for (let i = 0; i < this.cages.length; i++) {
      if (this.cageOk(this.cages[i])) {
        n++;
      }
    }
    return n;
  }

  private latinOk(): boolean {
    for (let r = 0; r < N; r++) {
      const seen: number[] = [];
      for (let c = 0; c < N; c++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen.indexOf(v) >= 0) {
          return false;
        }
        seen.push(v);
      }
    }
    for (let c = 0; c < N; c++) {
      const seen: number[] = [];
      for (let r = 0; r < N; r++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen.indexOf(v) >= 0) {
          return false;
        }
        seen.push(v);
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'kenken',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : this.cagesDone() * 50,
      durationMs: Date.now() - this.startAt,
      levelReached: this.cagesDone()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ── 输入 ──

  private setVal(i: number, v: number): void {
    const n: number[] = this.vals.slice();
    n[i] = v;
    this.vals = n;
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
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一局暂时给不出提示'));
  }

  /** ★ AI 代打：用出题时的完整解，一格一格填 */
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
    if (this.solCells.length < CELLS) {
      return false;
    }
    for (let i = 0; i < CELLS; i++) {
      if (this.vals[i] !== this.solCells[i]) {
        this.sel = i;
        this.put(this.solCells[i]);
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


  private put(d: number): void {
    if (this.over) {
      return;
    }
    this.setVal(this.sel, d);
    this.moves++;
    this.check();
  }

  private clearSel(): void {
    if (this.over) {
      return;
    }
    this.setVal(this.sel, 0);
    this.moves++;
    this.check();
  }

  private tapCell(i: number): void {
    if (this.over) {
      return;
    }
    this.sel = i;
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const done: number = this.cagesDone();
    if (done === this.cages.length && this.latinOk()) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 行列合法、笼全满足，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    this.tip = TG2('笼完成 {0} / {1}', String(done), String(this.cages.length)) +
      (this.latinOk() ? TG(' · 行列已合法') : TG(' · 行列还差一点'));
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
        Text((TG('笼完成'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.cagesDone()) + '/' + String(this.cages.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filled()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rows, (c: number) => {
              Column() {
              Text(this.anchor[((r * N + c))] ? this.clue(((r * N + c))) : '')
              .fontSize(FontSize.xxs)
              .fontColor(this.theme.inkFaint)
              .width('100%')
              .textAlign(I18n.isRTL() ? TextAlign.End : TextAlign.Start)
              Text(this.vals[(r * N + c)] === 0 ? '' : String(this.vals[(r * N + c)]))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.cageOk(this.cages[this.cageOf[(r * N + c)]]) ? Palette.emerald : this.theme.ink)
              .layoutWeight(1)
              .width('100%')
              .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .padding(2)
              .backgroundColor(tint(Palette.wheel[this.cageOf[(r * N + c)] % Palette.wheel.length], '22'))
              .borderRadius(Radius.xs)
              .border({ width: this.sel === (r * N + c) ? 2 : 1, color: this.sel === (r * N + c) ? Palette.primary : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tapCell((r * N + c));
              })
            }, (c: number) => 'nc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'nr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .layoutWeight(1)
          .height(Cell.of(38))
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .layoutWeight(1)
          .height(Cell.of(38))
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
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'na' + d)
        ForEach(this.k2, (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'nb' + d)
        this.delBtn()
      }
      .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.emerald)
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

  private filled(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.vals[i] !== 0) {
        n++;
      }
    }
    return n;
  }





  private clue(i: number): string {
    const c: Cage = this.cages[this.cageOf[i]];
    if (c.op === '') {
      return String(c.target);
    }
    return String(c.target) + c.op;
  }





  @Builder
  delBtn() {
    Text('⌫')
      .accessibilityText(TG('删除'))
      .fontSize(FontSize.lg)
      .fontColor(Palette.rose)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(Cell.of(44))
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
      .onClick(() => {
        Haptics.tick();
        this.clearSel();
      })
  }
}
