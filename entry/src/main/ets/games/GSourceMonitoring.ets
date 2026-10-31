/**
 * 来源监控 📐（id: source_monitoring）
 * 先记住 5 条消息各自是谁说的（限时 8 秒），再逐条回答「这话是谁说的」。
 * 胜负：5 题答对 ≥4 ⇒ 通关；进度：第几题 / 答对 / 记忆倒计时。
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
import { Tv } from '../core/Tv';

const CLAIMS: string[] = [
  TG('本周三有雷阵雨'), TG('图书馆周六闭馆'), TG('新食堂下月开张'), TG('地铁 15 号线年底通车'),
  TG('期末考提前一周'), TG('学校要办机器人赛'), TG('游泳馆水温调到 28 度'), TG('校车改到南门发车'),
  TG('下学期加开 Python 选修'), TG('操场跑道正在翻修')
];
const SOURCES: string[] = ['👩‍🏫 任课老师', '📰 校报', '🧑‍🔬 实验室学长', '👬 室友'];
const Q_IDX: number[] = [0, 1, 2, 3, 4];
const QUIZ: number = 5; const NEED: number = 4; const STUDY_SEC: number = 8; const WAIT_MS: number = 900;

function orderOf(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i];
    out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSourceMonitoring {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 QUIZ=5
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(5);
  onFinish: (r: GameResult) => void = () => {};
  @State claims: number[] = []; @State srcs: number[] = []; @State phase: string = 'study';
  @State left: number = STUDY_SEC; @State q: number = 0; @State score: number = 0;
  @State picked: number = -1; @State over: boolean = false; @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0; private done: boolean = false;
  private clock: number = -1; private nextTimer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSourceMonitoring')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.stopAll(); }
  private stopAll(): void {
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; }
  }
  private reset(): void {
    this.stopAll();
    const ord: number[] = orderOf(CLAIMS.length); const cs: number[] = []; const ss: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      cs.push(ord[i]);
      ss.push(Math.floor(Math.random() * SOURCES.length));
    }
    this.claims = cs; this.srcs = ss; this.phase = 'study'; this.left = STUDY_SEC;
    this.q = 0; this.score = 0; this.picked = -1; this.over = false; this.won = false;
    this.done = false; this.note = TG('记住每条消息的出处'); this.startAt = Date.now();
    this.clock = setInterval(() => { this.tick(); }, 1000);
  }
  private tick(): void {
    if (this.phase !== 'study') { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.toQuiz(); }
  }
  private toQuiz(): void {
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    this.left = 0; this.phase = 'quiz'; this.note = TG('这条消息是谁说的？');
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
    if (this.phase !== 'quiz' || this.picked >= 0) {
      return true;
    }
    this.pick(this.srcs[this.q]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 'quiz') {
      return Hint.none('none');
    }
    const who: string = SOURCES[this.srcs[this.q]];
    return Hint.make([this.srcs[this.q]],
      TG2('「{0}」是{1}说的', CLAIMS[this.claimNo()], who),
      TG2('{0} came from {1}', CLAIMS[this.claimNo()], who), t0);
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

  private pick(src: number): void {
    if (this.phase !== 'quiz' || this.picked >= 0 || this.over) { return; }
    this.picked = src;
    if (src === this.srcs[this.q]) { this.score++; this.note = TG('✅ 出处记对了'); }
    else { this.note = TG2('❌ 是「{0}」说的', SOURCES[this.srcs[this.q]]); }
    if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); }
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.q + 1 >= this.diffTotal) { this.finish(this.score >= NEED); return; }
      this.q++; this.picked = -1; this.note = TG('这条消息是谁说的？');
    }, WAIT_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.phase = 'over'; this.stopAll();
    const res: GameResult = { gameId: 'source_monitoring', solved: solved, score: this.score * 20, durationMs: Date.now() - this.startAt, levelReached: this.score };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  private softBtn(i: number): string {
    if (this.picked < 0 || this.phase !== 'quiz') { return this.theme.surface; }
    if (i === this.srcs[this.q]) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private claimNo(): number { return this.claims.length > this.q ? this.claims[this.q] : 0; }

  build() {
    Column({ space: Space.sm }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Text((this.phase === 'study' ? TG('记忆') : TG('题号 ') + Math.min(this.q + 1, this.diffTotal) + '/' + this.diffTotal)
        + TG('　答对 ') + this.score + '/' + NEED + '　倒计时 ' + this.left + 's')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      if (this.phase === 'study') {
        ForEach(Q_IDX, (i: number) => {
          Row({ space: Space.sm }) {
            Text(SOURCES[this.srcs.length > i ? this.srcs[i] : 0]).fontSize(FontSize.xs).fontColor(Palette.teal)
            Text(CLAIMS[this.claims.length > i ? this.claims[i] : 0]).fontSize(FontSize.sm)
              .fontColor(this.theme.ink).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.width('100%').padding(Space.xs).backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm).shadow(Shadow.card)
        }, (i: number) => 'st' + i)
        Button(TG('我记好了 ▶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.toQuiz(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.toQuiz(); }); })
      } else {
        Column({ space: Space.xs }) {
          Text(TG('这条消息是谁说的？')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(CLAIMS[this.claimNo()]).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
        }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).shadow(Shadow.card)
        Row({ space: Space.sm }) {
          this.srcBtn(0)
          this.srcBtn(1)
        }.width('100%')
        Row({ space: Space.sm }) {
          this.srcBtn(2)
          this.srcBtn(3)
        }.width('100%')
        Text(this.note).fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
          .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  srcBtn(i: number) {
    Button(SOURCES[i])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.picked === i ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.softBtn(i)).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tap(); this.pick(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(i); }); })
  }
}
