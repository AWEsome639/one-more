/**
 * 选择反应 —— 数字一亮就按「奇」或「偶」，测平均反应时
 * 胜负：10 题平均 < 900ms 且答错不超过 1 次 ⇒ 通关；进度：题号 / 平均 / 最快
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

const ROUNDS: number = 10;
const LIMIT_MS: number = 900;
const MAX_WAIT: number = 2200;

@Component
export struct GChoiceReactionTime {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private val: number = 0;
  @State private live: boolean = false;     // 刺激是否已出现
  @State private round: number = 1;
  @State private total: number = 0;         // 累计毫秒（答错按 1800ms 计）
  @State private best: number = 0;
  @State private wrong: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private waitTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GChoiceReactionTime')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 1; this.total = 0; this.best = 0; this.wrong = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.live = false;
    this.startAt = Date.now();
    this.arm();
  }
  /** 随机等 0.7~2.2 秒再亮出数字 */
  private arm(): void {
    this.live = false;
    this.pick = -1;
    this.msg = TG('准备… 数字一出现就按');
    this.waitTo = setTimeout(() => {
      this.waitTo = -1;
      this.val = 10 + Math.floor(Math.random() * 90);
      this.shownAt = Date.now();
      this.live = true;
      this.msg = TG('是奇数还是偶数？');
    }, 700 + Math.floor(Math.random() * (MAX_WAIT - 700)));
  }
  private avg(): number {
    const doneN: number = this.round - 1;
    return doneN > 0 ? Math.round(this.total / doneN) : 0;
  }
  /** 提示：报「是 / 否」——代打用的表达式算出来是它 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const truth: boolean = this.val % 2 === 0;
    return Hint.make([],
      truth ? TG('答案是「是」') : TG('答案是「否」'),
      truth ? TG('The answer is Yes') : TG('The answer is No'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔现算：this.val % 2 === 0
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
    if (this.over || !this.live || this.pick >= 0) {
      return true;
    }
    const rt: number = Date.now() - this.shownAt;
    this.answer(this.val % 2 === 0);
    return !this.over;
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

  private answer(saidEven: boolean): void {
    if (this.over || !this.live || this.pick >= 0) { return; }
    const rt: number = Date.now() - this.shownAt;
    const isEven: boolean = this.val % 2 === 0;
    this.pick = saidEven ? 1 : 0;
    this.live = false;
    if (saidEven === isEven) {
      this.total = this.total + rt;
      if (this.best === 0 || rt < this.best) { this.best = rt; }
      this.msg = '✅ ' + String(rt) + ' ms';
    } else {
      this.total = this.total + LIMIT_MS * 2;
      this.wrong = this.wrong + 1;
      this.msg = TG2("❌ {0} 是{1}，这题按 {2} ms 计", String(this.val), (isEven ? '偶数' : TG('奇数')), String(LIMIT_MS * 2));
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        const a: number = this.avg();
        this.over = true;
        this.won = a < LIMIT_MS && this.wrong <= 1;
        this.msg = TG2("{0}平均 {1} ms · 错 {2} 次", (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')), String(a),Digits(String(this.wrong), this.langCode));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.arm();
    }, 560);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const avg: number = this.avg();
    const r: GameResult = {
      gameId: 'choice_reaction_time', solved: solved, score: Math.max(0, LIMIT_MS * 2 - avg) * 2,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.avg() > 0 ? this.avg() + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最快'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.best > 0 ? this.best + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.live ? String(this.val) : '👀').fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.live ? Palette.orange : this.theme.inkFaint)
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }.width('100%').height(170).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.md }) {
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
        Button(TG('奇'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 0 ? Palette.primaryDeep : Palette.orange)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(78)).opacity(this.live ? 1 : 0.55)
          .scale({ x: this.pick === 0 ? Motion.pressScale : 1, y: this.pick === 0 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(false); }); })
          .onClick(() => { Haptics.tap(); this.answer(false); })
        Button(TG('偶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 1 ? Palette.primaryDeep : Palette.sky)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(78)).opacity(this.live ? 1 : 0.55)
          .scale({ x: this.pick === 1 ? Motion.pressScale : 1, y: this.pick === 1 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(true); }); })
          .onClick(() => { Haptics.tap(); this.answer(true); })
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('判定：平均 < {0} ms 且答错 ≤ 1 次（答错一题按 1800 ms 计）',Digits(String(LIMIT_MS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}