/**
 * 镜像描线（id: mirror_tracing）—— 你在一面镜子上描：点左边，画到右边 🪞
 * 胜负：3 关全部画完 ⇒ 通关；笔数耗尽 ⇒ 失败（可以「擦掉」反悔）
 * 进度：第几关 / 点中格数 / 剩余笔数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const CELLS: number = N * N;
const LEVELS: number = 3;
const BUDGET: number = 8;

/** 镜像坐标：左右对调（其余坐标不变） */
function mIdx(i: number): number {
  const r: number = Math.floor(i / N);
  const c: number = i % N;
  return r * N + (N - 1 - c);
}

@Component
export struct GMirrorTracing {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 LEVELS=3
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State private target: boolean[] = []; @State private mark: boolean[] = []; @State private taps: number = 0;
  @State private level: number = 1; @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false; private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMirrorTracing')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  private reset(): void {
    this.level = 1;
    this.taps = 0;
    this.over = false;
    this.won = false;
    this.done = false;
    this.startAt = Date.now();
    this.makeLevel();
  }
  /** 每关的图案：贴在镜面上的折线，逐关变长 */
  private makeLevel(): void {
    const t: boolean[] = new Array<boolean>(CELLS).fill(false);
    t[N - 1] = true;
    t[N - 2] = true;
    t[N - 3] = true;
    t[2 * N - 3] = true;
    if (this.level >= 2) {
      t[3 * N - 3] = true;
    }
    if (this.level >= 3) {
      t[3 * N - 4] = true;
    }
    this.target = t;
    this.mark = new Array<boolean>(CELLS).fill(false);
    this.taps = 0;
    this.msg = TG('点镜子左边，笔会落在右边的对称位置');
  }
  /** 提示：和代打同一个循环（含镜像下标换算） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.done) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.target.length; i++) {
      const j: number = mIdx(i);
      if (this.target[j] && !this.mark[j]) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 变体⑦：照真值走
  // target[j] 是应该被标记的格；tap(i) 会作用到 j = mIdx(i)
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over || this.done) {
      return false;
    }
    for (let i = 0; i < this.target.length; i++) {
      const j: number = mIdx(i);
      if (this.target[j] && !this.mark[j]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private tap(i: number): void {
    if (this.over || this.done) { return; }
    const j: number = mIdx(i);
    if (this.mark[j]) {
      this.mark[j] = false;
      this.taps = this.taps + 1;
      this.msg = TG('🧽 擦掉了一格（也算一笔）');
      return;
    }
    if (this.taps >= BUDGET) {
      this.failLevel();
      return;
    }
    this.mark[j] = true;
    this.taps = this.taps + 1;
    if (this.hitMismatch()) {
      this.msg = TG('✏️ 画歪了，可以点同一格擦掉');
    } else {
      this.msg = TG2("✏️ 对齐了 {0}/{1} 格", String(this.hitN()), String(this.targetN()));
    }
    if (this.allHit() && this.taps <= BUDGET) {
      if (this.level >= this.diffTotal) {
        this.done = true;
        this.over = true;
        this.won = true;
        this.msg = TG2('🎉 三关都画成了 · 共 {0} 笔',Digits(String(this.taps), this.langCode));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      } else {
        this.level = this.level + 1;
        this.msg = TG('✅ 这一关成了，下一关 👉');
        this.makeLevel();
      }
      return;
    }
    if (this.taps >= BUDGET) {
      this.failLevel();
    }
  }
  private hitN(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.mark[i] && this.target[i]) {
        n++;
      }
    }
    return n;
  }
  private targetN(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.target[i]) {
        n++;
      }
    }
    return n;
  }
  private allHit(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (this.mark[i] !== this.target[i]) {
        return false;
      }
    }
    return true;
  }
  private hitMismatch(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (this.mark[i] && !this.target[i]) {
        return true;
      }
    }
    return false;
  }
  private failLevel(): void {
    this.done = true;
    this.over = true;
    this.won = false;
    this.msg = TG('💤 笔用完了，这一关没描成');
    this.finish(false);
  }
  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mirror_tracing', solved: solved,
      score: solved ? Math.max(150, 300 * this.diffTotal - (BUDGET * this.diffTotal - this.taps) * 10) : (this.level - 1) * 120,
      durationMs: Date.now() - this.startAt, levelReached: this.level
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
    HintBar({
      showHint: true,
      onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
      demoOn: this.demoId >= 0,
      autoOn: this.autoId >= 0
    })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.level) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('对齐'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.hitN()) + '/' + String(this.targetN()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余笔'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, BUDGET - this.taps)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Text(TG('🎯 目标图案（在镜子里）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
      Column({ space: 2 }) {
      ForEach([0, 1, 2, 3], (r: number) => {
      Row({ space: 2 }) {
      ForEach([0, 1, 2, 3], (c: number) => {
      Stack() {
      Text(((true)) ? (this.target[(r * N + c)] ? '●' : '')
      : (this.mark[(r * N + c)] ? '●' : String((r * N + c) + 1))) .fontSize(FontSize.xxs)
      .fontColor(((true)) ? Palette.violet : (this.mark[(r * N + c)] ? Palette.teal : this.theme.inkFaint))
      }
      .layoutWeight(1)
      .aspectRatio(1)
      .backgroundColor(this.cellBg((r * N + c), ((true))))
      .borderRadius(Radius.xs)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
      Haptics.tick();
      if (((false))) {
      this.tap((r * N + c));
      }
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (((false))) { this.tap((r * N + c)); } }); })
      }, (c: number) => 'c' + c)
      }
      .width('100%')
      }, (r: number) => 'r' + r)
      }
      .width('72%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)
      Text(TG('✏️ 你描的（画布是镜子，左右反着落笔）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
      Column({ space: 2 }) {
      ForEach([0, 1, 2, 3], (r: number) => {
      Row({ space: 2 }) {
      ForEach([0, 1, 2, 3], (c: number) => {
      Stack() {
      Text(((false)) ? (this.target[(r * N + c)] ? '●' : '')
      : (this.mark[(r * N + c)] ? '●' : String((r * N + c) + 1))) .fontSize(FontSize.xxs)
      .fontColor(((false)) ? Palette.violet : (this.mark[(r * N + c)] ? Palette.teal : this.theme.inkFaint))
      }
      .layoutWeight(1)
      .aspectRatio(1)
      .backgroundColor(this.cellBg((r * N + c), ((false))))
      .borderRadius(Radius.xs)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
      Haptics.tick();
      if (((true))) {
      this.tap((r * N + c));
      }
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (((true))) { this.tap((r * N + c)); } }); })
      }, (c: number) => 'c' + c)
      }
      .width('100%')
      }, (r: number) => 'r' + r)
      }
      .width('72%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)
      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：3 关全部对齐通关 · 每关 8 笔（擦掉也算一笔）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  private cellBg(i: number, isTarget: boolean): string {
    if (isTarget) {
      return this.target[i] ? '#E9E3FE' : (this.theme.isDark ? '#1E1E1E' : '#FFFFFF');
    }
    if (this.mark[i]) {
      return this.target[i] ? '#CCFBF1' : '#FEE2E2';
    }
    return this.theme.isDark ? '#1E1E1E' : '#FFFFFF';
  }
}
