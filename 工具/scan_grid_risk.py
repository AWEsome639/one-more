#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""scan_grid_risk.py —— 扫「纵向堆叠正方形单元 + 宽度按整屏算」这一类布局风险

背景（判据 3098）：一晚修了四款同一类缺陷 ——
  `Simon Command`(3089) / `Simon Says`(3097) / `Odd Rotation`(3098) / `Silhouette Match`(3084)
  它们的共同写法是：
      Column { ForEach(行) { Row { ForEach(列) { Stack().layoutWeight(1).aspectRatio(1) } } } }
      .width('100%')                     ← 宽度按整屏算
  而 .aspectRatio(1) 让每块都是正方形 ⇒ **几行就占几倍行宽的高度** ⇒ 小屏竖屏必然装不下。

这个工具只做「筛」，不做「算」——每款的 chrome 不同，常数要逐款实测（见判据 3098）。

用法：
  python3 工具/scan_grid_risk.py            # 全库扫描 + 交叉台账
  python3 工具/scan_grid_risk.py --risky    # 只列有风险且未做宽度限高的
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')
LEDGER = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
REGISTRY = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'core', 'GameRegistry.ets')

AR1 = re.compile(r'\.aspectRatio\(\s*1\s*\)')
HEIGHT_CAP = re.compile(r'(?:\.width|\.constraintSize)\([^\n]{0,120}Bp\.height')


def load_measured():
    """返回 {'land': set(enName), 'port': set(enName)}"""
    land, port = set(), set()
    if not os.path.exists(LEDGER):
        return {'land': land, 'port': port}
    for line in io.open(LEDGER, encoding='utf-8', errors='replace'):
        p = line.rstrip('\n').split('\t')
        if len(p) < 3:
            continue
        m = re.search(r'scr=(\d+)x(\d+)', line)
        if not m:
            continue
        w, h = int(m.group(1)), int(m.group(2))
        (port if h > w else land).add(p[1])
    return {'land': land, 'port': port}


def load_registry():
    """组件名 → enName（靠 id 中转）"""
    if not os.path.exists(REGISTRY):
        return {}
    s = io.open(REGISTRY, encoding='utf-8', errors='replace').read()
    id2en = {m.group(1): m.group(3)
             for m in re.finditer(r"\{ id: '([^']+)', name: '([^']+)'.*?enName: '([^']+)'", s)}
    gh_path = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'pages', 'GameHost.ets')
    comp2en, last = {}, None
    if os.path.exists(gh_path):
        gh = io.open(gh_path, encoding='utf-8', errors='replace').read()
        for m in re.finditer(r"this\.gameId === '([^']+)'|G([A-Za-z0-9]+)\(\{", gh):
            if m.group(1):
                last = m.group(1)
            elif m.group(2) and last:
                comp2en.setdefault('G' + m.group(2), id2en.get(last, ''))
    return comp2en


def scan():
    comp2en = load_registry()
    measured = load_measured()
    rows = []
    for name in sorted(os.listdir(GAMES)):
        if not name.endswith('.ets'):
            continue
        path = os.path.join(GAMES, name)
        s = io.open(path, encoding='utf-8', errors='replace').read()
        ar = len(AR1.findall(s))
        if ar < 2:
            continue
        rows_total = len(re.findall(r'ForEach\(\s*(?:\[0,\s*1,\s*2\]|ROWS)', s))
        capped = bool(HEIGHT_CAP.search(s))
        comp = name[:-4]
        en = comp2en.get(comp, '')
        rows.append({
            'comp': comp, 'en': en, 'ar': ar, 'rows': rows_total, 'capped': capped,
            'port': (en in measured['port']) if en else False,
            'land': (en in measured['land']) if en else False,
        })
    return rows


def main():
    only_risky = '--risky' in sys.argv
    rows = scan()
    risky = [r for r in rows if not r['capped']]
    if only_risky:
        rows = risky

    print('== 纵向正方形网格扫描（共 %d 款有 ≥2 个 aspectRatio(1)）==' % len(rows))
    print('   其中【未做宽度限高】= 结构风险: %d 款' % len(risky))
    print()
    print('  %-30s %-26s AR 行 限高 竖屏测过' % ('组件', '游戏(enName)'))
    for r in sorted(rows, key=lambda x: (x['capped'], x['port'], -x['ar'])):
        warn = '  ' if r['capped'] else '⚠️'
        print('%s %-30s %-26s %2d %2d %-4s %s' % (
            warn, r['comp'], r['en'][:26] or '?', r['ar'], r['rows'],
            '是' if r['capped'] else '否', '是' if r['port'] else '**否**'))
    print()
    never = [r for r in risky if not r['port']]
    print('== ⚠️ 未限高 且 竖屏从未测过（最该先测）: %d 款 ==' % len(never))
    for r in never:
        print('   %-30s %s' % (r['comp'], r['en']))
    return 0


if __name__ == '__main__':
    sys.exit(main())

# ── 已知局限（诚实标注，别当权威）────────────────────────────
# 1. 「行」那一列只用 `ForEach([0,1,2]` / `ForEach(ROWS` 计数，
#    很多网格用的是 `ForEach(this.opts)` 之类 ⇒ 该列经常是 0，**不要用它判断行数**。
# 2. 「限高」判据只看 `width`/`constraintSize` 里有没有 `Bp.height`；
#    如果有游戏用别的写法限高（例如算出常量再传），会被误判成风险。
# 3. 这个工具**只筛不算** —— 每款的 chrome 不同，常数必须逐款实测（判据 3098）。
#    `⚠️` 只是「值得看一眼」，不是「有缺陷」（判据 3088 的同构教训）。
