/**
 * 反向斯特鲁普 —— 🧠 字用别的颜色印出来，请点「字义」而不是墨色（id: reverse_stroop）
 * 胜负：12 题答对 ≥ 10 且平均 < 1800ms ⇒ 通关；进度：题号/12 · 答对 · 平均
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const TOTAL: number = 12;
const WIN_RIGHT: number = 10;
const WIN_AVG: number = 1800;
const WORDS: string[] = [TG('红'), TG('蓝'), TG('绿'), TG('黄')];
const INKS: string[] = ['#EF4444', '#3B82F6', '#10B981', '#F59E0B'];
@Component
export struct GReverseStroop {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private wIdx: number = 0;
  @State private kIdx: number = 1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private totalMs: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private toId: number = -1;
  private done: boolean = false;
  private answered: number = 0;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearTo(); }
  private clearTo(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearTo();
    this.round = 1; this.right = 0; this.wrong = 0; this.totalMs = 0; this.pick = -1; this.answered = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.next();
  }
  /** 出题：字义与墨色必然不同 */
  private next(): void {
    const w: number = Math.floor(Math.random() * WORDS.length);
    let k: number = Math.floor(Math.random() * INKS.length);
    if (k === w) { k = (k + 1) % INKS.length; }
    this.wIdx = w; this.kIdx = k; this.pick = -1; this.shownAt = Date.now();
    this.msg = TG('点「字义」，别看墨色');
  }
  private avg(): number {
    return this.answered > 0 ? Math.round(this.totalMs / this.answered) : 0;
  }
  private answer(i: number): void {
    if (this.over || this.pick >= 0) { return; }
    const w: number = this.wIdx;
    const ok: boolean = i === w;
    this.totalMs = this.totalMs + (Date.now() - this.shownAt); this.answered = this.answered + 1;
    this.pick = i;
    if (ok) {
      this.right = this.right + 1;
      this.msg = TG('✅ 对');
    } else {
      this.wrong = this.wrong + 1;
      this.msg = TG2('❌ 字是「{0}」', WORDS[w]);
    }
    this.toId = setTimeout(() => {
      this.toId = -1;
      if (this.round >= this.diffTotal) { this.end(); return; }
      this.round = this.round + 1;
      this.next();
    }, 520);
  }
  private end(): void {
    if (this.done) { return; }
    const a: number = this.avg();
    this.clearTo();
    this.done = true; this.over = true; this.won = this.right >= WIN_RIGHT && a < WIN_AVG;
    this.msg = (this.won ? TG('🎉 通关 · 对 ') : TG('💤 结束 · 对 ')) +TG2("{0}/{1} · 平均 {2} ms", String(this.right), String(this.diffTotal), String(a));
    const r: GameResult = {
      gameId: 'reverse_stroop', solved: this.won, score: Math.max(0, this.right * 100 - Math.round(a / 20)),
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.avg() > 0 ? String(this.avg()) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('点「字义」· 别看墨色')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(WORDS[this.wIdx]).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(INKS[this.kIdx])
      }.width('100%').height(150).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Text(WORDS[(i)]).fontSize(FontSize.lg).fontColor('#FFFFFF').textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(72)).borderRadius(Radius.md)
          .backgroundColor(this.pick === (i) && (i) !== this.wIdx ? Palette.primaryDeep : INKS[(i)])
          .opacity(this.pick >= 0 && (i) !== this.wIdx && (i) !== this.pick ? 0.45 : 1)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
          .onClick(() => { this.answer((i)); })
        }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('判定：12 题答对 ≥ 10 且平均 < 1800 ms'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
