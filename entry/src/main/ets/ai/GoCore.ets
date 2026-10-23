/**
 * GoCore —— 9 路围棋的纯规则（2026-10-23 第二期抽出来）
 *
 * 为什么单独一个文件：
 *   MCTS 要搬到 TaskPool 工作线程（否则 400 ms 会冻住界面）。
 *   @Concurrent 函数不能带闭包，但**可以调用同模块导出的纯函数**
 *   ⇒ 规则抽到这里，游戏与 worker 共用同一份，不会分叉。
 *
 * ★ 本文件内容是从 GGo9.ets 第 51–259 行**原样搬过来的**，逻辑一字未改，
 *   只加了 export 前缀。
 * ⚠️ 已知重复：GGo9.ets 里仍保留自己的私有副本。
 *    将来应该让 GGo9 直接 import 这里，但那是大改游戏文件，
 *    本轮先保证 AI 侧有一份可信的规则。
 */

export const GO_EMPTY: number = 0;
export const GO_BLACK: number = 1;
export const GO_WHITE: number = 2;

const EMPTY: number = 0;
const BLACK: number = 1;
const WHITE: number = 2;

export function nbrs(i: number, n: number): number[] {
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
export function groupOf(b: number[], i: number, n: number): number[] {
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
export function libsOf(b: number[], grp: number[], n: number): number {
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
export function libsAt(b: number[], i: number, n: number): number {
  return libsOf(b, groupOf(b, i, n), n);
}

/**
 * 落子 + 提子。返回新局面；**非法（自杀）返回 null**。
 * 打劫不在这里判（由调用方比局面哈希）。
 */
export function placeStone(b: number[], i: number, who: number, n: number): number[] | null {
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
export function capturedBy(before: number[], after: number[], who: number): number {
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
export function areaScore(b: number[], n: number): number[] {
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
export function isOwnEye(b: number[], i: number, who: number, n: number): boolean {
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
export function legalMoves(b: number[], who: number, n: number, koStr: string): number[] {
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
export function pickRandom(arr: number[], seed: number): number {
  if (arr.length === 0) {
    return -1;
  }
  const k: number = seed % arr.length;
  return arr[k];
}

