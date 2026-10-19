/**
 * 电路连接 🔋
 * 规则：4×4 元件盘，点一下顺时针转 90°；电源从左上角左边进电，目标是右下角那格。
 * 胜负：电流通到右下角（且朝右出） = 通关；步数用尽没接通 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4; const LAST: number = N * N - 1; const TURNS: number = 26;
/** 位序 0上 1右 2下 3左；GLYPH[mask] = 画出来的样子 */
const BASE: number[] = [3, 5, 6, 9, 10, 12, 15];
const GLYPH: string[] = ['·', '╹', '╺', '╚', '╻', '║', '╔', '╠', '╸', '╝', '═', '╩', '╗', '╣', '╦', '╬'];
function has(m: number, d: number): boolean {
 return Math.floor(m / Math.pow(2, d)) % 2 === 1;
}
  @Component
export struct GCircuitConnect {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private grid: number[] = []; @State private rot: number[] = [];
  @State private on: boolean[] = []; @State private moves: number = 0;
  @State private over: boolean = false; @State private won: boolean = false;
  @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
 private reset(): void {
 const g: number[] = []; const rt: number[] = [];
 for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
 g.push(BASE[Math.floor(Math.random() * BASE.length)]); rt.push(Math.floor(Math.random() * 4));
 }
 this.grid = g; this.rot = rt; this.moves = 0; this.over = false;
 this.won = false; this.note = TG(TG(TG('转动元件，把电送到右下角 🔋')));
 this.startAt = Date.now(); this.on = this.powered();
 }
 /** 当前朝向的导通掩码 */
 private maskAt(i: number): number {
 const m: number = this.grid[i]; const r: number = this.rot[i]; let out: number = 0;
 for (let d = 0; d < 4; d++) {
 if (has(m, d)) { out += Math.pow(2, (d + r) % 4); }
 }
 return out;
 }
 /** 从左上角注电（左边视为电源馈入） */
 private powered(): boolean[] {
 const lit: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
 if (!has(this.maskAt(0), 3)) { return lit; }
 const st: number[] = [0]; lit[0] = true;
 while (st.length > 0) {
 const i: number = st.pop() as number; const r: number = Math.floor(i / this.diffTotal);
 const c: number = i % this.diffTotal; const m: number = this.maskAt(i);
 if (r > 0 && has(m, 0) && has(this.maskAt(i - this.diffTotal), 2) && !lit[i - this.diffTotal]) {
 lit[i - this.diffTotal] = true; st.push(i - this.diffTotal);
 }
 if (c < this.diffTotal - 1 && has(m, 1) && has(this.maskAt(i + 1), 3) && !lit[i + 1]) {
 lit[i + 1] = true; st.push(i + 1);
 }
 if (r < this.diffTotal - 1 && has(m, 2) && has(this.maskAt(i + this.diffTotal), 0) && !lit[i + this.diffTotal]) {
 lit[i + this.diffTotal] = true; st.push(i + this.diffTotal);
 }
 if (c > 0 && has(m, 3) && has(this.maskAt(i - 1), 1) && !lit[i - 1]) {
 lit[i - 1] = true; st.push(i - 1);
 }
 }
 return lit;
 }
 private spin(i: number): void {
 if (this.over) { return; }
 const rt: number[] = this.rot.slice(); rt[i] = (rt[i] + 1) % 4; this.rot = rt; this.moves++;
 const lit: boolean[] = this.powered(); this.on = lit; let cnt: number = 0;
 for (let t = 0; t < lit.length; t++) { if (lit[t]) { cnt++; } }
 const solved: boolean = lit[LAST] && has(this.maskAt(LAST), 1);
 if (solved || this.moves >= TURNS) {
 this.note = solved ? '接通了，灯亮 🎉' : '步数用尽，还没接通 😵'; this.finish(solved, cnt); return;
 }
 this.note = TG2('当前带电 {0}/{1} 格 ⚡', cnt, (this.diffTotal * this.diffTotal));
 }
 private finish(solved: boolean, lit: number): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'circuit_connect', solved: solved,
 score: solved ? 60 + Math.max(0, (TURNS - this.moves) * 4) : lit * 3,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.sm }) {
 Text(TG2('步数 {0}/{1}　电源 {2}',Digits(String(this.moves), this.langCode), String(TURNS), this.on[0] ? TG('接入 ✅') : TG('断开 ❌'))
 + TG2('　终点 {0}', this.on[LAST] ? TG('通电 💡') : TG('未通'))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(GLYPH[this.maskAt(r * this.diffTotal + c)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.on[r * this.diffTotal + c] ? Palette.amber : this.theme.inkFaint)
 Text(r * this.diffTotal + c === 0 ? '⚡' : (r * this.diffTotal + c === LAST ? '💡' : '')).fontSize(FontSize.xs).offset({ x: 0, y: 20 })
 }.layoutWeight(1).height(Cell.of(62)).backgroundColor(this.on[r * this.diffTotal + c] ? this.theme.surfaceAlt : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.on[r * this.diffTotal + c] ? Palette.amber : this.theme.line).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.spin(r * this.diffTotal + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).width('100%').height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
 }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}