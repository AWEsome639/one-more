#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 通用界面 × 12 语言扫描器（2026-10-16 第 7 轮）

用法：python3 -u 工具/扫界面12语言.py <页面>
  <页面> = stats（统计页）｜ guide（指南页）｜ settings（设置页）｜ lan（联机大厅）

★ 本脚本沉淀了第 6 轮踩过的 4 个坑（全部已修）：
  ① 设置页会记住滚动位置 ⇒ 搜索前必须【滚到顶】（10 次 × 600px）
  ② dump 的 children 挂在 node 上（不是 attributes）⇒ walk() 必须用 node.get
  ③ 连按返回在深层路由不可靠 ⇒ 用【强制重启 App】
  ④ ★ 坐标必须 dump 实测（卡片中心 (435,1670)），绝不目测
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
OUT = os.path.expanduser('~/dev/yiju/验收-日语-20261016')
TMP = '/tmp/sweep-dump.json'
PAGE = sys.argv[1] if len(sys.argv) > 1 else 'stats'
# ★★★ 2026-10-17：加两个能力（为验 release 包服务）
#   · SWEEP_PREFIX=R  ⇒ 输出 R-<PREFIX>-<lang>.jpeg（不覆盖 debug 包的旧图）
#   · 额外参数 de ar ⇒ 只扫这几门语言（省时间）
ONLY = sys.argv[2:]
SWEEP_PREFIX = os.environ.get('SWEEP_PREFIX', '')
PREFIX = {'stats': 'S', 'guide': 'G', 'settings': 'T', 'lan': 'L', 'ingame': 'I'}.get(PAGE, 'X')

LANGS = [
    ('简体中文', 'zh'), ('English', 'en'), ('日本語', 'ja'), ('Français', 'fr'),
    ('Русский', 'ru'), ('Deutsch', 'de'), ('العربية', 'ar'), ('한국어', 'ko'),
    ('繁體中文', 'zhtw'), ('Español', 'es'), ('Português', 'pt'), ('Italiano', 'it'),
]

# ★ dump 实测的关键坐标（设备 px）—— 抄自第 6 轮的 dump（铁律 #52）
TAB_GAMES = (220, 2100)
TAB_STATS = (660, 2100)
TAB_SETTINGS = (1098, 2102)
CARD_FIRST = (435, 1670)      # 第一张游戏卡（dump: 文字 bounds [282,1619][588,1675]）
GAME_HELP = (880, 283)        # 游戏内「?」


def sh(cmd, t=25):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def dump():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/sw.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/sw.json {TMP}', 30)
    try:
        return json.load(open(TMP, encoding='utf-8'))
    except Exception:
        return None


def walk(node, out):
    """★ children 挂在【node】上（第 6 轮血泪：写成 attributes 会只遍历顶层）"""
    if not isinstance(node, dict):
        return
    a = node.get('attributes', node)
    t = (a.get('text') or '') + (a.get('originalText') or '')
    b = a.get('bounds') or ''
    if t and b:
        out.append((t, b))
    for k in ('children', 'nodes'):
        for c in (node.get(k) or []):
            walk(c, out)
        for c in (a.get(k) or []):
            walk(c, out)


def find(text, scrolls=6):
    import re
    for si in range(scrolls + 1):
        d = dump()
        if d:
            els = []
            walk(d, els)
            for t, bd in els:
                if text in t:
                    m = re.findall(r'-?\d+', bd)
                    if len(m) >= 4:
                        return (int(m[0]) + int(m[2])) // 2, (int(m[1]) + int(m[3])) // 2
        if si < scrolls:
            sh(f'{HDC} shell "uitest uiInput swipe 660 1500 660 1100 400"', 20)
            time.sleep(1.0)
    return None


def tap(x, y, wait=2.5):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(wait)


def scroll_top():
    """★ 设置页/长页面：先滚到顶（10 次 × 600px，实测 6 次不够）"""
    for _ in range(10):
        sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
        time.sleep(0.35)
    time.sleep(1.2)


def shot(name):
    p = os.path.join(OUT, name)
    sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/{name}"', 30)
    sh(f'{HDC} file recv /data/local/tmp/{name} {p}', 30)
    return os.path.exists(p) and os.path.getsize(p) > 20000


def main():
    ok = []
    L = LANGS
    if ONLY:
        L = [(d, c) for d, c in LANGS if c in ONLY]
        print('  ★ 只扫: %s' % ' '.join(c for _, c in L), flush=True)
    for disp, code in L:
        print('  ══ %-10s (%s)' % (disp, code), flush=True)
        # ① 强制重启（★ 语言设置会保留）
        sh(f'{HDC} shell "aa force-stop com.andrewoscar.onemore"', 25)
        time.sleep(2.5)
        sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
        time.sleep(8)
        # ② 去设置 → 滚到顶 → 切语言
        tap(*TAB_SETTINGS, wait=2.5)
        scroll_top()
        pos = find(disp)
        if not pos:
            scroll_top()
            pos = find(disp)
        if not pos:
            print('     ✗ 找不到语言按钮', flush=True)
            continue
        tap(*pos, wait=3.5)
        # ③ 按目标页导航
        if PAGE == 'stats':
            tap(*TAB_STATS, wait=4.5)
        elif PAGE == 'ingame':
            # ★ 游戏内界面（进游戏后直接截图，不点 ?）
            tap(*TAB_GAMES, wait=3.5)
            tap(*CARD_FIRST, wait=5.0)
        elif PAGE == 'guide':
            tap(*TAB_GAMES, wait=3.5)
            tap(*CARD_FIRST, wait=4.5)
            tap(*GAME_HELP, wait=4.0)
        elif PAGE == 'settings':
            pass           # 已经切完语言就在设置页
        elif PAGE == 'lan':
            # ★★★ 2026-10-17：改用【结构】找入口（不靠翻译文字 —— 12 语言各不同）
            #   dump 实测：联机大厅那行的特征 = ① 整行宽 ② 右端有个 『›』(x≈1254-1272)
            #   ⇒ 找这样的行，点它的中心
            scrolled = 0
            pos = None
            while scrolled < 8 and pos is None:
                d = dump()
                if d:
                    els = []
                    walk(d, els)
                    chevrons = []
                    for t, b in els:
                        m = re.findall(r'-?\d+', b)
                        if len(m) >= 4 and 1240 <= int(m[0]) <= 1290 and 300 < int(m[1]) < 1300:
                            chevrons.append((int(m[1]), int(m[3])))
                    if chevrons:
                        cy = (chevrons[0][0] + chevrons[0][1]) // 2
                        pos = (660, cy)
                        break
                sh(f'{HDC} shell "uitest uiInput swipe 660 1700 660 1200 300"', 20)
                time.sleep(1.0)
                scrolled += 1
            if pos:
                tap(*pos, wait=5.0)
            else:
                print('     ✗ 找不到入口行（带 › 的整行）', flush=True)
                continue
        # ④ 截图
        nm = '%s%s-%s.jpeg' % (SWEEP_PREFIX, PREFIX, code)
        if shot(nm):
            print('     ✅ %s' % nm, flush=True)
            ok.append(code)
        else:
            print('     ✗ 截图失败', flush=True)
    print()
    print('  ★ 完成 %d/12: %s' % (len(ok), ' '.join(ok)))


if __name__ == '__main__':
    main()
