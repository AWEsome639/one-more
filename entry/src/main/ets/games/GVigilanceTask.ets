/**
 * 警觉任务（vigilance_task）—— CPT：符号逐个闪现，只在看到 ◆ 时点按钮，其余一律忍住
 * 胜负：40 个刺激里命中 ≥6 且误报 ≤3 ⇒ 通关；进度：进度 / 命中 / 误报 / 漏报
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

const TARGET: string = '◆';
const OTHERS: string[] = ['●', '▲', '■', '★', '✚', '◇'];
const TOTAL: number = 40;
const ON_MS: number = 620;
const OFF_MS: number = 380;
const NEED_HIT: number = 6;
const MAX_FA: number = 3;

@Component
export struct GVigilanceTask {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
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
  @State idx: number = 0;
  @State visible: boolean = false;
  @State cur: string = '';
  @State hit: number = 0;
  @State fa: number = 0;
  @State miss: number = 0;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  @State pressing: boolean = false;
  private stream: string[] = [];
  private tapped: boolean = false;
  private startAt: number = 0;
  private to: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVigilanceTask')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.to >= 0) { clearTimeout(this.to); this.to = -1; } }

  private reset(): void {
    this.clearAll();
    this.idx = 0; this.visible = false; this.hit = 0; this.fa = 0; this.miss = 0;
    this.over = false; this.won = false; this.done = false; this.pressing = false;
    this.tapped = false; this.cur = '';
    this.msg = TG2('盯住屏幕：只有 {0} 要点，其它都别点', TARGET);
    // 目标固定 8~12 个（不是纯随机）：保证这一局一定拿得到通关线，其余位置全是干扰项
    const s: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) { s.push(OTHERS[Math.floor(Math.random() * OTHERS.length)]); }
    const nT: number = 8 + Math.floor(Math.random() * 5);
    for (let k = 0; k < nT; k++) {
      let p: number = Math.floor(Math.random() * this.diffTotal);
      while (s[p] === TARGET) { p = (p + 1) % this.diffTotal; }
      s[p] = TARGET;
    }
    this.stream = s;
    this.startAt = Date.now();
    this.to = setTimeout(() => { this.to = -1; this.show(); }, 900);
  }

  private show(): void {
    if (this.idx >= this.diffTotal) { this.finishUp(); return; }
    this.cur = this.stream[this.idx];
    this.visible = true;
    this.tapped = false;
    this.to = setTimeout(() => { this.to = -1; this.afterShow(); }, ON_MS);
  }

  private afterShow(): void {
    this.visible = false;
    if (this.stream[this.idx] === TARGET && !this.tapped) {
      this.miss = this.miss + 1;
      this.msg = TG2('😴 漏掉了一个 {0}', TARGET);
    }
    this.idx = this.idx + 1;
    this.to = setTimeout(() => { this.to = -1; this.show(); }, OFF_MS);
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
    if (!this.visible || this.cur !== TARGET || this.tapped) {
      return true;
    }
    this.strike();
    return !this.over;
  }

  /** 提示：现在这个符号要不要点 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    if (!this.visible) { return Hint.none('none'); }
    if (this.cur === TARGET) {
      return Hint.make([], TG('✅ 现在这个就是 ◆ —— 马上点'),
        'This is the target - tap now', t0);
    }
    return Hint.make([], TG2('忍住，{0} 不是目标', this.cur),
      'Not the target - hold', t0);
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

  private strike(): void {
    if (this.over || !this.visible) { return; }
    if (this.cur === TARGET) {
      if (this.tapped) { return; }
      this.tapped = true;
      this.hit = this.hit + 1;
      this.msg = TG('✅ 命中！');
      return;
    }
    this.fa = this.fa + 1;
    this.msg = TG('⚠️ 误报：这不是目标');
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.hit >= NEED_HIT && this.fa <= MAX_FA;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("命中 {0}",Digits(String(this.hit), this.langCode))
      + TG2(' · 误报 {0} · 漏报 {1}', String(this.fa), String(this.miss));
    this.clearAll();
    const r: GameResult = {
      gameId: 'vigilance_task', solved: this.won,
      score: this.hit * 120 - this.fa * 60 - this.miss * 30,
      durationMs: Date.now() - this.startAt, levelReached: this.hit
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
      Row({ space: Space.xs }) {
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hit), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.fa), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('漏报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Text(this.visible ? this.cur : '·').fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
        .fontColor(this.visible && this.cur === TARGET ? Palette.primary : this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%').height(148).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('已结束') : ('看到 ' + TARGET + ' 就点我'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.lg).fontColor('#FFFFFF').enabled(!this.over)
        .backgroundColor(this.over ? this.theme.lineSoft : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(64))
        .onTouch((e: TouchEvent) => { this.pressing = e.type === TouchType.Down; })
        .scale({ x: this.pressing ? Motion.pressScale : 1, y: this.pressing ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.strike(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.strike(); }); })

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primaryDeep).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：这一局考的是「忍住」—— 乱点扣分，漏掉也扣分'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
