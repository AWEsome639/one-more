/**
 * 数独 —— 9×9，每行/每列/每宫都是 1..9
 *
 * 玩法：
 *   · 内置 3 道**完整解**做底（写死在文件里），开局随机选一道、随机挖掉 40 格
 *   · 挖空时用「唯一解校验」（回溯 + MRV 启发 + 节点预算）保证题目**有且只有一个答案**
 *   · 点格子选中 → 点下方数字填入；再点同一个数字 = 擦掉
 * 判据：81 格填满且每行每列每宫都是 1..9 ⇒ 通关
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 路线 B：难度不再只看挖空数，用模型预测「真实难度」
import { SudokuDifficulty } from '../ai/SudokuDifficulty';
// ★★★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIDE: number = 9;
const BOX: number = 3;
const CELLS: number = SIDE * SIDE;      // 81
const BLANKS: number = 40;              // 挖空 40 格左右
const SOLVER_BUDGET: number = 4000;     // 单次"数解"的节点预算
const DIG_BUDGET: number = 120000;      // 整局挖空的总节点预算
const TICK_MS: number = 1000;

const IDX9: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const IDX3: number[] = [0, 1, 2];
const DIGITS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9];

/** 棋盘配色（棋盘专属，浅/深两套） */
const PEER_LIGHT: string = '#EAF0F8';
const PEER_DARK: string = '#141A22';
const SEL_TINT: string = '#406366F1';
const SAME_TINT: string = '#2E0EA5E9';
const BAD_TINT: string = '#40F43F5E';
const BOARD_LIGHT: string = '#C9D4E8';
const BOARD_DARK: string = '#0E1116';
const GIVEN_TINT_LIGHT: string = '#E7EDF7';
const GIVEN_TINT_DARK: string = '#1A1A1A';

/**
 * 3 道完整解（自己构造：先取基础拉丁方 (r*3 + r/3 + c) % 9 + 1，再做数字置换）。
 * 每一道都满足"每行/每列/每宫 1..9 各一次"。
 */
const SOLUTIONS: number[][] = [
  [
    7, 8, 2, 5, 3, 1, 9, 4, 6,
    5, 3, 1, 9, 4, 6, 7, 8, 2,
    9, 4, 6, 7, 8, 2, 5, 3, 1,
    8, 2, 5, 3, 1, 9, 4, 6, 7,
    3, 1, 9, 4, 6, 7, 8, 2, 5,
    4, 6, 7, 8, 2, 5, 3, 1, 9,
    2, 5, 3, 1, 9, 4, 6, 7, 8,
    1, 9, 4, 6, 7, 8, 2, 5, 3,
    6, 7, 8, 2, 5, 3, 1, 9, 4
  ],
  [
    3, 1, 8, 4, 7, 2, 9, 5, 6,
    4, 7, 2, 9, 5, 6, 3, 1, 8,
    9, 5, 6, 3, 1, 8, 4, 7, 2,
    1, 8, 4, 7, 2, 9, 5, 6, 3,
    7, 2, 9, 5, 6, 3, 1, 8, 4,
    5, 6, 3, 1, 8, 4, 7, 2, 9,
    8, 4, 7, 2, 9, 5, 6, 3, 1,
    2, 9, 5, 6, 3, 1, 8, 4, 7,
    6, 3, 1, 8, 4, 7, 2, 9, 5
  ],
  [
    7, 6, 1, 2, 8, 4, 3, 5, 9,
    2, 8, 4, 3, 5, 9, 7, 6, 1,
    3, 5, 9, 7, 6, 1, 2, 8, 4,
    6, 1, 2, 8, 4, 3, 5, 9, 7,
    8, 4, 3, 5, 9, 7, 6, 1, 2,
    5, 9, 7, 6, 1, 2, 8, 4, 3,
    1, 2, 8, 4, 3, 5, 9, 7, 6,
    4, 3, 5, 9, 7, 6, 1, 2, 8,
    9, 7, 6, 1, 2, 8, 4, 3, 5
  ]
];

@Component
export struct GSudoku {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：挖空多少格（简单 28 格更好解 / 普通 40 / 困难 52 更难）
  //   BLANKS 是模块常量 ⇒ 必须用运行时的 this.blanksTotal
  private blanksTotal: number = GameDiff.sizeNow(BLANKS);
  onFinish: (r: GameResult) => void = () => {};

  @State private values: number[] = [];       // 当前盘面（0 = 空）
  @State private given: boolean[] = [];       // 是否为题目给定的格子
  @State private sel: number = -1;            // 选中的格子
  @State private mistakes: number = 0;        // 填错次数
  @State private filled: number = 0;          // 已填格数
  @State private seconds: number = 0;
  @State private done: boolean = false;
  @State private holes: number = 0;
  /** ★ 第二期：提示高亮的格子（-1 = 没有提示） */
  @State private hintCell: number = -1;
  /** 提示要填的数字（0 = 无） */
  @State private hintValue: number = 0;
  /** ★ 第二期：提示说了什么（空 = 没提示） */
  @State private hintMsg: string = '';
  /** ★ 路线 B：模型预测的本局难度（-1 = 模型不可用） */
  private aiDifficulty: number = -1;
  @State private label: string = '';          // 用的第几道底

  private answer: number[] = [];              // 本局完整解（判失误用）
  private nodes: number = 0;                  // 求解器节点计数
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.blanksTotal = GameDiff.sizeNow(BLANKS);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  // ────────────────────────── 生命周期 / 计时 ──────────────────────────


  /**
   * ★★★ 2026-10-23 第二期：数独提示
   *
   * 策略（从便宜到贵，够用就停）：
   *   ① 找「唯一候选」的空格 —— 直接告诉玩家这格填几（最快、最常见）
   *   ② 没有唯一候选 ⇒ 用回溯求解器算出完整解，揭一个空格（保证有提示，但更贵）
   *   ③ 都失败 ⇒ Hint.none()，界面说"这局暂时想不出来"
   *
   * ★ 为什么先找唯一候选：那是最"人类"的一步，玩家学会了自己也能看出来。
   *   直接揭答案（②）会让人失去推理乐趣，所以只在①失败时兜底。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    // ① 唯一候选
    for (let i = 0; i < CELLS; i++) {
      if (this.values[i] !== 0) {
        continue;
      }
      const mask: number = this.candMask(this.values, i);
      if (mask !== 0 && (mask & (mask - 1)) === 0) {
        // 只有一个 bit ⇒ 唯一候选
        let v: number = 0;
        for (let k = 1; k <= SIDE; k++) {
          if ((mask & (1 << k)) !== 0) {
            v = k;
            break;
          }
        }
        if (v > 0) {
          this.hintValue = v;
          return Hint.make([i], TG2('这一格只能是 {0}', v),
            TG2('This cell can only be {0}', v), t0);
        }
      }
    }
    // ② 回溯求解，揭一个空格
    const g: number[] = this.values.slice();
    if (this.fillSolved(g)) {
      for (let i = 0; i < CELLS; i++) {
        if (this.values[i] === 0 && g[i] !== 0) {
          this.hintValue = g[i];
          return Hint.make([i], TG2('试试在这里填 {0}', g[i]),
            TG2('Try {0} here', g[i]), t0);
        }
      }
    }
    this.hintValue = 0;
    return Hint.none('none');
  }

  /** 回溯填满（返回是否成功）。只用于提示，不影响玩家棋盘。 */
  private fillSolved(g: number[]): boolean {
    let best: number = -1;
    let bestCnt: number = 10;
    for (let i = 0; i < CELLS; i++) {
      if (g[i] !== 0) {
        continue;
      }
      const mask: number = this.candMask(g, i);
      let cnt: number = 0;
      for (let k = 1; k <= SIDE; k++) {
        if ((mask & (1 << k)) !== 0) {
          cnt++;
        }
      }
      if (cnt === 0) {
        return false;
      }
      if (cnt < bestCnt) {
        bestCnt = cnt;
        best = i;
        if (cnt === 1) {
          break;
        }
      }
    }
    if (best < 0) {
      return true;                      // 全填满了
    }
    const mask: number = this.candMask(g, best);
    for (let k = 1; k <= SIDE; k++) {
      if ((mask & (1 << k)) !== 0) {
        g[best] = k;
        if (this.fillSolved(g)) {
          return true;
        }
        g[best] = 0;
      }
    }
    return false;
  }

  /** 玩家点「提示」 */
  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintCell = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintCell = -1; this.hintMsg = ''; }, 4000);
      return;
    }
    this.hintCell = -1;
    this.hintValue = 0;
    this.hintMsg = TG('这局暂时想不出提示，再试试别的格');
    setTimeout(() => { this.hintMsg = ''; }, 4000);
  }

  private reset(): void {
    this.stopTimer();
    const pick: number = Math.floor(Math.random() * SOLUTIONS.length);
    const sol: number[] = SOLUTIONS[pick].slice();
    const puzzle: number[] = sol.slice();

    // 随机顺序试挖，挖完仍保证唯一解才真的挖掉
    const order: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      order.push(i);
    }
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    let blanks: number = 0;
    let budget: number = DIG_BUDGET;
    for (let k = 0; k < order.length; k++) {
      if (blanks >= this.blanksTotal || budget <= 0) {
        break;
      }
      const i: number = order[k];
      const keep: number = puzzle[i];
      puzzle[i] = 0;
      this.nodes = 0;
      const cnt: number = this.countSolutions(puzzle.slice(), 2);
      budget = budget - this.nodes;
      if (cnt === 1) {
        blanks++;
      } else {
        puzzle[i] = keep;      // 会出现多解 ⇒ 这一格留着
      }
    }

    // ★★★ 2026-10-23 路线 B：按【预测难度】补挖
    //   为什么：挖空数 ≠ 难度。实测同样挖 54 格，有的题 15 轮技巧推完、
    //   有的要 28 轮还夹搜索。原来困难档只是"挖 52 格"，运气不好出一局很水的题。
    //   现在：挖完后问模型"这局有多难"，离目标差得远就继续挖（最多多挖 8 格，
    //   且每一步仍然保证唯一解）⇒ 困难档真的难。
    //   模型不可用 ⇒ predict 返回 null ⇒ 完全跳过，行为与原来一致。
    let aiDiff: number = -1;
    try {
      const target: number = SudokuDifficulty.targetFor(GameDiff.now());
      let predicted: number | null = SudokuDifficulty.predict(puzzle);
      if (predicted !== null && predicted < target - 0.08 && budget > 0) {
        const extraCap: number = blanks + 8;
        for (let k = 0; k < order.length && budget > 0; k++) {
          if (blanks >= extraCap) {
            break;
          }
          const i: number = order[k];
          if (puzzle[i] === 0) {
            continue;
          }
          const keep: number = puzzle[i];
          puzzle[i] = 0;
          this.nodes = 0;
          const cnt: number = this.countSolutions(puzzle.slice(), 2);
          budget = budget - this.nodes;
          if (cnt === 1) {
            blanks++;
            const p2: number | null = SudokuDifficulty.predict(puzzle);
            if (p2 !== null && p2 >= target - 0.08) {
              predicted = p2;
              break;
            }
          } else {
            puzzle[i] = keep;
          }
        }
        if (predicted !== null) {
          const finalP: number | null = SudokuDifficulty.predict(puzzle);
          aiDiff = finalP === null ? predicted : finalP;
        }
      } else if (predicted !== null) {
        aiDiff = predicted;
      }
    } catch (e) {
      aiDiff = -1;
    }
    this.aiDifficulty = aiDiff;
    hilog.info(0x0000, 'SudokuDifficulty',
      '本局生成：挖空 %{public}d，模型难度 %{public}s，目标 %{public}s',
      blanks,
      aiDiff < 0 ? '不可用' : aiDiff.toFixed(3),
      SudokuDifficulty.targetFor(GameDiff.now()).toFixed(2));

    this.answer = sol;
    this.values = puzzle.slice();
    this.given = puzzle.map((v: number) => v !== 0);
    this.holes = blanks;
    this.label = TG2('底 {0}', (pick + 1));
    this.sel = -1;
    this.mistakes = 0;
    this.filled = 0;
    this.seconds = 0;
    this.done = false;
    this.finished = false;
    this.recount();
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

  // ────────────────────────── 求解器（只用来校验唯一解） ──────────────────────────

  /** 第 i 格的候选位掩码：bit d = 1 表示数字 d 可填 */
  private candMask(g: number[], i: number): number {
    const r: number = Math.floor(i / SIDE);
    const c: number = i % SIDE;
    let used: number = 0;
    for (let k = 0; k < SIDE; k++) {
      const a: number = g[r * SIDE + k];
      if (a > 0) {
        used = used | (1 << a);
      }
      const b: number = g[k * SIDE + c];
      if (b > 0) {
        used = used | (1 << b);
      }
    }
    const br: number = Math.floor(r / BOX) * BOX;
    const bc: number = Math.floor(c / BOX) * BOX;
    for (let dr = 0; dr < BOX; dr++) {
      for (let dc = 0; dc < BOX; dc++) {
        const v: number = g[(br + dr) * SIDE + (bc + dc)];
        if (v > 0) {
          used = used | (1 << v);
        }
      }
    }
    let mask: number = 0;
    for (let d = 1; d <= SIDE; d++) {
      if ((used & (1 << d)) === 0) {
        mask = mask | (1 << d);
      }
    }
    return mask;
  }

  /** 数解的个数（数到 cap 就收工）；超预算按"不唯一"处理，宁可少挖一格 */
  private countSolutions(g: number[], cap: number): number {
    this.nodes = this.nodes + 1;
    if (this.nodes > SOLVER_BUDGET) {
      return cap;
    }
    // MRV：挑候选最少的空格
    let best: number = -1;
    let bestMask: number = 0;
    let bestCnt: number = SIDE + 1;
    for (let i = 0; i < CELLS; i++) {
      if (g[i] !== 0) {
        continue;
      }
      const m: number = this.candMask(g, i);
      let cnt: number = 0;
      for (let d = 1; d <= SIDE; d++) {
        if ((m & (1 << d)) !== 0) {
          cnt++;
        }
      }
      if (cnt === 0) {
        return 0;                 // 这个分支死了
      }
      if (cnt < bestCnt) {
        bestCnt = cnt;
        best = i;
        bestMask = m;
        if (cnt === 1) {
          break;
        }
      }
    }
    if (best < 0) {
      return 1;                   // 盘面已满 ⇒ 找到一个解
    }
    let total: number = 0;
    for (let d = 1; d <= SIDE; d++) {
      if ((bestMask & (1 << d)) === 0) {
        continue;
      }
      g[best] = d;
      total = total + this.countSolutions(g, cap - total);
      g[best] = 0;
      if (total >= cap) {
        return total;
      }
    }
    return total;
  }

  // ────────────────────────── 玩法 ──────────────────────────

  private valueAt(i: number): number {
    if (i >= 0 && i < this.values.length) {
      return this.values[i];
    }
    return 0;
  }

  private givenAt(i: number): boolean {
    if (i >= 0 && i < this.given.length) {
      return this.given[i];
    }
    return false;
  }

  private recount(): void {
    let n: number = 0;
    for (let i = 0; i < this.values.length; i++) {
      if (this.values[i] !== 0) {
        n++;
      }
    }
    this.filled = n;
  }

  private fill(d: number): void {
    if (this.done || this.finished || this.sel < 0) {
      return;
    }
    if (this.givenAt(this.sel)) {
      return;
    }
    const vs: number[] = this.values.slice();
    if (vs[this.sel] === d) {
      vs[this.sel] = 0;                    // 再点一次同一个数字 = 擦掉
    } else {
      vs[this.sel] = d;
      if (d !== this.answer[this.sel]) {
        this.mistakes = this.mistakes + 1;
      }
    }
    this.values = vs;
    this.recount();
    if (this.filled === CELLS && this.isValid(vs)) {
      this.done = true;
      this.finish(true);
    }
  }

  private erase(): void {
    if (this.done || this.finished || this.sel < 0 || this.givenAt(this.sel)) {
      return;
    }
    const vs: number[] = this.values.slice();
    vs[this.sel] = 0;
    this.values = vs;
    this.recount();
  }

  /** 填满后校验：每行/每列/每宫都必须是 1..9 */
  private isValid(g: number[]): boolean {
    for (let r = 0; r < SIDE; r++) {
      let m: number = 0;
      for (let c = 0; c < SIDE; c++) {
        const v: number = g[r * SIDE + c];
        if (v < 1 || v > SIDE || (m & (1 << v)) !== 0) {
          return false;
        }
        m = m | (1 << v);
      }
    }
    for (let c = 0; c < SIDE; c++) {
      let mc: number = 0;
      for (let r = 0; r < SIDE; r++) {
        const v: number = g[r * SIDE + c];
        if (v < 1 || v > SIDE || (mc & (1 << v)) !== 0) {
          return false;
        }
        mc = mc | (1 << v);
      }
    }
    for (let b = 0; b < SIDE; b++) {
      let mb: number = 0;
      const r0: number = Math.floor(b / BOX) * BOX;
      const c0: number = (b % BOX) * BOX;
      for (let dr = 0; dr < BOX; dr++) {
        for (let dc = 0; dc < BOX; dc++) {
          const v: number = g[(r0 + dr) * SIDE + (c0 + dc)];
          if (v < 1 || v > SIDE || (mb & (1 << v)) !== 0) {
            return false;
          }
          mb = mb | (1 << v);
        }
      }
    }
    return true;
  }

  /** 与同行/同列/同宫里的其它格子撞了同一个数字 */
  private isConflict(i: number): boolean {
    const v: number = this.valueAt(i);
    if (v === 0) {
      return false;
    }
    const r: number = Math.floor(i / SIDE);
    const c: number = i % SIDE;
    for (let k = 0; k < SIDE; k++) {
      const a: number = r * SIDE + k;
      if (a !== i && this.valueAt(a) === v) {
        return true;
      }
      const b: number = k * SIDE + c;
      if (b !== i && this.valueAt(b) === v) {
        return true;
      }
    }
    const br: number = Math.floor(r / BOX) * BOX;
    const bc: number = Math.floor(c / BOX) * BOX;
    for (let dr = 0; dr < BOX; dr++) {
      for (let dc = 0; dc < BOX; dc++) {
        const k: number = (br + dr) * SIDE + (bc + dc);
        if (k !== i && this.valueAt(k) === v) {
          return true;
        }
      }
    }
    return false;
  }

  /** 与选中格同行/同列/同宫 */
  private isPeer(i: number): boolean {
    if (this.sel < 0 || i === this.sel) {
      return false;
    }
    const r: number = Math.floor(i / SIDE);
    const c: number = i % SIDE;
    const sr: number = Math.floor(this.sel / SIDE);
    const sc: number = this.sel % SIDE;
    if (r === sr || c === sc) {
      return true;
    }
    return Math.floor(r / BOX) === Math.floor(sr / BOX) && Math.floor(c / BOX) === Math.floor(sc / BOX);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const usedMs: number = Date.now() - this.startAt;
    const usedSec: number = Math.floor(usedMs / TICK_MS);
    const r: GameResult = {
      gameId: 'sudoku',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.mistakes * 60 - usedSec * 3) : 0,
      durationMs: usedMs,
      levelReached: this.holes
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ────────────────────────── 渲染 ──────────────────────────

  private cellBg(i: number): string {
    if (i === this.sel) {
      return SEL_TINT;
    }
    if (this.isConflict(i)) {
      return BAD_TINT;
    }
    const v: number = this.valueAt(i);
    if (v !== 0 && this.sel >= 0 && v === this.valueAt(this.sel)) {
      return SAME_TINT;
    }
    if (this.isPeer(i)) {
      return this.theme.isDark ? PEER_DARK : PEER_LIGHT;
    }
    if (this.givenAt(i)) {
      return this.theme.isDark ? GIVEN_TINT_DARK : GIVEN_TINT_LIGHT;
    }
    return this.theme.surface;
  }

  private cellInk(i: number): string {
    if (this.isConflict(i)) {
      return Palette.rose;
    }
    if (this.givenAt(i)) {
      return this.theme.ink;
    }
    return Palette.primary;
  }

  private statusText(): string {
    if (this.done) {
      return TG2("🎉 完成！失误 {0} 次 · 用时 {1} 秒",Digits(String(this.mistakes), this.langCode),Digits(String(this.seconds), this.langCode));
    }
    if (this.sel < 0) {
      if (this.hintMsg.length > 0) {
        return this.hintMsg;              // ★ 提示优先占状态栏，4 秒后自动清
      }
      return this.label + TG2(' · 挖空 {0} 格 · 唯一解 —— 点一个空格，再点下面的数字', this.holes);
    }
    if (this.givenAt(this.sel)) {
      return TG('这是题目给的数字，不能改 —— 换个空格试试');
    }
    return TG2("已选中第 {0} 行第 {1} 列", (Math.floor(this.sel / SIDE) + 1), (this.sel % SIDE + 1));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      // 棋盘：3×3 个宫，宫与宫之间留大缝，宫内的格子留小缝
      Column({ space: Space.xs }) {
        ForEach(IDX3, (br: number) => {
          Row({ space: Space.xs }) {
            ForEach(IDX3, (bc: number) => {
              Column({ space: 2 }) {
                ForEach(IDX3, (rr: number) => {
                  Row({ space: 2 }) {
                    ForEach(IDX3, (cc: number) => {
                      this.cellView((br * BOX + rr) * SIDE + (bc * BOX + cc))
                    }, (cc: number) => 'cc' + cc)
                  }
                  .width('100%')
                }, (rr: number) => 'rr' + rr)
              }
              .layoutWeight(1)
            }, (bc: number) => 'bc' + bc)
          }
          .width('100%')
        }, (br: number) => 'br' + br)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.isDark ? BOARD_DARK : BOARD_LIGHT)
      .borderRadius(Radius.lg)

      // 数字键盘
      Row({ space: Space.xs }) {
        ForEach(DIGITS, (d: number) => {
          Button(String(d))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(Palette.teal)
            .borderRadius(Radius.sm)
            .layoutWeight(1)
            .height(Cell.of(44))
            .onClick(() => {
              Haptics.tap();
              this.fill(d);
            })
        }, (d: number) => 'd' + d)
      }
      .width('100%')

      Text(this.statusText())
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkFaint)

      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .height(Cell.of(44))
          .padding({ left: Space.md, right: Space.md })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('擦除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.erase();
          })
        Button(TG('重开（新题）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=已填 1=失误 2=用时（值在 Builder 内部读状态，保证刷新） */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('已填') : (kind === 1 ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.filled + '/' + CELLS
        : (kind === 1 ? String(this.mistakes) : this.seconds + 's'))
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

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.valueAt(i) === 0 ? '' : String(this.valueAt(i)))
        .fontSize(FontSize.md)
        .fontWeight(this.givenAt(i) ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.cellInk(i))
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.cellBg(i))
    .borderRadius(Radius.xs)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.sel = i;
    })
  }
}
