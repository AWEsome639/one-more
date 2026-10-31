/**
 * 干扰矩阵 🔲 —— 4×4 符号矩阵里混着两种符号，限时数出目标符号的个数
 * 干扰项越来越多，靠"扫视 + 抑制干扰"快速清点
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 剩余秒数
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

const N: number = 4;
const CELLS: number = N * N;
const TOTAL: number = 8;
const PASS: number = 6;
const LIMIT: number = 10;
const NEXT_MS: number = 760;

interface Matrix {
  cells: number[];      // 1 = 目标符号，2 = 干扰符号
  target: string;
  distractor: string;
  count: number;
  opts: number[];
}

function build(i: number): Matrix {
  const pairs: string[][] = [['🔷', '🔶'], ['🟢', '🟣'], ['⭐', '🌙'], ['🍎', '🍋']];
  const pair: string[] = pairs[i % pairs.length];
  const cells: number[] = new Array<number>(CELLS).fill(2);
  const want: number = 2 + (i % 2);
  const pool: number[] = [];
  for (let k = 0; k < CELLS; k++) { pool.push(k); }
  for (let k = pool.length - 1; k > 0; k--) {
    const j: number = Math.floor(Math.random() * (k + 1));
    const t: number = pool[k]; pool[k] = pool[j]; pool[j] = t;
  }
  for (let k = 0; k < want; k++) { cells[pool[k]] = 1; }
  const set: number[] = [want];
  const cand: number[] = [1, 2, 3, 4, 5, 6, 7];
  for (let k = 0; k < cand.length && set.length < 4; k++) {
    if (set.indexOf(cand[k]) < 0) { set.push(cand[k]); }
  }
  for (let k = set.length - 1; k > 0; k--) {
    const j: number = Math.floor(Math.random() * (k + 1));
    const t: number = set[k]; set[k] = set[j]; set[j] = t;
  }
  return { cells: cells, target: pair[0], distractor: pair[1], count: want, opts: set };
}

@Component
export struct GDistractorMatrix {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private cells: number[] = [];
  @State private target: string = '';
  @State private distractor: string = '';
  @State private opts: number[] = [];
  @State private q: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private hits: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private hint: string = '';
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;
  private ticker: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDistractorMatrix')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }

  private stopTimers(): void {
    if (this.ticker >= 0) { clearInterval(this.ticker); this.ticker = -1; }
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private reset(): void {
    this.stopTimers();
    this.hits = 0; this.score = 0; this.q = 0; this.over = false; this.hint = '';
    this.startAt = Date.now();
    this.load();
  }

  private load(): void {
    const m: Matrix = build(this.q);
    this.cells = m.cells; this.target = m.target; this.distractor = m.distractor;
    this.opts = m.opts; this.left = this.total; this.locked = false; this.hint = '';
    this.startAt = this.startAt === 0 ? Date.now() : this.startAt;
    if (this.ticker >= 0) { clearInterval(this.ticker); }
    if (this.timer >= 0) { clearTimeout(this.timer); }
    this.ticker = setInterval(() => {
      if (this.locked || this.over) { return; }
      this.left--;
      if (this.left <= 0) { this.judge(-1); }
    }, 1000);
  }

  /** ★ AI 代打/提示共用：本局目标符号的真实个数 */
  private countTarget(): number {
    let n: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === 1) { n = n + 1; }
    }
    return n;
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
    if (this.over || this.locked) {
      return true;
    }
    this.judge(this.countTarget());
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('目标符号 {0} 一共 {1} 个', this.target, this.countTarget()),
      TG2('There are {1} of {0} in the matrix', this.target, this.countTarget()), t0);
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

  private judge(v: number): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    let real: number = 0;
    for (let k = 0; k < this.cells.length; k++) {
      if (this.cells[k] === 1) { real++; }
    }
    if (v === real) { this.hits++; this.score += 90 + this.left * 5; this.hint = TG(TG(TG('数对了 ✅'))); }
    else if (v < 0) { this.hint = TG2('超时 ⏰ 正确答案 {0}', real); }
    else { this.hint = TG2('数错了 ❌ 正确答案 {0}', real); }
    if (this.q + 1 >= TOTAL) {
      this.over = true;
      this.stopTimers();
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'distractor_matrix', solved: this.hits >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.hits
      });
      return;
    }
    this.timer = setTimeout(() => { this.q++; this.load(); }, NEXT_MS);
  }

  aboutToDisappear(): void { this.stopTimers(); }





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
        Text(TG2("第 {0}/{1}", (this.q + 1), TOTAL)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG('答对 ') + this.hits).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG2('剩 {0}s', Math.max(0, this.left))).fontSize(FontSize.md).fontColor(Palette.orange).layoutWeight(1)
      }.width('100%')

      Text(TG2('🔲 数出矩阵里 {0} 的个数（忽略 {1}）', this.target, this.distractor))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text((this.cells[r * N + c]) === 1 ? this.target : this.distractor).fontSize(FontSize.lg)
              }
              .layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.theme.surfaceAlt)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.hint.length > 0 ? this.hint : '⏱ 每题 ' + LIMIT + ' 秒，答得越快加分越多')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Button(String((this.opts[0])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.lime).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((this.opts[0])); }); })
        .onClick(() => { Haptics.tap(); this.judge((this.opts[0])); })
        Button(String((this.opts[1])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.lime).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((this.opts[1])); }); })
        .onClick(() => { Haptics.tap(); this.judge((this.opts[1])); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(String((this.opts[2])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.lime).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((this.opts[2])); }); })
        .onClick(() => { Haptics.tap(); this.judge((this.opts[2])); })
        Button(String((this.opts[3])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.lime).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge((this.opts[3])); }); })
        .onClick(() => { Haptics.tap(); this.judge((this.opts[3])); })
      }.width('100%')

      Button(this.over ? (this.hits >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
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
