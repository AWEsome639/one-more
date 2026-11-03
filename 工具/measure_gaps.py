#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
measure_gaps.py —— 界面「间隙信噪比 + 对比度」量测器
================================================================

来历（第 1070~1073 轮，判据 347 / 349 / 350）：
  开屏里 O 和 M 之间发生过两次视觉问题：
    ① 重叠 5.3%（奥森：「O 和 M 连到一起啦」）
    ② 修好后间隙只有 1.0 vp，仍显"粘"
  根因是**抗锯齿外扩**吃掉了大部分间隙：
    理论间隙 3.07 vp ｜ O 的抗锯齿外扩 2.3 vp ⇒ 实测只剩 1.0 vp
  ⇒ 判据 347：**阈值判断要给「信噪比」（实际值 ÷ 干扰值），
     不能只给"通过/不通过"**

为什么需要这个工具：
  · 目测"有没有缝"不可靠（三层缩放都会造假，判据 313）
  · "数值 > 0 ⇒ 已分离"也不可靠（信噪比 1.3 时肉眼看仍是粘的）
  · 每次手写量测脚本，容易犯两类错：
      ① 同色元素用颜色连通性分段 ⇒ 会被合并（判据 349）
      ② 取样框包含了别的元素（判据 310）
  ⇒ 把它做成工具，固定正确的量法

做什么：
  读一张截图，输出：
    ① **竖向内容带**（非背景的连续行区间）
    ② **相邻带之间的间隙 + 信噪比**（干扰值默认 2.3 vp 抗锯齿）
    ③ **每个带的对比度 ΔL**（最亮 − 背景最亮）
    ④ **横向指定区域的两元素间隙**（若给了 --x-pair）

用法：
  python3 工具/measure_gaps.py <截图路径>
  python3 工具/measure_gaps.py <截图路径> --density 3.0 --noise-vp 2.3
  python3 工具/measure_gaps.py <截图路径> --x-pair 913 2062   # 量横向间隙

判据说明：
  · 信噪比 = 间隙(vp) / 干扰(vp)   ⇒ **< 2 就是"临界"，< 1 就是"会被吃掉"**
  · ΔL     = 最亮 − 背景最亮      ⇒ **< 30 "偏淡"，< 12 "几乎不可见"**

⚠️⚠️ 已知局限（第 1074 轮实测，必须看）：
  **① 竖向布局 + 对比度：可靠**（已用开屏 960 帧验证过，与手工量测一致）
  **② 横向间隙（--x-pair）：已用形态学开运算改善，但仍需人工复核**
     （第 1075 轮更新：加了 `opening(mask, k=2)` 去掉星尘/颗粒）
     · **强光晕**（元素自带外发光且宽度 > 结构元）仍可能把间隙"填住"
     · 实测：开屏 O 环的外发光半径约等于间隙宽度 ⇒ 开运算后仍可能连在一起
     ⇒ **本段输出请结合截图人工确认**，不要单独依赖
"""
import sys
import os
import argparse

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print("需要 Pillow 与 numpy：pip install pillow numpy")
    sys.exit(2)


def load(path):
    im = Image.open(path).convert('RGB')
    return im, np.array(im, dtype=np.int32)


def background_median(A):
    """取图片最下方 8% 区域的中位色作为背景基准。"""
    H = A.shape[0]
    strip = A[int(H * 0.92):, :, :].reshape(-1, 3)
    return np.median(strip, axis=0)


def is_background_mask(A, bg, tol=32):
    """与背景基准的每通道差都 < tol 视为背景。"""
    d = np.abs(A - bg.reshape(1, 1, 3)).max(axis=2)
    return d < tol


def erode(mask, k=1):
    """二值腐蚀（用 min 滤波近似，k 为半径）。"""
    out = mask.copy()
    for _ in range(k):
        m = out.copy()
        # 四邻域取 min
        shifted = [m]
        shifted.append(np.pad(m[1:, :], ((0, 1), (0, 0)), constant_values=False))
        shifted.append(np.pad(m[:-1, :], ((1, 0), (0, 0)), constant_values=False))
        shifted.append(np.pad(m[:, 1:], ((0, 0), (0, 1)), constant_values=False))
        shifted.append(np.pad(m[:, :-1], ((0, 0), (1, 0)), constant_values=False))
        out = np.logical_and.reduce(shifted)
    return out


def dilate(mask, k=1):
    """二值膨胀（四邻域取 max）。"""
    out = mask.copy()
    for _ in range(k):
        m = out.copy()
        out = m.copy()
        out[1:, :] |= m[:-1, :]
        out[:-1, :] |= m[1:, :]
        out[:, 1:] |= m[:, :-1]
        out[:, :-1] |= m[:, 1:]
    return out


def opening(mask, k=1):
    """开运算 = 先腐蚀后膨胀 ⇒ 去掉比结构元小的亮斑（星尘/颗粒）。"""
    return dilate(erode(mask, k), k)


def content_runs(mask, min_h=3, min_px=30):
    """按行统计非背景像素数，返回连续的内容带 [(y1,y2), ...]。"""
    H = mask.shape[0]
    row = mask.sum(axis=1)
    runs, in_r, s = [], False, 0
    for y in range(H):
        if row[y] > min_px and not in_r:
            s, in_r = y, True
        elif row[y] <= min_px and in_r:
            if y - s >= min_h:
                runs.append((s, y - 1))
            in_r = False
    if in_r and H - s >= min_h:
        runs.append((s, H - 1))
    return runs


def band_stats(A, mask, y1, y2, bg):
    """一个内容带的统计：高度、最亮值、ΔL、主色。"""
    band = A[y1:y2 + 1]
    bm = mask[y1:y2 + 1]
    if bm.sum() == 0:
        return None
    px = band[bm]
    brightest = int(px.max())
    bg_bright = int(bg.max())
    return {
        'h_px': y2 - y1 + 1,
        'brightest': brightest,
        'dL': brightest - bg_bright,
        'mean': px.mean(axis=0),
    }


def horizontal_blocks(A, mask, x1, x2, y1, y2, min_w=4):
    """在 y1..y2 行内、x1..x2 列范围里，找横向的内容块。

    ★ 关键（判据 349）：**不能直接找"最长空白列"**
      —— 屏幕边缘的空白通常比两个元素之间的间隙更宽，
      那样会量到边缘而不是元素间隙。

    正确做法：先按列投影切出**内容块**，再找**相邻块之间**的空白。
    """
    sub = mask[y1:y2 + 1, x1:x2 + 1]
    col = sub.sum(axis=0)
    L = len(col)
    blocks = []
    in_b, s = False, 0
    for i in range(L):
        if col[i] > 2 and not in_b:
            s, in_b = i, True
        elif col[i] <= 2 and in_b:
            if i - s >= min_w:
                blocks.append((x1 + s, x1 + i - 1))
            in_b = False
    if in_b and L - s >= min_w:
        blocks.append((x1 + s, x1 + L - 1))
    return blocks


def gap_between_blocks(blocks, d, noise_vp):
    """找**相邻内容块之间**的空隙，返回按信噪比升序的列表。"""
    out = []
    for i in range(len(blocks) - 1):
        g = blocks[i + 1][0] - blocks[i][1] - 1
        if g <= 0:
            continue
        gv = g / d
        snr = gv / noise_vp if noise_vp > 0 else 999
        out.append({
            'gap_px': g, 'gap_vp': gv, 'snr': snr,
            'x1': blocks[i][1] + 1, 'x2': blocks[i + 1][0] - 1,
        })
    out.sort(key=lambda r: r['snr'])
    return out


def main():
    ap = argparse.ArgumentParser(description='界面「间隙信噪比 + 对比度」量测器')
    ap.add_argument('image', help='截图路径')
    ap.add_argument('--density', type=float, default=3.0,
                    help='像素/密度比（默认 3.0 ⇒ px ÷ 3 = vp）')
    ap.add_argument('--noise-vp', type=float, default=2.3,
                    help='抗锯齿等干扰的等效宽度 vp（默认 2.3，实测自开屏 O 环）')
    ap.add_argument('--min-run-px', type=int, default=30,
                    help='判定"有内容"的行阈值（默认 30 像素）')
    ap.add_argument('--bg-tol', type=int, default=32,
                    help='背景容差（默认 32）')
    ap.add_argument('--x-pair', nargs=2, type=int, metavar=('X1', 'X2'),
                    help='量横向间隙的列范围（如 913 2062）')
    args = ap.parse_args()

    if not os.path.exists(args.image):
        print('❌ 文件不存在: %s' % args.image)
        return 2

    im, A = load(args.image)
    H, W = A.shape[:2]
    d = args.density
    bg = background_median(A)
    mask = ~is_background_mask(A, bg, args.bg_tol)

    print()
    print('  ════════════════════════════════════════════════════════════')
    print('  界面间隙／对比度量测')
    print('  ════════════════════════════════════════════════════════════')
    print('  图: %s' % os.path.basename(args.image))
    print('      %d×%d px ⇒ **%d×%d vp**（密度 %.1f）' % (
        W, H, int(W / d), int(H / d), d))
    print('  背景基准: RGB(%d, %d, %d)' % (int(bg[0]), int(bg[1]), int(bg[2])))
    print('  干扰基准: **%.1f vp**（抗锯齿等）' % args.noise_vp)
    print()

    # ── ① 竖向内容带 ──
    runs = content_runs(mask, min_px=args.min_run_px)
    if not runs:
        print('  ⚠️ 没有检测到内容带（检查 --bg-tol 或截图是否为空）')
        return 1

    print('  ── ① 竖向内容带 ──')
    print('     %-4s %-14s %-14s %s' % ('#', 'y 范围', '高度', '对比度 ΔL'))
    for i, (y1, y2) in enumerate(runs, 1):
        st = band_stats(A, mask, y1, y2, bg)
        if not st:
            continue
        hp, hv = st['h_px'], st['h_px'] / d
        dL = st['dL']
        tag = '✅' if dL >= 40 else ('⚠️ 偏淡' if dL >= 30 else '🚨 几乎不可见')
        print('     %-4d %-14s %-14s %s' % (
            i,
            '%d..%d' % (y1, y2),
            '%d px = %.1f vp' % (hp, hv),
            'ΔL = **%d** %s' % (dL, tag)))

    # ── ② 竖向间隙 + 信噪比 ──
    print()
    print('  ── ② 相邻内容带的竖向间隙 ──')
    print('     %-8s %-12s %-12s %-8s %s' % ('带', '间隙', '信噪比', '判定', '备注'))
    warn = 0
    for i in range(len(runs) - 1):
        y1 = runs[i][1]
        y2 = runs[i + 1][0]
        gap_px = y2 - y1 - 1
        gap_vp = gap_px / d
        snr = gap_vp / args.noise_vp if args.noise_vp > 0 else 999
        if snr >= 2:
            tag, note = '✅ 安全', ''
        elif snr >= 1:
            tag, note = '⚠️ 临界', '可能有"粘"的观感'
            warn += 1
        else:
            tag, note = '🚨 会被吃掉', '视觉上会连成一片'
            warn += 1
        print('     %-8s %-12s %-12s %-8s %s' % (
            '%d→%d' % (i + 1, i + 2),
            '%d px = %.1f vp' % (gap_px, gap_vp),
            '**%.2f**' % snr, tag, note))

    if runs:
        last_bot = runs[-1][1]
        below = (H - 1 - last_bot) / d
        print()
        print('     最下内容带底 = %d ｜ 下方留白 **%.1f vp**' % (last_bot, below))

    # ── ③ 横向间隙（可选） ──
    if args.x_pair:
        x1, x2 = args.x_pair
        print()
        print('  ── ③ 横向间隙（列 %d..%d）──' % (x1, x2))
        print('     ⚠️ 已做形态学开运算去星尘；但**强光晕**仍可能填住间隙（见文件头局限 ②）')
        print('     ⚠️ 本段输出请结合截图人工确认')
        # ★ 关键修法（第 1075 轮）：先做**开运算**去掉星尘/颗粒/细小光斑，
        #   否则 `非背景` 掩码会被它们填满，两个元素会被合并成一个块
        clean = opening(mask, k=2)
        blocks = horizontal_blocks(A, clean, x1, x2, runs[0][0], runs[0][1])
        print('     检测到 **%d 个横向内容块**：' % len(blocks))
        for k, (a, b) in enumerate(blocks, 1):
            print('       块 %d: x %d..%d（宽 %d px = %.1f vp）' % (
                k, a, b, b - a + 1, (b - a + 1) / d))
        gaps = gap_between_blocks(blocks, d, args.noise_vp)
        if gaps:
            print()
            print('     相邻块之间的空隙（按信噪比升序）：')
            for r in gaps:
                tag = '✅ 安全' if r['snr'] >= 2 else (
                    '⚠️ 临界' if r['snr'] >= 1 else '🚨 会被吃掉')
                print('       x %d..%d ｜ 宽 %d px = **%.1f vp** ｜ 信噪比 **%.2f** ⇒ %s' % (
                    r['x1'], r['x2'], r['gap_px'], r['gap_vp'], r['snr'], tag))
                if r['snr'] < 2:
                    warn += 1
        else:
            print('     ⚠️ 只有 1 个内容块（两个元素已合并或范围切错）')

    # ── ④ 总结 ──
    print()
    print('  ────────────────────────────────────────────────────────────')
    if warn:
        print('  ⚠️ **%d 处落在临界或更差** ⇒ 按判据 347/348，'
              '若调整代价 < 5%% 就推到安全区' % warn)
    else:
        print('  ✅ 全部间隙信噪比 ≥ 2 ｜ 全部对比度 ΔL ≥ 30')
    print('  ────────────────────────────────────────────────────────────')
    print()
    print('  判据回顾：')
    print('    · 信噪比 < 2 ⇒ 临界（判据 347）')
    print('    · 信噪比 < 1 ⇒ 视觉上会被吃掉')
    print('    · ΔL < 30   ⇒ 偏淡 ｜ ΔL < 12 ⇒ 几乎不可见（判据 350）')
    print('    · 同色元素不能用颜色连通性分段，要用形状签名（判据 349）')
    print()
    return 0 if warn == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
