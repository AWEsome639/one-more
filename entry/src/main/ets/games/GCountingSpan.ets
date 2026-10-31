/**
 * 计数广度 —— 边数边记：数完每张卡的黄点数，再按顺序回忆
 * 胜负：全对且张数到 5 通关，2 条命用完判负　｜　进度：张数 / 最长 / 生命
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const DOTS: number = 9;
const MAX_COUNT: number = 5;
const START_SPAN: number = 2;
const WIN_SPAN: number = 5;
const LIVES: number = 2;
const PER_CARD: number = 100;

@Component
export struct GCountingSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：DOTS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(DOTS);
  onFinish: (r: GameResult) => void = () => {};

  @State counts: number[] = [];
  @State dots: boolean[] = [];
  @State cardIdx: number = 0;
  @State recallIdx: number = 0;
  @State span: number = START_SPAN;
  @State best: number = 0;
  @State life: number = LIVES;
  @State phase: number = 0;      // 0=数卡 1=回忆 2=结束
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCountingSpan')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(DOTS);
     this.reset(); }

  private reset(): void {
    this.span = START_SPAN; this.best = 0; this.life = LIVES;
    this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now();
    this.startRound();
  }

  private startRound(): void {
    const cs: number[] = [];
    for (let i = 0; i < this.span; i++) { cs.push(1 + Math.floor(Math.random() * MAX_COUNT)); }
    this.counts = cs;
    this.cardIdx = 0;
    this.recallIdx = 0;
    this.phase = 0;
    this.msg = TG('数出每张卡有几个黄点，别写下来');
    this.deal();
  }

  /** 当前卡上随机铺 n 个黄点（n = 该卡真实计数） */
  private deal(): void {
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) { pool.push(i); }
    for (let k = pool.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: number = pool[k];
      pool[k] = pool[j];
      pool[j] = tmp;
    }
    const cells: boolean[] = [];
    for (let i = 0; i < this.diffTotal; i++) { cells.push(false); }
    const n: number = this.counts[this.cardIdx];
    for (let i = 0; i < n; i++) { cells[pool[i]] = true; }
    this.dots = cells;
  }

  private nextCard(): void {
    if (this.phase !== 0 || this.over) { return; }
    if (this.cardIdx + 1 < this.span) {
      this.cardIdx++;
      this.deal();
      return;
    }
    this.phase = 1;
    this.recallIdx = 0;
    this.msg = TG2('第 1 / {0} 张有几个黄点？', this.span);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 两个阶段：0=数卡（要点「数好了，下一张」）1=回忆（答案 = counts[recallIdx]）
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
    if (this.phase === 0) {
      this.nextCard();                 // 数完这张 ⇒ 翻下一张 / 进回忆
      return true;
    }
    if (this.phase !== 1 || this.recallIdx >= this.counts.length) {
      return true;                     // 等过渡（换局 / 结算）
    }
    this.answerCount(this.counts[this.recallIdx]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 0) {
      const n: number = this.counts[this.cardIdx];
      return Hint.make([],
        TG2('这张卡上有 {0} 个黄点，记住它再点「数好了，下一张」', String(n)),
        'This card has ' + String(n) + ' dots', t0);
    }
    if (this.phase !== 1 || this.recallIdx >= this.counts.length) {
      return Hint.none('none');
    }
    const truth: number = this.counts[this.recallIdx];
    return Hint.make([truth],
      TG2('第 {0} 张卡是 {1} 个黄点', String(this.recallIdx + 1), String(truth)),
      'Card ' + String(this.recallIdx + 1) + ' has ' + String(truth) + ' dots', t0);
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

  private answerCount(k: number): void {
    if (this.phase !== 1 || this.over) { return; }
    const truth: number = this.counts[this.recallIdx];
    if (k === truth) {
      this.recallIdx++;
      if (this.recallIdx >= this.span) {
        this.best = this.span;
        if (this.best >= WIN_SPAN) { this.end(true); return; }
        this.span++;
        this.msg = TG2('✅ 全对！张数升到 {0}', this.span);
        this.startRound();
        return;
      }
      this.msg = TG2("✅ 第 {0} / {1} 张有几个黄点？", (this.recallIdx + 1), this.span);
      return;
    }
    this.life--;
    if (this.life <= 0) { this.end(false); return; }
    this.msg = TG2("❌ 那一张是 {0} 个，还剩 {1} 条命", truth,Digits(String(this.life), this.langCode));
    this.startRound();
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.phase = 2;
    this.msg = TG2("{0}{1} 张", (solved ? '🎉 通关：一口气记住 ' : '最长记住 '), this.best);
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'counting_span', solved: solved, score: this.best * PER_CARD,
      durationMs: Date.now() - this.startAt, levelReached: this.best
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
        Column({ space: 2 }) {
        Text((TG('张数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最长'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.best), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + ' / ' + LIVES)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Text('●').accessibilityLevel('no').fontSize(FontSize.xl)
              .fontColor(this.dots.length > (r * 3 + c) && this.dots[(r * 3 + c)] ? Palette.amber : this.theme.lineSoft)
              }.layoutWeight(1).aspectRatio(1)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.md)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      if (this.phase === 0) {
        Button(TG2('数好了，下一张（{0} / {1}）', (this.cardIdx + 1), this.span))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.amber)
          .borderRadius(Radius.md).width('100%').height(Cell.of(48))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.nextCard(); }); })
          .onClick(() => { Haptics.tap(); this.nextCard(); })
      } else {
        Row({ space: Space.xs }) {
          ForEach([1, 2, 3, 4, 5], (k: number) => {
            Button(String((k)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(Palette.primary)
            .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(52)).enabled(this.phase === 1)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answerCount((k)); }); })
            .onClick(() => { Haptics.tap(); this.answerCount((k)); })
          }, (k: number) => 'n' + k)
        }.width('100%')
      }

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('张数升到 {0} 即通关；黄点 1~5 个不等',Digits(String(WIN_SPAN), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
