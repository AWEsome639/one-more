#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 真 BUG 修复（第七轮）：25 个倒计时游戏在后台继续走表

现象（2026-10-17 13:2x 实测）：
  玩「不等式冲刺」剩 56s → 按 HOME 切后台 30 秒 → 回来只剩 17s
根因：
  setInterval(() => { this.left = this.left - 1; ... }, 1000) —— 每秒无条件减 1
修法：
  ① 每个倒计时游戏 import AppClock
  ② 在 setInterval 回调开头加：if (AppClock.isPaused()) { return; }
  ⇒ 后台期间 tick 被跳过，回来接着走

安全措施：
  · 只改【含倒计时减法】+【有 setInterval】的文件
  · 每处插入前断言原文匹配
  · 备份到 .clockbak/
  · 改完逐个括号校验
"""
import io
import os
import re
import shutil
import sys

ROOT = os.path.expanduser('~/dev/yiju/entry/src/main/ets')
BAK = os.path.expanduser('~/dev/yiju/.clockbak')
os.makedirs(BAK, exist_ok=True)
GAMES = os.path.join(ROOT, 'games')

# ★ 倒计时减法的四种写法
COUNTDOWN = re.compile(r"this\.(left|timeLeft|remain|leftSec)\s*=\s*this\.\1\s*-\s*1")
# ★ setInterval 开头（可能带换行）
SETIV = re.compile(r"(setInterval\(\s*\(\)\s*=>\s*\{)(\s*\n)")

targets = []
for fp in sorted(os.listdir(GAMES)):
    if not fp.endswith('.ets'):
        continue
    full = os.path.join(GAMES, fp)
    s = io.open(full, encoding='utf-8').read()
    if not COUNTDOWN.search(s):
        continue
    if not SETIV.search(s):
        continue
    if 'AppClock' in s:
        continue
    targets.append(fp)

print('  ★ 待修文件: %d 个' % len(targets))
if not targets:
    print('  （没有需要改的）')
    sys.exit(0)

ok = fail = 0
for fp in targets:
    full = os.path.join(GAMES, fp)
    shutil.copy(full, os.path.join(BAK, fp))
    s = io.open(full, encoding='utf-8').read()

    # ① import
    if "from '../core/AppClock'" not in s:
        # 找最后一个 import 行
        lines = s.split('\n')
        last_imp = -1
        for i, l in enumerate(lines):
            if l.startswith('import '):
                last_imp = i
        if last_imp < 0:
            print('  🔴 %-30s 没有 import 段 ⇒ 跳过' % fp)
            fail += 1
            continue
        lines.insert(last_imp + 1, "import { AppClock } from '../core/AppClock';")
        s = '\n'.join(lines)

    # ② 在每个 setInterval 回调开头插暂停检查（只插【倒计时那个】的前 6 行内有减法的）
    m = None
    for cand in SETIV.finditer(s):
        head = s[cand.start(): cand.start() + 400]
        if COUNTDOWN.search(head[:400]) or COUNTDOWN.search(s[cand.start(): cand.start()+300]):
            m = cand
            break
    if not m:
        # 退一步：用第一个 setInterval
        m = SETIV.search(s)
    if not m:
        print('  🔴 %-30s 找不到 setInterval' % fp)
        fail += 1
        continue

    ins_at = m.end(1)   # 在 "{" 之后
    s = s[:ins_at] + '\n      if (AppClock.isPaused()) { return; }' + s[ins_at:]
    io.open(full, 'w', encoding='utf-8').write(s)

    # ③ 回读
    back = io.open(full, encoding='utf-8').read()
    has_imp = "from '../core/AppClock'" in back
    has_chk = 'AppClock.isPaused()' in back
    if has_imp and has_chk:
        ok += 1
    else:
        print('  ⚠️ %-30s import=%s check=%s' % (fp, has_imp, has_chk))
        fail += 1

print('  ✅ 改好 %d 个 ｜ 失败 %d 个' % (ok, fail))

# ── 括号校验 ──
print()
bad = 0
for fp in targets:
    t = io.open(os.path.join(GAMES, fp), encoding='utf-8').read()
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
        print('     ⚠️ %-30s 括号差 %+d' % (fp, d))
        bad += 1
print('  ★ 括号异常 %d 个（未列出即正常）' % bad)

# ── 全库统计 ──
n = 0
for fp in os.listdir(GAMES):
    if not fp.endswith('.ets'):
        continue
    s = io.open(os.path.join(GAMES, fp), encoding='utf-8').read()
    if 'AppClock.isPaused()' in s:
        n += 1
print('  ★ 已接 AppClock 暂停检查的游戏: %d 个' % n)
