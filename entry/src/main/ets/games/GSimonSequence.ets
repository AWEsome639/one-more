/**
 * 西蒙序列 📈（id: simon_sequence）
 * 6 个数字格按顺序亮起，照着点回去；每过一关序列加长一位。
 * 胜负：长度撑到 8 ⇒ 通关；点错 ⇒ 失败。进度：序列长度 / 得分 / 已点几下。
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

const PADS: number = 6; const WIN_LEN: number = 8;
const SHOW_TICK: number = 420; const FLASH_MS: number = 170; const GAP_MS: number = 620;
const PAD_COLORS: string[] = [Palette.primary, Palette.berry, Palette.emerald, Palette.amber, Palette.sky, Palette.violet];
const PAD_NUM: string[] = ['1', '2', '3', '4', '5', '6'];
const ROW_A: number[] = [0, 1, 2]; const ROW_B: number[] = [3, 4, 5];

@Component
export struct GSimonSequence {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：原 SHOW_TICK=420
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(420);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State lit: number = -1; @State len: number = 0; @State pos: number = 0; @State score: number = 0;
  @State phase: string = 'show'; @State over: boolean = false; @State won: boolean = false;
  @State msg: string = '';
  private seq: number[] = []; private showIdx: number = -1;
  private showTimer: number = -1; private flashTimer: number = -1; private gapTimer: number = -1;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(420);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimers(); }
  private clearTimers(): void {
    if (this.showTimer >= 0) { clearInterval(this.showTimer); this.showTimer = -1; }
    if (this.flashTimer >= 0) { clearTimeout(this.flashTimer); this.flashTimer = -1; }
    if (this.gapTimer >= 0) { clearTimeout(this.gapTimer); this.gapTimer = -1; }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 'input') {
      return true;
    }
    this.tapPad(this.seq[this.pos]);
    return !this.over;
  }

  /** 提示：按顺序该点哪个号 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase !== 'input' || this.pos >= this.seq.length) {
      return Hint.make([], TG('正在演示：先看它亮的顺序'),
        TG('Watch the sequence first'), t0);
    }
    const v: number = this.seq[this.pos];
    return Hint.make([v], TG2('按顺序第 {0} 下点「{1}」号', String(this.pos + 1), PAD_NUM[v]),
      TG2('Press pad {1} as step {0}', String(this.pos + 1), PAD_NUM[v]), t0);
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

  private reset(): void {
    this.clearTimers(); this.seq = []; this.len = 0; this.pos = 0; this.score = 0;
    this.lit = -1; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  /** 序列加长一位，然后演示一遍 */
  private nextRound(): void {
    this.seq.push(Math.floor(Math.random() * PADS));
    this.len = this.seq.length; this.showIdx = -1; this.pos = 0; this.lit = -1;
    this.phase = 'show'; this.msg = TG2("看好了… 长度 {0}", this.len);
    if (this.showTimer >= 0) { clearInterval(this.showTimer); }
    this.showTimer = setInterval(() => { this.showStep(); }, this.diffTotal);
  }
  private showStep(): void {
    if (this.lit >= 0) { this.lit = -1; return; }
    if (this.showIdx + 1 < this.seq.length) {
      this.showIdx++; this.lit = this.seq[this.showIdx];
      return;
    }
    if (this.showTimer >= 0) { clearInterval(this.showTimer); this.showTimer = -1; }
    this.lit = -1; this.phase = 'input'; this.pos = 0;
    this.msg = TG2("轮到你了：按顺序点 {0} 下", this.len);
  }
  private tapPad(i: number): void {
    if (this.phase !== 'input' || this.over) { return; }
    if (this.seq[this.pos] !== i) { this.fail(); return; }
    this.flash(i); this.pos++;
    if (this.pos < this.seq.length) { return; }
    this.score += this.len * 15; this.phase = 'wait'; this.msg = TG2("✅ 长度 {0} 过关",Digits(String(this.len), this.langCode));
    if (this.len >= WIN_LEN) {
      this.won = true; this.over = true; this.phase = 'over';
      this.msg = TG2("🎉 序列长度到 {0}，通关！", WIN_LEN);
      this.clearTimers(); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.gapTimer >= 0) { clearTimeout(this.gapTimer); }
    this.gapTimer = setTimeout(() => { this.gapTimer = -1; this.nextRound(); }, GAP_MS);
  }
  private flash(i: number): void {
    this.lit = i;
    if (this.flashTimer >= 0) { clearTimeout(this.flashTimer); }
    this.flashTimer = setTimeout(() => { this.flashTimer = -1; this.lit = -1; }, FLASH_MS);
  }
  private fail(): void {
    this.over = true; this.won = false; this.phase = 'over'; this.lit = -1;
    this.msg = TG2('❌ 点错了，最长撑到 {0} 位', this.len);
    this.clearTimers(); this.finish(false);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const res: GameResult = {
      gameId: 'simon_sequence', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.len
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  private phaseText(): string {
    if (this.phase === 'input') { return this.pos + '/' + this.len; }
    if (this.phase === 'show') { return TG('演示'); }
    return '—';
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
        Text((this.len + '/' + WIN_LEN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phaseText())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach(ROW_A, (i: number) => { Stack() {
        Text(PAD_NUM[(i)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.lg)
        .backgroundColor(this.lit === (i) ? Palette.amber : PAD_COLORS[(i)])
        .shadow(this.lit === (i) ? Shadow.lifted : Shadow.card)
        .scale({ x: this.lit === (i) ? 1.05 : 1, y: this.lit === (i) ? 1.05 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapPad((i)); }) }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach(ROW_B, (i: number) => { Stack() {
        Text(PAD_NUM[(i)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.lg)
        .backgroundColor(this.lit === (i) ? Palette.amber : PAD_COLORS[(i)])
        .shadow(this.lit === (i) ? Shadow.lifted : Shadow.card)
        .scale({ x: this.lit === (i) ? 1.05 : 1, y: this.lit === (i) ? 1.05 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapPad((i)); }) }, (i: number) => 'b' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
