/**
 * 注意瞬脱 —— 一串字符逐个闪现，其中有且只有一个数字，找出它是几
 * 胜负：5 轮答对 4 轮以上 ⇒ 通关（每轮再快 40ms）；进度：轮次 / 答对 / 间隔
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const TRIALS: number = 5;
const NEED: number = 4;
const LEN: number = 13;
const LETTERS: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'K', 'M', 'P', 'R', 'S', 'T', 'V', 'X', 'Z'];
const SLOTS: number[] = [0, 1, 2, 3];

@Component
export struct GAttentionalBlink {
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
  @State private seq: string[] = [];
  @State private digit: string = '0';
  @State private idx: number = -1;      // -1 未开始，LEN = 已播完
  @State private showing: boolean = false;
  @State private trialNo: number = 1;
  @State private right: number = 0;
  @State private opts: string[] = [];
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private tickTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAttentionalBlink')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.tickTo >= 0) { clearTimeout(this.tickTo); this.tickTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  /** 每轮更快：300ms ⇒ 140ms */
  private pace(): number { return 300 - (this.trialNo - 1) * 40; }
  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.right = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }
  private newTrial(): void {
    const digits: string[] = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const list: string[] = [];
    for (let i = 0; i < LEN; i++) { list.push(LETTERS[Math.floor(Math.random() * LETTERS.length)]); }
    const at: number = 3 + Math.floor(Math.random() * (LEN - 6));
    const d: string = digits[Math.floor(Math.random() * digits.length)];
    list[at] = d;
    const pool: string[] = [d];
    while (pool.length < 4) {
      const x: string = digits[Math.floor(Math.random() * digits.length)];
      if (pool.indexOf(x) < 0) { pool.push(x); }
    }
    const mixed: string[] = [];
    while (pool.length > 0) { mixed.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
    this.seq = list;
    this.digit = d;
    this.opts = mixed;
    this.pick = -1;
    this.idx = -1;
    this.showing = false;
    this.msg = TG2("第 {0} 轮：数字混在字母里，记住它是几", String(this.trialNo));
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.play(0); }, 600);
  }
  /** 逐个闪现：亮 pace() 毫秒、灭 70 毫秒 */
  private play(k: number): void {
    if (k >= this.seq.length) {
      this.idx = LEN;
      this.showing = false;
      this.msg = TG('刚才的数字是几？');
      return;
    }
    this.idx = k;
    this.showing = true;
    this.tickTo = setTimeout(() => {
      this.tickTo = -1;
      this.showing = false;
      this.tickTo = setTimeout(() => { this.tickTo = -1; this.play(k + 1); }, 70);
    }, this.pace());
  }
  /** 提示：和代打同一个循环（含局部常量），只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.digit) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：opts[i] === this.digit 的那个选项
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
    if (this.over || this.pick >= 0 || this.idx < LEN) {
      return true;              // 还在刺激/过渡阶段，等
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.digit) {
        this.answer(i);
        return true;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private answer(i: number): void {
    if (this.over || this.pick >= 0 || this.idx < LEN) { return; }
    this.pick = i;
    if (this.opts[i] === this.digit) {
      this.right = this.right + 1;
      this.msg = TG('✅ 正确！');
    } else {
      this.msg = TG2("❌ 应该是 {0}", this.digit);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.trialNo >= this.diffTotal) {
        this.over = true;
        this.won = this.right >= NEED;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
    }, 780);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'attentional_blink', solved: solved, score: this.right * 120,
      durationMs: Date.now() - this.startAt, levelReached: this.trialNo
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private answered(): boolean { return this.pick >= 0; }
  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.trialNo + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('间隔'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.pace() + 'ms')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        Text(this.showing && this.idx >= 0 ? this.seq[this.idx] : '·')
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
      }.width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) { Text(this.opts[(0)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (0) ? '#FFFFFF' : (this.answered() ? this.theme.inkFaint : this.theme.ink))
      .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
      .backgroundColor(this.pick === (0) ? Palette.primaryDeep : (this.answered() ? this.theme.surface : this.theme.surfaceAlt))
      .borderRadius(Radius.md).opacity(this.answered() && this.pick !== (0) ? 0.5 : 1).shadow(Shadow.card)
      .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((0)); }); })
      .onClick(() => { Haptics.tick(); this.answer((0)); }); Text(this.opts[(1)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (1) ? '#FFFFFF' : (this.answered() ? this.theme.inkFaint : this.theme.ink))
      .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
      .backgroundColor(this.pick === (1) ? Palette.primaryDeep : (this.answered() ? this.theme.surface : this.theme.surfaceAlt))
      .borderRadius(Radius.md).opacity(this.answered() && this.pick !== (1) ? 0.5 : 1).shadow(Shadow.card)
      .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((1)); }); })
      .onClick(() => { Haptics.tick(); this.answer((1)); }) }.width('100%')
      Row({ space: Space.sm }) { Text(this.opts[(2)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (2) ? '#FFFFFF' : (this.answered() ? this.theme.inkFaint : this.theme.ink))
      .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
      .backgroundColor(this.pick === (2) ? Palette.primaryDeep : (this.answered() ? this.theme.surface : this.theme.surfaceAlt))
      .borderRadius(Radius.md).opacity(this.answered() && this.pick !== (2) ? 0.5 : 1).shadow(Shadow.card)
      .scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((2)); }); })
      .onClick(() => { Haptics.tick(); this.answer((2)); }); Text(this.opts[(3)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (3) ? '#FFFFFF' : (this.answered() ? this.theme.inkFaint : this.theme.ink))
      .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
      .backgroundColor(this.pick === (3) ? Palette.primaryDeep : (this.answered() ? this.theme.surface : this.theme.surfaceAlt))
      .borderRadius(Radius.md).opacity(this.answered() && this.pick !== (3) ? 0.5 : 1).shadow(Shadow.card)
      .scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((3)); }); })
      .onClick(() => { Haptics.tick(); this.answer((3)); }) }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：数字只出现一次，其余字母都是干扰项')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}