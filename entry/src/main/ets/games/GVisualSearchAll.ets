/** 视觉搜索进阶 📐（id: visual_search_all）
 * 把满屏相似水果里的每一个 🍎 都点掉，点错扣 2 秒；每过一轮目标更多、时间重置；
 * 3 轮全找完 ⇒ 通关，任一环节超时 ⇒ 失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
const N: number = 6;
const TOTAL: number = N * N;
const ROWS: number[] = [0, 1, 2, 3, 4, 5];
const ROUNDS: number = 3;
const SECS: number = 22;
const TARGET: string = '🍎';
const DECOY: string[] = ['🍒', '🍅'];
@Component
export struct GVisualSearchAll {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State cells: string[] = [];
  @State isTarget: boolean[] = [];
  @State found: boolean[] = [];
  @State round: number = 0;
  @State left: number = SECS;
  @State score: number = 0;
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
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.clearTimer();
    this.round = 0; this.score = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.setup();
  }
  private need(): number { return 3 + this.round; }
  private setup(): void {
    const at: number[] = [];
    const n: number = this.need();
    while (at.length < n) {
      const i: number = Math.floor(Math.random() * TOTAL);
      if (at.indexOf(i) < 0) { at.push(i); }
    }
    const cs: string[] = [];
    const tg: boolean[] = [];
    const fd: boolean[] = [];
    for (let i = 0; i < TOTAL; i++) {
      const hit: boolean = at.indexOf(i) >= 0;
      tg.push(hit); fd.push(false);
      cs.push(hit ? TARGET : DECOY[Math.floor(Math.random() * DECOY.length)]);
    }
    this.cells = cs; this.isTarget = tg; this.found = fd; this.left = SECS;
    this.note = TG2('把 {0} 全点掉 · 点错扣 2 秒', TARGET);
    this.clearTimer();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.over) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) { this.note = TG('时间到'); this.finish(false); }
    }, 1000);
  }
  private foundCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.found.length; i++) { if (this.found[i]) { n++; } }
    return n;
  }
  private tap(i: number): void {
    if (this.over || this.found[i]) { return; }
    if (!this.isTarget[i]) {
      this.left = Math.max(1, this.left - 2);
      this.note = TG('❌ 点错了，扣 2 秒');
      return;
    }
    const fd: boolean[] = this.found.slice();
    fd[i] = true;
    this.found = fd;
    const got: number = this.foundCount();
    if (got < this.need()) { this.note = '✅ ' + String(got) + '/' + String(this.need()); return; }
    this.score += 60 + this.left * 3;
    if (this.round + 1 >= this.diffTotal) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    this.round++;
    this.setup();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved;
    this.clearTimer();
    if (solved) { this.score += this.left * 2; }
    const r: GameResult = {
      gameId: 'visual_search_all', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG('第 ') + String(Math.min(this.round + 1, this.diffTotal)) + '/' + String(this.diffTotal) + ' 轮 · 找到 ' +
        String(this.foundCount()) + '/' + String(this.need()) +
        TG2(' · 剩余 {0}', String(Math.max(this.left, 0))) + TG2('s · 得分 {0}',Digits(String(this.score), this.langCode)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Column({ space: Space.xs }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(ROWS, (c: number) => {
              this.cell(r * N + c)
            }, (c: number) => 'vc' + c)
          }
          .width('100%')
        }, (r: number) => 'vr' + r)
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
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  cell(i: number) {
    Stack() {
      Text(this.cells.length > i ? this.cells[i] : '').fontSize(FontSize.lg)
        .opacity(this.found.length > i && this.found[i] ? 0.35 : 1)
    }
    .layoutWeight(1).aspectRatio(1).borderRadius(Radius.sm)
    .backgroundColor(this.found.length > i && this.found[i] ? Palette.emerald : this.theme.surface)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { this.tap(i); })
  }
}
