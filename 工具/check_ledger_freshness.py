#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_ledger_freshness.py —— 台账里的测量值是否**早于代码改动**

判据 2570：**数据有效性是第 0 步。** 台账里某款的值若是「改代码之前」量出来的，
那它描述的是旧代码 ⇒ 拿它推方案会推错（今天 `Kakuro Mini` 就栽在这里：
台账 `00:22` 的 `blk=24px` 早于 `07:06` 改成 `-360`，而 `-360` 从未被量过）。

做什么：对每个在台账里出现过的游戏，取**最后一次**测量时间，
与 `entry/src/main/ets/games/<类名>.ets` 的 mtime 比较：
  · 代码改了、但之后没再量过 ⇒ **过期（STALE）**
  · 量过之后代码没动 ⇒ 有效
输出：过期清单（按「代码改动距今天数」降序），以及统计。

用法：
  python3 工具/check_ledger_freshness.py            # 全部
  python3 工具/check_ledger_freshness.py --top 20   # 只看最该重测的 20 款
  python3 工具/check_ledger_freshness.py --stale-only
退出码恒为 0（这是报告器，不是闸门）。
"""
import os, sys, io, datetime, re
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
GAMES = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games')


# 台账里出现、但与「显示名 → G<名>.ets」规则对不上的真游戏。
# 来历：首次跑工具时报「找不到 .ets」的 8 款里，只有这几个是真游戏。
# ★ 2026-11-19（判据 2964）：别名与垃圾名单**统一到 `工具/ledger_names.py`**。
#   本文件原来自己维护 ALIAS(4 条)/SKIP(4 条)，但缺 N-Back / Go / No-Go /
#   Tic-Tac-Toe / 2048 这几个 ⇒ 与别的工具口径不一致。现在共用一份。
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ledger_names import canon as _canon, is_junk as _is_junk

# 台账展示名 → .ets 类名（只补 与 canon 不同的那几个；
# canon 给的是注册表 id 风格如 g2048/akari，这里要类名风格 G2048/GAkari）
CLASS_OVERRIDE = {
    'g2048': 'G2048', 'akari': 'GAkari', 'go9': 'GGo9',
    'schulte': 'GSchulte', 'word_snake_trail': 'GWordSnakeTrail',
    'tic_tac_toe': 'GTicTacToe', 'n_back': 'GNBack', 'go_no_go': 'GGoNoGo',
}


def class_name(game):
    """游戏显示名 → .ets 类名。'Matrix Reasoning' → 'GMatrixReasoning'。"""
    cid = _canon(game)
    if cid in CLASS_OVERRIDE:
        return CLASS_OVERRIDE[cid]
    return 'G' + re.sub(r'[^0-9A-Za-z\u4e00-\u9fff]', '', game)


def parse_ledger():
    """返回 OrderedDict: game -> (last_ts, last_line_no, status)"""
    last = OrderedDict()
    with io.open(LEDGER, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            parts = line.rstrip('\n').split('\t')
            if len(parts) < 3:
                continue
            ts, game, status = parts[0], parts[1], parts[2]
            try:
                t = datetime.datetime.strptime(ts, '%Y-%m-%dT%H:%M:%S')
            except ValueError:
                continue
            last[game] = (t, n, status)     # 后者覆盖前者 ⇒ 天然取最后一次
    return last


def main():
    top = None
    stale_only = '--stale-only' in sys.argv
    for a in sys.argv[1:]:
        if a.startswith('--top'):
            top = int(a.split('=')[1]) if '=' in a else 20

    last = parse_ledger()
    for _g in list(last.keys()):
        if _is_junk(_g):
            del last[_g]
    rows = []
    no_file = []
    for game, (t, n, status) in last.items():
        p = os.path.join(GAMES, class_name(game) + '.ets')
        if not os.path.exists(p):
            no_file.append(game)
            continue
        code_m = datetime.datetime.fromtimestamp(os.path.getmtime(p))
        delta = (code_m - t).total_seconds()
        rows.append((game, t, code_m, delta, status))

    stale = [r for r in rows if r[3] > 0]
    fresh = [r for r in rows if r[3] <= 0]
    stale.sort(key=lambda r: -r[3])

    print('== 台账新鲜度：%d 款有测量记录 ==' % len(rows))
    print('   ✅ 有效（量过之后代码没动）：%d 款' % len(fresh))
    print('   ⚠️ 过期（代码改了、之后没再量）：%d 款' % len(stale))
    if no_file:
        print('   ❓ 找不到 .ets（类名映射失败）：%d 款 —— %s' % (len(no_file), ', '.join(no_file[:6])))
    print()
    if stale and not stale_only:
        show = stale[:top] if top else stale
        print('-- 过期清单（按代码改动距测量的小时数降序；这些款的值不要用来推方案）--')
        for game, t, code_m, delta, status in show:
            print('  %-24s 量于 %s ｜ 代码改于 %s ｜ 滞后 %.0f h ｜ 末次 %s'
                  % (game, t.strftime('%m-%d %H:%M'), code_m.strftime('%m-%d %H:%M'),
                     delta / 3600.0, status))
        if top and len(stale) > top:
            print('  …还有 %d 款（--top 放大）' % (len(stale) - top))
        print()
    print('⇒ 明天动任何一款之前，先看它在不在上面这份清单里；在的话先量、再改。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
