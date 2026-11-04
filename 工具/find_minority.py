#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""find_minority.py —— 找「N-1 款有、1~3 款没有」的不一致（判据 821）

★ 为什么需要（第 1315 轮，来自 1314 轮修 GPegSolitaire 的经验）
  1314 轮发现：`setTimeout(… demoStart(), 3000)` 在 **354/355** 款里一模一样，
  只有 `GPegSolitaire` 是 0 ⇒ 那不是「特例设计」，是**漏写**。
  ⇒ 把这条经验工具化：**统计每个 marker 的覆盖率，少数派就是待查项**

★ 判据 821 的机械化
  · 多数派 = 基线（不需要解释）
  · 少数派 = **必须逐个解释**（是特例，还是遗漏？）

用法:
  python3 工具/find_minority.py            # 默认阈值：1~3 款缺
  python3 工具/find_minority.py --max 5    # 允许 1~5 款缺
退出码：0 = 无少数派 ｜ 1 = 有少数派待查 ｜ 2 = 输入问题
"""
import io
import os
import re
import sys

GAMES = 'entry/src/main/ets/games'

# 应当「几乎每款都有」的 marker（缺席 = 可疑）
MARKERS = [
    ('LanRace.noteStart', r'LanRace\.noteStart'),
    ('onRestart', r'\bonRestart\s*\('),
    ('DemoBar(', r'DemoBar\s*\('),
    ('demoOn:', r'demoOn\s*:'),
    ('demoOnce', r'demoOnce'),
    ('private demoStart', r'private\s+demoStart\s*\('),
    ('private demoBeat', r'private\s+demoBeat\s*\('),
    ('Hint.autoRun', r'Hint\.autoRun'),
    ('private autoStep', r'private\s+autoStep\s*\('),
    ('Tv.on()', r'Tv\.on\s*\(\s*\)'),
    ('focusOutline', r'focusOutline'),
    ('Haptics.', r'Haptics\.'),
    ('Space.', r'\bSpace\.'),
    ('FontSize.', r'\bFontSize\.'),
]


def strip_comments(src):
    out = []
    in_block = False
    for line in src.split('\n'):
        buf = []
        i = 0
        while i < len(line):
            if in_block:
                if line.startswith('*/', i):
                    buf.append('  ')
                    i += 2
                    in_block = False
                else:
                    buf.append(' ')
                    i += 1
            else:
                if line.startswith('//', i):
                    buf.append(' ' * (len(line) - i))
                    break
                elif line.startswith('/*', i):
                    buf.append('  ')
                    i += 2
                    in_block = True
                else:
                    buf.append(line[i])
                    i += 1
        out.append(''.join(buf))
    return '\n'.join(out)


def main():
    max_missing = 3
    for i, a in enumerate(sys.argv):
        if a == '--max' and i + 1 < len(sys.argv):
            max_missing = int(sys.argv[i + 1])

    if not os.path.isdir(GAMES):
        print('目录不存在: %s' % GAMES)
        return 2

    files = sorted(f for f in os.listdir(GAMES) if f.endswith('.ets'))
    total = len(files)
    srcs = {}
    for f in files:
        srcs[f] = strip_comments(io.open(os.path.join(GAMES, f),
                                        encoding='utf-8', errors='ignore').read())

    print('=' * 74)
    print('  少数派审计（判据 821）：共 %d 款' % total)
    print('  规则：marker 覆盖率 ≥ %d 款，而有 1~%d 款缺 ⇒ 列为待查' % (total - max_missing, max_missing))
    print('=' * 74)
    print()

    suspects = 0
    for name, pat in MARKERS:
        have = []
        miss = []
        for f in files:
            (have if re.search(pat, srcs[f]) else miss).append(f)
        cov = len(have)
        status = ''
        if 0 < len(miss) <= max_missing and cov >= total - max_missing:
            status = '⚠️ **少数派待查**'
            suspects += 1
        elif len(miss) == 0:
            status = '✅ 全覆盖'
        elif cov == 0:
            status = '⚪ 无人用（可能已废弃）'
        else:
            status = '（%d 款缺，属正常分组）' % len(miss)
        print('  %-22s 有 %3d / %d  %s' % (name, cov, total, status))
        if status.startswith('⚠️'):
            for m in sorted(miss):
                print('      → %s' % m)

    print()
    print('=' * 74)
    if suspects:
        print('  ⚠️ **%d 个 marker 出现少数派**' % suspects)
        print('  ⇒ 逐个解释：是「特例设计」还是「漏写」？（判据 821）')
        return 1
    print('  ✅ 未发现「少数派」不一致')
    return 0


if __name__ == '__main__':
    sys.exit(main())
