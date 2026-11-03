#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2048 价值网络 · 棋力对比（2026-10-23）

问题：「加了价值网络提示，棋真的变强了吗？」
  这个问题不能靠感觉答，必须跑对局比数字。

做法：同样 N 局、同样随机种子
  A 组：纯启发式（训练数据就是它产生的）
  B 组：启发式 + 价值网络一步前瞻（V 最大的方向）
  ⇒ 比平均分 / 中位数 / 最大块

⚠️ 诚实声明：
  B 组用的一步前瞻与端侧 askHint() 是同一个逻辑，
  但**这里是 Python 重写的**，与 ArkTS 实现可能有一两处细节差异。
  所以这个数字说明的是「这个算法思路」有没有用，不是「ArkTS 那 40 行」的精确成绩。
  真要验 ArkTS，得在真机上跑（目前没做）。
"""

import argparse, json, math, random, statistics, sys
from typing import List, Tuple

sys.path.insert(0, '/Users/a0000/dev/yiju/工具')
import importlib.util
spec = importlib.util.spec_from_file_location('t', '/Users/a0000/dev/yiju/工具/train_2048_value.py')
E = importlib.util.module_from_spec(spec); spec.loader.exec_module(E)

W = json.load(open('/Users/a0000/dev/yiju/entry/src/main/resources/rawfile/models/g2048_value.json', encoding='utf-8'))

def value_net(cells):
    f = E.features(cells)
    xs = [(f[i] - W['featureMean'][i]) / (W['featureStd'][i] or 1) for i in range(W['inDim'])]
    out = W['b2']
    for j in range(W['hidden']):
        s = W['b1'][j] + sum(W['W1'][j][i] * xs[i] for i in range(W['inDim']))
        if s > 0:
            out += W['W2'][j] * s
    return out

def pick_value(cells, rng):
    """价值网络一步前瞻：4 个方向各滑动，取 V 最大"""
    best, bestv = -1, -1e18
    for d in range(4):
        g, gain, moved = E.apply_move(cells, d)
        if not moved:
            continue
        v = value_net(g)
        if v > bestv:
            bestv, best = v, d
    return best

def play(rng, policy, max_steps=4000):
    cells = [0] * 16
    E.spawn(cells, rng); E.spawn(cells, rng)
    score = 0
    for _ in range(max_steps):
        d = policy(cells, rng)
        if d < 0:
            break
        g, gain, moved = E.apply_move(cells, d)
        if not moved:
            break
        cells = g; score += gain
        E.spawn(cells, rng)
        if E.is_dead(cells):
            break
    return score, max(cells)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--games', type=int, default=100)
    ap.add_argument('--seed', type=int, default=1234)
    a = ap.parse_args()

    print('  ══ 同一种子、同样 %d 局，只换决策策略' % a.games)
    res = {}
    for name, pol in (('A 纯启发式', E.pick_heuristic), ('B 价值网络前瞻', pick_value)):
        rng = random.Random(a.seed)          # 每组的随机序列一致（公平）
        scores, tiles = [], []
        for i in range(a.games):
            s, mx = play(rng, pol)
            scores.append(s); tiles.append(mx)
            if (i+1) % max(1, a.games//5) == 0:
                print('     %s %d/%d 均分 %.0f' % (name, i+1, a.games, sum(scores)/len(scores)))
        res[name] = (scores, tiles)
        print('  ══ %s：均分 %.0f ｜ 中位 %.0f ｜ 最高 %.0f ｜ 最大块 %d（均值 %d）'
              % (name, statistics.mean(scores), statistics.median(scores),
                 max(scores), max(tiles), int(statistics.mean(tiles))))

    A = res['A 纯启发式'][0]; B = res['B 价值网络前瞻'][0]
    print('\n  ══ 结论')
    print('     均分：%.0f → %.0f（%+.1f%%）' % (statistics.mean(A), statistics.mean(B),
          100.0*(statistics.mean(B)-statistics.mean(A))/max(1,statistics.mean(A))))
    print('     中位：%.0f → %.0f' % (statistics.median(A), statistics.median(B)))
    # 逐局配对比较（同一个种子下同一局，更能反映真实差异）
    wins = sum(1 for x, y in zip(A, B) if y > x)
    ties = sum(1 for x, y in zip(A, B) if y == x)
    print('     逐局：B 赢 %d ｜ 平 %d ｜ 输 %d（共 %d 局）' % (wins, ties, len(A)-wins-ties, len(A)))

if __name__ == '__main__':
    main()
