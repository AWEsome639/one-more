#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 判据①：release 签名包 · 六类界面实拍（带页面断言）

为什么单独写：之前所有实拍跑的都是【debug 包】，从没验过要上架的那一个。
用法：python3 -u 工具/验release包.py <zh|de|ar>
输出：验收-日语-20261016/R-<lang>-<screen>.jpeg
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.path.expanduser('~/dev/yiju/验收-日语-20261016')
LANG = sys.argv[1] if len(sys.argv) > 1 else 'zh'
TMP = '/tmp/rel.json'

# ★ 底部标签：★ RTL 也不镜像（第 61 条铁律实测）
TAB_GAMES = (220, 2100)
TAB_STATS = (660, 2100)
TAB_SET = (1098, 2102)
CARD_L = (435, 1670)
CARD_R = (885, 1670)
HELP = (883, 279)          # ★ RTL 也不镜像（实测）

# 每类页面的独有特征词（12 语言的都收）
SIG = {
    'games':    ['全部', 'Alle Spiele', 'Tutti i giochi', 'الألعاب', 'A-Z', '款小游戏'],
    'stats':    ['成就', 'Erfolge', 'Risultati', 'الإنجازات', '统计'],
    'settings': ['设置', 'Einstellungen', 'Impostazioni', 'الإعدادات'],
    'guide':    ['玩法', 'So geht', 'Come si', 'كيف تلعب'],
    'lan':      ['局域网', 'Lokales', 'Locale', 'لعب محلي', 'إعادة البحث'],
}


def sh(c, t=30):
    try:
        return subprocess.run(c, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def els():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/rel.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/rel.json {TMP}', 30)
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


def txt():
    return ' '.join(t for t, _ in els())


def where():
    """★★★ 2026-10-17 修：原来用弱特征词顺序匹配 ⇒ 指南页被判成 stats（第 57 条铁律又踩）
    ⇒ 改用【强特征】：
       ① 先看有没有【底部标签】（y>1950）—— 没有 ⇒ 全屏路由
       ② 有标签 ⇒ 读【页面标题】（y 190-365）来判断是哪一页
    """
    e = els()
    if not e:
        return '?'
    has_tabs = any(int(re.findall(r'-?\d+', b)[1]) > 1950
                   for t, b in e if len(re.findall(r'-?\d+', b)) >= 4)
    head = ' '.join(t for t, b in e
                    if len(re.findall(r'-?\d+', b)) >= 4
                    and 190 <= int(re.findall(r'-?\d+', b)[1]) <= 365)
    TITLE = {
        'games':    ['一局', 'OneMore', 'Все игры'],
        'stats':    ['统计', 'Statistik', 'Statistiche', 'إحصائيات', 'Statistiques',
                     'Estadísticas', 'Estatísticas', 'Статистика', '통계', '統計'],
        'settings': ['设置', 'Einstellungen', 'Impostazioni', 'الإعدادات', 'Réglages',
                     'Ajustes', 'Configurações', 'Настройки', '설정', '設定'],
        'guide':    ['怎么玩', 'So geht', 'Come si', 'كيف تلعب', 'Comment jouer',
                     'Cómo jugar', 'Como jogar', 'Как играть', '게임 방법'],
    }
    for k, sigs in TITLE.items():
        for x in sigs:
            if x in head:
                return k
    if not has_tabs:
        # ★ 全屏路由：游戏内 / 指南页 / 联机大厅
        if 'كيف تلعب' in head or '怎么玩' in head or 'So geht' in head:
            return 'guide'
        return 'fullscreen'
    return '?' 


def tap(x, y, w=2.5):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(w)


def shot(name):
    p = os.path.join(OUT, name)
    sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/s.jpeg"', 30)
    sh(f'{HDC} file recv /data/local/tmp/s.jpeg {p}', 30)
    return os.path.exists(p) and os.path.getsize(p) > 20000


def to_top():
    for _ in range(10):
        sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
        time.sleep(0.3)
    time.sleep(1.2)


def arrow_row():
    for _ in range(12):
        for t, b in els():
            m = re.findall(r'-?\d+', b)
            if len(m) >= 4 and 1240 <= int(m[0]) <= 1290 and 200 < int(m[1]) < 1400:
                return (660, (int(m[1]) + int(m[3])) // 2)
        sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1350 300"', 20)
        time.sleep(1.0)
    return None


def clean_tabs():
    """★ 从全屏路由退到底部标签页"""
    for _ in range(6):
        s = txt()
        if '返回列表' in s or 'عودة إلى القائمة' in s or 'Zurück' in s and 'Liste' in s:
            tap(660, 1983, 3.0)
            continue
        if any(x in s for x in ['全部', 'Alle Spiele', 'الألعاب']):
            return True
        tap(104, 414, 2.5)
    return False


def cap(screen, go, want, tries=3):
    name = 'R-%s-%s.jpeg' % (LANG, screen)
    for a in range(tries):
        go()
        p = where()
        if p == want or (want == '?' and p in ('fullscreen', '?')):
            print('     %-9s ✅ %s' % (screen, name if shot(name) else '（截图失败）'), flush=True)
            return True
        print('     %-9s ↻%d 落在「%s」' % (screen, a + 1, p), flush=True)
    print('     %-9s ✗' % screen, flush=True)
    return False


ok = 0
ok += cap('games',    lambda: tap(*TAB_GAMES, 3.5), 'games')
ok += cap('stats',    lambda: tap(*TAB_STATS, 4.5), 'stats')
ok += cap('settings', lambda: (to_top(), tap(*TAB_SET, 4.0)), 'settings')
ok += cap('ingame',   lambda: (tap(*TAB_GAMES, 3.5), tap(*(CARD_R if LANG == 'ar' else CARD_L), 5.0)), '?')
ok += cap('guide',    lambda: tap(*HELP, 4.5), 'guide')
ok += cap('lan',      lambda: (tap(96 if LANG == 'ar' else 104, 414, 2.0), tap(*TAB_SET, 3.5), to_top(),
                               (lambda p: tap(*p, 5.0) if p else None)(arrow_row())), 'lan')
print('  ★ release 包 %s：%d/6' % (LANG, ok))
