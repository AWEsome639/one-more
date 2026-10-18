/**
 * 像素临摹 👾
 * 规则：照着左边的目标像素图，在右边点出一样的图案（再点一次可擦掉）。
 * 胜负：64 格全部一致 ⇒ 通关；步数用尽还没画对 ⇒ 失败。　进度：对上几格 / 步数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 8; const LIMIT: number = 70;
const IDXN: number[] = [0, 1, 2, 3, 4, 5, 6, 7];

function sameMap(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
  return true;
}
function matchedOf(a: boolean[], b: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i] === b[i]) { n = n + 1; } }
  return n;
}
function countOf(a: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i]) { n = n + 1; } }
  return n;
}

@Component
export struct GPixelMimic {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=8）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(8);
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
  @State private goal: boolean[] = []; @State private mine: boolean[] = [];
  @State private steps: number = 0; @State private over: boolean = false; @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  private reset(): void {
    this.goal = this.makeGoal();
    this.mine = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    this.steps = 0; this.over = false; this.won = false;
    this.msg = TG('照左边画，多点的格子再点一次就擦掉');
    this.startAt = Date.now();
  }
  /** 四向对称 ⇒ 生成的图案像个小怪物的脸 */
  private makeGoal(): boolean[] {
    for (let attempt = 0; attempt < 40; attempt++) {
      const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
      for (let r = 0; r < this.diffTotal / 2; r++) {
        for (let c = 0; c < this.diffTotal / 2; c++) {
          if (Math.random() < 0.5) {
            g[r * this.diffTotal + c] = true; g[r * this.diffTotal + (this.diffTotal - 1 - c)] = true;
            g[(this.diffTotal - 1 - r) * this.diffTotal + c] = true; g[(this.diffTotal - 1 - r) * this.diffTotal + (this.diffTotal - 1 - c)] = true;
          }
        }
      }
      const n: number = countOf(g);
      if (n >= 12 && n <= 30) { return g; }
    }
    const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    for (let r = 0; r < this.diffTotal; r++) {
      for (let c = 0; c < this.diffTotal; c++) {
        if (Math.abs(r - 3.5) + Math.abs(c - 3.5) <= 2) { g[r * this.diffTotal + c] = true; }
      }
    }
    return g;
  }
  private paint(i: number): void {
    if (this.over) { return; }
    const m: boolean[] = this.mine.slice();
    m[i] = !m[i];
    this.mine = m; this.steps = this.steps + 1;
    if (sameMap(m, this.goal)) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.steps >= LIMIT) { this.finish(false); return; }
    this.msg = TG2("对上 {0}/{1} 格", String(matchedOf(m, this.goal)), String(this.diffTotal * this.diffTotal));
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 一模一样！' : '😵 步数用尽，还差几格';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'pixel_mimic', solved: solved,
      score: solved ? 120 + (LIMIT - this.steps) * 8 : matchedOf(this.mine, this.goal) * 2,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
    });
  }
  /** mode 1 = 目标图，0 = 我的画布 */
  private pixOf(mode: number, i: number): boolean { return mode === 1 ? this.goal[i] : this.mine[i]; }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(countOf(this.goal)))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('对上'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(matchedOf(this.mine, this.goal)) + '/' + String(this.diffTotal * this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(LIMIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
          Text(TG('目标')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 1 }) {
          ForEach(this.rowIdx(), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.pixOf((1), r * this.diffTotal + c) ? Palette.amber : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          if (false) { this.paint(r * this.diffTotal + c); }
          })
          }, (c: number) => (true ? 'gc' : 'pc') + c)
          }.width('100%')
          }, (r: number) => (true ? 'gr' : 'pr') + r)
          }.width('100%').padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('你的画布 · 点格子')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 1 }) {
          ForEach(this.rowIdx(), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.pixOf((0), r * this.diffTotal + c) ? Palette.amber : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          if (true) { this.paint(r * this.diffTotal + c); }
          })
          }, (c: number) => (false ? 'gc' : 'pc') + c)
          }.width('100%')
          }, (r: number) => (false ? 'gr' : 'pr') + r)
          }.width('100%').padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }.layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top)
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
