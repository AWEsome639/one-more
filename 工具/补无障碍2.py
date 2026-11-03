#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据③：无障碍收口 —— 把壳层【纯装饰图标】标 accessibilityLevel('no')

依据（2026-10-17 09:3x 实测分类）：
  · 六类界面里的纯图标 Text 共 26 处
  · 逐个查过上下文 ⇒ ★ 全部是【装饰】（都有文字兄弟，或本身只是视觉提示）
    例：🎲 旁边就是「随机来一局」｜📶 旁边是「局域网对战」｜› 是行末箭头
  · 真正"只有图标、没有文字"的按钮（GameHost ‹ ? ↻ ｜ GuidePage ‹ ｜ LanLobby ‹）
    已在上一轮补了 accessibilityText

做法：给这些 Text 追加 .accessibilityLevel('no') ⇒ 读屏跳过，不再念孤立符号
"""
import io
import os
import re
import shutil
import sys

ROOT = os.path.expanduser('~/dev/yiju/entry/src/main/ets')
BAK = os.path.expanduser('~/dev/yiju/.a11ybak2')
os.makedirs(BAK, exist_ok=True)

# ★ 从扫描结果抄下来的 (文件, 行号, 图标, 该行原文)
SITES = [
    ('components/GamesTab.ets',    764,  '⌄'),
    ('components/GamesTab.ets',    911,  '🔥'),
    ('components/GamesTab.ets',    979,  '🎲'),
    ('components/GamesTab.ets',    1005, '🎛️'),
    ('components/GamesTab.ets',    1453, '🔥'),
    ('components/StatsTab.ets',    926,  '›'),
    ('components/StatsTab.ets',    945,  '🌱'),
    ('components/SettingsTab.ets', 270,  '📶'),
    ('components/SettingsTab.ets', 279,  '›'),
    ('components/SettingsTab.ets', 459,  '🌏'),
    ('components/SettingsTab.ets', 510,  '🎨'),
    ('components/SettingsTab.ets', 535,  '✉️'),
    ('components/SettingsTab.ets', 579,  '🔒'),
    ('components/SettingsTab.ets', 582,  '›'),
    ('components/SettingsTab.ets', 741,  '🎨'),
    ('components/SettingsTab.ets', 750,  '🔠'),
    ('components/SettingsTab.ets', 867,  '✓'),
    ('components/SettingsTab.ets', 978,  '›'),
    ('components/SettingsTab.ets', 998,  '⚠️'),
    ('components/SettingsTab.ets', 1052, '🎲'),
    ('components/Common.ets',      444,  '🔥'),
    ('components/Common.ets',      741,  '✓'),
    ('components/Common.ets',      814,  '🔥'),
    ('pages/LanLobby.ets',         214,  '📶'),
]

by_file = {}
for f, ln, icon in SITES:
    by_file.setdefault(f, []).append((ln, icon))

total = 0
for rel, items in by_file.items():
    fp = os.path.join(ROOT, rel)
    shutil.copy(fp, os.path.join(BAK, os.path.basename(rel)))
    L = io.open(fp, encoding='utf-8').read().split('\n')
    for ln, icon in sorted(items, reverse=True):
        cur = L[ln - 1]
        # ★ 断言：这一行必须正好是 Text('<icon>') 开头（可带后续链式属性）
        if not re.match(r"^\s*Text\('%s'\)" % re.escape(icon), cur):
            print('  🔴 %s L%d 不是 Text(%r)（实际 %r）⇒ 跳过这处' % (rel, ln, icon, cur.strip()[:60]))
            continue
        if 'accessibilityLevel' in cur:
            print('  · %s L%d 已有 accessibilityLevel ⇒ 跳过' % (rel, ln))
            continue
        indent = cur[:len(cur) - len(cur.lstrip())]
        L.insert(ln, "%s  .accessibilityLevel('no')" % indent)
        total += 1
    io.open(fp, 'w', encoding='utf-8').write('\n'.join(L))
    print('  ✅ %-28s 标了 %d 处' % (rel, len(items)))

print()
print('  ★★ 共标 %d 处 accessibilityLevel(\'no\')' % total)

# ── 回读验证 + 括号校验 ──
print()
allok = True
for rel in list(by_file.keys()):
    t = io.open(os.path.join(ROOT, rel), encoding='utf-8').read()
    c = t.count(".accessibilityLevel('no')")
    a = t.count('.accessibilityText(')
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
    print('  %-30s level(no) %-3d ｜ text %-3d ｜ 括号差 %+d' % (rel, c, a, d))
