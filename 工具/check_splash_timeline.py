#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
开屏时间表检查器（判据 370 / 371）

★ 为什么要有这个文件（2026-11-03 第 1093 轮）
  开屏曾存在一个**严重但完全静默**的缺陷：
    L6 标题 820+550 = 1370 ｜ L7 副标题 1080+360 = 1440
    L8 标语 1220+400 = 1620 ｜ L9 退场 **1400**+460
  ⇒ **退场起点(1400) 早于副标题止点(1440)、标语止点(1620)**
  ⇒ 三行文字的「可读窗口」= 30ms / −40ms / −220ms
  ⇒ **没有一个字是静止可读的**
  而这件事在 12 帧"验收"里完全没被发现（拍的全早于 1620ms）。

⇒ 所以把两条判据固化成脚本：

  判据 370：入场止点必须 ≤ 出场起点（区间不许重叠）
  判据 371：每层必须有 ≥ 300ms 的「可读窗口」
           可读窗口 = [入场止点, 出场起点]

用法：
  python3 工具/check_splash_timeline.py
退出码：0 = 全通过 ｜ 1 = 有不合格项
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPLASH = os.path.join(ROOT, 'entry/src/main/ets/pages/Splash.ets')

# 需要检查的「入场层」：变量名 → 中文名
LAYERS = [
    ('pTitle', '标题 One More'),
    ('pSub',   '副标题 355 GAMES'),
    ('pTag',   '标语 A quick round'),
]

# 可读窗口下限（ms）—— 判据 371
MIN_READABLE = 300


def main() -> int:
    if not os.path.exists(SPLASH):
        print('🔴 找不到 %s' % SPLASH)
        return 1
    src = io.open(SPLASH, encoding='utf-8').read()

    fails = 0

    # ── 读 TOTAL / HOLD ──
    m_total = re.search(r'const TOTAL: number = (\d+);', src)
    m_hold = re.search(r'const HOLD: number = (\d+);', src)
    if not m_total or not m_hold:
        print('🔴 找不到 TOTAL / HOLD 常量')
        return 1
    total = int(m_total.group(1))
    hold = int(m_hold.group(1))

    # ── 读各层 (起点, 时长) ──
    entries = {}
    for var, name in LAYERS:
        m = re.search(r'this\.%s = (?:sm|lin)\((\d+),\s*(\d+)\);' % var, src)
        if not m:
            print('🔴 找不到 %s 的时间定义（this.%s = sm(...)）' % (name, var))
            fails += 1
            continue
        st, du = int(m.group(1)), int(m.group(2))
        entries[var] = (name, st, du, st + du)

    # ── 读退场 ──
    m_out = re.search(r'this\.pOut = (?:sm|lin)\((\d+),\s*(\d+)\);', src)
    if not m_out:
        print('🔴 找不到 pOut（整体推出）的时间定义')
        return 1
    out_st, out_du = int(m_out.group(1)), int(m_out.group(2))
    out_end = out_st + out_du

    print('=' * 62)
    print('开屏时间表检查（判据 370 / 371）')
    print('=' * 62)
    print('  TOTAL = %d ms ｜ HOLD = %d ms' % (total, hold))
    print('  退场  pOut  %4d + %4d = %4d ms' % (out_st, out_du, out_end))
    print()
    print('  %-18s %-18s %-12s %s' % ('层', '入场区间', '可读窗口', '判定'))
    print('  ' + '-' * 58)

    for var, name in LAYERS:
        if var not in entries:
            continue
        _, st, du, end = entries[var]
        win = out_st - end
        # 判据 370：入场止点 ≤ 出场起点
        ok370 = end <= out_st
        # 判据 371：窗口 ≥ MIN_READABLE
        ok371 = win >= MIN_READABLE
        ok = ok370 and ok371
        mark = '✅' if ok else ('🔴 重叠 %dms' % (end - out_st) if not ok370
                               else '🔴 窗口仅 %dms' % win)
        print('  %-18s %4d..%-4d (%-4d ms) %6d ms     %s'
              % (name, st, end, du, win, mark))
        if not ok:
            fails += 1

    print('  ' + '-' * 58)

    # ── 附加检查：TOTAL / HOLD 与退场的关系 ──
    print()
    print('  ══ 总时长一致性 ══')
    ok_total = total >= out_end
    print('    TOTAL(%d) ≥ 退场止点(%d) ?  %s'
          % (total, out_end, '✅' if ok_total else '🔴 退场还没走完就置 1 了'))
    if not ok_total:
        fails += 1
    ok_hold = hold <= total
    print('    HOLD(%d) ≤ TOTAL(%d) ?     %s'
          % (hold, total, '✅（硬跳先于进度终点，交接转场接住）' if ok_hold
             else '⚠️ HOLD 比 TOTAL 还晚，硬跳前已置 1'))
    gap = out_end - hold
    print('    硬跳比退场止点早 %d ms（由 Index 的入场接住）' % gap)

    print()
    last_end = max(e[3] for e in entries.values() if e)
    still = out_st - last_end
    print()
    print('    %d → %d = **%d ms** %s'
          % (last_end, out_st, still, '✅' if still >= MIN_READABLE else '🔴 太短'))
    if still < MIN_READABLE:
        fails += 1

    print()
    print('=' * 62)
    if fails == 0:
        print('✅ 全部通过（判据 370 区间不重叠 + 判据 371 窗口 ≥ %d ms）' % MIN_READABLE)
    else:
        print('🔴 %d 处不合格' % fails)
    print('=' * 62)
    return 0 if fails == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
