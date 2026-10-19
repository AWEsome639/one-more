/**
 * 斯特鲁普 —— 屏幕上是一个颜色词，却用另一种颜色印出来，只能答「墨色」
 * 胜负：12 题答对 ≥10 题通关
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 12;
const WORDS: string[] = [TG('红'), TG('黄'), TG('蓝'), TG('绿')];
const INKS: string[] = ['#EF4444', '#F59E0B', '#0EA5E9', '#10B981'];

@Component
export struct GStroopTest {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private word: number = 0;        // 字面写的颜色
  @State private ink: number = 1;         // 真正的墨色（永不等于字面色）
  @State private round: number = 1;
  @State private right: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); } }

  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.word = 0; this.ink = 1; this.round = 1; this.right = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextQuestion();
  }

  private nextQuestion(): void {
    const w: number = Math.floor(Math.random() * WORDS.length);
    let i: number = Math.floor(Math.random() * INKS.length);
    if (i === w) { i = (i + 1) % INKS.length; }
    this.word = w;
    this.ink = i;
    this.pick = -1;
    this.msg = TG('别读字，看颜色：它是什么颜色？');
  }

  private answer(k: number): void {
    if (this.over || this.pick >= 0) { return; }
    const ink: number = this.ink;
    const word: number = this.word;
    this.pick = k;
    if (k === ink) {
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ 墨色就是{0}', WORDS[ink]);
    } else {
      this.msg = TG2('❌ 墨色是{0}，"{1}"只是写在上面的字', WORDS[ink], WORDS[word]);
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 600);
  }

  private advance(): void {
    if (this.round >= this.diffTotal) {
      const win: boolean = this.right >= 10;
      this.over = true; this.won = win;
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'stroop_test', solved: win,
        score: this.right * 100 + (win ? 200 : 0),
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.nextQuestion();
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("题号 {0}/{1}", String(this.round), String(this.diffTotal))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.right)).fontSize(FontSize.sm).fontColor(Palette.teal)
        Text(TG('通关线 10')).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        Text(WORDS[this.word])
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(INKS[this.ink])
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }
      .width('100%').height(180).justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        this.opt(0)
        this.opt(1)
      }.width('100%')
      Row({ space: Space.sm }) {
        this.opt(2)
        this.opt(3)
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：12 题答对 ≥ 10 题；答的是墨色，不是字面写的颜色'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /** 选项写颜色名，底色就用它自己的颜色，方便一眼对齐 */
  @Builder
  opt(k: number) {
    Button(WORDS[k])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
      .fontSize(FontSize.xl).fontColor('#FFFFFF')
      .backgroundColor(this.pick === k ? Palette.primaryDeep : INKS[k])
      .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(62))
      .scale({ x: this.pick === k ? Motion.pressScale : 1, y: this.pick === k ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tap(); this.answer(k); })
  }
}
