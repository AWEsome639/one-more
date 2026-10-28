/**
 * 反应点击 —— ⚡ 亮起就立刻点它，8 次测平均反应时（id: reflex_tap）
 * 胜负：平均 < 550ms 且点偏 ≤ 2 次 ⇒ 通关；进度：第几/8 · 平均 · 最快
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
const ROUNDS: number = 8;
const WIN_MS: number = 550;
const PENALTY: number = 600;
@Component
export struct GReflexTap {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private pos: number = -1;
  @State private live: boolean = false;
  @State private round: number = 1;
  @State private total: number = 0;
  @State private best: number = 0;
  @State private miss: number = 0;
  @State private flash: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private waitTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  private hitN: number = 0;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见 .onTouch）
    if (Hint.demoOnce('GReflexTap')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.pos = -1; this.live = false; this.round = 1; this.total = 0; this.best = 0; this.miss = 0; this.flash = -1;
    this.over = false; this.won = false; this.done = false; this.hitN = 0; this.startAt = Date.now();
    this.arm();
  }
  /** 随机等 0.7~2.0 秒再点亮一个格子 */
  private arm(): void {
    this.live = false; this.pos = -1; this.flash = -1; this.msg = TG('⚡ 亮起就点它');
    this.waitTo = setTimeout(() => {
      this.waitTo = -1; this.pos = Math.floor(Math.random() * 9);
      this.shownAt = Date.now(); this.live = true; this.msg = TG('点！');
    }, 700 + Math.floor(Math.random() * 1300));
  }
  private avg(): number {
    return this.hitN > 0 ? Math.round(this.total / this.hitN) : 0;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.over) {
      return false;
    }
    if (this.over || !this.live) {
      return true;
    }
    this.tap(this.pos);
    return !this.over;
  }

  /** 提示：目标在哪一格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || !this.live) {
      return Hint.none('none');
    }
    const target: number = this.pos;
    return Hint.make([target], TG2('点第 {0} 个', String(target + 1)),
      TG2('Tap cell {0}', String(target + 1)), t0);
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
    if (this.over || !this.live) { return; }
    const target: number = this.pos;
    if (i !== target) {
      this.miss = this.miss + 1; this.flash = i; this.total = this.total + PENALTY;
      this.msg = TG2('❌ 点偏了，+{0} ms', String(PENALTY));
      return;
    }
    const rt: number = Date.now() - this.shownAt;
    this.total = this.total + rt; this.hitN = this.hitN + 1;
    if (this.best === 0 || rt < this.best) { this.best = rt; }
    this.live = false; this.msg = '✅ ' + String(rt) + ' ms';
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) { this.end(); return; }
      this.round = this.round + 1;
      this.arm();
    }, 460);
  }
  private end(): void {
    if (this.done) { return; }
    const a: number = this.avg();
    this.clearAll();
    this.done = true; this.over = true; this.won = a < WIN_MS && this.miss <= 2;
    this.msg = TG2("{0}{1} ms · 点偏 {2}", (this.won ? '🎉 通关 · 平均 ' : '💤 结束 · 平均 '), String(a), String(this.miss));
    const r: GameResult = {
      gameId: 'reflex_tap', solved: this.won, score: Math.max(0, WIN_MS * 2 - a) * 2,
      durationMs: Date.now() - this.startAt, levelReached: this.round
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
        Text((TG('第几'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.avg() > 0 ? String(this.avg()) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('最快'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.best > 0 ? String(this.best) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Text(this.live && (r * 3 + c) === this.pos ? '⚡' : '').fontSize(FontSize.xxl)
              }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.md)
              .backgroundColor(this.flash === (r * 3 + c) ? '#FEE2E2' : (this.live && (r * 3 + c) === this.pos ? Palette.emerald : this.theme.surface))
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.tap((r * 3 + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Text(this.msg).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：8 次平均 < 550 ms 且点偏 ≤ 2 次（一次罚 600 ms）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
