/**
 * 麻将连连看 —— 配对消牌 🀄
 *
 * 规则：4×4 共 16 张牌（萬/筒 各 1~4 各两张）。点两张相同的牌，
 *      若能用不超过两个拐弯、且只经过空格的路连起来，就能消掉。
 * 胜负：全部消完 = 通关；重排多次仍无解 = 失败
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const R: number = 4;
const C: number = 4;
const PR: number = R + 2;   // 外圈留空，方便绕行
const PC: number = C + 2;
const KINDS: number = 8;

const LABELS: string[] = ['1萬', '2萬', '3萬', '4萬', '1筒', '2筒', '3筒', '4筒'];

function labelColor(t: number): string {
  return t < 4 ? Palette.rose : Palette.sky;
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

@Component
export struct GMahjongSolitaire {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 KINDS=8
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(8);
  onFinish: (r: GameResult) => void = () => {};

  @State private grid: number[] = [];
  @State private sel: number = -1;
  @State private left: number = R * C;
  @State private moves: number = 0;
  @State private hints: number = 0;
  @State private hintA: number = -1;
  @State private hintB: number = -1;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMahjongSolitaire')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
    this.reset();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over) {
      return true;
    }
    this.aiPair(0);
    return !this.over;
  }

  /** 提示：哪两张牌能连 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const p: number[] = this.findPair();
    if (p.length < 2) { return Hint.none('none'); }
    const lab: string = LABELS[this.grid[p[0]]];
    const a1: string = String(Math.floor(p[0] / PC)) + TG(' 行 ') + String(p[0] % PC) + TG(' 列');
    const b1: string = String(Math.floor(p[1] / PC)) + TG(' 行 ') + String(p[1] % PC) + TG(' 列');
    return Hint.make(p, TG2('两张「{0}」能连：{1} 与 {2}', lab, a1, b1),
      TG2('Two "{0}" tiles link: {1} and {2}', lab, a1, b1), t0);
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
    // ★★ 2026-10-13 真机 BUG 修复（奥森报「麻将连连看不显示」）：
    //   棋盘固定 R×C = 16 格，但 `diffTotal` 会被**难度**改大（困难档 > 8）
    //   ⇒ tiles.length = diffTotal*2 > 16 ⇒ 多出来的牌写到第 5 行（渲染范围外）⇒ 凭空消失
    //   ⇒ 同时 left 原来写死 R*C=16，牌却装不满 ⇒ 永远消不完 ⇒ 死局
    //   修法：① 对数夹到棋盘能装下的上限 ② left 跟着【实际对数】走
    const maxPairs: number = Math.floor(R * C / 2);          // 4×4 ⇒ 最多 8 对
    const pairs: number = Math.min(this.diffTotal, maxPairs);
    const tiles: number[] = [];
    for (let t = 0; t < pairs; t++) {
      tiles.push(t % KINDS);      // 超出 KINDS 时循环取，避免 LABELS 越界
      tiles.push(t % KINDS);
    }
    shuffleArr(tiles);
    const g: number[] = new Array<number>(PR * PC).fill(-1);
    for (let i = 0; i < tiles.length; i++) {
      const r: number = Math.floor(i / C) + 1;
      const c: number = (i % C) + 1;
      g[r * PC + c] = tiles[i];
    }
    this.grid = g;
    this.sel = -1;
    this.left = tiles.length;   // ★ 跟着实际牌数（原来是写死的 R*C）
    this.moves = 0;
    this.hints = 0;
    this.hintA = -1;
    this.hintB = -1;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
    // 开局就无解（极罕见）时自动重排
    if (this.findPair().length === 0) {
      this.shuffleLeft();
    }
  }

  // ── 连通判定 ──

  private free(r: number, c: number): boolean {
    return this.grid[r * PC + c] < 0;
  }

  private clearH(r: number, c1: number, c2: number): boolean {
    const lo: number = Math.min(c1, c2) + 1;
    const hi: number = Math.max(c1, c2);
    for (let c = lo; c < hi; c++) {
      if (!this.free(r, c)) {
        return false;
      }
    }
    return true;
  }

  private clearV(c: number, r1: number, r2: number): boolean {
    const lo: number = Math.min(r1, r2) + 1;
    const hi: number = Math.max(r1, r2);
    for (let r = lo; r < hi; r++) {
      if (!this.free(r, c)) {
        return false;
      }
    }
    return true;
  }

  private direct(r1: number, c1: number, r2: number, c2: number): boolean {
    if (r1 === r2) {
      return this.clearH(r1, c1, c2);
    }
    if (c1 === c2) {
      return this.clearV(c1, r1, r2);
    }
    return false;
  }

  private oneTurn(r1: number, c1: number, r2: number, c2: number): boolean {
    if (this.free(r1, c2) && this.clearH(r1, c1, c2) && this.clearV(c2, r1, r2)) {
      return true;
    }
    if (this.free(r2, c1) && this.clearV(c1, r1, r2) && this.clearH(r2, c1, c2)) {
      return true;
    }
    return false;
  }

  private linkable(r1: number, c1: number, r2: number, c2: number): boolean {
    const a: number = this.grid[r1 * PC + c1];
    if (a < 0 || a !== this.grid[r2 * PC + c2]) {
      return false;
    }
    if (r1 === r2 && c1 === c2) {
      return false;
    }
    if (this.direct(r1, c1, r2, c2) || this.oneTurn(r1, c1, r2, c2)) {
      return true;
    }
    for (let c = 0; c < PC; c++) {
      if (c === c1 || !this.free(r1, c) || !this.clearH(r1, c1, c)) {
        continue;
      }
      if (this.direct(r1, c, r2, c2) || this.oneTurn(r1, c, r2, c2)) {
        return true;
      }
    }
    for (let r = 0; r < PR; r++) {
      if (r === r1 || !this.free(r, c1) || !this.clearV(c1, r1, r)) {
        continue;
      }
      if (this.direct(r, c1, r2, c2) || this.oneTurn(r, c1, r2, c2)) {
        return true;
      }
    }
    return false;
  }

  /** 找一对可消的牌，返回 [i, j]（下标是含外圈的） */
  private findPair(): number[] {
    for (let i = 0; i < this.grid.length; i++) {
      if (this.grid[i] < 0) {
        continue;
      }
      for (let j = i + 1; j < this.grid.length; j++) {
        if (this.grid[j] !== this.grid[i]) {
          continue;
        }
        if (this.linkable(Math.floor(i / PC), i % PC, Math.floor(j / PC), j % PC)) {
          const out: number[] = [i, j];
          return out;
        }
      }
    }
    return [];
  }

  private removedPairs(): number {
    return (R * C - this.left) / 2;
  }

  // ── 操作 ──

  private tap(i: number): void {
    if (this.over || this.grid[i] < 0) {
      return;
    }
    if (this.sel === -1) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    const ok: boolean = this.linkable(Math.floor(this.sel / PC), this.sel % PC,
      Math.floor(i / PC), i % PC);
    if (!ok) {
      this.sel = i;
      return;
    }
    const g: number[] = this.grid.slice();
    g[this.sel] = -1;
    g[i] = -1;
    this.grid = g;
    this.left = this.left - 2;
    this.moves = this.moves + 1;
    this.sel = -1;
    this.hintA = -1;
    this.hintB = -1;
    if (this.left === 0) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.findPair().length === 0) {
      this.shuffleLeft();
    }
  }

  /** 剩余牌重排，最多试 5 次；还是无解就判负 */
  private shuffleLeft(): void {
    for (let attempt = 0; attempt < 5; attempt++) {
      const pos: number[] = [];
      const vals: number[] = [];
      for (let i = 0; i < this.grid.length; i++) {
        if (this.grid[i] >= 0) {
          pos.push(i);
          vals.push(this.grid[i]);
        }
      }
      shuffleArr(vals);
      const g: number[] = this.grid.slice();
      for (let k = 0; k < pos.length; k++) {
        g[pos[k]] = vals[k];
      }
      this.grid = g;
      this.sel = -1;
      this.hintA = -1;
      this.hintB = -1;
      if (this.findPair().length > 0) {
        return;
      }
    }
    this.over = true;
    this.finish(false);
  }

  private useHint(): void {
    if (this.over) {
      return;
    }
    const p: number[] = this.findPair();
    if (p.length === 0) {
      return;
    }
    this.hints = this.hints + 1;
    this.hintA = p[0];
    this.hintB = p[1];
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mahjong_solitaire',
      solved: solved,
      score: solved ? Math.max(200, 1000 - this.moves * 10 - this.hints * 30) : this.removedPairs() * 80,
      durationMs: Date.now() - this.startAt,
      levelReached: this.removedPairs()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tileBg(i: number): string {
    if (this.sel === i) {
      return '#226366F1';
    }
    if (this.hintA === i || this.hintB === i) {
      return '#33F59E0B';
    }
    return this.theme.surface;
  }

  /** AI 用：先取消悬着的选中，再消掉 findPair 找到的那一对 */
  private aiPair(_d: number): void {
    if (this.sel >= 0) { this.tap(this.sel); }
    const p: number[] = this.findPair();
    if (p.length < 2) { this.shuffleLeft(); return; }
    this.tap(p[0]);
    this.tap(p[1]);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        this.head(TG('剩余'), 0)
        this.head(TG('步数'), 1)
        this.head(TG('提示'), 2)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach([1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([1, 2, 3, 4], (c: number) => {
              // ★ 内联，不用 @Builder —— Builder 的参数不建立 ArkUI 观察，
              //   牌被消掉后**不会重绘**（真机实测：牌面整片消失，但"剩余"不变）
              Stack() {
                Text(this.grid[r * PC + c] < 0 ? '' : LABELS[this.grid[r * PC + c]])
                  .fontSize(FontSize.md)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.grid[r * PC + c] < 0 ? this.theme.inkFaint : labelColor(this.grid[r * PC + c]))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.grid[r * PC + c] < 0 ? '#00000000' : this.tileBg(r * PC + c))
              .borderRadius(Radius.sm)
              .border({
                width: 1,
                color: this.grid[r * PC + c] < 0 ? '#00000000' : (this.sel === r * PC + c ? Palette.primary : this.theme.line)
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(r * PC + c); }); })
              .onClick(() => {
                Haptics.tick();
                this.tap(r * PC + c);
              })
            }, (c: number) => 't' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'row' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '70%' })
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.over ? (this.won ? '🎉 全部消完，通关！' : '无解了…重开一局') :
        (this.sel === -1 ? '点第一张牌，再点能和它连起来的同款牌' : '已选中，找它的搭档'))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('提示'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.useHint(); }); })
          .onClick(() => {
            Haptics.tap();
            this.useHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.rose).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }

  /**
   * 状态格
   * ★ 收「种类」不收「算好的字符串」—— `@Builder` 的参数**不建立 ArkUI 观察**，
   *   传算好的串时值变了界面不刷新（真机实测：剩余对数卡住不动）
   */
  @Builder
  head(label: string, kind: number) {
    Column({ space: 2 }) {
      Text(label).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? (String(this.left / 2) + ' 对')
        : (kind === 1 ? String(this.moves) : String(this.hints)))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1).padding(Space.sm)
    .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
  }

  @Builder
  tileBox(i: number) {
    Stack() {
      Text(this.grid[i] < 0 ? '' : LABELS[this.grid[i]])
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.grid[i] < 0 ? this.theme.inkFaint : labelColor(this.grid[i]))
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.grid[i] < 0 ? '#00000000' : this.tileBg(i))
    .borderRadius(Radius.sm)
    .border({
      width: 1,
      color: this.grid[i] < 0 ? '#00000000' : (this.sel === i ? Palette.primary : this.theme.line)
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
    .onClick(() => {
      Haptics.tick();
      this.tap(i);
    })
  }
}
