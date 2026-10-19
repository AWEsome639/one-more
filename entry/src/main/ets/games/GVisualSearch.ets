/**
 * 视觉搜索 —— 满屏干扰项里，一眼认出与众不同的那一个
 * 胜负：8 局找出 ≥6 个 ⇒ 通关｜进度：局数 / 已找出 / 得分（每局 8 秒，点错罚 1.2 秒）
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6; const CELLS: number = N * N; const IDX: number[] = [0, 1, 2, 3, 4, 5];
const ROUNDS: number = 8; const PASS: number = 6;
const LIMIT_MS: number = 8000; const TICK_MS: number = 100;
const PENALTY_MS: number = 1200; const GAP_MS: number = 550;
/** 形近 emoji 对：[目标, 干扰] */
const PAIRS: string[][] = [
  ['🍎', '🍒'], ['🐶', '🐺'], ['⭐', '🌟'], ['🔵', '🟣'],
  ['🍋', '🍐'], ['🦋', '🐝'], ['🐸', '🐢'], ['🍄', '🌰']
];

@Component
export struct GVisualSearch {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State cells: string[] = []; @State target: string = ''; @State targetIdx: number = -1;
  @State round: number = 1; @State found: number = 0; @State score: number = 0;
  @State leftMs: number = LIMIT_MS; @State msg: string = ''; @State badIdx: number = -1;
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private roundAt: number = 0;
  private timer: number = -1; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop();
    this.round = 1; this.found = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.newRound();
  }
  private newRound(): void {
    const pair: string[] = PAIRS[Math.floor(Math.random() * PAIRS.length)];
    const arr: string[] = new Array<string>(CELLS).fill(pair[1]);
    const at: number = Math.floor(Math.random() * CELLS);
    arr[at] = pair[0];
    this.cells = arr; this.target = pair[0]; this.targetIdx = at; this.badIdx = -1;
    this.leftMs = LIMIT_MS; this.roundAt = Date.now();
    this.msg = TG2("第 {0} 局：找出 {1}",Digits(String(this.round), this.langCode), this.target);
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= LIMIT_MS ? 0 : LIMIT_MS - gap;
    if (gap >= LIMIT_MS) { this.endRound(false); }
  }
  private pick(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    if (i === this.targetIdx) {
      const gain: number = 30 + Math.floor(this.leftMs / 100);
      this.found = this.found + 1; this.score = this.score + gain;
      this.msg = TG2('✅ 找到了！+{0}', gain); this.endRound(true);
      return;
    }
    this.badIdx = i; this.roundAt = this.roundAt - PENALTY_MS; this.msg = TG('❌ 不是它，罚 1.2 秒');
  }
  private endRound(ok: boolean): void {
    this.stop();
    if (!ok) { this.msg = TG('⌛ 超时了'); }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.found >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("找出 {0} / {1}", this.found, this.diffTotal);
      this.finish(this.won);
      return;
    }
    this.round = this.round + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.newRound(); }, GAP_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'visual_search', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text(('局')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('找出'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.found), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(this.target).fontSize(FontSize.xxl)
        Text(TG2('在下面 {0} 个里找出它', CELLS)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Row() {
        Row().height(Space.xs).width(String(Math.round((this.leftMs / LIMIT_MS) * 100)) + '%')
          .backgroundColor(this.leftMs > 2500 ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.full).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').height(Space.xs).backgroundColor(this.theme.line).borderRadius(Radius.full)
      Column({ space: Space.xs }) {
        ForEach(IDX, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(IDX, (c: number) => {
              Text(this.cells[(r * N + c)])
              .fontSize(FontSize.lg).textAlign(TextAlign.Center).layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.badIdx === (r * N + c) ? Palette.rose : this.theme.surface)
              .borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.pick((r * N + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
