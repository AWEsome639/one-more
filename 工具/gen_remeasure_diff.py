#!/usr/bin/env python3
"""配对对比：改前（基线 md）vs 改后（复测 jsonl/log）——按判据 1881 出「同一批款」的因果数据。

用法：
  python3 工具/gen_remeasure_diff.py --before _巡检记录/全量布局基线-20261109.md \
      --after /tmp/remeasure.log --out _巡检记录/配对对比-20261110.md
"""
import io
import re
import sys


def parse_before(path):
    txt = io.open(path, encoding='utf-8').read()
    out = {}
    for sec in ('OK', 'TIGHT', '溢出'):
        try:
            body = txt.split(f'## {sec}')[1].split('## ')[0]
        except IndexError:
            continue
        for m in re.finditer(r'^- `(.+?)` —— (.+)$', body, re.M):
            val = m.group(2).strip()
            num = int(re.sub(r'\D', '', val)) if re.search(r'\d', val) else None
            out[m.group(1)] = (sec, num)
    return out


def parse_after(path):
    out = {}
    for ln in io.open(path, encoding='utf-8'):
        m = re.match(r"\[\d+\]\s*(.+?):\s*max_bottom=(\d+)", ln.strip())
        if m:
            out[m.group(1).strip()] = int(m.group(2))
        else:
            m2 = re.match(r"\[\d+\]\s*(\w+)\s+(.+?)\s+\{", ln.strip())
            if m2 and m2.group(1) == 'PUSHED_OUT':
                out.setdefault(m2.group(2).strip(), 1600)
    return out


def main():
    a = sys.argv.index('--before'); before = sys.argv[a + 1]
    a = sys.argv.index('--after'); after = sys.argv[a + 1]
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else None
    B = parse_before(before)
    A = parse_after(after)
    rows = []
    for name, val in A.items():
        was = B.get(name)
        if not was:
            continue
        status = 'OK' if val <= 1516 else ('TIGHT' if val <= 1584 else '溢出')
        rows.append((name, was[1], val, status))
    fixed = [r for r in rows if r[3] in ('OK', 'TIGHT') and (r[1] or 1600) > 1584]
    still = [r for r in rows if r[3] == '溢出']
    lines = ['# 配对对比（同一批款、同一工具、改前 × 改后）', '',
             f'- 配对样本：**{len(rows)}** 款',
             f'- **改前溢出 → 改后 OK/TIGHT：`{len(fixed)}`**',
             f'- **改后仍溢出：`{len(still)}`**', '',
             '## 改善的', '']
    lines += [f'- `{n}` —— {b} → **{v}**（{s}）' for n, b, v, s in
              sorted(fixed, key=lambda r: -(r[1] or 1600) + r[2])[:40]]
    lines += ['', '## 仍溢出', '']
    lines += [f'- `{n}` —— {b} → {v}' for n, b, v, s in still]
    text = '\n'.join(lines)
    if out:
        io.open(out, 'w', encoding='utf-8').write(text)
        print(f'写出 {out}（配对 {len(rows)} 款，改善 {len(fixed)}，仍溢出 {len(still)}）')
    else:
        print(text[:1500])


if __name__ == '__main__':
    main()
