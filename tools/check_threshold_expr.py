# -*- coding: utf-8 -*-
"""复核我们批量写入的门槛表达式：`Math.max(1, Math.round(X * this.diffTotal / BASE))`
- X 与 BASE 必须是该文件内已声明的 const，或数字；
- BASE 不能等于 X（自比恒 1）；
- 统计每个文件出现次数，打印上下文行号。
"""
import io, os, re

GAMES = r'D:\work\one-more\entry\src\main\ets\games'
pat = re.compile(r'Math\.max\(1,\s*Math\.round\((\w+)\s*\*\s*this\.diffTotal\s*/\s*(\w+)\)\)')
issues = []
count = 0
files = 0
for fn in sorted(f for f in os.listdir(GAMES) if f.endswith('.ets')):
    t = io.open(os.path.join(GAMES, fn), encoding='utf-8').read()
    hits = list(pat.finditer(t))
    if not hits:
        continue
    files += 1
    declared = set(re.findall(r'const\s+([A-Z_][A-Z0-9_]*)\s*:', t))
    for m in hits:
        count += 1
        x, base = m.group(1), m.group(2)
        line = t[:m.start()].count('\n') + 1
        if x == base:
            issues.append((fn, line, 'X == BASE (%s)' % x))
        for name in (x, base):
            if not name.isdigit() and name not in declared:
                issues.append((fn, line, '未声明常量 ' + name))

for fn, line, why in issues:
    print('%-34s L%-4d %s' % (fn, line, why))
print('\nfiles:', files, 'expressions:', count, 'issues:', len(issues))
