/**
 * 停止信号 —— 多数回合是「冲」，偶尔亮红是「停」，红着时按下去就算错
 * 胜负：12 回合正确 ≥10 且「冲」的平均反应 < 800ms 通关
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const ROUNDS: number = 12;
const LIMIT_MS: number = 800;
const STOP_RATIO: number = 0.35;

@Component
export struct GStopSignal {
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

  @State private kind: number = 0;        // 0 准备 1 冲 2 停 3 回合间
  @State private round: number = 1;
  @State private right: number = 0;
  @State private total: number = 0;       // 冲的累计毫秒
  @State private goes: number = 0;        // 冲的次数
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private cueTo: number = -1;
  private sigTo: number = -1;
  private nextTo: number = -1;
  private cueAt: number = 0;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GStopSignal')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.cueTo >= 0) { clearTimeout(this.cueTo); this.cueTo = -1; }
    if (this.sigTo >= 0) { clearTimeout(this.sigTo); this.sigTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.kind = 0; this.round = 1; this.right = 0; this.total = 0; this.goes = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.arm();
  }

  /** 先给 0.5~1.4s 的准备时间，再随机亮「冲」或「停」 */
  private arm(): void {
    this.kind = 0;
    this.msg = TG2("第 {0}/{1} 回合 · 预备", String(this.round), String(this.diffTotal));
    this.cueTo = setTimeout(() => {
      this.cueTo = -1;
      this.cueAt = Date.now();
      const isStop: boolean = Math.random() < STOP_RATIO;
      this.kind = isStop ? 2 : 1;
      this.msg = isStop ? '🛑 停！千万别按' : '⚡ 冲！快按';
      this.sigTo = setTimeout(() => { this.sigTo = -1; this.timeout(); },
        380 + Math.floor(Math.random() * 1600));
    }, 500 + Math.floor(Math.random() * 900));
  }

  private timeout(): void {
    if (this.over || this.kind === 3) { return; }
    if (this.kind === 2) {
      this.right = this.right + 1;
      this.msg = TG('✅ 忍住了');
    } else {
      this.total = this.total + 1500;
      this.goes = this.goes + 1;
      this.msg = TG('⏰ 该按没按，按 1500 ms 计');
    }
    this.advance();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    if (this.kind !== 1) {
      return true;
    }
    this.tap();
    return !this.over;
  }

  /** 提示：现在该按还是该忍（kind 1 = 冲 / 2 = 停） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.kind === 1) {
      return Hint.make([], TG('⚡ 该按：这是「冲」信号'), TG('⚡ Press now — GO'), t0);
    }
    if (this.kind === 2) {
      return Hint.make([], TG('🛑 别按：这是「停」信号'), TG('🛑 Do NOT press — STOP'), t0);
    }
    return Hint.make([], TG('还没亮灯，等这一拍'), TG('Wait for the cue'), t0);
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

  private tap(): void {
    if (this.over) { return; }
    if (this.kind === 2) {
      this.msg = TG('❌ 停止信号不能按');
      this.advance();
      return;
    }
    if (this.kind !== 1) { return; }
    const rt: number = Date.now() - this.cueAt;
    this.total = this.total + rt;
    this.goes = this.goes + 1;
    this.right = this.right + 1;
    this.msg = '✅ ' + String(rt) + ' ms';
    this.advance();
  }

  private advance(): void {
    this.clearAll();
    this.kind = 3;
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) { this.stop(); return; }
      this.round = this.round + 1;
      this.arm();
    }, 700);
  }

  private avg(): number {
    return this.goes === 0 ? 9999 : Math.round(this.total / this.goes);
  }

  private stop(): void {
    if (this.done) { return; }
    this.done = true;
    this.clearAll();
    const avg: number = this.avg();
    const win: boolean = this.right >= 10 && avg < LIMIT_MS;
    this.over = true; this.won = win;
    this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("正确 {0}/{1}", String(this.right), String(this.diffTotal))
      + TG2(' · 冲均值 {0} ms', String(avg));
    const res: GameResult = {
      gameId: 'stop_signal', solved: win,
      score: Math.max(0, (LIMIT_MS * 2 - avg) * 3 + this.right * 40),
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  private panel(): string {
    if (this.kind === 1) { return Palette.emerald; }
    if (this.kind === 2) { return Palette.danger; }
    return this.theme.surface;
  }

  private icon(): string {
    if (this.kind === 1) { return '⚡'; }
    if (this.kind === 2) { return '🛑'; }
    if (this.kind === 0) { return '⏳'; }
    return '·';
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
      Row() {
        Text(TG2('回合 {0}/{1}', String(this.round), String(this.diffTotal))).fontSize(FontSize.sm).fontColor(this.theme.ink)
        Text(TG2('正确 {0}', String(this.right))).fontSize(FontSize.sm).fontColor(Palette.emerald)
        Text(TG2("冲均值 {0}", (this.goes > 0 ? String(this.avg()) + 'ms' : '—'))).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        Text(this.icon()).fontSize(FontSize.hero)
        Text(this.msg)
          .fontSize(FontSize.md).textAlign(TextAlign.Center)
          .fontColor(this.kind === 1 || this.kind === 2 ? '#FFFFFF' : this.theme.inkSoft)
      }
      .width('100%').height(170).justifyContent(FlexAlign.Center)
      .backgroundColor(this.panel()).borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(); }); })
      Button(this.kind === 2 ? '🛑 忍住' : '⚡ 冲')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.xxl).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : (this.kind === 2 ? Palette.danger : Palette.emerald))
        .borderRadius(Radius.lg).width('100%').height(Cell.of(84))
        .scale({ x: this.kind === 3 ? Motion.pressScale : 1, y: this.kind === 3 ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.tap(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tap(); }); })
      if (this.over) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.rose)
          .borderRadius(Radius.md).width('100%').height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      Text(TG('判定：正确 ≥ 10/12 且冲均值 < 800 ms（该按没按按 1500 ms 计）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
