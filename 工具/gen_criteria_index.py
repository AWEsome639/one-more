# -*- coding: utf-8 -*-
"""判据编号总表生成器（v2：扫交接文档 + _巡检记录/ 的全部 md）

v1 的缺陷：只抓「行首 18xx + **标题**」，漏掉「写在段落正文里的『判据 18xx』」
v2 修正：① 交接文档：行首标题 + 正文引用；② _巡检记录/：文件名 + 全文引用

用法：python3 工具/gen_criteria_index.py
输出：_巡检记录/判据编号总表.md
"""
import io, re, os, glob
from collections import Counter

DOC = "交接-给下一个拾海-20261106.md"
OUT = "_巡检记录/判据编号总表.md"
LOW, HIGH = 1790, 1850   # 统计缺口的区间

head_pat = re.compile(r'^(1[78]\d\d)([a-z]?)\s+\*\*(.+?)\*\*')
body_pat = re.compile(r'判据\s*(1[78]\d\d)([a-z]?)')
file_pat = re.compile(r'判据(1[78]\d\d)([a-z]?)-')

items = {}

# ① 交接文档
lines = io.open(DOC, encoding='utf-8').read().split('\n')
for i, ln in enumerate(lines, 1):
    m = head_pat.match(ln)
    if m:
        k = m.group(1) + m.group(2)
        items.setdefault(k, {'title': m.group(3)[:48], 'src': f'交接:{i}', 'kind': '标题'})
    for m in body_pat.finditer(ln):
        k = m.group(1) + m.group(2)
        items.setdefault(k, {'title': '（仅正文引用）', 'src': f'交接:{i}', 'kind': '引用'})

# ② _巡检记录/：文件名里的判据号
for f in sorted(glob.glob('_巡检记录/*.md')):
    base = os.path.basename(f)
    m = file_pat.search(base)
    if not m:
        continue
    k = m.group(1) + m.group(2)
    if k not in items:
        first = io.open(f, encoding='utf-8').readline().strip().lstrip('# ').strip()
        items[k] = {'title': first[:48] or '（见报告）', 'src': base, 'kind': '独立报告'}

# ③ _巡检记录/：报告正文里的「判据 18xx」
for f in sorted(glob.glob('_巡检记录/*.md')):
    base = os.path.basename(f)
    if file_pat.search(base):
        continue
    txt = io.open(f, encoding='utf-8').read()
    for m in body_pat.finditer(txt):
        k = m.group(1) + m.group(2)
        items.setdefault(k, {'title': '（见报告正文）', 'src': base, 'kind': '报告引用'})

nums = sorted(set(int(re.match(r'\d+', k).group()) for k in items))
gaps = [n for n in range(LOW, HIGH) if n not in nums]

out = [
    "# 判据编号总表（自动生成 v2）\n",
    f"> 来源：`{DOC}`（{len(lines)} 行）+ `_巡检记录/*.md`（{len(glob.glob('_巡检记录/*.md'))} 份）",
    f"> 共 **{len(items)} 条**判据条目 —— **标题 {sum(1 for v in items.values() if v['kind']=='标题')}** / "
    f"**独立报告 {sum(1 for v in items.values() if v['kind']=='独立报告')}** / "
    f"**其余 {sum(1 for v in items.values() if v['kind'] in ('引用','报告引用'))}**（仅正文引用）",
    "> **重新生成：`python3 工具/gen_criteria_index.py`**",
    "> ⚠️ 「仅正文引用」的条目**没有标题**，是「被提到过但没立条目」，需人工确认是否真的要立。\n",
    "## 编号缺口（%d–%d）\n" % (LOW, HIGH - 1),
    f"**{len(gaps)} 个号未出现**：\n",
    (', '.join(str(g) for g in gaps) if gaps else '（无）'),
    "\n> ⚠️ 「未出现」≠「从来没用过」—— 只代表「交接文档 + `_巡检记录/` 里都没提到」。\n",
    "## 明细\n",
    "| 编号 | 标题（截断） | 来源 | 类型 |",
    "|---|---|---|---|",
]
for k in sorted(items, key=lambda x: (int(re.match(r'\d+', x).group()), x)):
    v = items[k]
    t = v['title'].replace('|', '\\|')
    out.append(f"| **{k}** | {t} | {v['src']} | {v['kind']} |")

io.open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
c = Counter(v['kind'] for v in items.values())
print(f"生成：{len(items)} 条 / {dict(c)} / 缺口 {len(gaps)} 个 → {OUT}")
