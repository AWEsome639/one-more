/**
 * 猜数字 —— 7 次机会二分逼近 1~100 的秘密数字
 * 胜负：7 次内猜中 ⇒ 通关；次数用尽 ⇒ 失败｜进度：已用次数 / 当前范围
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LO: number = 1;
const HI: number = 100;
const MAX_TRIES: number = 7;
const KEEP: number = 4;

@Component
export struct GMathGuess {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 MAX_TRIES=7，按难度换算
  @State private diffTotal: number = GameDiff.livesNow(7);
  onFinish: (r: GameResult) => void = () => {};

  @State secret: number = 0; @State guess: number = 50; @State tries: number = 0;
  @State lowBound: number = LO; @State highBound: number = HI;
  @State history: string[] = []; @State hint: string = ''; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false;
  /** ★ 2026-10-14 动效（奥森：「动画要拉满」）：猜数变化时弹一下 */
  @State private bump: number = 1;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(7);
     this.reset(); }

  /** ★ 弹一下：先放大再回弹（140ms 一个来回） */
  private doBump(): void {
    this.bump = 1.12;
    setTimeout(() => { this.bump = 1; }, 140);
  }

  private reset(): void {
    this.secret = LO + Math.floor(Math.random() * (HI - LO + 1));
    this.guess = Math.floor((LO + HI) / 2);
    this.tries = 0; this.lowBound = LO; this.highBound = HI;
    this.history = []; this.hint = TG('提示：每猜一次就能砍掉一半范围');
    this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now();
  }

  private submit(): void {
    if (this.over) { return; }
    const v: number = Math.round(this.guess);
    this.tries = this.tries + 1;
    const left: number = this.diffTotal - this.tries;
    const line: string = TG2("第 {0} 猜：{1}", this.tries, v);
    this.doBump();   // ★ 提交也弹一下
    if (v === this.secret) {
      const gain: number = 100 + left * 150;
      this.score = this.score + gain;
      this.history = this.history.concat([line + ' ✅ 命中']);
      this.over = true; this.won = true;
      this.hint = TG2('🎉 就是 {0}！还剩 {1} 次没用，+{2}', v, left, gain);
      this.finish(true);
      return;
    }
    if (v < this.secret) {
      if (v + 1 > this.lowBound) { this.lowBound = v + 1; }
      this.hint = TG('⬆️ 小了，往大猜');
    } else {
      if (v - 1 < this.highBound) { this.highBound = v - 1; }
      this.hint = TG('⬇️ 大了，往小猜');
    }
    this.history = this.history.concat([line + (v < this.secret ? ' ↑' : ' ↓')]);
    if (left <= 0) {
      this.over = true;
      this.hint = TG2('💤 机会用完，答案是 {0}', this.secret);
      this.finish(false);
      return;
    }
    this.nudge(0);
  }

  /** delta=0 跳到范围中位；±1 微调。结果始终夹在 [lowBound, highBound] */
  private nudge(delta: number): void {
    if (this.over) { return; }
    const mid: number = Math.floor((this.lowBound + this.highBound) / 2);
    let v: number = delta === 0 ? mid : Math.round(this.guess) + delta;
    if (v < this.lowBound) { v = this.lowBound; }
    if (v > this.highBound) { v = this.highBound; }
    this.guess = v;
    this.doBump();   // ★ 弹一下
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'math_guess', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.tries };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private recentText(): string {
    if (this.history.length === 0) { return TG('（还没有猜测记录）'); }
    return this.history.slice(Math.max(0, this.history.length - KEEP)).join('\n');
  }

  build() {
    Column({ space: Space.md }) {
      Text(TG2('已用 {0}/{1}　范围 {2}', String(this.tries), String(this.diffTotal), String(this.lowBound))
        + TG2('~{0}　分 {1}',Digits(String(this.highBound), this.langCode),Digits(String(this.score), this.langCode)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(String(Math.round(this.guess)))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
          // ★ 动效：猜数一变就弹一下（原来是硬切）
          .scale({ x: this.bump, y: this.bump })
          .animation({ duration: Motion.fast, curve: Motion.spring() })
        Text(this.hint).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Row({ space: Space.sm }) {
        Button('−1')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).onClick(() => { this.nudge(-1); })
        Button(TG('中位'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).onClick(() => { this.nudge(0); })
        Button('+1')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).onClick(() => { this.nudge(1); })
      }.width('100%')
      Button(TG2('就猜 {0}', Math.round(this.guess)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(48))
        .enabled(!this.over).onClick(() => { this.submit(); })
      Text(this.recentText())
        .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Row({ space: Space.md }) {
        Text(this.over ? (this.won ? TG('已通关 🎉') : '已结束 💤') : '二分法 7 次足够覆盖 1~100')
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint).layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { this.reset(); })
      }.width('100%')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
