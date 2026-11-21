# -*- coding: utf-8 -*-
"""选出「今天还没测过」的款，并排除两类：
   ① 今天已有截图（用 enName 归一化后比对文件名 —— enName 带空格、文件名带下划线）
   ② 今天已连续失败 ≥2 次且从未成功（这类会一直失败，白烧预算；判据 3108）

用法：python3 工具/pick_untested.py [本批款数=10]
"""
import io, os, re, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
reg = io.open(os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets'),
              encoding='utf-8', errors='replace').read()
pairs = [(m.group(1), m.group(2)) for m in
         re.finditer(r"\{[^}]*?name: '([^']+)'[^}]*?enName: '([^']+)'", reg)]


def norm(s):
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

# ② 今天的失败统计（中文名）
fail_cnt, ok_today = {}, set()
ledger = os.path.join(D, 'layout-canonical.tsv')
if os.path.exists(ledger):
    for line in io.open(ledger, encoding='utf-8', errors='replace'):
        p = line.rstrip('\n').split('\t')
        if len(p) < 4 or not p[0].startswith(today):
            continue
        name, status = p[1], p[2]
        if status == 'OK':
            ok_today.add(name)
        else:
            fail_cnt[name] = fail_cnt.get(name, 0) + 1
chronic = {n for n, c in fail_cnt.items() if c >= 2 and n not in ok_today}

todo = [(zh, en) for zh, en in pairs if norm(en) not in done and zh not in chronic]
print('  今天已测 %d 款，慢性失败已排除 %d 款，剩 %d 款 / 共 %d'
      % (len(done), len(chronic), len(todo), len(pairs)))
n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
pick = todo[:n]
io.open('/tmp/todo.txt', 'w', encoding='utf-8').write('\n'.join(zh for zh, _ in pick) + '\n')
print('  本批:', ' / '.join(zh for zh, _ in pick))
