#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_text_squeeze.py —— 从真机 dump 里找「被挤压的文字」（判据 680 的工具化）

★ 为什么需要（第 1259 轮）
  第 1255~1258 轮为了修一个「233×233 上标题逐字竖排」，花了 **4 轮**：
    · 前两轮改错组件（判据 687：没先确认是哪个组件渲染的）
    · 第 1256 轮还推导出错误结论（把 `Space.lg` 记成 24，实际 20）
    · 最后靠「红色背景量像素」才定位（判据 688）
  而如果能**一眼看出「哪些文字的宽高比异常」**，第一轮就能锁定。

★ 判据 680 的定义
  `文字被挤压` ⇔ `bounds.高 / bounds.宽 > 1.5` 且 `字数 > 1`
  因为：横向排版的 2 字以上文本，高度应 ≈ 1 行高，宽度 ≈ 字数 × 字宽
        ⇒ 高/宽 通常 < 1；一旦逐字竖排，高/宽 会飙升到 3 以上

用法：
  python3 工具/check_text_squeeze.py <dump.json> [<dump2.json> ...]
  python3 工具/check_text_squeeze.py            # 自动扫 /tmp 下最近的 dump

退出码：0 = 无挤压 ｜ 1 = 有挤压 ｜ 2 = 输入问题
"""
import glob
import io
import json
import os
import re
import sys

# 不算「挤压」的目录外文字（状态栏）
SKIP = ('09, :', '10, :', '11, :', '08, :')

RATIO = 1.5      # 高/宽 超过这个倍数就算挤压（判据 680）


def scan(path):
    try:
        d = json.load(io.open(path, encoding='utf-8'))
    except Exception as e:
        return None, 'JSON 解析失败: %s' % e

    rows = []

    def walk(n):
        if not isinstance(n, dict):
            return
        a = n.get('attributes', {})
        t = (a.get('text') or '').strip()
        b = a.get('bounds') or ''
        m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', b)
        if t and m:
            x1, y1, x2, y2 = [int(v) for v in m[0]]
            w, h = x2 - x1, y2 - y1
            rows.append((t, x1, y1, w, h, a.get('type')))
        for c in n.get('children', []) or []:
            walk(c)

    walk(d)
    bad = []
    for t, x, y, w, h, ty in rows:
        if len(t) <= 1 or w <= 0 or h <= 0:
            continue
        if any(t.startswith(s) for s in SKIP):
            continue
        r = h / w
        if r > RATIO:
            bad.append((t, x, y, w, h, r, ty))
    return (len(rows), bad), None


def main():
    paths = sys.argv[1:]
    if not paths:
        # 扫 /tmp 下最近的 json
        cands = sorted(glob.glob('/tmp/*.json'), key=os.path.getmtime, reverse=True)[:12]
        paths = [p for p in cands if os.path.getsize(p) > 500]

    if not paths:
        print('没有可用的 dump 文件'); return 2

    print('=' * 72)
    print('  文字挤压检查（判据 680：高/宽 > %.1f 且字数 > 1）' % RATIO)
    print('=' * 72)
    total_bad = 0
    for p in paths:
        res, err = scan(p)
        if err:
            print('  ⚠️ %-40s %s' % (os.path.basename(p), err)); continue
        n, bad = res
        mark = '🔴' if bad else '✅'
        print('  %s %-38s 文字 %3d 条 ｜ 挤压 %d' % (mark, os.path.basename(p), n, len(bad)))
        for t, x, y, w, h, r, ty in bad[:8]:
            print('       「%s」 %dx%d 高/宽=%.1f  @(%d,%d)' % (t[:14], w, h, r, x, y))
        if len(bad) > 8:
            print('       …还有 %d 条' % (len(bad) - 8))
        total_bad += len(bad)
    print('=' * 72)
    print('  合计挤压 **%d** 条' % total_bad)
    print('=' * 72)
    return 1 if total_bad else 0


if __name__ == '__main__':
    sys.exit(main())
