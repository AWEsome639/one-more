/**
 * 猜数字 —— 7 次机会二分逼近 1~100 的秘密数字
 * 胜负：7 次内猜中 ⇒ 通关；次数用尽 ⇒ 失败｜进度：已用次数 / 当前范围
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const LO: number = 1;
const HI: number = 100;
const MAX_TRIES: number = 7;
const KEEP: number = 4;

@Component
export struct GMathGuess {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 MAX_TRIES=7，按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(7);
  onFinish: (r: GameResult) => void = () => {};

  @State secret: number = 0; @State guess: number = 50; @State tries: number = 0;
  @State lowBound: number = LO; @State highBound: number = HI;
  @State history: string[] = []; @State hint: string = ''; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false;
  /** ★ 2026-10-14 动效（奥森：「动画要拉满」）：猜数变化时弹一下 */
  @State private bump: number = 1;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMathGuess')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(7);
     this.reset(); }

  /** ★ 弹一下：先放大再回弹（140ms 一个来回） */
  private doBump(): void {
    this.bump = 1.12;
    setTimeout(() => { this.bump = 1; }, 140);
  }

  private reset(): void {
    this.secret = LO + Math.floor(Math.random() * (HI - LO + 1));
    this.guess = Math.floor((LO + HI) / 2);
    this.tries = 0; this.lowBound = LO; this.highBound = HI;
    this.history = []; this.hint = TG('提示：每猜一次就能砍掉一半范围');
    this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now();
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
    this.guess = this.secret;
    this.submit();
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 秘密数字就存在 this.secret 里（真值直取）
  /** 提示：直接报秘密数字 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.secret - LO],
      TG2('秘密数字是 {0}', String(this.secret)),
      TG2('The secret number is {0}', String(this.secret)), t0);
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

  private submit(): void {
    if (this.over) { return; }
    const v: number = Math.round(this.guess);
    this.tries = this.tries + 1;
    const left: number = this.diffTotal - this.tries;
    const line: string = TG2("第 {0} 猜：{1}", this.tries, v);
    this.doBump();   // ★ 提交也弹一下
    if (v === this.secret) {
      const gain: number = 100 + left * 150;
      this.score = this.score + gain;
      this.history = this.history.concat([line + ' ✅ 命中']);
      this.over = true; this.won = true;
      this.hint = TG2('🎉 就是 {0}！还剩 {1} 次没用，+{2}', v, left, gain);
      this.finish(true);
      return;
    }
    if (v < this.secret) {
      if (v + 1 > this.lowBound) { this.lowBound = v + 1; }
      this.hint = TG('⬆️ 小了，往大猜');
    } else {
      if (v - 1 < this.highBound) { this.highBound = v - 1; }
      this.hint = TG('⬇️ 大了，往小猜');
    }
    this.history = this.history.concat([line + (v < this.secret ? ' ↑' : ' ↓')]);
    if (left <= 0) {
      this.over = true;
      this.hint = TG2('💤 机会用完，答案是 {0}', this.secret);
      this.finish(false);
      return;
    }
    this.nudge(0);
  }

  /** delta=0 跳到范围中位；±1 微调。结果始终夹在 [lowBound, highBound] */
  private nudge(delta: number): void {
    if (this.over) { return; }
    const mid: number = Math.floor((this.lowBound + this.highBound) / 2);
    let v: number = delta === 0 ? mid : Math.round(this.guess) + delta;
    if (v < this.lowBound) { v = this.lowBound; }
    if (v > this.highBound) { v = this.highBound; }
    this.guess = v;
    this.doBump();   // ★ 弹一下
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'math_guess', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.tries };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private recentText(): string {
    if (this.history.length === 0) { return TG('（还没有猜测记录）'); }
    return this.history.slice(Math.max(0, this.history.length - KEEP)).join('\n');
  }

  build() {
    Column({ space: Space.md }) {
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
      Text(TG2('已用 {0}/{1}　范围 {2}', String(this.tries), String(this.diffTotal), String(this.lowBound))
        + TG2('~{0}　分 {1}',Digits(String(this.highBound), this.langCode),Digits(String(this.score), this.langCode)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.isDark ? Palette.primary : Palette.primaryDeep)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(String(Math.round(this.guess)))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
          // ★ 动效：猜数一变就弹一下（原来是硬切）
          .scale({ x: this.bump, y: this.bump })
          .animation({ duration: Motion.fast, curve: Motion.spring() })
        Text(this.hint).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Row({ space: Space.sm }) {
        Button('−1')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.nudge(-1); }); }).onClick(() => { Haptics.tap(); this.nudge(-1); })
        Button(TG('中位'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.nudge(0); }); }).onClick(() => { Haptics.tap(); this.nudge(0); })
        Button('+1')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.nudge(1); }); }).onClick(() => { Haptics.tap(); this.nudge(1); })
      }.width('100%')
      Button(TG2('就猜 {0}', Math.round(this.guess)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(48))
        .enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); }).onClick(() => { Haptics.tap(); this.submit(); })
      Text(this.recentText())
        .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Row({ space: Space.md }) {
        Text(this.over ? (this.won ? TG('已通关 🎉') : '已结束 💤') : '二分法 7 次足够覆盖 1~100')
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint).layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
