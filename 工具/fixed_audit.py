#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-11-14：**逐款算 `FIXED`（头部+底部）与最优封顶 `X`**

## 为什么需要它

修方阵溢出时，盘面上限 `X`（`.width(Math.min(Bp.width-40, Math.max(lo, Bp.height - X)))`）
**不该是一个全局常量** —— 实测 `FIXED` 跨 `42` 款方差 `211 ~ 350vp`（`±33%`）：
- 对 `FIXED = 211` 的款（`GFractionMatch`）⇒ `X=360` 浪费 `149vp` 宽度
- 对 `FIXED = 350` 的款（`GFindWord`）⇒ `X=360` 只剩 `9vp` 余量

**⇒ 正确的 `X` 必须逐款算：`X = FIXED + 底部余量`**

## 数据从哪来

`shot_game.py` 现在输出 `board=WxH@x,y`（最大方形块的宽×高，`px`）。
配合**第 4 列** `max_bottom`（最低内容像素的 `y2`，`px`）——
⚠️ **不要**用说明里的 `max=N`：那是「`depth≤4` 布局块的越界量」，语义不同（判据 2024）：
```
FIXED_px = max_px − board_H_px
FIXED_vp = FIXED_px / 3        # 2560x1600@480 ⇒ 3px = 1vp
最优 X   = FIXED_vp + MARGIN   # MARGIN 默认 30vp（留余量防负载抖动）
```

## 用法

    python3 工具/fixed_audit.py              # 全库，按「浪费」降序
    python3 工具/fixed_audit.py --margin 40  # 改余量

## 局限

· `board=` 只有**今晚之后**的测量才有 ⇒ 老数据会显示「无 board 数据」
· 「最大方形块」不一定是棋盘（大按钮/弹窗也可能）⇒ 名单要人工确认
· `FIXED` 里含「盘面到屏底之间的全部内容」（提示行 + 按钮 + 间距）
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
PX_PER_VP = 3.0          # onemore7: 2560x1600 @480 ⇒ 3px = 1vp
SCREEN_VP = 533.0


FLOOR18 = ['2048','Crown','Dominosa','Gokigen Naname','Gomoku','Heyawake','Hitori','Hitori All',
           'Matrix Reasoning','Memory','Modulo Path','Norinori','Path Intersect','Pipes','Shikaku',
           'Skyscrapers','Schulte Table','Countdown Math']


HEADER_VP = 104.0   # 2026-11-14 队友静态分析：状态栏 39 + 顶栏 45 + padding 20


def opt_mode(margin):
    """2026-11-14：**按每款的「底部内容」算它的最优盘面**（盲区 ④ 的解法）。

    模型（`★头部其实只有104vp-模型修正`）：
        头部(104) + 盘面 + 底部 ≤ 533
    ⇒ `底部 = max_px/3 − 104 − 盘面_now`
    ⇒ `最优盘面 = 533 − 104 − 底部 = 533 − 104 − (max/3 − 104 − 盘面_now)`
                = `429 − max/3 + 104 + 盘面_now` … 化简成直接算：
        `bottom = max/3 − 104 − board_now`
        `board_best = 429 − bottom − margin`

    ⇒ 它回答「这款**该把盘面做成多大**」，而不是「改 X 还是改 floor」。
    """
    last = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            continue
        # ★ 2026-11-14（判据 2024）：**必须用第 4 列的 `max_bottom`，不能用说明里的 `max=`**
        #   实测 `303` 行里 `max=` 与第 4 列**从不相等** —— 因为 `max=` 是
        #   「depth≤4 的布局块越界量(px)」，而第 4 列是「最低内容像素的 y2」。
        #   语义完全不同：`max=` 回答「越了多少」，第 4 列回答「内容到哪」。
        m = re.search(r'board=(\d+)x(\d+)@', ln)
        if m and f[3].isdigit():
            last[f[1]] = (int(m.group(2)) / 3.0, int(f[3]) / 3.0, f[0][:16])

    if not last:
        print('⚠️ 台账里还没有带 `board=` 的测量 ⇒ 今晚跑完再来。')
        return 0

    rows = []
    for name, (bh, mx, ts) in last.items():
        bottom = mx - HEADER_VP - bh
        cap = 533.0 - HEADER_VP - bottom      # 零余量下的盘面上限
        safe = cap - margin                    # 留余量的值
        now_total = bh + bottom + HEADER_VP    # 现在的总高
        # 判定：现在溢出 / 现在正好 / 现在有余量可放大
        if now_total > 533.5:
            verdict = '⚠️ 现在溢出 %.0f' % (now_total - 533)
            action = '缩到 %.0f' % safe
        elif cap - bh > 15:
            verdict = '可放大 +%.0f' % (cap - bh)
            action = '放大到 %.0f' % cap
        else:
            verdict = '· 正好'
            action = '不动'
        rows.append((cap - bh, name, bh, bottom, cap, safe, verdict, action, ts))
    rows.sort(reverse=True)

    print('== 每款的最优盘面（头部 %.0fvp）==' % HEADER_VP)
    print('%-24s %7s %7s %8s %8s %s' % ('游戏', '现盘面', '底部', '盘面上限', '留余量', '判读'))
    print('-' * 86)
    for d, name, bh, bottom, cap, safe, verdict, action, ts in rows[:25]:
        print('%-24s %7.0f %7.0f %8.0f %8.0f %s ⇒ %s' % (name, bh, bottom, cap, safe, verdict, action))
    print('-' * 86)
    n_up = sum(1 for r in rows if r[0] > 15)
    n_over = sum(1 for r in rows if r[2] + r[3] + HEADER_VP > 533.5)
    print('可放大 >15vp: %d 款 / 现在溢出: %d 款 / 其余基本合适（共 %d）'
          % (n_up, n_over, len(rows)))
    print('\n⇒ 「盘面上限」= 零余量下能放多大；「留余量」= 再留 %.0fvp。' % margin)
    print('⚠️ 「底部」是推算值（`max/3 − 104 − 盘面`），误差约 ±20vp。')
    return 0

    print('== 每款的最优盘面（头部 %.0fvp / 余量 %.0fvp）==' % (HEADER_VP, margin))
    print('%-26s %8s %8s %10s %9s %s' % ('游戏', '现盘面', '底部', '最优盘面', '可放大', '测于'))
    print('-' * 84)
    for d, name, bh, bottom, best, ts in rows[:25]:
        flag = '✅' if d > 15 else ('·' if d > -15 else '⚠️ 现在超了')
        print('%-26s %8.0f %8.0f %10.0f %+9.0f %s %s' % (name, bh, bottom, best, d, ts, flag))
    print('-' * 84)
    n_up = sum(1 for r in rows if r[0] > 15)
    n_dn = sum(1 for r in rows if r[0] < -15)
    print('可放大 >15vp: %d 款 / 需缩小 >15vp: %d 款 / 基本合适: %d 款（共 %d）'
          % (n_up, n_dn, len(rows) - n_up - n_dn, len(rows)))
    print('\n⇒ 用法：对「可放大」的款，把盘面调大到「最优盘面」那一列')
    print('   （方阵：`X = 533 − 最优盘面`；或按 `floor` 调，看哪一档在起作用）')
    print('⚠️ 「底部」是推算值（`max/3 − 104 − 盘面`），误差约 ±20vp ⇒ 放大时留够余量。')
    return 0


def floor_mode(margin, since=''):
    """2026-11-14：**把今晚的 `blk` 换成明天的 `floor`**

    ⇒ 那 `18` 款写的是 `Math.max(240, Bp.height - 360)`，在 `533vp` 屏上取 `240`
      ⇒ 盘面 `240vp`。若今晚 `blk = N px`，说明还溢出 `N/3 vp`
      ⇒ **新 floor = 240 − N/3**（把盘面再收 `N/3`），并留 `margin`。
    """
    last = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            continue
        if since and f[0] < since:
            continue          # ★ 判据 2012：只认 `--since` 之后的行
        m = re.search(r'blk=(\d+)/(\d+)px', ln)
        if m:
            last[f[1]] = (int(m.group(2)), f[0][:16], ln)
    print('== 把 `blk` 换成明天的 `floor`（余量 %.0fvp）==' % margin)
    if not since:
        print()
        print('🚨 **没给 `--since`** —— 现在用的是台账里「每款最新一行」，')
        print('   而那可能是**改动之前**测的（判据 2012：旧 `max` 被截在 1600，不能用来算 floor）。')
        print('   **正确用法**：`--since 2026-11-15T00:10`（今晚 install 之后的时刻）')
        print()
    else:
        print('   （只统计 `%s` 之后的行）' % since)
    print('%-22s %8s %10s %12s %s' % ('游戏', 'blk(px)', '新 floor', '盘面将变成', '测于 / 判读'))
    print('-' * 84)
    for name in FLOOR18:
        v = last.get(name)
        if not v:
            print('%-22s %8s' % (name, '（无数据）')); continue
        blk, ts, _ = v
        # ★ 2026-11-14（判据 2012）：**必须确认这一行是「改动后」测的**
        #   改动前的 `max` 被截在 1600、`blk` 反映的是旧盘面 ⇒ 拿它算新 floor 会**再错一次**。
        #   所以把时间戳打出来，由人确认它晚于今晚的 `install` 时刻。
        new_floor = 240 - blk / 3.0 - margin
        board = max(new_floor, 533 - 360)
        if blk == 0:
            print('%-22s %8d %10s %12s %s ✅ 不必改' % (name, blk, '—', '240', ts))
        elif new_floor < 120:
            print('%-22s %8d %10.0f %12.0f %s ⚠️ floor<120 ⇒ 减盘面尺寸更合适'
                  % (name, blk, new_floor, board, ts))
        else:
            print('%-22s %8d %10.0f %12.0f %s → floor=%.0f'
                  % (name, blk, new_floor, board, ts, round(new_floor)))
    print()
    print('⚠️ **先看「测于」那列**：必须是**今晚 install 之后**的行；')
    print('   改动前的行 `max` 被截在 1600、`blk` 反映旧盘面 ⇒ 拿它算 floor 会再错一次（判据 2012）。')
    print('⇒ 用法：把上表「新 floor」那一列写进对应文件的 `Math.max(240, …)`')
    print('⇒ `blk=0` 的**不要动** —— 改小 floor 只会让格子变小、白占空间')
    return 0


def main():
    margin = 30.0
    if '--opt' in sys.argv:
        _m = 30.0
        if '--margin' in sys.argv:
            try:
                _m = float(sys.argv[sys.argv.index('--margin') + 1])
            except Exception:
                pass
        return opt_mode(_m)
    if '--floor' in sys.argv:
        _f = 30.0
        if '--margin' in sys.argv:
            try:
                _f = float(sys.argv[sys.argv.index('--margin') + 1])
            except Exception:
                pass
        _since = ''
        if '--since' in sys.argv:
            try:
                _since = sys.argv[sys.argv.index('--since') + 1]
            except Exception:
                pass
        return floor_mode(_f, _since)
    if '--margin' in sys.argv:
        try:
            margin = float(sys.argv[sys.argv.index('--margin') + 1])
        except Exception:
            pass

    last = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            continue
        # ★ 判据 2024：用**第 4 列** `max_bottom`（最低内容像素的 y2），
        #   不用说明里的 `max=`（那是 depth≤4 布局块的**越界量**，语义完全不同）。
        m = re.search(r'board=(\d+)x(\d+)@', ln)
        if m and f[3].isdigit():
            last[f[1]] = (f[0][:10], int(m.group(1)), int(m.group(2)), int(f[3]))

    if not last:
        print('== 逐款 FIXED 审计 ==')
        print('⚠️ 台账里还没有带 `board=` 的测量 —— 这是正常的：')
        print('   `board=` 是 2026-11-14 08:50 才加进 `shot_game.py` 的，')
        print('   **今晚那轮跑完就会有数据**。')
        return 0

    rows = []
    for name, (ts, bw, bh, mx) in last.items():
        fixed_px = mx - bh
        fixed_vp = fixed_px / PX_PER_VP
        best_x = fixed_vp + margin
        board_now = SCREEN_VP - 360          # 当前统一封顶
        board_best = SCREEN_VP - best_x
        rows.append((board_best - board_now, name, ts, fixed_vp, best_x, bw, bh, mx, board_now, board_best))
    rows.sort(reverse=True)

    print('== 逐款 FIXED 审计（余量 %.0fvp）==' % margin)
    print('%-28s %9s %8s %9s %9s %s' % ('游戏', 'FIXED_vp', '现盘面', '可放大到', '变化', '测于'))
    print('-' * 78)
    n_ok = 0
    for d, name, ts, fixed_vp, best_x, bw, bh, mx, board_now, board_best in rows[:20]:
        flag = '✅' if d > 10 else ('·' if d > -10 else '⚠️ 现在太大')
        print('%-28s %9.0f %8.0f %9.0f %+9.0f %s %s' % (name, fixed_vp, board_now, board_best, d, ts, flag))
        if d > 10:
            n_ok += 1
    print('-' * 78)
    print('可放大 >10vp 的：%d 款 / 共 %d 款有数据' % (n_ok, len(rows)))
    print('\n⇒ 用法：对上面每一款，把它的 `X` 从 360 改成 `%.0f + FIXED`（表里「可放大到」那列的补数）' % margin)
    print('   `X = 533 − 可放大到`，即 `X = %.0f − FIXED_vp`' % (SCREEN_VP - margin))
    return 0


if __name__ == '__main__':
    sys.exit(main())
