/**
 * 数字大小 —— 字号故意捣乱：只看数字本身，比 5 大还是小
 * 胜负：12 题答对 ≥10 题通关
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 12;
const REF: number = 5;

@Component
export struct GStroopNumberSize {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private val: number = 0;
  @State private loud: boolean = false;   // 字形是否被放大（与数值无关的干扰）
  @State private round: number = 1;
  @State private right: number = 0;
  @State private pick: number = -1;       // -1 未答 0 大 1 小
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
    this.val = 0; this.loud = false; this.round = 1; this.right = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextQuestion();
  }

  /** 大字配小数字、小字配大数字 —— 让"看着大"和"其实大"互相打架 */
  private nextQuestion(): void {
    const big: boolean = Math.random() < 0.5;
    const v: number = big ? 6 + Math.floor(Math.random() * 4) : 1 + Math.floor(Math.random() * 4);
    this.val = v;
    this.loud = v > REF;
    this.pick = -1;
    this.msg = TG2('它比 {0} 大还是小？（别被字号骗）', String(REF));
  }

  private answer(saidBig: boolean): void {
    if (this.over || this.pick >= 0 || this.val === 0) { return; }
    const v: number = this.val;
    const truth: boolean = v > REF;
    this.pick = saidBig ? 0 : 1;
    if (saidBig === truth) {
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ ' + String(v) + ' 确实比 ' + String(REF) + (truth ? ' 大' : ' 小');
    } else {
      this.msg = TG2('❌ {0} 比 {1}{2}，字形在骗你', String(v), String(REF), truth ? TG(' 大') : TG(' 小'));
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 600);
  }

  private advance(): void {
    if (this.round >= this.diffTotal) {
      const win: boolean = this.right >= 10;
      this.over = true; this.won = win;
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'stroop_number_size', solved: win,
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
        Text(TG('答对 ') + String(this.right)).fontSize(FontSize.sm).fontColor(Palette.amber)
        Text(TG2('标准 {0}', String(REF))).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        Text(this.val === 0 ? '👀' : String(this.val))
          .fontSize(this.val === 0 ? FontSize.xxl : (this.loud ? FontSize.xxs : FontSize.hero))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.loud ? Palette.amber : Palette.sky)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }
      .width('100%').height(180).justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.md }) {
        Button(TG('比 5 大'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 0 ? Palette.primaryDeep : Palette.amber)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(72))
          .scale({ x: this.pick === 0 ? Motion.pressScale : 1, y: this.pick === 0 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('比 5 小'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 1 ? Palette.primaryDeep : Palette.sky)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(72))
          .scale({ x: this.pick === 1 ? Motion.pressScale : 1, y: this.pick === 1 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：12 题答对 ≥ 10 题'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
