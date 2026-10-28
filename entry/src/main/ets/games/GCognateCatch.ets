/**
 * 同源词 —— 给一对词，判断它们是否同源（同一古词根演化而来）
 * 胜负：12 题答对 ≥8 题通关；每题答完给一句词源小注
 * 进度：题号 / 答对数 / 得分
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 12; const PASS: number = 8; const SAME_N: number = 8;
interface Pair { a: string; b: string; same: boolean; note: string }
/** 前 8 条真同源，后 8 条形似而实不同源 */
const ALL: Pair[] = [
  { a: 'night', b: 'Nacht（德语）', same: true, note: '同出古日耳曼 *nahts：夜' },
  { a: 'father', b: 'Vater（德语）', same: true, note: '同出原始印欧 *ph₂tḗr：父' },
  { a: 'three', b: 'trois（法语）', same: true, note: '同出 *tréyes：三' },
  { a: 'heart', b: 'Herz（德语）', same: true, note: '同出 *ḱerd-：心' },
  { a: 'water', b: 'Wasser（德语）', same: true, note: '同出 *wódr̥：水' },
  { a: 'star', b: 'Stern（德语）', same: true, note: '同出 *h₂stḗr：星' },
  { a: 'tooth', b: 'Zahn（德语）', same: true, note: '同出 *h₃dónts：齿' },
  { a: 'milk', b: 'Milch（德语）', same: true, note: '同出 *melg-：挤奶' },
  { a: 'much（多）', b: 'mucho（西语：多）', same: false, note: 'much 出 *meg-，mucho 出拉丁 multus' },
  { a: 'pain（疼痛）', b: 'pan（西语：面包）', same: false, note: 'pain 出拉丁 poena，pan 出拉丁 panis' },
  { a: 'red（红）', b: 'Rede（德语：演讲）', same: false, note: 'red 出 *raudaz，Rede 出 *raþjō' },
  { a: 'tree（树）', b: 'drei（德语：三）', same: false, note: 'tree 出 *dóru，drei 出 *tréyes' },
  { a: 'grass（草）', b: 'gris（西语：灰）', same: false, note: 'grass 出 *gʰreh₁-，gris 出 *grēwaz' },
  { a: 'son（儿子）', b: 'Sonne（德语：太阳）', same: false, note: 'son 出 *suHnus，Sonne 出 *sóh₂wl̥' },
  { a: 'sun（太阳）', b: 'Sohn（德语：儿子）', same: false, note: 'sun 出 *sóh₂wl̥，Sohn 出 *suHnus' },
  { a: 'cold（冷）', b: 'Gold（德语：金子）', same: false, note: 'cold 出 *gel-，Gold 出 *ǵʰelh₃-' }
];
@Component
export struct GCognateCatch {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State order: number[] = []; @State qi: number = 0; @State correct: number = 0;
  @State score: number = 0; @State answered: boolean = false; @State lastOk: boolean = false;
  @State over: boolean = false; /** ★ 动效：进度数字弹动 */ @State bump: number = 1; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): Pair { return ALL[this.order[this.qi]]; }
  /** 从 from 里随机取 k 个不重复的 */
  private pick(from: number[], k: number): number[] {
    const out: number[] = []; const copy: number[] = from.slice();
    for (let i = 0; i < k; i++) {
      const p: number = Math.floor(Math.random() * copy.length);
      out.push(copy[p]); copy.splice(p, 1);
    }
    return out;
  }
  private reset(): void {
    this.qi = 0; this.correct = 0; this.score = 0; this.answered = false;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('这一对是同源词吗？'); this.startAt = Date.now();
    const ia: number[] = []; const ib: number[] = [];
    for (let i = 0; i < SAME_N; i++) { ia.push(i); }
    for (let i = SAME_N; i < ALL.length; i++) { ib.push(i); }
    const all: number[] = this.pick(ia, this.diffTotal / 2).concat(this.pick(ib, this.diffTotal / 2));
    for (let i = all.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = all[i]; all[i] = all[j]; all[j] = t;
    }
    this.order = all;
  }
  private answer(said: boolean): void {
    if (this.over || this.answered) { return; }
    const p: Pair = this.cur();
    const ok: boolean = said === p.same;
    this.answered = true; this.lastOk = ok;
    if (ok) { this.correct = this.correct + 1; this.score = this.score + 100; }
    this.msg = TG2(ok ? '✅ 答对了 —— {0}' : '❌ 答错了 —— {0}', p.note);
  }
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private nextQ(): void {
    if (this.over) { return; }
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.doBump();   // ★ 弹一下 this.answered = false; this.msg = TG('这一对是同源词吗？');
  }
  private end(): void {
    this.over = true; this.won = this.correct >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.correct, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'cognate_catch', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.correct };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
            Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
// ★ 动效：进度一变就弹一下
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.correct + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        Text(this.cur().a).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text('↔').accessibilityText(TG('对应')).fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
        Text(this.cur().b).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.primary)
      }
      .width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.answered ? (this.lastOk ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      if (this.answered) {
        Button(this.over ? '看结果' : '下一题 →')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.nextQ(); })
      } else {
        Row({ space: Space.md }) {
          Button(TG('同源 ✅'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.answer(true); })
          Button(TG('非同源 ❌'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.rose)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.answer(false); })
        }
        .width('100%')
      }
            Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：词形像不等于同源 —— 要看它们能不能追到同一个古词根'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
