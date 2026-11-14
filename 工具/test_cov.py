#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""`covered_count_tree` 的回归测试（判据 `2006` + `2022`）。

**为什么要有这个文件**
`cov` 这个指标今天坏了 **`4` 次**（父容器算盖住 / 全屏算盖住 / 无 `bounds` 撞 id / 超时）。
每次坏都**静默给 `0`** ⇒ 而 `0` 恰好是「没问题」的值 ⇒ **最坏的失败形态**。
⇒ 今晚要跑 `245` 款，若 `cov` 又坏了，那 `245` 行数据里这一列全是假的。

**⇒ 所以在跑之前先把这个仪器验一遍。** 五个样本覆盖四种失效模式：

| 样本 | 期望 | 抓的是哪个坑 |
|---|---|---|
| ① 正常嵌套（文字在父容器里）| `0` | 把**祖先**当遮挡 ⇒ 每款都报几千 |
| ② 兄弟方块整块盖住 | `1` | 根本测不出遮挡 |
| ③ 兄弟方块**部分**重叠 | `0` | 把「擦边」当遮挡 |
| ④ **全屏容器**盖住 | `0` | 把**根节点**当遮挡 |
| ⑤ **无 `bounds` 的节点**夹在中间 | `1` | `id = len(flat)` 撞号 ⇒ 恒 `0` |

用法：`python3 工具/test_cov.py`（退出码 `0` = 全过）
"""
import io
import os
import sys

os.environ.setdefault('SHOT_SCREEN_W', '2560')
os.environ.setdefault('SHOT_SCREEN_H', '1600')

HERE = os.path.dirname(os.path.abspath(__file__))
SHOT = os.path.join(HERE, 'shot_game.py')


def load_covered():
    src = io.open(SHOT, encoding='utf-8').read()
    cut = src.find('\ndef main(')
    # ★ 必须给 `__file__` —— `shot_game.py` 顶层用它定位目录（真机踩过：name '__file__' is not defined）
    g = {'__file__': SHOT, '__name__': 'shot_game_mod'}
    exec(compile(src[:cut] if cut > 0 else src, 'shot_game', 'exec'), g)
    return g['covered_count_tree']


def N(b, text=None, kids=None):
    a = {}
    if b is not None:
        a['bounds'] = '[%s]' % b
    if text is not None:
        a['text'] = text
    return {'attributes': a, 'children': kids or []}


def main():
    try:
        cc = load_covered()
    except Exception as e:
        print('❌ 装不起来: %s' % e)
        return 2

    cases = [
        ('① 正常嵌套（文字在父容器内）', '0',
         N('0,0][2560,1600', None, [N('100,100][900,500', None, [N('150,150][800,300', '你好')])]), 0),
        ('② 兄弟方块整块盖住文字', '1',
         N('0,0][2560,1600', None, [N('150,150][800,300', '你好'), N('100,100][900,500', None)]), 1),
        ('③ 兄弟方块部分重叠', '0',
         N('0,0][2560,1600', None, [N('150,150][800,300', '你好'), N('700,250][1200,600', None)]), 0),
        ('④ 全屏容器盖住（应排除）', '0',
         N('0,0][2560,1600', None, [N('150,150][800,300', '你好'), N('0,0][2560,1600', None)]), 0),
        ('⑤ 无 bounds 节点不撞 id', '1',
         {'attributes': {}, 'children': [
             N('100,100][900,500', None, [N('150,150][800,300', 'A')]),
             N('150,150][800,300', 'B')]}, 1),
    ]

    fails = 0
    for label, want, tree, expect in cases:
        try:
            got = cc(tree)
        except Exception as e:
            print('❌ %s ⇒ 抛异常: %s' % (label, e))
            fails += 1
            continue
        ok = (got == expect)
        if not ok:
            fails += 1
        print('%s %-32s 期望 %-2s 实得 %-4s' % ('✅' if ok else '❌', label, want, got))

    print()
    if fails:
        print('❌ %d/%d 个样本失败 ⇒ **`cov` 仪器坏了，今晚不要跑**' % (fails, len(cases)))
        return 1
    print('✅ %d/%d 全过 ⇒ `cov` 可以信' % (len(cases), len(cases)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
