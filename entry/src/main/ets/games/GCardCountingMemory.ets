/**
 * 数牌记忆 —— 8 张牌快速闪过（其中一张出现两次），说完后点出重复的那张
 * 胜负：8 轮答对 6 轮以上 ⇒ 通关；进度：轮次 / 答对 / 用时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 8;
const NEED: number = 6;
const SUITS: string[] = ['♠️', '♥️', '♦️', '♣️'];
const RANKS: string[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5, 6, 7];

function cardFace(id: number): string { return RANKS[id % 13] + SUITS[Math.floor(id / 13)]; }
function cardRed(id: number): boolean { const s: number = Math.floor(id / 13); return s === 1 || s === 2; }

@Component
export struct GCardCountingMemory {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private stream: number[] = [];
  @State private idx: number = -1;
  @State private showing: boolean = false;
  @State private phase: number = 0;     // 0=准备 1=发牌中 2=作答
  @State private round: number = 1;
  @State private right: number = 0;
  @State private dupIdx: number = -1;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private clock: number = 0;
  private startAt: number = 0;
  private timer: number = -1;
  private tickTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.tickTo >= 0) { clearTimeout(this.tickTo); this.tickTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 1; this.right = 0; this.over = false; this.won = false; this.done = false; this.clock = 0;
    this.startAt = Date.now();
    this.newRound();
    this.timer = setInterval(() => { if (!this.over) { this.clock = this.clock + 1; } }, 1000);
  }
  /** 造 8 张牌：5 张不同 + 其中一张的重份 + 1 张新的 ⇒ 恰好一张出现两次 */
  private newRound(): void {
    const base: number[] = [];
    while (base.length < 5) {
      const c: number = Math.floor(Math.random() * 52);
      if (base.indexOf(c) < 0) { base.push(c); }
    }
    const dup: number = base[Math.floor(Math.random() * base.length)];
    let extra: number = Math.floor(Math.random() * 52);
    while (base.indexOf(extra) >= 0) { extra = Math.floor(Math.random() * 52); }
    const list: number[] = [base[0], base[1], dup, base[2], base[3], dup, base[4], extra];
    let seen: number = 0;
    let at: number = -1;
    for (let i = 0; i < list.length; i++) {
      if (list[i] === dup) {
        seen = seen + 1;
        if (seen === 2) { at = i; }
      }
    }
    this.stream = list;
    this.dupIdx = at;
    this.pick = -1; this.phase = 0; this.idx = -1;
    this.msg = TG2("第 {0} 轮：盯住闪过的牌，有一张会出现两次",Digits(String(this.round), this.langCode));
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.deal(0); }, 700);
  }
  /** 每张亮 380ms、灭 90ms */
  private deal(k: number): void {
    if (k >= this.stream.length) {
      this.idx = 99;
      this.showing = false;
      this.phase = 2;
      this.msg = TG('哪一张出现了两次？点它');
      return;
    }
    this.phase = 1;
    this.idx = k;
    this.showing = true;
    this.tickTo = setTimeout(() => {
      this.tickTo = -1;
      this.showing = false;
      this.tickTo = setTimeout(() => { this.tickTo = -1; this.deal(k + 1); }, 90);
    }, 380);
  }
  private answer(i: number): void {
    if (this.phase !== 2 || this.pick >= 0) { return; }
    this.pick = i;
    if (i === this.dupIdx) {
      this.right = this.right + 1;
      this.msg = TG2('✅ 就是 {0}', cardFace(this.stream[i]));
    } else {
      this.msg = TG2('❌ 重复的是 {0}', cardFace(this.stream[this.dupIdx]));
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.over = true;
        this.won = this.right >= NEED;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.newRound();
    }, 800);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'card_counting_memory', solved: solved, score: this.right * 130,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private faceInk(id: number): string { return cardRed(id) ? '#E11D48' : '#0F172A'; }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.clock + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        if (this.showing && this.idx >= 0 && this.idx < this.stream.length) {
          Text(cardFace(this.stream[this.idx])).fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
            .fontColor(this.faceInk(this.stream[this.idx]))
        } else {
          Text(this.phase === 2 ? '🂠' : '🎴').fontSize(FontSize.hero)
        }
      }.width('100%').height(110).backgroundColor(Palette.surface).borderRadius(Radius.md)
        .border({ width: 3, color: Palette.rose }).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Grid() {
        ForEach(SLOTS, (i: number) => { GridItem() {
        Text(cardFace(this.stream[(i)])).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (i) ? '#FFFFFF' : this.faceInk(this.stream[(i)]))
        .textAlign(TextAlign.Center).width('100%').height(Cell.of(48))
        .backgroundColor(this.pick === (i) ? Palette.primaryDeep : '#FFFFFF')
        .borderRadius(Radius.sm).border({ width: 2, color: Palette.rose })
        .scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.answer((i)); })

        } }, (i: number) => 'cc' + i)
      }.columnsTemplate('1fr 1fr 1fr 1fr').rowsGap(Space.sm).columnsGap(Space.sm)
        .width('100%').height(150).opacity(this.phase === 2 ? 1 : 0.35)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('提示：下面 8 张就是刚才闪过的牌，只有一张出现两次')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}