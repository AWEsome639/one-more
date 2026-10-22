/**
 * SudokuFeatures —— 数独盘面的特征提取（2026-10-23，路线 B）
 *
 * ★★★ 这个文件必须与 工具/train_sudoku_diff.py 的 features() **逐项一致**。
 *   差一项、差一个归一化除数，模型就全错，而且不会报错（只是预测歪了）。
 *   ⇒ 改这里必须同步改那边，并用 工具/test_sudoku_model.mjs 复验。
 *
 * 特征（11 维，顺序不能动）：
 *   0  挖空数 / 81
 *   1  每行给定数的标准差 / 9
 *   2  每列给定数的标准差 / 9
 *   3  每宫给定数的标准差 / 9
 *   4  初始唯一候选数 / 81
 *   5  初始隐性唯一数 / 81
 *   6  候选总量 / (挖空数 × 9)
 *   7  双候选格数 / 挖空数
 *   8  三候选格数 / 挖空数
 *   9  存在候选为 0 的格（死局风险）→ 0 或 1
 *   10 各数字出现次数的标准差 / 9
 *
 * ⚠️ 全部只用「出题后立刻能算出来」的量。
 *    绝不能用解题过程中才知道的量（那是标签泄漏，离线能训、线上必崩）。
 */

const N: number = 9;
const ALL: number = 0x1FF;

/** 每格的 20 个关联格（同行/列/宫，不含自己）—— 只算一次 */
const PEERS: number[][] = (() => {
  const out: number[][] = [];
  for (let i = 0; i < 81; i++) {
    const r: number = Math.floor(i / N);
    const c: number = i % N;
    const b: number = Math.floor(r / 3) * 3 + Math.floor(c / 3);
    const list: number[] = [];
    for (let j = 0; j < 81; j++) {
      if (j === i) {
        continue;
      }
      const jr: number = Math.floor(j / N);
      const jc: number = j % N;
      const jb: number = Math.floor(jr / 3) * 3 + Math.floor(jc / 3);
      if (jr === r || jc === c || jb === b) {
        list.push(j);
      }
    }
    out.push(list);
  }
  return out;
})();

function popcount(x: number): number {
  let n: number = 0;
  let v: number = x;
  while (v !== 0) {
    v = v & (v - 1);
    n++;
  }
  return n;
}

function bitOf(v: number): number {
  return 1 << (v - 1);
}

/** 每格的候选掩码（已填格返回 0） */
function candMasks(g: number[]): number[] {
  const masks: number[] = new Array<number>(81);
  for (let i = 0; i < 81; i++) {
    if (g[i] !== 0) {
      masks[i] = 0;
      continue;
    }
    let mask: number = ALL;
    const ps: number[] = PEERS[i];
    for (let k = 0; k < ps.length; k++) {
      const p: number = ps[k];
      if (g[p] !== 0) {
        mask = mask & ~bitOf(g[p]);
      }
    }
    masks[i] = mask;
  }
  return masks;
}

/** 单位（行/列/宫）映射 */
function unitOf(i: number, kind: number): number {
  const r: number = Math.floor(i / N);
  const c: number = i % N;
  if (kind === 0) {
    return r;
  }
  if (kind === 1) {
    return c;
  }
  return Math.floor(r / 3) * 3 + Math.floor(c / 3);
}

/** 某维度的标准差（除以 9，与训练脚本同一口径） */
function unitStd(g: number[], kind: number): number {
  const cnts: number[] = new Array<number>(9);
  for (let u = 0; u < 9; u++) {
    cnts[u] = 0;
  }
  for (let i = 0; i < 81; i++) {
    if (g[i] !== 0) {
      cnts[unitOf(i, kind)]++;
    }
  }
  let mean: number = 0;
  for (let u = 0; u < 9; u++) {
    mean += cnts[u];
  }
  mean = mean / 9.0;
  let v: number = 0;
  for (let u = 0; u < 9; u++) {
    v += (cnts[u] - mean) * (cnts[u] - mean);
  }
  v = v / 9.0;
  return Math.sqrt(v) / 9.0;
}

/**
 * 提取 11 维特征。g 是 81 长度数组，0 = 空，1..9 = 已填。
 */
export function sudokuFeatures(g: number[]): number[] {
  let holes: number = 0;
  for (let i = 0; i < 81; i++) {
    if (g[i] === 0) {
      holes++;
    }
  }
  const masks: number[] = candMasks(g);
  const f: number[] = new Array<number>(11);

  // 0 挖空数
  f[0] = holes / 81.0;
  // 1-3 行/列/宫 给定数标准差
  f[1] = unitStd(g, 0);
  f[2] = unitStd(g, 1);
  f[3] = unitStd(g, 2);

  // 4 唯一候选数 / 5 隐性唯一数
  let singles: number = 0;
  for (let i = 0; i < 81; i++) {
    if (g[i] === 0 && popcount(masks[i]) === 1) {
      singles++;
    }
  }
  f[4] = singles / 81.0;

  let hidden: number = 0;
  for (let kind = 0; kind < 3; kind++) {
    for (let u = 0; u < 9; u++) {
      // 这个单位里的空格
      const cells: number[] = [];
      for (let i = 0; i < 81; i++) {
        if (g[i] === 0 && unitOf(i, kind) === u) {
          cells.push(i);
        }
      }
      for (let v = 1; v <= 9; v++) {
        let spots: number = 0;
        const bv: number = bitOf(v);
        for (let k = 0; k < cells.length; k++) {
          if ((masks[cells[k]] & bv) !== 0) {
            spots++;
          }
        }
        if (spots === 1) {
          hidden++;
        }
      }
    }
  }
  f[5] = hidden / 81.0;

  // 6 候选总量 / 7 双候选 / 8 三候选
  let total: number = 0;
  let two: number = 0;
  let three: number = 0;
  for (let i = 0; i < 81; i++) {
    if (g[i] !== 0) {
      continue;
    }
    const n: number = popcount(masks[i]);
    total += n;
    if (n === 2) {
      two++;
    } else if (n === 3) {
      three++;
    }
  }
  f[6] = holes > 0 ? total / (holes * 9.0) : 0.0;
  f[7] = holes > 0 ? two / holes : 0.0;
  f[8] = holes > 0 ? three / holes : 0.0;

  // 9 死局风险
  let dead: boolean = false;
  for (let i = 0; i < 81; i++) {
    if (g[i] === 0 && popcount(masks[i]) === 0) {
      dead = true;
      break;
    }
  }
  f[9] = dead ? 1.0 : 0.0;

  // 10 各数字出现次数的标准差
  const numCnt: number[] = new Array<number>(10);
  for (let v = 0; v <= 9; v++) {
    numCnt[v] = 0;
  }
  for (let i = 0; i < 81; i++) {
    if (g[i] !== 0) {
      numCnt[g[i]]++;
    }
  }
  let mean: number = 0;
  for (let v = 1; v <= 9; v++) {
    mean += numCnt[v];
  }
  mean = mean / 9.0;
  let var2: number = 0;
  for (let v = 1; v <= 9; v++) {
    var2 += (numCnt[v] - mean) * (numCnt[v] - mean);
  }
  var2 = var2 / 9.0;
  f[10] = Math.sqrt(var2) / 9.0;

  return f;
}
