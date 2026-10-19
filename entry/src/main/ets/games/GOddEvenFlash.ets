/**
 * 奇偶闪现 —— 数字一闪而过，消失后判断它是奇数还是偶数，闪现越来越快
 * 胜负：18 题答对 ≥ 13 ⇒ 通关　｜　进度：题号 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TRIALS: number = 18;
const PASS: number = 13;
const START_MS: number = 1500;
const FLOOR_MS: number = 600;
const STEP_MS: number = 50;
const FEED_MS: number = 620;

@Component
export struct GOddEvenFlash {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State value: number = 0;
  @State visible: boolean = true; @State canAnswer: boolean = false; @State locked: boolean = false;
  @State trial: number = 1; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  /** 每答一题快一点：1500ms ⇒ 600ms 封底 */
  private flashMs(): number {
    const ms: number = START_MS - (this.trial - 1) * STEP_MS;
    return ms < FLOOR_MS ? FLOOR_MS : ms;
  }

  private reset(): void {
    this.clearAll();
    this.trial = 1; this.right = 0; this.score = 0; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newTrial();
  }

  private newTrial(): void {
    this.value = 11 + Math.floor(Math.random() * 89);
    this.visible = true; this.canAnswer = false; this.locked = false;
    this.msg = TG2("第 {0} 题：看清这个数（{1} ms）", this.trial, this.flashMs());
    this.timer = setTimeout(() => {
      this.timer = -1; this.visible = false; this.canAnswer = true;
      this.msg = TG('它是奇数还是偶数？');
    }, this.flashMs());
  }

  private answer(isOdd: boolean): void {
    if (!this.canAnswer || this.locked || this.over) { return; }
    this.locked = true;
    const truth: boolean = this.value % 2 === 1;
    const word: string = truth ? '奇数' : TG('偶数');
    if (truth === isOdd) {
      this.right = this.right + 1; this.score = this.score + 60;
      this.msg = TG2('✅ {0} 是{1}', this.value, word);
    } else {
      this.msg = TG2('❌ {0} 是{1}', this.value, word);
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.trial >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.trial = this.trial + 1;
    this.newTrial();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'odd_even_flash', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.lime))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        Text(this.visible ? String(this.value) : '?').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.visible ? this.theme.ink : this.theme.inkFaint)
      }.width('100%').layoutWeight(1).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.sm }) {
        Button((TG('奇数')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor((true) ? Palette.violet : Palette.sky)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .enabled(this.canAnswer && !this.locked && !this.over)
        .onClick(() => { Haptics.tap(); this.answer((true)); })
        Button((TG('偶数')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor((false) ? Palette.violet : Palette.sky)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .enabled(this.canAnswer && !this.locked && !this.over)
        .onClick(() => { Haptics.tap(); this.answer((false)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('提示：数字消失后才能作答，答满 {0} 题对 {1} 题即通关',Digits(String(this.diffTotal), this.langCode),Digits(String(PASS), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
