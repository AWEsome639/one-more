/**
 * 倒背数字 —— 数字逐个闪现，凭记忆倒序点回去
 *
 * 胜负：6 轮答对 5 轮以上 ⇒ 通关；位数每两轮加长一位
 * 进度：轮次 / 答对 / 位数 / 已输入
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const TRIALS: number = 6; const NEED: number = 5; const BASE: number = 3;
const IDLE: number = -3;   // 未开始
const ASK: number = -2;    // 播完，等作答
const LOCK: number = -4;   // 已判定，锁定输入
@Component
export struct GDigitSpanReverse {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State private seq: number[] = [];
  @State private cursor: number = IDLE;
  @State private flash: boolean = false;
  @State private typed: number[] = [];
  @State private trialNo: number = 1;
  @State private right: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private to1: number = -1;
  private to2: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
    if (this.to2 >= 0) { clearTimeout(this.to2); this.to2 = -1; }
  }
  /** 位数：3,3,4,4,5,5 */
  private span(): number { return BASE + Math.floor((this.trialNo - 1) / 2); }
  private reset(): void {
    this.stop(); this.trialNo = 1; this.right = 0; this.over = false; this.won = false; this.done = false;
    this.typed = []; this.startAt = Date.now(); this.newTrial();
  }
  private newTrial(): void {
    const list: number[] = [];
    for (let i = 0; i < this.span(); i++) {
      list.push(1 + Math.floor(Math.random() * 9));
    }
    this.seq = list; this.typed = []; this.cursor = IDLE; this.flash = false;
    this.msg = TG2("第 {0} 轮 · 记住 {1} 个数字", String(this.trialNo), String(this.span()));
    this.to1 = setTimeout(() => { this.to1 = -1; this.play(0); }, 700);
  }
  private play(k: number): void {
    if (k >= this.seq.length) {
      this.cursor = ASK; this.flash = false; this.msg = TG('倒序点出来：先点最后一个');
      return;
    }
    this.cursor = k; this.flash = true; this.to1 = setTimeout(() => {
      this.to1 = -1; this.flash = false;
      this.to2 = setTimeout(() => { this.to2 = -1; this.play(k + 1); }, 180);
    }, 720);
  }
  private tapDigit(d: number): void {
    if (this.over || this.cursor !== ASK) { return; }
    const expect: number = this.seq[this.seq.length - 1 - this.typed.length];
    const next: number[] = this.typed.slice();
    next.push(d);
    this.typed = next;
    if (d !== expect) {
      this.cursor = LOCK; this.msg = TG2("❌ 第 {0} 位错了，应为 {1}", String(next.length), String(expect));
      this.to1 = setTimeout(() => { this.to1 = -1; this.advance(); }, 1100);
      return;
    }
    if (next.length === this.seq.length) {
      this.right = this.right + 1; this.cursor = LOCK; this.msg = TG('✅ 全对！');
      this.to1 = setTimeout(() => { this.to1 = -1; this.advance(); }, 700);
    }
  }
  private advance(): void {
    if (this.trialNo >= this.diffTotal) {
      this.won = this.right >= NEED; this.over = true;
      this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
      this.finish();
      return;
    }
    this.trialNo = this.trialNo + 1; this.newTrial();
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'digit_span_reverse', solved: this.won,
      score: this.right * 150, durationMs: Date.now() - this.startAt,
      levelReached: this.span()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('位数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.span()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        Text(this.cursor >= 0 && this.flash ? String(this.seq[this.cursor]) : (this.cursor === ASK ? '？' : '·'))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.sky)
      }.width('100%').height(110).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              Text(String((r * 3 + c + 1))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(48)).backgroundColor(this.theme.surfaceAlt)
              .borderRadius(Radius.sm).onClick(() => { Haptics.tick(); this.tapDigit((r * 3 + c + 1)); })
            }, (c: number) => 'kc' + c)
          }.width('100%')
        }, (r: number) => 'kr' + r)
      }.width('100%')
      Text(TG2("已输入：{0}", (this.typed.length === 0 ? '—' : this.typed.join(' ')))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky).borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
        .width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
