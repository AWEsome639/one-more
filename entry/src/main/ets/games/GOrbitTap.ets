/**
 * 轨道点击 👆
 * 规则：环形轨道上排着 12 个落脚点，目标 🛰️ 每 1.1 秒跳到别处；点中一次 +1。
 * 胜负：25 秒内点中 10 次 ⇒ 通关；时间耗尽 ⇒ 失败。　进度：命中 / 剩余秒 / 点空
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

const ARENA: number = 280; const RING: number = 100; const SLOTS: number = 12;
const DOT: number = 42; const NEED: number = 10; const LIMIT: number = 25; const HOP: number = 1100;
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/** 轨道区固定 ARENA 见方 ⇒ 用百分比定位，换算精确 */
function pctOf(px: number): string { return (px * 100 / ARENA).toFixed(2) + '%'; }
function slotX(i: number): number { return ARENA / 2 + RING * Math.cos(i * 2 * Math.PI / SLOTS) - DOT / 2; }
function slotY(i: number): number { return ARENA / 2 + RING * Math.sin(i * 2 * Math.PI / SLOTS) - DOT / 2; }

@Component
export struct GOrbitTap {
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
  @State private target: number = 0; @State private hits: number = 0; @State private miss: number = 0;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0; @State private over: boolean = false; @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private clock: number = -1; private hop: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    if (this.hop >= 0) { clearInterval(this.hop); this.hop = -1; }
  }
  private reset(): void {
    this.stop(); this.target = Math.floor(Math.random() * SLOTS); this.hits = 0; this.miss = 0;
    this.left = this.total; this.over = false; this.won = false; this.done = false;
    this.msg = TG('点中亮起的 🛰️，它会一直跳'); this.startAt = Date.now();
    this.clock = setInterval(() => { this.tick(); }, 1000);
    this.hop = setInterval(() => { this.move(); }, HOP);
  }
  private move(): void {
    if (this.over) { return; }
    let n: number = Math.floor(Math.random() * SLOTS);
    while (n === this.target) { n = Math.floor(Math.random() * SLOTS); }
    this.target = n;
  }
  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.finish(false); }
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.target],
      TG2('答案是第 {0} 个', String(this.target + 1)),
      TG2('The answer is option {0}', String(this.target + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.target   ｜ 守卫条件取自它自己的 if (...) { return; }
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
      return true;              // 还没到能作答的时刻 / 已经答过，等推进
    }
    this.tap(this.target);
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
    if (i === this.target) {
      this.hits = this.hits + 1; this.msg = TG2("✅ 命中 {0} 次",Digits(String(this.hits), this.langCode)); this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
      if (this.hits >= NEED) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
      this.move();
    } else { this.miss = this.miss + 1; this.msg = TG('❌ 点空了，它在别的格子上'); }
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.stop(); this.over = true; this.won = solved;
    if (this.left < 0) { this.left = 0; }
    this.msg = solved ? '🎉 全部点中！' : TG2("⏰ 时间到，命中 {0} 次",Digits(String(this.hits), this.langCode));
    const raw: number = this.hits * 100 - this.miss * 20;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'orbit_tap', solved: solved, score: raw > 0 ? raw : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    });
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.hits) + '/' + String(NEED))).fontSize(FontSize.md)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left > 0 ? this.left : 0) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('点空'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        Stack().width(RING * 2).height(RING * 2).borderRadius(Radius.full)
          .borderWidth(2).borderColor(this.theme.lineSoft)
        ForEach(IDX, (i: number) => { Stack() {
        Text((i) === this.target ? '🛰️' : '').fontSize(FontSize.xl)
        }.width(DOT).height(DOT).borderRadius(Radius.full)
        .backgroundColor((i) === this.target ? Palette.cyan : this.theme.surfaceAlt)
        .position({ x: pctOf(slotX((i))), y: pctOf(slotY((i))) })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tap((i)); }) }, (i: number) => 'slot' + i)
      }.width(ARENA).height(ARENA).backgroundColor(this.theme.surface)
      .borderRadius(Radius.xl).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
