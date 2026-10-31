/**
 * 反向斯特鲁普 —— 🧠 字用别的颜色印出来，请点「字义」而不是墨色（id: reverse_stroop）
 * 胜负：12 题答对 ≥ 10 且平均 < 1800ms ⇒ 通关；进度：题号/12 · 答对 · 平均
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
const TOTAL: number = 12;
const WIN_RIGHT: number = 10;
const WIN_AVG: number = 1800;
const WORDS: string[] = [TG('红'), TG('蓝'), TG('绿'), TG('黄')];
const INKS: string[] = ['#EF4444', '#3B82F6', '#10B981', '#F59E0B'];
@Component
export struct GReverseStroop {
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
  @State private wIdx: number = 0;
  @State private kIdx: number = 1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private totalMs: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private toId: number = -1;
  private done: boolean = false;
  private answered: number = 0;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GReverseStroop')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearTo(); }
  private clearTo(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearTo();
    this.round = 1; this.right = 0; this.wrong = 0; this.totalMs = 0; this.pick = -1; this.answered = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.next();
  }
  /** 出题：字义与墨色必然不同 */
  private next(): void {
    const w: number = Math.floor(Math.random() * WORDS.length);
    let k: number = Math.floor(Math.random() * INKS.length);
    if (k === w) { k = (k + 1) % INKS.length; }
    this.wIdx = w; this.kIdx = k; this.pick = -1; this.shownAt = Date.now();
    this.msg = TG('点「字义」，别看墨色');
  }
  private avg(): number {
    return this.answered > 0 ? Math.round(this.totalMs / this.answered) : 0;
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
    if (this.pick >= 0) {
      return true;
    }
    this.answer(this.wIdx);
    return !this.over;
  }

  /** 提示：直接报那个字/色 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.pick >= 0) {
      return Hint.none('none');
    }
    return Hint.make([this.wIdx], TG2('要找的是「{0}」', WORDS[this.wIdx]),
      TG2('Look for {0}', WORDS[this.wIdx]), t0);
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

  private answer(i: number): void {
    if (this.over || this.pick >= 0) { return; }
    const w: number = this.wIdx;
    const ok: boolean = i === w;
    this.totalMs = this.totalMs + (Date.now() - this.shownAt); this.answered = this.answered + 1;
    this.pick = i;
    if (ok) {
      this.right = this.right + 1;
      this.msg = TG('✅ 对');
    } else {
      this.wrong = this.wrong + 1;
      this.msg = TG2('❌ 字是「{0}」', WORDS[w]);
    }
    this.toId = setTimeout(() => {
      this.toId = -1;
      if (this.round >= this.diffTotal) { this.end(); return; }
      this.round = this.round + 1;
      this.next();
    }, 520);
  }
  private end(): void {
    if (this.done) { return; }
    const a: number = this.avg();
    this.clearTo();
    this.done = true; this.over = true; this.won = this.right >= WIN_RIGHT && a < WIN_AVG;
    this.msg = (this.won ? TG('🎉 通关 · 对 ') : TG('💤 结束 · 对 ')) +TG2("{0}/{1} · 平均 {2} ms", String(this.right), String(this.diffTotal), String(a));
    const r: GameResult = {
      gameId: 'reverse_stroop', solved: this.won, score: Math.max(0, this.right * 100 - Math.round(a / 20)),
      durationMs: Date.now() - this.startAt, levelReached: this.right
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.avg() > 0 ? String(this.avg()) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('点「字义」· 别看墨色')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(WORDS[this.wIdx]).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(INKS[this.kIdx])
      }.width('100%').height(150).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Text(WORDS[(i)]).fontSize(FontSize.lg).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(72)).borderRadius(Radius.md)
          .backgroundColor(this.pick === (i) && (i) !== this.wIdx ? Palette.primaryDeep : INKS[(i)])
          .opacity(this.pick >= 0 && (i) !== this.wIdx && (i) !== this.pick ? 0.45 : 1)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
          .onClick(() => { Haptics.tick(); this.answer((i)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((i)); }); })
        }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：12 题答对 ≥ 10 且平均 < 1800 ms'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
