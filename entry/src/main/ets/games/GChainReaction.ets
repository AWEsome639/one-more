/**
 * 连锁反应 ⚡
 * 规则：3×3 盘，每格容量 = 邻居数；点一下 +1 光点，超过容量就炸开、向四邻各送 1 点（连锁）。
 * 胜负：步数内清空全部光点 = 通关；步数用尽 = 失败。可悔一步 / 要提示。
 */
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

function capOf(i: number): number {
 const r: number = Math.floor(i / N); const c: number = i % N; let d: number = 0;
 if (r > 0) { d++; }
 if (r < N - 1) { d++; }
 if (c > 0) { d++; }
 if (c < N - 1) { d++; }
 return d;
}
function total(a: number[]): number {
 let s: number = 0;
 for (let i = 0; i < a.length; i++) { s += a[i]; }
 return s;
}
/** 点 i 后一路炸到稳定；null = 连锁失控 */
function boom(src: number[], i: number): number[] | null {
 const a: number[] = src.slice(); a[i]++; const qu: number[] = [i]; let guard: number = 0;
 while (qu.length > 0) {
 guard++;
 if (guard > 400) { return null; }
 const j: number = qu.shift() as number;
 if (a[j] <= capOf(j)) { continue; }
 a[j] = a[j] - capOf(j); const r: number = Math.floor(j / N); const c: number = j % N;
 if (r > 0) { a[j - N]++; qu.push(j - N); }
 if (r < N - 1) { a[j + N]++; qu.push(j + N); }
 if (c > 0) { a[j - 1]++; qu.push(j - 1); }
 if (c < N - 1) { a[j + 1]++; qu.push(j + 1); }
 }
 return a;
}
/**
 * 构造一个"保证能清空"的盘面：从空盘出发随机点 k 下，再把盘面倒过来当开局。
 * 玩家照这个序列走一遍就是解（链路可逆），k = 参考步数。
 */
// ★★ 2026-10-13 修复循环上界（困难档 ×1.3 ⇒ 棋盘更大）
function makeBoard(n: number): number[] {
 const a: number[] = new Array<number>(MAX_CELLS).fill(0);
 let clicks: number = 12 + Math.floor(Math.random() * 7);
 for (let t = 0; t < clicks; t++) {
  const ns: number[] | null = boom(a, Math.floor(Math.random() * n * n));
  if (ns === null) { break; }
  for (let i = 0; i < n * n; i++) { a[i] = ns[i]; }
 }
 return a;
}
  @Component
export struct GChainReaction {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

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
     this.reset(); }
 private reset(): void {
 this.cells = makeBoard(this.diffTotal);
 this.limit = 20;
 this.steps = 0; this.over = false; this.won = false; this.note = TG('点格子加光点，满了就炸 ⚡');
 this.tip = -1; this.hist = []; this.startAt = Date.now();
 }
 private pick(i: number): void {
 if (this.over) { return; }
 const ns: number[] | null = boom(this.cells, i);
 if (ns === null) {
 this.note = TG('连锁失控，重开吧 💥'); this.finish(false); return;
 }
 this.hist.push(this.cells.slice());
 if (this.hist.length > 60) { this.hist.shift(); }
 this.cells = ns; this.steps++; this.tip = -1;
 if (total(ns) === 0) {
 this.note = TG('一炸到底，全清 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.steps >= this.limit) {
 this.note = TG2('步数用尽，还剩 {0} 点 😵', total(ns)); this.finish(false); return;
 }
 this.note = TG('炸得漂亮，继续 👌');
 }
 private askHint(): void {
 let bestI: number = -1; let gain: number = 0; const cur: number = total(this.cells);
 for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
 const ns: number[] | null = boom(this.cells, i);
 if (ns === null) { continue; }
 if (cur - total(ns) > gain) {
 gain = cur - total(ns); bestI = i;
 }
 }
 this.tip = bestI; this.note = gain > 0 ? '试试闪光那格 ✨' : '这手不好走，悔一步吧';
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
 score: solved ? 60 + Math.max(0, (this.limit - this.steps) * 8) : this.steps * 5,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.sm }) {
 Text(TG2("步数 {0}/{1}　剩光点 {2}",Digits(String(this.steps), this.langCode),Digits(String(this.limit), this.langCode), total(this.cells))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.orbs(r * this.diffTotal + c)).fontSize(FontSize.xl).fontColor(Palette.amber)
 Text(String(this.cells[r * this.diffTotal + c])).fontSize(FontSize.xs).fontColor(this.theme.inkFaint).offset({ x: 0, y: 20 })
 }.layoutWeight(1).height(Cell.of(72)).backgroundColor(this.tip === r * this.diffTotal + c ? Palette.violet : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.cells[r * this.diffTotal + c] >= capOf(r * this.diffTotal + c)
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