/**
 * 截面切片 📐 —— 5×5×5 方块堆，只画第 h 层的平面图（黑格有方块、灰格空）
 * 问：这一层一共几个方块？（靠平面图逆推每行/每列各一个的阶梯结构）
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const TOTAL: number = 8;
const PASS: number = 6;
const NEXT_MS: number = 760;

@Component
export struct GCrossSectionSlice {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
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

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCrossSectionSlice')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
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

  private csArea(): number {
    let a: number = 0;
    for (let k = 0; k < this.plane.length; k++) {
      if (this.plane[k] === 1) { a++; }
    }
    return a;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.locked) {
      return true;
    }
    this.pick(this.csArea());
    return !this.over;
  }

  /** 提示：截面积是多少 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.locked || this.over) {
      return Hint.none('none');
    }
    let a: number = 0;
    for (let k = 0; k < this.plane.length; k++) {
      if (this.plane[k] === 1) { a++; }
    }
    return Hint.make([a], TG2('截面积是 {0}', String(a)),
      TG2('The area is {0}', String(a)), t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
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
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[0])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[0])); })
        Button((this.opts[1]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[1])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[1])); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button((this.opts[2]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[2])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[2])); })
        Button((this.opts[3]) + TG(' 个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[3])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[3])); })
      }.width('100%')

      Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
