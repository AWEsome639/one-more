/**
 * 倒序空间 —— 方块依次亮起，要按「相反」的顺序点回来（倒背）
 * 胜负：答对长度 5 的一轮通关，2 条命用完判负　｜　进度：长度 / 最长 / 生命
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const CELLS: number = 8;
const COLS: number = 4;
const START_SPAN: number = 3;
const WIN_SPAN: number = 5;
const LIVES: number = 2;
const ON_MS: number = 520;
const GAP_MS: number = 240;
const PER_SPAN: number = 120;

@Component
export struct GCorsiBackwardSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  onFinish: (r: GameResult) => void = () => {};

  @State seq: number[] = [];
  @State active: number = -1;
  @State tapIdx: number = 0;
  @State span: number = START_SPAN;
  @State best: number = 0;
  @State life: number = this.diffTotal;
  @State phase: number = 0;      // 0=观察 1=作答 2=结束
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;
  private t1: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
     this.reset(); }
  aboutToDisappear(): void { this.killTimer(); }

  private killTimer(): void {
    if (this.t1 >= 0) { clearTimeout(this.t1); this.t1 = -1; }
  }

  private reset(): void {
    this.killTimer();
    this.span = START_SPAN; this.best = 0; this.life = this.diffTotal;
    this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i); }
    for (let k = pool.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: number = pool[k];
      pool[k] = pool[j];
      pool[j] = tmp;
    }
    const s: number[] = [];
    for (let i = 0; i < this.span && i < CELLS; i++) { s.push(pool[i]); }
    this.seq = s;
    this.active = -1;
    this.tapIdx = 0;
    this.phase = 0;
    this.msg = TG2('看顺序，共 {0} 个（要倒着点）', s.length);
    this.flash(0, true);
  }

  private flash(step: number, lit: boolean): void {
    if (step >= this.seq.length) {
      this.active = -1;
      this.phase = 1;
      this.tapIdx = 0;
      this.msg = TG('倒着点回来：先点最后亮的那个');
      return;
    }
    this.active = lit ? this.seq[step] : -1;
    this.t1 = setTimeout(() => { this.flash(lit ? step : step + 1, !lit); }, lit ? ON_MS : GAP_MS);
  }

  /** 倒背：第 tapIdx 次要点的应是 seq 的倒数第 tapIdx+1 个 */
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 1) {
      return true;
    }
    this.tap(this.seq[this.seq.length - 1 - this.tapIdx]);
    return !this.over;
  }

  /** 提示：倒着数该点哪一格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.phase !== 1 || this.over) {
      return Hint.none('none');
    }
    const want: number = this.seq[this.seq.length - 1 - this.tapIdx];
    return Hint.make([want], TG2('点第 {0} 个', String(want + 1)),
      TG2('Tap cell {0}', String(want + 1)), t0);
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private tap(i: number): void {
    if (this.phase !== 1 || this.over) { return; }
    const want: number = this.seq[this.seq.length - 1 - this.tapIdx];
    if (i === want) {
      this.tapIdx++;
      if (this.tapIdx >= this.seq.length) {
        this.best = this.span;
        if (this.best >= WIN_SPAN) { this.end(true); return; }
        this.span++;
        this.msg = TG2('✅ 倒背成功！长度升到 {0}', this.span);
        this.newRound();
      }
      return;
    }
    this.life--;
    if (this.life <= 0) { this.end(false); return; }
    this.msg = TG2("❌ 顺序错了，还剩 {0} 条命",Digits(String(this.life), this.langCode));
    this.newRound();
  }

  private end(solved: boolean): void {
    this.killTimer();
    this.over = true;
    this.won = solved;
    this.phase = 2;
    this.active = -1;
    this.msg = TG2(solved ? '🎉 通关：最长倒背 {0} 个' : '最长倒背 {0} 个',Digits(String(this.best), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'corsi_backward_span', solved: solved, score: this.best * PER_SPAN,
      durationMs: Date.now() - this.startAt, levelReached: this.best
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        Column({ space: 2 }) {
        Text((TG('长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.berry))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最长'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.best), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach([0, 1], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text(this.active === (r * COLS + c) ? '💡' : '').fontSize(FontSize.xxl)
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.active === (r * COLS + c) ? Palette.berry : this.theme.surface)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.tap((r * COLS + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).layoutWeight(1)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('倒背：长度升到 {0} 即通关；倒着点，别顺着点',Digits(String(WIN_SPAN), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
