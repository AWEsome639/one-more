/**
 * 空间提示 —— 中心注视后先给一个方位提示，目标出现时尽快点它所在的一侧（测反应）
 * 胜负：16 次答对 ≥ 12 ⇒ 通关（越快分越高）　｜　进度：试次 / 答对 / 平均反应
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

const TRIALS: number = 16;
const PASS: number = 12;
const FIX_MS: number = 450;
const CUE_MS: number = 400;
const FEED_MS: number = 380;
const VALID_P: number = 0.75;
const MAX_BONUS: number = 120;

@Component
export struct GPosnerSpatialCueing {
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
  @State phase: number = 0;        // 0 注视　1 提示　2 目标　3 反馈
  @State cueSide: number = 0; @State targetSide: number = 0; @State pickSide: number = -1;
  @State trial: number = 1; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private rtSum: number = 0; private answered: number = 0; private shownAt: number = 0;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPosnerSpatialCueing')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private avgRt(): number { return this.answered > 0 ? Math.round(this.rtSum / this.answered) : 0; }

  private reset(): void {
    this.clearAll();
    this.trial = 1; this.right = 0; this.score = 0; this.pickSide = -1; this.startAt = Date.now();
    this.rtSum = 0; this.answered = 0;
    this.over = false; this.won = false; this.done = false;
    this.newTrial();
  }

  private newTrial(): void {
    const side: number = Math.random() < 0.5 ? 0 : 1;
    this.targetSide = side;
    const valid: boolean = Math.random() < VALID_P;
    this.cueSide = valid ? side : 1 - side;
    this.pickSide = -1; this.phase = 0;
    this.msg = TG2("第 {0} 次：盯住中间的 ➕",Digits(String(this.trial), this.langCode));
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1;
      this.msg = TG2("{0}（提示不一定准）", (this.cueSide === 0 ? '⬅️ 提示在左边' : '➡️ 提示在右边'));
      this.timer = setTimeout(() => {
        this.timer = -1; this.phase = 2; this.shownAt = Date.now();
        this.msg = TG('🎯 目标出现，快点它所在的一侧！');
      }, CUE_MS);
    }, FIX_MS);
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.targetSide],
      TG2('答案是第 {0} 个', String(this.targetSide + 1)),
      TG2('The answer is option {0}', String(this.targetSide + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.targetSide   ｜ 守卫取自它自己的 if (...) { return; }
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
    if (this.phase !== 2) {
      return true;
    }
    this.answer(this.targetSide);
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

  private answer(side: number): void {
    if (this.phase !== 2) { return; }
    const rt: number = Date.now() - this.shownAt;
    this.rtSum = this.rtSum + rt; this.answered = this.answered + 1;
    this.pickSide = side; this.phase = 3;
    if (side === this.targetSide) {
      this.right = this.right + 1;
      this.score = this.score + Math.max(20, MAX_BONUS - Math.floor(rt / 20));
      this.msg = '✅ ' + rt + ' ms';
    } else {
      this.msg = TG2("❌ 目标在{0}边", (this.targetSide === 0 ? TG('左') : TG('右')));
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.trial >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}，平均 {2} ms", this.right, this.diffTotal, this.avgRt());
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.trial = this.trial + 1;
    this.newTrial();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'posner_spatial_cueing', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
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
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.avgRt() + ' ms')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Column({ space: Space.sm }) {
        Text('➕').accessibilityLevel('no').fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
        Row({ space: Space.sm }) {
          Stack() {
          if (this.phase === 1 && this.cueSide === (0)) {
          Text(true ? '⬅️' : '➡️').fontSize(FontSize.xxl)
          } else if (this.phase >= 2 && this.targetSide === (0)) {
          Text('🎯').accessibilityLevel('no').fontSize(FontSize.xxxl)
          } else {
          Text('·').accessibilityLevel('no').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
          }
          }.layoutWeight(1).height(150).backgroundColor(this.pickSide === (0) ? Palette.lime : this.theme.surfaceAlt)
          .borderRadius(Radius.lg).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          Stack() {
          if (this.phase === 1 && this.cueSide === (1)) {
          Text(false ? '⬅️' : '➡️').fontSize(FontSize.xxl)
          } else if (this.phase >= 2 && this.targetSide === (1)) {
          Text('🎯').fontSize(FontSize.xxxl)
            .accessibilityLevel('no')
          } else {
          Text('·').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
            .accessibilityLevel('no')
          }
          }.layoutWeight(1).height(150).backgroundColor(this.pickSide === (1) ? Palette.lime : this.theme.surfaceAlt)
          .borderRadius(Radius.lg).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.width('100%').layoutWeight(1)
      }.width('100%').layoutWeight(1)
      Row({ space: Space.sm }) {
        Button((TG('⬅️ 左边')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(true ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 2).onClick(() => { Haptics.tap(); this.answer((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer((0)); }); })
        Button((TG('右边 ➡️')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(false ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 2).onClick(() => { Haptics.tap(); this.answer((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer((1)); }); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：提示有 1/4 是错的，别抢答，等 🎯 出来再点')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



  /** 一侧的方框：提示箭头 / 目标 🎯 都落在这里 */



}
