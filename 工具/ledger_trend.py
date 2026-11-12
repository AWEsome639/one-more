#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""台账趋势分析：`layout-canonical.tsv` 里每款游戏的全部历史测量 + 「同节点」判定。

★ 判据 1973：`max_bottom` 变大 ≠ 变差 —— 可能只是「最低节点换人」。
  比较两次 `max_bottom` 前**必须先看 `lowest` 是不是同一个节点**；
  若新的 `lowest` 是**原本看不见的内容**（内容文字，而不是纯数字读数）⇒ 那是**改善**。

输入格式（`_巡检记录/layout-canonical.tsv`，无表头，5 列）：
    时间戳 \t 游戏名 \t 状态 \t max_bottom(-) \t "耗时 lowest='...' -> 截图路径 @时间"

用法：
    python3 工具/ledger_trend.py                       # 默认读 _巡检记录/layout-canonical.tsv
    python3 工具/ledger_trend.py --tsv <路径> --markdown
    python3 工具/ledger_trend.py --history             # 额外打印每款的全部测量
    python3 工具/ledger_trend.py --self-test           # 自检（含判据 1973 的两个实例）

退出码：0 正常 ｜ 2 输入/参数问题 ｜ 3 自检失败

⚠️ 只读：本脚本**不写任何文件**（要落盘请自己重定向或复制输出）。
"""
import argparse
import io
import os
import re
import sys

DEFAULT_TSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '_巡检记录', 'layout-canonical.tsv')

LOWEST_RE = re.compile(r"lowest='([^']*)'")
# 纯数字/读数：只有数字 + 常见分隔符（8/21、0/40、121、1,234、3.5、12s 之外都交给"数值化"判断）
NUMERIC_RE = re.compile(r"^[\s\d.,/:;%+\-×x()（）]*$")

VERDICT_IMPROVED = '真改善'
VERDICT_MAYBE = '可能改善（内容进屏了）'
VERDICT_CHECK = '待人工确认'
VERDICT_WORSE = '变差'
VERDICT_SAME = '无变化'


# ────────────────────────────────────────────────────────────────────────────
#  解析
# ────────────────────────────────────────────────────────────────────────────
class Row:
    """一次测量。`mb` 只有 OK 行才有值（其余状态是 '-'）"""

    __slots__ = ('ts', 'game', 'status', 'mb', 'elapsed', 'lowest', 'raw')

    def __init__(self, ts, game, status, mb, elapsed, lowest, raw):
        self.ts = ts
        self.game = game
        self.status = status
        self.mb = mb
        self.elapsed = elapsed
        self.lowest = lowest
        self.raw = raw

    def __repr__(self):
        return 'Row(%s, %s, %s, %s, lowest=%r)' % (self.ts, self.game, self.status, self.mb, self.lowest)


def parse_line(line):
    """一行 → Row；格式不对返回 None（不抛异常，台账是生产数据）"""
    line = line.rstrip('\n')
    if not line.strip():
        return None
    f = line.split('\t')
    if len(f) < 5:
        return None
    ts, game, status, mb_raw = f[0], f[1], f[2], f[3]
    remark = '\t'.join(f[4:])
    mb = None
    if mb_raw.strip().isdigit():
        mb = int(mb_raw.strip())
    m = LOWEST_RE.search(remark)
    lowest = m.group(1) if m else None
    e = re.match(r'\s*([0-9.]+)s', remark)
    elapsed = e.group(1) if e else None
    return Row(ts, game, status, mb, elapsed, lowest, line)


def parse_tsv(path):
    rows = []
    bad = 0
    with io.open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            r = parse_line(line)
            if r is None:
                if line.strip():
                    bad += 1
                continue
            rows.append(r)
    return rows, bad


# ────────────────────────────────────────────────────────────────────────────
#  判定
# ────────────────────────────────────────────────────────────────────────────
def is_content_lowest(s):
    """`lowest` 是不是「内容文字」（而不是纯数字读数）。

    ★ 判据 1973 的关键：数字读数（`121` / `8/21` / `0/40`）只是统计数字，
      而内容文字（`选出移位后的十进制值` / `提示` / `B`）意味着**本来被裁掉的内容进屏了**。
    """
    if s is None:
        return False
    t = s.strip()
    if not t:
        return False
    return not NUMERIC_RE.match(t)


def verdict(prev, cur):
    """相邻两次测量 → (是否同节点, 趋势判定, 依据说明)。prev/cur 都是 Row（mb 非 None）。"""
    same = (prev.lowest or '') == (cur.lowest or '')
    delta = cur.mb - prev.mb
    if same:
        if delta < 0:
            return True, VERDICT_IMPROVED, '同节点，max_bottom %d → %d（-%d）' % (prev.mb, cur.mb, -delta)
        if delta > 0:
            return True, VERDICT_WORSE, '同节点，max_bottom %d → %d（+%d）' % (prev.mb, cur.mb, delta)
        return True, VERDICT_SAME, '同节点，max_bottom 没变（%d）' % cur.mb
    # 节点变了 —— 先把两种「变大」的语境分开（判据 1973 的核心）
    content = is_content_lowest(cur.lowest)
    if content:
        return False, VERDICT_MAYBE, '换节点 %r → %r（新的是内容文字），max_bottom %d → %d' % (
            prev.lowest, cur.lowest, prev.mb, cur.mb)
    if delta > 0:
        return False, VERDICT_CHECK, '换节点 %r → %r（新的仍是数字读数），max_bottom %d → %d（+%d）' % (
            prev.lowest, cur.lowest, prev.mb, cur.mb, delta)
    if delta < 0:
        return False, VERDICT_CHECK, '换节点 %r → %r，max_bottom %d → %d（-%d，仍要确认新节点是谁）' % (
            prev.lowest, cur.lowest, prev.mb, cur.mb, -delta)
    return False, VERDICT_CHECK, '换节点 %r → %r，max_bottom 没变（%d）' % (prev.lowest, cur.lowest, cur.mb)


# ────────────────────────────────────────────────────────────────────────────
#  汇总
# ────────────────────────────────────────────────────────────────────────────
def analyze(rows):
    """按游戏分组 → 每款的最新一次 + 与上一次 OK 的对比。返回 dict 列表（按游戏名排序）。"""
    by_game = {}
    for r in rows:
        by_game.setdefault(r.game, []).append(r)
    out = []
    for game in sorted(by_game):
        hist = sorted(by_game[game], key=lambda r: r.ts)
        oks = [r for r in hist if r.mb is not None]
        item = {'game': game, 'total': len(hist), 'ok': len(oks),
                'latest': oks[-1] if oks else None,
                'prev': oks[-2] if len(oks) >= 2 else None,
                'history': hist}
        if item['latest'] and item['prev']:
            item['same'], item['verdict'], item['why'] = verdict(item['prev'], item['latest'])
        else:
            item['same'] = None
            item['verdict'] = '样本不足'
            item['why'] = ('只有 1 次有效测量' if oks else '没有有效测量（全是 NOT_HOME/DUMP_FAIL 等）')
        out.append(item)
    return out


def summarize(items):
    cnt = {}
    for it in items:
        cnt[it['verdict']] = cnt.get(it['verdict'], 0) + 1
    return cnt


def render_table(items, markdown=False):
    """表格：游戏 | 次数 | 最新 max_bottom | 最新 lowest | 同节点 | 趋势判定"""
    lines = []
    if markdown:
        lines.append('| 游戏 | 次数(OK/总) | 最新 max_bottom | 最新 lowest | 与上次同节点 | 趋势判定 |')
        lines.append('|---|---:|---:|---|:--:|---|')
        for it in items:
            lt = it['latest']
            mb = lt.mb if lt else '—'
            lo = (lt.lowest if lt and lt.lowest is not None else '—')
            same = '—' if it['same'] is None else ('是' if it['same'] else '**否**')
            lines.append('| %s | %d/%d | %s | `%s` | %s | %s |' % (
                it['game'], it['ok'], it['total'], mb, lo, same, it['verdict']))
    else:
        hdr = '%-26s %7s %8s %-28s %6s  %s' % ('游戏', '次数OK/总', '最新bottom', '最新 lowest', '同节点', '趋势判定')
        lines.append(hdr)
        lines.append('-' * len(hdr))
        for it in items:
            lt = it['latest']
            mb = str(lt.mb) if lt else '—'
            lo = (lt.lowest if lt and lt.lowest is not None else '—')
            if len(lo) > 26:
                lo = lo[:25] + '…'
            same = '—' if it['same'] is None else ('是' if it['same'] else '否')
            lines.append('%-26s %7s %8s %-28s %6s  %s' % (
                it['game'], '%d/%d' % (it['ok'], it['total']), mb, lo, same, it['verdict']))
    return '\n'.join(lines)


def render_history(items):
    """每款的全部测量；**每个 OK 行都标注它与「上一次 OK」的同节点/Δ**（判据 1973 的全量版）"""
    lines = ['', '=== 每款的全部测量（按时间；OK 行标注「相对上一次 OK」）===']
    for it in items:
        lines.append('')
        lines.append('■ %s（%d 次，OK %d）' % (it['game'], it['total'], it['ok']))
        prev = None
        for r in it['history']:
            mb = str(r.mb) if r.mb is not None else '-'
            lo = '—' if r.lowest is None else repr(r.lowest)
            tag = ''
            if r.mb is not None:
                if prev is None:
                    tag = '  ← 首次有效测量'
                else:
                    same = (prev.lowest or '') == (r.lowest or '')
                    tag = '  ← %s ｜ Δ%+d' % ('同节点' if same else '换节点', r.mb - prev.mb)
                prev = r
            lines.append('   %s  %-9s mb=%-5s lowest=%-40s%s' % (r.ts, r.status, mb, lo, tag))
        oks = [r for r in it['history'] if r.mb is not None]
        if len(oks) >= 2:
            lines.append('   首→末：%d → %d（Δ%+d，%s）' % (
                oks[0].mb, oks[-1].mb, oks[-1].mb - oks[0].mb,
                '同节点' if (oks[0].lowest or '') == (oks[-1].lowest or '') else '换节点'))
    return '\n'.join(lines)


# ────────────────────────────────────────────────────────────────────────────
#  自检（判据 1973 的两个真实实例 + 同节点改善）
# ────────────────────────────────────────────────────────────────────────────
SELF_TEST_TSV = """\
2026-11-12T20:01:00\tBase Shift\tOK\t1569\t30.0s lowest='121' -> /x
2026-11-12T20:11:00\tBase Shift\tOK\t1589\t31.0s lowest='选出移位后的十进制值' -> /x
2026-11-12T20:02:00\tFraction Matcher\tOK\t1582\t30.0s lowest='8/21' -> /x
2026-11-12T20:12:00\tFraction Matcher\tOK\t1600\t30.0s lowest='B' -> /x
2026-11-12T20:03:00\tSame Node Good\tOK\t1400\t30.0s lowest='提示' -> /x
2026-11-12T20:13:00\tSame Node Good\tOK\t1200\t30.0s lowest='提示' -> /x
2026-11-12T20:04:00\tSame Node Bad\tOK\t1200\t30.0s lowest='提示' -> /x
2026-11-12T20:14:00\tSame Node Bad\tOK\t1400\t30.0s lowest='提示' -> /x
2026-11-12T20:05:00\tOnly Once\tOK\t1500\t30.0s lowest='9' -> /x
2026-11-12T20:06:00\tNever Home\tNOT_HOME\t-\t42.0s could not reach home
2026-11-12T20:07:00\tNever Home\tNOT_HOME\t-\t43.0s could not reach home
"""


def self_test():
    rows = [parse_line(l) for l in SELF_TEST_TSV.split('\n')]
    rows = [r for r in rows if r]
    items = {it['game']: it for it in analyze(rows)}
    checks = [
        ('Base Shift', VERDICT_MAYBE, False),
        ('Fraction Matcher', VERDICT_MAYBE, False),
        ('Same Node Good', VERDICT_IMPROVED, True),
        ('Same Node Bad', VERDICT_WORSE, True),
        ('Only Once', '样本不足', None),
        ('Never Home', '样本不足', None),
    ]
    ok = True
    for game, want, want_same in checks:
        it = items.get(game)
        got = it['verdict'] if it else 'MISSING'
        same = it['same'] if it else None
        good = (got == want) and (want_same is None or same == want_same)
        ok = ok and good
        print('%s %-18s verdict=%r（期望 %r）｜同节点=%r（期望 %r）' % (
            '  OK  ' if good else '  FAIL', game, got, want, same, want_same))
    # 数字/内容判定
    cases = [('121', False), ('8/21', False), ('0/40', False), ('提示', True), ('B', True),
             ('选出移位后的十进制值', True), ('', False), (None, False)]
    for s, want in cases:
        got = is_content_lowest(s)
        good = got == want
        ok = ok and good
        if not good:
            print('  FAIL is_content_lowest(%r) = %r（期望 %r）' % (s, got, want))
    print('  OK    is_content_lowest：8 个用例全部通过' if ok else '')
    return ok


# ────────────────────────────────────────────────────────────────────────────
#  main
# ────────────────────────────────────────────────────────────────────────────
def main(argv):
    ap = argparse.ArgumentParser(description='台账趋势分析（判据 1973：max_bottom 变大 ≠ 变差）')
    ap.add_argument('--tsv', default=DEFAULT_TSV, help='输入台账（默认 _巡检记录/layout-canonical.tsv）')
    ap.add_argument('--markdown', action='store_true', help='表格用 Markdown 格式输出（便于贴进报告）')
    ap.add_argument('--history', action='store_true', help='额外打印每款的全部测量')
    ap.add_argument('--self-test', action='store_true', help='跑内置自检')
    ap.add_argument('--keep-artifacts', action='store_true',
                    help='保留扫描器自检行（__nope__ / __selftest__ 等以 __ 开头的伪游戏）')
    args = ap.parse_args(argv)

    if args.self_test:
        return 0 if self_test() else 3

    path = os.path.abspath(args.tsv)
    if not os.path.exists(path):
        print('🔴 台账不存在：%s' % path, file=sys.stderr)
        return 2
    rows, bad = parse_tsv(path)
    if not rows:
        print('🔴 台账里没有可解析的行：%s' % path, file=sys.stderr)
        return 2
    dropped = 0
    if not args.keep_artifacts:
        kept = [r for r in rows if not r.game.startswith('__')]
        dropped = len(rows) - len(kept)
        rows = kept
    if not rows:
        print('🔴 过滤后没有可分析的行', file=sys.stderr)
        return 2
    items = analyze(rows)
    cnt = summarize(items)

    print('台账：%s' % path)
    print('解析：%d 行有效%s ｜ %d 款游戏%s' % (
        len(rows), '（%d 行格式异常已跳过）' % bad if bad else '', len(items),
        '（已过滤 %d 行扫描器自检行）' % dropped if dropped else ''))
    print('判据 1973：比较 max_bottom 前先看 lowest 是否同一个节点；'
          '新 lowest 是内容文字 ⇒ 视为改善。')
    print('')
    print(render_table(items, args.markdown))
    print('')
    order = [VERDICT_IMPROVED, VERDICT_MAYBE, VERDICT_CHECK, VERDICT_WORSE, VERDICT_SAME, '样本不足']
    label = {VERDICT_IMPROVED: '真改善', VERDICT_MAYBE: '可能改善', VERDICT_CHECK: '待人工确认',
             VERDICT_WORSE: '变差', VERDICT_SAME: '无变化', '样本不足': '样本不足'}
    print('汇总：' + ' · '.join('%s %d' % (label[k], cnt[k]) for k in order if cnt.get(k)))
    if args.history:
        print(render_history(items))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
