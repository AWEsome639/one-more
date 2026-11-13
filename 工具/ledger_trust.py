#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ledger_trust.py —— 给巡检台账打「可信度」标签（A 可信 / B 可疑 / C 已知作废）

背景（判据 1989 / 1990）
------------------------
2026-11-13 凌晨，模拟器 `/data/local/tmp` 被 `dumpLayout` 的 JSON 撑到 95%，
`hdc install` **静默失败**（退出码 0、还打 `AppMod finish`，但屏幕上跑的是旧包）。
⇒ 那段时间测出来的 `max_bottom` 全是**旧版的表现**，不能当作「改动前后」的证据。
清盘（09:07）后立刻恢复：`Stroop Test` 从 `1600` 变成 `1570`。

实测的「真正可信起点」
--------------------
`Stroop Test` 的清盘前后序列：
    09:04:41 1600    ← 清盘前，旧包
    09:07:21 1600    ← 刚清盘，包还没重装
    09:09:28 1600    ← 仍是旧包
    09:12:00 1570    ← **新包第一次生效**
⇒ 所以 `TRUST_FROM` 取 **09:12**，比「清盘时刻 09:07」更准确。

三档规则
--------
A 可信：`时间 >= TRUST_FROM` **或** 该行有截图文件真实存在（截图是硬证据）
B 可疑：`时间 < TRUST_FROM` 且无截图（旧包测的，可能不准）
C 已知作废：`-290` 封顶实验那批（改动已回退，测出来的值没有意义）

用法
----
    python3 工具/ledger_trust.py                 # 打印到 stdout
    python3 工具/ledger_trust.py --out a.md      # 另写一份 markdown
    python3 工具/ledger_trust.py --tsv p.tsv     # 指定台账
"""
import argparse
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TSV = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
SHOT_DIR = os.path.join(ROOT, '_巡检记录')

# ── 可调参数（改这里，别改下面的逻辑）─────────────────────────────
TRUST_FROM = '2026-11-13T09:12'      # 见文件头「实测的真正可信起点」
REVERTED_GAMES = {                   # -290 封顶实验批（已回退 ⇒ C）
    'Word Search',
}
GRADE_LABEL = {'A': 'A 可信', 'B': 'B 可疑', 'C': 'C 已知作废', 'X': 'X 无值(失败)'}
SKIP_GAMES = {'Nothing', '__nope__', '__selftest__', ''}   # 不是游戏：占位/探针行
OVERFLOW_PX = 1584                          # 屏高 1600，到这里就算触底

# 一行形如：
# 2026-11-13T02:15:36	Nonogram	OK	1365	102.6s lowest='提示' [2308,1233][2500,1365] -> …/截图-….jpeg @…
RE_LOWEST = re.compile(r"lowest='([^']*)'")
RE_BOUNDS = re.compile(r"\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]")
RE_BLK = re.compile(r'blk=(\d+)/(\d+)px')
RE_MAXN = re.compile(r'max=(\d+)')
RE_SHOT = re.compile(r'(截图-[^/\s]+\.jpeg)')


def parse_rows(path):
    """读台账 → list[dict]。容错：字段不足 / 非 OK / 无值都保留（值置 None）。"""
    rows = []
    with io.open(path, encoding='utf-8', errors='replace') as f:
        for lineno, line in enumerate(f, 1):
            line = line.rstrip('\n')
            if not line.strip():
                continue
            parts = line.split('\t')
            if len(parts) < 5:
                continue
            ts, game, status, value, msg = parts[0], parts[1], parts[2], parts[3], '\t'.join(parts[4:])
            try:
                val = int(value)
            except (TypeError, ValueError):
                val = None
            m = RE_LOWEST.search(msg)
            b = RE_BOUNDS.search(msg)
            s = RE_SHOT.search(msg)
            blk = RE_BLK.search(msg)
            if game in SKIP_GAMES:
                continue
            rows.append({
                'lineno': lineno,
                'ts': ts,
                'game': game,
                'status': status,
                'value': val,
                'lowest': (m.group(1).strip() if m else ''),
                'bounds': ([int(b.group(i)) for i in (1, 2, 3, 4)] if b else None),
                'blk': ((int(blk.group(1)), int(blk.group(2))) if blk else None),
                'maxn': (int(RE_MAXN.search(msg).group(1)) if RE_MAXN.search(msg) else None),
                'shot': (s.group(1) if s else ''),
            })
    return rows


def has_shot(row):
    """截图是否真实存在于 `_巡检记录/`。截图是硬证据（能看到实物）。"""
    name = row['shot']
    if not name:
        return False
    return os.path.isfile(os.path.join(SHOT_DIR, name))


def grade(row):
    """
    三档判定：C > A > B。
    ⚠️ **没有值的行不参与 A/B/C** —— 那是「测量失败」不是「可疑测量」
       （实测：清盘前的失败记录有 80 条，若混进 B 会把「可疑」夸大成 81 条）。
    """
    if row['value'] is None:
        return 'X'
    if row['game'] in REVERTED_GAMES and row['ts'] < TRUST_FROM:
        return 'C'
    if row['ts'] >= TRUST_FROM:
        return 'A'
    if has_shot(row):
        return 'A'
    return 'B'


def annotate(rows):
    for r in rows:
        r['grade'] = grade(r)
    return rows


def latest_by_game(rows):
    """
    每款游戏：
      · latest_trusted —— 最新一条 A 档且 **有值** 的记录（可信值）
      · latest_any     —— 最新一条有值记录（不管档位，仅作参考）
    返回 dict[game] = {...}
    """
    out = {}
    for r in rows:
        g = r['game']
        d = out.setdefault(g, {'latest_trusted': None, 'latest_any': None,
                               'grades': set(), 'n': 0, 'n_over': 0, 'n_val': 0})
        d['grades'].add(r['grade'])
        d['n'] += 1
        if r['value'] is not None:
            d['n_val'] += 1
            if r['value'] >= OVERFLOW_PX:
                d['n_over'] += 1
        if r['value'] is None:
            continue
        if d['latest_any'] is None or r['ts'] > d['latest_any']['ts']:
            d['latest_any'] = r
        if r['grade'] == 'A' and (d['latest_trusted'] is None
                                  or r['ts'] > d['latest_trusted']['ts']):
            d['latest_trusted'] = r
    return out


def fmt_bounds(b):
    if not b:
        return ''
    return '[%d,%d][%d,%d]' % tuple(b)


def build_report(rows, tsv_path):
    """生成 markdown 文本。"""
    per = latest_by_game(rows)
    L = []
    A = [r for r in rows if r['grade'] == 'A']
    B = [r for r in rows if r['grade'] == 'B']
    C = [r for r in rows if r['grade'] == 'C']
    X = [r for r in rows if r['grade'] == 'X']
    ok = [r for r in rows if r['value'] is not None]

    L.append('# 可信台账（按判据 1989 / 1990 重新标注）')
    L.append('')
    import datetime
    L.append('> 自动生成：`工具/ledger_trust.py` ｜ 数据源：`%s`（%d 行快照）'
             % (os.path.basename(tsv_path), len(rows)))
    L.append('> 生成时间：`%s`（台账仍在增长，重跑即可刷新）'
             % datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'))
    L.append('> **A 可信** ＝ 时间 ≥ `%s` **或** 有截图实物；'
             '**B 可疑** ＝ 清盘前且无截图；**C 已知作废** ＝ `-290` 回退批。'
             % TRUST_FROM)
    L.append('')
    L.append('## 为什么可信起点是 `%s` 而不是清盘时刻 `09:07`' % TRUST_FROM)
    L.append('')
    L.append('`Stroop Test` 的清盘前后实测序列：')
    L.append('')
    L.append('| 时间 | max_bottom | 说明 |')
    L.append('|---|---:|---|')
    L.append('| 09:04:41 | 1600 | 清盘前，旧包 |')
    L.append('| 09:07:21 | 1600 | 刚清盘，包还没重装 |')
    L.append('| 09:09:28 | 1600 | **仍是旧包** |')
    L.append('| 09:12:00 | **1570** | **新包第一次生效** |')
    L.append('')
    L.append('**⇒ 09:05~09:11 之间的记录仍是旧包测得**，若按「清盘时刻」判定会把它们误标成 A。')
    L.append('')
    L.append('## 每款最新可信值（按档位 + 数值降序）')
    L.append('')
    L.append('| 游戏 | 最新可信值 | 最新时间 | 档位 | 备注 |')
    L.append('|---|---:|---|---|---|')

    lines = []
    for g, d in per.items():
        lt = d['latest_trusted']
        la = d['latest_any']
        if lt is not None:
            val, ts, grade_ = lt['value'], lt['ts'], 'A 可信'
            note = ''
            if la is not None and la['ts'] > lt['ts']:
                note = '最新一条是 B/C 档（%s = %s）' % (la['ts'][11:19], la['value'])
        elif la is not None:
            val, ts, grade_ = la['value'], la['ts'], GRADE_LABEL.get(la['grade'], la['grade'])
            note = '无 A 档记录，回落到%s' % GRADE_LABEL.get(la['grade'], la['grade'])
        else:
            val, ts, grade_, note = None, '', '无有效值', ''
        lines.append((0 if lt is not None else 1, -(val if val is not None else -10 ** 9),
                      g, val, ts, grade_, note))

    lines.sort()
    for _, __, g, val, ts, grade_, note in lines:
        L.append('| %s | %s | %s | %s | %s |'
                 % (g,
                    ('**%d**' % val) if val is not None else '—',
                    ts.replace('T', ' ')[11:19] if ts else '—',
                    grade_,
                    note or ('%d 次测量' % per[g]['n'])))

    L.append('')
    L.append('## 统计')
    L.append('')
    games_a = {r['game'] for r in A}
    games_b = {r['game'] for r in B}
    games_c = {r['game'] for r in C}
    L.append('```')
    L.append('总记录 %d 条 / 涉及 %d 款游戏（其中有值 %d 条）' % (len(rows), len(per), len(ok)))
    L.append('A 可信    : %4d 条 / %3d 款' % (len(A), len(games_a)))
    L.append('B 可疑    : %4d 条 / %3d 款' % (len(B), len(games_b)))
    L.append('C 已知作废: %4d 条 / %3d 款' % (len(C), len(games_c)))
    L.append('X 无值失败: %4d 条 / %3d 款  ← **不计入 A/B/C**（没有测量值，谈不上可信）'
             % (len(X), len({r['game'] for r in X})))
    L.append('```')
    L.append('')
    L.append('> ⚠️ 修正一个容易踩的口径：清盘前的记录里 **%d 条是「测量失败」（没有值）**，'
             % len(X))
    L.append('> 若把它们算进 `B 可疑`，会得出「%d 条可疑」的夸张数字 —— '
             '实际**只有 %d 条**是有值的可疑测量。' % (len(B) + len(X), len(B)))
    # 口径闭合：清盘前的有值记录，要么有截图→A，要么属回退批→C
    pre_val = [r for r in rows if r['value'] is not None and r['ts'] < TRUST_FROM]
    pre_A = [r for r in pre_val if r['grade'] == 'A']
    n_close = len(pre_val) - len(pre_A)
    L.append('')
    L.append('### 口径闭合（证明 B=0 不是漏算）')
    L.append('')
    L.append('```')
    L.append('清盘前的有值记录            : %d 条' % len(pre_val))
    L.append('  其中有截图（→ A 可信）    : %d 条' % len(pre_A))
    L.append('  其中属 -290 回退批（→ C）: %d 条' % n_close)
    L.append('  ------------------------------ ')
    L.append('  合计                      : %d 条%s'
             % (len(pre_A) + n_close,
                '  ✅ 闭合' if len(pre_A) + n_close == len(pre_val) else '  ⚠️ 不闭合'))
    L.append('```')
    L.append('')
    # 最差的 5 款（可信值最大的 = 越靠屏幕底部 = 越可能溢出）
    cand = [t for t in lines if t[0] == 0 and t[3] is not None]
    cand.sort(key=lambda t: (-t[3], -per[t[2]]['n_over'], -per[t[2]]['n_val'], t[2]))
    worst = cand[:5]
    L.append('### 可信数据里最差的 5 款（数值最大 ⇒ 最靠屏底）')
    L.append('')
    L.append('| # | 游戏 | max_bottom | 触底次数 | 有值次数 | 最新时间 |')
    L.append('|---|---|---:|---:|---:|---|')
    for i, t in enumerate(worst, 1):
        d = per[t[2]]
        L.append('| %d | %s | %d | %d | %d | %s |'
                 % (i, t[2], t[3], d['n_over'], d['n_val'], (t[4] or '')[11:19]))
    L.append('')
    L.append('> 屏高 `1600px`；游戏区预算 `343vp = 1029px`（起点约 `381px`）。')
    L.append('> `max_bottom >= 1584` 表示触到/越过屏底 = 溢出。')
    L.append('')
    return '\n'.join(L)


def main(argv=None):
    ap = argparse.ArgumentParser(description='给巡检台账打可信度标签（A/B/C）')
    ap.add_argument('--tsv', default=DEFAULT_TSV, help='台账路径')
    ap.add_argument('--out', default='', help='另存 markdown 到该路径')
    args = ap.parse_args(argv)

    if not os.path.isfile(args.tsv):
        sys.stderr.write('台账不存在: %s\n' % args.tsv)
        return 2

    rows = annotate(parse_rows(args.tsv))
    md = build_report(rows, args.tsv)
    print(md)
    if args.out:
        with io.open(args.out, 'w', encoding='utf-8') as f:
            f.write(md + '\n')
        sys.stderr.write('已写入 %s\n' % args.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
