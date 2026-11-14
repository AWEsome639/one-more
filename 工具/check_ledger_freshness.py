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
ALIAS = {
    'Word Snake': 'GWordSnakeTrail',   # 真类是 GWordSnakeTrail.ets
    'Go (9x9)':   'GGo9',              # 真类是 GGo9.ets
    'Schulte Table': 'GSchulte',        # 真类是 GSchulte.ets
    'Akari (Light Up)': 'GAkari',       # 真类是 GAkari.ets
}

# 不是游戏、只是台账里出现过的测试/异常条目 ⇒ 跳过，别计入新鲜度统计
SKIP = {
    'Nothing',       # NOT_HOME 探针
    '__selftest__',  # 自检
    '__nope__',      # 故意不存在的名字
    'Matcher',       # NO_CARD：某个被截断的名字，不是真游戏
}


def class_name(game):
    """游戏显示名 → .ets 类名。'Matrix Reasoning' → 'GMatrixReasoning'。"""
    if game in ALIAS:
        return ALIAS[game]
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
        if _g in SKIP:
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
