/**
 * 连续再认 —— 图形一个接一个，判断「刚才见过没有」
 * 胜负：24 题答对 ≥ 17 通关，错满 6 题判负　｜　进度：题号 / 答对 / 错误
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐟', '🔔', '🍀', '🚀',
  '🎲', '🪁', '🧩', '🌻', '🍄', '⚓', '🎩', '🪐'];
const TRIALS: number = 24;
const PASS: number = 17;
const LAG: number = 4;          // 至少隔 4 个位置才允许重复
const REPEAT_P: number = 0.45;  // 重复题占比
const MAX_WRONG: number = 6;
const PER_HIT: number = 50;

interface RecItem {
  icon: string;
  isOld: boolean;
}

@Component
export struct GContinuousRecognition {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};

  @State seq: RecItem[] = [];
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
    this.msg = TG('第一次见点 🆕，见过点 🔁');
    this.seq = this.buildSeq();
    this.startAt = Date.now();
  }

  /** 生成题流：新图形 + 带间隔的旧图形 */
  private buildSeq(): RecItem[] {
    const seq: RecItem[] = [];
    const seen: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      const fresh: string[] = this.unused(seen);
      const wantOld: boolean = i >= LAG && seen.length >= 3 && Math.random() < REPEAT_P;
      if (wantOld || fresh.length === 0) {
        const j: number = Math.floor(Math.random() * seen.length);
        const oldOne: RecItem = { icon: seen[j], isOld: true };
        seq.push(oldOne);
      } else {
        const ic: string = fresh[Math.floor(Math.random() * fresh.length)];
        seen.push(ic);
        const newOne: RecItem = { icon: ic, isOld: false };
        seq.push(newOne);
      }
    }
    return seq;
  }

  private unused(seen: string[]): string[] {
    const out: string[] = [];
    for (let i = 0; i < POOL.length; i++) {
      if (seen.indexOf(POOL[i]) < 0) { out.push(POOL[i]); }
    }
    return out;
  }

  private answer(sayOld: boolean): void {
    if (this.over || this.trial >= this.seq.length) { return; }
    const it: RecItem = this.seq[this.trial];
    const truth: boolean = it.isOld;
    if (sayOld === truth) {
      this.correct++;
      this.msg = TG2("✅ 答对 {0} 题", this.correct);
    } else {
      this.wrong++;
      this.msg = truth ? '❌ 它前面出现过' : '❌ 它是第一次出现';
    }
    this.trial++;
    if (this.wrong >= MAX_WRONG) { this.end(false); return; }
    if (this.trial >= this.diffTotal) { this.end(this.correct >= PASS); return; }
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.msg = solved ? '🎉 通关：答对 ' + this.correct + ' / ' + this.diffTotal
      : TG('答对 ') + this.correct + ' 题，再来一局';
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'continuous_recognition', solved: solved, score: this.correct * PER_HIT,
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

      Stack() {
        Text(this.seq.length > 0 && this.trial < this.seq.length ? this.seq[this.trial].icon : '🏁')
          .fontSize(FontSize.hero)
      }.width('100%').layoutWeight(1).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button((TG('🆕 第一次见')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor((false) ? Palette.primary : Palette.sky).animation({ duration: Motion.fast, curve: Motion.snap() })
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.answer((false)); })
        Button((TG('🔁 见过')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor((true) ? Palette.primary : Palette.sky)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.answer((true)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('答满 {0} 题且答对 ≥ {1} 即通关',Digits(String(this.diffTotal), this.langCode),Digits(String(PASS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
