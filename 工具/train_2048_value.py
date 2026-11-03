#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2048 价值网络 · 训练场（2026-10-23，路线 C）

思路（为什么用「价值网络 + 一步前瞻」而不是 DQN/PPO）：
  DQN 要在端侧保存 Q 表或大网络，PPO 要策略分布采样 —— 对 4×4 的 2048 都太重。
  真正有效且**能塞进 ArkTS 手写前向**的做法是：
    ① 训一个价值网络 V(state) ≈ 从这局面继续打到结束还能得多少分
    ② 端侧只做一步前瞻：对 4 个方向各算「滑动后的局面」，取 V 最大的那个
  ⇒ 网络只需 24 维输入、一个标量输出；端侧推理 4 次，几百次乘加，毫秒级

数据从哪来（不需要人类对局）：
  用启发式策略自对弈一局 → 记录沿途每个局面 + 当时的累计分
  → 标签 = 「本局最终分 − 当时累计分」= 从该局面起还能拿多少分
  ⇒ 这就是蒙特卡洛价值估计，标签天然对齐 V 的定义
  ⚠️ 局限：只覆盖「启发式策略会遇到的局面」。但启发式本身不弱，
     而且端侧是用这个 V 做前瞻（比生成数据的策略更强），属于 off-policy 提升。

用法：
  python3 工具/train_2048_value.py --games 400 --out entry/src/main/resources/rawfile/models/g2048_value.json
"""

import argparse
import json
import math
import os
import random
from typing import List, Tuple

N = 4
CELLS = N * N


# ───────────────────────── 引擎（与 G2048.ets 逐行对应） ─────────────────────────
def collapse(line: List[int]) -> Tuple[List[int], int]:
    """与 G2048.ets 的 collapse 完全一致：左到右、每块最多合一次"""
    out = [v for v in line if v != 0]
    gained = 0
    i = 0
    while i < len(out) - 1:
        if out[i] == out[i + 1]:
            out[i] = out[i] * 2
            gained += out[i]
            out.pop(i + 1)
        i += 1
    while len(out) < N:
        out.append(0)
    return out, gained


def get_line(cells: List[int], r: int) -> List[int]:
    return [cells[r * N + c] for c in range(N)]


def get_col(cells: List[int], c: int) -> List[int]:
    return [cells[r * N + c] for r in range(N)]


def set_line(cells: List[int], r: int, vals: List[int]) -> None:
    for c in range(N):
        cells[r * N + c] = vals[c]


def set_col(cells: List[int], c: int, vals: List[int]) -> None:
    for r in range(N):
        cells[r * N + c] = vals[r]


DIRS = 4  # 0 左 / 1 右 / 2 上 / 3 下


def apply_move(cells: List[int], d: int) -> Tuple[List[int], int, bool]:
    """返回 (新盘, 得分, 是否真的动了)。不生成新块。"""
    g = list(cells)
    gained = 0
    moved = False
    if d in (0, 1):
        for r in range(N):
            line = get_line(g, r)
            src = line if d == 0 else list(reversed(line))
            out, gn = collapse(src)
            gained += gn
            res = out if d == 0 else list(reversed(out))
            if res != line:
                moved = True
            set_line(g, r, res)
    else:
        for c in range(N):
            col = get_col(g, c)
            src = col if d == 2 else list(reversed(col))
            out, gn = collapse(src)
            gained += gn
            res = out if d == 2 else list(reversed(out))
            if res != col:
                moved = True
            set_col(g, c, res)
    return g, gained, moved


def spawn(cells: List[int], rng: random.Random) -> bool:
    empty = [i for i in range(CELLS) if cells[i] == 0]
    if not empty:
        return False
    i = rng.choice(empty)
    cells[i] = 2 if rng.random() < 0.9 else 4
    return True


def is_dead(cells: List[int]) -> bool:
    for d in range(DIRS):
        _, _, moved = apply_move(cells, d)
        if moved:
            return False
    return True


# ───────────────────────── 特征（端侧必须能复现） ─────────────────────────
def features(cells: List[int]) -> List[float]:
    """24 维：16 个 log2 归一 + 8 个整体特征"""
    f = [0.0] * 24
    # ① 16 格：log2(v)/17（2^17 封顶，超过也夹住）
    for i in range(CELLS):
        v = cells[i]
        f[i] = 0.0 if v == 0 else min(1.0, math.log2(v) / 17.0)

    mx = max(cells) if cells else 0
    empty = sum(1 for v in cells if v == 0)
    # ② 最大块
    f[16] = 0.0 if mx == 0 else min(1.0, math.log2(mx) / 17.0)
    # ③ 空格数
    f[17] = empty / 16.0
    # ④ 单调性（行列各取「递增/递减哪个更顺」的归一和）
    mono = 0.0
    for r in range(N):
        line = [math.log2(v) if v > 0 else 0 for v in get_line(cells, r)]
        d1 = sum(max(0, line[i] - line[i + 1]) for i in range(N - 1))
        d2 = sum(max(0, line[i + 1] - line[i]) for i in range(N - 1))
        mono += min(d1, d2)
    f[18] = min(1.0, mono / 40.0)
    mono = 0.0
    for c in range(N):
        line = [math.log2(v) if v > 0 else 0 for v in get_col(cells, c)]
        d1 = sum(max(0, line[i] - line[i + 1]) for i in range(N - 1))
        d2 = sum(max(0, line[i + 1] - line[i]) for i in range(N - 1))
        mono += min(d1, d2)
    f[19] = min(1.0, mono / 40.0)
    # ⑤ 平滑度（相邻格差值的相反数）
    sm = 0.0
    for r in range(N):
        for c in range(N - 1):
            a = math.log2(cells[r * N + c]) if cells[r * N + c] > 0 else 0
            b = math.log2(cells[r * N + c + 1]) if cells[r * N + c + 1] > 0 else 0
            sm += abs(a - b)
    for c in range(N):
        for r in range(N - 1):
            a = math.log2(cells[r * N + c]) if cells[r * N + c] > 0 else 0
            b = math.log2(cells[(r + 1) * N + c]) if cells[(r + 1) * N + c] > 0 else 0
            sm += abs(a - b)
    f[20] = min(1.0, sm / 60.0)
    # ⑥ 可合并对数
    merges = 0
    for r in range(N):
        for c in range(N - 1):
            a, b = cells[r * N + c], cells[r * N + c + 1]
            if a != 0 and a == b:
                merges += 1
    for c in range(N):
        for r in range(N - 1):
            a, b = cells[r * N + c], cells[(r + 1) * N + c]
            if a != 0 and a == b:
                merges += 1
    f[21] = min(1.0, merges / 12.0)
    # ⑦ 最大块是否在角落
    corner = 0.0
    if mx > 0:
        idx = cells.index(mx)
        r, c = idx // N, idx % N
        if (r in (0, N - 1)) and (c in (0, N - 1)):
            corner = 1.0
        elif r in (0, N - 1) or c in (0, N - 1):
            corner = 0.5
    f[22] = corner
    # ⑧ 空格分布（四个角有几个空）
    ec = sum(1 for (r, c) in ((0, 0), (0, N-1), (N-1, 0), (N-1, N-1)) if cells[r * N + c] == 0)
    f[23] = ec / 4.0
    return f


# ───────────────────────── 启发式策略（生成数据用） ─────────────────────────
def heuristic_value(cells: List[int]) -> float:
    f = features(cells)
    # 手工权重：空位最值钱，其次单调、平滑、角落
    return (f[17] * 120.0 + f[22] * 60.0 + (1.0 - f[18]) * 50.0
            + (1.0 - f[19]) * 50.0 + (1.0 - f[20]) * 40.0 + f[21] * 15.0
            + f[16] * 100.0)


def pick_heuristic(cells: List[int], rng: random.Random) -> int:
    """一步前瞻 + 启发式评估（用作生成数据的策略）"""
    best, bestv = -1, -1e18
    for d in range(DIRS):
        g, gain, moved = apply_move(cells, d)
        if not moved:
            continue
        v = heuristic_value(g) + gain * 0.05
        if v > bestv:
            bestv, best = v, d
    if best < 0:
        return -1
    return best


# ───────────────────────── 自对弈造数据 ─────────────────────────
def play_one(rng: random.Random, max_steps: int = 3000, horizon: int = 30):
    """
    返回 [(state, K 步回报)]。

    ★★★ 2026-10-23 第二次翻车记录：
      标签原本 = 「最终分 - 当时分」（整局剩余分）。
      20 局 → 排序一致率 **53.6%**，接近瞎猜。
      根因：同一局面在不同局里剩余分能差 10 倍，运气完全主导 ⇒
            模型学到的是"这局好不好"，不是"这局面好不好"。
      ⇒ 改成 **K 步回报**：从这一刻起再走 horizon 步能拿多少分。
        方差大幅下降，且仍与真实价值单调相关（标准 TD(K) 思想）。
    """
    cells = [0] * CELLS
    spawn(cells, rng)
    spawn(cells, rng)
    score = 0
    snaps = []          # [(state, score)]
    for _ in range(max_steps):
        d = pick_heuristic(cells, rng)
        if d < 0:
            break
        snaps.append((list(cells), score))
        g, gain, moved = apply_move(cells, d)
        if not moved:
            break
        cells = g
        score += gain
        spawn(cells, rng)
        if is_dead(cells):
            break

    out = []
    for i, (st, sc) in enumerate(snaps):
        j = min(len(snaps) - 1, i + horizon)
        # snaps[j][1] 是"走完 j-i 步之后"的分数；最后一个格子用终局分
        out.append((st, float(snaps[j][1] - sc)))
    return out


# ───────────────────────── MLP 训练（numpy，向量化） ─────────────────────────
# ★ 为什么训练用 numpy 而前向仍手写：
#   纯 Python 跑 13,745 样本 × 2500 轮 = 200 亿次乘加，实测要几十分钟。
#   训练是离线的一次性工作，用 numpy 天经地义；
#   而**前向**必须手写，因为要移植到 ArkTS（那边没有 numpy）。
#   ⇒ 训练完用 工具/test_2048_model.mjs 对拍，保证两者数值一致。

def train(X, Y, hid=24, epochs=3000, lr=0.02, seed=11, batch=256):
    import numpy as np
    rng = np.random.default_rng(seed)
    X = np.asarray(X, dtype=np.float64)
    Y = np.asarray(Y, dtype=np.float64)
    n, nin = X.shape
    W1 = rng.normal(0, math.sqrt(2.0 / nin), size=(nin, hid))
    b1 = np.zeros(hid)
    W2 = rng.normal(0, math.sqrt(2.0 / hid), size=(hid,))
    b2 = 0.0
    for ep in range(epochs):
        idx = rng.permutation(n)
        tot = 0.0
        for st in range(0, n, batch):
            bi = idx[st:st + batch]
            xb = X[bi]
            yb = Y[bi]
            z = xb @ W1 + b1
            h = np.maximum(0.0, z)
            out = h @ W2 + b2
            d = (out - yb) * (2.0 / len(bi))        # dL/dout，L = mean((out-y)^2)
            gW2 = h.T @ d
            gb2 = d.sum()
            dh = np.outer(d, W2) * (z > 0)
            gW1 = xb.T @ dh
            gb1 = dh.sum(axis=0)
            W2 -= lr * gW2
            b2 -= lr * gb2
            W1 -= lr * gW1
            b1 -= lr * gb1
            tot += float(((out - yb) ** 2).mean()) * len(bi)
        if ep % 300 == 0:
            print('     epoch %-5d mse=%.4f' % (ep, tot / n))
    # ★★★ 2026-10-23 抓到的真 bug：numpy 里 W1 是 (nin, hid)，
    #   而手写 fwd / ArkTS 侧要的是 W1[j][i]（hid, nin）⇒ **必须转置**
    #   没转置的话模型等于随机数：排序一致率会卡在 50%（实测就是 50.7%）
    return W1.T.tolist(), b1.tolist(), W2.tolist(), float(b2)


def fwd(model, x):
    W1, b1, W2, b2 = model
    out = b2
    for j in range(len(W2)):
        s = b1[j]
        wj = W1[j]
        for i in range(len(x)):
            s += wj[i] * x[i]
        if s > 0:
            out += W2[j] * s
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--games', type=int, default=300)
    ap.add_argument('--out', type=str, default='entry/src/main/resources/rawfile/models/g2048_value.json')
    ap.add_argument('--seed', type=int, default=20261023)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    print('  ══ 自对弈 %d 局造数据（启发式策略）' % args.games)
    raw_X, raw_Y = [], []
    best = 0
    for g in range(args.games):
        traj = play_one(rng)
        for (s, remain) in traj:
            raw_X.append(features(s))
            raw_Y.append(remain)
        if traj:
            best = max(best, traj[0][1])
        if (g + 1) % max(1, args.games // 10) == 0:
            print('     %d/%d（当前最大局分 %.0f）' % (g + 1, args.games, best))

    print('  ══ 样本 %d，剩余分范围 %.0f ~ %.0f' % (len(raw_X), min(raw_Y), max(raw_Y)))

    # ★★★ 2026-10-23 第一次训练翻车记录（必须留着）：
    #   标签原本直接用「剩余得分」，20 局 → MAE 13,909 分，而标签标准差只有 5,290
    #   ⇒ 比瞎猜还烂。根因：同一局面在不同局的剩余分能差 10 倍（运气主导），
    #     小样本下模型学到的是"这一局好不好"，不是"这个局面好不好"。
    #   ⇒ 两个改动：① 标签取 log1p（压缩数量级差）
    #             ② 评估改用【排序相关】—— 前瞻时只比较 4 个后继局面，
    #                绝对值不重要，谁排前面才重要
    LOGY = [math.log1p(max(0.0, y)) for y in raw_Y]
    ymean = sum(LOGY) / len(LOGY)
    ysd = max(1e-3, (sum((y - ymean) ** 2 for y in LOGY) / len(LOGY)) ** 0.5)
    Y = [(y - ymean) / ysd for y in LOGY]
    X = raw_X

    # 特征标准化
    nin = len(X[0])
    mean = [sum(X[k][i] for k in range(len(X))) / len(X) for i in range(nin)]
    std = []
    for i in range(nin):
        v = sum((X[k][i] - mean[i]) ** 2 for k in range(len(X))) / len(X)
        std.append(max(1e-6, v ** 0.5))
    Xn = [[(X[k][i] - mean[i]) / std[i] for i in range(nin)] for k in range(len(X))]

    print('  ══ 训练（24 → 24 → 1，全手写）')
    model = train(Xn, Y, hid=24, epochs=2500, lr=0.02)

    # 评估：排序相关（这才是前瞻真正依赖的）
    import random as _r
    rr = _r.Random(5)
    pairs = 0
    agree = 0
    for _ in range(20000):
        a = rr.randrange(len(Xn)); b = rr.randrange(len(Xn))
        la, lb = raw_Y[a], raw_Y[b]
        if abs(la - lb) < 300:      # 太接近的放过（噪声主导）
            continue
        pairs += 1
        pa, pb = fwd(model, Xn[a]), fwd(model, Xn[b])
        if (la > lb) == (pa > pb):
            agree += 1
    rank = agree / max(1, pairs)
    mae = 0.0
    print('  ══ 排序一致率 = %.1f%%（%d 对）' % (100.0 * rank, pairs))

    W1, b1, W2, b2 = model
    out = {
        'kind': 'g2048-value',
        'version': 1,
        'note': '手写 MLP：24 维特征 → ReLU(24) → 1；输出需 *yStd + yMean 才是「剩余分」',
        'inDim': nin, 'hidden': len(W2),
        'featureMean': [round(v, 6) for v in mean],
        'featureStd': [round(v, 6) for v in std],
        'yMean': round(ymean, 6), 'yStd': round(ysd, 6), 'logLabel': 1,
        'W1': [[round(v, 6) for v in row] for row in W1],
        'b1': [round(v, 6) for v in b1],
        'W2': [round(v, 6) for v in W2],
        'b2': round(b2, 6),
        'rankAgree': round(rank, 4),
        'samples': len(X),
        'bestGameScore': int(best),
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print('  ══ 已写出 %s（%d B）' % (args.out, os.path.getsize(args.out)))


if __name__ == '__main__':
    main()
