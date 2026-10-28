/**
 * 二进制（Takuzu / Binary Puzzle）—— 6×6 填 0 和 1
 *
 * 规则：
 *   · 每行每列 0 与 1 各 3 个
 *   · 任何一行/一列不能出现连续三个相同的数
 * 判据：36 格填满且三条规则都满足 ⇒ 通关；填满了但有冲突 ⇒ 失败（也可随时放弃）
 * 出题：随机回溯生成合法满盘，再逐格挖空并验证「解唯一」
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 6;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 8×8 = 64 格，
//   而数组原来按 CELLS = 36 开 ⇒【困难档必越界】✗）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N;
const HALF: number = N / 2;
const EMPTY: number = -1;
/**
 * 题给数的比例（不是固定个数）
 *
 * ★★★ 2026-10-23 修 bug：原来是 `const GIVENS = 18` 写死，
 *   但难度会改棋盘边长：
 *     简单 4×4 = 16 格，need = 16 - 18 = **-2**
 *       ⇒ 挖空循环第一行就 break ⇒ 一格都不挖
 *       ⇒ **满盘全是题给数，玩家什么都填不了（游戏不可玩）**
 *     困难 8×8 = 64 格，need = 46 ⇒ 只留 18 个数，偏狠
 *   ⇒ 改成按比例：50% 题给数。
 *     4×4 → 8 个，6×6 → 18 个（与原来的 18 完全一致），8×8 → 32 个。
 */
const GIVEN_RATIO: number = 0.5;
const TICK_MS: number = 1000;
const GAP: number = 2;
const KEY_H: number = 46;

interface Puzzle {
  quiz: number[];
  answer: number[];
}

function shuffled(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

/**
 * 一行（或一列）是否还没违规：连续三连 + 0/1 数量上限
 *
 * ★★★ 2026-10-23 修 bug：原来这里写死了模块常量 N（=6）与 HALF（=3），
 *   但难度会改棋盘边长（简单 4 / 普通 6 / 困难 8）：
 *     · 简单 4×4：循环读到 vals[4]、vals[5] 是 undefined ⇒ 计入 zeros
 *       ⇒ zeros 恒 > HALF ⇒ **lineOk 永远 false ⇒ 简单档根本不可能通关**
 *     · 困难 8×8：只看前 6 格，第 7、8 格完全不校验 ⇒ 通关判定漏判
 *   ⇒ 改成接受 size 参数。这个 bug 是难度改造留下的回归。
 */
function lineOk(vals: number[], n: number): boolean {
  let ones: number = 0;
  let zeros: number = 0;
  for (let i = 0; i < n; i++) {
    const v: number = vals[i];
    if (v === EMPTY) {
      continue;
    }
    if (v === 1) {
      ones++;
    } else {
      zeros++;
    }
    if (i >= 2) {
      const a: number = vals[i - 2];
      const b: number = vals[i - 1];
      const c: number = vals[i];
      if (a !== EMPTY && a === b && b === c) {
        return false;
      }
    }
  }
  const half: number = Math.floor(n / 2);
  return ones <= half && zeros <= half;
}

/** idx 处放 v 是否合法（不改动 grid） */
function fits(grid: number[], idx: number, v: number, n: number): boolean {
  const r: number = Math.floor(idx / n);
  const c: number = idx % n;
  const old: number = grid[idx];
  grid[idx] = v;
  const row: number[] = [];
  const col: number[] = [];
  for (let i = 0; i < n; i++) {
    row.push(grid[r * n + i]);
    col.push(grid[i * n + c]);
  }
  const ok: boolean = lineOk(row, n) && lineOk(col, n);
  grid[idx] = old;
  return ok;
}

function fill(grid: number[], pos: number, n: number): boolean {
  if (pos === n * n) {
    return true;
  }
  if (grid[pos] !== EMPTY) {
    return fill(grid, pos + 1, n);
  }
  const order: number[] = Math.random() < 0.5 ? [0, 1] : [1, 0];
  for (let k = 0; k < order.length; k++) {
    const v: number = order[k];
    if (fits(grid, pos, v, n)) {
      grid[pos] = v;
      if (fill(grid, pos + 1, n)) {
        return true;
      }
      grid[pos] = EMPTY;
    }
  }
  return false;
}

// ★★ 2026-10-13 修复循环上界：原来用 CELLS（固定 base²）
//   ⇒ 困难档棋盘更大 ⇒ 只检查了前 base² 格；简单档更小 ⇒ 检查到棋盘外
//   ⇒ 加 size 参数（= 实际棋盘边长）
function count(grid: number[], limit: number, size: number): number {
  let pos: number = -1;
  for (let i = 0; i < size * size; i++) {
    if (grid[i] === EMPTY) {
      pos = i;
      break;
    }
  }
  if (pos < 0) {
    return 1;
  }
  let total: number = 0;
  for (let v = 0; v <= 1; v++) {
    if (fits(grid, pos, v, size)) {
      grid[pos] = v;
      total = total + count(grid, limit - total, size);
      grid[pos] = EMPTY;
      if (total >= limit) {
        return total;
      }
    }
  }
  return total;
}

function makePuzzle(size: number): Puzzle {
  const answer: number[] = new Array<number>(MAX_CELLS).fill(EMPTY);
  fill(answer, 0, size);
  const quiz: number[] = answer.slice();
  const order: number[] = shuffled(size * size);
  let removed: number = 0;
  const total: number = size * size;
  // 题给数 = 总数的 50%（向下取整），保证至少挖掉一半
  const givens: number = Math.floor(total * GIVEN_RATIO);
  const need: number = total - givens;
  for (let k = 0; k < order.length; k++) {
    if (removed >= need) {
      break;
    }
    const p: number = order[k];
    const keep: number = quiz[p];
    quiz[p] = EMPTY;
    const probe: number[] = quiz.slice();
    if (count(probe, 2, size) !== 1) {
      quiz[p] = keep;
    } else {
      removed++;
    }
  }
  const out: Puzzle = { quiz: quiz, answer: answer };
  return out;
}

@Component
export struct GBinaryPuzzle {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  /** 出题时的完整解 */

  private solCells: number[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State */

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private cells: number[] = [];
  @State private fixed: boolean[] = [];
  @State private mistakes: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;
  /** ★ 第二期：提示说的话（空 = 没提示） */
  @State private hintMsg: string = '';
  /** 提示指向的格子（-1 = 无） */
  @State private hintIdx: number = -1;

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBinaryPuzzle')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    const p: Puzzle = makePuzzle(this.diffTotal);
    // ★ 2026-10-24 第三期：出题时就有完整解（p.answer），以前丢掉了
    this.solCells = p.answer.slice();
    const cells: number[] = p.quiz.slice();
    const fixed: boolean[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      fixed.push(cells[i] !== EMPTY);
    }
    this.cells = cells;
    this.fixed = fixed;
    this.mistakes = 0;
    this.seconds = 0;
    this.status = TG('点格子循环切换：空 → 0 → 1');
    this.done = false;
    this.finished = false;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.done && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private valAt(i: number): number {
    return i >= 0 && i < this.cells.length ? this.cells[i] : EMPTY;
  }

  private isFixed(i: number): boolean {
    return i >= 0 && i < this.fixed.length ? this.fixed[i] : false;
  }

  private filled(): number {
    let n: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] !== EMPTY) {
        n++;
      }
    }
    return n;
  }

  /** 该格现在是否违规 */
  private bad(i: number): boolean {
    const v: number = this.valAt(i);
    if (v === EMPTY) {
      return false;
    }
    const probe: number[] = this.cells.slice();
    probe[i] = EMPTY;
    return !fits(probe, i, v, this.diffTotal);
  }


  /**
   * ★★★ 2026-10-23 第二期：二进制（Takuzu）提示
   *
   * 规则只有两条（见文件里的 lineOk）：每行列 0/1 数量相等、不能三连。
   * ⇒ 这是**逐行可判**的，所以能用和数织同一套技术：
   *    枚举这一行的所有合法排列（2^n，n ≤ 8 时最多 256 个），
   *    只保留与玩家已填内容不矛盾的，
   *    再求交集 —— 在所有候选里都一样的格，就是确定的。
   *
   * ⚠️ 判断依据只用「规则 + 玩家已填」，**不看题目答案**。
   *    这跟扫雷、数织是同一条底线。
   *
   * 全盘都推不出 ⇒ Hint.none()，界面直说"这一步推不出来"。
   * （Takuzu 确实存在需要试探的局面。）
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    const half: number = Math.floor(n / 2);
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < n; k++) {
        // 取这一行/列的当前值
        const marks: number[] = [];
        for (let i = 0; i < n; i++) {
          marks.push(horiz === 1 ? this.valAt(k * n + i) : this.valAt(i * n + k));
        }
        const total: number = 1 << n;
        let acc: number[] = [];
        let cnt: number = 0;
        for (let mask = 0; mask < total; mask++) {
          const bits: number[] = [];
          let ones: number = 0;
          let ok: boolean = true;
          let run: number = 1;
          for (let i = 0; i < n; i++) {
            const v: number = (mask >> i) & 1;
            bits.push(v);
            if (v === 1) {
              ones++;
            }
            if (marks[i] !== EMPTY && marks[i] !== v) {
              ok = false;
              break;
            }
            if (i > 0 && bits[i] === bits[i - 1]) {
              run++;
              if (run >= 3) {
                ok = false;
                break;
              }
            } else {
              run = 1;
            }
          }
          if (!ok || ones !== half) {
            continue;
          }
          if (cnt === 0) {
            acc = bits.slice();
          } else {
            for (let i = 0; i < n; i++) {
              if (acc[i] !== bits[i]) {
                acc[i] = -1;
              }
            }
          }
          cnt++;
        }
        if (cnt <= 1) {
          continue;
        }
        for (let i = 0; i < n; i++) {
          if (acc[i] < 0) {
            continue;
          }
          if (marks[i] === acc[i]) {
            continue;                     // 玩家已经填对了
          }
          const idx: number = horiz === 1 ? k * n + i : i * n + k;
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          return Hint.make([idx],
            TG2('第 {0} 行第 {1} 列一定是 {2}', String(r), String(c), String(acc[i])),
            TG2('Row {0}, column {1} must be {2}', String(r), String(c), String(acc[i])), t0);
        }
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第三期：AI 代打
   * 用出题时保留的完整解，一格一格点到位。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.done || this.finished) {
      return false;
    }
    const n: number = this.diffTotal;
    if (this.solCells.length < n * n) {
      return false;
    }
    for (let i = 0; i < n * n; i++) {
      if (this.cells[i] !== this.solCells[i] && !this.fixed[i]) {
        this.tap(i);
        return true;
      }
    }
    return false;
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
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步纯靠规则推不出来，得试着填一格看看');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  private tap(i: number): void {
    if (this.done || this.finished) {
      return;
    }
    if (this.isFixed(i)) {
      this.status = TG('题目自带的数字不能改');
      return;
    }
    const cur: number = this.valAt(i);
    const next: number = cur === EMPTY ? 0 : (cur === 0 ? 1 : EMPTY);
    const cells: number[] = this.cells.slice();
    cells[i] = next;
    this.cells = cells;

    if (next === EMPTY) {
      this.status = TG('清空了这一格');
      return;
    }
    if (!fits(cells, i, next, this.diffTotal)) {
      this.mistakes = this.mistakes + 1;
      this.status = TG('这格现在违规：三连或 0/1 数量不等');
    } else {
      this.status = TG('合法，继续');
    }
    // 填满且合法 ⇒ 立刻通关；填满了但有冲突 ⇒ 只提示，让玩家自己改（点「交卷」才认输）
    if (this.isWin()) {
      this.done = true;
      this.status = TG('🎉 每行每列都平衡，通关！');
      this.finish(true);
    } else if (this.allFilled()) {
      this.status = TG('填满了但有冲突：红色格子改一改，或点「交卷」认输');
    }
  }

  /** 交卷：满了且合法算通关，否则认输 */
  private submit(): void {
    if (this.done || this.finished) {
      return;
    }
    if (this.isWin()) {
      this.done = true;
      this.status = TG('🎉 每行每列都平衡，通关！');
      this.finish(true);
      return;
    }
    this.done = true;
    this.status = TG('交卷：盘面还有冲突，这一局没通关');
    this.finish(false);
  }

  private allFilled(): boolean {
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === EMPTY) {
        return false;
      }
    }
    return true;
  }

  private isWin(): boolean {
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.cells[i] === EMPTY) {
        return false;
      }
    }
    for (let r = 0; r < this.diffTotal; r++) {
      const row: number[] = [];
      const col: number[] = [];
      for (let c = 0; c < this.diffTotal; c++) {
        row.push(this.cells[r * this.diffTotal + c]);
        col.push(this.cells[c * this.diffTotal + r]);
      }
      if (!lineOk(row, this.diffTotal) || !lineOk(col, this.diffTotal)) {
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
    this.stopTimer();
    const r: GameResult = {
      gameId: 'binary_puzzle',
      solved: solved,
      score: solved ? Math.max(150, 1100 - this.seconds * 3 - this.mistakes * 100) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filled()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text(true ? TG('已填') : (false ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(true ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
        : (false ? String(this.mistakes) : (this.seconds + 's')))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text(false ? TG('已填') : (true ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
        : (true ? String(this.mistakes) : (this.seconds + 's')))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text(false ? TG('已填') : (false ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
        : (false ? String(this.mistakes) : (this.seconds + 's')))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: GAP }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: GAP }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.textOf((r * this.diffTotal + c)))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.inkOf((r * this.diffTotal + c)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.bgOf((r * this.diffTotal + c)))
              .borderRadius(Radius.sm)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('86%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor('#1A4F46E5')
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            if (this.done || this.finished) {
              return;
            }
            const cells: number[] = this.cells.slice();
            for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
              if (!this.isFixed(i)) {
                cells[i] = EMPTY;
              }
            }
            this.cells = cells;
            this.status = TG('已清空你填的格子');
          })
        Button(this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打')))
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('交卷'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.submit();
          })
      }
      .width('100%')

      Text(this.hintMsg.length > 0 ? this.hintMsg : this.status)
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=已填 1=失误 2=用时 */




  private textOf(i: number): string {
    const v: number = this.valAt(i);
    return v === EMPTY ? '' : String(v);
  }

  private bgOf(i: number): string {
    if (this.bad(i)) {
      return '#FECDD3';
    }
    const v: number = this.valAt(i);
    if (v === 1) {
      return Palette.primaryDeep;
    }
    if (v === 0) {
      return this.theme.isDark ? '#1E1E2E' : '#E2E8F0';
    }
    return this.isFixed(i) ? this.theme.surfaceAlt : this.theme.surface;
  }

  private inkOf(i: number): string {
    if (this.bad(i)) {
      return Palette.danger;
    }
    return this.valAt(i) === 1 ? '#FFFFFF' : this.theme.ink;
  }
}
