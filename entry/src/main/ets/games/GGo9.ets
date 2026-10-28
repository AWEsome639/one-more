/**
 * 9 路围棋（go9）—— 9×9 交叉点 · 气/提子 · 打劫 · 数子法（中国规则）
 *
 * 规则（规格书《新游戏-9路围棋-规格书.md》）：
 *   · 棋盘 9×9 **交叉点**（不是格子），黑先；人执黑，AI 执白
 *   · 气 = 上下左右相邻的空点；**无气的棋块被提掉**
 *   · 禁着点：落子后自己无气且提不到对方 ⇒ 非法
 *   · 打劫（简单版）：禁止"提回来立刻让局面回到上一步之前"（比局面哈希）
 *   · 终局：双方连续 2 次「停一手」或棋盘下满 ⇒ 数子
 *   · 计分：中国规则 = 己方子数 + 己方围住的空点；**白贴 6.5 目**
 *
 * ★ 本文件刻意遵守的既有规矩（都是真机踩过的坑）：
 *   ① `@Builder` **只收位置 (r,c)**，棋子/气/高亮全部在 builder 内部读 `@State`
 *      （按值传参不建立 ArkUI 观察 ⇒ 界面永不刷新）
 *   ② 组件方法**不叫 `size`**（撞 ArkUI 基类 `CustomComponent.size`）⇒ 用 `boardN()`
 *   ③ 棋盘用 `.width('100%').aspectRatio(1)` **宽驱动**；⛔ 不叠 `layoutWeight(1)`
 *   ④ ForEach 的 key 用**下标**（key 不变 ⇒ 项不更新）
 *   ⑤ 文案走 `TG('中文')`
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 第二期：围棋上 MCTS（工作线程）
import { GoWorker } from '../ai/GoWorker';
import { LanMatch, Side } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 9;                   // 9 路
const CELLS: number = N * N;
const EMPTY: number = 0;
const BLACK: number = 1;               // 人（先手）
const WHITE: number = 2;               // AI（后手，贴 6.5 目）
const KOMI: number = 6.5;              // 白贴目
const AI_DELAY: number = 420;
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
/**
 * ★★ 局域网哨兵（P12）
 *   'P' 停一手 —— 在围棋里是**真的一手**（两边都要计连续停手次数）
 *   'F' 只翻手 —— 重开时把回合翻回房主先手用（**不能复用 'P'**：
 *       对方会把翻手当成停一手，连着两次就误判终局）
 *   'R' 重开 —— 对方收到就整盘重置
 */
const LAN_PASS: string = 'P';
const LAN_FLIP: string = 'F';
const LAN_RESTART: string = 'R';
/** 星位（9 路：四角 + 天元） */
const STARS: number[] = [2 * N + 2, 2 * N + 6, 6 * N + 2, 6 * N + 6, 4 * N + 4];

/** 上下左右的邻居（越界的丢掉） */
function nbrs(i: number, n: number): number[] {
  const out: number[] = [];
  const r: number = Math.floor(i / n);
  const c: number = i % n;
  if (r > 0) {
    out.push(i - n);
  }
  if (r < n - 1) {
    out.push(i + n);
  }
  if (c > 0) {
    out.push(i - 1);
  }
  if (c < n - 1) {
    out.push(i + 1);
  }
  return out;
}

/** 与 i 同色的连通块（含 i 自己）；i 为空则返回空数组 */
function groupOf(b: number[], i: number, n: number): number[] {
  const who: number = b[i];
  if (who === EMPTY) {
    return [];
  }
  const out: number[] = [i];
  const seen: boolean[] = new Array<boolean>(b.length).fill(false);
  seen[i] = true;
  let head: number = 0;
  while (head < out.length) {
    const cur: number[] = nbrs(out[head], n);
    head++;
    for (let k = 0; k < cur.length; k++) {
      const j: number = cur[k];
      if (!seen[j] && b[j] === who) {
        seen[j] = true;
        out.push(j);
      }
    }
  }
  return out;
}

/** 一个棋块的气数（相邻空点去重） */
function libsOf(b: number[], grp: number[], n: number): number {
  const mark: boolean[] = new Array<boolean>(b.length).fill(false);
  let libs: number = 0;
  for (let k = 0; k < grp.length; k++) {
    const cur: number[] = nbrs(grp[k], n);
    for (let j = 0; j < cur.length; j++) {
      const p: number = cur[j];
      if (b[p] === EMPTY && !mark[p]) {
        mark[p] = true;
        libs++;
      }
    }
  }
  return libs;
}

/** 单点的气（= 该点所在块的气；用于判断打吃/自提） */
function libsAt(b: number[], i: number, n: number): number {
  return libsOf(b, groupOf(b, i, n), n);
}

/**
 * 落子 + 提子。返回新局面；**非法（自杀）返回 null**。
 * 打劫不在这里判（由调用方比局面哈希）。
 */
function placeStone(b: number[], i: number, who: number, n: number): number[] | null {
  if (i < 0 || i >= b.length || b[i] !== EMPTY) {
    return null;
  }
  const nb: number[] = b.slice();
  nb[i] = who;
  const foe: number = who === BLACK ? WHITE : BLACK;
  const around: number[] = nbrs(i, n);
  for (let k = 0; k < around.length; k++) {
    const j: number = around[k];
    if (nb[j] !== foe) {
      continue;
    }
    const g: number[] = groupOf(nb, j, n);
    if (libsOf(nb, g, n) === 0) {
      for (let t = 0; t < g.length; t++) {
        nb[g[t]] = EMPTY;
      }
    }
  }
  if (libsAt(nb, i, n) === 0) {
    return null;                 // 自杀（提不到对方 ⇒ 非法禁着点）
  }
  return nb;
}

/** 这一手提掉了几个子（给 AI 与「提子」计数用） */
function capturedBy(before: number[], after: number[], who: number): number {
  const foe: number = who === BLACK ? WHITE : BLACK;
  let n0: number = 0;
  let n1: number = 0;
  for (let i = 0; i < before.length; i++) {
    if (before[i] === foe) {
      n0++;
    }
    if (after[i] === foe) {
      n1++;
    }
  }
  return n0 - n1;
}

/**
 * 数子法（中国规则）：己方子数 + 己方围住的空点。
 * 返回 [黑目, 白目(不含贴目), 单官/公气]
 */
function areaScore(b: number[], n: number): number[] {
  let black: number = 0;
  let white: number = 0;
  const seen: boolean[] = new Array<boolean>(b.length).fill(false);
  for (let i = 0; i < b.length; i++) {
    if (b[i] === BLACK) {
      black++;
      seen[i] = true;
    } else if (b[i] === WHITE) {
      white++;
      seen[i] = true;
    }
  }
  let neutral: number = 0;
  for (let i = 0; i < b.length; i++) {
    if (seen[i]) {
      continue;
    }
    // 洪水填满这块空区，看它四周只有黑 / 只有白 / 都有
    const region: number[] = [i];
    seen[i] = true;
    let head: number = 0;
    let touchB: boolean = false;
    let touchW: boolean = false;
    while (head < region.length) {
      const cur: number[] = nbrs(region[head], n);
      head++;
      for (let k = 0; k < cur.length; k++) {
        const j: number = cur[k];
        if (b[j] === EMPTY) {
          if (!seen[j]) {
            seen[j] = true;
            region.push(j);
          }
        } else if (b[j] === BLACK) {
          touchB = true;
        } else {
          touchW = true;
        }
      }
    }
    if (touchB && !touchW) {
      black += region.length;
    } else if (touchW && !touchB) {
      white += region.length;
    } else {
      neutral += region.length;
    }
  }
  return [black, white, neutral];
}

/** 眼：四邻都是自己（简版，够 AI 不作死用） */
function isOwnEye(b: number[], i: number, who: number, n: number): boolean {
  const cur: number[] = nbrs(i, n);
  if (cur.length < 4) {
    return false;
  }
  for (let k = 0; k < cur.length; k++) {
    if (b[cur[k]] !== who) {
      return false;
    }
  }
  return true;
}

/** 所有合法落点（已排除自杀、己方眼） */
function legalMoves(b: number[], who: number, n: number, koStr: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < b.length; i++) {
    if (b[i] !== EMPTY || isOwnEye(b, i, who, n)) {
      continue;
    }
    const nb: number[] | null = placeStone(b, i, who, n);
    if (nb === null) {
      continue;                  // 自杀
    }
    if (koStr.length > 0 && nb.join('') === koStr) {
      continue;                  // 打劫：不能立刻回到上一步之前的局面
    }
    out.push(i);
  }
  return out;
}

/** 简单伪随机（避免 Math.random 让 AI 每步都换主意时不好复现；这里只用来打散候选） */
function pickRandom(arr: number[], seed: number): number {
  if (arr.length === 0) {
    return -1;
  }
  const k: number = seed % arr.length;
  return arr[k];
}

@Component
export struct GGo9 {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  /** AI 档位：0 乱下 / 1 会提子会逃 / 2 再加一层浅算（难度来自设置） */
  private aiLevel: number = GameDiff.pick(0, 1, 2);
  /** ★ 第二期：异步搜索的代际守卫 —— 重开/换局后旧结果必须作废 */
  private aiGen: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private board: number[] = [];
  @State private myCap: number = 0;        // 我提掉对方几个子
  @State private foeCap: number = 0;       // 对方提掉我几个子
  @State private moves: number = 0;
  @State private turn: number = BLACK;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = TG('点交叉点落子，黑先');
  @State private lastMove: number = -1;    // 最后一手（画标记）
  @State private passStreak: number = 0;   // 连续停一手次数
  @State private scoreText: string = '';   // 终局数子结果
  @State private thinking: boolean = false;

  private koStr: string = '';              // 打劫：上一步之前的局面
  private aiTimer: number = -1;
  private seed: number = 20261013;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机对局：对方的落子 = 本局「AI 的那一步」
    LanMatch.setHandler((d: string) => {
      this.onRemote(d);
    });
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.restartTap();
  }

  aboutToDisappear(): void {
    this.clearAi();
  }

  // ── 基础 ────────────────────────────────────────────────
  /** 本局边长（⛔ 别叫 size()：撞 ArkUI 基类） */
  private boardN(): number {
    return N;
  }

  /** 本局格子数 */
  private cellCount(): number {
    return CELLS;
  }

  private clearAi(): void {
    if (this.aiTimer !== -1) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  private rnd(): number {
    this.seed = (this.seed * 1103515245 + 12345) % 2147483648;
    return this.seed;
  }

  private reset(): void {
    // ★ 代际 +1：让还没回来的异步搜索结果作废，避免"重开后又落了一子"
    this.aiGen++;
    this.clearAi();
    this.board = new Array<number>(CELLS).fill(EMPTY);
    this.myCap = 0;
    this.foeCap = 0;
    this.moves = 0;
    this.turn = BLACK;
    this.over = false;
    this.won = false;
    this.lastMove = -1;
    this.passStreak = 0;
    this.scoreText = '';
    this.thinking = false;
    this.koStr = '';
    this.finished = false;
    this.msg = LanMatch.isActive() ? '联机：黑先（房主执黑）' : TG('点交叉点落子，黑先');
    if (LanMatch.isActive()) {
      // ★ 联机：本地 turn 必须跟"轮到谁"对齐（加入方执白，开局等房主落子）
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      if (this.turn === WHITE) {
        this.msg = TG('联机：等对手落子…');
      }
    }
    this.startAt = Date.now();
  }

  /** 落一手（含提子计数、打劫记录）；非法返回 false */
  private play(i: number, who: number): boolean {
    const nb: number[] | null = placeStone(this.board, i, who, this.boardN());
    if (nb === null) {
      return false;                // 自杀 / 非空点
    }
    // 打劫：新局面上一步之前出现过 ⇒ 非法
    if (this.koStr.length > 0 && nb.join('') === this.koStr) {
      return false;
    }
    const got: number = capturedBy(this.board, nb, who);
    this.koStr = this.board.join('');
    this.board = nb;
    if (who === BLACK) {
      this.myCap += got;
    } else {
      this.foeCap += got;
    }
    this.moves++;
    this.lastMove = i;
    this.passStreak = 0;
    return true;
  }

  /** 停一手 */
  private pass(): void {
    if (this.over) {
      return;
    }
    this.passStreak++;
    this.koStr = '';
    this.moves++;
    this.lastMove = -1;
    if (this.passStreak >= 2) {
      this.endGame();
      return;
    }
    this.turn = this.turn === BLACK ? WHITE : BLACK;
    if (LanMatch.isActive()) {
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      this.msg = this.turn === BLACK ? '联机：轮到你' : TG('联机：等对手落子…');
      return;
    }
    this.msg = TG('双方各停一手就数子');
    if (this.turn === WHITE) {
      this.scheduleAi();
    }
  }

  private endGame(): void {
    this.clearAi();
    const sc: number[] = areaScore(this.board, this.boardN());
    const blackPts: number = sc[0];
    const whitePts: number = sc[1] + KOMI;
    this.over = true;
    this.won = blackPts > whitePts;
    this.turn = 0;
    this.thinking = false;
    this.scoreText = TG2('黑 {0} 目 · 白 {1} 目（含贴 {2}）', blackPts, whitePts, KOMI);
    this.msg = this.won
      ? '🎉 数子：你（黑）赢了'
      : (blackPts === whitePts ? '和棋' : (LanMatch.isActive() ? '对手（白）赢了' : '电脑（白）赢了'));
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'go9',
      solved: solved,
      score: areaScore(this.board, this.boardN())[0] * 10 + this.myCap * 5,
      durationMs: Date.now() - this.startAt,
      levelReached: this.myCap
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ── 人操作 ──────────────────────────────────────────────
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (LanMatch.isActive()) {
      return false;
    }
    if (this.thinking || this.turn !== BLACK) {
      return true;
    }
    const mv: number = this.blackPick();
    const n: number = this.boardN();
    if (mv < 0) {
      this.passTap();
      return !this.over;
    }
    this.tapPoint(Math.floor(mv / n), mv % n);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 黑棋版「能提就提 → 被打吃就逃 → 否则在己方附近挑安全的」
  /** 黑棋选点；-1 = 停一手 */
  private blackPick(): number {
    const b: number[] = this.board;
    const n: number = this.boardN();
    const legal: number[] = legalMoves(b, BLACK, n, this.koStr);
    if (legal.length === 0) {
      return -1;
    }
    let bestCap: number = -1;
    let bestCapMove: number = -1;
    for (let k = 0; k < legal.length; k++) {
      const nb: number[] = placeStone(b, legal[k], BLACK, n) as number[];
      const got: number = capturedBy(b, nb, BLACK);
      if (got > bestCap) {
        bestCap = got;
        bestCapMove = legal[k];
      }
    }
    if (bestCap > 0) {
      return bestCapMove;
    }
    let inDanger: number = -1;
    for (let i = 0; i < b.length; i++) {
      if (b[i] !== BLACK) {
        continue;
      }
      const g: number[] = groupOf(b, i, n);
      if (libsOf(b, g, n) === 1) {
        const libs: number[] = nbrs(g[0], n);
        for (let k = 0; k < libs.length; k++) {
          if (b[libs[k]] === EMPTY) {
            inDanger = libs[k];
          }
        }
        if (inDanger >= 0) {
          break;
        }
      }
    }
    if (inDanger >= 0 && legal.indexOf(inDanger) >= 0) {
      return inDanger;
    }
    const near: number[] = [];
    for (let k = 0; k < legal.length; k++) {
      const cur: number[] = nbrs(legal[k], n);
      for (let j = 0; j < cur.length; j++) {
        if (b[cur[j]] === BLACK) {
          near.push(legal[k]);
          break;
        }
      }
    }
    const pool: number[] = near.length > 0 ? near : legal;
    const safe: number[] = [];
    for (let k = 0; k < pool.length; k++) {
      const nb: number[] = placeStone(b, pool[k], BLACK, n) as number[];
      if (libsAt(nb, pool[k], n) >= 2) {
        safe.push(pool[k]);
      }
    }
    const pick: number[] = safe.length > 0 ? safe : pool;
    let bestLibs: number = -1;
    let bestMv: number = pick[0];
    for (let k = 0; k < pick.length; k++) {
      const nb2: number[] = placeStone(b, pick[k], BLACK, n) as number[];
      const l: number = libsAt(nb2, pick[k], n);
      if (l > bestLibs) {
        bestLibs = l;
        bestMv = pick[k];
      }
    }
    return bestMv;
  }

  /** 提示：报黑棋该下在第几行第几列 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.thinking || this.turn !== BLACK) {
      return Hint.none('none');
    }
    const mv: number = this.blackPick();
    const n: number = this.boardN();
    if (mv < 0) {
      return Hint.make([], TG('建议停一手'), TG('Suggested: pass'), t0);
    }
    const r: number = Math.floor(mv / n) + 1;
    const c: number = (mv % n) + 1;
    return Hint.make([mv],
      TG2('下在第 {0} 行第 {1} 列', String(r), String(c)),
      TG2('Play row {0}, column {1}', String(r), String(c)), t0);
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

  private tapPoint(r: number, c: number): void {
    const i: number = r * this.boardN() + c;
    if (this.over || this.thinking || this.turn !== BLACK || this.board[i] !== EMPTY) {
      return;
    }
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      return;                                   // ★ 不是我的回合就吞掉
    }
    if (LanMatch.isActive()) {
      if (!this.play(i, BLACK)) {
        this.msg = TG('这里不能下（自杀 / 打劫）');
        return;
      }
      LanMatch.record(String(i));               // ★ 先广播（对方靠这一步算同样的局面）
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      this.msg = this.turn === BLACK ? '联机：轮到你' : TG('联机：等对手落子…');
      return;
    }
    if (!this.play(i, BLACK)) {
      this.msg = TG('这里不能下（自杀 / 打劫）');
      return;
    }
    if (this.moves > 0 && this.board.indexOf(EMPTY) < 0) {
      this.endGame();
      return;
    }
    this.turn = WHITE;
    this.thinking = true;
    this.msg = LanMatch.isActive() ? '联机：等对手落子…' : TG('电脑在想…');
    this.scheduleAi();
  }

  private passTap(): void {
    if (this.over) {
      return;
    }
    if (LanMatch.isActive()) {
      if (!LanMatch.myTurn()) {
        return;
      }
      LanMatch.record(LAN_PASS);                // 停一手也要广播（否则两边目数/终局不一致）
      this.passStreak++;
      this.koStr = '';
      this.moves++;
      this.lastMove = -1;
      if (this.passStreak >= 2) {
        this.endGame();
        return;
      }
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      this.msg = this.turn === BLACK ? '联机：轮到你' : TG('联机：等对手落子…');
      return;
    }
    this.pass();
  }

  // ── AI ─────────────────────────────────────────────────
  private scheduleAi(): void {
    if (LanMatch.isActive()) {
      return;                                   // ★ 联机时没有 AI
    }
    this.clearAi();
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      this.aiTurn();
    }, AI_DELAY);
  }

  private aiTurn(): void {
    if (this.over || this.turn !== WHITE) {
      this.thinking = false;
      return;
    }
    // ★★★ 2026-10-23 第二期：困难/普通档走 MCTS（工作线程），简单档保留启发式
    //   实测（贴目归零、每局 200 手）：
    //     100ms 预算 MCTS 2 胜 5 负  ⇒ 不够，会输给启发式
    //     400ms 预算 MCTS 5 胜 2 负  ⇒ 够了
    //   ⇒ 所以 简单档不用 MCTS（省电、也让新手能赢），普通 250ms / 困难 400ms
    const budget: number = this.aiLevel >= 2 ? 400 : (this.aiLevel === 1 ? 250 : 0);
    if (budget <= 0) {
      const mv0: number = this.aiPick();
      this.applyAiMove(mv0);
      return;
    }
    const gen: number = this.aiGen;
    this.thinking = true;
    this.msg = TG('AI 正在想…');
    GoWorker.pick(this.board.slice(), WHITE, this.boardN(), this.koStr, budget)
      .then((idx: number) => {
        if (gen !== this.aiGen) {
          return;                       // 已经重开/换局 ⇒ 这个结果作废
        }
        // 工作线程算不出（-1）⇒ 回落启发式，绝不让 AI 停手
        const mv: number = idx >= 0 ? idx : this.aiPick();
        this.applyAiMove(mv);
      })
      .catch(() => {
        if (gen !== this.aiGen) {
          return;
        }
        this.applyAiMove(this.aiPick());
      });
  }

  /** 把 AI 选的一手落下去（工作线程与降级共用） */
  private applyAiMove(mv: number): void {
    this.thinking = false;
    if (mv < 0) {
      this.pass();
      return;
    }
    this.play(mv, WHITE);
    if (this.board.indexOf(EMPTY) < 0) {
      this.endGame();
      return;
    }
    this.turn = BLACK;
    this.msg = TG('轮到你（黑）');
  }

  /**
   * AI 选点：按规格书 —— 能提就提 → 被打吃就逃 → 否则在己方附近随机。
   * 找不到像样的点 ⇒ 返回 -1（停一手）。
   */
  private aiPick(): number {
    const b: number[] = this.board;
    const n: number = this.boardN();
    const legal: number[] = legalMoves(b, WHITE, n, this.koStr);
    if (legal.length === 0) {
      return -1;
    }
    // ① 能提子：提得最多的一手
    let bestCap: number = -1;
    let bestCapMove: number = -1;
    for (let k = 0; k < legal.length; k++) {
      const nb: number[] = placeStone(b, legal[k], WHITE, n) as number[];
      const got: number = capturedBy(b, nb, WHITE);
      if (got > bestCap) {
        bestCap = got;
        bestCapMove = legal[k];
      }
    }
    if (bestCap > 0) {
      return bestCapMove;
    }
    // ② 自己有只剩 1 气的块 ⇒ 逃（下在它的气上）
    let inDanger: number = -1;
    for (let i = 0; i < b.length; i++) {
      if (b[i] !== WHITE) {
        continue;
      }
      const g: number[] = groupOf(b, i, n);
      if (libsOf(b, g, n) === 1) {
        const libs: number[] = nbrs(g[0], n);
        for (let k = 0; k < libs.length; k++) {
          if (b[libs[k]] === EMPTY) {
            inDanger = libs[k];
          }
        }
        if (inDanger >= 0) {
          break;
        }
      }
    }
    if (inDanger >= 0 && legal.indexOf(inDanger) >= 0) {
      return inDanger;
    }
    // ③ 己方棋子附近（1 格内）的空点里挑；没有就全盘挑
    const near: number[] = [];
    for (let k = 0; k < legal.length; k++) {
      const cur: number[] = nbrs(legal[k], n);
      for (let j = 0; j < cur.length; j++) {
        if (b[cur[j]] === WHITE) {
          near.push(legal[k]);
          break;
        }
      }
    }
    const pool: number[] = near.length > 0 ? near : legal;
    if (this.aiLevel === 0) {
      return pool[this.rnd() % pool.length];
    }
    // 1/2 档：先排除"下完自己只有 1 气"的点（除非提过子）
    const safe: number[] = [];
    for (let k = 0; k < pool.length; k++) {
      const nb: number[] = placeStone(b, pool[k], WHITE, n) as number[];
      const j: number = pool[k];
      if (libsAt(nb, j, n) >= 2) {
        safe.push(pool[k]);
      }
    }
    if (safe.length === 0) {
      return pool[this.rnd() % pool.length];
    }
    if (this.aiLevel === 1) {
      return safe[this.rnd() % safe.length];
    }
    // 2 档：在安全点里挑"我下完气最多"的
    let bestLibs: number = -1;
    let bestMv: number = safe[0];
    for (let k = 0; k < safe.length; k++) {
      const nb: number[] = placeStone(b, safe[k], WHITE, n) as number[];
      const l: number = libsAt(nb, safe[k], n);
      if (l > bestLibs) {
        bestLibs = l;
        bestMv = safe[k];
      }
    }
    return bestMv;
  }

  // ── 联机 ────────────────────────────────────────────────
  private onRemote(d: string): void {
    if (d === LAN_RESTART) {
      this.reset();
      return;
    }
    if (d === LAN_FLIP) {
      // 只翻手（重开用）：棋盘不动，把本地 turn 对齐
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      return;
    }
    if (d === LAN_PASS) {
      this.passStreak++;
      this.koStr = '';
      this.moves++;
      this.lastMove = -1;
      if (this.passStreak >= 2) {
        this.endGame();
        return;
      }
      this.turn = LanMatch.myTurn() ? BLACK : WHITE;
      this.msg = this.turn === BLACK ? '联机：轮到你' : TG('联机：等对手落子…');
      return;
    }
    const i: number = Number.parseInt(d, 10);
    if (isNaN(i) || this.over || i < 0 || i >= this.cellCount()) {
      return;
    }
    if (!this.play(i, WHITE)) {
      return;
    }
    if (this.board.indexOf(EMPTY) < 0) {
      this.endGame();
      return;
    }
    this.turn = LanMatch.myTurn() ? BLACK : WHITE;
    this.msg = this.turn === BLACK ? '联机：轮到你' : TG('联机：等对手落子…');
  }

  /** 重开：联机要通知对方一起重置，并把回合翻回房主（先手执黑） */
  private restartTap(): void {
    if (!LanMatch.isActive()) {
      this.reset();
      return;
    }
    const iAmHost: boolean = LanMatch.mySide() === Side.HOST;
    const turnWasHost: boolean = iAmHost ? LanMatch.myTurn() : !LanMatch.myTurn();
    this.reset();
    LanMatch.record(LAN_RESTART);
    if (turnWasHost) {
      LanMatch.record(LAN_FLIP);        // 只翻手，不是停一手
    }
    this.turn = LanMatch.myTurn() ? BLACK : WHITE;
  }

  // ── 界面 ────────────────────────────────────────────────
  private stoneAt(r: number, c: number): number {
    const i: number = r * this.boardN() + c;
    return this.board.length > i ? this.board[i] : EMPTY;
  }

  private isStar(r: number, c: number): boolean {
    return STARS.indexOf(r * this.boardN() + c) >= 0;
  }

  private isLast(r: number, c: number): boolean {
    return this.lastMove === r * this.boardN() + c;
  }

  private lineInk(): string {
    return this.theme.isDark ? '#6B7280' : '#8A7B63';
  }

  private stoneColorOf(v: number): string {
    return v === BLACK ? '#111827' : '#FFFFFF';
  }

  private canTap(r: number, c: number): boolean {
    return !this.over && this.turn === BLACK && this.stoneAt(r, c) === EMPTY
      && (!LanMatch.isActive() || LanMatch.myTurn());
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.statBox(0)
        this.statBox(1)
        this.statBox(2)
      }
      .width('100%')

      // 棋盘：9×9 交叉点用「整格线 + 棋子」画；★ 宽驱动，别叠 layoutWeight
      Column() {
        ForEach(IDX, (r: number) => {
          Row() {
            ForEach(IDX, (c: number) => {
              this.pointCell(r, c)
            }, (c: number) => 'gc' + c)
          }
          .width('100%')
          .layoutWeight(1)
        }, (r: number) => 'gr' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#2A2118' : '#E8C88C')
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(this.scoreText.length > 0 ? this.scoreText + '　' + this.msg : this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('停一手'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.passTap();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .onClick(() => {
            Haptics.tap();
            this.restartTap();
          })
      }
      .width('100%')

      Text(TG('黑先 · 无气提子 · 打劫不能立刻提回 · 双方停一手后按中国规则数子（白贴 6.5 目）'))
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

  /** 顶部小格：kind 0=我提子 1=对方提子 2=手数（只收种类，不收值） */
  @Builder
  statBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('我提子') : (kind === 1 ? (LanMatch.isActive() ? '对手提子' : '电脑提子') : TG('手数')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.myCap) : (kind === 1 ? String(this.foeCap) : String(this.moves)))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /**
   * 一个交叉点：**只收 (r,c) 位置**，棋子/星位/最后一手标记都在内部读状态。
   * ⛔ 绝不写成 `this.pointCell(this.board[i])` —— `@Builder` 按值传参不建立观察，
   *    那样棋盘会永远停在开局（真机踩过：274 文件/890 处）。
   */
  @Builder
  pointCell(r: number, c: number) {
    Stack() {
      // 横线 / 竖线（画满整格，最外圈自然就是棋盘边线）
      Row().width('100%').height(1).backgroundColor(this.lineInk())
      Column().width(1).height('100%').backgroundColor(this.lineInk())
      if (this.isStar(r, c) && this.stoneAt(r, c) === EMPTY) {
        Row().width(5).height(5).borderRadius(Radius.full).backgroundColor(this.lineInk())
      }
      if (this.stoneAt(r, c) !== EMPTY) {
        Row()
          .width('80%')
          .aspectRatio(1)
          .borderRadius(Radius.full)
          .backgroundColor(this.stoneColorOf(this.stoneAt(r, c)))
          .border({ width: 1, color: this.stoneAt(r, c) === WHITE ? '#9CA3AF' : '#000000' })
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
      }
      if (this.isLast(r, c) && this.stoneAt(r, c) !== EMPTY) {
        Row()
          .width('26%')
          .aspectRatio(1)
          .borderRadius(Radius.full)
          .backgroundColor(Palette.rose)
      }
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.canTap(r, c) ? '#15FFFFFF' : Color.Transparent)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.tapPoint(r, c);
    })
  }
}
