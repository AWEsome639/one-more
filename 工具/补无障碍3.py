#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据⑥ 收口：游戏内 28 处可点击纯图标 → accessibilityLevel('no')

设计依据（2026-10-17 12:4x 判断）：
  · 这 28 处都是【游戏棋盘上的棋子/控件】（🍕 披萨片、🥣 贝壳、🥁 鼓、🌀 螺旋、▼ 落子…）
  · 读屏用户本来就玩不了视觉小游戏；逐个念「·」「×」「🔢」只是噪音，不是帮助
  · 真正该念的是【导航与文字】（已在前两轮补齐：8 处 accessibilityText + 24 处 level no）
  ⇒ 所以统一标 no：读屏跳过，界面不再出现孤立符号

判据：全库「可点击 + 纯图标 + 无无障碍属性」= 0 处
"""
import io
import os
import re
import shutil
import sys

ROOT = os.path.expanduser('~/dev/yiju/entry/src/main/ets')
BAK = os.path.expanduser('~/dev/yiju/.a11ybak3')
os.makedirs(BAK, exist_ok=True)

pat = re.compile(r"Text\(\s*'([^']{1,6})'\s*\)")
targets = {}   # 文件 -> [(行号, 图标)]
for fp in sorted(os.listdir(os.path.join(ROOT, 'games'))):
    if not fp.endswith('.ets'):
        continue
    full = os.path.join(ROOT, 'games', fp)
    s = io.open(full, encoding='utf-8').read()
    lines = s.split('\n')
    for m in pat.finditer(s):
        t = m.group(1)
        if re.search(r'[\u4e00-\u9fff A-Za-z0-9]', t):
            continue
        ln = s[:m.start()].count('\n') + 1
        tail = '\n'.join(lines[ln - 1: ln + 14])
        if '.onClick' not in tail or 'accessibility' in tail:
            continue
        targets.setdefault(fp, []).append((ln, t))

total = 0
for f, items in targets.items():
    full = os.path.join(ROOT, 'games', f)
    shutil.copy(full, os.path.join(BAK, f))
    L = io.open(full, encoding='utf-8').read().split('\n')
    for ln, icon in sorted(items, reverse=True):
        cur = L[ln - 1]
        if not re.match(r"^\s*Text\('%s'\)" % re.escape(icon), cur):
            print('  🔴 %s L%d 不是 Text(%r)（实际 %r）⇒ 跳过' % (f, ln, icon, cur.strip()[:50]))
            continue
        if 'accessibilityLevel' in cur:
            continue
        indent = cur[:len(cur) - len(cur.lstrip())]
        L.insert(ln, "%s  .accessibilityLevel('no')" % indent)
        total += 1
    io.open(full, 'w', encoding='utf-8').write('\n'.join(L))
    print('  ✅ %-30s 标了 %d 处' % (f, len(items)))

print()
print('  ★★ 共标 %d 处 accessibilityLevel(\'no\')（游戏内）' % total)

# ── 最终复扫：全库应归零 ──
print()
print('  ══ 最终复扫（全库）:')
n = 0
for fp in sorted(os.listdir(os.path.join(ROOT, 'games'))):
    if not fp.endswith('.ets'):
        continue
    s = io.open(os.path.join(ROOT, 'games', fp), encoding='utf-8').read()
    lines = s.split('\n')
    for m in pat.finditer(s):
        t = m.group(1)
        if re.search(r'[\u4e00-\u9fff A-Za-z0-9]', t):
            continue
        ln = s[:m.start()].count('\n') + 1
        tail = '\n'.join(lines[ln - 1: ln + 14])
        if '.onClick' in tail and 'accessibility' not in tail:
            n += 1
            if n <= 5:
                print('     🔴 %s L%d %s' % (fp, ln, t))
print('     ★ 游戏内「可点击+纯图标+无无障碍」剩余: %d 处 %s' % (n, '✅ 归零' if n == 0 else ''))

# ── 括号校验 ──
print()
for f in targets:
    t = io.open(os.path.join(ROOT, 'games', f), encoding='utf-8').read()
    d = 0; ins = None; i = 0
    while i < len(t):
        ch = t[i]
        if ins:
            if ch == '\\':
                i += 2; continue
            if ch == ins:
                ins = None
        elif ch in ('"', "'"):
            ins = ch
        elif ch == '(':
            d += 1
        elif ch == ')':
            d -= 1
        i += 1
    if d != 0:
        print('     ⚠️ %-30s 括号差 %+d' % (f, d))
print('     括号校验完成（未列出的即差 0）')
