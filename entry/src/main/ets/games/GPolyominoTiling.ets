/**
 * 多联骨牌 🃏
 * 规则：挑一块骨牌，点棋盘放下（点已铺的格子能拿起来）；灰格是墙，放不了。
 * 胜负：把所有空格铺满 ⇒ 通关；步数用尽还没铺满 ⇒ 失败。　进度：已铺格数 / 剩余步数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5; const LIMIT: number = 26;
const IDXN: number[] = [0, 1, 2, 3, 4];
const IDXS: number[] = [0, 1, 2, 3, 4, 5];

interface Shape { name: string; dr: number[]; dc: number[] }

const SHAPES: Shape[] = [
  { name: '▬', dr: [0, 0, 0], dc: [0, 1, 2] },
  { name: '▟', dr: [0, 1, 2], dc: [0, 0, 1] },
  { name: '◼', dr: [0, 0, 1, 1], dc: [0, 1, 0, 1] },
  { name: '∿', dr: [0, 0, 1, 1], dc: [0, 1, 1, 2] },
  { name: '⊤', dr: [0, 0, 0, 1], dc: [0, 1, 2, 1] },
  { name: '▪', dr: [0], dc: [0] }
];
/** 棋盘值：0 空（要铺）、1 墙、2 已铺；以 start 为锚点能不能放下 */
function fits(board: number[], s: Shape, start: number): boolean {
  const r0: number = Math.floor(start / N); const c0: number = start % N;
  for (let t = 0; t < s.dr.length; t++) {
    const r: number = r0 + s.dr[t]; const c: number = c0 + s.dc[t];
    if (r < 0 || r >= N || c < 0 || c >= N) { return false; }
    if (board[r * N + c] !== 0) { return false; }
  }
  return true;
}
function countOf(a: number[], v: number): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i] === v) { n = n + 1; } }
  return n;
}

@Component
export struct GPolyominoTiling {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(5);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private board: number[] = []; @State private sel: number = 0; @State private moves: number = 0;
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  private reset(): void {
    this.board = this.makeBoard();
    this.sel = 0; this.moves = 0; this.over = false; this.won = false;
    this.msg = TG('挑一块，点棋盘放下');
    this.startAt = Date.now();
  }
  /** 先用骨牌随机铺一块区域 ⇒ 这块区域一定能被铺满，剩下的就是墙 */
  private makeBoard(): number[] {
    const cover: number[] = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
    for (let k = 0; k < 8; k++) {
      if (countOf(cover, 1) >= 15) { break; }
      const spots: number[] = []; const which: number[] = [];
      for (let s = 0; s < SHAPES.length; s++) {
        for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
          if (fits(cover, SHAPES[s], i)) { spots.push(i); which.push(s); }
        }
      }
      if (spots.length === 0) { break; }
      const j: number = Math.floor(Math.random() * spots.length);
      const s: Shape = SHAPES[which[j]];
      const r0: number = Math.floor(spots[j] / this.diffTotal); const c0: number = spots[j] % this.diffTotal;
      for (let t = 0; t < s.dr.length; t++) { cover[(r0 + s.dr[t]) * this.diffTotal + (c0 + s.dc[t])] = 1; }
    }
    const board: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { board.push(cover[i] === 0 ? 1 : 0); }
    return board;
  }
  private left(): number { return countOf(this.board, 0); }
  private total(): number { return this.diffTotal * this.diffTotal - countOf(this.board, 1); }
  private place(i: number): void {
    if (this.over) { return; }
    const cur: number = this.board[i];
    if (cur === 2) {
      const b: number[] = this.board.slice();
      b[i] = 0; this.board = b; this.moves = this.moves + 1;
      this.msg = TG2("拿起一块 · 还剩 {0} 步", String(LIMIT - this.moves));
      if (this.moves >= LIMIT) { this.finish(false); }
      return;
    }
    if (cur === 1) { this.msg = TG('这是墙，放不了'); return; }
    const s: Shape = SHAPES[this.sel];
    if (!fits(this.board, s, i)) { this.msg = TG('这块放不下，换个位置'); return; }
    const b: number[] = this.board.slice();
    const r0: number = Math.floor(i / this.diffTotal); const c0: number = i % this.diffTotal;
    for (let t = 0; t < s.dr.length; t++) { b[(r0 + s.dr[t]) * this.diffTotal + (c0 + s.dc[t])] = 2; }
    this.board = b; this.moves = this.moves + 1;
    if (this.left() === 0) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.moves >= LIMIT) { this.finish(false); return; }
    this.msg = TG2("已铺 {0}/{1} 格", String(this.total() - this.left()), String(this.total()));
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 一格不剩，全铺满！' : TG2("😵 步数用尽，还剩 {0} 格", String(this.left()));
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'polyomino_tiling', solved: solved,
      score: solved ? 150 + (LIMIT - this.moves) * 6 : (this.total() - this.left()) * 8,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
    });
  }
  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已铺'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.total() - this.left()) + '/' + String(this.total()))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(LIMIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        Column({ space: 2 }) {
        Text((TG('选中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((SHAPES[this.sel].name)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => { Stack() {
            Text(this.board[(r * this.diffTotal + c)] === 2 ? '▩' : '').fontSize(FontSize.lg).fontColor('#FFFFFF')
            }.layoutWeight(1).aspectRatio(1)
            .backgroundColor(this.board[(r * this.diffTotal + c)] === 2 ? Palette.teal
            : (this.board[(r * this.diffTotal + c)] === 1 ? this.theme.line : this.theme.surfaceAlt))
            .borderRadius(Radius.sm)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { this.place((r * this.diffTotal + c)); }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('86%').aspectRatio(1).padding(Space.xs)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(IDXS, (s: number) => { Column({ space: 2 }) {
        Text(SHAPES[(s)].name).fontSize(FontSize.lg).fontColor(this.sel === (s) ? '#FFFFFF' : this.theme.ink)
        Text(TG2("{0}格", String(SHAPES[(s)].dr.length))).fontSize(FontSize.xxs)
        .fontColor(this.sel === (s) ? '#FFFFFF' : this.theme.inkFaint)
        }.layoutWeight(1).padding({ top: Space.xs, bottom: Space.xs })
        .backgroundColor(this.sel === (s) ? Palette.teal : this.theme.surface)
        .borderRadius(Radius.sm).borderWidth(2)
        .borderColor(this.sel === (s) ? Palette.teal : this.theme.line)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.sel = (s); }) }, (s: number) => 'sh' + s)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
