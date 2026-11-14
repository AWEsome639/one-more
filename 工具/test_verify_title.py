#!/usr/bin/env python3
"""verify_title 的离线夹具测试（**不需要设备**）。

为什么要有它：`verify_title` 是「点对游戏了没」的闸门，它对 `Scroll`/懒加载很敏感
（`dumpLayout` 只报可见节点）。改它之前/之后都必须跑这一组，否则可能
① 把「在游戏内」误判成「不在」⇒ WRONG_GAME（今天 Matrix Reasoning 就是）
② 把「首页」误判成「在游戏内」⇒ 量错游戏的数据

用法：python3 工具/test_verify_title.py
退出码 0 = 全过；非 0 = 有用例不符。
"""
import importlib.util, sys, os

P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shot_game.py')
spec = importlib.util.spec_from_file_location('sg', P)
sg = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(sg)
except SystemExit:
    pass


def tree(texts):
    return {'attributes': {},
            'children': [{'attributes': {'text': t}, 'children': []} for t in texts]}


# (名字, dump 里的文本, 期望 ok)
CASES = [
    # 正常游戏内：HintBar 在
    ('游戏内+有提示', ['‹', '矩阵推理', '找规律填方格', '提示', 'AI 代打', '☆'], True),
    # ★ 今天的 WRONG_GAME：标题在，但 Scroll 把 HintBar 滚出视野
    ('游戏内+提示被滚走', ['‹', '矩阵推理', '找规律填方格', '☆', '?', '普通'], True),
    # 首页不能误判成游戏内（否则会量错游戏）
    ('首页A', ['今天这一局', '全部', '🎯', '磁铁', '分数匹配'], False),
    ('首页B', ['全部', '🎯', '355 款小游戏'], False),
    # 别的游戏不能当对
    ('别的游戏', ['‹', '找规律填方格', '提示', 'AI 代打'], False),
    # 英文界面（App 可切语言）
    ('英文游戏内', ['‹', 'Matrix Reasoning', 'Find the pattern', 'Hint'], True),
]


def main():
    bad = 0
    for name, texts, expect in CASES:
        ok, _ = sg.verify_title(tree(texts), 'Matrix Reasoning')
        good = (ok == expect)
        bad += 0 if good else 1
        print('%-18s ok=%-5s 期望=%-5s %s' % (name, ok, expect, '✅' if good else '❌'))
    print()
    if bad:
        print('⇒ %d 条不符' % bad)
        return 1
    print('⇒ 全部通过（%d 条）' % len(CASES))
    return 0


if __name__ == '__main__':
    sys.exit(main())
