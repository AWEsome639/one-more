/**
 * 关系记忆 —— 🃏 先记住 6 组配对，再凭记忆点出正确的那一半（id: relational_memory）
 * 胜负：6 题答对 ≥ 5 ⇒ 通关；进度：答对/6 · 题号 · 记忆倒计时
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
const PAIRS: number = 6;
const STUDY_MS: number = 5000;
const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐳', '🔑', '🍀', '🎸', '🚀', '🍄', '🧊', '🪁'];
function shuffled(a: string[]): string[] {
  const out: string[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}
@Component
export struct GRelationalMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PAIRS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(PAIRS);
  onFinish: (r: GameResult) => void = () => {};
  @State private sideA: string[] = [];
  @State private sideB: string[] = [];
  @State private options: string[] = [];
  @State private phase: string = 'study';
  @State private qIdx: number = 0;
  @State private hits: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private toId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GRelationalMemory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PAIRS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTo(); }
  private clearTo(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearTo();
    const pool: string[] = shuffled(POOL);
    this.sideA = pool.slice(0, this.diffTotal);
    this.sideB = pool.slice(this.diffTotal, this.diffTotal * 2);
    this.options = [];
    this.phase = 'study'; this.qIdx = 0; this.hits = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.msg = TG2("记住这 {0} 组配对", String(this.diffTotal));
    this.toId = setTimeout(() => { this.toId = -1; this.ask(0); }, STUDY_MS);
  }
  /** 出第 k 题：给出左半，四选一右半 */
  private ask(k: number): void {
    this.phase = 'quiz'; this.qIdx = k; this.pick = -1; this.msg = TG('它的另一半是？');
    const others: string[] = [];
    for (let i = 0; i < this.sideB.length; i++) {
      if (i !== k) { others.push(this.sideB[i]); }
    }
    const mixed: string[] = shuffled(others);
    const ans: string = this.sideB[k];
    this.options = shuffled([ans, mixed[0], mixed[1], mixed[2]]);
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
    if (this.phase !== 'quiz' || this.pick >= 0) {
      return true;
    }
    this.answer(this.sideB[this.qIdx]);
    return !this.over;
  }

  /** 提示：直接报答案 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.phase !== 'quiz' || this.pick >= 0) {
      return Hint.none('none');
    }
    const a: string = this.sideB[this.qIdx];
    if (a.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('应该是「{0}」', a),
      TG2('It should be {0}', a), t0);
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

  private answer(o: string): void {
    if (this.phase !== 'quiz' || this.pick >= 0 || this.over) { return; }
    const k: number = this.qIdx;
    const ans: string = this.sideB[k];
    const ok: boolean = o === ans;
    this.pick = ok ? 1 : 0;
    if (ok) { this.hits = this.hits + 1; }
    this.msg = ok ? '✅ 对了' : TG2("❌ 应该是 {0}", ans);
    const last: boolean = k + 1 >= this.diffTotal;
    this.toId = setTimeout(() => {
      this.toId = -1;
      if (last) { this.end(); return; }
      this.ask(k + 1);
    }, 720);
  }
  private end(): void {
    if (this.done) { return; }
    this.clearTo();
    this.done = true; this.over = true; this.phase = 'done'; this.won = this.hits >= 5;
    this.msg = TG2(this.won ? '🎉 通关 · 答对 {0}/{1}' : '💤 结束 · 答对 {0}/{1}',Digits(String(this.hits), this.langCode),Digits(String(this.diffTotal), this.langCode));
    const r: GameResult = {
      gameId: 'relational_memory', solved: this.won, score: this.hits * 100,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
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
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.hits) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'study' ? '记忆 5 秒' : String(this.qIdx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      if (this.phase === 'study') {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
            Row({ space: Space.sm }) {
            Text(this.sideA[(i)]).fontSize(FontSize.lg).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(42))
            .backgroundColor(this.theme.surface).borderRadius(Radius.sm)
            Text('↔').accessibilityText(TG('对应')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
            Text(this.sideB[(i)]).fontSize(FontSize.lg).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(42))
            .backgroundColor(this.theme.surface).borderRadius(Radius.sm)
            }.width('100%')
          }, (i: number) => 'p' + i)
        }.width('100%')
      } else {
        Column({ space: Space.md }) {
          Text(this.sideA[this.qIdx]).fontSize(FontSize.hero).textAlign(TextAlign.Center)
            .width('100%').height(110).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
          ForEach(this.options, (o: string) => {
            Text((o)).fontSize(FontSize.xxl).textAlign(TextAlign.Center).width('100%').height(Cell.of(52))
            .backgroundColor(this.pick >= 0 && (o) === this.sideB[this.qIdx] ? Palette.emerald : this.theme.surface)
            .borderRadius(Radius.md).shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
            .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
              .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            .onClick(() => { Haptics.tick(); this.answer((o)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((o)); }); })
          }, (o: string) => o)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：6 题答对 ≥ 5 通关；看 5 秒后开始答题'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
