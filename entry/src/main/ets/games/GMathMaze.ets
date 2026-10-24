/**
 * 数学迷宫（Math Maze）—— 5×5 🌀
 *
 * 规则：从左上角出发走到右下角 🏁，只能上下左右走、且不能走回头路；
 *       走过的格子的数字全部累加，**总路径和必须恰好等于目标数**。
 * 胜负：到达终点时和正好等于目标 ⇒ 通关；中途超出目标 / 步数用尽 / 到达终点时不等 ⇒ 失败。
 * 出题：先随机开一条通路，把通路上的数字之和当目标 ⇒ 保证一定有解。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，
//   而数组原来按 CELLS = 25 开 ⇒【困难档必越界】✗）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const GOAL: number = CELLS - 1;
const MAX_PATH: number = 13;
const MAX_STEPS: number = 20;
const NODE_CAP: number = 20000;

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
export struct GMathMaze {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 渲染原本用 ForEach(this.rows)，已改成 ForEach(this.rowIdx())
  @State private diffTotal: number = GameDiff.sizeNow(5);

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = new Array<number>(MAX_CELLS).fill(0);
  @State private target: number = 0;
  @State private trail: number[] = [0];
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG(TG(TG('点相邻格子往前走，和要刚好等于目标')));

  private startAt: number = 0;
  private finished: boolean = false;
  private nodes: number = 0;
  private rows: number[] = range(this.diffTotal);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
    this.reset();
  }

  private rowOf(i: number): number {
    return Math.floor(i / this.diffTotal);
  }

  private colOf(i: number): number {
    return i % this.diffTotal;
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

  // ── 出题：随机自避通路 (0,0) → (4,4) ──

  private walk(path: number[], used: boolean[]): boolean {
    this.nodes++;
    if (this.nodes > NODE_CAP) {
      return false;
    }
    const cur: number = path[path.length - 1];
    if (cur === GOAL) {
      return true;
    }
    if (path.length >= MAX_PATH) {
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
      if (this.walk(path, used)) {
        return true;
      }
      path.pop();
      used[nx] = false;
    }
    return false;
  }

  /** 兜底：4 个「右」+ 4 个「下」随机排列 ⇒ 单调阶梯路，必然合法 */
  private staircase(): number[] {
    const moves: number[] = [];
    for (let i = 0; i < this.diffTotal - 1; i++) {
      moves.push(1);   // 右
      moves.push(2);   // 下
    }
    for (let i = moves.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = moves[i];
      moves[i] = moves[j];
      moves[j] = t;
    }
    const path: number[] = [0];
    let r: number = 0;
    let c: number = 0;
    for (let i = 0; i < moves.length; i++) {
      if (moves[i] === 1) {
        c++;
      } else {
        r++;
      }
      path.push(r * this.diffTotal + c);
    }
    return path;
  }

  private genPath(): number[] {
    for (let attempt = 0; attempt < 200; attempt++) {
      const path: number[] = [0];
      const used: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
      used[0] = true;
      this.nodes = 0;
      if (this.walk(path, used)) {
        return path;
      }
    }
    return this.staircase();
  }

  private reset(): void {
    const path: number[] = this.genPath();
    const vals: number[] = new Array<number>(MAX_CELLS).fill(0);
    let sum: number = 0;
    for (let i = 0; i < path.length; i++) {
      vals[path[i]] = 1 + Math.floor(Math.random() * 9);
      sum += vals[path[i]];
    }
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (vals[i] === 0) {
        vals[i] = 1 + Math.floor(Math.random() * 9);
      }
    }
    this.vals = vals;
    this.target = sum;
    this.trail = [0];
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG(TG(TG('点相邻格子往前走，和要刚好等于目标')));
    this.startAt = Date.now();
  }

  // ── 状态 ──

  private sumNow(): number {
    let s: number = 0;
    for (let i = 0; i < this.trail.length; i++) {
      s += this.vals[this.trail[i]];
    }
    return s;
  }

  /**
   * ★ 2026-10-23 第二期：数学迷宫提示（真求解器）
   *
   * 规则：从左上走到右下，不能回头；路径上的数字之和必须等于目标。
   * ⇒ DFS：从当前格出发，维护"已访问 + 当前和"，超过目标就剪枝，
   *        走到右下且和相等就成功。
   * ⇒ 提示**只报下一步走哪一格**（报整条路径玩家也用不上，因为格子会变）。
   */
  private dfsSum(cur: number, sum: number, visited: boolean[], out: number): boolean {
    if (cur === GOAL) {
      return sum === this.target;
    }
    const ns: number[] = this.nbrs(cur);
    for (let t = 0; t < ns.length; t++) {
      const nx: number = ns[t];
      if (visited[nx]) {
        continue;
      }
      const nsum: number = sum + this.vals[nx];
      if (nsum > this.target) {
        continue;                      // 剪枝：和只会越来越大（值都 ≥1）
      }
      visited[nx] = true;
      if (this.dfsSum(nx, nsum, visited, out)) {
        if (out < 0) {
          // 记下"第一步"：回溯到最外层时才知道，所以用返回值链传递
        }
        visited[nx] = false;
        return true;
      }
      visited[nx] = false;
    }
    return false;
  }

  private findNext(): number {
    const start: number = this.trail[this.trail.length - 1];
    if (start === GOAL) {
      return -1;
    }
    const visited: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
    for (let i = 0; i < this.trail.length; i++) {
      visited[this.trail[i]] = true;
    }
    let sum: number = this.sumNow();
    const ns: number[] = this.nbrs(start);
    for (let t = 0; t < ns.length; t++) {
      const nx: number = ns[t];
      if (visited[nx]) {
        continue;
      }
      const nsum: number = sum + this.vals[nx];
      if (nsum > this.target) {
        continue;
      }
      const v2: boolean[] = visited.slice();
      v2[nx] = true;
      if (this.dfsSum(nx, nsum, v2, -1)) {
        return nx;
      }
    }
    return -1;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const nx: number = this.findNext();
    if (nx < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(nx / this.diffTotal) + 1;
    const c: number = (nx % this.diffTotal) + 1;
    const add: number = this.vals[nx];
    const sum: number = this.sumNow() + add;
    return Hint.make([nx],
      TG4('走第 {0} 行第 {1} 列（+{2}，累计 {3}）', String(r), String(c), String(add), String(sum)),
      TG4('Step to row {0}, column {1} (+{2}, total {3})', String(r), String(c), String(add), String(sum)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private steps(): number {
    return this.trail.length - 1;
  }

  private stuck(): boolean {
    const cur: number = this.trail[this.trail.length - 1];
    const ns: number[] = this.nbrs(cur);
    for (let k = 0; k < ns.length; k++) {
      if (this.trail.indexOf(ns[k]) < 0) {
        return false;
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const diff: number = Math.abs(this.target - this.sumNow());
    const r: GameResult = {
      gameId: 'math_maze',
      solved: solved,
      score: solved ? Math.max(150, 1200 - this.steps() * 40) : Math.max(0, 300 - diff * 10),
      durationMs: Date.now() - this.startAt,
      levelReached: this.steps()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private lose(why: string): void {
    if (this.finished) {
      return;
    }
    this.over = true;
    this.tip = why;
    this.finish(false);
  }

  private step(to: number): void {
    if (this.over) {
      return;
    }
    const cur: number = this.trail[this.trail.length - 1];
    if (this.trail.indexOf(to) >= 0 || this.nbrs(cur).indexOf(to) < 0) {
      this.tip = TG(TG(TG('只能走到相邻的、没走过的格子')));
      return;
    }
    const nt: number[] = this.trail.slice();
    nt.push(to);
    this.trail = nt;
    const s: number = this.sumNow();
    if (to === GOAL) {
      if (s === this.target) {
        this.over = true;
        this.won = true;
        this.tip = '🎉 刚好 ' + String(this.target) + TG('，通关！');
        this.finish(true);
      } else {
        this.lose(TG2('到达终点时是 {0}，不等于目标 {1}', String(s), String(this.target)));
      }
      return;
    }
    if (s > this.target) {
      this.lose(TG2('和已到 {0}，超出目标 {1}', String(s), String(this.target)));
      return;
    }
    if (this.steps() >= MAX_STEPS) {
      this.lose(TG('步数用尽，重开一题吧'));
      return;
    }
    if (this.stuck()) {
      this.lose(TG(TG('走进死胡同，没有能走的格子了')));
      return;
    }
    this.tip = TG2('当前和 {0} · 还差 {1}', String(s), String(this.target - s));
  }

  private undo(): void {
    if (this.over || this.trail.length <= 1) {
      return;
    }
    const nt: number[] = this.trail.slice();
    nt.pop();
    this.trail = nt;
    this.tip = TG2('退回一格，当前和 {0}', String(this.sumNow()));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.target), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('当前和')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.sumNow()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('还差')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.target - this.sumNow()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Column({ space: 1 }) {
              Text(String(this.vals[(r * this.diffTotal + c)]))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              Text((r * this.diffTotal + c) === GOAL ? '🏁' : (this.trail.length > 0 && (r * this.diffTotal + c) === this.trail[0] ? '起' : ''))
              .fontSize(FontSize.xxs)
              .fontColor(this.theme.inkFaint)
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.trail.length > 0 && (r * this.diffTotal + c) === this.trail[this.trail.length - 1]
              ? '#336366F1'
              : (this.trail.indexOf((r * this.diffTotal + c)) >= 0 ? '#2210B981' : this.theme.surface))
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.step((r * this.diffTotal + c));
              })
            }, (c: number) => 'xc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'xr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(TG('退一步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.undo();
          })
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.orange)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG2("步数 {0}/{1} · 从左上角走到右下角 🏁，和要刚好等于目标", String(this.steps()),Digits(String(MAX_STEPS), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
