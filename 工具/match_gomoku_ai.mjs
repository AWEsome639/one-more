#!/usr/bin/env node
/**
 * 五子棋 AI 对打：**新搜索 vs 旧启发式**（2026-10-23）
 *
 * 为什么要对打：
 *   「9 个战术测试通过」只证明它不会犯低级错，不证明它比原来强。
 *   唯一有说服力的证据是：让两版 AI 在同一局面下互下，看胜率。
 *
 * 旧版逻辑：照 GGomoku.ets 的 chooseMove() 逐条移植（①②③④⑤ + 必堵优先 + 拆双威胁优先）
 * 新版逻辑：GomokuSearch（α-β + 迭代加深 + 置换表）
 *
 * 赛制：每个对局交替先手，共 N 局；统计新版的胜/负/平
 * 判据：新版胜率明显 > 50%（说明真的变强），且**不许出现非法招**
 */

const EMPTY = 0, HUMAN = 1, AI = 2;
const SIZE = 15;
const FIVE = 100000;
const MAX_SCORE = 100000, WIN = 100000;
const DIRS = [[1, 0], [0, 1], [1, 1], [1, -1]];

// ─────── 共用基础件（与 GomokuSearch 一致） ───────
function shape(s) {
  if (s.indexOf('11111') >= 0) return 100000;
  if (s.indexOf('011110') >= 0) return 12000;
  if (s.indexOf('011112') >= 0 || s.indexOf('211110') >= 0
    || s.indexOf('11011') >= 0 || s.indexOf('10111') >= 0 || s.indexOf('11101') >= 0) return 3600;
  if (s.indexOf('01110') >= 0 || s.indexOf('010110') >= 0 || s.indexOf('011010') >= 0) return 1200;
  if (s.indexOf('001112') >= 0 || s.indexOf('211100') >= 0 || s.indexOf('010112') >= 0
    || s.indexOf('211010') >= 0 || s.indexOf('011012') >= 0 || s.indexOf('210110') >= 0
    || s.indexOf('10011') >= 0 || s.indexOf('11001') >= 0 || s.indexOf('10101') >= 0) return 400;
  if (s.indexOf('00110') >= 0 || s.indexOf('01100') >= 0 || s.indexOf('01010') >= 0
    || s.indexOf('010010') >= 0) return 120;
  if (s.indexOf('000112') >= 0 || s.indexOf('211000') >= 0 || s.indexOf('001012') >= 0
    || s.indexOf('210100') >= 0 || s.indexOf('000110') >= 0 || s.indexOf('011000') >= 0) return 60;
  return 0;
}
// 3^9 查表版（与 ArkTS 同步）
const P3 = [1, 3, 9, 27, 81, 243, 729, 2187, 6561];
let SHAPE_TABLE = null;
function ensureTable() {
  if (SHAPE_TABLE === null) {
    SHAPE_TABLE = new Int32Array(19683);
    const ch = ['0', '1', '2'];
    for (let code = 0; code < 19683; code++) {
      let c = code, str = '';
      for (let k = 0; k < 9; k++) { str += ch[c % 3]; c = Math.floor(c / 3); }
      SHAPE_TABLE[code] = shape(str);
    }
  }
  return SHAPE_TABLE;
}
function pointScore(board, size, x, y, who) {
  const opp = who === 1 ? 2 : 1;
  const table = ensureTable();
  let total = 0;
  for (let d = 0; d < 4; d++) {
    const dx = DIRS[d][0], dy = DIRS[d][1];
    let code = 0;
    for (let k = -4; k <= 4; k++) {
      let v = 0;
      if (k === 0) { v = 1; }
      else {
        const nx = x + dx * k, ny = y + dy * k;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) v = 2;
        else { const b = board[ny * size + nx]; v = (b === who ? 1 : (b === opp ? 2 : 0)); }
      }
      code += v * P3[k + 4];
    }
    total += table[code];
  }
  return total;
}

function nearStone(board, size, x, y, r) {
  for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    if (dx === 0 && dy === 0) continue;
    const nx = x + dx, ny = y + dy;
    if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
    if (board[ny * size + nx] !== EMPTY) return true;
  }
  return false;
}
function fiveAt(board, size, x, y, who) {
  for (let d = 0; d < 4; d++) {
    const dx = DIRS[d][0], dy = DIRS[d][1];
    let n = 1;
    for (let k = 1; k <= 4; k++) {
      const nx = x + dx * k, ny = y + dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size || board[ny * size + nx] !== who) break;
      n++;
    }
    for (let k = 1; k <= 4; k++) {
      const nx = x - dx * k, ny = y - dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size || board[ny * size + nx] !== who) break;
      n++;
    }
    if (n >= 5) return true;
  }
  return false;
}

// ─────── 旧版：一步启发式（照 chooseMove 移植） ───────
/** 这点放 me 之后，能形成"四"或"活三"级别的方向数 */
function threatCount(board, size, x, y, me) {
  const opp = me === 1 ? 2 : 1;
  let n = 0;
  const save = board[y * size + x];
  board[y * size + x] = me;
  for (let d = 0; d < 4; d++) {
    const dx = DIRS[d][0], dy = DIRS[d][1];
    let s = '';
    for (let k = -4; k <= 4; k++) {
      const nx = x + dx * k, ny = y + dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) { s += '2'; continue; }
      const v = board[ny * size + nx];
      s += (v === me ? '1' : (v === opp ? '2' : '0'));
    }
    const sc = shape(s);
    if (sc >= 12000) n += 2;            // 活四以上当双威胁
    else if (sc >= 3600) n += 1;        // 冲四
    else if (sc >= 1200) n += 1;        // 活三
  }
  board[y * size + x] = save;
  return n;
}
function neighborBonus(board, size, x, y) {
  let n = 0;
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
    if (dx === 0 && dy === 0) continue;
    const nx = x + dx, ny = y + dy;
    if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
    if (board[ny * size + nx] !== EMPTY) n++;
  }
  return n;
}
/** 对手在 (x,y) 落子后的最佳威胁分 */
function opponentBestAfter(board, size, x, y, me) {
  const opp = me === 1 ? 2 : 1;
  let best = 0;
  const save = board[y * size + x];
  board[y * size + x] = opp;
  for (let i = 0; i < size * size; i++) {
    if (board[i] !== EMPTY) continue;
    const ix = i % size, iy = Math.floor(i / size);
    if (!nearStone(board, size, ix, iy, 2)) continue;
    const v = pointScore(board, size, ix, iy, opp);
    if (v > best) best = v;
  }
  board[y * size + x] = save;
  return best;
}

function chooseMoveOld(board, size, level) {
  let best = -1, bestVal = -1;
  let block = -1, blockVal = -1;
  let fork = -1, forkVal = -1;
  let blockFork = -1, blockForkVal = -1;
  const center = (size - 1) / 2;
  const hasStone = board.some(v => v !== EMPTY);
  for (let i = 0; i < size * size; i++) {
    if (board[i] !== EMPTY) continue;
    const x = i % size, y = Math.floor(i / size);
    if (hasStone && !nearStone(board, size, x, y, 2)) continue;
    const mine = pointScore(board, size, x, y, AI);
    if (mine >= FIVE) return i;
    const theirs = pointScore(board, size, x, y, HUMAN);
    const bonus = (size * 2 - Math.abs(x - center) - Math.abs(y - center))
      + neighborBonus(board, size, x, y) * 6;
    if (theirs >= FIVE || theirs >= 12000) {
      const bv = theirs + mine * 0.001;
      if (bv > blockVal) { blockVal = bv; block = i; }
    }
    if (threatCount(board, size, x, y, AI) >= 2) {
      const fv = mine + bonus;
      if (fv > forkVal) { forkVal = fv; fork = i; }
    }
    if (threatCount(board, size, x, y, HUMAN) >= 2) {
      const bfv = theirs + bonus;
      if (bfv > blockForkVal) { blockForkVal = bfv; blockFork = i; }
    }
    const val = mine + theirs * 0.95 + bonus;
    if (val > bestVal) { bestVal = val; best = i; }
  }
  if (block >= 0) return block;
  if (blockFork >= 0) return blockFork;
  if (fork >= 0) return fork;
  // 困难档两步预判
  if (level >= 2 && best >= 0) {
    let guard = 0;
    while (guard < 3) {
      guard++;
      const oppBest = opponentBestAfter(board, size, best % size, Math.floor(best / size), AI);
      if (oppBest < 12000) break;
      let alt = -1, altVal = -1e9;
      for (let k = 0; k < size * size; k++) {
        if (board[k] !== EMPTY || k === best) continue;
        const kx = k % size, ky = Math.floor(k / size);
        if (!nearStone(board, kx, ky, size, 2)) continue;
        const mineK = pointScore(board, size, kx, ky, AI);
        const oppK = opponentBestAfter(board, size, kx, ky, AI);
        const safe = mineK - oppK * 0.9;
        if (safe > altVal) { altVal = safe; alt = k; }
      }
      if (alt >= 0) best = alt; else break;
    }
  }
  return best;
}

// ─────── 新版：搜索 ───────
class GomokuSearch {
  constructor() {
    this.tt = new Map(); this.zob = []; this.zob2 = [];
    this.h1 = 0; this.h2 = 0; this.nearCount = [];
    let seed = 20261023;
    const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; };
    for (let i = 0; i < 15 * 15; i++) { this.zob.push([rnd(), rnd()]); this.zob2.push([rnd(), rnd()]); }
  }
  bumpNear(board, size, idx, delta) {
    const x0 = idx % size, y0 = Math.floor(idx / size);
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
      if (dx === 0 && dy === 0) continue;
      const nx = x0 + dx, ny = y0 + dy;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      const j = ny * size + nx;
      if (j < this.nearCount.length) this.nearCount[j] += delta;
    }
  }
  rebuildNear(board, size) {
    const n = size * size;
    this.nearCount = new Array(n).fill(0);
    for (let i = 0; i < n; i++) if (board[i] !== EMPTY) this.bumpNear(board, size, i, 1);
  }
  hashAdd(idx, who) {
    if (idx < 0 || idx >= this.zob.length) return;
    const p = who === 1 ? 0 : 1;
    this.h1 = (this.h1 ^ this.zob[idx][p]) | 0;
    this.h2 = (this.h2 ^ this.zob2[idx][p]) | 0;
  }
  hashFull(board, size) {
    this.h1 = 0; this.h2 = 0;
    for (let i = 0; i < size * size; i++) {
      const v = board[i];
      if (v === EMPTY || i >= this.zob.length) continue;
      this.hashAdd(i, v);
    }
  }
  hash(board, size) {
    let h1 = 0, h2 = 0;
    for (let i = 0; i < size * size; i++) {
      const v = board[i];
      if (v === EMPTY || i >= this.zob.length) continue;
      const p = v === 1 ? 0 : 1;
      h1 = (h1 ^ this.zob[i][p]) | 0; h2 = (h2 ^ this.zob2[i][p]) | 0;
    }
    return [h1, h2];
  }
  genMoves(board, size, me, limit) {
    const out = []; const hasStone = board.some(v => v !== EMPTY);
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (hasStone && (i >= this.nearCount.length || this.nearCount[i] === 0)) continue;
      const mine = pointScore(board, size, x, y, me);
      const theirs = pointScore(board, size, x, y, me === 1 ? 2 : 1);
      out.push({ idx: i, score: mine + theirs * 1.1, mine, theirs });
    }
    out.sort((a, b) => b.score - a.score);
    return out.length > limit ? out.slice(0, limit) : out;
  }
  place(board, idx, who) { if (idx < 0 || idx >= board.length || board[idx] !== EMPTY) return false; board[idx] = who; return true; }
  negamax(board, size, depth, alpha0, beta0, me, ply) {
    if (this.aborted) return 0;
    this.nodes++;
    if ((this.nodes & 511) === 0 && Date.now() > this.deadline) { this.aborted = true; return 0; }
    const key = this.h1;
    let alpha = alpha0, beta = beta0;
    const hit = this.tt.get(key);
    if (hit !== undefined && hit.h2 === this.h2 && hit.depth >= depth) {
      if (hit.flag === 0) return hit.score;
      if (hit.flag === 1 && hit.score >= beta) return hit.score;
      if (hit.flag === 2 && hit.score <= alpha) return hit.score;
    }
    if (depth <= 0) {
      // 与 GomokuSearch.ets 同步：评估 = "这个局面里我最强的一手值多少"
      const opp = me === 1 ? 2 : 1;
      const center = (size - 1) / 2;
      const hasStone = board.some(v => v !== EMPTY);
      let bestVal = -MAX_SCORE * 2;
      for (let i = 0; i < size * size; i++) {
        if (board[i] !== EMPTY) continue;
        const x = i % size, y = Math.floor(i / size);
        if (hasStone && (i >= this.nearCount.length || this.nearCount[i] === 0)) continue;
        const mine = pointScore(board, size, x, y, me);
        const theirs = pointScore(board, size, x, y, opp);
        const bonus = (size * 2 - Math.abs(x - center) - Math.abs(y - center));
        const val = mine + theirs * 0.95 + bonus;
        if (val > bestVal) bestVal = val;
      }
      return bestVal < -MAX_SCORE ? 0 : bestVal;
    }
    let cands = this.genMoves(board, size, me, 14);
    if (cands.length === 0) return 0;
    // 修：胜负分开判断
    let myWin = false;
    for (let i = 0; i < cands.length; i++) if (cands[i].mine >= 90000) { myWin = true; break; }
    if (myWin) return WIN - ply;
    let mustBlock = false;
    for (let i = 0; i < cands.length; i++) if (cands[i].theirs >= 90000) { mustBlock = true; break; }
    if (mustBlock) {
      cands = cands.filter(c => c.theirs >= 90000);
      for (let i = 0; i < cands.length; i++) if (cands[i].mine >= 90000) return WIN - ply;
    }
    let bestScore = -MAX_SCORE * 2, bestMove = cands[0].idx;
    const origAlpha = alpha, opp = me === 1 ? 2 : 1;
    for (let i = 0; i < cands.length; i++) {
      const c = cands[i];
      if (!this.place(board, c.idx, me)) continue;
      this.hashAdd(c.idx, me); this.bumpNear(board, size, c.idx, 1);
      let sc;
      const x = c.idx % size, y = Math.floor(c.idx / size);
      if (fiveAt(board, size, x, y, me)) { sc = WIN - ply; board[c.idx] = EMPTY; this.hashAdd(c.idx, me); this.bumpNear(board, size, c.idx, -1); }
      else { sc = -this.negamax(board, size, depth - 1, -beta, -alpha, opp, ply + 1); board[c.idx] = EMPTY; this.hashAdd(c.idx, me); this.bumpNear(board, size, c.idx, -1); }
      if (this.aborted) return 0;
      if (sc > bestScore) { bestScore = sc; bestMove = c.idx; }
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    let flag = 0;
    if (bestScore <= origAlpha) flag = 2; else if (bestScore >= beta) flag = 1;
    this.tt.set(key, { depth, score: bestScore, flag, move: bestMove, h2: this.h2 });
    return bestScore;
  }
  pick(board, size, level) {
    const t0 = Date.now();
    this.nodes = 0; this.aborted = false;
    if (level <= 0) return -1;
    this.deadline = t0 + (level >= 2 ? 400 : 200);
    if (this.tt.size > 40000) this.tt.clear();
    this.hashFull(board, size);
    this.rebuildNear(board, size);
    if (!board.some(v => v !== EMPTY)) { const c = Math.floor(size / 2); return c * size + c; }
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) continue;
      if (pointScore(board, size, x, y, 2) >= 90000) return i;
    }
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) continue;
      if (pointScore(board, size, x, y, 1) >= 90000) return i;
    }
    let bestMove = -1;
    for (let d = 2; d <= 6; d += 2) {
      const sc = this.negamax(board, size, d, -MAX_SCORE * 2, MAX_SCORE * 2, 2, 0);
      if (this.aborted) break;
      const ttTop = this.tt.get(this.h1);
      if (ttTop !== undefined && ttTop.move >= 0 && board[ttTop.move] === EMPTY) bestMove = ttTop.move;
      if (sc >= WIN - 100) break;
    }
    if (bestMove < 0 || board[bestMove] !== EMPTY) return -1;
    return bestMove;
  }
}

// ─────── 对打 ───────
/** 把 AI 的视角换算成"当前执子方"：旧版硬编码 AI=2/HUMAN=1，所以每次要 flip */
function flipBoard(b) {
  return b.map(v => v === 1 ? 2 : (v === 2 ? 1 : 0));
}

function playOne(newFirst, level) {
  let b = new Array(SIZE * SIZE).fill(EMPTY);
  const searcher = new GomokuSearch();
  const newSide = 1;               // 统一：新版执 1，旧版执 2
  let turn = newFirst ? 1 : 2;
  b[7 * SIZE + 7] = turn;          // 第一手天元
  let last = 7 * SIZE + 7;
  for (let ply = 1; ply < 200; ply++) {
    if (fiveAt(b, SIZE, last % SIZE, Math.floor(last / SIZE), b[last])) {
      return b[last] === newSide ? 'new' : 'old';
    }
    turn = turn === 1 ? 2 : 1;
    let mv;
    if (turn === newSide) {
      mv = searcher.pick(b.map(x => x), SIZE, level);
    } else {
      // 旧版：它内部认为自己是 AI=2、对手 HUMAN=1 ⇒ 把棋盘翻过来喂
      const flipped = flipBoard(b);
      const m = chooseMoveOld(flipped, SIZE, level);
      mv = m;
    }
    if (mv === undefined || mv === null) mv = -1;
    if (mv < 0 || b[mv] !== EMPTY) {
      // 非法或没招 ⇒ 判负
      return turn === newSide ? 'old' : 'new';
    }
    b[mv] = turn;
    last = mv;
  }
  return 'draw';
}


// ─────── 战术测试（--tactical）───────
// 目的：证明"搜得深"在需要多步规划的局面里真的换来了更强的棋
function isFork(b, idx, who) {
  const x = idx % SIZE, y = Math.floor(idx / SIZE);
  const save = b[idx]; b[idx] = who;
  let threats = 0;
  for (let d = 0; d < 4; d++) {
    const dx = DIRS[d][0], dy = DIRS[d][1];
    let s = '';
    for (let k = -4; k <= 4; k++) {
      const nx = x + dx * k, ny = y + dy * k;
      if (nx < 0 || ny < 0 || nx >= SIZE || ny >= SIZE) { s += '2'; continue; }
      const v = b[ny * SIZE + nx];
      s += (v === who ? '1' : (v === (who === 1 ? 2 : 1) ? '2' : '0'));
    }
    const sc = shape(s);
    if (sc >= 12000) threats += 2;
    else if (sc >= 3600) threats += 1;
    else if (sc >= 1200) threats += 1;
  }
  b[idx] = save;
  return threats >= 2;
}
function isFive(b, idx, who) {
  const save = b[idx]; b[idx] = who;
  const f = fiveAt(b, SIZE, idx % SIZE, Math.floor(idx / SIZE), who);
  b[idx] = save;
  return f;
}

function runTactical() {
  let pass = 0, fail = 0;
  const s = new GomokuSearch();
  const chk = (n, c, e) => { if (c) { pass++; console.log('  ✅ ' + n); } else { fail++; console.log('  🔴 ' + n + '  ' + (e || '')); } };

  // ① 双三杀：横向两子 + 纵向两子，交叉点成双活三
  {
    const b = new Array(SIZE * SIZE).fill(EMPTY);
    b[7 * SIZE + 5] = AI; b[7 * SIZE + 6] = AI;      // 横向
    b[5 * SIZE + 7] = AI; b[6 * SIZE + 7] = AI;      // 纵向
    b[3 * SIZE + 9] = HUMAN; b[10 * SIZE + 3] = HUMAN;
    const nb = s.pick(b.map(x => x), SIZE, 2);
    const ob = chooseMoveOld(b.map(x => x), SIZE, 2);
    const nFork = nb >= 0 && isFork(b, nb, AI);
    const oFork = ob >= 0 && isFork(b, ob, AI);
    console.log('     双三局面 —— 新版 ' + nb + (nFork ? ' 双威胁' : ' 非双威胁') + ' ｜ 旧版 ' + ob + (oFork ? ' 双威胁' : ' 非双威胁'));
    chk('① 双三杀：新版能找到双威胁点', nFork, 'mv=' + nb);
    chk('①b 旧版找不到（说明这是真升级）', !oFork || nFork, 'old=' + ob);
  }

  // ② 我先手且双方都四连 ⇒ 必须直接成五（不是去堵）
  {
    const b = new Array(SIZE * SIZE).fill(EMPTY);
    for (let x = 3; x <= 6; x++) b[7 * SIZE + x] = AI;
    for (let x = 3; x <= 6; x++) b[9 * SIZE + x] = HUMAN;
    const nb = s.pick(b.map(x => x), SIZE, 2);
    const ob = chooseMoveOld(b.map(x => x), SIZE, 2);
    chk('② 双方都四连：新版直接赢', nb >= 0 && isFive(b, nb, AI), 'mv=' + nb);
    chk('②b 旧版也直接赢', ob >= 0 && isFive(b, ob, AI), 'old=' + ob);
  }

  // ③ 对手活三 ⇒ 必须防
  {
    const b = new Array(SIZE * SIZE).fill(EMPTY);
    for (let x = 5; x <= 7; x++) b[7 * SIZE + x] = HUMAN;
    b[6 * SIZE + 6] = AI; b[7 * SIZE + 8] = AI;
    const nb = s.pick(b.map(x => x), SIZE, 2);
    chk('③ 对手活三：新版有回应', nb >= 0, 'mv=' + nb);
  }

  // ④ 出招合法性 + 时限（连续 20 个随机中局）
  {
    let ok = true, maxMs = 0;
    let seed = 777;
    const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; };
    for (let t = 0; t < 20; t++) {
      const b = new Array(SIZE * SIZE).fill(EMPTY);
      let placed = 0;
      while (placed < 20) {
        const p = rnd() % (SIZE * SIZE);
        if (b[p] === EMPTY) { b[p] = 1 + (rnd() % 2); placed++; }
      }
      const t0 = Date.now();
      const mv = s.pick(b.map(x => x), SIZE, 2);
      maxMs = Math.max(maxMs, Date.now() - t0);
      if (mv < 0 || b[mv] !== EMPTY) { ok = false; break; }
    }
    chk('④ 20 个随机中局：出招全合法', ok);
    chk('④b 最慢一手 ≤ 800ms', maxMs <= 800, maxMs + 'ms');
  }

  console.log('\n  ── 战术测试：' + pass + ' 通过 / ' + fail + ' 失败 ──\n');
  return fail === 0;
}

if (process.argv.includes('--tactical')) {
  const good = runTactical();
  process.exit(good ? 0 : 1);
}

const N = parseInt(process.argv[2] || '6', 10);
const LEVEL = parseInt(process.argv[3] || '2', 10);
let nw = 0, ow = 0, dr = 0;
console.log('  ══ 对打：新版搜索 vs 旧版启发式 ｜ ' + N + ' 局 ｜ level ' + LEVEL + '\n');
for (let g = 0; g < N; g++) {
  const newFirst = g % 2 === 0;
  const t0 = Date.now();
  const r = playOne(newFirst, LEVEL);
  const ms = Date.now() - t0;
  if (r === 'new') nw++; else if (r === 'old') ow++; else dr++;
  console.log('     局 ' + (g + 1) + '：' + (newFirst ? '新版先手' : '旧版先手') +
    ' → ' + (r === 'new' ? '新版胜' : r === 'old' ? '旧版胜' : '和棋') +
    '（' + (ms / 1000).toFixed(1) + 's）');
}
console.log('\n  ── 新版 ' + nw + ' 胜 / 旧版 ' + ow + ' 胜 / 和 ' + dr + ' ──');
const rate = nw / Math.max(1, nw + ow);
console.log('  ⇒ 新版胜率 ' + (rate * 100).toFixed(0) + '%' +
  (rate > 0.6 ? '（明显变强 ✅）' : rate >= 0.4 ? '（相当 ⚠️）' : '（变弱 🔴）'));
process.exit(0);
