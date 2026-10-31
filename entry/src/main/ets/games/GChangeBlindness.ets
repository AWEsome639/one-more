/**
 * 变化盲视 —— 九宫格先闪 1.3 秒，翻动后第二次呈现时换掉一格，指出是哪一格
 * 胜负：6 轮答对 4 轮以上 ⇒ 通关；进度：轮次 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
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

const POOL: string[] = ['🍎', '🍊', '🍇', '🍓', '🍒', '🥝', '🌵', '🌻', '🍄', '🐟', '🐤', '🦋', '⭐', '🌙'];
const ROUNDS: number = 6;
const NEED: number = 4;
const PEEK_MS: number = 1300;
const CELLS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];

@Component
export struct GChangeBlindness {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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
  @State private base: string[] = [];
  @State private shown: string[] = [];
  @State private at: number = -1;       // 被换掉的那一格
  @State private phase: number = 0;     // 0=第一眼 1=翻动 2=第二眼
  @State private idx: number = 0;
  @State private roundNo: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private timer: number = -1;
  private stepTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GChangeBlindness')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.stepTo >= 0) { clearTimeout(this.stepTo); this.stepTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.roundNo = 1; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now();
    this.newRound();
    this.timer = setInterval(() => {
      if (!this.over && this.phase === 2) { this.score = Math.max(0, this.score - 5); }
    }, 1000);
  }
  private newRound(): void {
    const base: string[] = [];
    while (base.length < 9) {
      const s: string = POOL[Math.floor(Math.random() * POOL.length)];
      if (base.indexOf(s) < 0) { base.push(s); }
    }
    const at: number = Math.floor(Math.random() * 9);
    let rep: string = POOL[Math.floor(Math.random() * POOL.length)];
    let guard: number = 0;
    while ((base.indexOf(rep) >= 0 || rep === base[at]) && guard < 60) {
      rep = POOL[Math.floor(Math.random() * POOL.length)];
      guard = guard + 1;
    }
    const shown: string[] = base.slice();
    shown[at] = rep;
    this.base = base;
    this.shown = shown;
    this.at = at;
    this.pick = -1; this.idx = 0; this.phase = 0;
    this.msg = TG2("第 {0} 轮：记住这 9 个符号", String(this.roundNo));
    this.stepTo = setTimeout(() => { this.stepTo = -1; this.phase = 1; this.msg = TG('翻动中…'); this.flip(0); }, PEEK_MS);
  }
  /** 一格一格遮住第一眼（约 540ms），遮完立刻进入第二眼 */
  private flip(k: number): void {
    if (k >= 9) {
      this.phase = 2;
      this.msg = TG('再看一眼 —— 哪一格变了？点它');
      return;
    }
    this.idx = k;
    this.stepTo = setTimeout(() => { this.stepTo = -1; this.flip(k + 1); }, 60);
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.at],
      TG2('答案是第 {0} 个', String(this.at + 1)),
      TG2('The answer is option {0}', String(this.at + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：answer(this.at)
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
    if (this.phase !== 2 || this.pick >= 0) {
      return true;              // 还在第一眼/翻动中，或已答完等下一轮
    }
    this.answer(this.at);
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
    if (this.phase !== 2 || this.pick >= 0) { return; }
    this.pick = i;
    if (i === this.at) {
      this.right = this.right + 1;
      this.score = this.score + 100; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2("✅ 找到了！就是第 {0} 格", String(i + 1));
    } else {
      this.msg = TG2("❌ 变的是第 {0} 格", String(this.at + 1));
    }
    this.stepTo = setTimeout(() => {
      this.stepTo = -1;
      if (this.roundNo >= this.diffTotal) {
        this.over = true;
        this.won = this.right >= NEED;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.roundNo = this.roundNo + 1;
      this.newRound();
    }, 880);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'change_blindness', solved: solved, score: this.right * 120,
      durationMs: Date.now() - this.startAt, levelReached: this.roundNo
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
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
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.roundNo + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.phase === 2 ? Palette.lime : this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Grid() {
        ForEach(CELLS, (i: number) => { GridItem() {
        Stack() {
        if (this.phase === 0 || this.phase === 2) {
        Text(this.phase === 2 ? this.shown[(i)] : this.base[(i)]).fontSize(FontSize.xxl)
        } else if ((i) < this.idx) {
        Text(this.base[(i)]).fontSize(FontSize.xxl).opacity(0.25)
        } else {
        Text(this.phase === 1 && (i) === this.idx ? '🔎' : '·').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
        }
        }.width('100%').aspectRatio(1)
        .backgroundColor(this.pick === (i) ? Palette.lime : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((i)); }); })
        .onClick(() => { Haptics.tick(); this.answer((i)); })

        } }, (i: number) => 'cb' + i)
      // ★ 2026-10-31 真机：原写死 .height(250)，在 533 高的横屏上占 47~49%，
      //   加上 HintBar 与统计行后底部按钮被切。改成按屏高自适应（上限仍是原值）。
      }.columnsTemplate('1fr 1fr 1fr').rowsGap(Space.sm).columnsGap(Space.sm).width('100%').height(Math.min(250, Bp.height * 0.35))
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：第一次只闪 1.3 秒，第二眼才换掉一格；越快作答分越高')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}