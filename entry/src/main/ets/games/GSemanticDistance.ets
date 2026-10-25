/** 语义距离 —— 判断两个候选词里哪个离锚点词更近｜胜负：10 题答对 ≥7 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 10; const PASS: number = 7; const GAP_MS: number = 700;

/** [锚点, 近义词, 远义词] */
const TRIOS: string[][] = [
  ['冷', '冰', '火'], ['快', '疾', '缓'], ['大', '巨', '微'], ['亮', '明', '暗'],
  ['甜', '蜜', '苦'], ['高', '塔', '坑'], ['静', '悄', '闹'], ['旧', '古', '新'],
  ['强', '壮', '弱'], ['近', '邻', '远'], ['圆', '球', '方'], ['湿', '潮', '干'],
  ['硬', '钢', '棉'], ['香', '花', '臭'], ['深', '海', '滩'], ['轻', '羽', '石']
];

@Component
export struct GSemanticDistance {
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

  @State anchor: string = ''; @State opts: string[] = []; @State ans: number = 0;
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
    const t: string[] = TRIOS[Math.floor(Math.random() * TRIOS.length)];
    if (Math.random() < 0.5) { this.opts = [t[1], t[2]]; this.ans = 0; }
    else { this.opts = [t[2], t[1]]; this.ans = 1; }
    this.anchor = t[0]; this.picked = -1;
    this.msg = TG2('哪个词离「{0}」更近？', t[0]);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是第 {0} 个', String(n + 1)),
      TG2('The answer is option {0}', String(n + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
      this.msg = TG2('✅ 对，「{0}」更近', this.opts[i]);
    } else { this.msg = TG2('❌ 更近的是「{0}」', this.opts[this.ans]); }
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
    const r: GameResult = { gameId: 'semantic_distance', solved: solved, score: this.score,
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
        Text(TG('📖 锚点词')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.anchor).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.primary)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primary
        : ((0) === this.ans ? Palette.emerald : ((0) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((0)); })
        Button(this.opts.length > (1) ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.primary
        : ((1) === this.ans ? Palette.emerald : ((1) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((1)); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2("{0} 题，答对 ≥{1} 通关：词义越近越好",Digits(String(this.diffTotal), this.langCode), PASS))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
