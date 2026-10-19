/**
 * 色词匹配 —— 斯特鲁普式「词义 vs 墨色」
 * 胜负：24 题答对 ≥ 16 通关，错满 6 题判负　｜　进度：题号 / 答对 / 错误
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const NAMES: string[] = [TG('红'), TG('黄'), TG('蓝'), TG('绿')];
const INKS: string[] = ['#EF4444', '#F59E0B', '#0EA5E9', '#10B981'];
const TRIALS: number = 24;
const PASS: number = 16;
const MAX_WRONG: number = 6;
const PER_HIT: number = 20;

@Component
export struct GColorWordMatchUp {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};

  @State wordIdx: number = 0;
  @State inkIdx: number = 0;
  @State trial: number = 0;
  @State correct: number = 0;
  @State wrong: number = 0;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }

  private reset(): void {
    this.trial = 0; this.correct = 0; this.wrong = 0;
    this.over = false; this.won = false; this.finished = false;
    this.msg = TG('词义与墨色一致吗？');
    this.startAt = Date.now();
    this.nextTrial();
  }

  private nextTrial(): void {
    this.wordIdx = Math.floor(Math.random() * NAMES.length);
    this.inkIdx = Math.floor(Math.random() * INKS.length);
  }

  private answer(saySame: boolean): void {
    if (this.over) { return; }
    const wi: number = this.wordIdx;
    const ii: number = this.inkIdx;
    const same: boolean = wi === ii;
    if (saySame === same) {
      this.correct++;
      this.msg = TG2("✅ 答对 {0} 题", this.correct);
    } else {
      this.wrong++;
      this.msg = TG2("❌ 其实是{0}", (same ? '一致' : '不一致'));
    }
    this.trial++;
    if (this.wrong >= MAX_WRONG) { this.end(false); return; }
    if (this.trial >= this.diffTotal) { this.end(this.correct >= PASS); return; }
    this.nextTrial();
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.msg = solved ? '🎉 通关：答对 ' + this.correct + ' / ' + this.diffTotal
      : TG('答对 ') + this.correct + ' 题，再来一局';
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'color_word_match_up', solved: solved, score: this.correct * PER_HIT,
      durationMs: Date.now() - this.startAt, levelReached: this.correct
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.trial + 1, this.diffTotal) + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.correct), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.wrong + ' / ' + MAX_WRONG)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(TG('它的墨色是')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(NAMES[this.wordIdx]).fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(INKS[this.inkIdx]).padding(Space.lg).backgroundColor(this.theme.surface)
          .borderRadius(Radius.lg).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').layoutWeight(1)

      Row({ space: Space.sm }) {
        Button((TG('✅ 一致')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor((true) ? Palette.emerald : Palette.sky)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.answer((true)); })
        Button((TG('❌ 不一致')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor((false) ? Palette.emerald : Palette.sky)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.answer((false)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('答满 {0} 题且答对 ≥ {1} 即通关',Digits(String(this.diffTotal), this.langCode),Digits(String(PASS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
