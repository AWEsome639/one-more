# -*- coding: utf-8 -*-
import io, re, os, glob
from collections import OrderedDict

DOC = "交接-给下一个拾海-20261106.md"
lines = io.open(DOC, encoding='utf-8').read().split('\n')

# 抓「行首 18xx / 17xx + 空格 + 内容」的条目
pat = re.compile(r'^(1[78]\d\d)([a-z]?)\s+\*\*(.+?)\*\*')
items = OrderedDict()
for i, ln in enumerate(lines, 1):
    m = pat.match(ln)
    if m:
        num = int(m.group(1)); suf = m.group(2); title = m.group(3)
        key = f"{num}{suf}"
        if key not in items:
            items[key] = (i, title)

# 找 _巡检记录/判据*.md 覆盖了哪些编号
covered = {}
for f in glob.glob('_巡检记录/判据*.md'):
    m = re.search(r'判据(\d{4})', os.path.basename(f))
    if m: covered[int(m.group(1))] = os.path.basename(f)

# 找冲突（同号不同标题）
seen = {}
conflicts = []
for k, (ln, t) in items.items():
    n = int(re.match(r'\d+', k).group())
    if n in seen and seen[n] != t:
        conflicts.append((k, seen[n], t))

out = []
out.append("# 判据编号总表（自动生成，2026-11-09 03:02）\n")
out.append(f"> 来源：`{DOC}`（{len(lines)} 行）+ `_巡检记录/判据*.md`（{len(covered)} 个文件）")
out.append(f"> 共 **{len(items)} 条**判据条目\n")
out.append("| 编号 | 标题（截断） | 交接文档行 | 独立报告 |")
out.append("|---|---|---|---|")
for k, (ln, t) in items.items():
    tt = t if len(t) <= 46 else t[:44] + '…'
    tt = tt.replace('|', '\\|')
    n = int(re.match(r'\d+', k).group())
    rep = covered.get(n, '—')
    out.append(f"| **{k}** | {tt} | {ln} | {rep} |")

if conflicts:
    out.append("\n## ⚠️ 编号冲突\n")
    for k, a, b in conflicts:
        out.append(f"- **{k}**：`{a}` vs `{b}`")
else:
    out.append("\n## ✅ 无编号冲突\n")

# 缺口（1800-1850 之间没出现的号）
nums = sorted(set(int(re.match(r'\d+', k).group()) for k in items))
gaps = [n for n in range(1800, 1850) if n not in nums]
out.append(f"\n## 1800–1849 区间缺口（{len(gaps)} 个号）\n")
out.append(', '.join(str(g) for g in gaps) if gaps else '（无）')

io.open('_巡检记录/判据编号总表.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f"生成完成：{len(items)} 条判据，{len(conflicts)} 处冲突，{len(gaps)} 个缺口")
