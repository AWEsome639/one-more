/**
 * GomokuSearch —— 五子棋 α-β 搜索（2026-10-23 新增）
 *
 * 为什么要独立一个文件：
 *   GGomoku.ets 830 行、其中 AI 部分是"一步启发式"，改它风险大。
 *   搜索器只用【棋盘 + 尺寸 + 难度】三个入参，不碰界面状态 ⇒ 单独一个文件最安全。
 *
 * 为什么五子棋必须上搜索：
 *   一步启发式只能看到"现在这一步的分"，看不到"我下这里、他下那里、我再下"。
 *   五子棋的双三/四三杀是 **2–3 步才能成形** 的，一步评估必然漏 ⇒ 电脑被双三杀穿。
 *
 * 实现要点（每一条都是踩坑后的选择）：
 *   ① 置换表用 Zobrist 双 32 位（h1 当 key、h2 当验证），不用 board.join('')（每节点 O(n) 太慢）
 *   ② 迭代加深：从 depth 2 起，每层 +2，超预算就交**上一层的答案**（永远有合法招）
 *   ③ 时间预算：Date.now() 检查，不用 setTimeout（ArkTS 里前者更可靠）
 *   ④ 候选点只取"已有棋子周围 2 格内"，并按启发分排序 ⇒ 剪枝率大幅提高
 *   ⑤ 任何异常都返回 -1，让调用方回落到原来的启发式（绝不让游戏打不开）
 */

/** 空 / 我 / 对手 —— 与 GGomoku 里的常量保持同值（0/1/2），但这里含义是"以 search 方视角" */
const EMPTY: number = 0;
const MAX_SCORE: number = 100000;
const WIN: number = 100000;

/** 置换表条目 */
interface TtEntry {
  depth: number;
  score: number;
  flag: number;      // 0=精确 1=下界 2=上界
  move: number;
  h2: number;        // 第二个哈希，用来验证不是碰撞
}

/** 候选着法 */
interface Cand {
  idx: number;
  score: number;
  /** 我在这里落子的成形分（>=90000 表示我一子成五） */
  mine: number;
  /** 对手在这里落子的成形分（>=90000 表示对手能一子成五 ⇒ 我必须堵） */
  theirs: number;
}

/** 搜索统计（给调试与断言用） */
export interface SearchStat {
  nodes: number;
  depth: number;
  ms: number;
  ttHit: number;
  /** 是否因为超时/异常而回落到启发式 */
  fellBack: boolean;
}

/** 4 个方向 */
const DIRS: number[][] = [[1, 0], [0, 1], [1, 1], [1, -1]];

/**
 * 棋形分（与 GGomoku 的 shapeScore 同构，但这里独立一份 —— 不 import 那个文件，
 * 免得搜索器依赖游戏 UI 模块，导致将来复用困难）
 */
function shape(s: string): number {
  if (s.indexOf('11111') >= 0) {
    return 100000;
  }
  if (s.indexOf('011110') >= 0) {
    return 12000;
  }
  if (s.indexOf('011112') >= 0 || s.indexOf('211110') >= 0
    || s.indexOf('11011') >= 0 || s.indexOf('10111') >= 0 || s.indexOf('11101') >= 0) {
    return 3600;
  }
  if (s.indexOf('01110') >= 0 || s.indexOf('010110') >= 0 || s.indexOf('011010') >= 0) {
    return 1200;
  }
  if (s.indexOf('001112') >= 0 || s.indexOf('211100') >= 0 || s.indexOf('010112') >= 0
    || s.indexOf('211010') >= 0 || s.indexOf('011012') >= 0 || s.indexOf('210110') >= 0
    || s.indexOf('10011') >= 0 || s.indexOf('11001') >= 0 || s.indexOf('10101') >= 0) {
    return 400;
  }
  if (s.indexOf('00110') >= 0 || s.indexOf('01100') >= 0 || s.indexOf('01010') >= 0
    || s.indexOf('010010') >= 0) {
    return 120;
  }
  if (s.indexOf('000112') >= 0 || s.indexOf('211000') >= 0 || s.indexOf('001012') >= 0
    || s.indexOf('210100') >= 0 || s.indexOf('000110') >= 0 || s.indexOf('011000') >= 0) {
    return 60;
  }
  return 0;
}

/**
 * ★★★ 2026-10-23 性能修③（最大的一处）：3^9 棋形查表
 *
 * 原来 pointScore 每个方向都在**拼字符串**再调 shape()：
 *   每次评估 ≈ 40 候选 × 2 次 × 4 方向 × 9 字符 ≈ 2,880 次字符串拼接
 *   实测把搜索卡在 3 节点/ms 左右（预算 400ms 只买得到 1000 多个节点）
 * 改成：9 格各取 0/1/2 值，编码成三进制整数（3^9 = 19,683 种）⇒ 直接查表
 *   ⇒ 9 次整数运算替代 9 次字符串拼接，纯整数运算，快一个数量级
 */
const P3: number[] = [1, 3, 9, 27, 81, 243, 729, 2187, 6561];
let SHAPE_TABLE: Int32Array | null = null;

/** 建表（第一次用的时候建一次；19,683 项，几十毫秒） */
function buildShapeTable(): Int32Array {
  const t: Int32Array = new Int32Array(19683);
  const ch: string[] = ['0', '1', '2'];
  for (let code = 0; code < 19683; code++) {
    let c: number = code;
    let str: string = '';
    for (let k = 0; k < 9; k++) {
      str += ch[c % 3];
      c = Math.floor(c / 3);
    }
    t[code] = shape(str);
  }
  return t;
}

function ensureTable(): Int32Array {
  if (SHAPE_TABLE === null) {
    SHAPE_TABLE = buildShapeTable();
  }
  return SHAPE_TABLE as Int32Array;
}

/**
 * 单点成形分：以 (x,y) 为中心，四方向各取 9 格窗口（中心放 who）
 * 返回四方向之和 —— 这与 GGomoku 的 pointScore 语义一致
 */
function pointScore(board: number[], size: number, x: number, y: number, who: number): number {
  const opp: number = who === 1 ? 2 : 1;
  const table: Int32Array = ensureTable();
  let total: number = 0;
  for (let d = 0; d < 4; d++) {
    const dx: number = DIRS[d][0];
    const dy: number = DIRS[d][1];
    let code: number = 0;
    for (let k = -4; k <= 4; k++) {
      let v: number = 0;
      if (k === 0) {
        v = 1;                        // 我在这里落子 —— 先假设
      } else {
        const nx: number = x + dx * k;
        const ny: number = y + dy * k;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
          v = 2;                      // 出界当对手挡（保守）
        } else {
          const b: number = board[ny * size + nx];
          v = (b === who ? 1 : (b === opp ? 2 : 0));
        }
      }
      code = code + v * P3[k + 4];    // 三进制编码，k+4 从 0 到 8
    }
    total += table[code];
  }
  return total;
}

/**
 * ★★★ 2026-10-23 对打后重写（这是全文件最重要的一个函数）
 *
 * 第一版写成「全盘成形分求和 - 对手求和」，结果 0:2 输给旧启发式。
 * 原因：旧启发式强的是**知识**（必堵活四、拆双威胁、双三检测），
 *      我用一个粗糙的全盘求和当评估 ⇒ 那些知识全丢了 ⇒ 搜得越深越糟。
 *
 * 正解（标准做法）：**用「这个局面里我最强的一手值多少」当评估** ——
 *   它天然包含了旧启发式那套打分口径（成形分 + 防守权重 + 位置分 + 邻接分），
 *   而搜索在它之上多看几步 ⇒ 严格 ≥ 旧版。
 *
 * 口径与 GGomoku.chooseMove 的 `mine + theirs*0.95 + bonus` 一致，
 * 让搜索与启发式说同一种语言。
 */
function evaluate(board: number[], size: number, me: number, nearCount: number[]): number {
  const opp: number = me === 1 ? 2 : 1;
  const center: number = (size - 1) / 2;
  const hasStone: boolean = board.some((v: number) => v !== EMPTY);
  let best: number = -1;
  let bestVal: number = -MAX_SCORE * 2;
  for (let i = 0; i < size * size; i++) {
    if (board[i] !== EMPTY) {
      continue;
    }
    const x: number = i % size;
    const y: number = Math.floor(i / size);
    // ★ 同上：用 nearCount，别再用 nearStone（nearCount 由外部传进来，
    //   因为 evaluate 是独立函数，ArkTS 不许它用 this）
    if (hasStone && (i >= nearCount.length || nearCount[i] === 0)) {
      continue;
    }
    const mine: number = pointScore(board, size, x, y, me);
    const theirs: number = pointScore(board, size, x, y, opp);
    // 位置分：越靠中心越好（与旧启发式同一口径）
    const bonus: number = (size * 2 - Math.abs(x - center) - Math.abs(y - center));
    const val: number = mine + theirs * 0.95 + bonus;
    if (val > bestVal) {
      bestVal = val;
      best = i;
    }
  }
  if (best < 0) {
    return 0;
  }
  // 空盘/无候选时退回 0
  return bestVal;
}

/** 某点周围 r 格内有没有棋子 */
function nearStone(board: number[], size: number, x: number, y: number, r: number): boolean {
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      if (dx === 0 && dy === 0) {
        continue;
      }
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

/** 成五检测（含长连）：以 (x,y) 为中心，某方向连续 >=5 */
function fiveAt(board: number[], size: number, x: number, y: number, who: number): boolean {
  for (let d = 0; d < 4; d++) {
    const dx: number = DIRS[d][0];
    const dy: number = DIRS[d][1];
    let n: number = 1;
    for (let k = 1; k <= 4; k++) {
      const nx: number = x + dx * k;
      const ny: number = y + dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size || board[ny * size + nx] !== who) {
        break;
      }
      n++;
    }
    for (let k = 1; k <= 4; k++) {
      const nx: number = x - dx * k;
      const ny: number = y - dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size || board[ny * size + nx] !== who) {
        break;
      }
      n++;
    }
    if (n >= 5) {
      return true;
    }
  }
  return false;
}

/**
 * 主搜索器
 * 用法：
 *   const s = new GomokuSearch();
 *   const mv = s.pick(board, size, level);       // level 0/1/2
 *   if (mv < 0) 回落启发式
 *   const st = s.lastStat();                     // 拿统计
 */
export class GomokuSearch {
  private size: number = 15;
  private tt: Map<number, TtEntry> = new Map<number, TtEntry>();
  private zob: number[][] = [];        // [cell][0 或 1] → h1
  private zob2: number[][] = [];       // [cell][0 或 1] → h2
  private deadline: number = 0;
  private nodes: number = 0;
  /** ★★★ 2026-10-23 性能修：增量 Zobrist —— 落子/撤销时 XOR，不再每节点扫全盘
   *   原来是 hash(board) 每节点 O(225)，实测只有 3.7 节点/ms ⇒ 搜不到深度 4
   *   改成增量后 O(1)，同样预算下能多搜 10–50 倍节点 */
  private h1: number = 0;
  private h2: number = 0;
  /** ★★★ 2026-10-23 性能修②：邻域计数 —— nearCount[i] = 第 i 格半径 2 内有多少颗子
   *   原来每次评估都跑 nearStone()（225 格 × 25 邻格 = 5,625 次判断）
   *   实测把搜索卡在 3.7 节点/ms。改成数组后 O(1) 查询 */
  private nearCount: number[] = [];
  private ttHit: number = 0;
  private aborted: boolean = false;
  private stat: SearchStat = { nodes: 0, depth: 0, ms: 0, ttHit: 0, fellBack: false };

  constructor() {
    this.initZobrist();
  }

  /** 固定种子的伪随机，保证每次运行同一张表（便于复现） */
  private initZobrist(): void {
    let seed: number = 20261023;
    const rnd = (): number => {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    };
    this.zob = [];
    this.zob2 = [];
    for (let i = 0; i < 15 * 15; i++) {
      this.zob.push([rnd(), rnd()]);
      this.zob2.push([rnd(), rnd()]);
    }
  }

  /** 第 idx 格落子/撤子时，把半径 2 内的邻格计数 ±1 */
  private bumpNear(board: number[], size: number, idx: number, delta: number): void {
    const x0: number = idx % size;
    const y0: number = Math.floor(idx / size);
    for (let dy = -2; dy <= 2; dy++) {
      for (let dx = -2; dx <= 2; dx++) {
        if (dx === 0 && dy === 0) {
          continue;
        }
        const nx: number = x0 + dx;
        const ny: number = y0 + dy;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
          continue;
        }
        const j: number = ny * size + nx;
        if (j < this.nearCount.length) {
          this.nearCount[j] = this.nearCount[j] + delta;
        }
      }
    }
  }

  /** 从当前棋盘重建 nearCount（只在 pick 开头跑一次） */
  private rebuildNear(board: number[], size: number): void {
    const n: number = size * size;
    this.nearCount = new Array<number>(n);
    for (let i = 0; i < n; i++) {
      this.nearCount[i] = 0;
    }
    for (let i = 0; i < n; i++) {
      if (board[i] !== EMPTY) {
        this.bumpNear(board, size, i, 1);
      }
    }
  }

  /** 增量：把 (idx, who) 放进哈希 */
  private hashAdd(idx: number, who: number): void {
    if (idx < 0 || idx >= this.zob.length) {
      return;
    }
    const p: number = who === 1 ? 0 : 1;
    this.h1 = (this.h1 ^ this.zob[idx][p]) | 0;
    this.h2 = (this.h2 ^ this.zob2[idx][p]) | 0;
  }

  /** 全量重算（只在 pick 开头跑一次） */
  private hashFull(board: number[], size: number): void {
    this.h1 = 0;
    this.h2 = 0;
    for (let i = 0; i < size * size; i++) {
      const v: number = board[i];
      if (v === EMPTY || i >= this.zob.length) {
        continue;
      }
      this.hashAdd(i, v);
    }
  }

  private hash(board: number[], size: number): number[] {
    let h1: number = 0;
    let h2: number = 0;
    for (let i = 0; i < size * size; i++) {
      const v: number = board[i];
      if (v === EMPTY || i >= this.zob.length) {
        continue;
      }
      const p: number = v === 1 ? 0 : 1;
      h1 = (h1 ^ this.zob[i][p]) | 0;
      h2 = (h2 ^ this.zob2[i][p]) | 0;
    }
    return [h1, h2];
  }

  /** 生成候选（周围 2 格内、按启发分降序、最多 limit 个） */
  private genMoves(board: number[], size: number, me: number, limit: number): Cand[] {
    const out: Cand[] = [];
    const hasStone: boolean = board.some((v: number) => v !== EMPTY);
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) {
        continue;
      }
      const x: number = i % size;
      const y: number = Math.floor(i / size);
      // ★ 用 nearCount O(1) 判断，不再跑 nearStone（那是 O(25)）
      if (hasStone && (i >= this.nearCount.length || this.nearCount[i] === 0)) {
        continue;
      }
      const mine: number = pointScore(board, size, x, y, me);
      const theirs: number = pointScore(board, size, x, y, me === 1 ? 2 : 1);
      // ★★★ 2026-10-23 对打抓到 bug：原来把 mine / theirs 合成一个 score，
      //   于是「对手能一子成五、我必须去堵」被当成「我能赢」⇒ 判分整个反了
      //   ⇒ 两个字段分开存，negamax 里各走各的分支
      out.push({ idx: i, score: mine + theirs * 1.1, mine, theirs });
    }
    out.sort((a: Cand, b: Cand) => b.score - a.score);
    return out.length > limit ? out.slice(0, limit) : out;
  }

  /** 落子 / 撤销（返回下过的地方，-1 表示非法） */
  private place(board: number[], idx: number, who: number): boolean {
    if (idx < 0 || idx >= board.length || board[idx] !== EMPTY) {
      return false;
    }
    board[idx] = who;
    return true;
  }

  /** α-β（negamax 形式）：返回以 me 视角的分数 */
  private negamax(board: number[], size: number, depth: number, alpha0: number, beta0: number,
                  me: number, ply: number): number {
    if (this.aborted) {
      return 0;
    }
    this.nodes++;
    // 每 512 个节点查一次时间（Date.now 本身有开销）
    if ((this.nodes & 511) === 0 && Date.now() > this.deadline) {
      this.aborted = true;
      return 0;
    }
    // 置换表（用增量哈希：this.h1 / this.h2）
    const key: number = this.h1;
    let alpha: number = alpha0;
    let beta: number = beta0;
    const hit: TtEntry | undefined = this.tt.get(key);
    if (hit !== undefined && hit.h2 === this.h2 && hit.depth >= depth) {
      this.ttHit++;
      if (hit.flag === 0) {
        return hit.score;
      }
      if (hit.flag === 1 && hit.score >= beta) {
        return hit.score;
      }
      if (hit.flag === 2 && hit.score <= alpha) {
        return hit.score;
      }
    }

    if (depth <= 0) {
      return evaluate(board, size, me, this.nearCount);
    }
    let cands: Cand[] = this.genMoves(board, size, me, 14);
    if (cands.length === 0) {
      return evaluate(board, size, me, this.nearCount);
    }
    // ★★★ 2026-10-23 修：胜负必须分开判断 ——
    //   ① 我有成五点 ⇒ 立刻赢（这是真的赢）
    let myWin: boolean = false;
    for (let i = 0; i < cands.length; i++) {
      if (cands[i].mine >= 90000) {
        myWin = true;
        break;
      }
    }
    if (myWin) {
      return WIN - ply;
    }
    //   ② 对手有成五点 ⇒ 我**只能去堵**，其余候选全部作废
    //      （不这么做的话，搜索会以为"这里分很高"而跑去下别处，直接被打死）
    let mustBlock: boolean = false;
    for (let i = 0; i < cands.length; i++) {
      if (cands[i].theirs >= 90000) {
        mustBlock = true;
        break;
      }
    }
    if (mustBlock) {
      const only: Cand[] = [];
      for (let i = 0; i < cands.length; i++) {
        if (cands[i].theirs >= 90000) {
          only.push(cands[i]);
        }
      }
      cands = only;
      // 我自己这一步能不能顺便成五？能就还是我赢
      for (let i = 0; i < cands.length; i++) {
        if (cands[i].mine >= 90000) {
          return WIN - ply;
        }
      }
    }
    let bestScore: number = -MAX_SCORE * 2;
    let bestMove: number = cands[0].idx;
    const origAlpha: number = alpha;
    const opp: number = me === 1 ? 2 : 1;
    for (let i = 0; i < cands.length; i++) {
      const c: Cand = cands[i];
      if (!this.place(board, c.idx, me)) {
        continue;
      }
      this.hashAdd(c.idx, me);                  // 增量：落子
      this.bumpNear(board, size, c.idx, 1);     // 增量：邻域计数
      let sc: number;
      const x: number = c.idx % size;
      const y: number = Math.floor(c.idx / size);
      if (fiveAt(board, size, x, y, me)) {
        sc = WIN - ply;                 // 越早赢分越高
        board[c.idx] = EMPTY;
        this.hashAdd(c.idx, me);
        this.bumpNear(board, size, c.idx, -1);
      } else {
        sc = -this.negamax(board, size, depth - 1, -beta, -alpha, opp, ply + 1);
        board[c.idx] = EMPTY;
        this.hashAdd(c.idx, me);
        this.bumpNear(board, size, c.idx, -1);
      }
      if (this.aborted) {
        return 0;
      }
      if (sc > bestScore) {
        bestScore = sc;
        bestMove = c.idx;
      }
      if (sc > alpha) {
        alpha = sc;
      }
      if (alpha >= beta) {
        break;                          // 剪枝
      }
    }
    // 存表
    let flag: number = 0;
    if (bestScore <= origAlpha) {
      flag = 2;
    } else if (bestScore >= beta) {
      flag = 1;
    }
    this.tt.set(key, { depth, score: bestScore, flag, move: bestMove, h2: this.h2 });
    return bestScore;
  }

  /**
   * 主入口：返回要下的棋盘下标；-1 = 让调用方回落启发式
   * level: 0 简单（不搜）｜1 中等（预算 400ms）｜2 困难（预算 900ms）
   */
  pick(board: number[], size: number, level: number): number {
    const t0: number = Date.now();
    this.size = size;
    this.nodes = 0;
    this.ttHit = 0;
    this.aborted = false;
    this.stat = { nodes: 0, depth: 0, ms: 0, ttHit: 0, fellBack: false };

    if (level <= 0) {
      this.stat.fellBack = true;
      return -1;                          // 简单档：不搜，交给启发式（保持原手感）
    }
    // ★★★ 2026-10-23 路线 D 下半：预算从 400ms 放开到 1200ms
    //   原来压到 400 是因为它跑在 UI 主线程上（同步调用），900ms 会明显冻界面。
    //   现在搜索走 TaskPool 工作线程（ai/GomokuWorker.ets），UI 完全不冻
    //   ⇒ 同样"电脑在思考"的体感下，可以搜到深度 8 而不是 6，棋力再上一档。
    //   ⚠️ 别无限加：玩家等 1.2 秒已经是耐心的边界了，2 秒会显得卡。
    const budget: number = level >= 2 ? 1200 : 400;
    this.deadline = t0 + budget;
    if (this.tt.size > 40000) {
      this.tt.clear();                    // 防内存无限涨
    }
    this.hashFull(board, size);           // 增量哈希的初值（只跑一次）
    this.rebuildNear(board, size);        // 邻域计数重建（只跑一次）

    // 空盘：给天元附近
    const hasStone: boolean = board.some((v: number) => v !== EMPTY);
    if (!hasStone) {
      const c: number = Math.floor(size / 2);
      this.stat.ms = Date.now() - t0;
      return c * size + c;
    }

    // ① 快速必杀/必堵（不搜也能确定，省时间）
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) {
        continue;
      }
      const x: number = i % size;
      const y: number = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) {
        continue;
      }
      if (pointScore(board, size, x, y, 2) >= 90000) {
        this.stat.ms = Date.now() - t0;
        return i;                          // 我一子成五
      }
    }
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) {
        continue;
      }
      const x: number = i % size;
      const y: number = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) {
        continue;
      }
      if (pointScore(board, size, x, y, 1) >= 90000) {
        this.stat.ms = Date.now() - t0;
        return i;                          // 对手一子成五 ⇒ 必堵
      }
    }

    // ② 迭代加深
    let bestMove: number = -1;
    let bestDepth: number = 0;
    try {
      for (let d = 2; d <= 8; d += 2) {   // ★ 路线 D 下半：时间够了，深度 6→8
        const sc: number = this.negamax(board, size, d, -MAX_SCORE * 2, MAX_SCORE * 2, 2, 0);
        if (this.aborted) {
          break;                           // 用上一层的答案
        }
        const ttTop: TtEntry | undefined = this.tt.get(this.h1);
        if (ttTop !== undefined && ttTop.move >= 0 && board[ttTop.move] === EMPTY) {
          bestMove = ttTop.move;
          bestDepth = d;
        }
        if (sc >= WIN - 100) {
          break;                           // 已算到必胜，不用再深
        }
      }
    } catch (e) {
      this.stat.fellBack = true;
      this.stat.ms = Date.now() - t0;
      return -1;                           // 任何异常都回落
    }

    this.stat.nodes = this.nodes;
    this.stat.depth = bestDepth;
    this.stat.ttHit = this.ttHit;
    this.stat.ms = Date.now() - t0;
    if (bestMove < 0 || board[bestMove] !== EMPTY) {
      this.stat.fellBack = true;
      return -1;
    }
    return bestMove;
  }

  lastStat(): SearchStat {
    return this.stat;
  }
}
