# -*- coding: utf-8 -*-
"""生成「全量游戏清单」：355 款的 id/中文名/类别/难度/playStyle/文件。
派活前先看这张表，别再凭记忆列名单。
用法：python3 工具/gen_game_index.py
"""
import io, re, os

REG = 'entry/src/main/ets/core/GameRegistry.ets'
GAMES_DIR = 'entry/src/main/ets/games'
OUT = '_巡检记录/全量游戏清单.md'

pat = re.compile(
    r"\{\s*id:\s*'([^']+)',\s*name:\s*'([^']+)'.*?"
    r"category:\s*GameCategory\.(\w+).*?"
    r"difficulty:\s*Difficulty\.(\w+),\s*baseXp:\s*\d+,\s*tags:\s*\[([^\]]*)\]",
    re.S)

src = io.open(REG, encoding='utf-8').read()
rows = []
for m in pat.finditer(src):
    gid, zh, cat, diff, tags = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    tl = [t.strip().strip("'") for t in tags.split(',') if t.strip()]
    ps = next((t for t in tl if t.startswith('ps_')), '')
    rows.append((gid, zh, cat, diff, ps))

files = [f[:-4] for f in os.listdir(GAMES_DIR) if f.endswith('.ets')]
def norm(s): return re.sub(r'[^a-z0-9]', '', s.lower())
fmap = {}
for f in files: fmap[norm(f)] = f
for f in files:
    if f.startswith('G'): fmap.setdefault(norm(f[1:]), f)

def find_file(gid):
    k = norm(gid)
    return fmap.get(k) or fmap.get('g' + k) or ''

rows.sort(key=lambda r: (r[2], r[0]))
by_cat = {}
for r in rows: by_cat.setdefault(r[2], []).append(r)

out = [
    "# 全量游戏清单（自动生成）\n",
    f"> 来源：`{REG}`（解析 **{len(rows)} 款**）+ `{GAMES_DIR}/*.ets`（**{len(files)} 个文件**）",
    "> **派活前先看这张表，别再凭记忆列名单。**",
    "> 文件列是**推导**的（文件名去 `G` + 小写），**不确定就 `ls` 核对**。",
    "> 重新生成：`python3 工具/gen_game_index.py`\n",
    "## 按类别汇总\n", "| 类别 | 款数 |", "|---|---:|",
]
for c in sorted(by_cat): out.append(f"| {c} | {len(by_cat[c])} |")
out.append(f"| **合计** | **{len(rows)}** |\n")
out.append("## 明细\n")
miss = 0
for c in sorted(by_cat):
    out.append(f"### {c}（{len(by_cat[c])} 款）\n")
    out.append("| id | 中文名 | 难度 | playStyle | 文件 |")
    out.append("|---|---|---|---|---|")
    for gid, zh, _, diff, ps in by_cat[c]:
        f = find_file(gid)
        if not f:
            miss += 1
            f = '❓ 需核对'
        out.append(f"| `{gid}` | {zh} | {diff} | `{ps}` | {f} |")
    out.append('')

io.open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(f"生成：{len(rows)} 款 / {len(by_cat)} 类 / 文件未命中 {miss} 个 → {OUT}")
