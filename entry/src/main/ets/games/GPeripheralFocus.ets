/**
 * 周边视野 —— 眼睛盯住中心的 ➕，用余光辨认一闪而过的周边符号
 * 胜负：14 次答对 ≥ 10 ⇒ 通关　｜　进度：试次 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SHAPES: string[] = ['🍎', '🔷', '⭐', '🎵', '🍀', '🔺', '⚡', '🌙', '🎈', '🍄'];
const CELLS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const OPTS: number[] = [0, 1, 2, 3];
const CENTER: number = 4;
const TRIALS: number = 14;
const PASS: number = 10;
const START_MS: number = 950;
const FLOOR_MS: number = 380;
const STEP_MS: number = 42;
const FEED_MS: number = 620;

@Component
export struct GPeripheralFocus {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State at: number = -1; @State target: string = ''; @State opts: string[] = [];
  @State phase: number = 0;        // 0 呈现　1 作答　2 反馈
  @State pick: string = '';
  @State trial: number = 1; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private shuffle(src: string[]): string[] {
    const out: string[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  /** 越往后闪得越短：950ms ⇒ 380ms 封底 */
  private showMs(): number {
    const ms: number = START_MS - (this.trial - 1) * STEP_MS;
    return ms < FLOOR_MS ? FLOOR_MS : ms;
  }

  private reset(): void {
    this.clearAll();
    this.trial = 1; this.right = 0; this.score = 0; this.pick = ''; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newTrial();
  }

  private newTrial(): void {
    const bag: string[] = this.shuffle(SHAPES);
    this.target = bag[0];
    this.opts = this.shuffle(bag.slice(0, 4));
    const outer: number[] = [];
    for (let i = 0; i < CELLS.length; i++) {
      if (CELLS[i] !== CENTER) { outer.push(CELLS[i]); }
    }
    this.at = outer[Math.floor(Math.random() * outer.length)];
    this.pick = ''; this.phase = 0;
    this.msg = TG2("第 {0} 次：盯住中心 ➕，别移开视线",Digits(String(this.trial), this.langCode));
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1;
      this.msg = TG2('刚才余光里的符号是哪个？（{0} ms）', this.showMs());
    }, this.showMs());
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.target   ｜ 守卫取自它自己的 if (...) { return; }
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 1) {
      return true;
    }
    this.answer(this.target);
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

  private answer(sym: string): void {
    if (this.phase !== 1) { return; }
    this.pick = sym; this.phase = 2;
    if (sym === this.target) {
      this.right = this.right + 1; this.score = this.score + 80;
      this.msg = TG('✅ 余光认对了');
    } else {
      this.msg = TG2('❌ 闪过的符号是 {0}', this.target);
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.trial >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.trial = this.trial + 1;
    this.newTrial();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'peripheral_focus', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.cyan))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Grid() {
        ForEach(CELLS, (i: number) => { GridItem() {
        Stack() {
        if ((i) === CENTER) {
        Text('➕').accessibilityLevel('no').fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
        } else if (this.phase === 0 && (i) === this.at) {
        Text(this.target).fontSize(FontSize.xxl)
        } else if (this.phase === 2 && (i) === this.at) {
        Text(this.target).fontSize(FontSize.xxl).fontColor(Palette.amber)
        } else {
        Text('·').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
        }
        }.width('100%').aspectRatio(1).backgroundColor(this.phase === 2 && (i) === this.at ? Palette.amber : this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))

        } }, (i: number) => 'pf' + i)
      }.columnsTemplate('1fr 1fr 1fr').rowsGap(Space.sm).columnsGap(Space.sm).width('100%').height(258)
      Row({ space: Space.sm }) {
        ForEach(OPTS, (i: number) => { Button(this.opts.length > (i) ? this.opts[(i)] : '?')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF').backgroundColor(this.pick === this.opts[(i)] ? Palette.cyan : Palette.primary)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(60)).enabled(this.phase === 1).onClick(() => { Haptics.tap(); this.answer(this.opts[(i)]); }) }, (i: number) => 'po' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：视线始终留在中心 ➕ 上，只靠余光看四周的格子')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
