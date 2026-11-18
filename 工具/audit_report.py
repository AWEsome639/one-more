#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
审计早报里的数字：**每一个数都从台账原始数据重算一遍**。

判据要求「每个结论能复算」。这个脚本让这句话可执行 ——
早报（`_巡检记录/★★★★★★★★★早报-*.md`）里写死的关键数字，
必须能在 `_巡检记录/layout-canonical.tsv` 里重新推导出同样的值。

用法：python3 工具/audit_report.py [日期 YYYY-MM-DD]
不传日期则用最近一次有记录的那天。
"""
import re, sys, os, io, collections

LEDGER = '_巡检记录/layout-canonical.tsv'

# ── 早报里写死的断言（改早报时必须同步改这里，否则审计会报不符）─────────────
CLAIMS = {
    '2026-11-19': {
        'bounds': ('02:33', '早报取的单实例分界'),
        'pre':  (63, 40, 63.5),      # (条数, OK, 通过率%)  三跑批期
        'post': (174, 168, 96.6),    # 单实例后
        'blk_gt0': 18,
        'returns': {                 # 6 款 Scroll 回滚，末次必须 OK
            'Wordle': 'OK', 'Kakuro Mini': 'OK', 'Magnets': 'OK',
            'Percentage Shopping': 'OK', 'Fraction Matcher': 'OK', '2048': 'OK',
        },
        'sev': {                     # 精确严重度（max/blkh × 100）
            'Shadow Pivot': 120.0, 'Collatz': 30.0, 'Memory': 27.3,
            'Wordle': 20.8, 'Snake 3D': 15.9, 'Magnets': 2.7,
            'Divided Attention': 2.7, 'Mandelbrot': 2.8,
        },
    },
}

def load():
    if not os.path.exists(LEDGER):
        sys.exit('台账不存在：%s' % LEDGER)
    rows = []
    for ln in io.open(LEDGER, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) >= 5:
            rows.append(f)
    return rows

def main():
    rows = load()
    day = sys.argv[1] if len(sys.argv) > 1 else max(r[0][:10] for r in rows)
    if day not in CLAIMS:
        # ★ 判据 3013：**没有当日断言表不是失败** —— 那是「还没写早报」。
        #   跑批收尾会调它，所以这里必须退出 0，否则每晚都报一次假失败。
        print('跳过：%s 还没有断言表（写早报时在 CLAIMS 里补）' % day)
        return 0
    C = CLAIMS[day]
    bound = C['bounds'][0]
    day_rows = [r for r in rows if r[0][:10] == day]
    pre = [r for r in day_rows if r[0][11:16] < bound]
    post = [r for r in day_rows if r[0][11:16] >= bound]

    bad = 0
    def check(name, got, want, tol=0.0):
        nonlocal bad
        ok = abs(got - want) <= tol
        if not ok: bad += 1
        print('  %-34s 实测 %-10s 早报 %-10s %s' % (name, got, want, '✅' if ok else '❌'))

    print('审计 %s（分界 %s）—— 台账 %d 行' % (day, bound, len(rows)))
    print('\n[① 通过率]')
    for nm, x, want in (('三跑批期', pre, C['pre']), ('单实例后', post, C['post'])):
        ok = sum(1 for r in x if r[2] == 'OK')
        pct = 100.0 * ok / len(x) if x else 0.0
        check('%s 条数' % nm, len(x), want[0])
        check('%s OK 数' % nm, ok, want[1])
        check('%s 通过率 %%' % nm, round(pct, 1), want[2], 0.05)

    print('\n[② blk>0 的款数]')
    blk = [r for r in post if re.search(r'blk=([1-9]\d*)/', r[4])]
    check('blk>0 款数', len(blk), C['blk_gt0'])

    print('\n[③ 回滚款末次状态]')
    for g, want in C['returns'].items():
        rec = [r for r in rows if r[1] == g]
        if not rec:
            print('  %-34s ❌ 台账里没有这款' % g); bad += 1; continue
        got = rec[-1][2]
        if got != want: bad += 1
        print('  %-34s 实测 %-6s 期望 %-6s %s' % (g, got, want, '✅' if got == want else '❌'))

    print('\n[④ 精确严重度 = max/blkh]')
    for g, want in C['sev'].items():
        hit = None
        for r in post:
            if r[1] != g: continue
            h = re.search(r'blkh=(\d+)px', r[4]); x = re.search(r'(?:^|\s)max=(\d+)', r[4])
            if h and x and int(h.group(1)) > 0:
                hit = (int(x.group(1)), int(h.group(1))); break
        if not hit:
            print('  %-34s ❌ 找不到带 blkh 的记录' % g); bad += 1; continue
        real = 100.0 * hit[0] / hit[1]
        print('  %-34s %d/%d = %5.1f%%  早报 %5.1f%%  %s'
              % (g, hit[0], hit[1], real, want, '✅' if abs(real - want) < 0.15 else '❌'))
        if abs(real - want) >= 0.15: bad += 1

    print('\n%s（不符项 %d）' % ('✅ 早报每一个数都能从台账重算出来' if bad == 0
                                else '❌ 有 %d 项与台账不符 —— 改早报或改断言表' % bad, bad))
    return 0 if bad == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
