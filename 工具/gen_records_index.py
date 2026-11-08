# -*- coding: utf-8 -*-
"""生成 `_巡检记录/` 的索引（给「下一个拾海」的地图）

为什么要它：`_巡检记录/` 有 190+ 份 md，没有索引时「下一个拾海」不知道从哪读起。
用法：python3 工具/gen_records_index.py
输出：_巡检记录/00-索引.md
"""
import io, os, re, glob
from collections import defaultdict

OUT = '_巡检记录/00-索引.md'
files = sorted(glob.glob('_巡检记录/*.md'))
files = [f for f in files if os.path.basename(f) not in ('00-索引.md',)]

rows = []
for f in files:
    base = os.path.basename(f)
    # 日期
    m = re.search(r'(2026)(\d{2})(\d{2})', base)
    date = f'{m.group(1)}-{m.group(2)}-{m.group(3)}' if m else '无日期'
    # 标题（首行）
    try:
        first = io.open(f, encoding='utf-8').readline().strip()
    except Exception:
        first = ''
    title = re.sub(r'^#+\s*', '', first)
    if not title:
        title = base[:-3]
    # 大小
    size = os.path.getsize(f)
    rows.append((date, base, title[:60], size))

by_date = defaultdict(list)
for r in rows:
    by_date[r[0]].append(r)

out = [
    '# `_巡检记录/` 索引（自动生成）\n',
    f'> 共 **{len(rows)} 份** md ｜ **{len(by_date)} 个日期**',
    '> 重新生成：`python3 工具/gen_records_index.py`',
    '> ⚠️ 摘要取每份的**首行标题**（不准确时改那份文件的首行）\n',
    '## 按日期\n',
    '| 日期 | 份数 |',
    '|---|---:|',
]
for d in sorted(by_date, reverse=True):
    out.append(f'| {d} | {len(by_date[d])} |')
out.append('\n## 明细\n')

for d in sorted(by_date, reverse=True):
    out.append(f'### {d}（{len(by_date[d])} 份）\n')
    out.append('| 文件 | 摘要 | 大小 |')
    out.append('|---|---|---:|')
    for _, base, title, size in sorted(by_date[d], key=lambda x: -x[3]):
        t = title.replace('|', '\\|')
        out.append(f'| `{base}` | {t} | {size // 1024}K |')
    out.append('')

io.open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f"生成：{len(rows)} 份 / {len(by_date)} 个日期 → {OUT}")
