/**
 * 密文破译 —— 单词被整体平移若干位（凯撒位移），靠已知映射还原明文
 * 胜负：8 关解出 ≥6 关通关，错 3 次即失败；每揭一条「密文→明文」映射扣 30 分
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 8; const PASS: number = 6; const LIVES: number = 3; const HINT_COST: number = 30;
interface Item { w: string; hint: string }
const POOL: Item[] = [
  { w: 'GARDEN', hint: '花园 🌷' }, { w: 'WINTER', hint: '冬天 ❄️' },
  { w: 'SILVER', hint: '银 🥈' }, { w: 'ORANGE', hint: '橙子 🍊' },
  { w: 'PLANET', hint: '行星 🪐' }, { w: 'MARKET', hint: '市场 🛒' },
  { w: 'ISLAND', hint: '岛屿 🏝️' }, { w: 'CASTLE', hint: '城堡 🏰' },
  { w: 'DRAGON', hint: '龙 🐉' }, { w: 'FOREST', hint: '森林 🌲' },
  { w: 'PENCIL', hint: '铅笔 ✏️' }, { w: 'ROCKET', hint: '火箭 🚀' }
];
/** 凯撒位移：每个字母在 A–Z 里向后挪 k 位 */
const AZ: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
function shiftWord(w: string, k: number): string {
  const out: string[] = [];
  for (let i = 0; i < w.length; i++) {
    out.push(AZ.charAt((AZ.indexOf(w.charAt(i)) + k) % 26));
  }
  return out.join('');
}
@Component
export struct GCryptogram {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State order: number[] = []; @State qi: number = 0; @State word: string = '';
  @State cipher: string = ''; @State k: number = 0; @State revealed: number = 0;
  @State input: string = ''; @State solved: number = 0; @State life: number = LIVES;
  @State score: number = 0; @State over: boolean = false; /** ★ 动效：进度数字弹动 */ @State bump: number = 1; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): Item { return POOL[this.order[this.qi]]; }
  /** 已揭晓的映射，如「D → A」 */
  private mapText(): string {
    if (this.revealed <= 0) { return TG('（还没有揭晓任何映射）'); }
    const parts: string[] = []; const n: number = Math.min(this.revealed, this.word.length);
    for (let i = 0; i < n; i++) { parts.push(this.cipher.charAt(i) + ' → ' + this.word.charAt(i)); }
    return parts.join('　');
  }
  private reset(): void {
    this.qi = 0; this.solved = 0; this.life = LIVES; this.score = 0; this.input = '';
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out; this.deal();
  }
  private deal(): void {
    this.word = this.cur().w; this.k = 1 + Math.floor(Math.random() * 25);
    this.cipher = shiftWord(this.word, this.k); this.revealed = 0; this.input = '';
    this.msg = TG('每个字母都被向后推了同样的位数 —— 破解它');
  }
  private hint(): void {
    if (this.over || this.revealed >= this.word.length) { return; }
    this.revealed = this.revealed + 1; this.score = this.score > HINT_COST ? this.score - HINT_COST : 0;
    this.msg = TG('🔎 又揭晓一条映射');
  }
  private submit(): void {
    if (this.over) { return; }
    const guess: string = this.input.trim().toUpperCase();
    this.input = '';
    if (guess.length === 0) { return; }
    if (guess === this.word) {
      this.solved = this.solved + 1; this.score = this.score + 120;
      this.msg = TG2('✅ 破译成功：{0}（位移 {1}）', this.word, this.k);
      this.nextQ();
    } else {
      this.life = this.life - 1;
      this.msg = TG2("❌ 「{0}」不是明文，还剩 {1} 条命", guess,Digits(String(this.life), this.langCode));
      if (this.life <= 0) { this.end(); }
    }
  }
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private nextQ(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.doBump();   // ★ 弹一下
    this.deal();
  }
  private end(): void {
    this.over = true; this.won = this.solved >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("破译 {0} / {1}", this.solved, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'cryptogram', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solved };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
// ★ 动效：进度一变就弹一下
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已解'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.solved + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        Text(TG('密文')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.cipher.split('').join(' ')).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(TG2('线索：{0}', this.cur().hint)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        Text(TG2('已知映射：{0}', this.mapText())).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(Palette.emerald)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入明文单词' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm })
          .onChange((v: string) => { this.input = v; }).onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.submit(); })
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.sm }) {
        Button(TG('揭一条映射（-30 分）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(!this.over).onClick(() => { Haptics.tap(); this.hint(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
