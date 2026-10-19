/**
 * 猜球 —— 🎲 看清球在哪个碗下，洗牌后点出它的位置（id: shell_game）
 * 胜负：连中 5 关 ⇒ 通关（每关多洗 2 次）；进度：猜中/5 · 洗牌次数 · 阶段
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const LEVELS: number = 5;
const BASE_SWAPS: number = 4;
const SHOW_MS: number = 1400;
const SWAP_MS: number = 360;
@Component
export struct GShellGame {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State private order: number[] = [0, 1, 2];
  @State private ballCup: number = 0;
  @State private level: number = 0;
  @State private wins: number = 0;
  @State private swaps: number = BASE_SWAPS;
  @State private phase: string = 'show';
  @State private hotA: number = -1;
  @State private hotB: number = -1;
  @State private reveal: boolean = false;
  @State private pickSlot: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private toId: number = -1;
  private ivId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
    if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.level = 0; this.wins = 0; this.hotA = -1; this.hotB = -1; this.pickSlot = -1;
    this.reveal = false; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }
  private newRound(): void {
    this.order = [0, 1, 2];
    this.ballCup = Math.floor(Math.random() * 3);
    this.swaps = BASE_SWAPS + this.level * 2;
    this.phase = 'show'; this.reveal = true; this.hotA = -1; this.hotB = -1; this.pickSlot = -1;
    this.msg = TG2("看好球 → 第 {0} 关，洗 {1} 次", String(this.level + 1),Digits(String(this.swaps), this.langCode));
    this.toId = setTimeout(() => { this.toId = -1; this.startShuffle(); }, SHOW_MS);
  }
  private startShuffle(): void {
    this.reveal = false; this.phase = 'shuffle'; this.msg = TG('洗牌中…');
    let left: number = this.swaps;
    this.ivId = setInterval(() => {
      const i: number = Math.floor(Math.random() * 3);
      const j: number = (i + 1) % 3;
      const nx: number[] = this.order.slice();
      const t: number = nx[i];
      nx[i] = nx[j];
      nx[j] = t;
      this.order = nx;
      this.hotA = i; this.hotB = j;
      left = left - 1;
      if (left <= 0) {
        if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
        this.hotA = -1; this.hotB = -1; this.phase = 'pick'; this.msg = TG('球在哪个碗下？');
      }
    }, SWAP_MS);
  }
  private pick(slot: number): void {
    if (this.phase !== 'pick' || this.over) { return; }
    this.phase = 'done'; this.pickSlot = slot; this.reveal = true;
    const cup: number = this.order[slot];
    if (cup === this.ballCup) {
      this.wins = this.wins + 1;
      this.msg = TG('✅ 命中！');
      if (this.wins >= this.diffTotal) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 通关 · 连中 {0} 关",Digits(String(this.diffTotal), this.langCode));
        this.end();
        return;
      }
      this.level = this.level + 1;
      this.toId = setTimeout(() => { this.toId = -1; this.newRound(); }, 850);
      return;
    }
    this.over = true; this.won = false; this.msg = TG('❌ 球在另一个碗下');
    this.end();
  }
  private end(): void {
    if (this.done) { return; }
    this.clearAll();
    this.done = true;
    const r: GameResult = {
      gameId: 'shell_game', solved: this.won, score: this.wins * 100 + this.level * 20,
      durationMs: Date.now() - this.startAt, levelReached: this.wins
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('猜中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.wins) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('洗牌'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.swaps) + TG(' 次'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('状态'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'shuffle' ? '洗牌' : (this.phase === 'pick' ? '快选' : '看球'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        ForEach([0, 1, 2], (slot: number) => {
          Column({ space: Space.xs }) {
          Text(this.reveal && this.order[(slot)] === this.ballCup ? '⚪' : '').fontSize(FontSize.xl).height(Cell.of(30))
          Text('🥣').fontSize(FontSize.hero)
            .accessibilityLevel('no')
          }.layoutWeight(1).height(160).justifyContent(FlexAlign.End).padding(Space.sm)
          .borderRadius(Radius.lg).shadow(Shadow.card)
          .backgroundColor(this.pickSlot === (slot) ? Palette.primaryDeep : (this.hotA === (slot) || this.hotB === (slot) ? Palette.amber : this.theme.surface))
          .scale({ x: this.pickSlot === (slot) ? Motion.pressScale : 1, y: this.pickSlot === (slot) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.pick((slot)); })
        }, (slot: number) => 's' + slot)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：连中 5 关通关；每过一关多洗 2 次'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
