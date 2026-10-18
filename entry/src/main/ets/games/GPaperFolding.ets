/**
 * 折纸 📄
 * 规则：纸对折两次（你看到的是左上角那四分之一）；在折好的纸上打孔，孔会镜像成四份。
 * 胜负：展开后与目标完全一致 ⇒ 通关；步数用尽还没对上 ⇒ 失败。　进度：已打孔 / 步数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const Q: number = 4; const F: number = Q * 2; const HOLES: number = 3; const LIMIT: number = 14;
const IDXQ: number[] = [0, 1, 2, 3]; const IDXF: number[] = [0, 1, 2, 3, 4, 5, 6, 7];

/** 折叠态 → 展开态：一个孔镜像成四份 */
function unfold(q: boolean[]): boolean[] {
  const out: boolean[] = new Array<boolean>(F * F).fill(false);
  for (let r = 0; r < Q; r++) {
    for (let c = 0; c < Q; c++) {
      if (!q[r * Q + c]) { continue; }
      out[r * F + c] = true; out[r * F + (F - 1 - c)] = true;
      out[(F - 1 - r) * F + c] = true; out[(F - 1 - r) * F + (F - 1 - c)] = true;
    }
  }
  return out;
}
function sameMap(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
  return true;
}
function countOf(a: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i]) { n = n + 1; } }
  return n;
}

@Component
export struct GPaperFolding {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 Q=4，按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(4);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State private mine: boolean[] = []; @State private goal: boolean[] = []; @State private shown: boolean[] = [];
  @State private steps: number = 0; @State private over: boolean = false; @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  private reset(): void {
    const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { pool.push(i); }
    for (let k = 0; k < HOLES; k++) {
      const j: number = Math.floor(Math.random() * pool.length);
      g[pool[j]] = true; pool.splice(j, 1);
    }
    this.goal = unfold(g); this.mine = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false); this.shown = unfold(this.mine);
    this.steps = 0; this.over = false; this.won = false;
    this.msg = TG2('展开后要有 {0} 个孔，位置你自己找', String(HOLES * 4));
    this.startAt = Date.now();
  }
  private punch(i: number): void {
    if (this.over) { return; }
    const m: boolean[] = this.mine.slice();
    m[i] = !m[i];
    this.mine = m; this.shown = unfold(m); this.steps = this.steps + 1;
    if (sameMap(this.shown, this.goal)) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.steps >= LIMIT) { this.finish(false); return; }
    this.msg = TG2("已打 {0} 孔（展开后 {1} 个）", String(countOf(m)), String(countOf(this.shown)));
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 展开后与目标完全一致！' : '😵 步数用尽，图案还没对上';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'paper_folding', solved: solved,
      score: solved ? 100 + (LIMIT - this.steps) * 40 : countOf(this.shown) * 6,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 3 : 1
    });
  }
  /** mode 1 = 目标图，0 = 我的展开图 */
  private hasHole(mode: number, i: number): boolean { return mode === 1 ? this.goal[i] : this.shown[i]; }
  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标孔'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(HOLES * 4))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已打'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(countOf(this.mine) * 4))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(LIMIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          Text(TG('折好的纸 · 点它打孔')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: Space.xs }) {
            ForEach(IDXQ, (r: number) => {
              Row({ space: Space.xs }) {
                ForEach(IDXQ, (c: number) => { Stack() {
                Text(this.mine[(r * this.diffTotal + c)] ? '🕳️' : '').fontSize(FontSize.sm)
                }.layoutWeight(1).aspectRatio(1)
                .backgroundColor(this.mine[(r * this.diffTotal + c)] ? Palette.amber : this.theme.surface)
                .borderRadius(Radius.sm).borderWidth(2)
                .borderColor(this.mine[(r * this.diffTotal + c)] ? Palette.primaryDeep : this.theme.line)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
                // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
                .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                  .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
                .onClick(() => { this.punch((r * this.diffTotal + c)); }) }, (c: number) => 'fc' + c)
              }.width('100%')
            }, (r: number) => 'fr' + r)
          }.width('100%').aspectRatio(1).padding(Space.xs)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
        }.layoutWeight(2)
        Column({ space: Space.xs }) {
          Text(TG('目标')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(IDXF, (r: number) => {
          Row({ space: 1 }) {
          ForEach(IDXF, (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.hasHole((1), r * F + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
          }, (c: number) => (true ? 'gc' : 'mc') + c)
          }.width('100%')
          }, (r: number) => (true ? 'gr' : 'mr') + r)
          }.width('100%')
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('我的')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(IDXF, (r: number) => {
          Row({ space: 1 }) {
          ForEach(IDXF, (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.hasHole((0), r * F + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
          }, (c: number) => (false ? 'gc' : 'mc') + c)
          }.width('100%')
          }, (r: number) => (false ? 'gr' : 'mr') + r)
          }.width('100%')
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
