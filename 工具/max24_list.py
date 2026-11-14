#!/usr/bin/env python3
"""列出「有块贴屏底」（max=24）的游戏，按 lowest.y2 距屏底的距离排序。

为什么这个信号可信（判据 2487）：
  台账的 blk 用 GAME_BOTTOM=1516 + SLACK=60 = 1576 做基线，
  over = y2 - 1576、max = max(over)。
  ⇒ max=24 意味着最深块的 y2 = 1576+24 = 1600 = 屏幕最下沿。
  ⇒ 「棋盘被裁」必然留下一个贴屏底的块 ⇒ max=24 是这种情况的**必要条件**。
  ⇒ 所以这 33 款要逐一核；max=0 的（无块贴底）大概率安全。

⚠️ 已核结论（2026-11-14）：
  com 不可玩：Pattern Sequence Draw / Path Intersect / Pipes / Norinori
  功能级：Magnets / Kakuro Mini / Fraction Matcher
  警告：Modulo Path（提示压棋盘）/ Kakuro（键盘行边界）
  正常：Binary Matrix Rank
"""
import io, re, sys

TSV = '_巡检记录/layout-canonical.tsv'
DONE = {  # 已核过的款 → 结论（避免重复看）
    'Pattern Sequence Draw': '❌ 不可玩（第三行 7 8 9 被裁）',
    'Path Intersect':        '❌ 不可玩（棋盘只露 1.5 行）',
    'Pipes':                 '❌ 不可玩（只露 2 行，应有 5+ 行）',
    'Norinori':              '❌ 不可玩（只露 2 行）',
    'Magnets':               '功能级（线索格被切）',
    'Kakuro Mini':           '功能级（键盘行被切）',
    'Fraction Matcher':      '功能级（选项被切）',
    'Modulo Path':           '⚠️ 提示压棋盘（可玩、要修）',
    'Kakuro':                '⚠️ 键盘行边界（可玩）',
    'Binary Matrix Rank':    '✅ 正常（但只差 32px）',
    'Percentage Shopping':   '待今晚数据（可能已修好）',
    'Wordle':                '待今晚数据',
    'Block Count 3D':        '待今晚数据',
    'Pythagorean Triple Builder': '✅ 确认不改（键露 67%）',
}

rows = {}
for ln in io.open(TSV, encoding='utf-8'):
    c = ln.rstrip('\n').split('\t')
    if len(c) > 4 and c[2] in ('OK', 'TIGHT', 'OVER', 'NEAR'):
        rows[c[1]] = (c[0][:16], c[4])

hit = []
for g, (t, ex) in rows.items():
    m = re.search(r'blk=(\d+)/(\d+)px.*max=(\d+)', ex)
    ly = re.search(r"lowest='[^']*'\s*\[-?\d+,-?\d+\]\[-?\d+,(-?\d+)\]", ex)
    if not m or int(m.group(3)) != 24:
        continue
    y2 = int(ly.group(1)) if ly else -1
    hit.append((1600 - y2 if y2 >= 0 else 9999, g, y2, t))

hit.sort()
unchecked = [h for h in hit if h[1] not in DONE]
print('max=24 共 %d 款；已核 %d；**未核 %d**' % (len(hit), len(hit) - len(unchecked), len(unchecked)))
print()
print('=== 未核（按 lowest.y2 距屏底升序 ⇒ 越靠前越可能被裁）===')
for mg, g, y2, t in unchecked:
    print('  余量 %3s  %-28s y2=%4d  测于 %s' % (mg if mg < 9999 else '?', g, y2, t[5:]))
if '--all' in sys.argv:
    print()
    print('=== 全部 %d 款（含已核结论）===' % len(hit))
    for mg, g, y2, t in hit:
        print('  余量 %3s  %-28s %s' % (mg if mg < 9999 else '?', g, DONE.get(g, '（未核）')))
