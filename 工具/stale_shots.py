#!/usr/bin/env python3
"""列出「截图早于代码最后改动」的款 —— 这些截图只能当历史、不能当现状。

背景（判据 2498/2499）：
  2026-11-14 抽样 13 款，发现 9 款（69%）的截图早于代码改动。
  根因是「夜间批量改代码」+「白天测量」的节奏错位：
  07:00–07:11 那批 9 个提交改了十几款，而它们的图是凌晨 00:xx–06:xx 拍的。

用法：
  python3 工具/stale_shots.py            # 列出过期的（默认只列前 20）
  python3 工具/stale_shots.py --all      # 全部
  python3 工具/stale_shots.py --count    # 只报数
"""
import io, os, subprocess, sys, time, re

TSV = '_巡检记录/layout-canonical.tsv'
GAMES = 'entry/src/main/ets/games'

# 台账显示名 → 文件名：用「G + 去掉空格/连字符」猜，并核对文件存在
_files = set(os.listdir(GAMES))
def guess_file(display):
    base = 'G' + display.replace(' ', '').replace('-', '').replace("'", '').replace('&', '')
    for f in _files:
        if f.lower() == (base + '.ets').lower():
            return f
    for f in _files:                      # 退一步：前缀匹配
        if f.lower().startswith(base.lower()[:10]):
            return f
    return None

def last_commit(path):
    return subprocess.run(['git', 'log', '-1', '--format=%ad', '--date=format:%Y-%m-%dT%H:%M', '--', path],
                          capture_output=True, text=True).stdout.strip()

# 每款取最后一次成功测量的截图
shots = {}
SUCCESS = ('OK', 'TIGHT', 'OVER', 'NEAR')
for ln in io.open(TSV, encoding='utf-8'):
    c = ln.rstrip('\n').split('\t')
    # ★ 2026-11-14 修（判据 2006/2009）：**只取成功行**。
    #   原来不看 outcome ⇒ `NO_CARD`/`NOT_HOME` 这类失败行也带截图（那是失败现场图），
    #   于是 `Word Ladder` 被判成「图有效 01:25」，而它最后一次**成功**测量是 11-13 03:03。
    if len(c) > 4 and c[2] in SUCCESS and '->' in c[4]:
        p = c[4].split('->')[-1].strip().split(' @')[0].strip()
        if p.startswith('/') and os.path.exists(p):
            # ★ 2026-11-14 修：必须保留**最新**成功行（原来 setdefault 保留的是第一条=最旧）
            #   ⇒ 会让「过期」数偏大（拿最旧的图去比代码时刻）。
            shots[c[1]] = p

stale, ok, unknown = [], [], []
for g, p in shots.items():
    fn = guess_file(g)
    if not fn:
        unknown.append((g, 'no-file')); continue
    code = last_commit(os.path.join(GAMES, fn))
    if not code:
        unknown.append((g, 'no-commit')); continue
    smt = time.strftime('%Y-%m-%dT%H:%M', time.localtime(os.path.getmtime(p)))
    if smt < code:
        stale.append((g, smt, code, os.path.basename(p)))
    else:
        ok.append((g, smt, code))

if '--count' in sys.argv:
    print('截图 %d 张：过期 %d、当前 %d、未验 %d'
          % (len(shots), len(stale), len(ok), len(unknown)))
    sys.exit(0)

print('截图 %d 张：**过期 %d**、当前 %d、未验 %d\n' % (len(shots), len(stale), len(ok), len(unknown)))
print('=== 过期（图早于代码最后改动 ⇒ 只能当历史）===')
lim = 10 ** 9 if '--all' in sys.argv else 20
for g, smt, code, f in sorted(stale, key=lambda r: r[2])[:lim]:
    print('  %-28s 图 %s ｜ 代码 %s ｜ %s' % (g, smt[5:], code[5:], f))
if len(stale) > lim:
    print('  …（还有 %d 款，用 --all 看全）' % (len(stale) - lim))
if unknown and '--all' in sys.argv:
    print('\n=== 未验（找不到对应文件或缺提交记录）===')
    for g, why in unknown[:20]:
        print('  %-28s %s' % (g, why))
