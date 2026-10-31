/**
 * 威斯康星卡片分类 —— 按隐藏规则把卡片归堆，连对 4 次规则就会悄悄换掉
 * 规则藏在「颜色 / 形状 / 数量」三者之一；参考堆 i 的三个特征都是 i
 * 胜负：18 试次答对 ≥12 ⇒ 通关｜进度：试次 / 答对 / 连对
 */
import { A11y } from '../core/A11y';
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

const TRIALS: number = 18; const PASS: number = 12; const SWITCH_AT: number = 4; const FEED_MS: number = 420;
const FOUR: number[] = [0, 1, 2, 3];
const SHAPES: string[] = ['●', '▲', '■', '★'];
const COLORS: string[] = [Palette.rose, Palette.sky, Palette.emerald, Palette.amber];
const MARKS: string[] = ['①', '②', '③', '④'];

@Component
export struct GWisconsinCardSorting {
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

  @State deckShape: number = 0; @State deckColor: number = 0; @State deckCount: number = 1;
  @State rule: number = 0;
  @State trial: number = 1; @State right: number = 0; @State streak: number = 0;
  @State score: number = 0; @State msg: string = ''; @State good: boolean = false;
  @State locked: boolean = false; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWisconsinCardSorting')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop();
    this.rule = 0; this.trial = 1; this.right = 0; this.streak = 0; this.score = 0;
    this.locked = false; this.over = false; this.won = false; this.done = false;
    this.good = false; this.msg = TG('开局先按「颜色」归类');
    this.startAt = Date.now(); this.deal();
  }
  private deal(): void {
    this.deckColor = Math.floor(Math.random() * 4);
    this.deckShape = Math.floor(Math.random() * 4);
    this.deckCount = 1 + Math.floor(Math.random() * 4);
  }
  /** 当前规则下这张牌该进哪一堆 */
  private correctPile(): number {
    if (this.rule === 0) { return this.deckColor; }
    if (this.rule === 1) { return this.deckShape; }
    return this.deckCount - 1;
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
    if (this.locked) {
      return true;
    }
    this.put(this.correctPile());
    return !this.over;
  }

  /** 提示：该放哪一堆 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.locked || this.over) {
      return Hint.none('none');
    }
    const p: number = this.correctPile();
    return Hint.make([p], TG2('放到第 {0} 堆', String(p + 1)),
      TG2('Put it on pile {0}', String(p + 1)), t0);
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

  private put(pile: number): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    const ok: boolean = pile === this.correctPile();
    if (ok) { this.right = this.right + 1; this.streak = this.streak + 1; this.score = this.score + 50; }
    else { this.streak = 0; this.score = this.score > 10 ? this.score - 10 : 0; }
    if (ok && this.streak >= SWITCH_AT) {
      this.rule = (this.rule + 1) % 3; this.streak = 0; this.good = false;
      this.msg = TG('⚠️ 连对 4 次 —— 规则悄悄换了');
    } else {
      this.good = ok; this.msg = ok ? '✅ 放对了 +50' : '❌ 这一堆放错了 -10';
    }
    this.trial = this.trial + 1;
    if (this.trial > this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.locked = false; this.deal(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'wisconsin_card_sorting', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
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
        Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trial + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.teal))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('连对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.streak), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('当前这张牌')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          // ★ 色盲辅助（项目 D ③）：颜色是「颜色/形状/数量」三维里唯一没被文字化的 ⇒ 补一个颜色字母
          //   ⚠️ 这里不是色块：颜色涂在形状字的 fontColor 上，底色是 surfaceAlt（浅色）
          //      ⇒ 白字 + 阴影在浅底上等于看不见，所以用 theme.ink 深色粗体
          //   ⚠️ 加 chip 底色：让它明显是"标签"，不会被误数成图形的个数
          Text(A11y.glyph(this.deckColor))
            .fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            .padding({ left: Space.xs, right: Space.xs }).backgroundColor(this.theme.surface).borderRadius(Radius.xs)
          ForEach(FOUR, (k: number) => {
            Text((k) < (this.deckCount) ? SHAPES[(this.deckShape)] : '').fontSize(FontSize.lg).fontColor(COLORS[(this.deckColor)])
          }, (k: number) => 'd' + k)
        }.justifyContent(FlexAlign.Center).padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%')
      Text(TG('放进哪一堆？')).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(FOUR, (i: number) => {
          Column({ space: Space.xs }) {
          Row({ space: Space.xs }) {
          ForEach(FOUR, (k: number) => {
          Text((k) < ((i) + 1) ? SHAPES[((i))] : '').fontSize(FontSize.lg).fontColor(COLORS[((i))])
          }, (k: number) => 'g' + k)
          }.justifyContent(FlexAlign.Center).height(Cell.of(30))
          // ★ 色盲辅助（项目 D ③）：第 i 堆的颜色就是 COLORS[i] ⇒ 标一个同款字母，和卡片上的字母直接对照
          Row({ space: Space.xs }) {
            Text(A11y.glyph(i)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            Text(MARKS[(i)]).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
          }
          }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md)
          .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.put((i)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put((i)); }); })
        }, (i: number) => 'p' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose)
          : (this.good ? Palette.emerald : this.theme.inkSoft))
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：规则只认颜色 / 形状 / 数量之一，连对 4 次就换')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


  /** 一张卡的第 slot 个图形（不足 count 个就留空） */

  /** 参考堆 i：颜色 / 形状 / 数量三个特征都取 i */

}
