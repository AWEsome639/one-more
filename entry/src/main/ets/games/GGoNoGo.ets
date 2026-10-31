/**
 * 去或停（Go / No-Go）—— 绿灯要快点，红灯要忍住
 * 胜负：20 试里正确 ≥ 17 且误点 ≤ 1 ⇒ 通关；进度：试次 / 正确 / 误点
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
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

const TRIALS: number = 20;
const WINDOW: number = 1000;      // 反应窗口
const NOGO_RATE: number = 0.25;
const NEED_CORRECT: number = 17;
const MAX_FA: number = 1;

@Component
export struct GGoNoGo {
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

  @State private kind: number = 0;        // 0 绿灯 1 红灯
  @State private live: boolean = false;
  @State private trialNo: number = 1;
  @State private hitN: number = 0;        // 绿灯按了
  @State private missN: number = 0;       // 绿灯没按
  @State private faN: number = 0;         // 红灯按了
  @State private crN: number = 0;         // 红灯忍住
  @State private fbMark: number = 0;      // 0 无 1 对 2 错
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private shownAt: number = 0;
  private waitTo: number = -1;
  private closeTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GGoNoGo')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.closeTo >= 0) { clearTimeout(this.closeTo); this.closeTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
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
    if (!this.live) {
      return true;
    }
    this.aiReact(0);
    return !this.over;
  }

  /** 提示：绿灯按、红灯忍 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (!this.live) {
      return Hint.make([], TG('等灯亮：绿灯要马上按，红灯别动'),
        TG('Wait for the light: press on green, hold on red'), t0);
    }
    if (this.kind === 0) {
      return Hint.make([], TG('🟢 绿灯 —— 现在按！'), TG('🟢 Green — press now!'), t0);
    }
    return Hint.make([], TG('🔴 红灯 —— 千万别按'), TG('🔴 Red — do not press'), t0);
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

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.hitN = 0; this.missN = 0; this.faN = 0; this.crN = 0;
    this.fbMark = 0; this.live = false;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('绿灯点、红灯忍');
    this.startAt = Date.now();
    this.schedule();
  }

  /** 随机等 0.6~1.4 秒亮灯，亮 1 秒内必须作出反应 */
  private schedule(): void {
    this.live = false;
    this.fbMark = 0;
    this.msg = TG('准备…');
    this.kind = Math.random() < NOGO_RATE ? 1 : 0;
    this.waitTo = setTimeout(() => {
      this.waitTo = -1;
      this.shownAt = Date.now();
      this.live = true;
      this.msg = this.kind === 0 ? '🟢 快按！' : '🔴 别动！';
      this.closeTo = setTimeout(() => { this.closeTo = -1; this.resolve(false); }, WINDOW);
    }, 600 + Math.floor(Math.random() * 800));
  }

  private tap(): void {
    if (this.over || !this.live) { return; }
    if (this.closeTo >= 0) { clearTimeout(this.closeTo); this.closeTo = -1; }
    this.resolve(true);
  }

  private resolve(pressed: boolean): void {
    this.live = false;
    const isGo: boolean = this.kind === 0;
    if (isGo && pressed) {
      this.hitN = this.hitN + 1; this.fbMark = 1;
      this.msg = '✅ ' + String(Date.now() - this.shownAt) + ' ms';
    } else if (isGo) {
      this.missN = this.missN + 1; this.fbMark = 2;
      this.msg = TG('❌ 绿灯要按的');
    } else if (pressed) {
      this.faN = this.faN + 1; this.fbMark = 2;
      this.msg = TG('🚫 红灯不该按');
    } else {
      this.crN = this.crN + 1; this.fbMark = 1;
      this.msg = TG('🛑 忍住了');
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.trialNo >= this.diffTotal) { this.judge(); return; }
      this.trialNo = this.trialNo + 1;
      this.schedule();
    }, 620);
  }

  private correctN(): number {
    return this.hitN + this.crN;
  }

  private judge(): void {
    this.clearAll();
    this.over = true;
    this.won = this.correctN() >= NEED_CORRECT && this.faN <= MAX_FA;
    this.msg = TG2(this.won ? '🎉 通关！正确 {0}/{1}' : '💤 结束，正确 {0}/{1}', String(this.correctN()),Digits(String(this.diffTotal), this.langCode))
      + TG2(' · 误点 {0} 次',Digits(String(this.faN), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'go_no_go', solved: this.won,
        score: Math.max(0, this.correctN() * 60 - this.faN * 120),
        durationMs: Date.now() - this.startAt, levelReached: this.correctN()
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  /** AI 用：绿灯就按，红灯不动（灯没亮就等） */
  private aiReact(_d: number): void {
    if (!this.live) { return; }
    if (this.kind === 0) { this.tap(); }
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
        Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.over ? this.diffTotal : this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('正确'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.correctN()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('误点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.faN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(this.live ? (this.kind === 0 ? '🟢' : '🔴') : (this.over ? (this.won ? '🎉' : '💤') : '👀'))
          .fontSize(FontSize.hero)
          .scale({ x: this.live ? 1.1 : 1, y: this.live ? 1.1 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }.width('100%').height(Space.xxxl * 2).justifyContent(FlexAlign.Center)
      .backgroundColor(this.fbMark === 1 ? '#1A10B981' : (this.fbMark === 2 ? '#1AEF4444' : this.theme.surface))
      .borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(TG('点！')).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl * 2)
        .backgroundColor(this.live && this.kind === 0 ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.lg).opacity(this.live ? 1 : 0.5)
        .scale({ x: this.fbMark === 2 ? Motion.pressScale : 1, y: this.fbMark === 2 ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(); }); })
        .onClick(() => { Haptics.tick(); this.tap(); })

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('判定：正确 ≥ {0}/{1}', String(NEED_CORRECT), String(this.diffTotal))
        + TG2(' 且误点 ≤ {0} 次 · 红灯约四分之一',Digits(String(MAX_FA), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
