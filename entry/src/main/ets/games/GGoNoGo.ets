/**
 * 去或停（Go / No-Go）—— 绿灯要快点，红灯要忍住
 * 胜负：20 试里正确 ≥ 17 且误点 ≤ 1 ⇒ 通关；进度：试次 / 正确 / 误点
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TRIALS: number = 20;
const WINDOW: number = 1000;      // 反应窗口
const NOGO_RATE: number = 0.25;
const NEED_CORRECT: number = 17;
const MAX_FA: number = 1;

@Component
export struct GGoNoGo {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};

  @State private kind: number = 0;        // 0 绿灯 1 红灯
  @State private live: boolean = false;
  @State private trialNo: number = 1;
  @State private hitN: number = 0;        // 绿灯按了
  @State private missN: number = 0;       // 绿灯没按
  @State private faN: number = 0;         // 红灯按了
  @State private crN: number = 0;         // 红灯忍住
  @State private fbMark: number = 0;      // 0 无 1 对 2 错
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private shownAt: number = 0;
  private waitTo: number = -1;
  private closeTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.closeTo >= 0) { clearTimeout(this.closeTo); this.closeTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.hitN = 0; this.missN = 0; this.faN = 0; this.crN = 0;
    this.fbMark = 0; this.live = false;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('绿灯点、红灯忍');
    this.startAt = Date.now();
    this.schedule();
  }

  /** 随机等 0.6~1.4 秒亮灯，亮 1 秒内必须作出反应 */
  private schedule(): void {
    this.live = false;
    this.fbMark = 0;
    this.msg = TG('准备…');
    this.kind = Math.random() < NOGO_RATE ? 1 : 0;
    this.waitTo = setTimeout(() => {
      this.waitTo = -1;
      this.shownAt = Date.now();
      this.live = true;
      this.msg = this.kind === 0 ? '🟢 快按！' : '🔴 别动！';
      this.closeTo = setTimeout(() => { this.closeTo = -1; this.resolve(false); }, WINDOW);
    }, 600 + Math.floor(Math.random() * 800));
  }

  private tap(): void {
    if (this.over || !this.live) { return; }
    if (this.closeTo >= 0) { clearTimeout(this.closeTo); this.closeTo = -1; }
    this.resolve(true);
  }

  private resolve(pressed: boolean): void {
    this.live = false;
    const isGo: boolean = this.kind === 0;
    if (isGo && pressed) {
      this.hitN = this.hitN + 1; this.fbMark = 1;
      this.msg = '✅ ' + String(Date.now() - this.shownAt) + ' ms';
    } else if (isGo) {
      this.missN = this.missN + 1; this.fbMark = 2;
      this.msg = TG('❌ 绿灯要按的');
    } else if (pressed) {
      this.faN = this.faN + 1; this.fbMark = 2;
      this.msg = TG('🚫 红灯不该按');
    } else {
      this.crN = this.crN + 1; this.fbMark = 1;
      this.msg = TG('🛑 忍住了');
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.trialNo >= this.diffTotal) { this.judge(); return; }
      this.trialNo = this.trialNo + 1;
      this.schedule();
    }, 620);
  }

  private correctN(): number {
    return this.hitN + this.crN;
  }

  private judge(): void {
    this.clearAll();
    this.over = true;
    this.won = this.correctN() >= NEED_CORRECT && this.faN <= MAX_FA;
    this.msg = TG2(this.won ? '🎉 通关！正确 {0}/{1}' : '💤 结束，正确 {0}/{1}', String(this.correctN()),Digits(String(this.diffTotal), this.langCode))
      + TG2(' · 误点 {0} 次',Digits(String(this.faN), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'go_no_go', solved: this.won,
        score: Math.max(0, this.correctN() * 60 - this.faN * 120),
        durationMs: Date.now() - this.startAt, levelReached: this.correctN()
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.over ? this.diffTotal : this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('正确'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.correctN()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('误点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.faN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(this.live ? (this.kind === 0 ? '🟢' : '🔴') : (this.over ? (this.won ? '🎉' : '💤') : '👀'))
          .fontSize(FontSize.hero)
          .scale({ x: this.live ? 1.1 : 1, y: this.live ? 1.1 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }.width('100%').height(Space.xxxl * 2).justifyContent(FlexAlign.Center)
      .backgroundColor(this.fbMark === 1 ? '#1A10B981' : (this.fbMark === 2 ? '#1AEF4444' : this.theme.surface))
      .borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(TG('点！')).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .textAlign(TextAlign.Center).width('100%').height(Space.xxxl * 2)
        .backgroundColor(this.live && this.kind === 0 ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.lg).opacity(this.live ? 1 : 0.5)
        .scale({ x: this.fbMark === 2 ? Motion.pressScale : 1, y: this.fbMark === 2 ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tap(); })

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('判定：正确 ≥ {0}/{1}', String(NEED_CORRECT), String(this.diffTotal))
        + TG2(' 且误点 ≤ {0} 次 · 红灯约四分之一',Digits(String(MAX_FA), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
