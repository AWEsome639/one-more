/** 勾股数 —— 构造勾股三元组｜6 关解出 5 关过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LEVELS: number = 6;
const PASS: number = 5;

interface Tri { a: number; b: number; c: number }

const TRIPLES: Tri[] = [
  { a: 3, b: 4, c: 5 }, { a: 5, b: 12, c: 13 }, { a: 6, b: 8, c: 10 },
  { a: 7, b: 24, c: 25 }, { a: 8, b: 15, c: 17 }, { a: 9, b: 12, c: 15 },
  { a: 9, b: 40, c: 41 }, { a: 12, b: 16, c: 20 }, { a: 15, b: 20, c: 25 },
  { a: 20, b: 21, c: 29 }, { a: 10, b: 24, c: 26 }, { a: 18, b: 24, c: 30 }
];

@Component
export struct GPythagoreanTripleBuilder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State private ask: string = '';
  @State private ans: number = 5;
  @State private typed: string = '';
  @State private level: number = 0;
  @State private clears: number = 0;
  @State private miss: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = '';
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.level = 0;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.load();
  }

  private load(): void {
    const t: Tri = TRIPLES[Math.floor(Math.random() * TRIPLES.length)];
    const flip: boolean = Math.random() < 0.5;
    const ax: number = flip ? t.b : t.a;
    const bx: number = flip ? t.a : t.b;
    if (Math.random() < 0.5) {
      this.ask = TG2("两条直角边 {0} 与 {1}，斜边 = ?", String(ax), String(bx));
      this.ans = t.c;
    } else {
      this.ask = TG2("斜边 {0}，一条直角边 {1}，另一边 = ?", String(t.c), String(ax));
      this.ans = bx;
    }
    this.typed = '';
    this.miss = 0;
    this.tip = TG('a² + b² = c²，输入整数后点确认');
  }

  private typedValue(): number {
    let v: number = 0;
    for (let i = 0; i < this.typed.length; i++) { v = v * 10 + (this.typed.charCodeAt(i) - 48); }
    return v;
  }

  private pickKey(s: string): void {
    if (this.over) { return; }
    if (s === '⌫') {
      this.typed = this.typed.length > 0 ? this.typed.substring(0, this.typed.length - 1) : '';
      return;
    }
    if (s === TG('确认')) { this.submit(); return; }
    if (this.typed.length < 3) { this.typed = this.typed + s; }
  }

  private submit(): void {
    if (this.typed.length === 0) { this.tip = TG('先输入一个数'); return; }
    const v: number = this.typedValue();
    if (v === this.ans) {
      this.clears++;
      this.score += 14;
      this.next(TG2('✓ 正是 {0}', String(this.ans)));
      return;
    }
    this.miss++;
    this.score -= 3;
    if (this.miss >= 2) { this.next(TG2('✗ 正确答案是 {0}', String(this.ans))); return; }
    this.tip = TG2("{0} 不对，再算一次（a² + b² = c²）", String(v));
    this.typed = '';
  }

  private next(msg: string): void {
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("{0}｜共解出 {1}/{2} 关", msg,Digits(String(this.clears), this.langCode),Digits(String(this.diffTotal), this.langCode));
      const res: GameResult = {
        gameId: 'pythagorean_triple_builder', solved: this.clears >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.clears
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.load();
    this.tip = TG2("{0}，第 {1} 关", msg, String(this.level + 1));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.level + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已解出'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.clears), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(this.ask).fontSize(FontSize.lg).fontColor(this.theme.ink).textAlign(TextAlign.Center).width('100%')
        Text(this.typed.length > 0 ? this.typed : '?')
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.berry)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
        Button((('1')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('1')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('1')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('1')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('1'))); })
        Button((('2')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('2')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('2')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('2')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('2'))); })
        Button((('3')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('3')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('3')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('3')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('3'))); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('4')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('4')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('4')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('4')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('4'))); })
        Button((('5')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('5')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('5')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('5')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('5'))); })
        Button((('6')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('6')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('6')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('6')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('6'))); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('7')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('7')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('7')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('7')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('7'))); })
        Button((('8')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('8')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('8')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('8')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('8'))); })
        Button((('9')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('9')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('9')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('9')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('9'))); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('⌫')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('⌫')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('⌫')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('⌫')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('⌫'))); })
        Button((('0')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('0')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('0')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('0')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('0'))); })
        Button(((TG('确认'))))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(((TG('确认'))) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor(((TG('确认'))) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(((TG('确认'))) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey(((TG('确认')))); })
        }.width('100%')
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.berry)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('背熟的勾股数：3-4-5、5-12-13、8-15-17')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
