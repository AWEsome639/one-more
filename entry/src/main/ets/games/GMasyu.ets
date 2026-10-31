/**
 * 数回（Masyu）—— 5×5 ➰
 *
 * 规则（简化口径，注释里写明，免得玩家困惑）：
 *   · 用一条「不交叉、不自交」的闭合回路穿过所有圆圈；
 *   · ⚫ 黑圈处必须拐弯（前后两格在自己的垂直方向）；
 *   · ⚪ 白圈处必须直行（前后两格在自己的同一直线上）。
 * 玩法：依次点相邻格子铺回路，点回起点 = 闭合；可「退一步」。
 * 胜负：回路闭合 且 所有圆圈规则都满足 ⇒ 通关；步数用尽 ⇒ 失败。
 * 出题：随机找一条简单回路，再从路上挑「拐弯点」当黑圈、「直行点」当白圈。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，
//   而数组原来按 CELLS = 25 开 ⇒【困难档必越界】✗）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const MIN_LOOP: number = 8;
const MAX_LOOP: number = 14;
const MAX_TAPS: number = 40;
const NODE_CAP: number = 30000;
const BLACK_N: number = 2;
const WHITE_N: number = 2;
/** 兜底回路：5×5 最外圈 */
const RING: number[] = [0, 1, 2, 3, 4, 9, 14, 19, 24, 23, 22, 21, 20, 15, 10, 5];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

function shuffled(n: number): number[] {
  const a: number[] = range(n);
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GMasyu {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 渲染原本用 ForEach(this.rows)，已改成 ForEach(this.rowIdx())
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」第 21 个：
   *   候选环路来自 RING —— 固定 5×5 边框的 16 个格子（手工写的）。
   *   但原来 diffTotal = sizeNow(5)（4/5/7），棋盘按 diffTotal² 渲染：
   *     · 简单 4×4：RING 里 index 最大到 24，超出 16 格范围 ⇒ 越界
   *     · 困难 7×7：RING 只覆盖中间 5×5 的边框，位置全错
   *   ⇒ 修法：棋盘固定 5×5，难度改到**点击次数上限**上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = 5;
  /** 本局允许的点击次数：简单 56 / 普通 40 / 困难 28 */
  @State private tapCap: number = GMasyu.capNow();

  private static capNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 56;
    }
    if (d === 2) {
      return 28;
    }
    return 40;
  }

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private path: number[] = [];
  @State private black: number[] = [];
  @State private white: number[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('依次点相邻格子铺回路，点回起点即闭合');

  /** ★ 出题时那条回路 = 本题答案（AI 代打/提示照它铺） */
  private sol: number[] = [];
  private startAt: number = 0;
  private finished: boolean = false;
  private nodes: number = 0;
  private rows: number[] = range(this.diffTotal);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMasyu')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.tapCap = GMasyu.capNow();
    this.reset();
  }

  private rowOf(i: number): number {
    return Math.floor(i / this.diffTotal);
  }

  private colOf(i: number): number {
    return i % this.diffTotal;
  }

  private adj(a: number, b: number): boolean {
    const dr: number = Math.abs(this.rowOf(a) - this.rowOf(b));
    const dc: number = Math.abs(this.colOf(a) - this.colOf(b));
    return dr + dc === 1;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.rowOf(i);
    const c: number = this.colOf(i);
    if (r > 0) {
      out.push(i - this.diffTotal);
    }
    if (r < this.diffTotal - 1) {
      out.push(i + this.diffTotal);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < this.diffTotal - 1) {
      out.push(i + 1);
    }
    return out;
  }

  /** 前后两格在过 c 的同一横/竖线上 ⇒ c 处是直行，否则拐弯 */
  private straight(c: number, prev: number, next: number): boolean {
    if (prev === c || next === c) {
      return false;
    }
    const sameRow: boolean = this.rowOf(prev) === this.rowOf(c) && this.rowOf(next) === this.rowOf(c);
    const sameCol: boolean = this.colOf(prev) === this.colOf(c) && this.colOf(next) === this.colOf(c);
    return sameRow || sameCol;
  }

  // ── 出题 ──

  private grow(path: number[], used: boolean[], start: number): boolean {
    this.nodes++;
    if (this.nodes > NODE_CAP) {
      return false;
    }
    const cur: number = path[path.length - 1];
    if (path.length >= MIN_LOOP && this.adj(cur, start)) {
      return true;
    }
    if (path.length >= MAX_LOOP) {
      return false;
    }
    const ns: number[] = this.nbrs(cur);
    const perm: number[] = shuffled(ns.length);
    for (let t = 0; t < perm.length; t++) {
      const nx: number = ns[perm[t]];
      if (used[nx]) {
        continue;
      }
      used[nx] = true;
      path.push(nx);
      if (this.grow(path, used, start)) {
        return true;
      }
      path.pop();
      used[nx] = false;
    }
    return false;
  }

  private findLoop(): number[] {
    for (let attempt = 0; attempt < 300; attempt++) {
      const start: number = Math.floor(Math.random() * CELLS);
      const path: number[] = [start];
      const used: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
      used[start] = true;
      this.nodes = 0;
      if (this.grow(path, used, start) && path.length >= MIN_LOOP) {
        return path;
      }
    }
    return RING;
  }

  private makeCircles(loop: number[]): void {
    const turns: number[] = [];
    const lines: number[] = [];
    for (let k = 0; k < loop.length; k++) {
      const prev: number = loop[(k - 1 + loop.length) % loop.length];
      const next: number = loop[(k + 1) % loop.length];
      if (this.straight(loop[k], prev, next)) {
        lines.push(loop[k]);
      } else {
        turns.push(loop[k]);
      }
    }
    const bt: number[] = shuffled(turns.length);
    const wt: number[] = shuffled(lines.length);
    const bs: number[] = [];
    const ws: number[] = [];
    for (let k = 0; k < bt.length && bs.length < BLACK_N; k++) {
      bs.push(turns[bt[k]]);
    }
    for (let k = 0; k < wt.length && ws.length < WHITE_N; k++) {
      ws.push(lines[wt[k]]);
    }
    this.black = bs;
    this.white = ws;
  }

  private reset(): void {
    const loop: number[] = this.findLoop();
    this.sol = loop;
    this.makeCircles(loop);
    this.path = [];
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('依次点相邻格子铺回路，点回起点即闭合');
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private circlesOnPath(): number {
    let n: number = 0;
    for (let k = 0; k < this.black.length; k++) {
      if (this.path.indexOf(this.black[k]) >= 0) {
        n++;
      }
    }
    for (let k = 0; k < this.white.length; k++) {
      if (this.path.indexOf(this.white[k]) >= 0) {
        n++;
      }
    }
    return n;
  }

  private badCircles(): number {
    const len: number = this.path.length;
    let bad: number = 0;
    for (let k = 0; k < len; k++) {
      const c: number = this.path[k];
      const prev: number = this.path[(k - 1 + len) % len];
      const next: number = this.path[(k + 1) % len];
      const isBlack: boolean = this.black.indexOf(c) >= 0;
      const isWhite: boolean = this.white.indexOf(c) >= 0;
      if (isBlack && this.straight(c, prev, next)) {
        bad++;
      }
      if (isWhite && !this.straight(c, prev, next)) {
        bad++;
      }
    }
    for (let k = 0; k < this.black.length; k++) {
      if (this.path.indexOf(this.black[k]) < 0) {
        bad++;
      }
    }
    for (let k = 0; k < this.white.length; k++) {
      if (this.path.indexOf(this.white[k]) < 0) {
        bad++;
      }
    }
    return bad;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'masyu',
      solved: solved,
      score: solved ? Math.max(200, 1200 - this.moves * 20) : this.circlesOnPath() * 80,
      durationMs: Date.now() - this.startAt,
      levelReached: this.circlesOnPath()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private lose(): void {
    if (this.finished) {
      return;
    }
    this.over = true;
    this.tip = TG('步数用尽，重开一题吧');
    this.finish(false);
  }

  // ── 输入 ──

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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
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
    if (this.over || this.autoCell() < 0) {
      return true;
    }
    this.tap(this.autoCell());
    return !this.over;
  }

  // 通关 = 回路闭合 + 所有圆圈规则都满足 ⇒ 报出题时那条回路的下一个格子
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.autoCell();
    if (i < 0) {
      return Hint.none('none');
    }
    const n: number = this.diffTotal;
    const what: string = this.path.length < this.sol.length ? '下一格点 ' : '点回起点闭合（';
    const tail: string = this.path.length < this.sol.length ? '' : String(this.sol.length) + ' 格）';
    return Hint.make([i], what + '第' + String(Math.floor(i / n) + 1) + '行第' + String(i % n + 1) + '列' + tail,
      'Tap row ' + String(Math.floor(i / n) + 1) + ', column ' + String(i % n + 1), t0);
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

    /** 代打/提示共用：下一步该点的格子（本题答案 = 出题时那条回路） */
    private autoCell(): number {
      if (this.sol.length === 0) {
        return -1;
      }
      const k: number = this.path.length;
      if (k > this.sol.length) {
        return -1;
      }
      for (let i = 0; i < k; i++) {
        if (this.path[i] !== this.sol[i]) {
          return -1;
        }
      }
      if (k < this.sol.length) {
        return this.sol[k];
      }
      return this.sol[0];
    }
  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.path.length === 0) {
      this.path = [i];
      this.moves++;
      this.tip = TG('起点已定，继续点相邻格子');
      return;
    }
    if (this.path.length > 1 && i === this.path[0]) {
      this.tryClose();
      return;
    }
    if (this.path.indexOf(i) >= 0) {
      this.tip = TG('这一格已经在回路上了');
      return;
    }
    const last: number = this.path[this.path.length - 1];
    if (!this.adj(last, i)) {
      this.tip = TG('只能接到上一格的上下左右');
      return;
    }
    const np: number[] = this.path.slice();
    np.push(i);
    this.path = np;
    this.moves++;
    if (this.moves >= this.tapCap) {
      this.lose();
      return;
    }
    this.tip = TG2('回路 {0} 格 · 圈 {1}/{2}', String(this.path.length), String(this.circlesOnPath()), String(this.black.length + this.white.length));
  }

  private tryClose(): void {
    const len: number = this.path.length;
    if (len < MIN_LOOP) {
      this.tip = TG2("太短了，回路至少要 {0} 格", String(MIN_LOOP));
      return;
    }
    if (!this.adj(this.path[len - 1], this.path[0])) {
      this.tip = TG('首尾不相邻，接不上');
      return;
    }
    const bad: number = this.badCircles();
    if (bad > 0) {
      this.tip = TG2('还有 {0} 处圈规则没满足', String(bad));
      return;
    }
    this.over = true;
    this.won = true;
    this.tip = TG('🎉 回路闭合、黑圈拐弯白圈直行，通关！');
    this.finish(true);
  }

  private undo(): void {
    if (this.over || this.path.length === 0) {
      return;
    }
    const np: number[] = this.path.slice();
    np.pop();
    this.path = np;
  }

  private clearAll(): void {
    if (this.over) {
      return;
    }
    this.path = [];
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
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.tapCap))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('回路'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.path.length) + TG(' 格'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text(('圈')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.circlesOnPath()) + '/' + String(this.black.length + this.white.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.black.indexOf((r * this.diffTotal + c)) >= 0 ? '⚫' : (this.white.indexOf((r * this.diffTotal + c)) >= 0 ? '⚪' : ''))
              .fontSize(FontSize.xl)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.path.indexOf((r * this.diffTotal + c)) >= 0 ? '#2210B981' : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({
              width: this.path.length > 0 && (r * this.diffTotal + c) === this.path[0] ? 2 : 1,
              color: this.path.length > 0 && (r * this.diffTotal + c) === this.path[0] ? Palette.emerald : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'yc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'yr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('退一步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.undo(); }); })
          .onClick(() => {
            Haptics.tap();
            this.undo();
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.clearAll(); }); })
          .onClick(() => {
            Haptics.tap();
            this.clearAll();
          })
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.lime)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('⚫ 必须拐弯 · ⚪ 必须直行 · 回路要闭合成一圈'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
