/** 语义联想 —— 挑出与线索词关系最紧的搭档词｜胜负：10 题答对 ≥7 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 10; const PASS: number = 7; const GAP_MS: number = 700;

/** 强关联词对：[线索, 搭档] */
const PAIRS: string[][] = [
  ['针', '线'], ['锁', '钥匙'], ['笔', '纸'], ['茶', '杯'],
  ['雨', '伞'], ['夜', '灯'], ['锅', '铲'], ['蜂', '蜜'],
  ['雪', '冬'], ['火', '柴'], [TG('桥'), '河'], ['医', '药'],
  ['鞋', '袜'], ['电脑', '键盘'], ['太阳', '光'], ['风筝', '线轴']
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
export struct GSemanticAssociation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State cue: string = ''; @State opts: string[] = []; @State ans: number = 0;
  @State picked: number = -1; @State qi: number = 0; @State right: number = 0;
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
    this.qi = 0; this.right = 0; this.score = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.next();
  }

  private next(): void {
    const pi: number = Math.floor(Math.random() * PAIRS.length);
    const pair: string[] = PAIRS[pi];
    const pool: string[] = [];
    for (let i = 0; i < PAIRS.length; i++) { if (i !== pi) { pool.push(PAIRS[i][1]); } }
    const mixed: string[] = shufStr(pool);
    const four: string[] = shufStr([pair[1], mixed[0], mixed[1], mixed[2]]);
    this.cue = pair[0]; this.opts = four; this.ans = four.indexOf(pair[1]);
    this.picked = -1; this.msg = TG2('提到「{0}」，最先想到哪个？', pair[0]);
  }

  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1; this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ ' + this.cue + ' ↔ ' + this.opts[i];
    } else { this.msg = TG2('❌ 更贴切的是 {0}', this.opts[this.ans]); }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'semantic_association', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 语义联想')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.cue).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.isDark ? Palette.primary : Palette.primaryDeep)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primaryDeep
        : ((0) === this.ans ? Palette.emerald : ((0) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((0)); })
        Button(this.opts.length > (1) ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primaryDeep
        : ((1) === this.ans ? Palette.emerald : ((1) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((1)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (2) ? this.opts[(2)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primaryDeep
        : ((2) === this.ans ? Palette.emerald : ((2) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((2)); })
        Button(this.opts.length > (3) ? this.opts[(3)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primaryDeep
        : ((3) === this.ans ? Palette.emerald : ((3) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((3)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2("{0} 题，答对 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
