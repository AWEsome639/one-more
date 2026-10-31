/** 描路径 📐（id: trace_path）
 * 先看一遍亮起的路线，灭掉后从 🚩 起按原路一格一格点下去，点错就断线重来；
 * 3 条路线全部描完 ⇒ 通关，断线 4 次 ⇒ 失败。 */
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
const M: number = 5;
const CELLS: number = M * M;
const LEN: number = 7;
const ROUNDS: number = 3;
const MAX_ERR: number = 4;
const PREVIEW: number = 1600;
const RX: number[] = [0, 1, 2, 3, 4];
@Component
export struct GTracePath {
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
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State path: number[] = [];
  @State traced: number[] = [];
  @State round: number = 0;
  @State err: number = 0;
  @State show: boolean = false;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTracePath')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); }
  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.clearTimer();
    this.round = 0; this.err = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newPath();
  }
  private makePath(): number[] {
    for (let attempt = 0; attempt < 60; attempt++) {
      const p: number[] = [Math.floor(Math.random() * CELLS)];
      while (p.length < LEN) {
        const c: number = p[p.length - 1];
        const r: number = Math.floor(c / M);
        const col: number = c % M;
        const cand: number[] = [];
        if (r > 0 && p.indexOf(c - M) < 0) { cand.push(c - M); }
        if (r < M - 1 && p.indexOf(c + M) < 0) { cand.push(c + M); }
        if (col > 0 && p.indexOf(c - 1) < 0) { cand.push(c - 1); }
        if (col < M - 1 && p.indexOf(c + 1) < 0) { cand.push(c + 1); }
        if (cand.length === 0) { break; }
        p.push(cand[Math.floor(Math.random() * cand.length)]);
      }
      if (p.length === LEN) { return p; }
    }
    return [0, 1, 2, 3, 4, 9, 14];
  }
  private newPath(): void {
    this.path = this.makePath();
    this.traced = [this.path[0]];
    this.show = true;
    this.note = TG2("看清路线 · 共 {0} 格", String(LEN));
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1; this.show = false; this.note = TG('从 🚩 开始，按刚才的路线点下去');
    }, PREVIEW);
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
    if (this.show) {
      return true;
    }
    this.tap(this.path[this.traced.length]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const next: number = this.path[this.traced.length];
    if (this.traced.length >= this.path.length) {
      return Hint.none('none');
    }
    const r: number = Math.floor(next / M) + 1;
    const c: number = (next % M) + 1;
    return Hint.make([next],
      TG2('按原路线，下一个点第 {0} 行第 {1} 列', String(r), String(c)),
      TG2('Next on the route: row {0}, column {1}', String(r), String(c)), t0);
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

  private tap(i: number): void {
    if (this.over || this.show) { return; }
    if (i === this.path[this.traced.length]) {
      const t: number[] = this.traced.slice();
      t.push(i);
      this.traced = t;
      if (t.length < this.path.length) { this.note = TG2('继续 · {0}/{1}', String(t.length), String(LEN)); return; }
      if (this.round + 1 >= this.diffTotal) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
 TG2("✅ 第 {0} 条描完",Digits(String(this.round), this.langCode)); this.note = TG2('✅ 第 {0} 条描完',Digits(String(this.round), this.langCode));
      this.newPath();
      return;
    }
    this.err++;
    this.traced = [this.path[0]];
    if (this.err >= MAX_ERR) { this.note = TG2('断线 {0} 次',Digits(String(MAX_ERR), this.langCode)); this.finish(false); return; }
    this.note = TG2('❌ 断线了，从 🚩 重来 · 失误 {0}/{1}', String(this.err), String(MAX_ERR));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.show = false;
    this.clearTimer();
    const r: GameResult = {
      gameId: 'trace_path', solved: solved,
      score: solved ? Math.max(60, 300 - this.err * 50) : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.round + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private cellColor(i: number): string {
    if (this.traced.indexOf(i) >= 0) { return this.over && !this.won ? Palette.rose : Palette.primary; }
    return this.show && this.path.indexOf(i) >= 0 ? Palette.cyan : this.theme.surface;
  }
  private mark(i: number): string {
    if (this.path.length === 0) { return ''; }
    if (i === this.path[0]) { return '🚩'; }
    return i === this.path[this.path.length - 1] ? '🏁' : '';
  }
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
            Text(TG2('路线 {0}/{1}', String(Math.min(this.round + 1, this.diffTotal)), String(this.diffTotal)) +
        TG2(' · 已描 {0}/{1}', String(this.traced.length), String(LEN)) +
        TG2(' · 失误 {0}/{1}', String(this.err), String(MAX_ERR)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Column({ space: Space.xs }) {
        ForEach(RX, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(RX, (c: number) => {
              this.cell(r * M + c)
            }, (c: number) => 'gc' + c)
          }
          .width('100%')
        }, (r: number) => 'gr' + r)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  cell(i: number) {
    Stack() {
      Text(this.mark(i)).fontSize(FontSize.md)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.cellColor(i)).borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
  }
}
