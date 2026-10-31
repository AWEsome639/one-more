/**
 * 幽灵点击 —— 4×4 阵里幽灵一闪即逝，趁它还在时点中它（越到后面越快）
 * 胜负：15 只里抓到 ≥ 12 只 ⇒ 通关；进度：第 n 只 / 抓到 / 溜走
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const SIZE: number = 4;
const CELLS: number = SIZE * SIZE;
const GHOSTS: number = 15;
const WIN_HITS: number = 12;

@Component
export struct GGhostTap {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GHOSTS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(GHOSTS);
  onFinish: (r: GameResult) => void = () => {};

  @State private ghostIdx: number = -1;
  @State private flash: number = -1;
  @State private fbOk: boolean = true;
  @State private spawnN: number = 0;
  @State private hitN: number = 0;
  @State private missN: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private lifeTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GGhostTap')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GHOSTS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.lifeTo >= 0) { clearTimeout(this.lifeTo); this.lifeTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.ghostIdx = -1; this.flash = -1; this.fbOk = true;
    this.spawnN = 0; this.hitN = 0; this.missN = 0;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('幽灵一现就点它（越到后面越快）');
    this.startAt = Date.now();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.spawn(); }, 700);
  }

  private spawn(): void {
    if (this.over) { return; }
    if (this.spawnN >= this.diffTotal) { this.judge(); return; }
    this.spawnN = this.spawnN + 1;
    let idx: number = Math.floor(Math.random() * CELLS);
    if (idx === this.ghostIdx) { idx = (idx + 1) % CELLS; }
    this.ghostIdx = idx;
    this.flash = -1;
    this.msg = TG('👻 出现了！');
    const life: number = this.spawnN <= 5 ? 820 : (this.spawnN <= 10 ? 620 : 460);
    this.lifeTo = setTimeout(() => { this.lifeTo = -1; this.expire(); }, life);
  }

  private expire(): void {
    if (this.over) { return; }
    if (this.ghostIdx >= 0) {
      this.missN = this.missN + 1;
      this.flash = this.ghostIdx;
      this.fbOk = false;
      this.msg = TG('👻 溜走了');
      this.ghostIdx = -1;
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.flash = -1; this.spawn(); }, 240);
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
    if (this.ghostIdx < 0) {
      return true;
    }
    this.tapCell(this.ghostIdx);
    return !this.over;
  }

  /** 提示：鬼在哪一格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.ghostIdx < 0) {
      return Hint.none('none');
    }
    const g: number = this.ghostIdx;
    return Hint.make([g], TG2('鬼在第 {0} 格', String(g + 1)),
      TG2('Ghost at cell {0}', String(g + 1)), t0);
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

  private tapCell(i: number): void {
    if (this.over) { return; }
    if (this.ghostIdx < 0) { this.msg = TG('❌ 这里空空的'); return; }
    if (i === this.ghostIdx) {
      this.hitN = this.hitN + 1;
      this.flash = i; this.fbOk = true;
      this.msg = TG('✅ 抓住了');
      this.ghostIdx = -1;
      if (this.lifeTo >= 0) { clearTimeout(this.lifeTo); this.lifeTo = -1; }
    } else {
      this.missN = this.missN + 1;      // 点偏了，幽灵仍在，还能再点
      this.flash = i; this.fbOk = false;
      this.msg = TG('❌ 点偏了，它还在！');
      return;
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.flash = -1; this.spawn(); }, 240);
  }

  private judge(): void {
    this.clearAll();
    this.ghostIdx = -1; this.over = true; this.won = this.hitN >= WIN_HITS;
    this.msg = TG2(this.won ? '🎉 通关！抓到 {0}/{1}' : '💤 结束，抓到 {0}/{1}',Digits(String(this.hitN), this.langCode),Digits(String(this.diffTotal), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'ghost_tap', solved: this.won,
        score: Math.max(0, this.hitN * 80 - this.missN * 20),
        durationMs: Date.now() - this.startAt, levelReached: this.hitN
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  private cellColor(i: number): string {
    if (this.flash === i) { return this.fbOk ? Palette.emerald : Palette.rose; }
    if (this.ghostIdx === i) { return Palette.lime; }
    return this.theme.surfaceAlt;
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
        Text((TG('第几只'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.spawnN) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('抓到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hitN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('溜走'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.missN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (row: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (col: number) => {
              Stack() {
              Text(this.ghostIdx === (row * SIZE + col) ? '👻' : '').fontSize(FontSize.xxl)
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.cellColor((row * SIZE + col))).borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell((row * SIZE + col)); }); })
              .onClick(() => { Haptics.tick(); this.tapCell((row * SIZE + col)); })
            }, (col: number) => 'c' + col + this.cellColor(row * SIZE + col))
          }.width('100%')
        }, (row: number) => 'r' + row)
      }.width('100%').aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('判定：{0} 只里抓到 {1} 只即通关，点偏会拖慢节奏',Digits(String(this.diffTotal), this.langCode),Digits(String(WIN_HITS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
