#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据⑥ 交叉点：长语言 × 简约模式 —— 六类界面（带【每步验证】）

为什么重写：第一版拍出来的文件名与内容不符（导航漂移）
  ⇒ ★ 每步之后 dump 确认「当前在哪个页面」，对不上就重试

用法：python3 -u 工具/拍简约模式.py <lang>      # lang = de / ar
输出：验收-日语-20261016/K-<lang>-<screen>.jpeg
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.path.expanduser('~/dev/yiju/验收-日语-20261016')
LANG = sys.argv[1] if len(sys.argv) > 1 else 'de'
TMP = '/tmp/kv.json'

# ★ 底部标签：★ RTL 下也【不镜像】（dump 实测：游戏 220 / 统计 660 / 设置 1098）
TAB_GAMES = (220, 2100)
TAB_STATS = (660, 2100)
TAB_SET = (1098, 2102)
CARD_L = (435, 1670)      # 网格左列第一张
CARD_R = (885, 1670)      # 网格右列第一张
HELP_L = (880, 283)       # LTR 游戏内「?」
HELP_R = (440, 283)       # RTL 游戏内「?」

# ★ 每类页面的【识别特征】（dump 里出现这些词 ⇒ 说明在该页）
SIG = {
    'games': ['Alle Spiele', 'Tutti i giochi', 'الألعاب', 'A-Z', 'Alle 355'],
    'stats': ['Erfolge', 'Statistik', 'إحصائيات', 'الإنجازات'],
    'settings': ['Einstellungen', 'الإعدادات', 'Aussehen', 'المظهر'],
    'guide': ['So geht es', 'Come si gioca', 'كيف تلعب'],
    'lan': ['Lokales Spiel', 'Lobby', 'لعب محلي', 'Verbinden', 'اتصال'],
}


def sh(c, t=30):
    try:
        return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def els():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/kv.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/kv.json {TMP}', 30)
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


def which_page():
    e = els()
    txt = ' '.join(t for t, _ in e)
    for k, sig in SIG.items():
        for s in sig:
            if s in txt:
                return k
    return '?'


def tap(x, y, w=2.5):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(w)


def shot(name):
    p = os.path.join(OUT, name)
    sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/s.jpeg"', 30)
    sh(f'{HDC} file recv /data/local/tmp/s.jpeg {p}', 30)
    return os.path.exists(p) and os.path.getsize(p) > 20000


def find_arrow_row():
    """★ 联机大厅入口：右端带 › 的整行（x 1240-1290）"""
    for i in range(12):
        for t, b in els():
            m = re.findall(r'-?\d+', b)
            if len(m) >= 4 and 1240 <= int(m[0]) <= 1290 and 200 < int(m[1]) < 1400:
                return (660, (int(m[1]) + int(m[3])) // 2)
        sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1350 300"', 20)
        time.sleep(1.0)
    return None


def to_top():
    for _ in range(10):
        sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
        time.sleep(0.3)
    time.sleep(1.2)


def capture(screen, go_fn, verify_page, tries=3):
    """★ 走一次导航 → 验证在目标页 → 截图（失败重试）"""
    name = 'K-%s-%s.jpeg' % (LANG, screen)
    for a in range(tries):
        go_fn()
        p = which_page()
        if verify_page(p):
            ok = shot(name)
            print('     %-10s ✅ %s' % (screen, name if ok else '（截图失败）'), flush=True)
            return True
        print('     %-10s ↻ 第 %d 次：落在「%s」⇒ 重试' % (screen, a + 1, p), flush=True)
    print('     %-10s ✗ 三次都没到位' % screen, flush=True)
    return False


def main():
    ok = 0
    # ① 游戏页
    ok += capture('games', lambda: tap(*TAB_GAMES, 3.5), lambda p: p == 'games')
    # ② 统计页
    ok += capture('stats', lambda: tap(*TAB_STATS, 4.5), lambda p: p == 'stats')
    # ③ 设置页
    ok += capture('settings', lambda: (to_top(), tap(*TAB_SET, 4.0)), lambda p: p == 'settings')
    # ④ 游戏内
    def go_ingame():
        tap(*TAB_GAMES, 3.5)
        tap(*(CARD_R if LANG == 'ar' else CARD_L), 5.0)
    ok += capture('ingame', go_ingame, lambda p: p == '?')   # 游戏内不在 SIG 里 ⇒ 用 '?' 表示"不是六类页之一"
    # ⑤ 指南页
    def go_guide():
        tap(*(HELP_R if LANG == 'ar' else HELP_L), 4.5)
    ok += capture('guide', go_guide, lambda p: p == 'guide')
    # ⑥ 联机大厅
    def go_lan():
        tap(126 if LANG == 'ar' else 104, 279, 2.0)   # 返回
        tap(*TAB_SET, 3.5)
        to_top()
        pos = find_arrow_row()
        if pos:
            tap(*pos, 5.0)
    ok += capture('lan', go_lan, lambda p: p == 'lan')
    print('  ★ %s：%d/6' % (LANG, ok))


if __name__ == '__main__':
    main()
