/**
 * 分配注意 —— 左右两路符号同时跳变，哪边出现 🎯 就点哪边
 *
 * 胜负：12 拍里命中 ≥7 且误报 ≤2 ⇒ 通关
 * 进度：拍数 / 命中 / 误报 / 漏报
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
const TICKS: number = 12; const PACE: number = 1100; const TARGET: string = '🎯';
const DECOYS: string[] = ['🍀', '⭐', '🔷', '🌙', '🔺', '🎈', '🧩', '⚡'];
interface Side {
  sym: string;
  on: boolean;     // 这一拍是不是靶
  done: boolean;   // 这一拍已经点过
}
@Component
export struct GDividedAttention {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TICKS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TICKS);
  onFinish: (r: GameResult) => void = () => {};
  @State private left: Side = { sym: '·', on: false, done: false };
  @State private right: Side = { sym: '·', on: false, done: false };
  @State private tickNo: number = 0;
  @State private hits: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  @State private fa: number = 0;
  @State private miss: number = 0;
  /** ★ 2026-10-15 错误抖动 */
  @State private shakeX: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private timer: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDividedAttention')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TICKS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.stop(); this.hits = 0; this.fa = 0; this.miss = 0; this.over = false; this.won = false;
    this.done = false; this.tickNo = 1; this.left = this.roll(); this.right = this.roll();
    this.msg = TG('两边一起看：出现 🎯 就点那一边'); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, PACE);
  }
  private roll(): Side {
    const isOn: boolean = Math.random() < 0.42;
    const sym: string = isOn ? TARGET : DECOYS[Math.floor(Math.random() * DECOYS.length)];
    const made: Side = { sym: sym, on: isOn, done: false };
    return made;
  }
  private tick(): void {
    if (this.over) { return; }
    let missCount: number = this.miss;
    if (this.left.on && !this.left.done) { missCount = missCount + 1; }
    if (this.right.on && !this.right.done) { missCount = missCount + 1; }
    this.miss = missCount; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.tickNo >= this.diffTotal) {
      this.finish();
      return;
    }
    this.tickNo = this.tickNo + 1; this.left = this.roll(); this.right = this.roll();
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
    if (!(this.left.on && !this.left.done) && !(this.right.on && !this.right.done)) {
      return true;
    }
    this.tap((this.left.on && !this.left.done) ? 0 : 1);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const l: boolean = this.left.on && !this.left.done;
    const r: boolean = this.right.on && !this.right.done;
    if (!l && !r) {
      return Hint.none('none');
    }
    if (l && r) {
      return Hint.make([0, 1],
        TG('左右两边这一拍都是 🎯，两边都要点'),
        TG('Both sides show 🎯 this beat — tap both'), t0);
    }
    if (l) {
      return Hint.make([0], TG('左边这一拍是 🎯，点左边'), TG('The left side is 🎯 — tap it'), t0);
    }
    return Hint.make([1], TG('右边这一拍是 🎯，点右边'), TG('The right side is 🎯 — tap it'), t0);
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

  private tap(idx: number): void {
    if (this.over || this.tickNo === 0) { return; }
    const side: Side = idx === 0 ? this.left : this.right;
    if (side.done) { return; }
    const next: Side = { sym: side.sym, on: side.on, done: true };
    if (idx === 0) { this.left = next; } else { this.right = next; }
    if (side.on) {
      this.hits = this.hits + 1; this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
    } else {
      this.fa = this.fa + 1;
    }
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.stop(); this.over = true; this.won = this.hits >= 7 && this.fa <= 2;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG2('命中 {0} · 误报 {1} · 漏报 {2}',Digits(String(this.hits), this.langCode),Digits(String(this.fa), this.langCode),Digits(String(this.miss), this.langCode));
    const raw: number = this.hits * 100 - this.fa * 40 - this.miss * 30; const r: GameResult = {
      gameId: 'divided_attention', solved: this.won,
      score: raw > 0 ? raw : 0, durationMs: Date.now() - this.startAt,
      levelReached: this.hits
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
        Text((TG('拍数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.tickNo) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hits), this.langCode)).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.fa), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('漏报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.md)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
        Text(true ? TG('左') : TG('右')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.left).sym).fontSize(FontSize.hero).fontColor(Palette.rose)
        Text((this.left).done ? ((this.left).on ? '✔ 点对了' : '✘ 误报') : ' ').fontSize(FontSize.xxs).fontColor((this.left).done && (this.left).on ? Palette.success : Palette.danger)
        }.layoutWeight(1).aspectRatio(0.86).justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface).borderRadius(Radius.lg).borderWidth(2)
        .borderColor((this.left).done ? ((this.left).on ? Palette.success : Palette.danger) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((0)); }); }).onClick(() => { Haptics.tick(); this.tap((0)); })
        Column({ space: Space.xs }) {
        Text(false ? TG('左') : TG('右')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right).sym).fontSize(FontSize.hero).fontColor(Palette.rose)
        Text((this.right).done ? ((this.right).on ? '✔ 点对了' : '✘ 误报') : ' ').fontSize(FontSize.xxs).fontColor((this.right).done && (this.right).on ? Palette.success : Palette.danger)
        }.layoutWeight(1).aspectRatio(0.86).justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface).borderRadius(Radius.lg).borderWidth(2)
        .borderColor((this.right).done ? ((this.right).on ? Palette.success : Palette.danger) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((1)); }); }).onClick(() => { Haptics.tick(); this.tap((1)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：只点 🎯 那一边；点错和漏掉都扣分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
