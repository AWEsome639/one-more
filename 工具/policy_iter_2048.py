#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2048 策略迭代（2026-10-23）

为什么需要它（上一轮的教训）：
  拿"在启发式轨迹上训出来的价值网络"直接贪心用 ⇒ 100 局均分 10,885 → 919
  根因：贪心决策会走到训练分布之外。这是 off-policy 评估的根本问题。
  ⇒ 正解是**策略迭代**：用当前策略产生数据 → 训价值 → 用新价值贪心 → 再产生数据

循环：
  π0 = 启发式（已知均分 ~10,900）
  V0 = 训练于 π0 的轨迹
  π1 = V0 贪心 + ε 探索        ← 关键：ε 探索让数据覆盖 V 贪心会走到的局面
  V1 = 训练于 π1 的轨迹
  π2 = V1 贪心 + ε
  …
每轮都测一次 π 的实际均分，看有没有真的变强。

⚠️ 说清楚：这是「策略迭代」的教学版，不是 PPO。
   目标是回答一个问题：**这个价值网络还有救吗，还是启发式已经够好了。**
"""

import argparse, json, math, random, statistics, sys, importlib.util

sys.path.insert(0, '/Users/a0000/dev/yiju/工具')
spec = importlib.util.spec_from_file_location('t', '/Users/a0000/dev/yiju/工具/train_2048_value.py')
E = importlib.util.module_from_spec(spec); spec.loader.exec_module(E)

NIN, HID = 24, 24

def load_model(path):
    return json.load(open(path, encoding='utf-8'))

def fwd(W, x):
    xs = [(x[i] - W['featureMean'][i]) / (W['featureStd'][i] or 1) for i in range(W['inDim'])]
    out = W['b2']
    for j in range(W['hidden']):
        s = W['b1'][j] + sum(W['W1'][j][i] * xs[i] for i in range(W['inDim']))
        if s > 0:
            out += W['W2'][j] * s
    return out * W['yStd'] + W['yMean']     # 还原到 log1p 空间

def value_of(W, cells):
    return fwd(W, E.features(cells))

def pick_value(W, cells, rng, eps=0.0):
    """V 贪心 + ε 随机（ε 让数据覆盖到 V 自己会走到的局面）"""
    moves = []
    for d in range(4):
        g, gain, moved = E.apply_move(cells, d)
        if moved:
            moves.append((d, g, gain))
    if not moves:
        return -1
    if eps > 0 and rng.random() < eps:
        return rng.choice(moves)[0]
    best, bestv = -1, -1e18
    for (d, g, gain) in moves:
        v = value_of(W, g) + gain * 0.02
        if v > bestv:
            bestv, best = v, d
    return best

def play(policy, rng, max_steps=4000, collect=False):
    cells = [0] * 16
    E.spawn(cells, rng); E.spawn(cells, rng)
    score = 0
    traj = []
    for _ in range(max_steps):
        d = policy(cells, rng)
        if d < 0:
            break
        if collect:
            traj.append((list(cells), score))
        g, gain, moved = E.apply_move(cells, d)
        if not moved:
            break
        cells = g; score += gain
        E.spawn(cells, rng)
        if E.is_dead(cells):
            break
    if collect:
        out = []
        H = 30
        for i, (st, sc) in enumerate(traj):
            j = min(len(traj) - 1, i + H)
            out.append((st, float(traj[j][1] - sc)))
        return score, max(cells), out
    return score, max(cells), []

def train(X, Y, epochs=1200, lr=0.02, seed=11):
    import numpy as np
    rng = np.random.default_rng(seed)
    X = np.asarray(X, dtype=np.float64)
    Y = np.asarray(Y, dtype=np.float64)
    n, nin = X.shape
    W1 = rng.normal(0, math.sqrt(2.0 / nin), size=(nin, HID))
    b1 = np.zeros(HID)
    W2 = rng.normal(0, math.sqrt(2.0 / HID), size=(HID,))
    b2 = 0.0
    for ep in range(epochs):
        idx = rng.permutation(n)
        for st in range(0, n, 256):
            bi = idx[st:st + 256]
            xb, yb = X[bi], Y[bi]
            z = xb @ W1 + b1
            h = np.maximum(0.0, z)
            out = h @ W2 + b2
            d = (out - yb) * (2.0 / len(bi))
            gW2 = h.T @ d; gb2 = d.sum()
            dh = np.outer(d, W2) * (z > 0)
            W1 -= lr * (xb.T @ dh); b1 -= lr * dh.sum(axis=0)
            W2 -= lr * gW2; b2 -= lr * gb2
    return W1.T.tolist(), b1.tolist(), W2.tolist(), float(b2)

def to_model(W1, b1, W2, b2, mean, std, ymean, ysd):
    return {'inDim': NIN, 'hidden': HID, 'featureMean': mean, 'featureStd': std,
            'yMean': ymean, 'yStd': ysd, 'W1': W1, 'b1': b1, 'W2': W2, 'b2': b2}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--iters', type=int, default=3)
    ap.add_argument('--games', type=int, default=80)
    ap.add_argument('--eval-games', type=int, default=30)
    ap.add_argument('--eval-seed', type=int, default=999)
    ap.add_argument('--out', type=str, default='/tmp/pi_2048.json')
    a = ap.parse_args()

    print('  ══ 基线：启发式跑 %d 局' % a.eval_games)
    rng = random.Random(a.eval_seed)
    base = [play(E.pick_heuristic, rng)[0] for _ in range(a.eval_games)]
    base_mean = statistics.mean(base)
    print('     π0 启发式：均分 %.0f ｜ 中位 %.0f' % (base_mean, statistics.median(base)))

    # 初始数据：启发式轨迹
    rng = random.Random(1234)
    X, Y = [], []
    for _ in range(a.games):
        _, _, traj = play(E.pick_heuristic, rng, collect=True)
        for (st, r) in traj:
            X.append(E.features(st)); Y.append(r)
    print('  ══ 初始数据 %d 样本' % len(X))

    best_mean, best_model = base_mean, None
    for it in range(1, a.iters + 1):
        # ① 训 V
        LY = [math.log1p(max(0.0, y)) for y in Y]
        ym = sum(LY) / len(LY)
        ys = max(1e-3, (sum((y - ym) ** 2 for y in LY) / len(LY)) ** 0.5)
        Yn = [(y - ym) / ys for y in LY]
        mean = [sum(X[k][i] for k in range(len(X))) / len(X) for i in range(NIN)]
        std = [max(1e-6, (sum((X[k][i] - mean[i]) ** 2 for k in range(len(X))) / len(X)) ** 0.5) for i in range(NIN)]
        Xn = [[(X[k][i] - mean[i]) / std[i] for i in range(NIN)] for k in range(len(X))]
        W1, b1, W2, b2 = train(Xn, Yn)
        W = to_model(W1, b1, W2, b2, mean, std, ym, ys)
        W['yStd'] = ys; W['yMean'] = ym

        # ② 测 V 贪心的实际棋力
        rng = random.Random(a.eval_seed)
        res = [play(lambda c, r: pick_value(W, c, r, eps=0.0), rng)[0] for _ in range(a.eval_games)]
        m = statistics.mean(res)
        flag = '✅ 超过启发式' if m > base_mean else '🔴 不如启发式'
        print('  ══ 第 %d 轮 ｜ π%d（V 贪心）均分 %.0f ｜ %s' % (it, it, m, flag))
        if m > best_mean:
            best_mean = m
            best_model = W

        # ③ 用 ε-greedy 版本产生新数据（ε=0.15 保证覆盖）
        rng = random.Random(10000 + it)
        add = 0
        for _ in range(a.games):
            _, _, traj = play(lambda c, r: pick_value(W, c, r, eps=0.15), rng, collect=True)
            for (st, rr) in traj:
                X.append(E.features(st)); Y.append(rr); add += 1
        print('         新增 %d 样本（累计 %d）' % (add, len(X)))

    print('\n  ══ 结论')
    print('     π0 启发式        均分 %.0f' % base_mean)
    print('     最好的一轮        均分 %.0f' % best_mean)
    if best_model and best_mean > base_mean:
        json.dump(best_model, open(a.out, 'w', encoding='utf-8'), ensure_ascii=False)
        print('     ✅ 策略迭代有提升，模型已写 %s' % a.out)
    else:
        print('     ⇒ 策略迭代没有跑赢启发式')
        print('       这意味着：**对 2048 来说，那套手工启发式本来就很强，')
        print('       在有限训练量下学不出比它更好的评估。**')
        print('       产品上应该继续用启发式，不再拿模型做主评估。')

if __name__ == '__main__':
    main()
