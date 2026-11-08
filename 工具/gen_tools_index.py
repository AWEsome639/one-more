# -*- coding: utf-8 -*-
"""生成 `工具/` 的索引（给「下一个拾海」的工具地图）

为什么要它：`工具/` 有 146 个文件，只有 26 个带注释头 ⇒ 不知道哪个能干什么。
用法：python3 工具/gen_tools_index.py
输出：工具/00-索引.md
"""
import io, os, glob, re
from collections import defaultdict

OUT = '工具/00-索引.md'
files = [f for f in glob.glob('工具/*') if os.path.isfile(f) and not f.endswith('00-索引.md')]

ext_of = {'py': 'Python', 'sh': 'Shell', 'mjs': 'Node', 'json': '配置', 'txt': '文本'}
rows = []
for f in files:
    base = os.path.basename(f)
    ext = base.rsplit('.', 1)[-1] if '.' in base else '其它'
    kind = ext_of.get(ext, '其它')
    # 描述：取前 8 行里第一条「非 shebang、非空、非纯分隔」的行
    desc = ''
    try:
        head = io.open(f, encoding='utf-8', errors='ignore').read().split('\n')[:8]
        for ln in head:
            s = ln.strip()
            if not s or s.startswith('#!') or s in ('"""', "'''"):
                continue
            s = re.sub(r'^#\s*', '', s).strip()
            if s:
                desc = s[:70]
                break
    except Exception:
        pass
    rows.append((kind, base, desc, os.path.getsize(f)))

by_kind = defaultdict(list)
for r in rows:
    by_kind[r[0]].append(r)

out = [
    '# `工具/` 索引（自动生成）\n',
    f'> 共 **{len(rows)} 个文件** ｜ {len(by_kind)} 类',
    '> 重新生成：`python3 工具/gen_tools_index.py`',
    '> ⚠️ 描述取「前 8 行里第一条非 shebang 的行」—— 没有注释的会显示为「（无描述）」\n',
    '## 按类型\n',
    '| 类型 | 个数 |',
    '|---|---:|',
]
for k in sorted(by_kind):
    out.append(f'| {k} | {len(by_kind[k])} |')
out.append('\n## 明细\n')

for k in sorted(by_kind):
    out.append(f'### {k}（{len(by_kind[k])} 个）\n')
    out.append('| 文件 | 描述 | 大小 |')
    out.append('|---|---|---:|')
    for _, base, desc, size in sorted(by_kind[k], key=lambda x: x[1]):
        d = (desc or '（无描述）').replace('|', '\\|')
        out.append(f'| `{base}` | {d} | {size // 1024}K |')
    out.append('')

io.open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f"生成：{len(rows)} 个 / {len(by_kind)} 类 → {OUT}")
