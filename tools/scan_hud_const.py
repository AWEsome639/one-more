# -*- coding: utf-8 -*-
"""扫：门槛已按难度缩放，但 HUD/文案还直接引用常量（PASS/NEED 等）。"""
import io, os, re

GAMES = r'D:\work\one-more\entry\src\main\ets\games'
rows = []
for fn in sorted(f for f in os.listdir(GAMES) if f.endswith('.ets')):
    t = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
    scaled = ('Math.round(' in t and '* this.diffTotal' in t)
    if not scaled:
        continue
    for m in re.finditer(r"(?:String\(|'\s*/\s*'|\+\s*)(PASS|NEED|WIN_RIGHT|WIN_HITS)\b", t):
        line = t[:m.start()].count('\n') + 1
        seg = t[max(0, m.start() - 60):m.start() + 40].replace('\n', ' ')
        rows.append((fn, line, m.group(1), seg.strip()[:80]))

for fn, line, const, seg in rows:
    print('%-34s L%-5d %-9s %s' % (fn, line, const, seg))
print('\ncandidates:', len(rows))
