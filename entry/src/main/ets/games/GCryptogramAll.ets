/**
 * 密文进阶 🔐 —— 凯撒移位密文，给出部分密钥（key），推出原词
 * 每个字母被移位 +k 加密；密钥只露出几位，其余靠四个候选词反推
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const TOTAL: number = 8;
const PASS: number = 6;
const NEXT_MS: number = 780;
const AZ: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const WORDS: string[] = [
  'CIPHER', 'PUZZLE', 'SHADOW', 'GALAXY', 'MARBLE',
  'FOSSIL', 'ORCHID', 'VELVET', 'BEACON', 'THRIVE'
];
const REVEAL: string[] = ['012', '123', '234', '045', '135', '246', '056', '147'];

@Component
export struct GCryptogramAll {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private word: string = '';
  @State private cipher: string = '';
  @State private shown: string = '';
  @State private opts: string[] = [];
  @State private qi: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-14 动效：进度数字弹动 */
  @State private bump: number = 1;
  @State private over: boolean = false;
  @State private hint: string = '';
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  private reset(): void {
    this.right = 0; this.score = 0; this.qi = 0; this.over = false; this.hint = '';
    this.load(0); this.startAt = Date.now();
  }

  /** 生成本题：原词 + 随机移位 + 只露几位密钥 */
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private load(i: number): void {
    this.doBump();   // ★ 换题弹一下
    const word: string = WORDS[i % WORDS.length];
    const shift: number = 3 + (i % 7);
    let cipher: string = '';
    for (let k = 0; k < word.length; k++) {
      const p: number = AZ.indexOf(word.charAt(k));
      cipher += p < 0 ? word.charAt(k) : AZ.charAt((p + shift) % 26);
    }
    const reveal: string = REVEAL[i % REVEAL.length];
    let shown: string = '';
    for (let k = 0; k < reveal.length; k++) {
      const at: number = Number.parseInt(reveal.charAt(k));
      if (at < word.length && shown.indexOf(cipher.charAt(at)) < 0) {
        shown += (shown.length > 0 ? '  ' : '') + cipher.charAt(at) + '→' + word.charAt(at);
      }
    }
    const pool: string[] = ['BAFFLE', 'MEADOW', 'SPIRAL', 'THRONE', 'ZEPHYR', 'QUARTZ'];
    const opts: string[] = [word];
    for (let k = 0; k < pool.length && opts.length < 4; k++) {
      if (pool[k] !== word) { opts.push(pool[k]); }
    }
    for (let k = opts.length - 1; k > 0; k--) {   // 洗牌，正确项不固定在最后一格
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: string = opts[k]; opts[k] = opts[j]; opts[j] = t;
    }
    this.word = word; this.cipher = cipher; this.shown = shown; this.opts = opts;
    this.qi = i; this.locked = false; this.hint = '';
  }

  private pick(v: string): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    const plain: string = this.word;
    if (v === plain) { this.right++; this.score += 130; this.hint = TG(TG(TG('破译成功 ✅'))); }
    else { this.hint = TG2('原词是 {0} ❌', plain); }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'cryptogram_all', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      });
      return;
    }
    this.timer = setTimeout(() => { this.load(this.qi + 1); }, NEXT_MS);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); }
  }





  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", (this.qi + 1), this.diffTotal)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        Text(TG('答对 ') + this.right).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG('得分 ') + this.score).fontSize(FontSize.md).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')

      Text(TG('🔐 每个字母都被移位加密了；密钥只露出一部分，推出原词'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.cipher.split(''), (ch: string, i: number) => {
          Stack() {
          Text((ch)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .layoutWeight(1).height(Cell.of(46)).backgroundColor(Palette.violet).borderRadius(Radius.sm)
        }, (ch: string, i: number) => 'cc' + i)
      }.width('100%')

      Text(TG2('🔑 已知：{0}', this.shown))
        .fontSize(FontSize.sm).fontColor(Palette.violet).width('100%').textAlign(TextAlign.Center)

      Text(this.hint.length > 0 ? this.hint : '提示：同一位移的凯撒密码，密钥里的字母差就是位移量')
        .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Button((this.opts.length > 0 ? this.opts[0] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[0] : '')); })
        Button((this.opts.length > 0 ? this.opts[1] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[1] : '')); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button((this.opts.length > 0 ? this.opts[2] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[2] : '')); })
        Button((this.opts.length > 0 ? this.opts[3] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[3] : '')); })
      }.width('100%')

      Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
