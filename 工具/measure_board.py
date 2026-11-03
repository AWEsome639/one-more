#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
棋盘类游戏「行列数」测量器（判据 438 落地）

★ 为什么要有这个（2026-11-03 第 1128 轮，一次严重的自我纠正）
  我在数 Bejeweled 的行列时，用 `gem[:840, :] = False` 排除顶部 UI
  ⇒ 而某个系数下棋盘恰好从 y=744 开始 ⇒ **第 1 行被这一刀砍掉**
  ⇒ 得到「6 行」，与另一个真实问题（我改系数造成的回归）**巧合一致**
  ⇒ **两个错误互相印证，我判定"发现了既有 bug"，还写了三条判据支持它**

  ⇒ 判据 438：**测量脚本里"排除某区域"必须相对定位，禁止写死像素边界**
  ⇒ 判据 439：**两个数一致时也要 diff 口径**

★ 本工具的做法（三步，全部相对）
  ① 找**被测对象自己的包围盒**（高饱和彩色块 = 宝石/棋子）
     —— 不做任何固定像素排除
  ② 从包围盒**内部**做行/列投影
  ③ 用**中位带高**筛掉假阳性（残余文字、进度条）
  ④ 输出行数/列数 + 每格尺寸 + 棋盘在屏内的占比 + 是否贴边

用法：
  python3 工具/measure_board.py <截图.png> [--min-cell 12]
退出码：0 = 数出了结果 ｜ 1 = 数不出（需人工看）
"""
import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print('🔴 缺少 Pillow / numpy')
    sys.exit(1)


def measure(path, min_cell_vp=12.0, sat_min=90, px_per_vp=3.0):
    im = Image.open(path).convert('RGB')
    A = np.array(im, dtype=np.int32)
    H, W = A.shape[:2]
    sat = A.max(axis=2) - A.min(axis=2)
    mask = sat > sat_min

    ys, xs = np.where(mask)
    if len(xs) < 500:
        return {'ok': False, 'why': '高饱和像素太少（不是棋盘类画面？）'}

    # ★ 步骤①：定位棋盘 —— **二维密度网格找最大的密集块**
    #   ⚠️ 前两版定位都是错的，完整记录（判据 440）：
    #     ① "最长连续有内容区间" ⇒ 抓到 HintBar（细长彩条）⇒ 数出「1 行 × 2 列」
    #     ② "相邻区段合并 + 方形度" ⇒ 只在相邻 UI 条之间合并 ⇒ 数出「3 行 × 7 列」
    #   ⇒ 两版的共同错误：**用"行方向的一维信号"去找一个二维对象**。
    #   ⇒ 正确做法：把图分成粗网格，标出"高饱和占比高"的格子，
    #      再找这些格子连成的**最大块**（这才是棋盘的形状）。
    GX, GY = 32, 32
    gh, gw = H // GY, W // GX
    dens = np.zeros((GY, GX))
    for gy in range(GY):
        for gx in range(GX):
            cell = mask[gy * gh:(gy + 1) * gh, gx * gw:(gx + 1) * gw]
            dens[gy, gx] = cell.mean() if cell.size else 0
    # 高饱和占比 > 15% 的格子算"棋盘格"
    hot = dens > 0.15
    # 找最大连通块（4 邻域）
    from collections import deque
    seen = np.zeros_like(hot, dtype=bool)
    best_block = None
    for gy in range(GY):
        for gx in range(GX):
            if not hot[gy, gx] or seen[gy, gx]:
                continue
            q = deque([(gy, gx)])
            seen[gy, gx] = True
            cells = []
            while q:
                cy, cx = q.popleft()
                cells.append((cy, cx))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < GY and 0 <= nx < GX and hot[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if best_block is None or len(cells) > len(best_block):
                best_block = cells
    if not best_block:
        return {'ok': False, 'why': '密度网格里找不到密集块'}
    ys_ = [c[0] for c in best_block]
    xs_ = [c[1] for c in best_block]
    best_st = max(0, min(ys_) * gh)
    best_en = min(H - 1, (max(ys_) + 1) * gh - 1)
    bcx1 = max(0, min(xs_) * gw)
    bcx2 = min(W - 1, (max(xs_) + 1) * gw - 1)
    best_sq = min(bcx2 - bcx1 + 1, best_en - best_st + 1) / max(bcx2 - bcx1 + 1, best_en - best_st + 1)

    # ★ 步骤②：在棋盘主体内部做投影
    cx1, cx2 = bcx1, bcx2
    inner = mask[best_st:best_en + 1, cx1:cx2 + 1]

    def bands(proj, min_px):
        out, st2 = [], None
        for i, v in enumerate(proj):
            if v > min_px and st2 is None:
                st2 = i
            elif v <= min_px and st2 is not None:
                out.append((st2, i - 1))
                st2 = None
        if st2 is not None:
            out.append((st2, len(proj) - 1))
        return [b for b in out if b[1] - b[0] + 1 >= 4]

    rb = bands(inner.sum(axis=1), 10)
    cb = bands(inner.sum(axis=0), 10)

    # ★ 步骤③：中位带高/宽筛假阳性
    if not rb:
        return {'ok': False, 'why': '行带为空'}
    rh = [(b - a + 1) for a, b in rb]
    mh = sorted(rh)[len(rh) // 2]
    rb2 = [b for b in rb if abs((b[1] - b[0] + 1) - mh) < mh * 0.6]
    if cb:
        cw = [(b - a + 1) for a, b in cb]
        mw = sorted(cw)[len(cw) // 2]
        cb2 = [b for b in cb if abs((b[1] - b[0] + 1) - mw) < mw * 0.6]
    else:
        cb2 = []

    cell_vp = mh / px_per_vp
    if cell_vp < min_cell_vp:
        return {'ok': False, 'why': '格子太小（%.1f vp），可能数错了' % cell_vp,
                'rows': len(rb2), 'cols': len(cb2)}

    return {
        'ok': True,
        'rows': len(rb2),
        'cols': len(cb2),
        'cell_vp': cell_vp,
        'board_y_vp': (best_st + rb2[0][0]) / px_per_vp if rb2 else best_st / px_per_vp,
        'board_bottom_vp': (best_st + rb2[-1][1]) / px_per_vp if rb2 else best_en / px_per_vp,
        'screen_vp': (W / px_per_vp, H / px_per_vp),
        'raw_rows': len(rb),
        'raw_cols': len(cb),
        'squareness': float(best_sq),
    }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    if not args:
        print('用法: python3 工具/measure_board.py <截图.png>')
        return 1
    rc = 0
    for p in args:
        if not os.path.exists(p):
            print('  ⚠️ 跳过（不存在）: %s' % p)
            continue
        r = measure(p)
        print('=' * 64)
        print('  %s' % os.path.basename(p))
        print('=' * 64)
        if not r['ok']:
            print('  🔴 数不出来：%s' % r.get('why'))
            if 'rows' in r:
                print('     粗数：%d 行 × %d 列（未通过筛选）' % (r['rows'], r['cols']))
            rc = 1
            continue
        print('  **%d 行 × %d 列**' % (r['rows'], r['cols']))
        print('  方形度 %.2f（1.00 = 正方形块，用来确认抓对了区域）' % r.get('squareness', 0))
        print('  每格 %.1f vp ｜ 原始带数 %d 行 / %d 列（筛掉 %d/%d 个假阳性）'
              % (r['cell_vp'], r['raw_rows'], r['raw_cols'],
                 r['raw_rows'] - r['rows'], r['raw_cols'] - r['cols']))
        print('  棋盘 y %.1f..%.1f vp ｜ 屏 %.0f×%.0f vp ｜ 底部余量 **%.1f vp**'
              % (r['board_y_vp'], r['board_bottom_vp'],
                 r['screen_vp'][0], r['screen_vp'][1],
                 r['screen_vp'][1] - r['board_bottom_vp']))
        if r['rows'] != r['cols'] and r['rows'] in (5, 6, 7, 8, 9) and r['cols'] in (5, 6, 7, 8, 9):
            print('  ⚠️ 行列不等 —— 棋盘类游戏通常应为正方形（人工确认 N）')
    print()
    print('=' * 64)
    print('  ⚠️ 本工具**不做任何固定像素排除**（判据 438）')
    print('  ⚠️ 行列数必须与源码里的 `const N` 对照（判据 439）')
    print('=' * 64)
    return rc


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
