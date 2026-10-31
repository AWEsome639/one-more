/**
 * 连线测验（trail_making）—— TMT-B：按 1→A→2→B→…→12→L→13 的交替顺序点格子
 * 胜负：25 个全连上且错误 ≤4 ⇒ 通关；错第 5 次立即失败；进度：已连 / 错误 / 下一类
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

const SIZE: number = 5;
const TOTAL: number = 25;
const ALLOWED: number = 4;
const LETTERS: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];
const ROWS: number[] = [0, 1, 2, 3, 4];
const COLS: number[] = [0, 1, 2, 3, 4];

@Component
export struct GTrailMaking {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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
  @State cells: string[] = [];
  @State flags: boolean[] = [];
  @State step: number = 0;
  @State mistakes: number = 0;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private seq: string[] = [];
  private startAt: number = 0;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTrailMaking')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  /** 1→A→2→B→…→12→L→13，共 25 个 */
  private buildSeq(): string[] {
    const s: string[] = [];
    for (let i = 0; i < 13; i++) {
      s.push(String(i + 1));
      if (i < 12) { s.push(LETTERS[i]); }
    }
    return s;
  }

  private reset(): void {
    const s: string[] = this.buildSeq();
    const c: string[] = s.slice();
    for (let i = c.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = c[i];
      c[i] = c[j];
      c[j] = t;
    }
    this.seq = s;
    this.cells = c;
    this.flags = new Array<boolean>(this.diffTotal).fill(false);
    this.step = 0; this.mistakes = 0; this.over = false; this.won = false; this.done = false;
    this.msg = TG('从 1 开始，数字与字母交替点：1→A→2→B…');
    this.startAt = Date.now();
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
    if (this.step >= this.diffTotal) {
      return true;
    }
    this.tap(this.cells.indexOf(this.seq[this.step]));
    return !this.over;
  }

  /** 提示：报下一个该点的符号 + 它在第几行第几列 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.step >= this.diffTotal) {
      return Hint.none('none');
    }
    const want: string = this.seq[this.step];
    const k: number = this.cells.indexOf(want);
    if (k < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(k / SIZE) + 1;
    const c: number = k - Math.floor(k / SIZE) * SIZE + 1;
    return Hint.make([k],
      TG2('下一个是「{0}」（第 {1} 行第 {2} 列）', want, String(r), String(c)),
      TG2('Next is "{0}" (row {1}, column {2})', want, String(r), String(c)), t0);
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
    if (this.over || this.flags[i]) { return; }
    if (this.cells[i] === this.seq[this.step]) {
      const f: boolean[] = this.flags.slice();
      f[i] = true;
      this.flags = f;
      this.step = this.step + 1;
      this.msg = TG2('✅ 已连 {0}/{1}', String(this.step), String(this.diffTotal));
      if (this.step >= this.diffTotal) { this.finishUp(true); }
      return;
    }
    this.mistakes = this.mistakes + 1;
    if (this.mistakes > ALLOWED) {
      this.msg = TG2('💥 错满 {0} 次，本局失败', String(ALLOWED + 1));
      this.finishUp(false);
      return;
    }
    this.msg = TG2('❌ 顺序不对，还剩 {0} 次机会', String(ALLOWED - this.mistakes + 1));
  }

  private finishUp(win: boolean): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = win;
    if (win) { this.msg = TG2('🎉 通关！25 个全连上，错 {0} 次',Digits(String(this.mistakes), this.langCode)); }
    const r: GameResult = {
      gameId: 'trail_making', solved: win, score: this.step * 40 - this.mistakes * 60,
      durationMs: Date.now() - this.startAt, levelReached: this.step
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
        Text((TG('已连'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.step) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.mistakes) + '/' + String(ALLOWED + 1))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('下一类'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.step >= this.diffTotal ? '—' : (this.step % 2 === 0 ? '数字' : '字母'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(COLS, (c: number) => {
              Text(this.cells[(r * SIZE + c)]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
              .fontColor(this.flags[(r * SIZE + c)] ? '#FFFFFF' : this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.flags[(r * SIZE + c)] ? Palette.primaryDeep : this.theme.surface)
              .borderRadius(Radius.sm).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.tap((r * SIZE + c)); })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * SIZE + c)); }); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.isDark ? '#141414' : '#E8EDF5')
      .borderRadius(Radius.lg)

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primaryDeep).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：数字与字母交替着走，别按视觉位置找'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
