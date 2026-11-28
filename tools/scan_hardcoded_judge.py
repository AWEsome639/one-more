# -*- coding: utf-8 -*-
"""扫「判定文案写死数字」而「门槛已按难度缩放」的嫌疑款。"""
import io, os, re

GAMES = r'D:\work\one-more\entry\src\main\ets\games'
rows = []
for fn in sorted(f for f in os.listdir(GAMES) if f.endswith('.ets')):
    p = os.path.join(GAMES, fn)
    t = io.open(p, encoding='utf-8').read()
    scaled = ('Math.round(' in t and '* this.diffTotal' in t)
    if not scaled:
        continue
    for m in re.finditer(r"TG(?:2)?\(\s*['\"]([^'\"]*\d[^'\"]*)['\"]", t):
        s = m.group(1)
        if '判定' in s or '通关' in s or '题' in s or '关' in s:
            line = t[:m.start()].count('\n') + 1
            rows.append((fn, line, s[:60]))

for fn, line, s in rows:
    print('%-34s L%-5d %s' % (fn, line, s))
print('\ncandidates:', len(rows))
