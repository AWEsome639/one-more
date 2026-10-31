/**
 * 节奏大师 —— 🥁 先看 4 下示范拍，再照同样的间隔自己敲 4 下（id: rhythm_master）
 * 胜负：平均间隔误差 ≤ 150ms ⇒ 通关；进度：阶段 · 已敲 x/4 · 误差
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
import { Tv } from '../core/Tv';
const BEAT_MS: number = 600;
const DEMO: number = 4;
const TAPS: number = 4;
const WIN_ERR: number = 150;
const TAP_TIMEOUT: number = 9000;
@Component
export struct GRhythmMaster {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：原 BEAT_MS=600
  @State private diffTotal: number = GameDiff.timeNow(600);
  onFinish: (r: GameResult) => void = () => {};
  @State private phase: string = 'demo';
  @State private beat: number = 0;
  @State private pulse: boolean = false;
  @State private tapCount: number = 0;
  @State private errMs: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  /** 代打计时器（-1 = 未运行）。必须 @State，否则按钮文字不刷新 */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  /** 代打排好的敲击（setTimeout id 表） */
  private autoTos: number[] = [];
  private taps: number[] = [];
  private startAt: number = 0;
  private ivId: number = -1;
  private toId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GRhythmMaster')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(600);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); this.stopAuto(); }
  private clearAll(): void {
    if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  // ═══════════ AI 代打 / 提示（2026-10-28 第六批）═══════════
  // ★ 「什么时候敲」不能用节拍器：本作要的间隔 = diffTotal（简单 900 / 普通 600 / 困难 420），
  //   而 Hint.autoRun 固定 320ms 一拍 —— 直接按它敲就是 320ms 一拍 ⇒ 必然判负。
  //   ⇒ 代打只用通用节拍器决定"什么时候开始排期"，真正那几下用 setTimeout 排在
  //     base + diffTotal×k（base = 上一次敲击的时刻），精度只受 setTimeout 抖动影响
  //     （±16ms），远小于 150ms 的判定线。
  /** 示范还剩几拍（提示用） */
  private aiDemoLeft(): number {
    const left: number = DEMO - this.beat + 1;
    return left < 0 ? 0 : left;
  }

  /** 把还缺的拍子按目标间隔排好（base = 上一次敲击的时间；还没敲过就用现在） */
  private aiArm(): void {
    const now: number = Date.now();
    let base: number = now;
    if (this.taps.length > 0) {
      base = this.taps[this.taps.length - 1];
    }
    const need: number = TAPS - this.tapCount;
    for (let k = 1; k <= need; k++) {
      let delay: number = base + this.diffTotal * k - now;
      if (delay < 0) {
        delay = 0;
      }
      this.autoTos.push(setTimeout(() => { this.tapBeat(); }, delay));
    }
  }

  /**
   * 代打的一步（走通用的 Hint.autoRun 节拍，320ms 一次）：
   * 示范阶段只是等；一进「跟拍」就把剩下几下按目标间隔排上，然后等它们敲完。
   * ★ 320ms 的节拍器不会污染成绩 —— 真正的敲击时间由 aiArm 的 setTimeout 决定，
   *   节拍器只负责"什么时候开始排期"（晚一拍开始也不影响：成绩只看每两下之间的间隔）。
   */
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
    if (this.over || this.phase === 'done') {
      return false;
    }
    if (this.phase !== 'tap') {
      return true;                // 示范还没走完，等
    }
    if (this.autoTos.length > 0) {
      return true;                // 已经排好期了，等它们敲完
    }
    this.aiArm();
    return true;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    if (this.over) {
      Hint.toast(TG('这一局已经结束了 —— 点「再来一局」'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      clearInterval(this.autoId);
      this.autoId = -1;
    }
    for (let i = 0; i < this.autoTos.length; i++) {
      clearTimeout(this.autoTos[i]);
    }
    this.autoTos = [];
  }

  /** 提示：报目标间隔；已经敲了几下的话报「你现在平均多少、偏快还是偏慢」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 'demo') {
      return Hint.make([], TG2('先看示范：每 {0} ms 一下，还剩 {1} 拍', this.diffTotal, this.aiDemoLeft()),
        TG2('Watch the demo: one beat every {0} ms, {1} beats left', this.diffTotal, this.aiDemoLeft()), t0);
    }
    if (this.phase !== 'tap') {
      return Hint.none('none');
    }
    if (this.taps.length < 2) {
      return Hint.make([], TG2('目标是每 {0} ms 敲一下，跟着刚才示范的节奏', this.diffTotal),
        TG2('Tap once every {0} ms', this.diffTotal), t0);
    }
    let sum: number = 0;
    for (let i = 1; i < this.taps.length; i++) {
      sum = sum + (this.taps[i] - this.taps[i - 1]);
    }
    const avg: number = Math.round(sum / (this.taps.length - 1));
    const fast: boolean = avg < this.diffTotal;
    return Hint.make([], TG2('你现在平均 {0} ms/下，目标 {1} ms —— {2}', avg, this.diffTotal,
      fast ? TG('偏快了，放慢一点') : TG('偏慢了，加快一点')),
      TG2('You average {0} ms, target {1} ms — {2}', avg, this.diffTotal, fast ? 'too fast' : 'too slow'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private reset(): void {
    this.clearAll();
    this.stopAuto();
    this.beat = 1; this.pulse = true; this.tapCount = 0; this.errMs = -1;
    this.over = false; this.won = false; this.done = false; this.taps = [];
    this.startAt = Date.now(); this.phase = 'demo';
    this.msg = TG2('看节奏：每 {0} ms 一下', String(this.diffTotal));
    this.ivId = setInterval(() => {
      this.beat = this.beat + 1;
      this.pulse = !this.pulse;
      if (this.beat > DEMO) {
        if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
        this.phase = 'tap'; this.pulse = false; this.taps = [];
        this.msg = TG2("轮到你了：照刚才的间隔敲 {0} 下", String(TAPS));
        this.toId = setTimeout(() => { this.toId = -1; this.timeout(); }, TAP_TIMEOUT);
      }
    }, this.diffTotal);
  }
  private timeout(): void {
    if (this.phase !== 'tap') { return; }
    this.phase = 'done'; this.over = true; this.won = false; this.errMs = TAP_TIMEOUT;
    this.msg = TG2("💤 超时，没敲满 {0} 下", String(TAPS));
    this.end();
  }
  private tapBeat(): void {
    if (this.phase !== 'tap') { return; }
    this.taps.push(Date.now());
    this.tapCount = this.taps.length;
    if (this.tapCount < TAPS) {
      this.msg = TG2("第 {0} 下 · 别停", String(this.tapCount));
      return;
    }
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
    let sum: number = 0;
    for (let i = 1; i < this.taps.length; i++) {
      const gap: number = this.taps[i] - this.taps[i - 1];
      sum = sum + Math.abs(gap - this.diffTotal);
    }
    const err: number = Math.round(sum / (TAPS - 1));
    this.errMs = err; this.phase = 'done'; this.over = true; this.won = err <= WIN_ERR;
    this.msg = TG2(this.won ? '🎉 稳！平均误差 {0}' : '💤 飘了，平均误差 {0}', String(err)) + ' ms';
    this.end();
  }
  private end(): void {
    if (this.done) { return; }
    const err: number = this.errMs < 0 ? TAP_TIMEOUT : this.errMs;
    this.clearAll();
    this.done = true;
    const r: GameResult = {
      gameId: 'rhythm_master', solved: this.won, score: Math.max(0, 400 - err) * 3,
      durationMs: Date.now() - this.startAt, levelReached: this.tapCount
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
        Column({ space: Space.xs }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'demo' ? '示范' : (this.phase === 'tap' ? '跟拍' : TG('结束')))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已敲'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.tapCount) + '/' + String(TAPS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('误差'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.errMs >= 0 ? String(this.errMs) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('🥁').fontSize(FontSize.hero)
          .accessibilityLevel('no')
          .scale({ x: this.pulse ? 1.3 : 1, y: this.pulse ? 1.3 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(this.phase === 'demo' ? TG('第 ') + String(this.beat) + ' 拍' : '目标间隔 ' + String(this.diffTotal) + ' ms')
          .fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').height(140).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Button(TG('敲一下'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF')
        .backgroundColor(this.phase === 'tap' ? Palette.violet : this.theme.lineSoft)
        .borderRadius(Radius.lg).width('100%').height(Cell.of(84))
        .onClick(() => { Haptics.tap(); this.tapBeat(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tapBeat(); }); })
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：4 下平均间隔误差 ≤ 150 ms（目标间隔 600 ms）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
