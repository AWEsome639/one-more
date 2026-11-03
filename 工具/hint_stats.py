#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按注册表逐个文件统计提示覆盖率。每次写台账前跑一次，不要手记。"""
import io, os, re
from collections import Counter
GAMES='/Users/a0000/dev/yiju/entry/src/main/ets/games'
REG='/Users/a0000/dev/yiju/entry/src/main/ets/core/GameRegistry.ets'
s=io.open(REG,encoding='utf-8').read()
recs=re.findall(r"id:\s*'([^']+)',\s*name:\s*'([^']+)',[^\n]*?category:\s*GameCategory\.([A-Z]+)", s)
def candidates(gid):
    """给出可能的文件名（按命中率排序）。
    ★ 原来的写法 `'G' + pascal(gid)` 会给 g2048 算出 GG2048、
      norinori 算出 Gnorinori —— 都是错的。
      现在改成"多试几个"，谁存在用谁。"""
    parts = re.split(r'[_\-]', gid)
    out = []
    # ① 直接把 id 首字母大写再加 G（全小写 id 的常见情形）
    out.append('G' + gid[0].upper() + gid[1:])
    # ② 每段首字母大写
    out.append('G' + ''.join(p.capitalize() for p in parts))
    # ③ id 自身首字母大写（id 已含 g 的情形）
    out.append(gid[0].upper() + gid[1:])
    seen = []
    for c in out:
        if c not in seen:
            seen.append(c)
    return seen
has=Counter(); total=Counter(); missing={}
for gid,name,cat in recs:
    p=None
    for c in candidates(gid):
        q=os.path.join(GAMES, c+'.ets')
        if os.path.exists(q): p=q; break
    if p is None: continue
    total[cat]+=1
    # ★ 2026-10-24 修：以前只要 import 了 ai/Hint 就算有提示，
    #   但 AI 代打也会 import Hint（用 toast）⇒ 只接代打的游戏被误算。
    #   正确判据：文件里有 private askHint（真接上了提示入口）。
    _src = io.open(p, encoding='utf-8').read()
    if 'ai/Hint' in _src and 'private askHint' in _src:
        has[cat]+=1
    else:
        missing.setdefault(cat,[]).append((gid,name))
print('  注册表 %d 款 ｜ 对上源文件 %d 款' % (len(recs), sum(total.values())))
for c in sorted(total):
    print('     %-8s %3d / %3d' % (c, has[c], total[c]))
print('     %-8s %3d / %3d' % ('合计', sum(has.values()), sum(total.values())))
import sys
if '--missing' in sys.argv and len(sys.argv)>2:
    cat=sys.argv[2]
    for gid,name in missing.get(cat,[]):
        print('     %-26s %s' % (gid,name))

# ── 附加用法：python3 工具/hint_stats.py --cat <游戏id>  ⇒ 打印它的分类
import sys as _sys
if '--cat' in _sys.argv:
    _id = _sys.argv[_sys.argv.index('--cat') + 1]
    for gid, name, cat in recs:
        if gid == _id:
            print('  %s（%s）→ %s' % (gid, name, cat))
            break
    else:
        print('  🔴 注册表里没有 id=%s' % _id)
