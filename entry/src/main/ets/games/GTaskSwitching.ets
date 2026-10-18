/**
 * 切换代价（task_switching）—— 同一刺激，按提示在「判形状」与「判颜色」间切换，对比两种试次反应时
 * 胜负：16 轮答对 ≥12 ⇒ 通关；进度：轮次 / 答对 / 重复-切换平均反应时与代价
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TRIALS: number = 16;
const NEED: number = 12;

@Component
export struct GTaskSwitching {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State trialNo: number = 1;
  @State right: number = 0;
  @State wrong: number = 0;
  @State rule: number = 0;          // 0=判形状 1=判颜色
  @State shape: number = 0;         // 0=圆 ● 1=方 ■
  @State hue: number = 0;           // 0=红 1=蓝
  @State pick: number = -1;
  @State switched: boolean = false;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private prevRule: number = -1;
  private qAt: number = 0;
  private repSum: number = 0;
  private repN: number = 0;
  private swSum: number = 0;
  private swN: number = 0;
  private startAt: number = 0;
  private to: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.to >= 0) { clearTimeout(this.to); this.to = -1; } }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.right = 0; this.wrong = 0; this.pick = -1; this.over = false;
    this.won = false; this.done = false; this.prevRule = -1;
    this.repSum = 0; this.repN = 0; this.swSum = 0; this.swN = 0;
    this.msg = TG('先看规则，再判刺激');
    this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const keep: boolean = this.prevRule >= 0 && Math.random() < 0.5;
    this.rule = this.prevRule < 0 ? 0 : (keep ? this.prevRule : 1 - this.prevRule);
    this.switched = this.prevRule >= 0 && this.rule !== this.prevRule;
    this.prevRule = this.rule;
    this.shape = Math.random() < 0.5 ? 0 : 1;
    this.hue = Math.random() < 0.5 ? 0 : 1;
    this.pick = -1;
    this.qAt = Date.now();
  }

  private ruleName(): string { return this.rule === 0 ? '判形状' : '判颜色'; }
  private avgRep(): number { return this.repN > 0 ? Math.round(this.repSum / this.repN) : 0; }
  private avgSw(): number { return this.swN > 0 ? Math.round(this.swSum / this.swN) : 0; }
  private cost(): number { return this.avgSw() - this.avgRep(); }
  private optName(i: number): string {
    return this.rule === 0 ? (i === 0 ? '● 圆' : '■ 方') : (i === 0 ? '🔴 红' : '🔵 蓝');
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    const rt: number = Date.now() - this.qAt;
    if (this.switched) { this.swSum = this.swSum + rt; this.swN = this.swN + 1; }
    else { this.repSum = this.repSum + rt; this.repN = this.repN + 1; }
    const want: number = this.rule === 0 ? this.shape : this.hue;
    if (i === want) { this.right = this.right + 1; this.msg = '✅ ' + String(rt) + 'ms'; }
    else { this.wrong = this.wrong + 1; this.msg = TG2('❌ {0}ms，应选 {1}', String(rt), this.optName(want)); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.trialNo >= this.diffTotal) { this.finishUp(); return; }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
    }, 520);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal))
      + TG2(' · 切换代价 {0}ms', String(this.cost()));
    this.clearAll();
    const r: GameResult = {
      gameId: 'task_switching', solved: this.won, score: this.right * 100 - this.wrong * 40,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trialNo + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG2("本轮规则：{0}{1}", this.ruleName(), (this.switched ? ' 🔀' : ' ↻'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Palette.cyan)
        Text(this.shape === 0 ? '●' : '■').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.hue === 0 ? Palette.rose : Palette.sky)
      }.width('100%').height(136).justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Text(this.optName((0))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64)).backgroundColor(this.pick === (0) ? Palette.cyan : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card).scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((0)); })
        Text(this.optName((1))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64)).backgroundColor(this.pick === (1) ? Palette.cyan : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card).scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((1)); })
      }.width('100%')

      Text(TG2('重复 {0}ms · 切换 {1}ms · 代价 ', String(this.avgRep()), String(this.avgSw()))
        + String(this.cost()) + 'ms')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.cyan).width('100%').textAlign(TextAlign.Center).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.cyan).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })

      Text(TG('提示：切换试次比重复试次慢多少，就是这一局的「切换代价」')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
