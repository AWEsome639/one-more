/** 线框旋转 🔄（id: wireframe_3d_rotation）
 * 题面是 4 块方块搭成的立体形状，四个点阵里只有一个是它「转了个方向」的正交投影；
 * 4 题答对 ≥3 ⇒ 通关，否则失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
const G: number = 7; const ROUNDS: number = 4;
const NEED: number = 3;
const PAUSE: number = 900;
const TWO: number[] = [0, 1];
const EMPTY: boolean[] = [];
const SHAPES: number[][] = [
  [0, 0, 0, 1, 0, 0, 2, 0, 0, 3, 0, 0], [0, 0, 0, 1, 0, 0, 2, 0, 0, 2, 1, 0],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0], [0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 2, 1, 0], [0, 0, 0, 1, 0, 0, 2, 0, 0, 1, 1, 0],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1]
];
function rot90(p: number[], ax: number): number[] {
  if (ax === 0) { return [p[0], -p[2], p[1]]; }
  return ax === 1 ? [p[2], p[1], -p[0]] : [-p[1], p[0], p[2]];
}
/** 绕坐标轴连转 4~7 次 90°，得到一个正着放的随机朝向 */
function orient(shape: number[]): number[] {
  let cur: number[] = shape.slice(); const n: number = 4 + Math.floor(Math.random() * 4);
  for (let i = 0; i < n; i++) {
    const ax: number = Math.floor(Math.random() * 3); const out: number[] = [];
    for (let k = 0; k < cur.length; k += 3) {
      const q: number[] = rot90([cur[k], cur[k + 1], cur[k + 2]], ax);
      out.push(q[0]); out.push(q[1]); out.push(q[2]); }
    cur = out;
  }
  return cur;
}
/** 正交投影到 G×G 点阵（坐标恒在 -3..3，平移 +3 即可） */
function marks(shape: number[]): boolean[] {
  const out: boolean[] = new Array<boolean>(G * G).fill(false);
  for (let i = 0; i < shape.length; i += 3) { out[(3 - shape[i + 1]) * G + shape[i] + 3] = true; }
  return out;
}
function art(m: boolean[]): string {
  let s: string = ''; for (let r = 0; r < G; r++) {
    for (let c = 0; c < G; c++) { s += m[r * G + c] ? '⬛' : '⬜'; }
    s += '\n'; }
  return s;
}
@Component
export struct GWireframe3dRotation {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 NEED=3
  @State private diffTotal: number = GameDiff.sizeNow(3);
  onFinish: (r: GameResult) => void = () => {};
  @State targetMarks: boolean[] = [];
  @State optMarks: boolean[][] = [];
  @State ans: number = 0;
  @State asked: number = 0;
  @State hits: number = 0;
  @State picked: number = -1;
  @State over: boolean = false;
  @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private timer: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); } private win(): boolean { return this.hits >= this.diffTotal; }
  private clearTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private reset(): void {
    this.clearTimer(); this.asked = 0; this.hits = 0; this.over = false; this.done = false;
    this.startAt = Date.now(); this.newRound();
  }
  private newRound(): void {
    for (let attempt = 0; attempt < 60; attempt++) {
      const si: number = Math.floor(Math.random() * SHAPES.length);
      const base: number[] = SHAPES[si];
      const mt: string = marks(base).join(''); const right: number[] = orient(base);
      const mr: string = marks(right).join('');
      if (mr === mt) { continue; }
      const cands: boolean[][] = []; const seen: string[] = [mt, mr];
      for (let k = 0; k < SHAPES.length && cands.length < 3; k++) {
        if (k === si) { continue; }
        const one: boolean[] = marks(orient(SHAPES[k])); const finger: string = one.join('');
        if (seen.indexOf(finger) >= 0) { continue; }
        seen.push(finger); cands.push(one);
      }
      if (cands.length < 3) { continue; }
      const at: number = Math.floor(Math.random() * 4);
      const out: boolean[][] = []; let k: number = 0;
      for (let i = 0; i < 4; i++) {
        if (i === at) { out.push(marks(right)); } else { out.push(cands[k]); k++; }
      }
      this.targetMarks = marks(base); this.optMarks = out; this.ans = at; this.picked = -1;
      this.note = TG('哪个只是转了个方向？');
      return;
    }
  }
  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i; this.asked++;
    if (i === this.ans) { this.hits++; this.note = TG('✅ 同一块积木，转过来的'); } else { this.note = TG('❌ 绿框那个才是它'); }
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.asked >= ROUNDS) { this.finish(this.win()); return; }
      this.newRound();
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.clearTimer();
    const r: GameResult = {
      gameId: 'wireframe_3d_rotation', solved: solved, score: this.hits * 25,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG('第 ') + String(Math.min(this.asked + 1, ROUNDS)) + '/' + String(ROUNDS) + ' 题 · 答对 ' +
        String(this.hits) + '/' + String(this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Text(art(this.targetMarks)).fontSize(FontSize.sm).lineHeight(Space.md)
        .textAlign(TextAlign.Center).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      ForEach(TWO, (r: number) => {
        Row({ space: Space.sm }) {
          this.opt(r * 2)
          this.opt(r * 2 + 1)
        }
        .width('100%')
      }, (r: number) => 'orow' + r)
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.win() ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.win() ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  opt(i: number) {
    Column() {
      Text(art(this.optMarks.length > i ? this.optMarks[i] : EMPTY))
        .fontSize(FontSize.sm).lineHeight(Space.md).textAlign(TextAlign.Center)
    }
    .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
    .borderRadius(Radius.md).borderWidth(2)
    .borderColor(this.picked < 0 ? this.theme.line :
      (i === this.ans ? Palette.emerald : (i === this.picked ? Palette.rose : this.theme.line)))
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.pick(i); })
  }
}
