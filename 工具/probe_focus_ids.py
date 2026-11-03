"""探测：1166 处 .focusable(Tv.on()) 各自"应该用哪个表达式作为唯一 id"。

思路：focusable 出现在某个组件（Stack/Column/Row/Text/Circle…）的属性链上，
      而该组件的"索引"通常来自它内部 Text(...) 的下标表达式，或来自 ForEach 的变量。
      这里只做**取证**：统计每处 focusable 向上 25 行内出现的下标表达式形态。
"""
import io, glob, re, collections

ID_PATTERNS = [
    (r'\(r \* [\w.]+ \+ c\)', '(r * X + c)'),
    (r'\(r \* N \+ c\)', '(r * N + c)'),
    (r'this\.idx\(r, c\)', 'this.idx(r, c)'),
    (r'\(i\)', '(i)'),
    (r'\(idx\)', '(idx)'),
    (r'\(k\)', '(k)'),
    (r'\(n\)', '(n)'),
]

kinds = collections.Counter()
per_file = []
no_pattern = []

for f in sorted(glob.glob('entry/src/main/ets/games/*.ets')):
    s = io.open(f, encoding='utf-8').read()
    lines = s.split('\n')
    name = f.split('/')[-1][:-4]
    found = 0
    for i, l in enumerate(lines):
        if '.focusable(Tv.on())' not in l:
            continue
        found += 1
        ctx = '\n'.join(lines[max(0, i-25):i])
        hit = None
        for pat, label in ID_PATTERNS:
            if re.search(pat, ctx):
                hit = label
                break
        if hit:
            kinds[hit] += 1
        else:
            kinds['(未识别)'] += 1
            no_pattern.append('%s:%d' % (name, i+1))
    if found:
        per_file.append((name, found))

print('  focusable 总数: %d' % sum(v for _, v in per_file))
print()
print('  按下标表达式形态分布:')
for k, v in kinds.most_common():
    print('    %-22s %d 处' % (k, v))
print()
print('  无法识别的 %d 处（前 8）:' % len(no_pattern))
for x in no_pattern[:8]:
    print('    %s' % x)
