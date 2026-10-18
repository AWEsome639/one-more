/**
 * 剪影匹配 📐（id: silhouette_match）
 * 积木的颜色与花纹都不算，剪影只看轮廓 —— 挑出轮廓完全相同的那张（转过的不算）。
 * 胜负：6 题答对 ≥4 ⇒ 通关；进度：题号 / 答对。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const M: number = 5; const CELLS: number = M * M;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，原来只开 25）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N; const ROUNDS: number = 6; const NEED: number = 4;
const ROWS: number[] = [0, 1, 2, 3, 4];
const SHAPES: string[] = [
  '01100,01100,00100,00000,00000', '01000,11100,01000,00000,00000',
  '11000,01100,00100,00000,00000', '01110,00100,00100,00000,00000',
  '10000,11000,01100,00100,00000', '01100,00100,01100,00000,00000'
];

function parse(s: string): number[] {
  const flat: string = s.split(',').join(''); const out: number[] = [];
  for (let i = 0; i < flat.length; i++) { out.push(flat.charAt(i) === '1' ? 1 : 0); }
  return out;
}
/** 顺时针 90°：(r,c) → (c, M-1-r) */
// ★★ 2026-10-13 修复循环上界（困难档 ×1.3 ⇒ 棋盘更大，原来只转前 CELLS 格）
function rot(a: number[], n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n * n; i++) { if (a[i] === 1) { out[(i % n) * n + (n - 1 - Math.floor(i / n))] = 1; } }
  return out;
}
/** 原形 + 90°/180°/270° 三个朝向 */
function ring4(b: number[], n: number): number[][] {
  const out: number[][] = [b];
  for (let i = 0; i < 3; i++) { out.push(rot(out[i], n)); }
  return out;
}

@Component
export struct GSilhouetteMatch {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 M=5
  @State private diffTotal: number = GameDiff.sizeNow(5);
  onFinish: (r: GameResult) => void = () => {};
  @State target: number[] = []; @State opts: number[][] = []; @State answerAt: number = 0;
  @State asked: number = 0; @State hits: number = 0; @State picked: number = -1;
  @State over: boolean = false; @State won: boolean = false; @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private nextTimer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; } }
  private reset(): void {
    this.stopTimer(); this.asked = 0; this.hits = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    const b: number[] = parse(SHAPES[0]); const ring: number[][] = ring4(b, this.diffTotal);
    this.target = b; this.opts = [b, ring[1], ring[2], ring[3]]; this.answerAt = 0;
    this.note = TG('剪影只看轮廓，颜色花纹不算');
    this.newRound();
  }
  private newRound(): void {
    const b: number[] = parse(SHAPES[Math.floor(Math.random() * SHAPES.length)]);
    const ring: number[][] = ring4(b, this.diffTotal);
    // 四张里只有第 0 张的轮廓与原形相同，另外三张都被转过 90°/180°/270°
    const list: number[][] = [b, ring[1], ring[2], ring[3]];
    const shift: number = Math.floor(Math.random() * 4);
    const opts: number[][] = [list[shift], list[(shift + 1) % 4], list[(shift + 2) % 4], list[(shift + 3) % 4]];
    let ans: number = 0;
    for (let i = 0; i < 4; i++) { if (opts[i] === b) { ans = i; } }
    this.target = b; this.opts = opts; this.answerAt = ans; this.picked = -1;
    this.note = TG('哪张剪影的轮廓和积木完全一样？');
  }
  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i; this.asked++;
    if (i === this.answerAt) { this.hits++; this.note = TG('✅ 轮廓一模一样'); }
    else { this.note = TG('❌ 那张被转过 90° 以上，绿框才对'); }
    this.stopTimer();
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.asked >= ROUNDS) { this.finish(this.hits >= NEED); return; }
      this.newRound();
    }, 900);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.stopTimer();
    const res: GameResult = { gameId: 'silhouette_match', solved: solved, score: this.hits * 15, durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  /** mode < 0 ⇒ 积木彩格（颜色与剪影无关）；mode ≥ 0 ⇒ 第 mode 张剪影 */
  private cellColor(cells: number[], mode: number, i: number): string {
    if (cells.length <= i || cells[i] !== 1) { return this.theme.surfaceAlt; }
    if (mode < 0) { return i % this.diffTotal % 2 === 0 ? Palette.primary : Palette.orange; }
    return this.picked >= 0 && mode === this.answerAt ? Palette.emerald : (this.theme.isDark ? '#E2E8F0' : '#334155');
  }

  build() {
    Column({ space: Space.sm }) {
      Text(TG2("题号 {0}/{1}", Math.min(this.asked + 1, ROUNDS), ROUNDS))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
          Text(TG('积木')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Column() { Column({ space: 2 }) {
          ForEach(ROWS, (r: number) => {
          Row({ space: 2 }) {
          ForEach(ROWS, (c: number) => {
          Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
          .backgroundColor(this.cellColor((this.target), (-1), r * this.diffTotal + c))
          }, (c: number) => 'gc' + c)
          }.width('100%')
          }, (r: number) => 'gr' + r)
          }.width('100%') }.width(104)
        }.layoutWeight(1)
        Text(TG('🕯️ ➜ 剪影')).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(0)]), ((0)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('72%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((0) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((0)); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(1)]), ((1)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('72%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((1) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((1)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(2)]), ((2)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('72%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((2) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((2)); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(3)]), ((3)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('72%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((3) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((3)); })
      }.width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
