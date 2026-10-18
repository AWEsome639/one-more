/**
 * 拓扑 —— 不看形状只看"洞"：两图洞数相同就拓扑等价（可互相拉伸变过去）
 * 胜负：8 题答对 ≥ 6 ⇒ 通关　｜　进度：题号 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface Sh { g: string; h: number; }

const ROUNDS: number = 8; const PASS: number = 6; const FEED_MS: number = 950;

const SHAPES: Sh[] = [
  { g: '●', h: 0 }, { g: '▲', h: 0 }, { g: '★', h: 0 }, { g: '✚', h: 0 }, { g: '■', h: 0 }, { g: '➖', h: 0 },
  { g: '○', h: 1 }, { g: '△', h: 1 }, { g: '🍩', h: 1 }, { g: '0', h: 1 }, { g: 'A', h: 1 }, { g: 'P', h: 1 }, { g: '⭕', h: 1 },
  { g: '8', h: 2 }, { g: 'B', h: 2 }
];

@Component
export struct GTopology {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State li: number = 0; @State ri: number = 1; @State same: boolean = false; @State revealed: boolean = false;
  @State round: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll(); this.round = 1; this.hits = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  /** 一半概率出"洞数相同"的题，一半出"洞数不同"的题 */
  private newRound(): void {
    const wantSame: boolean = Math.random() < 0.5;
    const i: number = Math.floor(Math.random() * SHAPES.length);
    let j: number = Math.floor(Math.random() * SHAPES.length);
    let guard: number = 0;
    while (guard < 80 && (j === i || (SHAPES[j].h === SHAPES[i].h) !== wantSame)) {
      j = Math.floor(Math.random() * SHAPES.length); guard = guard + 1;
    }
    this.li = i; this.ri = j; this.same = SHAPES[i].h === SHAPES[j].h; this.revealed = false;
    this.msg = TG2("第 {0} / {1} 题：它俩拓扑等价吗？", this.round, this.diffTotal);
  }

  private answer(guessSame: boolean): void {
    if (this.over || this.revealed) { return; }
    this.revealed = true;
    const lh: number = SHAPES[this.li].h; const rh: number = SHAPES[this.ri].h;
    const pair: string = SHAPES[this.li].g + TG2(' {0} 洞 ｜ {1} {2} 洞', lh, SHAPES[this.ri].g, rh);
    if (guessSame === this.same) {
      this.hits = this.hits + 1; this.score = this.score + 12; this.msg = '✅ ' + pair;
    } else {
      this.msg = '❌ ' + pair + ' ⇒ ' + (this.same ? '等价' : TG('不等价'));
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.hits, this.diffTotal);
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.newRound();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'topology', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text(SHAPES[(this.li)].g).fontSize(FontSize.hero).fontColor(this.theme.ink)
        Text(this.revealed ? SHAPES[(this.li)].h + ' 个洞' : '?').fontSize(FontSize.sm)
        .fontColor(this.revealed ? Palette.orange : this.theme.inkFaint)
        }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text('≟').accessibilityText(TG('比较')).fontSize(FontSize.xxl).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
        Column({ space: Space.xs }) {
        Text(SHAPES[(this.ri)].g).fontSize(FontSize.hero).fontColor(this.theme.ink)
        Text(this.revealed ? SHAPES[(this.ri)].h + ' 个洞' : '?').fontSize(FontSize.sm)
        .fontColor(this.revealed ? Palette.orange : this.theme.inkFaint)
        }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').height(170)
      Row({ space: Space.sm }) {
        Button((TG('等价（洞数相同）')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor((true) ? Palette.teal : Palette.rose)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((true)); })
        Button((TG('不等价')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor((false) ? Palette.teal : Palette.rose)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((false)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('判据是洞的个数：能拉伸、能压扁，洞既不会变多也不会变少')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
