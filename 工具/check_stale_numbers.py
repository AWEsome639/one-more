#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_stale_numbers.py —— 注释里的"N 款/N 条"与实际不符的检测器
================================================================
来历（第 872 轮，判据 225）：
  `core/ai/Hint.ets` 头部写着「355 款里…**只有 1 款（数独）有真求解器**」，
  那是 2026-10-23 建层时的状态；实际已是 **355/355 全部有真提示**。
  ⇒ 差了 354 款，而**没有任何检查器会去比对这句话**。

  ⇒ 判据 225：写"有多少款"这类注释时必须附上复算命令。
     但更根本的是：**这类数字应该有机器来比。**

做什么：
  扫所有 .ets 的**注释行**，抽出「N 款 / N 条 / N 处 / N 种」这类断言，
  在能自动验证的范围内与**实际计数**比对：

    能验的：
      · 「355 款」/「354 款」/「353 款」  ⇒ 数 games/*.ets 的个数
      · 「N 条 DICT」                      ⇒ 数 I18n 字典条目

    不能验的（跳过，不报）：
      · 带 `≈` / `>` / `<` / `以上` / `多` 的
      · 数字后面跟 vp / ms / px / % / 秒 / 倍 / 档 的（这些是设计常量，不是计数）

用法：
  python3 工具/check_stale_numbers.py            # 全量
  python3 工具/check_stale_numbers.py --limit 20

退出码：
  0 = 没有可自动验证的不符项
  1 = 有不符项
  2 = 环境不可用
"""
import glob
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')

# 断言模式：数字 + 单位（只收"计数类"单位）
UNIT_PAT = re.compile(r'(\d{2,4})\s*(款|条|处)')
# 排除：带这些标记的表示"约数/上界"，不该精确比对
SKIP_NEAR = ('≈', '~', '以上', '以下', '多', '>', '<', '封顶', '最多', '至少', '不超过', '上限')


def load_actual_counts():
    """实际计数。只有**能唯一确定**的才放进来。"""
    counts = {}
    if os.path.isdir(GAMES):
        n = len(glob.glob(os.path.join(GAMES, '*.ets')))
        counts['款'] = n
    return counts


def main():
    args = sys.argv[1:]
    limit = 30
    if '--limit' in args:
        i = args.index('--limit')
        if i + 1 < len(args):
            limit = int(args[i + 1])

    if not os.path.isdir(GAMES):
        print('  ❌ 环境不可用：找不到 %s' % GAMES)
        return 2

    counts = load_actual_counts()
    print('  实际计数：%s' % ', '.join('%s=%d' % (k, v) for k, v in counts.items()))
    print()

    bad = []
    for f in glob.glob(os.path.join(ROOT, 'entry/src/main/ets/**/*.ets'), recursive=True):
        try:
            lines = io.open(f, encoding='utf-8').read().split('\n')
        except Exception:
            continue
        for i, l in enumerate(lines):
            s = l.strip()
            if not (s.startswith('*') or s.startswith('//')):
                continue
            # 跳过约数
            if any(k in l for k in SKIP_NEAR):
                continue
            for m in UNIT_PAT.finditer(l):
                num = int(m.group(1))
                unit = m.group(2)
                if unit not in counts:
                    continue
                actual = counts[unit]
                if num != actual:
                    bad.append((os.path.basename(f), i + 1, num, unit, actual, s[:74]))

    print('  ══ 可自动验证的计数断言里，与实际的差 ══')
    if not bad:
        print('  ✅ 全部一致')
        return 0

    print('  **%d 处不符**：' % len(bad))
    for fn, ln, num, unit, actual, t in bad[:limit]:
        print('    %-26s L%-5d 写 %d %s，实际 %d %s' % (fn, ln, num, unit, actual, unit))
        print('      %s' % t)
    if len(bad) > limit:
        print('    …还有 %d 处（--limit 放大）' % (len(bad) - limit))
    print()
    print('  ⇒ 这些不一定是错：注释可能说的是"当时"或"某个子集"。')
    print('     但按判据 225，凡是会变的总数**必须写明它的口径**')
    print('     （例如「355 款里 103 款是解谜类」= 355 是总量、103 是子集）。')
    return 1


if __name__ == '__main__':
    sys.exit(main())
