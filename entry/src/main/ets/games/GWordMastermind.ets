/**
 * 猜词大师 —— 猜隐藏的 5 字母单词，逐格给出「位置对 / 字母在 / 都没有」
 * 胜负：7 次内猜中通关｜次数用完未猜中失败｜进度：第几次 / 剩余机会 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const LEN: number = 5; const TRIES: number = 7; const KEYS: number = 28;
const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const BANK: string[] = [
  'APPLE', 'BEACH', 'BRAIN', 'BREAD', 'BRICK', 'CHAIR', 'CHESS', 'CLOUD', 'DANCE', 'DREAM',
  'DRINK', 'EARTH', 'FIELD', 'FLAME', 'FRUIT', 'GHOST', 'GRAPE', 'GREEN', 'HAPPY', 'HEART',
  'HONEY', 'HOUSE', 'JUICE', 'KNIFE', 'LEMON', 'LIGHT', 'MONEY', 'MOUSE', 'MUSIC', 'NIGHT',
  'OCEAN', 'PAPER', 'PEACH', 'PIANO', 'PLANT', 'PLATE', 'QUEEN', 'RIVER', 'ROBOT', 'SHEEP',
  'SHIRT', 'SMILE', 'SNAKE', 'SPACE', 'SPOON', 'STONE', 'STORM', 'SUGAR', 'TABLE', 'TIGER',
  'TOAST', 'TRAIN', 'WATER', 'WHALE', 'WHEEL', 'WORLD', 'YOUTH', 'ZEBRA'
];
@Component
export struct GWordMastermind {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 LEN=5
  @State private diffTotal: number = GameDiff.sizeNow(5);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State answer: string = ''; @State rows: string[] = []; @State marks: string[] = [];
  @State typed: string = ''; @State score: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  private reset(): void {
    this.answer = BANK[Math.floor(Math.random() * BANK.length)];
    this.rows = []; this.marks = []; this.typed = ''; this.score = 0;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.msg = TG2('凑满 {0} 个字母后按 ⏎ 提交', this.diffTotal);
  }
  /** 逐格标记：2 = 位置对，1 = 字母在但位置错，0 = 词里没有 */
  private mark(g: string): string {
    const res: string[] = new Array<string>(this.diffTotal).fill('0');
    const left: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      if (g.charAt(i) === this.answer.charAt(i)) { res[i] = '2'; }
      else { left.push(this.answer.charAt(i)); }
    }
    for (let i = 0; i < this.diffTotal; i++) {
      if (res[i] === '2') { continue; }
      const k: number = left.indexOf(g.charAt(i));
      if (k >= 0) { res[i] = '1'; left.splice(k, 1); }
    }
    return res.join('');
  }
  private press(k: number): void {
    if (this.over) { return; }
    if (k < 26) {
      if (this.typed.length < this.diffTotal) { this.typed = this.typed + LETTERS.charAt(k); }
      return;
    }
    if (k === 26) {
      this.typed = this.typed.length > 0 ? this.typed.substring(0, this.typed.length - 1) : '';
      return;
    }
    this.submit();
  }
  private submit(): void {
    if (this.typed.length < this.diffTotal) { this.msg = TG2('还差 {0} 个字母', this.diffTotal - this.typed.length); return; }
    const g: string = this.typed;
    this.rows = this.rows.concat([g]);
    this.marks = this.marks.concat([this.mark(g)]);
    this.typed = '';
    if (g === this.answer) {
      this.over = true; this.won = true; this.score = (TRIES - this.rows.length + 1) * 100;
      this.msg = TG2('🎉 猜中了：{0}', this.answer); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    if (this.rows.length >= TRIES) {
      this.over = true; this.score = 0; this.msg = TG2('❌ 机会用完，答案是 {0}', this.answer);
      this.finish(false); return;
    }
    this.msg = TG2("第 {0} 次反馈：🟩 位置对｜🟨 字母在｜⬜ 没有", this.rows.length);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true;
    const r: GameResult = { gameId: 'word_mastermind', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rows.length };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private letterAt(r: number, c: number): string {
    if (r < this.rows.length) { return this.rows[r].charAt(c); }
    if (r === this.rows.length && c < this.typed.length) { return this.typed.charAt(c); }
    return '';
  }
  private toneAt(r: number, c: number): string {
    if (r >= this.marks.length) { return this.theme.surface; }
    const k: string = this.marks[r].charAt(c);
    if (k === '2') { return Palette.emerald; }
    if (k === '1') { return Palette.amber; }
    return this.theme.isDark ? '#2A2A2A' : '#D8DDE6';
  }
  private keyLabel(k: number): string {
    if (k < 26) { return LETTERS.charAt(k); }
    return k === 26 ? '⌫' : '⏎';
  }
  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('第几次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rows.length + ' / ' + TRIES)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(TRIES - this.rows.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5, 6], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => { Text(this.letterAt((r), (c))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(34)).backgroundColor(this.toneAt((r), (c))).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
              if (r * 7 + c < KEYS) {
                Text(this.keyLabel((r * 7 + c))).fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(36)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).shadow(Shadow.card).onClick(() => { Haptics.tick(); this.press((r * 7 + c)); })
              }
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Button(TG('删一个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.press(26); })
      }.width('100%')
      Text(TG('提示：🟩 字母与位置都对｜🟨 字母在词里但位置错｜⬜ 词里没有')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
