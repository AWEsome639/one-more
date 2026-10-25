/**
 * 空间冲突 —— 箭头的「方向 / 文字 / 位置」互相捣乱，只准跟箭头走
 * 胜负：12 题答对 ≥ 9 ⇒ 通关　｜　进度：题号 / 答对 / 得分
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

const TRIALS: number = 12; const PASS: number = 9; const FEED_MS: number = 380;

@Component
export struct GSpatialConflict {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State dir: number = 0; @State word: number = 0; @State spot: number = 0; @State flash: number = -1;
  @State trial: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll(); this.trial = 1; this.hits = 0; this.score = 0; this.flash = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const d: number = Math.random() < 0.5 ? 0 : 1;
    this.dir = d; this.spot = Math.random() < 0.5 ? 0 : 1;
    this.word = Math.random() < 0.65 ? 1 - d : d; this.flash = -1;
    this.msg = TG2("第 {0} / {1} 题：照箭头指的方向点", this.trial, this.diffTotal);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.dir   ｜ 守卫取自它自己的 if (...) { return; }
  /** 提示：报答案（字段 this.dir） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      this.dir === 0 ? TG('选左边') : TG('选右边'),
      this.dir === 0 ? TG('Pick the left one') : TG('Pick the right one'), t0);
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
    if (this.over || this.flash >= 0) {
      return true;
    }
    this.answer(this.dir);
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

  private answer(pickDir: number): void {
    if (this.over || this.flash >= 0) { return; }
    const name: string = this.dir === 0 ? TG('左') : TG('右');
    if (pickDir === this.dir) {
      this.hits = this.hits + 1; this.score = this.score + 10; this.flash = 1; this.msg = TG2('✅ 箭头指向{0}', name);
    } else {
      this.flash = 0; this.msg = TG2('❌ 箭头指向{0}，别被字和位置骗', name);
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
    const r: GameResult = { gameId: 'spatial_conflict', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.trial };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trial + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Stack() {
        if (this.spot === (0)) {
        Column({ space: Space.xs }) {
        Text(this.dir === 0 ? '⬅️' : '➡️').fontSize(FontSize.hero)
        Text(this.word === 0 ? TG('左') : TG('右')).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        }
        } else {
        Text('·').accessibilityLevel('no').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
        }
        }.layoutWeight(1).height('100%')
        .backgroundColor(this.flash < 0 ? this.theme.surfaceAlt : (this.flash === 1 ? '#2210B981' : '#22EF4444'))
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        Stack() {
        if (this.spot === (1)) {
        Column({ space: Space.xs }) {
        Text(this.dir === 0 ? '⬅️' : '➡️').fontSize(FontSize.hero)
        Text(this.word === 0 ? TG('左') : TG('右')).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        }
        } else {
        Text('·').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
        }
        }.layoutWeight(1).height('100%')
        .backgroundColor(this.flash < 0 ? this.theme.surfaceAlt : (this.flash === 1 ? '#2210B981' : '#22EF4444'))
        .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').height(180)
      Row({ space: Space.sm }) {
        Button((TG('⬅️ 左')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(true ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).onClick(() => { Haptics.tap(); this.answer((0)); })
        Button((TG('右 ➡️')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(false ? Palette.sky : Palette.violet)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).onClick(() => { Haptics.tap(); this.answer((1)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
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
      Text(TG('规矩只有一条：跟箭头走，字和位置都在骗你')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



  /** 某一侧：箭头 + 捣乱的字 */



}
