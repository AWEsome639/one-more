/**
 * 数字探针 —— 数字一位一位闪现，闪完后问「第 k 位是几」，用键盘答出来
 * 胜负：位数从 3 一路答到 8 位 ⇒ 通关；中途答错 ⇒ 失败　｜　进度：位数 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const START_LEN: number = 3;
const MAX_LEN: number = 8;
const SHOW_MS: number = 620;
const FEED_MS: number = 800;
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1, 2, 3, 4];

@Component
export struct GProbeDigitSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 MAX_LEN=8
  @State private diffTotal: number = GameDiff.sizeNow(8);
  onFinish: (r: GameResult) => void = () => {};
  @State digits: number[] = [];
  @State phase: number = 0;        // 0 呈现　1 探针　2 反馈
  @State at: number = 0; @State probe: number = 0; @State len: number = START_LEN;
  @State typed: string = ''; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll();
    this.len = START_LEN; this.right = 0; this.score = 0; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newLevel();
  }

  private newLevel(): void {
    const digits: number[] = [];
    for (let i = 0; i < this.len; i++) { digits.push(Math.floor(Math.random() * 10)); }
    this.digits = digits; this.at = 0; this.typed = ''; this.phase = 0;
    this.msg = TG2("记住这 {0} 位数字，逐位闪现", this.len);
    this.showStep();
  }

  /** 一位一位地闪；闪完立刻出探针 */
  private showStep(): void {
    if (this.at >= this.digits.length) { this.askProbe(); return; }
    this.timer = setTimeout(() => {
      this.timer = -1; this.at = this.at + 1; this.showStep();
    }, SHOW_MS);
  }

  private askProbe(): void {
    this.phase = 1;
    this.probe = Math.floor(Math.random() * this.digits.length);
    this.typed = '';
    this.msg = TG2("第 {0} 位是几？（从左数）", (this.probe + 1));
  }

  private answer(d: number): void {
    if (this.phase !== 1) { return; }
    this.typed = String(d);
    const want: number = this.digits[this.probe];
    if (d !== want) {
      this.end(false, TG('❌ 第 ') + (this.probe + 1) + ' 位是 ' + want + '，你答了 ' + d);
      return;
    }
    this.right = this.right + 1;
    this.score = this.score + 60 + this.len * 20;
    this.phase = 2;
    this.msg = TG2("✅ 第 {0} 位正是 {1}", (this.probe + 1), want);
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.len >= this.diffTotal) { this.end(true, TG2('✅ {0} 位也答对了', this.diffTotal)); return; }
      this.len = this.len + 1; this.newLevel();
    }, FEED_MS);
  }

  private end(solved: boolean, note: string): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true; this.won = solved; this.phase = 2;
    this.msg = note + (solved ? '　🎉 通关' : '　💤 结束');
    this.clearAll();
    const r: GameResult = { gameId: 'probe_digit_span', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.len };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('位数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.len), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        if (this.phase === 0) {
          Text(this.at < this.digits.length ? String(this.digits[this.at]) : '').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        } else {
          Column({ space: Space.xs }) {
            Text(TG('你的答案')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
            Text(this.typed.length > 0 ? this.typed : '?').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.phase === 1 ? this.theme.inkFaint : Palette.emerald)
          }
        }
      }.width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (col: number) => { Button(String((row * 5 + col)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF')
            .backgroundColor(this.typed === String((row * 5 + col)) && this.phase === 1 ? Palette.sky : Palette.primary).animation({ duration: Motion.fast, curve: Motion.snap() })
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50))
            .enabled(this.phase === 1)
            .onClick(() => { Haptics.tap(); this.answer((row * 5 + col)); }) }, (col: number) => 'dk' + row + '_' + col)
          }.width('100%')
        }, (row: number) => 'dr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('提示：位数从 {0} 涨到 {1}，答错一次就结束',Digits(String(START_LEN), this.langCode),Digits(String(this.diffTotal), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
