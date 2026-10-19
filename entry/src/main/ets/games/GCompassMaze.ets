/**
 * 罗盘迷宫 🌀
 * 规则：7×7 迷宫（先走通一条路再补墙，必有路）。底部是指南针指令带：
 * 点「走一步」按下达方向走，撞墙白扣一步；⇄ 反转整条指令带（排错用，不扣步数）。
 * 胜负：走到右下角出口 = 通关；步数用尽 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 7; const CELLS: number = N * N;
// ★★ 2026-10-13 修复（奥森："电脑水平太低" 挖出的尺寸越界）：
//   GameDiff.sizeScale 困难档 = ×1.3 ⇒ 棋盘会变成 10×10
//   而数组原来按 CELLS = 49 开 ⇒ 【困难档必越界】✗
//   ⇒ 按【困难档最大尺寸】开数组（多占几百个 int，可忽略）
const MAX_N: number = 10;
const MAX_CELLS: number = MAX_N * MAX_N; const DMAX: number = 20; const TAPE: number = 8;
/** 方向 0上 1右 2下 3左；墙位 1/2/4/8 */
const DR: number[] = [-1, 0, 1, 0]; const DC: number[] = [0, 1, 0, -1];
const ARROW: string[] = ['↑', '→', '↓', '←']; const WALL: number[] = [1, 2, 4, 8];
interface Maze {
 walls: number[]; cmds: number[];
}
/** 从左上角凿一条随机路通到右下角，其余墙随机再拆几道；指令带 = 这条路正反两遍 */
function genMaze(n: number): Maze {
 // ★★★ 2026-10-18 00:2x 真 BUG 修复（与 GClassicMaze 同一类）：
 //   原来用【常量 N=7】生成（终点 CELLS-1=48），但 follow() 用 this.diffTotal（5/7/9）算行列
 //   ⇒ 简单档/困难档下墙壁错位、终点判定错 ⇒ 迷宫可能走不通
 //   ⇒ 修法：按【实际边长 n】生成
 const nn: number = n > 1 ? n : 2;
 const cells: number = nn * nn;
 const w: number[] = new Array<number>(MAX_CELLS).fill(15); const cs: number[] = [];
 let cur: number = 0; let guard: number = 0;
 // ★★★ 2026-10-18 01:0x 真 BUG 修复（第三处）：原来 guard 上限固定 400 步
 //   实测 9×9 时只有 11/20 次能走到终点 ⇒ 指令带 cs 不完整 ⇒ 玩家永远到不了终点
 //   ⇒ 按棋盘大小给足预算（2D 随机游走覆盖时间 ~ n²·log²n，取 cells*400 极保守）
 while (cur !== cells - 1 && guard < cells * 400) {
 guard++; const r: number = Math.floor(cur / nn);
 const c: number = cur - r * nn; const opts: number[] = [];
 if (r < nn - 1) { opts.push(2); }
 if (c < nn - 1) { opts.push(1); }
 if (r > 0) { opts.push(0); }
 if (c > 0) { opts.push(3); }
 const d: number = opts[Math.floor(Math.random() * opts.length)];
 const nb: number = (r + DR[d]) * nn + (c + DC[d]);
 // ★★★ 2026-10-18 00:3x 真 BUG 修复：原来用 `-` 拆墙，重复拆同一面会减成负数
 //   ⇒ 墙壁位掩码变负 ⇒ 位运算结果不可预测 ⇒ 迷宫的墙全乱
 //   ⇒ 改用位清零 `&= ~挡位`（幂等，重复拆也不会错）
 w[cur] = w[cur] & (~WALL[d]);
 w[nb] = w[nb] & (~WALL[(d + 2) % 4]); cs.push(d); cur = nb;
 }
 for (let k = 0; k < 6; k++) { // 再拆几道墙，路不唯一才好玩
 const i: number = Math.floor(Math.random() * cells); const r: number = Math.floor(i / nn);
 const c: number = i - r * nn; const opts: number[] = [];
 if (r > 0) { opts.push(0); }
 if (r < nn - 1) { opts.push(2); }
 if (c > 0) { opts.push(3); }
 if (c < nn - 1) { opts.push(1); }
 const d: number = opts[Math.floor(Math.random() * opts.length)];
 const nb: number = (r + DR[d]) * nn + (c + DC[d]);
 // ★★★ 同上：位清零代替减法
 w[i] = w[i] & (~WALL[d]);
 w[nb] = w[nb] & (~WALL[(d + 2) % 4]);
 }
 const tape: number[] = [];
 for (let i = 0; i < cs.length; i++) { tape.push(cs[i]); }
 for (let i = cs.length - 1; i >= 0; i--) { tape.push((cs[i] + 2) % 4); }
 while (tape.length < TAPE * 2) { tape.push(Math.floor(Math.random() * 4)); }
 return { walls: w, cmds: tape };
}
  @Component
export struct GCompassMaze {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=7；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5, 6]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(7);
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

  @State private walls: number[] = []; @State private cmds: number[] = [];
  @State private pos: number = 0; @State private idx: number = 0;
  @State private steps: number = 0; @State private over: boolean = false;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(7);
     this.reset(); }
 /** ★ 出口格子下标（随棋盘边长走） */
 private goalIdx(): number { return this.diffTotal * this.diffTotal - 1; }
 private reset(): void {
 const m: Maze = genMaze(this.diffTotal); this.walls = m.walls; this.cmds = m.cmds; this.pos = 0;
 this.idx = 0; this.steps = 0; this.over = false; this.won = false;
 this.note = TG('照着指令走到右下角 🌀'); this.startAt = Date.now();
 }
 private follow(): void {
 if (this.over) { return; }
 const d: number = this.cmds[this.idx]; const cur: number = this.pos;
 const nr: number = Math.floor(cur / this.diffTotal) + DR[d]; const nc: number = cur % this.diffTotal + DC[d];
 if ((this.walls[cur] & WALL[d]) !== 0 || nr < 0 || nr >= this.diffTotal || nc < 0 || nc >= this.diffTotal) {
 this.note = TG('撞墙，这一步白走 🧱');
 } else {
 this.pos = nr * this.diffTotal + nc;
 }
 this.idx = (this.idx + 1) % this.cmds.length; this.steps++;
 if (this.pos === this.goalIdx()) {
 this.note = TG('指令走完，出关 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.steps >= DMAX) {
 this.note = TG('步数用尽，还在半路 😵'); this.finish(false); return;
 }
 this.note = TG2('下一步指令：{0}', ARROW[this.cmds[this.idx]]);
 }
 /** ⇄ 反转整条指令带：0↔2、1↔3，不扣步数 */
 private flip(): void {
 if (this.over) { return; }
 const cs: number[] = [];
 for (let i = 0; i < this.cmds.length; i++) { cs.push((this.cmds[i] + 2) % 4); }
 this.cmds = cs; this.note = TG('指令带已反转 ⇄（不扣步数）');
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'compass_maze', solved: solved,
 score: solved ? 70 + Math.max(0, (DMAX - this.steps) * 5) : this.steps * 4,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.xs }) {
 Text(TG('步数 ') + this.steps + '/' + DMAX + '　指令 ' + (this.idx + 1) + '/' + this.cmds.length
 + TG2('　出口 {0}排{1}列', this.diffTotal, this.diffTotal)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: 0 }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: 0 }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.pos === r * this.diffTotal + c ? '🔵' : (r * this.diffTotal + c === this.goalIdx() ? '🏁' : '')).fontSize(FontSize.sm)
 }.layoutWeight(1).height(Cell.of(40)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).borderWidth({
 top: (this.walls[r * this.diffTotal + c] & 1) !== 0 ? 2 : 0, right: (this.walls[r * this.diffTotal + c] & 2) !== 0 ? 2 : 0,
 bottom: (this.walls[r * this.diffTotal + c] & 4) !== 0 ? 2 : 0,
 left: (this.walls[r * this.diffTotal + c] & 8) !== 0 ? 2 : 0
 }).borderColor(Palette.wall).animation({ duration: Motion.fast, curve: Motion.snap() })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Row({ space: 2 }) {
 ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
 Text(ARROW[this.cmds[(this.idx + i) % this.cmds.length]]).fontSize(FontSize.sm).fontColor(i === 0 ? '#FFFFFF' : this.theme.inkSoft).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30)).backgroundColor(i === 0 ? Palette.amber : this.theme.surface).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
 }, (i: number) => 'm' + i) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.xs }) {
 Button(TG2('走一步 {0}', ARROW[this.cmds[this.idx]]))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(2).height(Cell.of(46)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.follow(); })
 Button(TG('⇄ 反转'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(46)).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.flip(); })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(46)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.violet).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
 }.width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}