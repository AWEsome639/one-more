/** 整除冲刺（Divisibility Dash）—— 限时判断整除
 *  玩法：快速点「能整除 / 不能整除」。过关判据：45 秒内答对 ≥ 12 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LIMIT: number = 45;
const NEED: number = 12;

@Component
export struct GDivisibilityDash {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private num: number = 24;
  @State private div: number = 4;
  @State private yes: boolean = true;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private streak: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('整除吗？');

  private startAt: number = 0;
  private tick: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => {
      if (this.over) { return; }
      this.left--;
      if (this.left <= 0) {
        this.left = 0;
        this.over = true;
        this.tip = TG2("时间到｜答对 {0} 题", String(this.right));
        this.finish(false);
      }
    }, 1000);
  }

  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }

  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
  }

  private reset(): void {
    this.startAt = Date.now();
    this.left = this.total;
    this.right = 0;
    this.wrong = 0;
    this.score = 0;
    this.streak = 0;
    this.over = false;
    this.tip = TG('整除吗？');
    this.roll();
  }

  private roll(): void {
    const d: number = 2 + Math.floor(Math.random() * 11);
    const base: number = d * (2 + Math.floor(Math.random() * 28));
    const clean: boolean = Math.random() < 0.5;
    const n: number = clean ? base : base + 1 + Math.floor(Math.random() * (d - 1));
    this.div = d;
    this.num = n;
    this.yes = n % d === 0;
  }

  private answer(said: boolean): void {
    if (this.over) { return; }
    if (said === this.yes) {
      this.right++;
      this.streak++;
      this.score += 10 + (this.streak >= 5 ? 5 : 0); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.tip = TG2('✓ 对了，连击 {0}', String(this.streak));
      if (this.right >= NEED) {
        this.over = true;
        this.tip = TG2('达标！答对 {0} 题 🎉', String(this.right));
        this.finish(true);
        return;
      }
    } else {
      this.wrong++;
      this.streak = 0;
      this.score = Math.max(0, this.score - 5); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.tip = '✗ ' + String(this.num) + ' ÷ ' + String(this.div) + ' ' +
        (this.yes ? '能整除' : '不能整除');
    }
    this.roll();
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'divisibility_dash', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(NEED))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('🔢 整除吗？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        Text(String(this.num) + ' ÷ ' + String(this.div))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG2("连击 {0}", String(this.streak))).fontSize(FontSize.xs).fontColor(this.streak >= 5 ? Palette.orange : this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.md }) {
        Button(TG('能整除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(Palette.emerald).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('不能整除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.tip.startsWith('✓') ? Palette.emerald : this.theme.inkSoft).height(20)

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('答错 -5 分；连击 5 次起加分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
