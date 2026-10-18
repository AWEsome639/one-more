/** 句子重组 —— 把打乱的 6 个单词按正确语序点回去｜胜负：5 句答对 ≥4 通关，错 3 次失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 5; const PASS: number = 4; const LIVES: number = 3; const GAP_MS: number = 900;

/** 全部是 6 词句，正好铺成 3×2 的格子 */
const SENTS: string[] = [
  'THE CAT SLEEPS ON THE MAT', 'SHE READS A BOOK EVERY NIGHT',
  'THE OLD MAN DREAMS ABOUT LIONS', 'RAIN FALLS SOFTLY ON THE ROOF',
  'HE KEEPS A SMALL BLUE NOTEBOOK', 'TIME FLIES WHEN WE ARE READING',
  'THE SEA RETURNS WHAT IT TAKES', 'A SMALL BOAT CROSSES THE BAY',
  'WE WALK TO SCHOOL EVERY MORNING', 'THE LAMP GLOWS IN THE DARK',
  'HIS NOTEBOOK HOLDS MANY SECRET WORDS', 'SHE SINGS A QUIET SONG TONIGHT'
];

function shufStr(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSentenceUnscramble {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State plan: string[] = []; @State tiles: string[] = []; @State pickedIdx: number[] = [];
  @State qi: number = 0; @State right: number = 0; @State lives: number = LIVES;
  @State score: number = 0; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private reset(): void {
    this.stop();
    this.plan = shufStr(SENTS).slice(0, this.diffTotal);
    this.qi = 0; this.right = 0; this.lives = LIVES; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now(); this.next();
  }

  private next(): void {
    const sent: string = this.plan[this.qi];
    const words: string[] = sent.split(' ');
    let mixed: string[] = shufStr(words);
    if (mixed.join(' ') === sent) { mixed = mixed.slice(1).concat(mixed.slice(0, 1)); }
    this.tiles = mixed; this.pickedIdx = [];
    this.msg = TG2('按正确语序点词 —— 第 {0} 句', (this.qi + 1));
  }

  private usedAt(i: number): boolean { return this.pickedIdx.indexOf(i) >= 0; }
  private placed(): string {
    const out: string[] = [];
    for (let i = 0; i < this.pickedIdx.length; i++) { out.push(this.tiles[this.pickedIdx[i]]); }
    return out.join(' ');
  }
  private pick(i: number): void {
    if (this.over || this.usedAt(i) || this.msg.indexOf('❌') === 0) { return; }
    const sel: number[] = this.pickedIdx.slice();
    sel.push(i); this.pickedIdx = sel;
    if (sel.length < this.tiles.length) { return; }
    if (this.placed() === this.plan[this.qi]) {
      this.right = this.right + 1; this.score = this.score + 120; this.msg = TG('✅ 语序正确！');
    } else {
      this.lives = this.lives - 1; this.msg = TG2('❌ 正确语序：{0}', this.plan[this.qi]);
    }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 机会用尽 —— 答对 {0} / {1}', this.right, this.diffTotal);
      this.finish(false); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'sentence_unscramble', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('句号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 已拼')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.pickedIdx.length === 0 ? '_ _ _ _ _ _' : this.placed())
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.pickedIdx.length === 0 ? this.theme.inkFaint : this.theme.ink)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Text(this.tiles.length > (0) ? this.tiles[(0)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((0)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((0)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((0)); })
        Text(this.tiles.length > (1) ? this.tiles[(1)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((1)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((1)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((1)); })
        Text(this.tiles.length > (2) ? this.tiles[(2)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((2)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((2)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((2)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(this.tiles.length > (3) ? this.tiles[(3)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((3)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((3)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((3)); })
        Text(this.tiles.length > (4) ? this.tiles[(4)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((4)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((4)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((4)); })
        Text(this.tiles.length > (5) ? this.tiles[(5)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).maxLines(1).textAlign(TextAlign.Center)
        .fontColor(this.usedAt((5)) ? this.theme.inkFaint : '#FFFFFF')
        .backgroundColor(this.usedAt((5)) ? this.theme.lineSoft : Palette.emerald)
        .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(44))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { this.pick((5)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG2("{0} 句，答对 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
