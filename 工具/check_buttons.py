#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
按钮属性完整性检查（只读）。

来历：这个错犯了**两次**（数蛇、数独）——
      在 Button(...) 那一行之后插代码，会把按钮和它自己的属性拆散，
      结果按钮存在、点不动。

判据：每个 Button( 行之后、下一个 Button( 之前，必须出现 .onClick(
"""
import io, os, re, sys

GAMES = '/Users/a0000/dev/yiju/entry/src/main/ets/games'
bad = []
for fn in sorted(os.listdir(GAMES)):
    if not fn.endswith('.ets'):
        continue
    lines = io.open(os.path.join(GAMES, fn), encoding='utf-8').read().split('\n')
    for i, l in enumerate(lines):
        if not re.match(r"\s*Button\(", l):
            continue
        attrs = []
        j = i + 1
        while j < len(lines) and j - i < 40:
            s = lines[j].strip()
            if s.startswith('Button('):
                break   # 只认下一个 Button( 作为结束，别被 } 打断
            # ★ 空行不能当结束 —— 有些文件的属性之间有空行
            if s != '':
                attrs.append(s)
            j += 1
        # 只检查我们关心的那几个（提示/代打/重开），避免误报
        label = l.strip()
        if not any(k in label for k in ('提示', '代打', '重开')):
            continue
        if not any('.onClick(' in a for a in attrs):
            bad.append((fn, i + 1, label[:50]))

if bad:
    print('  🔴 %d 个按钮缺 onClick：' % len(bad))
    for fn, ln, label in bad:
        print('     %-26s :%-4d %s' % (fn, ln, label))
    sys.exit(1)
print('  ✅ 提示/代打/重开 按钮的 onClick 全部完整')
