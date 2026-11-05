#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
工具/parse_dump_text.py —— **按 `|` 分隔解析 uitest dump 的文本**（判据 1629/1630）

★ 为什么要有（第 1418 轮）
  我用 `'|'.join(texts)` 生成一行，然后写正则 `归位 [0-9]+/[0-9]+`（**带空格**）
  ⇒ 而实际是 `归位|0/4`
  ⇒ **永远匹配不上** ⇒ 我读到「(空)」⇒ 差一点就误判成「修复无效」

★ 判据 1629：`dump` 的文本是**分节点**的，用 `|` 拼起来时**标签与值之间也是 `|`**
  ⇒ 正则必须按 `|` 写，或先 split 再按「标签的下一个元素」取值

★ 用法
  python3 工具/parse_dump_text.py 归位 步数 得分       # 取这些标签的值
  python3 工具/parse_dump_text.py --all                # 打印全部文本（调试）

★ 退出码：0 = 至少取到一个值 ｜ 1 = 一个都没取到
"""
import json
import os
import sys


def texts(path='/tmp/w2.json'):
    if not os.path.exists(path) or os.path.getsize(path) < 500:
        return []
    try:
        d = json.load(open(path, encoding='utf-8'))
    except Exception:
        return []
    out = []

    def w(x):
        if not isinstance(x, dict):
            return
        s = (x.get('attributes', {}).get('text') or '').strip()
        if s:
            out.append(s)
        for c in x.get('children', []) or []:
            w(c)
    w(d)
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print('用法: parse_dump_text.py <标签> [标签...] ｜ --all')
        return 1
    ts = texts()
    if not ts:
        print('(dump 空或不存在)')
        return 1
    if '--all' in args:
        print('|'.join(ts))
        return 0
    got = 0
    vals = []
    for label in args:
        # ★ 判据 1629：**标签的下一个元素**才是值（因为用 `|` 拼的）
        v = None
        for i, t in enumerate(ts):
            if t == label and i + 1 < len(ts):
                v = ts[i + 1]
                break
            if t.startswith(label) and len(t) > len(label):
                v = t[len(label):].strip(':： ')
                break
        vals.append('%s=%s' % (label, v if v is not None else '?'))
        if v is not None:
            got += 1
    print(' '.join(vals))
    return 0 if got else 1


if __name__ == '__main__':
    sys.exit(main())
