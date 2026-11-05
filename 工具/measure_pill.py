#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
工具/measure_pill.py —— **量「药丸形」圆角是否真的生效**（判据 1297~1306）

★ 干嘛的：
  给一张截图 + 一个纯色元素的 y 范围，量它的**上下端点宽度**，
  与「药丸形理论值」对比。

★ 为什么需要（第 1391 轮）
  goal 待办：「`Radius.full`（160 处）的观感未抽验」
  我第一次判「🔴 方角」，因为我用了**拍出来的阈值** `ratio < 0.90`。
  而几何上：药丸形半径 = H/2 ⇒ **顶行只内缩 H/2**
    1080 宽的条、24px 高 ⇒ 顶行只缩 12px/侧 = 1.1%
    ⇒ ratio = **0.978**，**永远到不了 0.90**
  ⇒ 正确判据：**顶行宽 = W − H（±4px 抗锯齿）**

★ 用法：
  python3 工具/measure_pill.py <截图> [--y0 N] [--y1 N] [--color gray|accent]

★ 退出码：0 = 药丸形（差 ≤ 4px）；1 = 方角或测不到；2 = 用法错误

判据 1305：`Radius.full` 的观感可以**完全量化**，不需要「看着像不像」
"""
import sys
import numpy as np
from PIL import Image


def gray_mask(row):
    return ((np.abs(row[:, 0] - row[:, 1]) < 10) &
            (np.abs(row[:, 1] - row[:, 2]) < 10) &
            (row.mean(axis=1) > 150) & (row.mean(axis=1) < 240))


def accent_mask(row):
    sat = row.max(axis=1) - row.min(axis=1)
    return (sat > 60) & (row[:, 2] > 150) & (row[:, 2] > row[:, 0])


def longest_run(mask_idx):
    if len(mask_idx) == 0:
        return None
    runs = []
    st = mask_idx[0]
    prev = mask_idx[0]
    for x in mask_idx[1:]:
        if x - prev > 3:
            runs.append((st, prev))
            st = x
        prev = x
    runs.append((st, prev))
    return max(runs, key=lambda r: r[1] - r[0])


def main():
    if len(sys.argv) < 2:
        print('用法: measure_pill.py <截图> [--y0 N] [--y1 N] [--color gray|accent]')
        return 2
    p = sys.argv[1]
    y0 = 0
    y1 = None
    color = 'gray'
    args = sys.argv[2:]
    i = 0
    while i < len(args):
        if args[i] == '--y0':
            y0 = int(args[i + 1]); i += 2
        elif args[i] == '--y1':
            y1 = int(args[i + 1]); i += 2
        elif args[i] == '--color':
            color = args[i + 1]; i += 2
        else:
            i += 1

    A = np.array(Image.open(p).convert('RGB')).astype(int)
    H, W, _ = A.shape
    y1 = y1 or H
    maskf = gray_mask if color == 'gray' else accent_mask
    print('  图 %dx%d ｜ 扫描 y ∈ [%d, %d) ｜ 颜色 %s' % (W, H, y0, y1, color))

    # ① 找最长的一条
    best = None
    for y in range(max(0, y0), min(H, y1)):
        r = longest_run(np.where(maskf(A[y]))[0])
        if r and (r[1] - r[0]) > 200:
            if best is None or (r[1] - r[0]) > (best[2] - best[1]):
                best = (y, r[0], r[1])
    if best is None:
        print('  🔴 未找到色块（试 --color accent 或放宽 --y0/--y1）')
        return 1
    ymid, x0, x1 = best
    xc = (x0 + x1) // 2

    # ② 量高度（中线上下延伸）
    def ok(y):
        r = longest_run(np.where(maskf(A[y]))[0])
        return r is not None and r[0] <= xc <= r[1]
    ytop = ymid
    while ytop > 0 and ok(ytop - 1):
        ytop -= 1
    ybot = ymid
    while ybot < H - 1 and ok(ybot + 1):
        ybot += 1
    h = ybot - ytop + 1
    wmid = x1 - x0 + 1
    print('  条：y %d..%d ｜ 高 **%d px = %.1f vp** ｜ 中线宽 **%d px**'
          % (ytop, ybot, h, h / 3, wmid))

    # ③ 端点宽度（取顶/底行）
    def row_w(y):
        r = longest_run(np.where(maskf(A[y]))[0])
        return (r[1] - r[0] + 1) if r else 0
    wtop = row_w(ytop)
    wbot = row_w(ybot)

    # ④ ★ 判据 1304：按**几何**算，不用拍出来的阈值
    theo = wmid - h          # 药丸形：顶行 = W − H
    print()
    print('  ── 几何判据（判据 1304）──')
    print('    药丸形理论：顶行 = W − H = %d − %d = **%d**' % (wmid, h, theo))
    print('    实测：顶行 %d ｜ 底行 %d' % (wtop, wbot))
    dtop = wtop - theo
    dbot = wbot - theo
    print('    差：顶 %+d px ｜ 底 %+d px（±4 内算抗锯齿）' % (dtop, dbot))
    print()
    if abs(dtop) <= 4 and abs(dbot) <= 4:
        print('  ✅ **药丸形（`Radius.full` 生效，两端是半圆）**')
        return 0
    # 方角会是什么样？
    square = wmid
    if abs(wtop - square) <= 4 and abs(wbot - square) <= 4:
        print('  🔴 **方角（圆角未生效）** —— 顶/底行宽 ≈ 中线宽 %d' % square)
    else:
        print('  ⚠️ **既不是药丸也不是方角**（顶行 %d，理论药丸 %d，方角 %d）'
              % (wtop, theo, square))
    return 1


if __name__ == '__main__':
    sys.exit(main())
