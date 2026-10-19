/**
 * 辅音重建 —— 单词里的元音被挖成下划线，靠辅音骨架 + 中文提示还原整词
 * 胜负：6 个词全部还原通关；答错或跳过扣一条命，命尽即失败
 * 进度：第几词 / 已还原数 / 生命 / 得分
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 6; const LIVES: number = 3; const VOWELS: string = 'AEIOU';
interface Item { w: string; hint: string }
const POOL: Item[] = [
  { w: 'ELEPHANT', hint: '大象 🐘' }, { w: 'MOUNTAIN', hint: '高山 ⛰️' },
  { w: 'KITCHEN', hint: '厨房 🍳' }, { w: 'WINDOW', hint: '窗户 🪟' },
  { w: 'GIRAFFE', hint: '长颈鹿 🦒' }, { w: 'UMBRELLA', hint: '雨伞 ☂️' },
  { w: 'BICYCLE', hint: '自行车 🚲' }, { w: 'DOLPHIN', hint: '海豚 🐬' },
  { w: 'LIBRARY', hint: '图书馆 📚' }, { w: 'CHOCOLATE', hint: '巧克力 🍫' },
  { w: 'PENGUIN', hint: '企鹅 🐧' }, { w: 'SANDWICH', hint: '三明治 🥪' }
];
/** 元音换成下划线，辅音与字母总数原样保留 */
function skeleton(w: string): string {
  const out: string[] = [];
  for (let i = 0; i < w.length; i++) {
    const ch: string = w.charAt(i);
    out.push(VOWELS.indexOf(ch) >= 0 ? '_' : ch);
  }
  return out.join(' ');
}
@Component
export struct GConsonantReconstruct {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State order: number[] = []; @State qi: number = 0; @State solved: number = 0;
  @State life: number = LIVES; @State score: number = 0; @State input: string = '';
  @State msg: string = ''; @State over: boolean = false; /** ★ 动效：进度数字弹动 */ @State bump: number = 1; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): Item { return POOL[this.order[this.qi]]; }
  private reset(): void {
    this.qi = 0; this.solved = 0; this.life = LIVES; this.score = 0; this.input = '';
    this.over = false; this.won = false; this.done = false;
    this.msg = TG(TG(TG('补全元音，拼出这个单词'))); this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out;
  }
  private submit(): void {
    if (this.over) { return; }
    const guess: string = this.input.trim().toUpperCase();
    this.input = '';
    if (guess.length === 0) { return; }
    if (guess === this.cur().w) {
      this.solved = this.solved + 1; this.score = this.score + 120; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ {0} —— 正确！', this.cur().w);
      this.nextQ();
    } else {
      this.life = this.life - 1;
      this.msg = '❌ 「' + guess + '」不对，还剩 ' + this.life + TG(' 条命');
      if (this.life <= 0) { this.end(); }
    }
  }
  private skip(): void {
    if (this.over) { return; }
    this.life = this.life - 1; this.input = '';
    this.msg = TG2('⏭ 跳过：答案是 {0}', this.cur().w);
    if (this.life <= 0) { this.end(); return; }
    this.nextQ();
  }
  /** 换词时把上一个词的长度报进度，玩家能对上下题 */
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private nextQ(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.doBump();   // ★ 弹一下
    this.msg = this.msg + '　｜　下一词：' + this.cur().w.length + TG(' 个字母');
  }
  private end(): void {
    this.over = true; this.won = this.solved >= this.diffTotal;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("还原 {0} / {1}", this.solved, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'consonant_reconstruct', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solved };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
// ★ 动效：进度一变就弹一下
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('还原')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.solved), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
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
        Text(this.cur().hint).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        Text(skeleton(this.cur().w)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(Palette.primary)
        Text(TG2("共 {0}", this.cur().w.length)).fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }
      .width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入完整单词' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm })
          .onChange((v: string) => { this.input = v; }).onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.submit(); })
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Button(TG('跳过（-1 命）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(!this.over).onClick(() => { Haptics.tap(); this.skip(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')
      Text(TG('提示：下划线是被人挖走的元音，字母总数照原样保留'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
