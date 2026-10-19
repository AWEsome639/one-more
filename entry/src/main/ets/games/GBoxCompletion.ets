/**
 * 补全盒子 📐
 * 规则：盘上零散格子中恰好有 12 格能拼成一个矩形边框；点亮空格补齐，点多了就算输。
 * 胜负：恰好点亮 12 格、且全部落在同一个矩形边框上 = 通关；超过 12 格 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIDE: number = 4; const CELLS: number = SIDE * SIDE;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 6×6 = 36 格，
//   而数组原来按 CELLS = 16 开 ⇒【困难档必越界】✗）
const MAX_N: number = 6;
const MAX_CELLS: number = MAX_N * MAX_N; const PERIM: number = 12;

function rectCells(r1: number, c1: number, r2: number, c2: number): number[] {
 const out: number[] = [];
 for (let r = r1; r <= r2; r++) {
 for (let c = c1; c <= c2; c++) {
 if (r === r1 || r === r2 || c === c1 || c === c2) { out.push(r * SIDE + c); }
 }
 }
 return out;
}
  @Component
export struct GBoxCompletion {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（简单 3 / 普通 4 / 困难 5）
  //   ⚠️ 光改 this.diffTotal 不够 —— 渲染用的是写死的 [0,1,2,3]，必须同时改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);   // 4 = 原 SIDE
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a: number[] = [];
    for (let i = 0; i < n; i++) { a.push(i); }
    return a;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private cells: boolean[] = []; @State private lit: boolean[] = [];
  @State private moves: number = 0; @State private over: boolean = false;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
 private reset(): void {
 let board: boolean[] | null = null;
 for (let round: number = 0; round < 60; round++) {
 const r1: number = Math.floor(Math.random() * 2); const c1: number = Math.floor(Math.random() * 2);
 const r2: number = r1 + 1 + Math.floor(Math.random() * (this.diffTotal - 1 - r1));
 const c2: number = c1 + 1 + Math.floor(Math.random() * (this.diffTotal - 1 - c1));
 const per: number[] = rectCells(r1, c1, r2, c2);
 const grid: boolean[] = new Array<boolean>(MAX_CELLS).fill(false); let holes: number = 0;
 for (let t = 0; t < per.length; t++) {
 if (Math.random() < 0.6) { grid[per[t]] = true; } else { holes++; }
 }
 if (holes < 3 || holes > 6) { continue; }
 board = grid; break;
 }
 if (board === null) { // 兜底：整圈边框挖 4 个洞
 const g: boolean[] = new Array<boolean>(MAX_CELLS).fill(true); g[1] = false;
 g[2] = false; g[7] = false; g[11] = false; board = g;
 }
 this.cells = board; this.lit = new Array<boolean>(MAX_CELLS).fill(false);
 this.moves = 0; this.over = false; this.won = false; this.note = TG('点亮空格，把边框补成 12 格 📐');
 this.startAt = Date.now();
 }
 private litCount(): number {
 let n: number = 0;
 for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { if (this.lit[i]) { n++; } }
 return n;
 }
 private pick(i: number): void {
 if (this.over || this.cells[i]) { return; }
 const cur: boolean[] = this.lit.slice();
 if (cur[i]) {
 cur[i] = false; this.lit = cur; return;
 }
 cur[i] = true; this.lit = cur; this.moves++; const n: number = this.litCount();
 if (n > PERIM) {
 this.note = TG2('补过头了，多出 {0} 格 ❌', n - PERIM); this.finish(false); return;
 }
 if (n === PERIM) {
 let r1: number = this.diffTotal; let c1: number = this.diffTotal; let r2: number = -1; let c2: number = -1;
 for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
 if (this.cells[k] || this.lit[k]) {
 const r: number = Math.floor(k / this.diffTotal); const c: number = k - r * this.diffTotal;
 if (r < r1) { r1 = r; }
 if (r > r2) { r2 = r; }
 if (c < c1) { c1 = c; }
 if (c > c2) { c2 = c; }
 }
 }
 const per: number[] = rectCells(r1, c1, r2, c2); let bad: number = 0;
 for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
 if ((this.cells[k] || this.lit[k]) && per.indexOf(k) < 0) { bad++; }
 }
 if (bad === 0 && per.length === PERIM) {
 this.note = TG('边框合拢，完美盒子 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 this.note = TG('12 格了，但凑不成一个完整边框 🤔 撤几格再试'); return;
 }
 this.note = TG2('已补 {0}/{1} 格，还差 {2} 格', n, PERIM, PERIM - n);
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'box_completion', solved: solved,
 score: solved ? 80 + Math.max(0, 40 - this.moves * 4) : this.litCount() * 4,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.sm }) {
 Text(TG2('已补 {0}/{1} 格　步数 {2}', this.litCount(), PERIM,Digits(String(this.moves), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.cells[r * this.diffTotal + c] && this.lit[r * this.diffTotal + c] ? '✨'
 : (this.cells[r * this.diffTotal + c] ? '⬛'
 : (this.lit[r * this.diffTotal + c] ? '🟨' : ''))).fontSize(FontSize.xxl)
 }.layoutWeight(1).height(Cell.of(62)).backgroundColor(this.lit[r * this.diffTotal + c] ? Palette.amber : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.cells[r * this.diffTotal + c] ? Palette.ink : this.theme.line).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick(r * this.diffTotal + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.sm }) {
 Button(TG('清空点亮'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).onClick(() => {
 Haptics.tap();
 if (!this.over) { this.lit = new Array<boolean>(MAX_CELLS).fill(false); }
 })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
 }.width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}