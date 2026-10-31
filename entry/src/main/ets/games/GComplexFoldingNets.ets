/**
 * 复杂折纸 📄 —— 纸条沿标线依次对折（折痕在中间或四分之一处），问标记处叠了几层
 * 线段模型：每段一段纸（起始 [0,1) 表示第 1 层），折 k 次后标记点所在段数 = 层数
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

const TOTAL: number = 8;
const PASS: number = 6;
const NEXT_MS: number = 760;
const SEED: number[] = [3, 6, 12, 8, 7, 14, 2, 9];

function foldCount(folds: number[], pos: number): number {
  let segs: number[] = [0, 1];
  for (let i = 0; i < folds.length; i++) {
    const f: number = folds[i];
    const next: number[] = [0];
    for (let j = 0; j < segs.length; j++) {
      const a: number = segs[j];
      const b: number = segs[j + 1];
      next.push(a < f ? f - a : a);
      if (b >= f) {
        next.push(b - f);
      }
    }
    segs = next;
  }
  for (let i = 0; i < segs.length - 1; i++) {
    if (pos >= segs[i] && pos < segs[i + 1]) {
      return i + 1;
    }
  }
  return 1;
}

function makeFolds(seed: number): number[] {
  let x: number = seed * 9301 + 49297;
  const rnd: () => number = (): number => {
    x = (x * 9301 + 49297) % 233280;
    return x / 233280;
  };
  const n: number = 2 + Math.floor(rnd() * 3);
  const out: number[] = [];
  let cur: number = 0.5;
  for (let i = 0; i < n; i++) {
    const t: number = i === 0 ? 0.5 : (rnd() < 0.5 ? 1 : 3) / 4;
    cur = cur * t;
    out.push(cur);
  }
  return out;
}

@Component
export struct GComplexFoldingNets {
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

  @State private folds: number[] = [];
  @State private mark: number = 0.25;
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
    if (Hint.demoOnce('GComplexFoldingNets')) {
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
    const folds: number[] = makeFolds(SEED[i]);
    const marks: number[] = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875];
    const pos: number = marks[(i * 3 + 1) % marks.length];
    const ans: number = foldCount(folds, pos);
    const set: number[] = [ans];
    let d: number = 1;
    while (set.length < 4) {
      if (ans + d <= 16 && set.indexOf(ans + d) < 0) { set.push(ans + d); }
      if (ans - d >= 1 && set.indexOf(ans - d) < 0) { set.push(ans - d); }
      d++;
    }
    this.folds = folds; this.mark = pos; this.opts = set;
    this.qi = i; this.locked = false;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    this.pick(foldCount(this.folds, this.mark));
    return !this.over;
  }

  /** 提示：折叠后有 N 层 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.locked || this.over) {
      return Hint.none('none');
    }
    const ans: number = foldCount(this.folds, this.mark);
    return Hint.make([], TG2('折完是 {0} 层', String(ans)),
      TG2('It becomes {0} layers', String(ans)), t0);
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
    const ans: number = foldCount(this.folds, this.mark);
    if (v === ans) { this.right++; this.score += 120; }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'complex_folding_nets', solved: this.right >= PASS,
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

      Text(TG('📄 纸条按下列折痕依次对折，📍 处最终叠了几层？'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.folds, (f: number, i: number) => {
          Text(TG2('折{0} {1}%', ((i) + 1), ((f) * 100).toFixed(0)))
          .fontSize(FontSize.sm).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(34)).backgroundColor(Palette.emerald).borderRadius(Radius.sm)
        }, (f: number, i: number) => 'f' + i)
      }.width('100%')

      Row({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
          Stack() {
          Text(this.mark >= (i) / 8 && this.mark < ((i) + 1) / 8 ? '📍' : '').fontSize(FontSize.sm)
          }
          .layoutWeight(1).height(Cell.of(46))
          .backgroundColor(this.mark >= (i) / 8 && this.mark < ((i) + 1) / 8 ? Palette.amber : this.theme.surface)
          .borderRadius(Radius.xs)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        }, (i: number) => 'p' + i)
      }.width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(TG(TG('箭头从左往右 = 展开后的纸条；实心块就是 📍 落点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')

      Row({ space: Space.sm }) {
        Button((this.opts[0]) + ' 层')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(52)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        .shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[0])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[0])); })
        Button((this.opts[1]) + ' 层')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(52)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        .shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[1])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[1])); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button((this.opts[2]) + ' 层')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(52)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        .shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts[2])); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts[2])); })
        Button((this.opts[3]) + ' 层')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(52)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        .shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
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
