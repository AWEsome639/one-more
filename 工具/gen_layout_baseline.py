#!/usr/bin/env python3
"""把「全量布局扫描」的 jsonl 汇总成一张基线表（停演示基线，判据 1865）。

用法：
    python3 工具/gen_layout_baseline.py            # 读 _巡检记录/layout-*.jsonl
    python3 工具/gen_layout_baseline.py --out X.md

判定：
    max_bottom <= 1516          ⇒ OK
    1517 .. 1584                ⇒ TIGHT
    > 1584                      ⇒ 溢出
"""
import glob
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OK_MAX = 1516
TIGHT_MAX = 1584


def rows():
    seen = {}
    for f in sorted(glob.glob(os.path.join(ROOT, '_巡检记录/layout-*.jsonl'))):
        for ln in io.open(f, encoding='utf-8'):
            m = re.match(r"\[\d+\]\s+(\w+)\s+(.+?)\s+\{", ln.strip())
            if m and m.group(1) in ('OK', 'TIGHT', 'PUSHED_OUT', 'NOT_HOME', 'NOT_IN_GAME', 'NO_CARD', 'WRONG_GAME'):
                seen.setdefault(m.group(2).strip(), m.group(1))
            m2 = re.match(r"\[(\d+)\] ([^:]+): max_bottom=(\d+) lowest='(.*?)'", ln.strip())
            if m2:
                seen.setdefault(m2.group(2).strip(), 'mb%s' % m2.group(3))
    return seen


def main():
    out = None
    if '--out' in sys.argv:
        out = sys.argv[sys.argv.index('--out') + 1]
    data = rows()
    buckets = {'OK': [], 'TIGHT': [], '溢出': [], '未测到': []}
    for name, v in sorted(data.items()):
        if v.startswith('mb'):
            mb = int(v[2:])
            key = 'OK' if mb <= OK_MAX else ('TIGHT' if mb <= TIGHT_MAX else '溢出')
            buckets[key].append((name, mb))
        else:
            buckets['未测到'].append((name, v))
    lines = ['# 全量布局基线（停演示基线，判据 1865）', '']
    for k in ('OK', 'TIGHT', '溢出', '未测到'):
        lines.append(f'## {k}（{len(buckets[k])} 款）')
        lines.append('')
        for name, v in buckets[k]:
            lines.append(f'- `{name}` —— {v}')
        lines.append('')
    text = '\n'.join(lines)
    if out:
        io.open(out, 'w', encoding='utf-8').write(text)
        print(f'写出 {out}（{sum(len(v) for v in buckets.values())} 款）')
    else:
        print(text[:2000])


if __name__ == '__main__':
    main()
