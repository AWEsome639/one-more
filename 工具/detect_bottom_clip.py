#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ⛔⛔⛔ **本脚本未校准，不要用它下结论（判据 3018）** ⛔⛔⛔
#
# 2026-11-19 首次运行结果：**190 / 355 张（54%）被判「底部被切」** —— 明显误报：
#   · `Mandelbrot` 被判 52.8%，但它精确严重度只有 `2.8%`、截图看过是好的
#   · `Wordle` 20.8% 也上了榜（历史 7 次稳定、已验证）
#   · `Magnets` 2.7% 同样
#
# 根因：它把「**满屏设计的背景面板延伸到下边**」当成了「卡片被切」。
# 区分这两者需要**形状感知**（有没有可见的底边圆角/描边），单靠颜色做不到。
#
# ⇒ **54% 的误报率比没有检测器更糟**（报警疲劳，判据 3010）。
#   要修：加「底边是否有圆角/描边」的判据，或直接人工看截图。
#   在那之前，本文件只作为「试过、失败」的记录保留，不进任何流程。
"""
在**截图**上检测「底部被切」—— 判据 3017 的配套尺子。

为什么需要它：`blk` 量不出「元素本该多高」（`3011`/`3017`），
`Simon Command` 的色块实际被切 `71vp` 而 `blk` 只报 `8vp`（差 9 倍）。
⇒ 直接在截图上找「有一块颜色一直延伸到屏幕最底行」的签名。

判据：最后一行（y=h-1）上若有 **连续 ≥60px、颜色≠背景、且该颜色连通面积 ≥5000px** 的像素段，
      就判「有一块面板/卡片被下沿切了」。背景色大面积铺底不算。

用法：
  python3 工具/detect_bottom_clip.py [--all] [--top N]
  默认只查台账每个游戏**末次**引用的截图；--all 查全部截图。
"""
import sys, os, io, re, glob
from collections import Counter
try:
    from PIL import Image
    import numpy as np
except ImportError:
    sys.exit('需要 Pillow + numpy')

LEDGER = '_巡检记录/layout-canonical.tsv'
SIZE = (2560, 1600)           # 只查本机横屏截图；别的尺寸常量不同，判不了
RUN_MIN = 60                  # 连续段最短像素
AREA_MIN = 5000               # 该颜色连通面积下限（滤掉细线与手势条）
ROW_BAND = 3                  # 允许最后几行（JPEG 边缘噪声）

def clip_ratio(a):
    """返回 (被切比例 0~1, 细节)。0 表示没测到底部被切。"""
    h, w, _ = a.shape
    # 手势条区域（最底 ~20px、中间 40% 宽）会被系统画成浅色 ⇒ 排除
    m = a.copy()
    m[h-22:h, int(w*0.28):int(w*0.72)] = 255
    # 背景色 = 全图最常见颜色
    small = m[::4, ::4].reshape(-1, 3)
    bg = Counter(map(tuple, small)).most_common(1)[0][0]
    bgv = np.array(bg)
    # 每个候选颜色：全图连通面积（用出现的总像素数近似）
    flat = m.reshape(-1, 3)
    cnt = Counter(map(tuple, flat[::3]))
    big = {c for c, n in cnt.items() if n*9 >= AREA_MIN and max(abs(np.array(c)-bgv)) > 25}
    if not big:
        return 0.0, None
    # 看最后几行
    for y in range(h-1, h-1-ROW_BAND, -1):
        row = m[y]
        best = None; run = 0; prev = None
        for x in range(w):
            c = tuple(row[x])
            if any(abs(c[i]-bgv[i]) <= 25 for i in range(3)):
                run = 0; prev = None; continue
            if prev is not None and all(abs(c[i]-prev[i]) <= 18 for i in range(3)):
                run += 1
            else:
                run = 1; prev = c
            if run >= RUN_MIN and c in big:
                best = (c, run, x); break
        if best:
            # 量这块颜色从底部往上连续多少行
            c = np.array(best[0])
            hh = 0
            for yy in range(h-1, max(0, h-900), -1):
                if np.abs(m[yy]-c).max(axis=1).min() <= 18: hh += 1
                else: break
            return min(1.0, hh/float(h)), (best[0], best[1], hh)
    return 0.0, None

def main():
    want_all = '--all' in sys.argv
    top = 30
    if '--top' in sys.argv:
        top = int(sys.argv[sys.argv.index('--top')+1])
    want = {}
    if not want_all:
        rows=[l.rstrip('\n').split('\t') for l in io.open(LEDGER, encoding='utf-8') if len(l.split('\t'))>=5]
        last={}
        for r in rows: last[r[1]]=r
        for g, r in last.items():
            mm = re.search(r'(_巡检记录/截图-\S+?\.jpeg)', r[4])
            if mm: want[mm.group(1)] = g
        files = sorted(want)
    else:
        files = sorted(glob.glob('_巡检记录/截图-*.jpeg'))
    hits = []
    checked = 0
    for p in files:
        if not os.path.exists(p): continue
        try:
            im = Image.open(p).convert('RGB')
        except Exception:
            continue
        if im.size != SIZE: continue
        checked += 1
        ratio, info = clip_ratio(np.asarray(im).astype(int))
        if ratio > 0:
            hits.append((ratio, want.get(p, os.path.basename(p)), os.path.basename(p), info))
    hits.sort(reverse=True)
    print('检查 %d 张 %dx%d 截图，判「底部被切」%d 张' % (checked, SIZE[0], SIZE[1], len(hits)))
    print('\n%-6s %-30s %-13s %s' % ('占比', '游戏', '截图', '被切高度'))
    for ratio, g, f, info in hits[:top]:
        print('%-6.1f%% %-30s %-13s %dpx (%.0fvp)' % (ratio*100, g[:30], f[-10:-5], info[2], info[2]/3))
    if len(hits) > top:
        print('… 另有 %d 张' % (len(hits)-top))

if __name__ == '__main__':
    main()
