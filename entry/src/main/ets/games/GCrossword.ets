/**
 * 填字游戏 —— 5×5 迷你填字：按线索从词库里挑词，填满五行
 * 秘密：这五个词横竖皆成词（词方阵 HEART / EMBER / ABUSE / RESIN / TREND）
 * 胜负：五行全填对通关；挑错 3 次即失败　进度：已填行数 / 失误 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const SIZE: number = 5; const MAX_MISS: number = 3;
const WORDS: string[] = ['HEART', 'EMBER', 'ABUSE', 'RESIN', 'TREND'];
const CLUES: string[] = [
  '1 行：胸腔里日夜跳动的器官（5 字母）',
  '2 行：炭火里将熄未熄的红光（5 字母）',
  '3 行：错误地、过度地使用权力或药物（5 字母）',
  '4 行：松柏伤口渗出的黏稠物（5 字母）',
  '5 行：风向；潮流所向（5 字母）'
];
const EXTRA: string[] = ['STONE', 'FLAME'];
@Component
export struct GCrossword {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 SIZE=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(5);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State rows: string[] = []; @State bank: string[] = []; @State used: string[] = [];
  @State cur: number = 0; @State miss: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  private isUsed(i: number): boolean {
    return i < this.bank.length && this.used.indexOf(this.bank[i]) >= 0;
  }
  private reset(): void {
    this.rows = new Array<string>(this.diffTotal).fill(''); this.used = [];
    this.cur = 0; this.miss = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('从词库里挑一个词，填进这一行'); this.startAt = Date.now();
    const arr: string[] = WORDS.concat(EXTRA);
    for (let i = arr.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    this.bank = arr;
  }
  private place(i: number): void {
    if (this.over || i >= this.bank.length || this.isUsed(i)) { return; }
    const w: string = this.bank[i];
    if (w !== WORDS[this.cur]) {
      this.miss = this.miss + 1;
      this.msg = TG2('❌ 「{0}」对不上线索，失误 {1} / {2}', w, this.miss, MAX_MISS);
      if (this.miss >= MAX_MISS) { this.end(false); }
      return;
    }
    const next: string[] = this.rows.slice();
    next[this.cur] = w; this.rows = next;
    this.used = this.used.concat([w]);
    this.score = this.score + 100;
    this.cur = this.cur + 1;
    if (this.cur >= this.diffTotal) { this.end(true); return; }
    this.msg = TG2("✅ 第 {0} 行填好了，接着下一行", this.cur);
  }
  private end(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 通关！横竖同词：HEART · EMBER · ABUSE · RESIN · TREND'
      : TG2('💤 失误 {0} 次，这一局结束', MAX_MISS);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'crossword', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cur };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.cur + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.miss + '/' + MAX_MISS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.rows[(r)].length > (c) ? this.rows[(r)].charAt((c)) : '')
              .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
              .fontColor((r) === this.cur && !this.over ? '#FFFFFF' : this.theme.ink)
              }
              .layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
              .backgroundColor((r) === this.cur && !this.over ? Palette.amber : this.theme.surface)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      Text(this.over ? this.msg : CLUES[this.cur]).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.ink)
      Text(this.msg).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.xs }) {
        Text((0) < this.bank.length ? this.bank[(0)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((0)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((0)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((0)); })
        Text((1) < this.bank.length ? this.bank[(1)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((1)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((1)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((1)); })
        Text((2) < this.bank.length ? this.bank[(2)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((2)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((2)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((2)); })
        Text((3) < this.bank.length ? this.bank[(3)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((3)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((3)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((3)); })
      }
      .width('100%')
      Row({ space: Space.xs }) {
        Text((4) < this.bank.length ? this.bank[(4)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((4)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((4)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((4)); })
        Text((5) < this.bank.length ? this.bank[(5)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((5)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((5)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((5)); })
        Text((6) < this.bank.length ? this.bank[(6)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((6)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((6)) ? this.theme.surfaceAlt : Palette.primary)
        .onClick(() => { this.place((6)); })
      }
      .width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
