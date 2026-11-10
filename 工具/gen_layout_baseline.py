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
    # ★ 2026-11-09：**后写的覆盖先写的**（同一款可能被测过多次；要取「最新」而不是「最早」）
    files = glob.glob(os.path.join(ROOT, '_巡检记录/layout-*.jsonl'))
    files.sort(key=lambda p: os.path.getmtime(p))
    for f in files:
        for ln in io.open(f, encoding='utf-8'):
            m = re.match(r"(?:\[\d+\]\s+)?(\w+)\s{2,}(.+?)\s+\{", ln.strip())
            if m and m.group(1) in ('OK', 'TIGHT', 'PUSHED_OUT', 'NOT_HOME', 'NOT_IN_GAME', 'NO_CARD', 'WRONG_GAME'):
                seen[m.group(2).strip()] = m.group(1)
            # ★ 2026-11-10（判据 1889）：优先用「行内时间戳」判断新旧；没有才退回「后写覆盖」
            m3 = re.match(r"\[(\d{4}-\d\d-\d\dT[\d:]+)\] ([^:]+): max_bottom=(\d+)", ln.strip())
            if m3:
                name = m3.group(2).strip()
                prev = seen.get(name)
                ts = m3.group(1)
                if not (isinstance(prev, tuple) and prev[0] > ts):
                    seen[name] = (ts, 'mb%s' % m3.group(3))
                continue
            m2 = re.match(r"\[(\d+)\] ([^:]+): max_bottom=(\d+) lowest='(.*?)'", ln.strip())
            if m2:
                seen[m2.group(2).strip()] = 'mb%s' % m2.group(3)
    return seen


def main():
    out = None
    if '--out' in sys.argv:
        out = sys.argv[sys.argv.index('--out') + 1]
    data = rows()
    buckets = {'OK': [], 'TIGHT': [], '溢出': [], '未测到': []}
    for name, v in sorted(data.items()):
        if isinstance(v, tuple):
            v = v[1]
        if v.startswith('mb'):
            mb = int(v[2:])
            key = 'OK' if mb <= OK_MAX else ('TIGHT' if mb <= TIGHT_MAX else '溢出')
            buckets[key].append((name, mb))
        elif v == 'OK':
            buckets['OK'].append((name, 'OK'))
        elif v == 'TIGHT':
            buckets['TIGHT'].append((name, 'TIGHT'))
        elif v == 'PUSHED_OUT':
            buckets['溢出'].append((name, 'PUSHED_OUT'))
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
