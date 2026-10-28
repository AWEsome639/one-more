/**
 * 动态凸显 —— 20 秒内点掉那个发亮的方块，它会自己换位置
 *
 * 胜负：20 秒内命中 ≥10 ⇒ 通关；点错不扣时间但计误点
 * 进度：剩余秒数 / 命中 / 误点
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
const SIDE: number = 4; const CELLS: number = SIDE * SIDE; const LIMIT: number = 20;      // 秒
const HOP: number = 1500;      // 目标自动换位间隔
const NEED: number = 10;
@Component
export struct GDynamicSalience {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private hot: number = 0;
  @State private hits: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  @State private miss: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private clock: number = -1;
  private hopper: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDynamicSalience')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    if (this.hopper >= 0) { clearInterval(this.hopper); this.hopper = -1; }
  }
  private reset(): void {
    this.stop(); this.hot = Math.floor(Math.random() * CELLS); this.hits = 0; this.miss = 0;
    this.left = this.total; this.over = false; this.won = false; this.done = false; this.msg = TG('点亮着的方块，它会一直换位');
    this.startAt = Date.now(); this.clock = setInterval(() => { this.tick(); }, 1000);
    this.hopper = setInterval(() => { this.jump(); }, HOP);
  }
  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.finish(); }
  }
  private jump(): void {
    if (this.over) { return; }
    let next: number = Math.floor(Math.random() * CELLS);
    while (next === this.hot) {
      next = Math.floor(Math.random() * CELLS);
    }
    this.hot = next;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.hot   ｜ 守卫取自它自己的 if (...) { return; }
  /** 提示：报答案（字段 this.hot） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.hot],
      TG2('答案是第 {0} 个', String(this.hot + 1)),
      TG2('The answer is option {0}', String(this.hot + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
    if (this.over) {
      return true;
    }
    this.tap(this.hot);
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

  private tap(i: number): void {
    if (this.over) { return; }
    if (i === this.hot) {
      this.hits = this.hits + 1; this.msg = TG2('✅ 命中 {0}',Digits(String(this.hits), this.langCode)); this.jump(); this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
    } else {
      this.miss = this.miss + 1; this.msg = TG('❌ 点偏了'); this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    }
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.stop(); this.over = true; this.won = this.hits >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG2('命中 {0} · 误点 {1}',Digits(String(this.hits), this.langCode),Digits(String(this.miss), this.langCode));
    const raw: number = this.hits * 100 - this.miss * 30; const r: GameResult = {
      gameId: 'dynamic_salience', solved: this.won,
      score: raw > 0 ? raw : 0, durationMs: Date.now() - this.startAt,
      levelReached: this.hits
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
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left > 0 ? this.left : 0) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hits), this.langCode)).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(NEED), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text((r * SIDE + c) === this.hot ? '🌟' : '').fontSize(FontSize.lg)
              }.layoutWeight(1).aspectRatio(1).backgroundColor((r * SIDE + c) === this.hot ? Palette.amber : this.theme.surfaceAlt)
              .borderRadius(Radius.md).scale({ x: (r * SIDE + c) === this.hot ? 1.06 : 1, y: (r * SIDE + c) === this.hot ? 1.06 : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * SIDE + c)); }); }).onClick(() => { Haptics.tick(); this.tap((r * SIDE + c)); })
            }, (c: number) => 'sc' + c)
          }.width('100%')
        }, (r: number) => 'sr' + r)
      }.width('100%').aspectRatio(1)
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：它每 1.5 秒换一次位置，手快一点')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
