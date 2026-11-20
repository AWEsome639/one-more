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
import os, subprocess, sys, io, datetime, re
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# ★ 2026-11-20（判据 3074）：**默认仍是横屏台账，但可以用 `--nonshort` 切到竖屏台账**。
#   起因：这个工具原来只读横屏台账，而**竖屏台账 `layout-nonshort.tsv` 完全不受监控** ——
#   实测它有 `456` 条 OK、其中 `409` 条来自 `11-16`（两三天前）。
#   我差点拿它做「预测器在竖屏是否成立」的验证，而那批数据早被修过、全都过时。
LEDGER = os.path.join(ROOT, '_巡检记录',
                      'layout-nonshort.tsv' if '--nonshort' in sys.argv
                      else 'layout-canonical.tsv')
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
    # ★ 2026-11-19（判据 3002）：**台账里有一条名字被截断的历史脏数据** ——
    #   第 1265 行是 `odular Clock Arithmetic`（少了首字母 `M`，11-16 12:38 TIMEOUT），
    #   来自当时 `--names-file` 里被切坏的一行。真名 `Modular Clock Arithmetic` 另有正常记录。
    #   不映射的话，报告永远显示「1 款类名映射失败」，会让人以为工具坏了。
    #   ⇒ 映射到同一个 .ets，让它参与新鲜度统计（而不是被当成不存在）。
    'odular_clock_arithmetic': 'GModularClockArithmetic',
}


_gt_cache = {}
def _git_time(path):
    """文件最后一次 git 提交时间；没有提交记录时退回 mtime（新文件/未跟踪）。"""
    if path in _gt_cache:
        return _gt_cache[path]
    try:
        out = subprocess.run(['git', 'log', '-1', '--format=%ct', '--', path],
                             capture_output=True, text=True, timeout=15).stdout.strip()
        m = datetime.datetime.fromtimestamp(int(out)) if out else None
    except Exception:
        m = None
    if m is None:
        m = datetime.datetime.fromtimestamp(os.path.getmtime(path))
    _gt_cache[path] = m
    return m


def class_name(game):
    """游戏显示名 → .ets 类名。'Matrix Reasoning' → 'GMatrixReasoning'。"""
    cid = _canon(game)
    if cid in CLASS_OVERRIDE:
        return CLASS_OVERRIDE[cid]
    return 'G' + re.sub(r'[^0-9A-Za-z\u4e00-\u9fff]', '', game)


def parse_ledger():
    """返回 OrderedDict: game -> (last_ts, last_line_no, status)

    ★ 2026-11-20（判据 3074）：**同时记下整份台账的时间跨度** —— 只看「多少款有效」
      会掩盖「数据其实是三天前的」这件事。今天我就差点被它误导。
    """
    last = OrderedDict()
    global OLDEST, NEWEST, N_ROWS
    OLDEST = NEWEST = None
    N_ROWS = 0
    # ★ 2026-11-20（判据 3074）：`layout-nonshort.tsv` **不是纯 UTF-8**（含 0xe9 孤立字节）
    #   ⇒ 必须 `errors='replace'`，否则 `--nonshort` 直接抛 UnicodeDecodeError。
    with io.open(LEDGER, encoding='utf-8', errors='replace') as f:
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
            N_ROWS += 1
            if OLDEST is None or t < OLDEST: OLDEST = t
            if NEWEST is None or t > NEWEST: NEWEST = t
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
        # ★ 2026-11-19（判据 3015）：**用 git 最后一次提交时间，不用 mtime**。
        #   实测 `302 / 355` 款文件的 mtime 与 git 提交时间差 >10 分钟 ——
        #   mtime 会被 checkout / stash / 批量脚本无内容变化地改掉。
        #   判例：`GOddRotation.ets` mtime=`11-19 00:12`（假的），
        #         git 最后提交=`11-13 01:49`（真的）⇒ 工具误报它「过期 31h」。
        #   ⇒ 「代码改过没有」是**内容**问题，只有 git 能回答。
        code_m = _git_time(p)
        delta = (code_m - t).total_seconds()
        rows.append((game, t, code_m, delta, status))

    stale = [r for r in rows if r[3] > 0]
    fresh = [r for r in rows if r[3] <= 0]
    stale.sort(key=lambda r: -r[3])

    # ★ 2026-11-20（判据 3074）：**先把「这份台账是哪份、数据有多旧」打在最前面**。
    #   只报「多少款有效」会掩盖「数据是三天前的」—— 今天我差点拿竖屏旧数据做验证。
    _name = os.path.basename(LEDGER)
    _span = ''
    if OLDEST is not None and NEWEST is not None:
        _days = (NEWEST - OLDEST).days
        _span = '｜记录 %d 条 · %s → %s（跨 %d 天）' % (
            N_ROWS, OLDEST.strftime('%m-%d %H:%M'), NEWEST.strftime('%m-%d %H:%M'), _days)
        _warn = ''
        if _days >= 2:
            _warn = ('\n   ⚠️ **这份台账跨 %d 天**：靠前的记录可能已被之后的改动作废（判据 2613）'
                     '\n      拿它做「某特征能否预测缺陷」这类统计前，先确认数据新鲜度' % _days)
        else:
            _warn = ''
    print('== 台账新鲜度：%d 款有测量记录 ==' % len(rows))
    print('   📄 %s%s%s' % (_name, _span, _warn))
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
