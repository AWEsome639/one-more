/**
 * 西蒙指令 📐（id: simon_command）
 * 只有「西蒙说」开头的指令才照做；没这句话就必须按「不做动作 ✋」。每题限时 2.2 秒。
 * 胜负：答对 10 题 ⇒ 通关；失误 3 次 ⇒ 失败。进度：答对 / 失误 / 剩余时间。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const PADS: number[] = [0, 1, 2, 3];
const PAD_COLORS: string[] = [Palette.rose, Palette.sky, Palette.emerald, Palette.amber];
const PAD_NAMES: string[] = [TG('红'), TG('蓝'), TG('绿'), TG('黄')];
const PAD_ICONS: string[] = ['🔴', '🔵', '🟢', '🟡'];
const WIN: number = 10; const MAX_ERR: number = 3; const LIMIT_MS: number = 2200;
const TICK: number = 100; const WAIT_MS: number = 700;

@Component
export struct GSimonCommand {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 WIN=10，按难度换算
  @State private diffTotal: number = GameDiff.livesNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State hasWord: boolean = false; @State color: number = 0; @State correct: number = 0;
  @State errors: number = 0; @State left: number = LIMIT_MS; @State phase: string = 'play';
  @State over: boolean = false; @State won: boolean = false; @State note: string = '';
  private startAt: number = 0; private done: boolean = false;
  private tickTimer: number = -1; private nextTimer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(10);
     this.reset(); }
  aboutToDisappear(): void { this.stopAll(); }
  private stopAll(): void {
    if (this.tickTimer >= 0) { clearInterval(this.tickTimer); this.tickTimer = -1; }
    if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; }
  }
  private reset(): void {
    this.stopAll(); this.correct = 0; this.errors = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now();
    this.note = TG(TG('「西蒙说」才照做，否则按「不做动作」'));
    this.newRound();
  }
  private newRound(): void {
    this.hasWord = Math.random() < 0.55;
    this.color = Math.floor(Math.random() * PADS.length);
    this.left = LIMIT_MS; this.phase = 'play';
    if (this.tickTimer >= 0) { clearInterval(this.tickTimer); }
    this.tickTimer = setInterval(() => { this.tick(); }, TICK);
  }
  private tick(): void {
    if (this.phase !== 'play' || this.over) { return; }
    this.left = this.left - TICK;
    if (this.left <= 0) { this.left = 0; this.judge(-1); }   // 超时 = 没做动作
  }
  /** act: 0~3 点了色块，-1 表示「不做动作」 */
  private judge(act: number): void {
    if (this.phase !== 'play' || this.over) { return; }
    if (this.tickTimer >= 0) { clearInterval(this.tickTimer); this.tickTimer = -1; }
    const want: number = this.hasWord ? this.color : -1;
    if (act === want) {
      this.correct++;
      this.note = this.hasWord ? '✅ 听话，做对了' : '✅ 忍住没动，正确';
    } else {
      this.errors++;
      this.note = this.hasWord ? '❌ 这句要照做的' : '❌ 没有「西蒙说」，不该动';
    }
    this.phase = 'pause';
    if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); }
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.correct >= this.diffTotal) { this.finish(true); return; }
      if (this.errors >= MAX_ERR) { this.finish(false); return; }
      this.newRound();
    }, WAIT_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.phase = 'over'; this.stopAll();
    const raw: number = this.correct * 12 - this.errors * 8;
    const res: GameResult = { gameId: 'simon_command', solved: solved, score: raw > 0 ? raw : 0, durationMs: Date.now() - this.startAt, levelReached: this.correct };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  private bar(): string {
    const ms: number = this.left > 0 ? this.left : 0;
    return Math.round(ms * 100 / LIMIT_MS) + '%';
  }

  build() {
    Column({ space: Space.md }) {
      Text(TG2("答对 {0}/{1}", this.correct, this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(8).backgroundColor(this.theme.line).borderRadius(Radius.full)
        Row().width(this.bar()).height(8).borderRadius(Radius.full)
          .backgroundColor(this.hasWord ? Palette.emerald : Palette.amber)
      }.width('100%')
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          if (this.hasWord) {
            Text(TG('西蒙说')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
          }
          Text(TG2('点「{0}」', PAD_NAMES[this.color])).fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        this.pad(0)
        this.pad(1)
      }.width('100%')
      Row({ space: Space.sm }) {
        this.pad(2)
        this.pad(3)
      }.width('100%')
      Button(TG('不做动作 ✋'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).width('100%').height(Cell.of(48))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.judge(-1); })
      Text(this.note).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  pad(i: number) {
    Column({ space: 2 }) {
      Text(PAD_ICONS[i]).fontSize(FontSize.xxl)
      Text(PAD_NAMES[i]).fontSize(FontSize.xs).fontColor('#FFFFFF')
    }.layoutWeight(1).aspectRatio(1.4).justifyContent(FlexAlign.Center).backgroundColor(PAD_COLORS[i])
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.phase === 'play' ? 1 : Motion.pressScale, y: this.phase === 'play' ? 1 : Motion.pressScale })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { this.judge(i); })
  }
}
