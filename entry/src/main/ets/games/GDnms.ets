/**
 * 非匹配延迟（DNMS）—— 先记住一组样例，再从选项里挑出「没见过」的那一个
 *
 * 胜负：6 轮答对 5 轮以上 ⇒ 通关；样例数逐轮变多
 * 进度：轮次 / 答对 / 选项数 / 阶段
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
const TRIALS: number = 6; const NEED: number = 5; const STUDY: number = 1500; const GAP: number = 600;
const POOL: string[] = ['🍎', '🚗', '🚀', '🐱', '☂️', '🎹', '📷', '⏰', '⚽', '🍰', '💡', '🔑', '🐟', '🌻', '🎲', '🧊'];
@Component
export struct GDnms {
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
  @State private samples: string[] = [];   // 见过的样例
  @State private opts: string[] = [];
  @State private ansIdx: number = -1;      // 全新的那一个在选项里的位置
  @State private phase: number = 0;        // 0 记忆 1 空屏 2 选择 3 判定
  @State private pick: number = -1;
  @State private trialNo: number = 1;
  @State private right: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private to1: number = -1;
  private to2: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDnms')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
    if (this.to2 >= 0) { clearTimeout(this.to2); this.to2 = -1; }
  }
  /** 样例数：3,3,4,4,5,5 ⇒ 选项 4~6 个 */
  private keep(): number { return 3 + Math.floor((this.trialNo - 1) / 2); }
  private reset(): void {
    this.stop(); this.trialNo = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.newTrial();
  }
  private newTrial(): void {
    const bag: string[] = POOL.slice(); const kept: string[] = [];
    while (kept.length < this.keep()) {
      kept.push(bag.splice(Math.floor(Math.random() * bag.length), 1)[0]);
    }
    const fresh: string = bag.splice(Math.floor(Math.random() * bag.length), 1)[0];
    const list: string[] = kept.slice();
    list.push(fresh);
    const mixed: string[] = [];
    while (list.length > 0) {
      mixed.push(list.splice(Math.floor(Math.random() * list.length), 1)[0]);
    }
    this.samples = kept; this.opts = mixed; this.ansIdx = mixed.indexOf(fresh); this.pick = -1;
    this.phase = 0; this.msg = TG2("第 {0} 轮 · 记住这 {1} 个", String(this.trialNo), String(this.keep()));
    this.to1 = setTimeout(() => { this.to1 = -1; this.toGap(); }, STUDY);
  }
  private toGap(): void {
    this.phase = 1; this.to1 = setTimeout(() => {
      this.to1 = -1; this.phase = 2; this.msg = TG('哪一个没见过？');
    }, GAP);
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ansIdx）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ansIdx 里） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ansIdx;
    return Hint.make([n],
      TG2('答案是「{0}」', this.opts[n]),
      TG2('The answer is "{0}"', this.opts[n]), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.answer(this.ansIdx);
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

  private answer(i: number): void {
    if (this.over || this.phase !== 2 || i >= this.opts.length) { return; }
    this.pick = i; this.phase = 3;
    if (i === this.ansIdx) {
      this.right = this.right + 1; this.msg = TG2('✅ 对！{0} 是新的', this.opts[i]);
    } else {
      this.msg = TG2('❌ {0} 刚才见过，新的是 {1}', this.opts[i], this.opts[this.ansIdx]);
    }
    this.to1 = setTimeout(() => { this.to1 = -1; this.advance(); }, 1000);
  }
  private advance(): void {
    if (this.trialNo >= this.diffTotal) {
      this.won = this.right >= NEED; this.over = true;
      this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
      this.finish();
      return;
    }
    this.trialNo = this.trialNo + 1; this.newTrial();
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'dnms', solved: this.won, score: this.right * 140,
      durationMs: Date.now() - this.startAt, levelReached: this.keep() + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private face(): string {
    if (this.phase === 0) { return this.samples.join(' '); }
    if (this.phase === 1) { return '·'; }
    if (this.phase === 2) { return '❓'; }
    return this.pick >= 0 ? this.opts[this.pick] : '·';
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
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('选项'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.keep() + 1))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        Text(this.face()).fontSize(this.phase === 0 ? FontSize.xl : FontSize.hero).fontColor(Palette.lime)
      }.width('100%').height(110).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Column({ space: Space.sm }) {
        ForEach([0, 1], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Text(this.phase >= 2 && (r * 3 + c) < this.opts.length ? this.opts[(r * 3 + c)] : '·')
              .fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(56))
              .backgroundColor(this.phase === 3 && this.pick === (r * 3 + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
              .borderRadius(Radius.md).opacity(this.phase === 2 ? 1 : 0.55)
              .scale({ x: this.phase === 3 && this.pick === (r * 3 + c) ? Motion.pressScale : 1, y: this.phase === 3 && this.pick === (r * 3 + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((r * 3 + c)); }); }).onClick(() => { Haptics.tick(); this.answer((r * 3 + c)); })
            }, (c: number) => 'oc' + c)
          }.width('100%')
        }, (r: number) => 'or' + r)
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：其余几个刚才都见过，只有一个是全新的')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
