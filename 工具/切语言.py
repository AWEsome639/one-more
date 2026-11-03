#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
★★★ 切语言助手（2026-10-16 建）—— 根治「点了半天点不中」

用法：
    python3 工具/切语言.py 한국어          # 切到韩语
    python3 工具/切语言.py --list          # 只列出当前页所有语言按钮的真实坐标
    python3 工具/切语言.py --dump           # 只 dump 并保存

★ 为什么需要它：
  · 语言按钮的 text 带国旗 emoji（`🇰🇷 한국어`）⇒ 精确匹配永远找不到
  · 设置页是 Scroll，每次进页面的滚动位置都可能不同 ⇒ 手写坐标会偏
  · dumpLayout 给的是【当前真实 bounds】⇒ 用它点，100% 命中

★ 已实测：dump 72520 B 里三个语言按钮都在（한국어/繁體中文/Español）
"""
import json
import os
import re
import subprocess
import sys
import time

HDC = os.path.expanduser(
    '~/Library/Huawei/command-line-tools/sdk/default/openharmony/toolchains/hdc')
DEV = '127.0.0.1:5555'
TMP = '/tmp/lang-dump.json'


def sh(cmd, timeout=40):
    return subprocess.run(cmd, shell=True, capture_output=True,
                          text=True, timeout=timeout).stdout


def dump():
    """dump 当前页面布局到 TMP"""
    for i in range(3):
        sh(f'timeout 40 {HDC} shell "uitest dumpLayout -p /data/local/tmp/d.json"')
        sh(f'timeout 30 {HDC} file recv /data/local/tmp/d.json {TMP}')
        if os.path.exists(TMP) and os.path.getsize(TMP) > 1000:
            return True
        time.sleep(1)
    return False


def nodes(obj, out):
    """递归收集所有带 bounds 的节点"""
    if isinstance(obj, dict):
        a = obj.get('attributes')
        if isinstance(a, dict) and 'bounds' in a:
            out.append(a)
        for c in (obj.get('children') or []):
            nodes(c, out)
    elif isinstance(obj, list):
        for c in obj:
            nodes(c, out)


def parse_bounds(b):
    m = re.match(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b or '')
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return x1, y1, x2, y2, (x1 + x2) // 2, (y1 + y2) // 2


def find(target):
    """找 text 包含 target 的元素（★ 用包含，因为带国旗 emoji 前缀）"""
    hit = []
    try:
        d = json.load(open(TMP, encoding='utf-8'))
    except Exception as e:
        print(f'  ✗ dump 解析失败: {e}')
        return hit
    all_nodes = []
    nodes(d, all_nodes)
    for a in all_nodes:
        t = (a.get('text') or '') + (a.get('originalText') or '')
        if target in t:
            pb = parse_bounds(a.get('bounds'))
            if pb:
                hit.append((t.strip(), pb, a.get('clickable')))
    # ★ 优先 clickable 的、面积最小的（最内层元素）
    hit.sort(key=lambda h: (h[2] != 'true', (h[1][2] - h[1][0]) * (h[1][3] - h[1][1])))
    return hit


def tap(x, y):
    sh(f'timeout 20 {HDC} shell "uitest uiInput click {x} {y}"')
    time.sleep(4)


LANGS = ['简体中文', '繁體中文', 'English', '日本語', '한국어', 'Español',
         'Français', 'Deutsch', 'Português', 'Русский', 'Italiano', 'العربية']


def scroll_down(times=1):
    """★ 向下滚（内容上移），每次约 400 设备 px"""
    for _ in range(times):
        sh(f'timeout 20 {HDC} shell "uitest uiInput swipe 660 1500 660 1100 300"')
        time.sleep(1.5)


def main():
    if not dump():
        print('  ✗ dump 失败')
        return 1
    size = os.path.getsize(TMP)
    if '--list' in sys.argv or '--dump' in sys.argv:
        print(f'  dump {size} B')
        if '--dump' in sys.argv:
            return 0
        for lg in LANGS:
            h = find(lg)
            if h:
                t, pb, clk = h[0]
                print(f'     {lg:10s} ⇒ 设备({pb[4]},{pb[5]})  clickable={clk}  text="{t}"')
        return 0
    target = sys.argv[1]
    h = find(target)
    # ★★★ 2026-10-16 补：找不到就【自动往下滚】再找（设置页很长，界面模式在语言下面）
    if not h:
        for i in range(6):
            scroll_down(1)
            if not dump():
                break
            h = find(target)
            if h:
                print(f'  ↕ 滚了 {i+1} 次后找到')
                break
    if not h:
        print(f'  ✗ 当前页找不到「{target}」（dump {size} B，已滚 6 次）')
        return 1
    t, pb, clk = h[0]
    print(f'  ✅ 找到「{t}」⇒ 设备({pb[4]},{pb[5]}) clickable={clk} ｜ 点击')
    tap(pb[4], pb[5])
    return 0


if __name__ == '__main__':
    sys.exit(main())
