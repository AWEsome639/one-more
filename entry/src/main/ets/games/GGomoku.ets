/**
 * 五子棋 15×15 —— 人机对战（人执黑先行）
 *
 * AI：**启发式评分**（不搜博弈树）——
 *   ① 先看能不能一子成五 ⇒ 直接赢
 *   ② 再看对手有没有"下这里就成五"的点 ⇒ 必堵
 *   ③ 否则对每个空点算 `我方成形分 + 0.95 × 对手成形分 + 位置分`，取最高
 *   成形分按方向取 9 格窗口做棋形匹配：成五 / 活四 / 冲四 / 活三 / 眠三 / 活二 / 眠二
 *
 * 交互：点空点落子（电脑延迟 260ms 落子，可悔棋）；连成五子（含长连）判胜
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch, Side } from '../core/LanMatch';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const SIZE: number = 15;
const CELLS: number = SIZE * SIZE;
/**
 * ★★ 局域网对战（2026-10-13，P12）
 * 走子编码 = **棋盘下标**（"0".."n²-1"）。围棋/五子棋盘没有"我这半边"的概念，
 * 两边看到的是**同一张绝对坐标盘** ⇒ 不需要像播棋那样做编号映射，直接传下标 ✓
 * 每台设备都把自己当 ●（HUMAN）、对方当 ○（AI）⇒ 画面永远"我在下黑棋"。
 * 哨兵：'R' 重开（对方整盘重置）、'P' 空过（只翻手；重开时把回合翻回房主先手用）。
 */
const LAN_PASS: string = 'P';
const LAN_RESTART: string = 'R';
const EMPTY: number = 0;
const HUMAN: number = 1;
const AI: number = 2;
const DRAW: number = 3;
const FIVE: number = 100000;

/** 15 个下标（避免每次 build 重新造数组） */
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

/** 4 个方向：横 / 竖 / 撇 / 捺 */
const DIRS: number[][] = [[1, 0], [0, 1], [1, 1], [1, -1]];

/** 把一段棋形串打分（串里：1=我方 2=对方 0=空 3=出界） */
function shapeScore(s: string): number {
  if (s.indexOf('11111') >= 0) {
    return FIVE;                                  // 成五
  }
  if (s.indexOf('011110') >= 0) {
    return 12000;                                 // 活四
  }
  if (s.indexOf('011112') >= 0 || s.indexOf('211110') >= 0
    || s.indexOf('11011') >= 0 || s.indexOf('10111') >= 0 || s.indexOf('11101') >= 0) {
    return 3600;                                  // 冲四 / 跳四
  }
  if (s.indexOf('01110') >= 0 || s.indexOf('010110') >= 0 || s.indexOf('011010') >= 0) {
    return 1200;                                  // 活三
  }
  if (s.indexOf('001112') >= 0 || s.indexOf('211100') >= 0 || s.indexOf('010112') >= 0
    || s.indexOf('211010') >= 0 || s.indexOf('011012') >= 0 || s.indexOf('210110') >= 0
    || s.indexOf('10011') >= 0 || s.indexOf('11001') >= 0 || s.indexOf('10101') >= 0) {
    return 320;                                   // 眠三
  }
  if (s.indexOf('00110') >= 0 || s.indexOf('01100') >= 0 || s.indexOf('01010') >= 0) {
    return 140;                                   // 活二
  }
  if (s.indexOf('00112') >= 0 || s.indexOf('21100') >= 0 || s.indexOf('01012') >= 0
    || s.indexOf('21010') >= 0 || s.indexOf('10010') >= 0 || s.indexOf('01001') >= 0) {
    return 60;                                    // 眠二
  }
  return 0;
}

/** 取以 (x,y) 为中心、沿 (dx,dy) 的 9 格窗口串，中心按"已放我方子"算 */
function buildLine(board: number[], x: number, y: number, dx: number, dy: number, me: number, size: number): string {
  let s: string = '';
  for (let k = -4; k <= 4; k++) {
    if (k === 0) {
      s += '1';
      continue;
    }
    const nx: number = x + dx * k;
    const ny: number = y + dy * k;
    // ⚠️ 一律用本局边长 size（难度会改棋盘；写死 SIZE 会在 11/20 路时算错坐标）
    if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
      s += '3';
      continue;
    }
    const v: number = board[ny * size + nx];
    s += v === EMPTY ? '0' : (v === me ? '1' : '2');
  }
  return s;
}

/** 某空点放 me 的四个方向成形分之和 */
function pointScore(board: number[], x: number, y: number, me: number, size: number): number {
  let total: number = 0;
  for (let d = 0; d < DIRS.length; d++) {
    total += shapeScore(buildLine(board, x, y, DIRS[d][0], DIRS[d][1], me, size));
  }
  return total;
}

/** 这一点放 me 之后，能形成"四"或"活三"级别的方向数（≥2 = 双威胁，基本必胜） */
function threatCount(board: number[], x: number, y: number, me: number, size: number): number {
  let n: number = 0;
  for (let d = 0; d < DIRS.length; d++) {
    if (shapeScore(buildLine(board, x, y, DIRS[d][0], DIRS[d][1], me, size)) >= 1200) {
      n++;
    }
  }
  return n;
}

/** 周围 8 格的棋子数（越热闹越值得下） */
function neighborBonus(board: number[], x: number, y: number, size: number): number {
  let n: number = 0;
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      if (dx === 0 && dy === 0) {
        continue;
      }
      const nx: number = x + dx;
      const ny: number = y + dy;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
        continue;
      }
      if (board[ny * size + nx] !== EMPTY) {
        n++;
      }
    }
  }
  return n;
}


/**
 * ★ 2026-10-13：候选点生成 —— (x,y) 周围 R 格内有没有棋子
 *   五子棋 AI 的标准优化：远离棋子的空点几乎不可能是好点，直接跳过。
 *   依据见 knowledge/cards/棋类AI-算法与难度分级.md §一①
 */
function nearStone(board: number[], x: number, y: number, size: number, r: number): boolean {
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      const nx: number = x + dx;
      const ny: number = y + dy;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
        continue;
      }
      if (board[ny * size + nx] !== EMPTY) {
        return true;
      }
    }
  }
  return false;
}

/** 电脑选点：返回格子下标，-1 = 没地方下了 */

/**
 * ★★ 2026-10-13 AI 拔高 修改 ⑤：**两步预判**（困难档专用）
 *
 * 思路（依据 knowledge/cards/棋类AI-算法与难度分级.md §一③）：
 *   贪心 AI 的通病是"只看我这一手多好"，不看【我下完之后对手能干什么】。
 *   ⇒ 落子 i 后，扫一遍对手的最佳回应分；分越高说明这一手越危险。
 *
 * 成本控制：只对【前几个候选】做预判（不是全部），否则手机扛不住。
 * 返回：对手在我落子 i 之后能取得的最高 pointScore
 */
function opponentBestAfter(board: number[], size: number, myMove: number, self: number): number {
  board[myMove] = self;
  let bestOpp: number = 0;
  for (let j = 0; j < size * size; j++) {
    if (board[j] !== EMPTY) {
      continue;
    }
    const jx: number = j % size;
    const jy: number = Math.floor(j / size);
    if (!nearStone(board, jx, jy, size, 2)) {
      continue;
    }
    const v: number = pointScore(board, jx, jy, HUMAN, size);
    if (v >= FIVE) {              // 对手能成五 ⇒ 这一手是送死，直接返回最大值
      board[myMove] = EMPTY;
      return FIVE * 2;
    }
    if (v > bestOpp) {
      bestOpp = v;
    }
  }
  board[myMove] = EMPTY;
  return bestOpp;
}

/**
 * ★★ 2026-10-13 AI 拔高 修改 ④：难度真正作用到 AI 强度
 *
 * 原来：难度只改【棋盘大小】⇒ 简单档(9×9)和困难档(15×15)的电脑**一样聪明** ✗
 * 现在：level 控制 AI 的"认真程度"（依据见 knowledge/cards/棋类AI-算法与难度分级.md §二）
 *   · 0 简单：**35% 概率不走最优**（故意露破绽）⇒ 新手能赢
 *   · 1 中等：全力下（= 原来的水平）
 *   · 2 困难：全力下 + **不会漏掉"对手一步成五"**（保险起见再扫一遍）
 */
function chooseMove(board: number[], size: number, level: number): number {
  let best: number = -1;
  let bestVal: number = -1;
  let block: number = -1;
  let blockVal: number = -1;
  let fork: number = -1;        // 我下这里能形成双威胁 ⇒ 两步内必胜
  let forkVal: number = -1;
  let blockFork: number = -1;   // 对手下这里能形成双威胁 ⇒ 必须提前拆
  let blockForkVal: number = -1;

  const center: number = (size - 1) / 2;
  const hasStone: boolean = board.some((v: number) => v !== EMPTY);
  for (let i = 0; i < size * size; i++) {
    if (board[i] !== EMPTY) {
      continue;
    }
    const x: number = i % size;
    const y: number = Math.floor(i / size);
    // ★★ 2026-10-13 AI 拔高 修改 ③（**性能关键**）：
    //   候选点生成 —— 只考虑【已有棋子周围 2 格内】的空点
    //   依据：五子棋 AI 的标准做法（见 knowledge/cards/棋类AI-算法与难度分级.md）
    //   效果：15×15 从 225 个候选降到几十个 ⇒ 同样的时间能搜更深
    //   ⚠️ 棋盘全空时（第一手）不筛，直接下天元附近
    if (hasStone && !nearStone(board, x, y, size, 2)) {
      continue;
    }
    const mine: number = pointScore(board, x, y, AI, size);
    if (mine >= FIVE) {
      return i;                                   // ① 一子成五，直接赢
    }
    const theirs: number = pointScore(board, x, y, HUMAN, size);
    const bonus: number = (size * 2 - Math.abs(x - center) - Math.abs(y - center))
      + neighborBonus(board, x, y, size) * 6;
    // ★★ 2026-10-13 AI 拔高（奥森：「电脑的水平实在是太低了」）修改 ①：
    //   原来只堵 FIVE（成五）⇒ 对手的【活四】(12000) 不算"必须堵"，
    //   虽然综合分通常也会选它，但在有更高即时收益时会漏 ⇒ 显式纳入。
    if (theirs >= FIVE || theirs >= 12000) {      // ② 对手成五 / 成活四 ⇒ 必须堵
      const bv: number = theirs + mine * 0.001;
      if (bv > blockVal) {
        blockVal = bv;
        block = i;
      }
    }
    if (threatCount(board, x, y, AI, size) >= 2) {   // ③ 我的双威胁点
      const fv: number = mine + bonus;
      if (fv > forkVal) {
        forkVal = fv;
        fork = i;
      }
    }
    if (threatCount(board, x, y, HUMAN, size) >= 2) {  // ④ 对手的双威胁点
      const bfv: number = theirs + bonus;
      if (bfv > blockForkVal) {
        blockForkVal = bfv;
        blockFork = i;
      }
    }
    const val: number = mine + theirs * 0.95 + bonus;   // ⑤ 攻守综合分
    if (val > bestVal) {
      bestVal = val;
      best = i;
    }
  }
  if (block >= 0) {
    return block;
  }
  // ★★ 2026-10-13 AI 拔高 修改 ②（**最关键的一处**）：
  //   原来顺序是「我的双威胁 → 堵对手双威胁」，这是错的：
  //     我下 A 成双活三、对手下 B 也成双活三 ⇒ 我先下 A ⇒ 他下 B ⇒ **他先成五，我挡不住** ⇒ 输
  //   ⇒ 正确：**先拆掉对手的双威胁**，再考虑自己的
  //   ⇒ 这一处改动对"电脑太弱"的改善最直接（原来会被双三杀穿）
  if (blockFork >= 0) {
    return blockFork;
  }
  if (fork >= 0) {
    return fork;
  }
  // ★★ 难度 2（困难）：两步预判 —— 若"我下 best 之后对手能成大威胁"，换一个更安全的点
  //   只在困难档跑（成本换强度），且最多重试 3 次，避免手机卡
  if (level >= 2 && best >= 0) {
    let guard: number = 0;
    while (guard < 3) {
      const oppBest: number = opponentBestAfter(board, size, best, AI);
      if (oppBest < 12000) {      // 对手拿不到活四及以上 ⇒ 这一手够安全
        break;
      }
      // 不安全 ⇒ 找一个"对手回应后威胁更小"的替代点
      let alt: number = -1;
      let altVal: number = -1;
      for (let k = 0; k < size * size; k++) {
        if (board[k] !== EMPTY || k === best) {
          continue;
        }
        const kx: number = k % size;
        const ky: number = Math.floor(k / size);
        if (!nearStone(board, kx, ky, size, 2)) {
          continue;
        }
        const mineK: number = pointScore(board, kx, ky, AI, size);
        const oppK: number = opponentBestAfter(board, size, k, AI);
        const safe: number = mineK - oppK * 0.9;
        if (safe > altVal) {
          altVal = safe;
          alt = k;
        }
      }
      if (alt < 0 || altVal <= 0) {
        break;
      }
      best = alt;
      guard++;
    }
  }

  // ★ 难度 0（简单）：35% 概率【故意不走最优】⇒ 露个破绽给玩家
  //   这是"难度分级"的标准做法：不是把 AI 变笨，而是让它【有时不认真】
  if (level <= 0 && best >= 0 && Math.random() < 0.35) {
    const pool: number[] = [];
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) {
        continue;
      }
      const x: number = i % size;
      const y: number = Math.floor(i / size);
      if (nearStone(board, x, y, size, 2)) {
        pool.push(i);
      }
    }
    if (pool.length > 0) {
      return pool[Math.floor(Math.random() * pool.length)];
    }
  }
  return best;
}

/** 沿一个方向数同色连子 */
function countDir(board: number[], x: number, y: number, dx: number, dy: number, who: number, size: number): number {
  let n: number = 0;
  let cx: number = x + dx;
  let cy: number = y + dy;
  while (cx >= 0 && cy >= 0 && cx < size && cy < size && board[cy * size + cx] === who) {
    n++;
    cx += dx;
    cy += dy;
  }
  return n;
}

/** idx 处落 who 之后是否连成五子（含长连） */
function fiveAt(board: number[], idx: number, who: number, size: number): boolean {
  const x: number = idx % size;
  const y: number = Math.floor(idx / size);
  for (let d = 0; d < DIRS.length; d++) {
    const dx: number = DIRS[d][0];
    const dy: number = DIRS[d][1];
    const n: number = 1 + countDir(board, x, y, dx, dy, who, size) + countDir(board, x, y, -dx, -dy, who, size);
    if (n >= 5) {
      return true;
    }
  }
  return false;
}

/** 棋子配色：黑（人）/ 白（电脑），深浅主题都给一圈描边保证看得见 */
function stoneColor(who: number, theme: Theme): ResourceColor {
  if (who === HUMAN) {
    return theme.isDark ? Palette.inkSoft : Palette.ink;
  }
  return theme.isDark ? Palette.dInk : Palette.surface;
}

@Component
export struct GGomoku {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 SIZE=15）
  //   ⚠️ 原本 ForEach(IDX, …) 是常量数组，已改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(15);
  /** ★★ 2026-10-14 修复【死动画】：原来 .scale({x:1,y:1}) 是常量 ⇒ 落子动效从没生效
   *  现在：落子时先 0.6 再弹回 1（注释里原本就写着「从 0.6 弹到 1」）*/
  @State private pop: number = 1;
  @State private popAt: number = -1;   // 哪一手刚落子

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State board: number[] = [];
  @State turn: number = HUMAN;
  @State thinking: boolean = false;
  @State over: boolean = false;
  @State winner: number = EMPTY;      // EMPTY=未分 1=人 2=电脑 3=平局
  @State lastMove: number = -1;
  @State steps: number = 0;

  private history: number[] = [];
  private startAt: number = 0;
  private aiTimer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机：对方的落子 = 本局「AI 的那一步」
    LanMatch.setHandler((d: string) => {
      this.onRemote(d);
    });
    this.reset();
  }

  /** 宿主点了「换一局」：联机时要通知对方，否则两边棋盘不一样 */
  onRestart(): void {
    this.restartTap();
  }

  aboutToDisappear(): void {
    if (this.aiTimer >= 0) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  /**
   * 本局棋盘边长。★ 联机时**钉死标准 15 路**：难度会改边长（简单 11 / 普通 15 / 困难 20），
   * 两边不同 ⇒ 下标语义不一样 ⇒ 直接对不了局。
   */
  private pickSize(): number {
    return LanMatch.isActive() ? SIZE : GameDiff.sizeNow(15);
  }

  /** 本局格子数（⛔ 不要再用模块常量 CELLS —— 边长是难度驱动的） */
  private cellCount(): number {
    return this.diffTotal * this.diffTotal;
  }

  private reset(): void {
    if (this.aiTimer >= 0) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
    this.diffTotal = this.pickSize();
    this.board = new Array<number>(this.cellCount()).fill(EMPTY);
    this.turn = HUMAN;
    // ★ 联机：本地 turn 必须跟"轮到谁"对齐（否则加入方开局会显示"轮到你"却点不动）
    if (LanMatch.isActive()) {
      this.turn = LanMatch.myTurn() ? HUMAN : AI;
    }
    this.thinking = false;
    this.over = false;
    this.winner = EMPTY;
    this.lastMove = -1;
    // ★ 落子弹跳：0.6 → 1（150ms）
    this.popAt = this.lastMove;
    this.pop = 0.6;
    setTimeout(() => { this.pop = 1; }, 16);
    this.steps = 0;
    this.history = [];
    this.startAt = Date.now();
  }

  /**
   * 重开（按钮与宿主「换一局」都走这里）
   * ★ 联机时必须通知对方一起重置；并把回合翻回房主先手
   */
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
      LanMatch.record(LAN_PASS);      // 再翻一次 ⇒ 回合回到房主
    }
    this.turn = LanMatch.myTurn() ? HUMAN : AI;
  }

  /** 收到对方的落子（LanMatch 转进来）：对方的下标直接可用，落成 ○(AI) */
  private onRemote(d: string): void {
    if (d === LAN_RESTART) {
      this.reset();
      return;
    }
    if (d === LAN_PASS) {
      this.turn = LanMatch.myTurn() ? HUMAN : AI;
      return;
    }
    const idx: number = Number.parseInt(d, 10);
    if (isNaN(idx) || this.over || idx < 0 || idx >= this.cellCount() || this.board[idx] !== EMPTY) {
      return;
    }
    const win: boolean = this.place(idx, AI);
    if (win) {
      this.over = true;
      this.winner = AI;
      this.finish(false);
      return;
    }
    if (this.steps >= this.cellCount()) {
      this.over = true;
      this.winner = DRAW;
      this.finish(false);
      return;
    }
    this.turn = LanMatch.myTurn() ? HUMAN : AI;
  }

  private place(idx: number, who: number): boolean {
    const b: number[] = this.board.slice();
    b[idx] = who;
    this.board = b;
    this.history.push(idx);
    this.lastMove = idx;
    this.steps++;
    return fiveAt(b, idx, who, this.diffTotal);
  }

  /** 人落子 */
  private humanTap(idx: number): void {
    if (this.over || this.thinking || this.turn !== HUMAN || this.board[idx] !== EMPTY) {
      return;
    }
    // ★ 联机：不是我的回合就不接受点击
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      return;
    }
    const win: boolean = this.place(idx, HUMAN);
    if (LanMatch.isActive()) {
      LanMatch.record(String(idx));      // ★ 先广播（对方要靠这一步才能算出同样的胜负）
      if (win) {
        this.over = true;
        this.winner = HUMAN;
        this.finish(true);
        return;
      }
      if (this.steps >= this.cellCount()) {
        this.over = true;
        this.winner = DRAW;
        this.finish(false);
        return;
      }
      this.turn = LanMatch.myTurn() ? HUMAN : AI;
      return;                            // ★ 联机不跑 AI（对手就是那个人）
    }
    if (win) {
      this.over = true;
      this.winner = HUMAN;
      this.finish(true);
      return;
    }
    if (this.steps >= this.cellCount()) {
      this.over = true;
      this.winner = DRAW;
      this.finish(false);
      return;
    }
    this.turn = AI;
    this.thinking = true;
    if (this.aiTimer >= 0) {
      clearTimeout(this.aiTimer);
    }
    this.aiTimer = setTimeout(() => {
      this.aiMove();
    }, Motion.slow);
  }

  /** 电脑落子 */
  private aiMove(): void {
    this.aiTimer = -1;
    if (this.over) {
      this.thinking = false;
      return;
    }
    const idx: number = chooseMove(this.board, this.diffTotal, GameDiff.now());
    if (idx < 0) {
      this.thinking = false;
      this.over = true;
      this.winner = DRAW;
      this.finish(false);
      return;
    }
    const win: boolean = this.place(idx, AI);
    this.thinking = false;
    if (win) {
      this.over = true;
      this.winner = AI;
      this.finish(false);
      return;
    }
    if (this.steps >= this.cellCount()) {
      this.over = true;
      this.winner = DRAW;
      this.finish(false);
      return;
    }
    this.turn = HUMAN;
  }

  /** 悔棋：退回到"轮到你"（通常退两手：电脑 + 你） */
  private undo(): void {
    // ★ 联机不能单方悔棋（两边棋盘会不一致）⇒ 直接禁用
    if (LanMatch.isActive() || this.thinking || this.over || this.history.length === 0) {
      return;
    }
    const b: number[] = this.board.slice();
    let n: number = 0;
    while (this.history.length > 0 && n < 2) {
      const idx: number = this.history[this.history.length - 1];
      this.history.splice(this.history.length - 1, 1);
      b[idx] = EMPTY;
      n++;
    }
    this.board = b;
    this.turn = HUMAN;
    this.steps = this.history.length;
    this.lastMove = this.history.length > 0 ? this.history[this.history.length - 1] : -1;
  }

  private finish(solved: boolean): void {
    const sec: number = Math.max(1, Math.floor((Date.now() - this.startAt) / 1000));
    const r: GameResult = {
      gameId: 'gomoku',
      solved: solved,
      score: solved ? Math.max(200, 1200 - this.steps * 8) : 0,
      durationMs: Date.now() - this.startAt
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private countOf(who: number): number {
    let n: number = 0;
    for (let i = 0; i < this.board.length; i++) {
      if (this.board[i] === who) {
        n++;
      }
    }
    return n;
  }

  private statusText(): string {
    if (this.over) {
      if (this.winner === HUMAN) {
        return TG('🎉 五子连珠，你赢了！');
      }
      if (this.winner === AI) {
        return LanMatch.isActive() ? '对手连成五子，再来一局？' : '电脑连成五子，再来一局？';
      }
      return TG('平局，棋盘满了');
    }
    if (LanMatch.isActive()) {
      return this.turn === HUMAN ? '联机：轮到你落子（你 ●）' : TG('联机：等对手落子…');
    }
    return this.thinking ? '电脑正在算…' : '轮到你落子（黑先）';
  }

  build() {
    Column({ space: Space.md }) {
      // ── 顶部信息 ──
      Row({ space: Space.md }) {
        // ⚠️ 只传「种类」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三格整局不刷新
        Column({ space: 2 }) {
        Text(true ? '手数' : (false ? (LanMatch.isActive() ? '我 ●' : '你 ●')
        : (LanMatch.isActive() ? '对手 ○' : '电脑 ○')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(true ? String(this.steps)
        : (false ? String(this.countOf(HUMAN)) : String(this.countOf(AI))))
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
        Text(false ? '手数' : (true ? (LanMatch.isActive() ? '我 ●' : '你 ●')
        : (LanMatch.isActive() ? '对手 ○' : '电脑 ○')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(false ? String(this.steps)
        : (true ? String(this.countOf(HUMAN)) : String(this.countOf(AI))))
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
        Text(false ? '手数' : (false ? (LanMatch.isActive() ? '我 ●' : '你 ●')
        : (LanMatch.isActive() ? '对手 ○' : '电脑 ○')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(false ? String(this.steps)
        : (false ? String(this.countOf(HUMAN)) : String(this.countOf(AI))))
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

      // ── 棋盘 ──
      Column({ space: 0 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 0 }) {
            ForEach(this.rowIdx(), (c: number) => {
              // ★★★ 2026-10-13 奥森指出的规则性错误修复：
              //   「五子棋怎么是下在格子里的？不应该是交叉点上吗？」
              //   ⇒ 原来每格填色 + 描边 = 【国际象棋式格子棋盘】✗
              //   ⇒ 改成围棋/五子棋的正确画法：
              //       · 每格画【十字线】（横线 + 竖线，都过格心）
              //       · 棋子画在格心 ⇒ 正好落在【线的交叉点】上 ✅
              //       · 去掉格子的底色与边框，只留木色棋盘
              Stack() {
              // 横线（过格心，贯穿整格宽）
              Row()
              .width('100%').height(1)
              .backgroundColor(this.theme.line)
              // 竖线（过格心，贯穿整格高）
              Column()
              .width(1).height('100%')
              .backgroundColor(this.theme.line)
              // 棋子：落在格心 = 交叉点上
              if (this.board[(r * this.diffTotal + c)] !== EMPTY) {
              Row()
              .width('78%')
              .aspectRatio(1)
              .borderRadius(Radius.full)
              .backgroundColor(stoneColor(this.board[(r * this.diffTotal + c)], this.theme))
              .border({
              width: this.lastMove === (r * this.diffTotal + c) ? 2 : 1,
              color: this.lastMove === (r * this.diffTotal + c) ? Palette.rose : Palette.inkFaint
              })
              // ★ 落子动效：从 0.6 弹到 1（有"啪"一下落子的感觉）
              // ★ 修复死动画：读 pop（刚落的那一手从 0.6 弹到 1）
              .scale({
                x: (r * this.diffTotal + c) === this.popAt ? this.pop : 1,
                y: (r * this.diffTotal + c) === this.popAt ? this.pop : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.spring() })
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .onClick(() => {
              Haptics.tick();
              this.humanTap((r * this.diffTotal + c));
              })
            }, (c: number) => 'gk' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'gkr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      // ★ 棋盘底色：木色（围棋/五子棋盘的样子），不再用页面底色
      .backgroundColor(this.theme.isDark ? '#3A2E22' : '#E8C99B')
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      // ── 状态 ──
      Text(this.statusText())
        .fontSize(FontSize.sm)
        .fontColor(this.over
          ? (this.winner === HUMAN ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)

      // ── 操作 ──
      Row({ space: Space.md }) {
        Button(TG('悔棋'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .enabled(!LanMatch.isActive())      // ★ 联机不能单方悔棋
          .onClick(() => {
            Haptics.tap();
            this.undo();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.restartTap();
          })
      }
      .width('100%')

      Text(LanMatch.isActive()
        ? '联机：你执 ● 先行（房主先手）；对方落 ○，五子连珠即胜 · 悔棋已禁用'
        : '你执黑先行；电脑用启发式评分抢攻与堵截，连成五子即胜')
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** 顶部小格：kind 0=手数 1=我的子 2=对方的子（联机时叫"对手"） */



}
