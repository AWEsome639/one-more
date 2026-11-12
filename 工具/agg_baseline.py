#!/usr/bin/env python3
"""从唯一台账 `_巡检记录/layout-canonical.tsv` 聚合出「每款最新一次」的正式表。

判据 1945：**只有落盘到同一份台账，聚合才是可信的。**
"""
import io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CANON = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')

def main():
    latest = {}
    if os.path.exists(CANON):
        for ln in io.open(CANON, encoding='utf-8'):
            parts = ln.rstrip('\n').split('\t')
            if len(parts) < 5:
                continue
            ts, name, oc, mb = parts[0], parts[1], parts[2], parts[3]
            if not re.match(r'^\d{4}-', ts) or mb == '-':
                continue
            try:
                v = int(mb)
            except ValueError:
                continue
            latest[name] = (ts, oc, v)
    ok = {k: x for k, x in latest.items() if x[2] <= 1516}
    tight = {k: x for k, x in latest.items() if 1516 < x[2] <= 1584}
    bad = {k: x for k, x in latest.items() if x[2] > 1584}
    tot = len(latest)
    print('台账:', CANON)
    print('去重 %d 款：OK %d / TIGHT %d / 溢出 %d' % (tot, len(ok), len(tight), len(bad)))
    if tot:
        print('达标或接近 %d/%d = %.1f%%' % (len(ok) + len(tight), tot,
                                            (len(ok) + len(tight)) * 100.0 / tot))
    if bad:
        print('\n溢出清单：')
        for k, (ts, oc, v) in sorted(bad.items(), key=lambda x: -x[1][2]):
            print('  %5d  %-28s %s' % (v, k, ts))
    return 0

if __name__ == '__main__':
    sys.exit(main())
