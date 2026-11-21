# -*- coding: utf-8 -*-
"""选出「今天还没测过」的国产（按 enName 归一化后比对文件名）"""
import io, os, re, sys, time
ROOT = '/Users/a0000/dev/One More'
reg = io.open(os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets'),
              encoding='utf-8', errors='replace').read()
pairs = [(m.group(1), m.group(2)) for m in
         re.finditer(r"\{[^}]*?name: '([^']+)'[^}]*?enName: '([^']+)'", reg)]

def norm(s):
    # 文件名里的 enName：空格 → 下划线
    return s.replace(' ', '_')

D = os.path.join(ROOT, '_巡检记录')
today = time.strftime('%Y-%m-%d')
done = set()
for n in os.listdir(D):
    if not n.startswith('截图-') or not n.endswith('.jpeg'):
        continue
    p = os.path.join(D, n)
    if time.strftime('%Y-%m-%d', time.localtime(os.path.getmtime(p))) != today:
        continue
    m = re.match(r'截图-(.+)-(\d{6})\.jpeg$', n)
    if m:
        done.add(m.group(1))

todo = [(zh, en) for zh, en in pairs if norm(en) not in done]
print('  今天已测 %d 款，剩 %d 款 / 共 %d' % (len(done), len(todo), len(pairs)))
n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
pick = todo[:n]
io.open('/tmp/todo.txt', 'w', encoding='utf-8').write('\n'.join(zh for zh, _ in pick) + '\n')
print('  本批:', ' / '.join(zh for zh, _ in pick))
