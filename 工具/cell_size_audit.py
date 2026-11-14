#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-11-14：**格子尺寸静态审计** —— 抓「限宽之后格子小到点不准」这一类（盲区 ③）

为什么需要它：
    `blk` 只量「超出屏幕」，`cov` 只量「被挡住」。
    而**格子缩小是修溢出的正常手段**，缩过头之后 `blk=0`、`cov=0`，
    看起来完美，**但格子只有 `11.5vp`，手指点不到** —— 两个指标都测不出来。

判据（★ 2026-11-14 校准）：
    名义下限 `44vp`（HIG），但**本项目的实际可接受下限约 `30vp`** ——
    证据：`Nurikabe`（`5×5`，`-360` ⇒ `34.6vp/格`）截图里格子 `~106px = 35vp`，**可正常点选**；
    `Sieve Visualizer`（`10×10` ⇒ `17.3vp`）实测 `OK 1454`，也无人报障。
    ⇒ 所以默认阈值取 **`30vp`**（`< 30` 偏小、`< 20` 不可点），而不是教条的 `44`。
    ⇒ 用 `--min 44` 可以按 HIG 严格模式跑。

用法：
    python3 工具/cell_size_audit.py            # 全库
    python3 工具/cell_size_audit.py --min 44   # 改阈值

局限（写在前面，别信过头）：
    · 列数靠「`const N` / `ForEach([...])` 元素个数」推断，**动态列数推不出来**（会跳过）
    · 封顶靠 `Math.min(... Bp.height - X)` 的 `X` 推断；用 `boardPx()` 的款也跳过
    · 所以它是**线索**，不是判决 —— 名单上的款要人工确认
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')
SCREEN_H = 533.0   # onemore7 的 vp 高度（2560x1600 @480 ⇒ 853x533）


def _strip_comments(src):
    """★ 2026-11-14（判据 2004）：**去掉注释行** —— 否则会读出注释里讲的旧值。

    实例：`GGo9` 的注释写着「h = (Bp.height - 300) * 0.70」（那是公式的一步），
    而真正的横屏封顶是 `-360`（同一文件 `L1047` 的注释明确写「实测 173vp」）。
    **⇒ 不去注释就会把 `GGo9` 读成 `X=300`，而它实际是 `360`。**
    """
    out = []
    for ln in src.split('\n'):
        t = ln.strip()
        if t.startswith('//') or t.startswith('*') or t.startswith('/*'):
            continue
        out.append(ln)
    return '\n'.join(out)


def cap_value(src):
    """取 `(floor, X)` —— **必须两个都取**（2026-11-14 修，判据 2008）。

    ⚠️ 为什么不能只取 X：写法是 `Math.max(240, Bp.height - 360)`，
       而 `533 - 360 = 173 < 240` ⇒ **`Math.max` 取 `240`** ⇒ **盘面是 `240vp`，
       不是 `173vp`**。今天有 `18` 处这种写法 ⇒ 只取 X 会把它们的盘面**低估 `67vp`**、
       把每格**低估 28%**（`Gomoku` 会算成 `11.5vp`，实际 `16.0vp`）。

    ⚠️ 另外必须先去掉注释行（判据 2004）—— 否则会命中注释里的演示值。
    """
    body = _strip_comments(src)
    m = re.search(r'Bp\.height\s*-\s*(\d+)', body)
    if not m:
        return None
    x = int(m.group(1))
    mf = re.search(r'Math\.max\(\s*(\d+)\s*,\s*Bp\.height\s*-\s*' + str(x), body)
    floor = int(mf.group(1)) if mf else 0
    return (floor, x)


def cols_value(src):
    """推断列数：优先 `const N`/`const COLS`/`NC`，其次 `ForEach([0,1,2,3])` 的元素个数"""
    m = re.search(r'const\s+(?:N|COLS|NC|SIZE)\s*:\s*number\s*=\s*(\d+)', src)
    if m:
        return int(m.group(1))
    # ForEach([0, 1, 2, 3], ...) —— 取出现次数最多的那个数组长度（通常是列循环）
    lens = []
    for arr in re.findall(r'ForEach\(\[([0-9,\s]+)\]', src):
        nums = [x.strip() for x in arr.split(',') if x.strip()]
        if 2 <= len(nums) <= 30:
            lens.append(len(nums))
    if not lens:
        return None
    # 列数通常 = 最常见的长度
    return max(set(lens), key=lens.count)


def main():
    threshold = 30.0   # ★ 本项目校准值（见文件头说明）；HIG 严格模式用 --min 44
    if '--min' in sys.argv:
        try:
            threshold = float(sys.argv[sys.argv.index('--min') + 1])
        except Exception:
            pass

    rows = []
    skipped = []
    for fn in sorted(os.listdir(GAMES)):
        if not fn.endswith('.ets'):
            continue
        p = os.path.join(GAMES, fn)
        src = io.open(p, encoding='utf-8').read()
        if 'aspectRatio(1)' not in src:
            continue
        cap = cap_value(src)
        cols = cols_value(src)
        if cap is None or not cols or cols < 2:
            skipped.append(fn[:-4])
            continue
        floor, x = cap
        # ★ 判据 2008：盘面 = max(floor, 屏高 - X)；floor 大于它就说明**封顶没生效**
        board = max(floor, SCREEN_H - x)
        cell = board / cols             # 每格（vp）
        rows.append((cell, fn[:-4], cols, x, board, floor))

    rows.sort()   # 小的排前面
    print('== 格子尺寸审计（触控下限 %.0fvp）==' % threshold)
    print('%-30s %5s %7s %7s %8s %s' % ('游戏', '列', '封顶X', '盘面vp', '格子vp', '判定'))
    print('-' * 72)
    bad = [r for r in rows if r[0] < threshold]
    ok = [r for r in rows if r[0] >= threshold]
    for cell, name, cols, x, board, floor in bad:
        flag = '❌ 不可点' if cell < 20 else '⚠️ 偏小'
        _fl = '' if floor <= (SCREEN_H - x) else ' (floor=%d 生效)' % floor
        print('%-30s %5d %7d %7.0f %8.1f %s%s' % (name, cols, x, board, cell, flag, _fl))
    print('-' * 72)
    print('偏小 %d 款 / 合规 %d 款 / 推断不出 %d 款' % (len(bad), len(ok), len(skipped)))
    if skipped:
        print('推断不出（列数或封顶不明，需人工看）：%s' % ', '.join(skipped[:8]))
    # ★ 2026-11-14：**另一半价值 —— 抓「封顶太松」（盘面会溢出）**
    #   今天我自己犯过：用 `Bp.height - 240` ⇒ 盘面 293vp + 头部 320 = 613vp > 533vp。
    #   判据：`X < 340` ⇒ 盘面 > 193vp ⇒ 加头部就有溢出风险。
    loose = [r for r in rows if r[3] < 340]
    if loose:
        print('\n== ⚠️ 封顶太松（X < 340 ⇒ 盘面 > 193vp，加头部可能溢出）%d 款 ==' % len(loose))
        for cell, name, cols, x, board, floor in sorted(loose, key=lambda r: r[3]):
            print('  %-30s X=%-4d 盘面=%.0fvp  每格=%.1fvp' % (name, x, board, cell))
        print('  ⇒ 判据：方形盘**高 = 封顶值**，加头部 ~320vp 必须 ≤ 533vp ⇒ **X ≥ 320**')
    else:
        print('\n== ✅ 没有「封顶太松」的款（全部 X ≥ 340）==')

    print('\n⚠️ 这是**线索**不是判决：名单上的款要人工确认「是不是真的点不准」。')
    print('⚠️ 已知误报来源：① `const N` 有时是「格子总数」不是列数（`Sieve` `N=100` 实为 `10×10`）')
    print('                ② 街机类（`Snake`/`Tetris`/`Breakout`）不是点选网格，格子小是设计如此')
    return 0


if __name__ == '__main__':
    sys.exit(main())
