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
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
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
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * SIDE + c)); })
            }, (c: number) => 'sc' + c)
          }.width('100%')
        }, (r: number) => 'sr' + r)
      }.width('100%').aspectRatio(1)
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：它每 1.5 秒换一次位置，手快一点')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
