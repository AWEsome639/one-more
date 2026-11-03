#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
提交前自检：找出"模板占位符数量 > TG 函数能接受的参数数"的地方。

来历：这个错我犯了**八次**（.宽度写错、占位符写成 TG2 但用了 4 个…）
⇒ 不再靠记性，写成脚本挂在提交前跑。

规则：
  TG   0 个占位符
  TG2  最多 3 个（{0}{1}{2}）
  TG4  最多 4 个（{0}{1}{2}{3}）
"""
import io, os, re, sys

GAMES = '/Users/a0000/dev/yiju/entry/src/main/ets/games'
LIMIT = {'TG': 0, 'TG2': 3, 'TG4': 4}
bad = []
for fn in sorted(os.listdir(GAMES)):
    if not fn.endswith('.ets'):
        continue
    src = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
    for m in re.finditer(r"\b(TG|TG2|TG4)\((['\"])(.*?)\2", src):
        fname, _, tpl = m.group(1), m.group(2), m.group(3)
        used = [int(x) for x in re.findall(r'\{(\d)\}', tpl)]
        need = (max(used) + 1) if used else 0
        cap = LIMIT[fname]
        if need > cap:
            line = src[:m.start()].count('\n') + 1
            bad.append((fn, line, fname, need, cap, tpl[:42]))

if bad:
    print('  🔴 占位符超限 %d 处：' % len(bad))
    for fn, line, fname, need, cap, tpl in bad:
        print('     %-26s :%-4d %s 用了 %d 个，上限 %d ｜ %s' % (fn, line, fname, need, cap, tpl))
    sys.exit(1)
print('  ✅ 占位符数量全部合法')
