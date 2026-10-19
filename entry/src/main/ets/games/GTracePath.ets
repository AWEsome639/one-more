/** 描路径 📐（id: trace_path）
 * 先看一遍亮起的路线，灭掉后从 🚩 起按原路一格一格点下去，点错就断线重来；
 * 3 条路线全部描完 ⇒ 通关，断线 4 次 ⇒ 失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const M: number = 5;
const CELLS: number = M * M;
const LEN: number = 7;
const ROUNDS: number = 3;
const MAX_ERR: number = 4;
const PREVIEW: number = 1600;
const RX: number[] = [0, 1, 2, 3, 4];
@Component
export struct GTracePath {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State path: number[] = [];
  @State traced: number[] = [];
  @State round: number = 0;
  @State err: number = 0;
  @State show: boolean = false;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); }
  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.clearTimer();
    this.round = 0; this.err = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newPath();
  }
  private makePath(): number[] {
    for (let attempt = 0; attempt < 60; attempt++) {
      const p: number[] = [Math.floor(Math.random() * CELLS)];
      while (p.length < LEN) {
        const c: number = p[p.length - 1];
        const r: number = Math.floor(c / M);
        const col: number = c % M;
        const cand: number[] = [];
        if (r > 0 && p.indexOf(c - M) < 0) { cand.push(c - M); }
        if (r < M - 1 && p.indexOf(c + M) < 0) { cand.push(c + M); }
        if (col > 0 && p.indexOf(c - 1) < 0) { cand.push(c - 1); }
        if (col < M - 1 && p.indexOf(c + 1) < 0) { cand.push(c + 1); }
        if (cand.length === 0) { break; }
        p.push(cand[Math.floor(Math.random() * cand.length)]);
      }
      if (p.length === LEN) { return p; }
    }
    return [0, 1, 2, 3, 4, 9, 14];
  }
  private newPath(): void {
    this.path = this.makePath();
    this.traced = [this.path[0]];
    this.show = true;
    this.note = TG2("看清路线 · 共 {0} 格", String(LEN));
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1; this.show = false; this.note = TG('从 🚩 开始，按刚才的路线点下去');
    }, PREVIEW);
  }
  private tap(i: number): void {
    if (this.over || this.show) { return; }
    if (i === this.path[this.traced.length]) {
      const t: number[] = this.traced.slice();
      t.push(i);
      this.traced = t;
      if (t.length < this.path.length) { this.note = TG2('继续 · {0}/{1}', String(t.length), String(LEN)); return; }
      if (this.round + 1 >= this.diffTotal) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
 TG2("✅ 第 {0} 条描完",Digits(String(this.round), this.langCode)); this.note = TG2('✅ 第 {0} 条描完',Digits(String(this.round), this.langCode));
      this.newPath();
      return;
    }
    this.err++;
    this.traced = [this.path[0]];
    if (this.err >= MAX_ERR) { this.note = TG2('断线 {0} 次',Digits(String(MAX_ERR), this.langCode)); this.finish(false); return; }
    this.note = TG2('❌ 断线了，从 🚩 重来 · 失误 {0}/{1}', String(this.err), String(MAX_ERR));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.show = false;
    this.clearTimer();
    const r: GameResult = {
      gameId: 'trace_path', solved: solved,
      score: solved ? Math.max(60, 300 - this.err * 50) : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.round + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private cellColor(i: number): string {
    if (this.traced.indexOf(i) >= 0) { return this.over && !this.won ? Palette.rose : Palette.primary; }
    return this.show && this.path.indexOf(i) >= 0 ? Palette.cyan : this.theme.surface;
  }
  private mark(i: number): string {
    if (this.path.length === 0) { return ''; }
    if (i === this.path[0]) { return '🚩'; }
    return i === this.path[this.path.length - 1] ? '🏁' : '';
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG2('路线 {0}/{1}', String(Math.min(this.round + 1, this.diffTotal)), String(this.diffTotal)) +
        TG2(' · 已描 {0}/{1}', String(this.traced.length), String(LEN)) +
        TG2(' · 失误 {0}/{1}', String(this.err), String(MAX_ERR)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Column({ space: Space.xs }) {
        ForEach(RX, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(RX, (c: number) => {
              this.cell(r * M + c)
            }, (c: number) => 'gc' + c)
          }
          .width('100%')
        }, (r: number) => 'gr' + r)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  cell(i: number) {
    Stack() {
      Text(this.mark(i)).fontSize(FontSize.md)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.cellColor(i)).borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
