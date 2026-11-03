#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 指南页 × 12 语言全扫（2026-10-16 第 6 轮）

为什么选指南页：它是本地化字符串【最密集】的一屏 ——
  游戏名 + 分类 + 说明 + 4 条分类要点 + 4 个档位名 + 进度数字
⇒ 扫这一屏 = 把所有本地化机制（gameName/gameTagline/catLabel/L2/TIER_NAME/Digits）过一遍

用法：python3 -u 工具/指南页扫12语言.py
输出：验收-日语-20261016/G-<语言>.jpeg
"""
import json
import os
import subprocess
import sys
import time

HDC = os.path.expanduser('~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
DEV = '127.0.0.1:5555'
OUT = os.path.expanduser('~/dev/yiju/验收-日语-20261016')
TMP = '/tmp/lang-dump2.json'

# ★ 语言列表（按设置页里的显示文本 —— 带国旗 emoji，用【包含】匹配）
LANGS = [
    ('简体中文', 'zh'), ('English', 'en'), ('日本語', 'ja'), ('Français', 'fr'),
    ('Русский', 'ru'), ('Deutsch', 'de'), ('العربية', 'ar'), ('한국어', 'ko'),
    ('繁體中文', 'zhtw'), ('Español', 'es'), ('Português', 'pt'), ('Italiano', 'it'),
    ('Русский', 'ru'), ('Deutsch', 'de'), ('العربية', 'ar'), ('한국어', 'ko'),
    ('繁體中文', 'zhtw'), ('Español', 'es'), ('Português', 'pt'), ('Italiano', 'it'),
]

# 每个语言的【游戏名】（用来在游戏页找到目标游戏）
GAME = {
    'zh': '宝石迷阵', 'en': 'Bejeweled', 'ja': 'ジュエル', 'fr': 'Bijoux',
    'ru': 'Самоцветы', 'de': 'Juwelen', 'ar': 'مجوهرات', 'ko': '보석',
    'zhtw': '寶石迷陣', 'es': 'Joyas', 'pt': 'Joias', 'it': 'Gioielli',
}


def sh(cmd, t=25):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ''


def dump():
    sh(f'{HDC} shell "uitest dumpLayout -p /data/local/tmp/d2.json"', 40)
    sh(f'{HDC} file recv /data/local/tmp/d2.json {TMP}', 30)
    try:
        return json.load(open(TMP, encoding='utf-8'))
    except Exception:
        return None


def walk(node, out):
    """★★★ 2026-10-16 血泪：children 挂在【node】上，不是挂在 attributes 上！
       我第一版写成 `b.get('children')`（b = attributes）⇒ 只遍历到顶层
       ⇒ 12 个语言全报"找不到语言按钮"（我手测用 n.get 所以手测成功 ⇒ 误导了我一轮）
    """
    if not isinstance(node, dict):
        return
    b = node.get('attributes', node)
    txt = (b.get('text') or '') + (b.get('originalText') or '')
    bd = b.get('bounds') or ''
    if txt and bd:
        out.append((txt, bd))
    for k in ('children', 'nodes'):
        for c in (node.get(k) or []):
            walk(c, out)
        for c in (b.get(k) or []):     # 兜底：有些 dump 把 children 塞在 attributes 里
            walk(c, out)


def find(text, scrolls=6):
    """★ 找含 text 的元素中心（设备坐标）"""
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
                        x = (int(m[0]) + int(m[2])) // 2
                        y = (int(m[1]) + int(m[3])) // 2
                        return x, y
        if si < scrolls:
            sh(f'{HDC} shell "uitest uiInput swipe 660 1500 660 1100 400"', 20)
            time.sleep(1.2)
    return None


def tap(x, y):
    sh(f'{HDC} shell "uitest uiInput click {x} {y}"', 20)
    time.sleep(2.5)


def shot(name):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    sh(f'{HDC} shell "snapshot_display -f /data/local/tmp/{name}"', 30)
    sh(f'{HDC} file recv /data/local/tmp/{name} {p}', 30)
    return os.path.exists(p) and os.path.getsize(p) > 20000


def main():
    ok = []
    for disp, code in LANGS:
        print('  ══ %s (%s)' % (disp, code), flush=True)
        # ① 回干净首页
        #   ★★★ 2026-10-16 血泪：原来用【连按 3 次返回】，但在指南页/深层路由下
        #   返回不可靠（实测有一次直接卡在意大利语指南页，后面全失败）
        #   ⇒ 改用【强制重启 App】—— 实测能回到游戏页，且【语言设置保留】
        sh(f'{HDC} shell "aa force-stop com.andrewoscar.onemore"', 25)
        time.sleep(2.5)
        sh(f'{HDC} shell "aa start -a EntryAbility -b com.andrewoscar.onemore"', 25)
        time.sleep(8)
        # ② 去设置
        tap(1098, 2102)
        time.sleep(2)
        # ★★★ 2026-10-16 血泪：设置页会【记住上次的滚动位置】——
        #   我第一次跑 12 个语言全失败，就是因为页面停在【底部】（数据/关于那段），
        #   而语言选择在【上面】；find() 只会往下滚 ⇒ 越滚越远 ⇒ 永远找不到。
        #   ⇒ 搜索前先【滚到顶】（swipe 向下 = 内容下移 = 回到顶部）
        #   ★ 实测：6 次 × 500px 【不够】（页面很长）；8 次 × 600px 才到顶 ⇒ 用 10 次保险
        for _ in range(10):
            sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
            time.sleep(0.35)
        time.sleep(1.5)
        # ③ 切语言
        pos = find(disp)
        if not pos:
            # ★ 重试：再滚一次到顶（页面滚动位置偶发不同）
            for _ in range(10):
                sh(f'{HDC} shell "uitest uiInput swipe 660 1200 660 1800 250"', 20)
                time.sleep(0.35)
            time.sleep(1.5)
            pos = find(disp)
        if not pos:
            print('     ✗ 找不到语言按钮', flush=True)
            continue
        tap(*pos)
        time.sleep(3)
        # ④ 去游戏页
        tap(220, 2100)
        time.sleep(3)
        # ⑤ 进游戏
        #   ★★★ 2026-10-16 改打法：原来按【游戏名】找（GAME 表），
        #   但游戏名在各语言下的译文我猜不准（Bijoux/Juwelen/보석…全失败）
        #   ⇒ 改用【固定第一张卡片位置】—— 列表顺序变了也无所谓，
        #     指南页的机制（游戏名/分类/说明/要点/档位名/数字）任何一款都覆盖
        #   ★★★ 2026-10-16 铁律 28 又咬我一次：我把【预览坐标】当【设备坐标】用了！
        #   预览 994×1680 → 设备 1320×2232，系数 1.328
        #   第一张卡片预览 y≈1490 ⇒ 设备 y≈1979（我原来点 1500 ⇒ 点在卡片【上面】⇒ 没进游戏）
        #   ★★★ 2026-10-16 我又违反铁律 #38（目测坐标）—— 补上 dump 实测：
        #   dump 显示卡片文字「Bejeweled」bounds [282,1619][588,1675]
        #   ⇒ 卡片中心 ≈ (435, 1670)；我原来点 1979/2080 ⇒ ★ 点到【底部标签栏】的空处
        tap(435, 1670)
        time.sleep(4.5)
        # ⑥ 点「?」（游戏内右上角第二个按钮，设备坐标固定）
        tap(880, 283)
        time.sleep(3)
        # ⑦ 截图
        nm = 'G-%s.jpeg' % code
        if shot(nm):
            print('     ✅ %s' % nm, flush=True)
            ok.append(code)
        else:
            print('     ✗ 截图失败', flush=True)
    print()
    print('  ★ 完成 %d/12: %s' % (len(ok), ' '.join(ok)))


if __name__ == '__main__':
    main()
