/** 三重序列 📈（id: triple_sequence）
 * 三行光点各自按固定节拍循环（周期 2/3/4 不等），一次猜出三行的下一拍位置；
 * 5 拍猜中 ≥11 个 ⇒ 通关，否则失败。 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROWS: number[] = [0, 1, 2];
const CELLS: number[] = [0, 1, 2, 3, 4, 5];
const STEPS: number = 5;
const NEED: number = 11;
const PAUSE: number = 700;
@Component
export struct GTripleSequence {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：STEPS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(STEPS);
  onFinish: (r: GameResult) => void = () => {};
  @State periods: number[] = [];
  @State step: number = 0;
  @State picks: number[] = [];
  @State lastAns: number[] = [];
  @State lastPick: number[] = [];
  @State hits: number = 0;
  @State rounds: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(STEPS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); }
  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.clearTimer();
    const p: number[] = [];
    for (let i = 0; i < ROWS.length; i++) { p.push(2 + Math.floor(Math.random() * 3)); }
    this.periods = p;
    this.step = 0; this.picks = [-1, -1, -1]; this.lastAns = []; this.lastPick = [];
    this.hits = 0; this.rounds = 0; this.over = false; this.won = false; this.done = false;
    this.note = TG('每行节拍不同，猜出下一拍亮在哪一格'); this.startAt = Date.now();
  }
  private beacon(i: number): number {
    return i < this.periods.length ? this.step % this.periods[i] : -1;
  }
  /** 代打/提示共用：第 i 行下一拍该点的格（judge 里就是 (step + 1) % periods[i]） */
  private ansAt(i: number): number {
    return i < this.periods.length ? (this.step + 1) % this.periods[i] : -1;
  }

  /** 代打：还有哪一行没点（全点完就 0，等 judge 的定时器） */
  private autoRow(): number {
    for (let i = 0; i < ROWS.length; i++) {
      if (this.picks.length > i && this.picks[i] < 0) {
        return i;
      }
    }
    return 0;
  }

  private autoCol(): number {
    return this.ansAt(this.autoRow());
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picks.indexOf(-1) < 0) {
      return true;
    }
    this.pick(this.autoRow(), this.autoCol());
    return !this.over;
  }

  // 答案 = (step + 1) % periods[i]（judge 里就是这么比的），报的是格号内容
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.picks.indexOf(-1) < 0) {
      return Hint.none('none');
    }
    const cells: number[] = [];
    const parts: string[] = [];
    for (let i = 0; i < ROWS.length; i++) {
      const c: number = this.ansAt(i);
      if (c < 0) {
        return Hint.none('none');
      }
      cells.push(i * CELLS.length + c);
      parts.push('第' + String(i + 1) + '行第' + String(c + 1) + '格');
    }
    return Hint.make(cells, '三行各点：' + parts.join('、'),
      'Tap ' + parts.join(' / '), t0);
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

  private pick(i: number, c: number): void {
    if (this.over || this.picks[i] >= 0) { return; }
    const p: number[] = this.picks.slice();
    p[i] = c;
    this.picks = p;
    if (this.picks.indexOf(-1) < 0) { this.judge(); }
  }
  private judge(): void {
    let hit: number = 0;
    const ans: number[] = [];
    for (let i = 0; i < ROWS.length; i++) {
      const a: number = (this.step + 1) % this.periods[i];
      ans.push(a);
      if (a === this.picks[i]) { hit++; }
    }
    this.hits += hit;
    this.lastAns = ans; this.lastPick = this.picks.slice();
    this.note = TG2('本轮 {0}/3 · 累计 {1}/{2}', String(hit), String(this.hits), String(NEED));
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.lastAns = []; this.lastPick = [];
      this.step++; this.rounds++; this.picks = [-1, -1, -1];
      if (this.rounds >= this.diffTotal) { this.finish(this.hits >= NEED); }
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved;
    this.clearTimer();
    const r: GameResult = {
      gameId: 'triple_sequence', solved: solved, score: this.hits * 20,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private shown(i: number): number {
    if (this.lastPick.length > i) { return this.lastPick[i]; }
    return this.picks.length > i ? this.picks[i] : -1;
  }
  private markColor(i: number): string {
    if (this.lastPick.length > i) {
      return this.lastPick[i] === this.lastAns[i] ? Palette.emerald : Palette.rose;
    }
    return Palette.primary;
  }
  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG2('第 {0}/{1} 拍 · 命中 {2}', String(Math.min(this.rounds + 1, this.diffTotal)),Digits(String(this.diffTotal), this.langCode),Digits(String(this.hits), this.langCode)) +
        TG2('/{0} · 三行各点一格', String(NEED)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Column({ space: Space.sm }) {
        ForEach(ROWS, (i: number) => {
          this.line(i)
        }, (i: number) => 'ln' + i)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  line(i: number) {
    Row({ space: Space.xs }) {
      ForEach(CELLS, (c: number) => {
        this.cell(i, c)
      }, (c: number) => 'tc' + i + '_' + c)
    }
    .width('100%')
  }
  @Builder
  cell(i: number, c: number) {
    Stack() {
      Text(c === this.beacon(i) ? '●' : '').fontSize(FontSize.xxs).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
    .backgroundColor(c === this.beacon(i) ? Palette.primary : this.theme.surface)
    .borderWidth(this.shown(i) === c ? 3 : 0).borderColor(this.markColor(i))
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
    .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
      .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
    .onClick(() => { Haptics.tick(); this.pick(i, c); })
  }
}
