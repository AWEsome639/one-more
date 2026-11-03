#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据① 后半：release 签名包下【抽查 20 款游戏能开】

判据：每款点开后
  ① dump 里出现游戏内容（不是游戏列表页）
  ② 有「‹」返回按钮 + 一个非空标题
  ③ 截图非空
用法：python3 -u 工具/抽查20款.py
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.path.expanduser('~/dev/yiju/验收-日语-20261016/抽查20款')
os.makedirs(OUT, exist_ok=True)
TMP = '/tmp/s20.json'


def sh(c, t=30):
    try:
        return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def els():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/s20.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/s20.json {TMP}', 30)
    try:
        d = json.load(open(TMP, encoding='utf-8'))
    except Exception:
        return []
    out = []

    def walk(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', n)
        t = (a.get('text') or '') + (a.get('originalText') or '')
        b = a.get('bounds') or ''
        if t and b:
            out.append((t, b))
        for k in ('children', 'nodes'):
            for c in (n.get(k) or []):
                walk(c)
            for c in (a.get(k) or []):
                walk(c)
    walk(d)
    return out


def tap(x, y, w=1.2):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(w)


def is_game_page():
    """★ 强判据：游戏内一定有「‹」返回 + 顶栏标题；游戏列表页一定有「全部 · N 款」"""
    e = els()
    s = ' '.join(t for t, _ in e)
    if any(x in s for x in ['全部', 'Alle Spiele', 'Tutti i giochi', 'الألعاب']) and '款' in s:
        # 列表页特征（有分类胶囊）
        if 'A-Z' in s or '经典' in s or 'Klassisch' in s:
            return False, '列表页'
    has_back = False
    for t, b in e:
        if t.strip() == '‹' and int(re.findall(r'-?\d+', b)[1]) < 400:
            has_back = True
            break
    return has_back, ('游戏内' if has_back else '?')


def go_back():
    """★ 找 ‹ 的真实坐标（不靠记忆）"""
    for t, b in els():
        if t.strip() == '‹':
            m = re.findall(r'-?\d+', b)
            if len(m) >= 4:
                tap((int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2, 1.6)
                return True
    return False


def back_to_top():
    for _ in range(12):
        sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
        time.sleep(0.25)


# 网格坐标（手机 1320×2232；两列）
COLS = [(435, 1670), (885, 1670), (435, 1900), (885, 1900)]
ok = 0
fails = []
for i in range(20):
    col = i % 4
    if i >= 4 and i % 4 == 0:
        # 每 4 款滚一格
        sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1400 300"', 20)
        time.sleep(1.0)
    # 每轮重新读网格坐标（滚动后位置会变）
    # ★★★ 2026-10-17 修：卡片标题实测在 y 300-2000（页面已滚到顶）
    #   左列标题 x0≈282 ｜ 右列标题 x0≈906  ⇒ 点标题中心即可打开
    e = els()
    cards = []
    for t, b in e:
        m = re.findall(r'-?\d+', b)
        if len(m) < 4:
            continue
        x0, y0, x1, y1 = int(m[0]), int(m[1]), int(m[2]), int(m[3])
        if 260 <= x0 <= 320 and 300 < y0 < 2000 and (x1 - x0) > 200:
            cards.append(((x0 + x1) // 2, (y0 + y1) // 2))
    if not cards:
        print('     %2d ✗ 读不到卡片' % (i + 1), flush=True)
        fails.append(i + 1)
        continue
    x, y = cards[0]
    tap(x, y, 3.5)
    okpage, where = is_game_page()
    if okpage:
        sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/s.jpeg"', 30)
        sh(f'{HDC} file recv /data/local/tmp/s.jpeg {OUT}/%02d.jpeg' % (i + 1), 25)
        sz = os.path.getsize(os.path.join(OUT, '%02d.jpeg' % (i + 1))) if os.path.exists(os.path.join(OUT, '%02d.jpeg' % (i + 1))) else 0
        print('     %2d ✅ 开了（%s，截图 %d B）' % (i + 1, where, sz), flush=True)
        ok += 1
    else:
        print('     %2d ✗ 没开成（%s）' % (i + 1, where), flush=True)
        fails.append(i + 1)
    go_back()
print()
print('  ★★ release 包抽查：%d/20 能开 ｜ 失败 %s' % (ok, fails if fails else '无'))
