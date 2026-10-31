/**
 * 倒背数字 —— 数字逐个闪现，凭记忆倒序点回去
 *
 * 胜负：6 轮答对 5 轮以上 ⇒ 通关；位数每两轮加长一位
 * 进度：轮次 / 答对 / 位数 / 已输入
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const TRIALS: number = 6; const NEED: number = 5; const BASE: number = 3;
const IDLE: number = -3;   // 未开始
const ASK: number = -2;    // 播完，等作答
const LOCK: number = -4;   // 已判定，锁定输入
@Component
export struct GDigitSpanReverse {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State private seq: number[] = [];
  @State private cursor: number = IDLE;
  @State private flash: boolean = false;
  @State private typed: number[] = [];
  @State private trialNo: number = 1;
  @State private right: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private to1: number = -1;
  private to2: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDigitSpanReverse')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
    if (this.to2 >= 0) { clearTimeout(this.to2); this.to2 = -1; }
  }
  /** 位数：3,3,4,4,5,5 */
  private span(): number { return BASE + Math.floor((this.trialNo - 1) / 2); }
  private reset(): void {
    this.stop(); this.trialNo = 1; this.right = 0; this.over = false; this.won = false; this.done = false;
    this.typed = []; this.startAt = Date.now(); this.newTrial();
  }
  private newTrial(): void {
    const list: number[] = [];
    for (let i = 0; i < this.span(); i++) {
      list.push(1 + Math.floor(Math.random() * 9));
    }
    this.seq = list; this.typed = []; this.cursor = IDLE; this.flash = false;
    this.msg = TG2("第 {0} 轮 · 记住 {1} 个数字", String(this.trialNo), String(this.span()));
    this.to1 = setTimeout(() => { this.to1 = -1; this.play(0); }, 700);
  }
  private play(k: number): void {
    if (k >= this.seq.length) {
      this.cursor = ASK; this.flash = false; this.msg = TG('倒序点出来：先点最后一个');
      return;
    }
    this.cursor = k; this.flash = true; this.to1 = setTimeout(() => {
      this.to1 = -1; this.flash = false;
      this.to2 = setTimeout(() => { this.to2 = -1; this.play(k + 1); }, 180);
    }, 720);
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
    if (this.cursor !== ASK) {
      return true;
    }
    this.tapDigit(this.seq[this.seq.length - 1 - this.typed.length]);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值就在 seq 里：倒序第 k 位 = seq[seq.length - 1 - typed.length]
  /** 提示：报下一位该点的数字 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.cursor !== ASK) {
      return Hint.none('none');
    }
    const d: number = this.seq[this.seq.length - 1 - this.typed.length];
    return Hint.make([d],
      TG2('倒序第 {0} 位是 {1}', String(this.typed.length + 1), String(d)),
      TG2('Reverse position {0} is {1}', String(this.typed.length + 1), String(d)), t0);
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

  private tapDigit(d: number): void {
    if (this.over || this.cursor !== ASK) { return; }
    const expect: number = this.seq[this.seq.length - 1 - this.typed.length];
    const next: number[] = this.typed.slice();
    next.push(d);
    this.typed = next;
    if (d !== expect) {
      this.cursor = LOCK; this.msg = TG2("❌ 第 {0} 位错了，应为 {1}", String(next.length), String(expect));
      this.to1 = setTimeout(() => { this.to1 = -1; this.advance(); }, 1100);
      return;
    }
    if (next.length === this.seq.length) {
      this.right = this.right + 1; this.cursor = LOCK; this.msg = TG('✅ 全对！');
      this.to1 = setTimeout(() => { this.to1 = -1; this.advance(); }, 700);
    }
  }
  private advance(): void {
    if (this.trialNo >= this.diffTotal) {
      this.won = this.right >= NEED; this.over = true;
      this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
      this.finish();
      return;
    }
    this.trialNo = this.trialNo + 1; this.newTrial();
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'digit_span_reverse', solved: this.won,
      score: this.right * 150, durationMs: Date.now() - this.startAt,
      levelReached: this.span()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('位数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.span()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        Text(this.cursor >= 0 && this.flash ? String(this.seq[this.cursor]) : (this.cursor === ASK ? '？' : '·'))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.sky)
      }.width('100%').height(110).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              Text(String((r * 3 + c + 1))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(48)).backgroundColor(this.theme.surfaceAlt)
              .borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapDigit((r * 3 + c + 1)); }); }).onClick(() => { Haptics.tick(); this.tapDigit((r * 3 + c + 1)); })
            }, (c: number) => 'kc' + c)
          }.width('100%')
        }, (r: number) => 'kr' + r)
      }.width('100%')
      Text(TG2("已输入：{0}", (this.typed.length === 0 ? '—' : this.typed.join(' ')))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky).borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
        .width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
