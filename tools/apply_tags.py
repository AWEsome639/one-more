#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 /tmp/game_tags.json 里的 tags **手术式**写回 GameRegistry.ets（拾海/game-balancer 2026-11-08）

为什么需要这个脚本 —— `tools/gen_catalog.py` 不能用来更新 tags：
  ① 它**整个重写** GameRegistry.ets，会把文件头警告过的 59 处
     `ACCENT_TAG` / `ACCENT_DEEP_TAG` 哨兵写回 `Palette.primary`（主题色不再跟随用户选择）；
  ② `/tmp/game_tags.json` 不存在时它原来会静默写 355 个空 tags
     （现在 gen_catalog.py 已加硬闸，但本脚本仍是**首选**路径）。

本脚本只替换「id 命中且 tags 真的变了」那一行里的 `tags: [...]`，其余字节一个不动。

用法：
  python3 tools/apply_tags.py            # dry-run：只统计 + 打印前 6 处新旧对比
  python3 tools/apply_tags.py --write    # 落盘
  python3 tools/apply_tags.py --json=/path/to/game_tags.json   # 换数据源（默认 /tmp/game_tags.json）
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
TAGSJSON = '/tmp/game_tags.json'

for _a in sys.argv:
    if _a.startswith('--json='):
        TAGSJSON = _a.split('=', 1)[1]
    elif _a.startswith('--reg='):
        REG = _a.split('=', 1)[1]

TAG_RE = re.compile(r'tags: \[[^\]]*\]')
ID_RE = re.compile(r"id: '([^']+)'")


def fmt(tags):
    return 'tags: [' + ', '.join("'%s'" % t for t in tags) + ']'


def main():
    dry = '--write' not in sys.argv
    if not os.path.exists(TAGSJSON):
        print('❌ 缺 %s —— 先跑 tools/gen_tags.py' % TAGSJSON)
        return 1
    if not os.path.exists(REG):
        print('❌ 找不到 %s' % REG)
        return 1

    tagmap = json.load(io.open(TAGSJSON, encoding='utf-8'))
    src = io.open(REG, encoding='utf-8').read()
    lines = src.split('\n')

    hit = 0
    changed = 0
    problems = []
    for i, ln in enumerate(lines):
        m = ID_RE.search(ln)
        if not m:
            continue
        gid = m.group(1)
        if gid not in tagmap:
            problems.append(gid + '(json 里没有)')
            continue
        hit += 1
        t = TAG_RE.search(ln)
        if not t:
            problems.append(gid + '(该行没有 tags 段)')
            continue
        new = fmt(tagmap[gid])
        if t.group(0) == new:
            continue
        changed += 1
        lines[i] = ln[:t.start()] + new + ln[t.end():]

    print('命中 %d / 355 ｜ 需改 %d 行 ｜ 异常 %d' % (hit, changed, len(problems)))
    for p in problems[:8]:
        print('   异常:', p)
    if changed == 0:
        print('（数据与文件一致，无需改动）')
        return 0

    if dry:
        print('\n—— dry-run（未写盘）。前 6 处 ——')
        n = 0
        for i, ln in enumerate(src.split('\n')):
            if lines[i] != ln and n < 6:
                print(' %-28s\n    旧 %s\n    新 %s' % (
                    ID_RE.search(ln).group(1),
                    TAG_RE.search(ln).group(0),
                    TAG_RE.search(lines[i]).group(0)))
                n += 1
        print('\n确认无误后加 --write 落盘。')
        return 0

    io.open(REG, 'w', encoding='utf-8').write('\n'.join(lines))
    print('✅ 已写回 %s（改了 %d 行）' % (REG, changed))
    return 0


if __name__ == '__main__':
    sys.exit(main())
