/**
 * 截面切片 📐 —— 5×5×5 方块堆，只画第 h 层的平面图（黑格有方块、灰格空）
 * 问：这一层一共几个方块？（靠平面图逆推每行/每列各一个的阶梯结构）
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const TOTAL: number = 8;
const PASS: number = 6;
const NEXT_MS: number = 760;

@Component
export struct GCrossSectionSlice {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private plane: number[] = [];
  @State private h: number = 0;
  @State private opts: number[] = [];
  @State private qi: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  private reset(): void {
    this.right = 0; this.score = 0; this.qi = 0; this.over = false;
    this.load(0); this.startAt = Date.now();
  }

  private load(i: number): void {
    // 每列放 1~5 个方块，重叠成一堆；第 h 层平面图 = 各列高度是否 ≥ h+1
    const plane: number[] = [];
    let area: number = 0;
    const h: number = 1 + Math.floor(Math.random() * 4);
    for (let c = 0; c < N * N; c++) {
      const tall: number = 1 + Math.floor(Math.random() * N);
      const on: number = tall >= h + 1 ? 1 : 0;
      plane.push(on);
      if (on === 1) { area++; }
    }
    const set: number[] = [area];
    const cand: number[] = [0, N, N * 2, N * 2 + 1, N * 3, N * 3 + 2, N * 4, 1, 2, 3];
    for (let k = 0; k < cand.length && set.length < 4; k++) {
      if (set.indexOf(cand[k]) < 0) { set.push(cand[k]); }
    }
    this.plane = plane; this.h = h; this.opts = set;
    this.qi = i; this.locked = false;
  }

  private pick(v: number): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    let area: number = 0;
    for (let k = 0; k < this.plane.length; k++) {
      if (this.plane[k] === 1) { area++; }
    }
    if (v === area) { this.right++; this.score += 110; }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'cross_section_slice', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      });
      return;
    }
    this.timer = setTimeout(() => { this.load(this.qi + 1); }, NEXT_MS);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); }
  }





  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", (this.qi + 1), this.diffTotal)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG('答对 ') + this.right).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG('得分 ') + this.score).fontSize(FontSize.md).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')

      Text(TG2('🧊 一堆方块（每列 1~5 层）。这是第 {0} 层的俯视切片 —— 这一层有几个方块？', (this.h + 1)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text((this.plane[r * N + c]) === 1 ? '⬛' : '').fontSize(FontSize.md)
              }
              .layoutWeight(1).aspectRatio(1)
              .backgroundColor((this.plane[r * N + c]) === 1 ? (this.theme.isDark ? '#E2E8F0' : '#0F172A') : this.theme.surfaceAlt)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(TG('⬛ = 这一层有方块　▫️ = 这一层是空的（下层再高也不算）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')

      Row({ space: Space.sm }) {
        Button((this.opts[0]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts[0])); })
        Button((this.opts[1]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts[1])); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button((this.opts[2]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts[2])); })
        Button((this.opts[3]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts[3])); })
      }.width('100%')

      Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
