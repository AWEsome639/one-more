/** 押韵大师 —— 四选一挑出与目标词押韵的词｜胜负：8 题答对 ≥6 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 8; const PASS: number = 6; const GAP_MS: number = 700;

/** 每个家族内部互相押韵 */
const FAMS: string[][] = [
  ['LIGHT', 'NIGHT', 'FIGHT', 'SIGHT'], ['CAT', 'HAT', 'MAT', 'BAT'],
  ['MOON', 'SPOON', 'SOON', 'BALLOON'], ['MAKE', 'CAKE', 'LAKE', 'SNAKE'],
  ['RING', 'SING', 'KING', 'WING'], ['CHAIR', 'FAIR', 'HAIR', 'STAIR'],
  ['BLUE', 'TRUE', 'GLUE', 'CLUE'], ['GOLD', 'TOLD', 'BOLD', 'FOLD'],
  ['SMILE', 'TILE', 'MILE', 'WHILE'], ['TREE', 'FREE', 'THREE', 'AGREE'],
  ['STAR', 'CAR', 'FAR', 'JAR'], ['CLOCK', 'ROCK', 'SOCK', 'LOCK']
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
export struct GRhymeMaster {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State target: string = ''; @State opts: string[] = []; @State ans: number = 0;
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
    const fi: number = Math.floor(Math.random() * FAMS.length);
    const fam: string[] = FAMS[fi];
    const correct: string = fam[1 + Math.floor(Math.random() * (fam.length - 1))];
    const pool: string[] = [];
    for (let i = 0; i < FAMS.length; i++) {
      if (i !== fi) { for (let k = 0; k < FAMS[i].length; k++) { pool.push(FAMS[i][k]); } }
    }
    const mixed: string[] = shufStr(pool);
    const four: string[] = shufStr([correct, mixed[0], mixed[1], mixed[2]]);
    this.target = fam[0]; this.opts = four; this.ans = four.indexOf(correct);
    this.picked = -1; this.msg = TG('哪个词和它押韵？');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
    return !this.over;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1; this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ 押韵！{0} ↔ {1}', this.target, this.opts[i]);
    } else { this.msg = TG2('❌ 不押韵 —— 正解是 {0}', this.opts[this.ans]); }
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
    const r: GameResult = { gameId: 'rhyme_master', solved: solved, score: this.score,
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
        Text(TG('🎵 与它押韵的是？')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.target).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.cyan)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.cyan
        : ((0) === this.ans ? Palette.emerald : ((0) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((0)); })
        Button(this.opts.length > (1) ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.cyan
        : ((1) === this.ans ? Palette.emerald : ((1) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((1)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (2) ? this.opts[(2)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.cyan
        : ((2) === this.ans ? Palette.emerald : ((2) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((2)); })
        Button(this.opts.length > (3) ? this.opts[(3)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.cyan
        : ((3) === this.ans ? Palette.emerald : ((3) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((3)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2("{0} 题，答对 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
