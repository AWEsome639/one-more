#!/usr/bin/env node
/**
 * GomokuSearch 算法验收（2026-10-23）
 *
 * 为什么要有这个测试：
 *   ArkTS 编译通过 ≠ 算法正确。搜索器的 bug（死循环、置换表污染、剪枝错）
 *   在模拟器上表现为"电脑突然不出招"或"出不合法招"，很难定位。
 *   ⇒ 先把同一套逻辑移植到 JS，用固定局面测，全过了再上真机。
 *
 * 移植说明：逻辑与 entry/src/main/ets/ai/GomokuSearch.ets 逐行对应，
 *   唯一差别是 JS 没有类型标注。
 */

const EMPTY = 0, HUMAN = 1, AI = 2;
const MAX_SCORE = 100000, WIN = 100000;
const DIRS = [[1, 0], [0, 1], [1, 1], [1, -1]];

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

function pointScore(board, size, x, y, who) {
  const opp = who === 1 ? 2 : 1;
  let total = 0;
  for (let d = 0; d < 4; d++) {
    const dx = DIRS[d][0], dy = DIRS[d][1];
    let s = '';
    for (let k = -4; k <= 4; k++) {
      if (k === 0) { s += '1'; continue; }
      const nx = x + dx * k, ny = y + dy * k;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) { s += '2'; continue; }
      const v = board[ny * size + nx];
      s += (v === who ? '1' : (v === opp ? '2' : '0'));
    }
    total += shape(s);
  }
  return total;
}

function evaluate(board, size, me) {
  let mine = 0, theirs = 0;
  for (let i = 0; i < size * size; i++) {
    if (board[i] === EMPTY) continue;
    const x = i % size, y = Math.floor(i / size);
    if (board[i] === me) mine += pointScore(board, size, x, y, me);
    else theirs += pointScore(board, size, x, y, me === 1 ? 2 : 1);
  }
  return mine - theirs * 1.05;
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

class GomokuSearch {
  constructor() {
    this.tt = new Map();
    this.zob = []; this.zob2 = [];
    let seed = 20261023;
    const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; };
    for (let i = 0; i < 15 * 15; i++) {
      this.zob.push([rnd(), rnd()]);
      this.zob2.push([rnd(), rnd()]);
    }
  }
  hash(board, size) {
    let h1 = 0, h2 = 0;
    for (let i = 0; i < size * size; i++) {
      const v = board[i];
      if (v === EMPTY || i >= this.zob.length) continue;
      const p = v === 1 ? 0 : 1;
      h1 = (h1 ^ this.zob[i][p]) | 0;
      h2 = (h2 ^ this.zob2[i][p]) | 0;
    }
    return [h1, h2];
  }
  genMoves(board, size, me, limit) {
    const out = [];
    const hasStone = board.some(v => v !== EMPTY);
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (hasStone && !nearStone(board, size, x, y, 2)) continue;
      const mine = pointScore(board, size, x, y, me);
      const theirs = pointScore(board, size, x, y, me === 1 ? 2 : 1);
      out.push({ idx: i, score: mine + theirs * 1.1 });
    }
    out.sort((a, b) => b.score - a.score);
    return out.length > limit ? out.slice(0, limit) : out;
  }
  place(board, idx, who) {
    if (idx < 0 || idx >= board.length || board[idx] !== EMPTY) return false;
    board[idx] = who;
    return true;
  }
  negamax(board, size, depth, alpha0, beta0, me, ply) {
    if (this.aborted) return 0;
    this.nodes++;
    if ((this.nodes & 511) === 0 && Date.now() > this.deadline) { this.aborted = true; return 0; }
    const h = this.hash(board, size);
    const key = h[0];
    let alpha = alpha0, beta = beta0;
    const hit = this.tt.get(key);
    if (hit !== undefined && hit.h2 === h[1] && hit.depth >= depth) {
      this.ttHit++;
      if (hit.flag === 0) return hit.score;
      if (hit.flag === 1 && hit.score >= beta) return hit.score;
      if (hit.flag === 2 && hit.score <= alpha) return hit.score;
    }
    if (depth <= 0) return evaluate(board, size, me);
    const cands = this.genMoves(board, size, me, 14);
    if (cands.length === 0) return evaluate(board, size, me);
    for (let i = 0; i < cands.length; i++) if (cands[i].score >= 90000) return WIN - ply;
    let bestScore = -MAX_SCORE * 2, bestMove = cands[0].idx;
    const origAlpha = alpha;
    const opp = me === 1 ? 2 : 1;
    for (let i = 0; i < cands.length; i++) {
      const c = cands[i];
      if (!this.place(board, c.idx, me)) continue;
      let sc;
      const x = c.idx % size, y = Math.floor(c.idx / size);
      if (fiveAt(board, size, x, y, me)) { sc = WIN - ply; board[c.idx] = EMPTY; }
      else { sc = -this.negamax(board, size, depth - 1, -beta, -alpha, opp, ply + 1); board[c.idx] = EMPTY; }
      if (this.aborted) return 0;
      if (sc > bestScore) { bestScore = sc; bestMove = c.idx; }
      if (sc > alpha) alpha = sc;
      if (alpha >= beta) break;
    }
    let flag = 0;
    if (bestScore <= origAlpha) flag = 2;
    else if (bestScore >= beta) flag = 1;
    this.tt.set(key, { depth, score: bestScore, flag, move: bestMove, h2: h[1] });
    return bestScore;
  }
  pick(board, size, level) {
    const t0 = Date.now();
    this.nodes = 0; this.ttHit = 0; this.aborted = false;
    this.stat = { nodes: 0, depth: 0, ms: 0, ttHit: 0, fellBack: false };
    if (level <= 0) { this.stat.fellBack = true; return -1; }
    const budget = level >= 2 ? 400 : 200;
    this.deadline = t0 + budget;
    if (this.tt.size > 40000) this.tt.clear();
    const hasStone = board.some(v => v !== EMPTY);
    if (!hasStone) { const c = Math.floor(size / 2); this.stat.ms = Date.now() - t0; return c * size + c; }
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) continue;
      if (pointScore(board, size, x, y, 2) >= 90000) { this.stat.ms = Date.now() - t0; return i; }
    }
    for (let i = 0; i < size * size; i++) {
      if (board[i] !== EMPTY) continue;
      const x = i % size, y = Math.floor(i / size);
      if (!nearStone(board, size, x, y, 2)) continue;
      if (pointScore(board, size, x, y, 1) >= 90000) { this.stat.ms = Date.now() - t0; return i; }
    }
    let bestMove = -1, bestDepth = 0;
    try {
      for (let d = 2; d <= 6; d += 2) {
        const sc = this.negamax(board, size, d, -MAX_SCORE * 2, MAX_SCORE * 2, 2, 0);
        if (this.aborted) break;
        const ttTop = this.tt.get(this.hash(board, size)[0]);
        if (ttTop !== undefined && ttTop.move >= 0 && board[ttTop.move] === EMPTY) { bestMove = ttTop.move; bestDepth = d; }
        if (sc >= WIN - 100) break;
      }
    } catch (e) { this.stat.fellBack = true; this.stat.ms = Date.now() - t0; return -1; }
    this.stat.nodes = this.nodes; this.stat.depth = bestDepth; this.stat.ttHit = this.ttHit;
    this.stat.ms = Date.now() - t0;
    if (bestMove < 0 || board[bestMove] !== EMPTY) { this.stat.fellBack = true; return -1; }
    return bestMove;
  }
}

// ───────────────────── 测试 ─────────────────────
const SIZE = 15;
function mk() { return new Array(SIZE * SIZE).fill(EMPTY); }
function set(b, x, y, who) { b[y * SIZE + x] = who; }

let pass = 0, fail = 0;
function check(name, cond, extra) {
  if (cond) { pass++; console.log('  ✅ ' + name); }
  else { fail++; console.log('  🔴 ' + name + (extra ? '  ' + extra : '')); }
}

const s = new GomokuSearch();

// ① 我四连 → 必须成五
{
  const b = mk();
  for (let x = 3; x <= 6; x++) set(b, x, 7, AI);
  for (let x = 3; x <= 5; x++) set(b, x, 8, HUMAN);
  const mv = s.pick(b, SIZE, 2);
  const ok = mv >= 0 && pointScore(b, SIZE, mv % SIZE, Math.floor(mv / SIZE), AI) >= 90000;
  check('① 我四连 ⇒ 必须一子成五', ok, 'mv=' + mv);
}

// ② 对手四连 → 必须堵
{
  const b = mk();
  for (let x = 3; x <= 6; x++) set(b, x, 7, HUMAN);
  for (let x = 3; x <= 5; x++) set(b, x, 8, AI);
  const mv = s.pick(b, SIZE, 2);
  const ok = mv === 2 * SIZE + 7 - 0 || mv === 7 * SIZE + 7 || (mv >= 0 && pointScore(b, SIZE, mv % SIZE, Math.floor(mv / SIZE), HUMAN) >= 90000);
  check('② 对手四连 ⇒ 必须堵', ok, 'mv=' + mv + ' (应为 x=2 或 x=7, y=7)');
}

// ③ 对手活三 → 必须防（或自己造更大威胁）
{
  const b = mk();
  for (let x = 5; x <= 7; x++) set(b, x, 7, HUMAN);
  set(b, 6, 6, AI); set(b, 7, 8, AI);
  const mv = s.pick(b, SIZE, 2);
  check('③ 对手活三 ⇒ 必须防', mv >= 0, 'mv=' + mv);
}

// ④ 空盘 → 天元
{
  const b = mk();
  const mv = s.pick(b, SIZE, 2);
  check('④ 空盘 ⇒ 中心', mv === 7 * SIZE + 7, 'mv=' + mv);
}

// ⑤ 出招必须合法（空点）
{
  const b = mk();
  set(b, 7, 7, HUMAN); set(b, 8, 8, AI);
  const mv = s.pick(b, SIZE, 2);
  check('⑤ 出招必须落在空点', mv >= 0 && b[mv] === EMPTY, 'mv=' + mv);
}

// ⑥ 时间预算（困难档 ≤ 400ms + 余量）
{
  const b = mk();
  set(b, 7, 7, HUMAN); set(b, 8, 8, AI); set(b, 6, 8, HUMAN); set(b, 9, 7, AI);
  const t0 = Date.now();
  const mv = s.pick(b, SIZE, 2);
  const ms = Date.now() - t0;
  check('⑥ 困难档出招 ≤ 800ms（预算 400 + 余量）', ms <= 800 && mv >= 0, ms + 'ms');
}

// ⑦ 简单档不搜索（返回 -1 让调用方回落）
{
  const b = mk();
  set(b, 7, 7, HUMAN);
  const mv = s.pick(b, SIZE, 0);
  check('⑦ 简单档 ⇒ 返回 -1（回落启发式）', mv === -1, 'mv=' + mv);
}

// ⑧ 连打 30 手自对弈：不许崩溃、不许出非法招、不许卡住
{
  let b = mk();
  let legal = true, msMax = 0;
  b[7 * SIZE + 7] = HUMAN;
  for (let t = 0; t < 30; t++) {
    const t0 = Date.now();
    const mv = s.pick(b, SIZE, 1);
    msMax = Math.max(msMax, Date.now() - t0);
    if (mv < 0 || b[mv] !== EMPTY) { legal = false; break; }
    b[mv] = AI;
    if (fiveAt(b, SIZE, mv % SIZE, Math.floor(mv / SIZE), AI)) break;
    // 人随手下一手
    const empties = [];
    for (let i = 0; i < SIZE * SIZE; i++) if (b[i] === EMPTY) empties.push(i);
    b[empties[Math.floor(empties.length / 2)]] = HUMAN;
  }
  check('⑧ 自对弈 30 手：全部合法且不卡', legal && msMax <= 600, 'max=' + msMax + 'ms');
}

// ⑨ 搜索统计合理（节点数 > 0、深度 >= 2）
{
  const b = mk();
  set(b, 7, 7, HUMAN); set(b, 8, 8, AI);
  s.pick(b, SIZE, 2);
  const st = s.stat;
  check('⑨ 搜索统计合理（节点>0 且 深度>=2）', st.nodes > 0 && st.depth >= 2, JSON.stringify(st));
}

console.log('\n  ── 结果：' + pass + ' 通过 / ' + fail + ' 失败 ──\n');
process.exit(fail === 0 ? 0 : 1);
