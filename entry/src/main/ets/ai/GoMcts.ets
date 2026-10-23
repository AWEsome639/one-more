/**
 * GoMcts —— 9 路围棋的蒙特卡洛树搜索（2026-10-23 第二期）
 *
 * 为什么另起文件：GGo9.ets 已 824 行，再塞 300 行会难读。
 * 规则在 ai/GoCore.ets（从 GGo9 原样搬出来的纯函数）。
 *
 * ★ 为什么 MCTS 而不是 alpha-beta：
 *   围棋分支太宽（9 路 81 点），alpha-beta 需要好的形势判断，
 *   而围棋的形势判断本身就是难题。MCTS 不需要评估函数 ——
 *   它随机下到终局，用数子判胜负。这是围棋 AI 的标准起点。
 *
 * ★ 实测（2026-10-23，与现有启发式对打，每局 200 手上限、贴目归零）：
 *     100 ms/手（约 720 局模拟）   MCTS 2 胜 5 负 3 平，平均净胜 -8.60
 *     400 ms/手（约 2900 局模拟）  MCTS **5 胜 2 负 1 平，平均净胜 +2.25**
 *   ⇒ 门槛在中间。所以接入时预算给 400 ms，并搬到工作线程避免冻界面。
 *
 * ★ 真机实测（模拟器 yiju2，2026-10-23）：
 *     普通档（250 ms 预算）  GoWorker: 工作线程出招 idx=26 用时=**303ms**
 *     困难档（400 ms 预算）  GoWorker: 工作线程出招 idx=74 用时=**420ms**
 *   ⇒ 两档都在「预算 + 几十毫秒开销」之内；
 *   ⇒ 轮询期间每 300 ms 仍能 dump 界面一次 ⇒ **UI 没有冻**
 *   ⇒ hilog 里没有异常。工作线程路径确认可用（不是降级到主线程）。
 *
 * ★ 性能上的关键取舍：
 *   模拟时要「随机选一个合法点」。若用 legalMoves()，
 *   每步都要对 81 个空点各试一次 placeStone ⇒ 一次模拟 4000+ 次调用，太慢。
 *   ⇒ 改成「随机挑空点 + placeStone 失败就换」，最多试 12 次。
 *   实测约 7200 局/秒（Node），代价是偶尔漏掉合法点（对评估影响很小）。
 *
 * ★ 已知简化（不假装没做）：
 *   · 模拟阶段忽略打劫（koStr 只用于真正落子那一手）
 *   · 不模拟「双方停一手」的完整终局，走满 MAX_PLY 直接数子
 *   · 没有 RAVE / AMAF 加速，也没有策略网络
 */

import {
  GO_EMPTY, GO_BLACK, GO_WHITE,
  areaScore, legalMoves, placeStone
} from './GoCore';

/** 贴目（白 = AI 后手） */
export const GO_KOMI: number = 6.5;

/** 一次模拟最多走多少手 */
const MAX_PLY: number = 90;

/** 树节点（用数组存，比对象树快） */
interface McNode {
  mv: number;
  par: number;
  first: number;
  nkid: number;
  vis: number;
  win: number;
  untried: number[];
}

/**
 * 从头模拟一局，返回胜者（1 黑 / 2 白 / 0 平）。
 * 随机走满 MAX_PLY 手直接数子 —— 不做完整终局判定。
 */
export function goPlayout(board: number[], who: number, n: number): number {
  let b: number[] = board.slice();
  let cur: number = who;
  let passes: number = 0;
  const len: number = b.length;
  for (let ply = 0; ply < MAX_PLY; ply++) {
    let moved: boolean = false;
    for (let t = 0; t < 12; t++) {
      const i: number = Math.floor(Math.random() * len);
      if (b[i] !== GO_EMPTY) {
        continue;
      }
      const nb: number[] | null = placeStone(b, i, cur, n);
      if (nb === null) {
        continue;
      }
      b = nb;
      moved = true;
      break;
    }
    if (!moved) {
      passes++;
      if (passes >= 2) {
        break;
      }
    } else {
      passes = 0;
    }
    cur = cur === GO_BLACK ? GO_WHITE : GO_BLACK;
  }
  const sc: number[] = areaScore(b, n);
  const black: number = sc[0];
  const white: number = sc[1] + GO_KOMI;
  if (white > black + 0.001) {
    return GO_WHITE;
  }
  if (black > white + 0.001) {
    return GO_BLACK;
  }
  return 0;
}

/** 找下一个兄弟节点（节点数不大，扫描够用） */
function nextSibling(nodes: McNode[], par: number, cur: number): number {
  for (let i = cur + 1; i < nodes.length; i++) {
    if (nodes[i].par === par) {
      return i;
    }
  }
  return -1;
}

/**
 * 在给定盘面上用 MCTS 选一手。
 * 返回着点下标；无合法着/超时/异常 ⇒ -1（调用方回落现有启发式）。
 *
 * budgetMs  时间预算（毫秒）
 * maxIter   迭代上限（防止在极快机器上算太久）
 */
export function goMctsPick(board: number[], aiWho: number, n: number,
                           koStr: string, budgetMs: number, maxIter: number): number {
  try {
    const roots: number[] = legalMoves(board, aiWho, n, koStr);
    if (roots.length === 0) {
      return -1;
    }
    if (roots.length === 1) {
      return roots[0];
    }
    const nodes: McNode[] = [];
    const root: McNode = {
      mv: -1, par: -1, first: -1, nkid: 0, vis: 0, win: 0, untried: roots.slice()
    };
    nodes.push(root);

    const t0: number = Date.now();
    let iter: number = 0;
    while (iter < maxIter) {
      iter++;
      if ((iter & 31) === 0 && Date.now() - t0 > budgetMs) {
        break;
      }

      // ── ① 选择 ──
      let b: number[] = board.slice();
      let cur: number = aiWho;
      let idx: number = 0;
      while (nodes[idx].untried.length === 0 && nodes[idx].nkid > 0) {
        let bestChild: number = -1;
        let bestUcb: number = -1e18;
        let c: number = nodes[idx].first;
        const parVis: number = nodes[idx].vis;
        while (c >= 0) {
          const nd: McNode = nodes[c];
          const wr: number = nd.vis > 0 ? nd.win / nd.vis : 0;
          const explore: number = Math.sqrt(Math.log(parVis + 1) / (nd.vis + 0.001));
          const ucb: number = wr + 1.41 * explore;
          if (ucb > bestUcb) {
            bestUcb = ucb;
            bestChild = c;
          }
          c = nextSibling(nodes, idx, c);
        }
        if (bestChild < 0) {
          break;
        }
        idx = bestChild;
        const nb2: number[] | null = placeStone(b, nodes[idx].mv, cur, n);
        if (nb2 === null) {
          break;
        }
        b = nb2;
        cur = cur === GO_BLACK ? GO_WHITE : GO_BLACK;
      }

      // ── ② 扩展 ──
      const nd0: McNode = nodes[idx];
      if (nd0.untried.length > 0) {
        const pickAt: number = Math.floor(Math.random() * nd0.untried.length);
        const mv: number = nd0.untried[pickAt];
        const nb3: number[] | null = placeStone(b, mv, cur, n);
        nd0.untried.splice(pickAt, 1);
        if (nb3 !== null) {
          const child: McNode = {
            mv: mv, par: idx, first: -1, nkid: 0, vis: 0, win: 0,
            untried: legalMoves(nb3, cur === GO_BLACK ? GO_WHITE : GO_BLACK, n, '')
          };
          const ci: number = nodes.length;
          nodes.push(child);
          if (nodes[idx].first < 0) {
            nodes[idx].first = ci;
          }
          nodes[idx].nkid++;
          b = nb3;
          cur = cur === GO_BLACK ? GO_WHITE : GO_BLACK;
          idx = ci;
        }
      }

      // ── ③ 模拟 ──
      const winner: number = goPlayout(b, cur, n);

      // ── ④ 回传 ──
      const aiWin: number = winner === aiWho ? 1 : 0;
      let p: number = idx;
      let guard: number = 0;
      while (p >= 0 && guard < 4096) {
        guard++;
        nodes[p].vis++;
        nodes[p].win += aiWin;
        p = nodes[p].par;
      }
    }

    // 选访问次数最多的根子节点（不是胜率最高的 —— 那会偏向没试过的）
    let best: number = -1;
    let bestVis: number = -1;
    let c: number = nodes[0].first;
    while (c >= 0) {
      if (nodes[c].vis > bestVis) {
        bestVis = nodes[c].vis;
        best = nodes[c].mv;
      }
      c = nextSibling(nodes, 0, c);
    }
    return best;
  } catch (e) {
    return -1;
  }
}
