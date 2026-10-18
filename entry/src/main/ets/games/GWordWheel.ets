/**
 * 单词轮 —— 从 6 个字母里拼英文单词（每个字母一轮只能用一次）
 * 胜负：找齐 5 个词通关；拼错 3 次失败　进度：已找到 / 得分 / 剩余机会
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface WheelSet { letters: string; words: string[]; }
const SETS: WheelSet[] = [
  { letters: 'SILENT', words: ['SIT', 'TIN', 'TIE', 'LIE', 'LINE', 'LIST', 'NEST', 'SENT', 'TILE', 'SILT'] },
  { letters: 'MASTER', words: ['ARM', 'ART', 'EAT', 'SEA', 'TEAM', 'EAST', 'MAST', 'STEM', 'TEAR', 'RATE'] },
  { letters: 'GARDEN', words: ['AGE', 'END', 'RAN', 'RED', 'DEAR', 'READ', 'DARE', 'RANG', 'GRAND', 'GRADE'] },
  { letters: 'PLANET', words: ['PLAN', 'LANE', 'TALE', 'LATE', 'NEAT', 'PLEA', 'PLANE', 'PLANT', 'PETAL'] },
  { letters: 'CANDLE', words: ['CAN', 'AND', 'END', 'LAND', 'LANE', 'DEAL', 'LEAD', 'LEND', 'DANCE', 'CLEAN'] }
];
const GOAL: number = 5; const LIVES: number = 3;

@Component
export struct GWordWheel {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GOAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(GOAL);
  onFinish: (r: GameResult) => void = () => {};

  @State letters: string[] = []; @State bank: string[] = []; @State found: string[] = [];
  @State typed: string = ''; @State score: number = 0; @State life: number = LIVES;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3, 4, 5];

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GOAL);
     this.reset(); }

  private reset(): void {
    const s: WheelSet = SETS[Math.floor(Math.random() * SETS.length)];
    this.letters = s.letters.split(''); this.bank = s.words; this.found = []; this.typed = '';
    this.score = 0; this.life = LIVES; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.msg = TG('点字母拼词 —— 每个字母一轮只能用一次');
  }

  private goal(): number { return Math.min(this.diffTotal, this.bank.length); }

  private cnt(src: string, ch: string): number {
    let n: number = 0;
    for (let i = 0; i < src.length; i++) { if (src.charAt(i) === ch) { n = n + 1; } }
    return n;
  }

  private pick(i: number): void {
    if (this.over) { return; }
    const ch: string = this.letters[i];
    if (this.cnt(this.typed, ch) >= this.cnt(this.letters.join(''), ch)) {
      this.msg = TG2('「{0}」这一轮已经用掉了', ch); return;
    }
    this.typed = this.typed + ch;
  }

  private submit(): void {
    if (this.over) { return; }
    const w: string = this.typed;
    if (w.length < 3) { this.msg = TG('至少 3 个字母才算词'); return; }
    if (this.found.indexOf(w) >= 0) { this.msg = TG2('「{0}」已经找过了', w); return; }
    if (this.bank.indexOf(w) < 0) {
      this.life = this.life - 1; this.score = Math.max(0, this.score - 20); this.typed = '';
      if (this.life <= 0) { this.end(false); return; }
      this.msg = TG2('❌ 本组词里没有「{0}」，只剩 {1} 次机会', w,Digits(String(this.life), this.langCode)); return;
    }
    const gain: number = 40 + w.length * 10;
    const f: string[] = this.found.slice(); f.push(w); this.found = f;
    this.score = this.score + gain; this.typed = '';
    if (f.length >= this.goal()) { this.end(true); return; }
    this.msg = TG2("✅ 「{0}」+ {1} 分", w, gain);
  }

  private end(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 找齐 ' + this.goal() + ' 个词，通关！'
      : '💤 机会用完 —— 本组共有 ' + this.bank.length + TG(' 个词');
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'word_wheel', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.found.length };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('找到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found.length + '/' + this.goal())).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.cyan))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('机会'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Text(this.typed.length === 0 ? '＿ ＿ ＿' : this.typed)
        .fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).width('100%').height(Cell.of(56))
        .textAlign(TextAlign.Center)
        .fontColor(this.typed.length === 0 ? this.theme.inkFaint : Palette.primaryDeep)
        .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.xs }) {
        ForEach(this.slots, (i: number) => {
          Text(this.letters[(i)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .textAlign(TextAlign.Center).layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.theme.isDark ? Palette.primaryDeep : Palette.primary)
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { this.pick((i)); })
        }, (i: number) => 'L' + i)
      }
      .width('100%')

      Text(this.found.length === 0 ? '已找到：（空）' : '已找到：' + this.found.join(' · '))
        .fontSize(FontSize.xs).fontColor(this.theme.inkFaint).width('100%')

      Row({ space: Space.sm }) {
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { this.submit(); })
        Button(TG('退格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).width(76).height(Cell.of(46))
          .onClick(() => { this.typed = this.typed.substring(0, Math.max(0, this.typed.length - 1)); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.cyan)
          .borderRadius(Radius.md).width(76).height(Cell.of(46)).onClick(() => { this.reset(); })
      }
      .width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Text(TG('提示：词都是 3~6 个字母的常见英文词，先凑短的再拼长的'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
