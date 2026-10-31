/**
 * 特征回忆 —— 4×4 里亮起 6 格，遮蔽后要把这 6 格「全部」点回来
 * 胜负：6 格完全正确 ⇒ 通关；进度：倒计时 / 已选 n/6 / 点对数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
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
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const N: number = 4;
const TOTAL: number = N * N;
const LIT: number = 6;
const SHOW_SEC: number = 5;

@Component
export struct GFeatureMatrixRecallAll {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private hiColors: string[] = [];
  @State private picked: boolean[] = [];
  @State private phase: number = 0;      // 0 记忆 1 作答 2 判定
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SHOW_SEC);
  @State private secLeft: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFeatureMatrixRecallAll')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(SHOW_SEC);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }

  private reset(): void {
    this.clearAll();
    const colors: string[] = new Array<string>(TOTAL).fill('');
    const slots: number[] = [];
    for (let i = 0; i < TOTAL; i++) { slots.push(i); }
    for (let i = 0; i < LIT; i++) {                    // 洗牌取前 6 格
      const j: number = i + Math.floor(Math.random() * (TOTAL - i));
      const tmp: number = slots[i]; slots[i] = slots[j]; slots[j] = tmp;
    }
    for (let i = 0; i < LIT; i++) {
      colors[slots[i]] = i % 2 === 0 ? Palette.violet : Palette.teal;
    }
    this.hiColors = colors;
    this.picked = new Array<boolean>(TOTAL).fill(false);
    this.phase = 0; this.secLeft = this.total; this.over = false; this.won = false; this.done = false;
    this.msg = TG('记住亮起的 6 格（颜色只是装饰）');
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.phase !== 0) { return; }
      this.secLeft = this.secLeft - 1;
      if (this.secLeft <= 0) {
        this.clearAll();
        this.phase = 1;
        this.msg = TG('把这 6 格全部点回来');
      }
    }, 1000);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在 this.hiColors（亮起的那 6 格）⇒ 记忆期等着，作答期一格格点回来
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
    if (this.phase !== 1) {
      return true;              // 还在记忆/倒计时，等
    }
    for (let i = 0; i < TOTAL; i++) {
      const want: boolean = this.hiColors[i] !== '';
      if (this.picked[i] !== want) {
        this.toggle(i);
        return true;
      }
    }
    this.judge();
    return !this.over;
  }

  /** 提示：把亮过的 6 格按行列报出来（报格子，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const parts: string[] = [];
    for (let i = 0; i < TOTAL; i++) {
      if (this.hiColors[i] !== '') {
        const r: number = Math.floor(i / N) + 1;
        const c: number = i % N + 1;
        parts.push(r + '排' + c + '列');
      }
    }
    if (parts.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('亮过的是：{0}', parts.join('、')),
      TG2('The lit cells: {0}', parts.join(', ')), t0);
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

  private toggle(i: number): void {
    if (this.phase !== 1) { return; }
    const next: boolean[] = this.picked.slice();
    next[i] = !next[i];
    this.picked = next;
  }

  private pickCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.picked.length; i++) { if (this.picked[i]) { n = n + 1; } }
    return n;
  }

  private hitCount(): number {
    let n: number = 0;
    for (let i = 0; i < TOTAL; i++) {
      if (this.hiColors[i] !== '' && this.picked[i]) { n = n + 1; }
    }
    return n;
  }

  private judge(): void {
    if (this.phase !== 1 || this.pickCount() !== LIT) { return; }
    let ok: boolean = true;
    for (let i = 0; i < TOTAL; i++) {
      if (this.picked[i] !== (this.hiColors[i] !== '')) { ok = false; }
    }
    this.phase = 2; this.over = true; this.won = ok;
    this.msg = ok ? '🎉 6 格全中！' : TG2("💤 只对了 {0}/{1} 格", String(this.hitCount()), String(LIT));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'feature_matrix_recall_all', solved: ok, score: ok ? 360 : this.hitCount() * 50,
        durationMs: Date.now() - this.startAt, levelReached: this.hitCount()
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  private cellInk(i: number): string {
    if (this.phase === 2) {
      const isTarget: boolean = this.hiColors[i] !== '';
      if (isTarget && this.picked[i]) { return '✅'; }
      if (isTarget) { return '❌'; }
      return this.picked[i] ? '⛔' : '';
    }
    return this.phase === 1 && this.picked[i] ? '🎯' : '';
  }

  private cellBg(i: number): string {
    if (this.phase === 1) { return this.picked[i] ? Palette.primary : this.theme.surfaceAlt; }
    return this.hiColors[i] === '' ? this.theme.surfaceAlt : this.hiColors[i];
  }

  /** 键里带上格子外观，确保状态一变 ForEach 就重绘 */
  private cellKey(i: number): string {
    return 'k' + String(i) + this.cellBg(i) + (this.picked[i] ? '1' : '0') + this.cellInk(i);
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? TG('记忆') : (this.phase === 2 ? '判定' : '作答'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已选'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.pickCount()) + '/' + String(LIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('点对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.hitCount()))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Text(this.phase === 0 ? ('⏳ ' + String(this.secLeft) + ' 秒后遮蔽') : this.msg)
        .fontSize(FontSize.sm).fontColor(this.phase === 0 ? Palette.amber : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (row: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (col: number) => {
              Stack() {
              Text(this.cellInk((row * N + col))).fontSize(FontSize.lg)
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.cellBg((row * N + col))).borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.toggle((row * N + col)); }); })
              .onClick(() => { Haptics.tick(); this.toggle((row * N + col)); })
            }, (col: number) => this.cellKey(row * N + col))
          }.width('100%')
        }, (row: number) => 'r' + row)
      }.width('100%').aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Button(this.phase === 2 ? TG('再来一局') : TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .enabled(this.phase === 1 && this.pickCount() === LIT)
        .opacity(this.phase === 1 && this.pickCount() === LIT ? 1 : 0.5)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.phase === 2) { this.reset(); } else { this.judge(); } }); })
        .onClick(() => { Haptics.tap(); if (this.phase === 2) { this.reset(); } else { this.judge(); } })

      Text(TG('不许多点也不许漏点：选满 6 格才能提交'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
