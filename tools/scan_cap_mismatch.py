# -*- coding: utf-8 -*-
"""找「同一个 diffTotal 有的地方夹了上限、有的地方没夹」的款。"""
import io, os, re

GAMES = r'D:\work\one-more\entry\src\main\ets\games'
rows = []
for fn in sorted(f for f in os.listdir(GAMES) if f.endswith('.ets')):
    t = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
    assigns = re.findall(r'this\.diffTotal\s*=\s*([^;]+);', t)
    if len(assigns) < 2:
        continue
    capped = [a for a in assigns if 'Math.min(' in a]
    plain = [a for a in assigns if 'Math.min(' not in a and 'GameDiff.sizeNow' in a]
    if capped and plain:
        rows.append((fn, len(assigns), len(capped), len(plain),
                     plain[0].strip()[:60]))

for fn, n, c, p, sample in rows:
    print('%-34s assigns=%d capped=%d plain=%d  %s' % (fn, n, c, p, sample))
print('\ncandidates:', len(rows))
