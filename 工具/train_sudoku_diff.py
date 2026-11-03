#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数独难度模型 · 训练场（2026-10-23，路线 B）

为什么不用 .ms：
  SDK 里没有 converter_lite，也拿不到样例 .ms。
  但「30 维输入 → 12 隐层 → 1 输出」这种小网络**不需要任何框架**：
  它就是一串矩阵乘法 + 两个激活函数，ArkTS 里 40 行就能跑完。
  ⇒ 换掉转换链，换来：零依赖、零体积、可读可审计、调试直白。

标签怎么来（这一步是整个模型的地基，必须说清）：
  没有真实人类解题时间数据集 ⇒ 用【解题努力度】当代理标签：
    只用「唯一候选 + 隐性唯一」两种最基础的技巧往下推，
    推到推不动为止；然后数【还需要回溯搜索多少节点】才能解出来。
  ⇒ 需要的节点越多 = 越难。这与人类体感的排序高度相关，
    而且**可计算、可复现、不依赖人的主观标注**。

特征只用「出题后立刻能算出来」的量（运行时必须能复现）：
  挖空数、每行/列/宫给定数的方差、初始唯一候选数、初始隐性唯一数、
  首次推演能填的格子数、候选总量、双值格数 …
  ⚠️ 绝不能用「解题过程中才知道」的量当特征 —— 那叫标签泄漏。

用法：
  python3 工具/train_sudoku_diff.py --n 1200 --out entry/src/main/resources/rawfile/models/sudoku_diff.json
"""

import argparse
import json
import random
import sys
from typing import List, Tuple

N = 9
ALL = 0x1FF  # 9 位全 1


# ───────────────────────── 基础工具 ─────────────────────────
def popcount(x: int) -> int:
    return bin(x).count('1')


def bit_of(v: int) -> int:
    return 1 << (v - 1)


def row_of(i: int) -> int:
    return i // N


def col_of(i: int) -> int:
    return i % N


def box_of(i: int) -> int:
    return (row_of(i) // 3) * 3 + (col_of(i) // 3)


PEERS: List[List[int]] = []
for _i in range(81):
    s = set()
    r, c, b = row_of(_i), col_of(_i), box_of(_i)
    for j in range(81):
        if j == _i:
            continue
        if row_of(j) == r or col_of(j) == c or box_of(j) == b:
            s.add(j)
    PEERS.append(sorted(s))


def solve_count(grid: List[int], cap: int = 2, budget: List[int] = None) -> int:
    """数解的数量（最多数到 cap）。budget[0] 会随每个节点减一，到 0 就提前退出。"""
    if budget is None:
        budget = [10 ** 9]
    cnt = [0]

    def rec(g: List[int]) -> None:
        if budget[0] <= 0 or cnt[0] >= cap:
            return
        budget[0] -= 1
        # 找候选最少的空格（MRV）
        best = -1
        best_mask = 0
        best_n = 10
        for i in range(81):
            if g[i] != 0:
                continue
            mask = ALL
            for p in PEERS[i]:
                if g[p] != 0:
                    mask &= ~bit_of(g[p])
            n = popcount(mask)
            if n == 0:
                return
            if n < best_n:
                best_n, best, best_mask = n, i, mask
                if n == 1:
                    break
        if best < 0:
            cnt[0] += 1
            return
        for v in range(1, 10):
            if best_mask & bit_of(v):
                g[best] = v
                rec(g)
                g[best] = 0
                if cnt[0] >= cap or budget[0] <= 0:
                    return

    rec(list(grid))
    return cnt[0]


def gen_full(rng: random.Random) -> List[int]:
    """生成一个完整解（回溯 + 随机顺序）"""
    g = [0] * 81

    def rec(pos: int) -> bool:
        if pos == 81:
            return True
        # MRV 选点
        best, best_mask, best_n = -1, 0, 10
        for i in range(81):
            if g[i] != 0:
                continue
            mask = ALL
            for p in PEERS[i]:
                if g[p] != 0:
                    mask &= ~bit_of(g[p])
            n = popcount(mask)
            if n == 0:
                return False
            if n < best_n:
                best_n, best, best_mask = n, i, mask
                if n == 1:
                    break
        if best < 0:
            return True
        vals = [v for v in range(1, 10) if best_mask & bit_of(v)]
        rng.shuffle(vals)
        for v in vals:
            g[best] = v
            if rec(pos + 1):
                return True
            g[best] = 0
        return False

    rec(0)
    return g


def dig(full: List[int], holes: int, rng: random.Random) -> List[int]:
    """挖洞，保持唯一解"""
    g = list(full)
    order = list(range(81))
    rng.shuffle(order)
    dug = 0
    for i in order:
        if dug >= holes:
            break
        keep = g[i]
        g[i] = 0
        if solve_count(g, cap=2, budget=[40000]) != 1:
            g[i] = keep
        else:
            dug += 1
    return g


# ───────────────────────── 特征（只用出题后可算的量） ─────────────────────────
def cand_masks(g: List[int]) -> List[int]:
    masks = [0] * 81
    for i in range(81):
        if g[i] != 0:
            continue
        mask = ALL
        for p in PEERS[i]:
            if g[p] != 0:
                mask &= ~bit_of(g[p])
        masks[i] = mask
    return masks


def features(g: List[int]) -> List[float]:
    empties = [i for i in range(81) if g[i] == 0]
    masks = cand_masks(g)
    holes = len(empties)

    # ① 挖空数（归一到 0-1）
    f = [holes / 81.0]

    # ② 每行/列/宫给定数的标准差（分布不均 = 难）
    for unit_fn, label in ((row_of, 'row'), (col_of, 'col'), (box_of, 'box')):
        cnts = [0] * 9
        for i in range(81):
            if g[i] != 0:
                cnts[unit_fn(i)] += 1
        mean = sum(cnts) / 9.0
        var = sum((c - mean) ** 2 for c in cnts) / 9.0
        f.append((var ** 0.5) / 9.0)

    # ③ 初始唯一候选数 / 隐性唯一数
    singles = 0
    hidden = 0
    for i in empties:
        if popcount(masks[i]) == 1:
            singles += 1
    for unit_fn in (row_of, col_of, box_of):
        for u in range(9):
            cells = [i for i in range(81) if unit_fn(i) == u and g[i] == 0]
            for v in range(1, 10):
                spots = [i for i in cells if masks[i] & bit_of(v)]
                if len(spots) == 1:
                    hidden += 1
    f.append(singles / 81.0)
    f.append(hidden / 81.0)

    # ④ 候选总量 / 双值格 / 空格平均候选
    total = sum(popcount(masks[i]) for i in empties) if empties else 0
    f.append(total / (holes * 9.0) if holes else 0.0)
    two = sum(1 for i in empties if popcount(masks[i]) == 2)
    f.append(two / holes if holes else 0.0)
    three = sum(1 for i in empties if popcount(masks[i]) == 3)
    f.append(three / holes if holes else 0.0)

    # ⑤ 死局危险：有空格候选为 0
    dead = sum(1 for i in empties if popcount(masks[i]) == 0)
    f.append(1.0 if dead > 0 else 0.0)

    # ⑥ 给定格的数字分布（某个数字出现太少 = 难）
    num_cnt = [0] * 10
    for i in range(81):
        if g[i] != 0:
            num_cnt[g[i]] += 1
    mean = sum(num_cnt[1:]) / 9.0
    var = sum((c - mean) ** 2 for c in num_cnt[1:]) / 9.0
    f.append((var ** 0.5) / 9.0)

    return f


# ───────────────────────── 标签：解题努力度 ─────────────────────────
def label_effort_raw(g: List[int]) -> dict:
    """
    原始努力度（未归一）。

    ★★★ 2026-10-23 第一版翻车记录（这条必须留在代码里）：
      第一版标签 = 「回溯节点数 / 20000」。
      结果 **全部样本的标签都是 0.0001** —— 因为随机挖洞造出来的题
      **全都是「唯一候选 + 隐性唯一」就能推完的**（实测剩 0 空）。
      ⇒ 随机生成的数独天然偏简单，只有专门构造的题才需要高级技巧。
      ⇒ 所以改用【解题轮次】当主信号：一轮 = 从头扫一遍能不能填出新格。
        需要 19 轮才能推完的题，明显比 8 轮的重。方差在这里。

    返回各分量的原始值，由 main() 按百分位归一（这样永远有区分度）。
    """
    info = _solve_by_techniques(g)
    budget = [200000]
    solve_count(info['grid'], cap=1, budget=budget)
    nodes = 200000 - budget[0]
    return {'rounds': info['rounds'], 'steps': info['steps'], 'nodes': nodes}


def _solve_by_techniques(g: List[int]) -> dict:
    """只用唯一候选 + 隐性唯一往下推，返回轮次/步数/推完后的盘"""
    g = list(g)
    rounds = 0
    steps = 0
    while True:
        rounds += 1
        progressed = False
        masks = cand_masks(g)
        # 唯一候选
        for i in range(81):
            if g[i] == 0 and popcount(masks[i]) == 1:
                g[i] = masks[i].bit_length()
                steps += 1
                progressed = True
        if progressed:
            if rounds > 300:
                break
            continue
        # 隐性唯一
        masks = cand_masks(g)
        for unit_fn in (row_of, col_of, box_of):
            for u in range(9):
                cells = [i for i in range(81) if unit_fn(i) == u and g[i] == 0]
                for v in range(1, 10):
                    spots = [i for i in cells if masks[i] & bit_of(v)]
                    if len(spots) == 1:
                        g[spots[0]] = v
                        steps += 1
                        progressed = True
                        break
                if progressed:
                    break
            if progressed:
                break
        if not progressed or rounds > 300:
            break
    return {'grid': g, 'rounds': rounds, 'steps': steps}


# ───────────────────────── 极简 MLP（numpy 都不用） ─────────────────────────
def train(X: List[List[float]], Y: List[float], hid: int = 12, epochs: int = 4000,
          lr: float = 0.05, seed: int = 7):
    rng = random.Random(seed)
    nin = len(X[0])
    # He 初始化
    import math
    W1 = [[rng.gauss(0, math.sqrt(2.0 / nin)) for _ in range(nin)] for _ in range(hid)]
    b1 = [0.0] * hid
    W2 = [rng.gauss(0, math.sqrt(2.0 / hid)) for _ in range(hid)]
    b2 = 0.0

    n = len(X)
    for ep in range(epochs):
        gW1 = [[0.0] * nin for _ in range(hid)]
        gb1 = [0.0] * hid
        gW2 = [0.0] * hid
        gb2 = 0.0
        loss = 0.0
        for k in range(n):
            x = X[k]
            # forward
            h = [0.0] * hid
            for j in range(hid):
                s = b1[j]
                wj = W1[j]
                for i in range(nin):
                    s += wj[i] * x[i]
                h[j] = s if s > 0 else 0.0     # ReLU
            out = b2
            for j in range(hid):
                out += W2[j] * h[j]
            y = Y[k]
            d = out - y
            loss += d * d
            # backward
            gb2 += d
            for j in range(hid):
                gW2[j] += d * h[j]
                if h[j] > 0:
                    dh = d * W2[j]
                    gb1[j] += dh
                    for i in range(nin):
                        gW1[j][i] += dh * x[i]
        # update
        sc = 1.0 / n
        for j in range(hid):
            W2[j] -= lr * gW2[j] * sc
            b1[j] -= lr * gb1[j] * sc
            for i in range(nin):
                W1[j][i] -= lr * gW1[j][i] * sc
        b2 -= lr * gb2 * sc
        if ep % 500 == 0:
            print('  epoch %-5d loss=%.5f' % (ep, loss / n))
    return W1, b1, W2, b2


def forward(model, x: List[float]) -> float:
    W1, b1, W2, b2 = model
    hid = len(W2)
    out = b2
    for j in range(hid):
        s = b1[j]
        wj = W1[j]
        for i in range(len(x)):
            s += wj[i] * x[i]
        h = s if s > 0 else 0.0
        out += W2[j] * h
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--n', type=int, default=600, help='样本数（每档挖空数均匀采样）')
    ap.add_argument('--out', type=str, default='entry/src/main/resources/rawfile/models/sudoku_diff.json')
    ap.add_argument('--seed', type=int, default=20261023)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    print('  ══ 造数据（%d 题）：生成完整解 → 按挖空数挖洞 → 特征 → 标签' % args.n)
    X, Y, meta = [], [], []
    RAW = []
    for t in range(args.n):
        holes = rng.choice([26, 30, 34, 38, 42, 46, 50, 54])
        full = gen_full(rng)
        g = dig(full, holes, rng)
        f = features(g)
        raw = label_effort_raw(g)
        X.append(f)
        RAW.append(raw)
        meta.append({'holes': sum(1 for v in g if v == 0), 'raw': raw})
        if (t + 1) % max(1, args.n // 10) == 0:
            print('     %d/%d' % (t + 1, args.n))

    # ★ 百分位归一：标签 = 这个样本的努力度在全体里的排名（0-1）
    #   为什么不用 min-max：极少数特别简单的题会把其余全挤到接近 0
    def effort_score(r: dict) -> float:
        return r['rounds'] * 1.0 + r['steps'] * 0.02 + r['nodes'] / 2000.0
    order = sorted(range(len(RAW)), key=lambda k: effort_score(RAW[k]))
    Y = [0.0] * len(RAW)
    for rank, k in enumerate(order):
        Y[k] = rank / max(1, len(RAW) - 1)
    print('  ══ 努力度分量: rounds %d-%d ｜ steps %d-%d ｜ nodes %d-%d'
          % (min(r['rounds'] for r in RAW), max(r['rounds'] for r in RAW),
             min(r['steps'] for r in RAW), max(r['steps'] for r in RAW),
             min(r['nodes'] for r in RAW), max(r['nodes'] for r in RAW)))

    ys = sorted(Y)
    print('  ══ 标签分布: min=%.4f p25=%.4f 中位=%.4f p75=%.4f max=%.4f'
          % (ys[0], ys[len(ys)//4], ys[len(ys)//2], ys[3*len(ys)//4], ys[-1]))

    # 标准化特征（推理时要带同样的均值/方差）
    nin = len(X[0])
    mean = [sum(X[k][i] for k in range(len(X))) / len(X) for i in range(nin)]
    std = []
    for i in range(nin):
        v = sum((X[k][i] - mean[i]) ** 2 for k in range(len(X))) / len(X)
        std.append(max(1e-6, v ** 0.5))
    Xn = [[(X[k][i] - mean[i]) / std[i] for i in range(nin)] for k in range(len(X))]

    print('  ══ 训练（%d 维 → 12 → 1，全手写，无框架）' % nin)
    model = train(Xn, Y, hid=12, epochs=4000, lr=0.05)

    # 评估
    err = [abs(forward(model, Xn[k]) - Y[k]) for k in range(len(Xn))]
    mae = sum(err) / len(err)
    print('  ══ 训练集 MAE = %.4f' % mae)
    # 排序一致性（难度排序比绝对值更重要）
    pairs = 0
    agree = 0
    for a in range(0, len(Xn), 7):
        for b in range(a + 1, len(Xn), 11):
            if abs(Y[a] - Y[b]) < 0.02:
                continue
            pairs += 1
            pa = forward(model, Xn[a])
            pb = forward(model, Xn[b])
            if (Y[a] > Y[b]) == (pa > pb):
                agree += 1
    print('  ══ 排序一致率 = %.1f%%（%d 对）' % (100.0 * agree / max(1, pairs), pairs))

    W1, b1, W2, b2 = model
    out = {
        'app': 'One More',
        'kind': 'sudoku-difficulty',
        'version': 1,
        'note': '手写 MLP（无框架）：特征标准化 → ReLU(12) → 线性 → 0-1 难度',
        'inDim': nin,
        'hidden': len(W2),
        'featureMean': [round(v, 6) for v in mean],
        'featureStd': [round(v, 6) for v in std],
        'W1': [[round(v, 6) for v in row] for row in W1],
        'b1': [round(v, 6) for v in b1],
        'W2': [round(v, 6) for v in W2],
        'b2': round(b2, 6),
        'trainMae': round(mae, 4),
        'rankAgree': round(agree / max(1, pairs), 3),
        'samples': len(X),
    }
    import os
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    sz = os.path.getsize(args.out)
    print('  ══ 已写出 %s（%d B）' % (args.out, sz))


if __name__ == '__main__':
    main()
