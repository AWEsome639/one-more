/**
 * 时序判断 —— 左右两侧先后各亮一个图形，判断哪一个先出现
 * 胜负：10 次答对 ≥ 7 ⇒ 通关（越快分越高）　｜　进度：试次 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TRIALS: number = 10; const PASS: number = 7;
const A_MS: number = 430; const GAP_MS: number = 280; const B_MS: number = 430; const FEED_MS: number = 560;
const POOL: string[] = ['🍎', '⭐', '🔔', '🎈', '🍀', '🔷', '🌙', '🍋'];

@Component
export struct GTemporalOrderJudgment {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State embA: string = ''; @State embB: string = ''; @State sideA: number = 0;
  @State lit: number = -1;       // -1 无　0 第一次闪现　1 第二次闪现
  @State phase: number = 0;      // 0 第一下　1 间隔　2 第二下　3 作答　4 反馈
  @State trial: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private shownAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll(); this.trial = 1; this.hits = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const i: number = Math.floor(Math.random() * POOL.length);
    let j: number = Math.floor(Math.random() * POOL.length);
    while (j === i) { j = Math.floor(Math.random() * POOL.length); }
    this.embA = POOL[i]; this.embB = POOL[j];
    this.sideA = Math.random() < 0.5 ? 0 : 1;
    this.lit = 0; this.phase = 0;
    this.msg = TG2("第 {0} / {1} 次：看清先后",Digits(String(this.trial), this.langCode),Digits(String(this.diffTotal), this.langCode));
    this.timer = setTimeout(() => {
      this.timer = -1; this.lit = -1; this.phase = 1;
      this.timer = setTimeout(() => {
        this.timer = -1; this.lit = 1; this.phase = 2;
        this.timer = setTimeout(() => {
          this.timer = -1; this.lit = -1; this.phase = 3; this.shownAt = Date.now();
          this.msg = TG('哪一个先出现？点它那一侧');
        }, B_MS);
      }, GAP_MS);
    }, A_MS);
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.sideA],
      TG2('答案是第 {0} 个', String(this.sideA + 1)),
      TG2('The answer is option {0}', String(this.sideA + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.sideA   ｜ 守卫取自它自己的 if (...) { return; }
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 3 || this.over) {
      return true;
    }
    this.answer(this.sideA);
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

  private answer(side: number): void {
    if (this.phase !== 3 || this.over) { return; }
    const rt: number = Date.now() - this.shownAt;
    this.phase = 4;
    if (side === this.sideA) {
      this.hits = this.hits + 1; this.score = this.score + Math.max(25, 120 - Math.floor(rt / 25));
      this.msg = '✅ ' + rt + ' ms';
    } else {
      this.msg = TG2('❌ 先出现的是 {0}', this.embA);
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.trial >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.hits, this.diffTotal);
      this.finish(this.won); return;
    }
    this.trial = this.trial + 1; this.newTrial();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'temporal_order_judgment', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private embAt(side: number): string { return side === this.sideA ? this.embA : this.embB; }
  private isLit(side: number): boolean {
    if (this.lit < 0) { return false; }
    return this.lit === 0 ? side === this.sideA : side !== this.sideA;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('试次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.lime))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Stack() {
        if (this.isLit((0))) {
        Text(this.embAt((0))).fontSize(FontSize.hero)
        } else if (this.phase >= 3) {
        Text(this.embAt((0))).fontSize(FontSize.xxl).fontColor(this.theme.inkFaint)
        } else {
        Text('·').accessibilityLevel('no').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
        }
        }.layoutWeight(1).height('100%')
        .backgroundColor(this.isLit((0)) ? (this.lit === 0 ? Palette.amber : Palette.sky) : this.theme.surfaceAlt)
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        Stack() {
        if (this.isLit((1))) {
        Text(this.embAt((1))).fontSize(FontSize.hero)
        } else if (this.phase >= 3) {
        Text(this.embAt((1))).fontSize(FontSize.xxl).fontColor(this.theme.inkFaint)
        } else {
        Text('·').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
        }
        }.layoutWeight(1).height('100%')
        .backgroundColor(this.isLit((1)) ? (this.lit === 0 ? Palette.amber : Palette.sky) : this.theme.surfaceAlt)
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').height(180)
      Row({ space: Space.sm }) {
        Button((true ? '⬅️ ' : '➡️ ') + this.embAt((0)) + (true ? ' 左边先' : ' 右边先'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(true ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(this.phase === 3 && !this.over)
        .onClick(() => { Haptics.tap(); this.answer((0)); })
        Button((false ? '⬅️ ' : '➡️ ') + this.embAt((1)) + (false ? ' 左边先' : ' 右边先'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(false ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).enabled(this.phase === 3 && !this.over)
        .onClick(() => { Haptics.tap(); this.answer((1)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('两次闪现之间夹着一小段空白，别看错先后')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
