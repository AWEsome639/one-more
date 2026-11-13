#!/usr/bin/env python3
"""把 `_巡检记录/layout-canonical.tsv` 变成「下一步该看哪些截图」的清单。

2026-11-13：判据 1998 的配套 —— `blk` 只量垂直，真正定性靠截图 ⇒
  需要一张**按可疑程度排序**的名单，而不是 355 行原始数据。

用法：
  python3 工具/triage.py                # 全部
  python3 工具/triage.py --since 2026-11-13   # 只看某天之后
"""
import io, re, sys, collections

TSV = '_巡检记录/layout-canonical.tsv'
GAME_AREA_BOTTOM = 1516   # 游戏区底（px）
GESTURE = 1584            # 手势区起点

def parse(since=None):
    rows = []
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 3:
            continue
        ts, name, outcome = f[0], f[1], f[2]
        if name in ('Nothing', '__nope__', ''):
            continue
        if since and ts < since:
            continue
        mb = f[3] if len(f) > 3 else '-'
        blk = 0
        m = re.search(r'blk=(\d+)/(\d+)px', ln)
        if m:
            blk = int(m.group(2))
        low = ''
        m2 = re.search(r"lowest='([^']*)'", ln)
        if m2:
            low = m2.group(1)
        rows.append(dict(ts=ts, name=name, outcome=outcome, mb=mb, blk=blk, low=low))
    return rows

def main():
    since = None
    if '--since' in sys.argv:
        since = sys.argv[sys.argv.index('--since') + 1]
    rows = parse(since)
    # 同一款取最后一次
    last = {}
    for r in rows:
        last[r['name']] = r
    rows = list(last.values())

    env = [r for r in rows if r['outcome'] in ('NOT_HOME', 'NO_CARD', 'DUMP_FAIL', 'TIMEOUT')]
    got = [r for r in rows if r not in env]

    # 分档：越可疑越靠前
    A = [r for r in got if r['blk'] >= 24]                       # 真越界 ≥ 8vp
    B = [r for r in got if 0 < r['blk'] < 24]                    # 轻微越界
    C = [r for r in got if r['blk'] == 0 and r['mb'] not in ('-',) and int(r['mb']) >= GESTURE]  # 触到手势区
    D = [r for r in got if r['blk'] == 0 and r['mb'] not in ('-',) and int(r['mb']) < GESTURE]
    for lst in (A, B, C, D):
        lst.sort(key=lambda r: -r['blk'] if 'blk' in r else 0)

    print('== %d 款有测量结果，%d 款是环境失败（要重测）==' % (len(got), len(env)))
    print('\n【A 档】blk ≥ 24px（真越界，先看这些）%d 款' % len(A))
    for r in A:
        print('  %-30s blk=%-3d max=%-5s lowest=%s' % (r['name'], r['blk'], r['mb'], r['low'][:26]))
    print('\n【B 档】0 < blk < 24px（轻微）%d 款' % len(B))
    for r in B:
        print('  %-30s blk=%-3d max=%-5s' % (r['name'], r['blk'], r['mb']))
    print('\n【C 档】blk=0 但 max_bottom ≥ %d（触到手势区）%d 款' % (GESTURE, len(C)))
    for r in C:
        print('  %-30s max=%-5s lowest=%s' % (r['name'], r['mb'], r['low'][:26]))
    print('\n【D 档】blk=0 且 max < %d（看起来干净，仍需扫一眼截图）%d 款' % (GESTURE, len(D)))
    print('\n【环境失败】要重测 %d 款：%s' % (len(env), ', '.join(r['name'] for r in env[:20])))

    print('\n== 结论 ==')
    print('A+B+C = %d 款需要**优先看截图**；D = %d 款可抽样看。' % (len(A) + len(B) + len(C), len(D)))
    print('⚠️ 但判据 1998：`blk=0` 也可能有横向裁切/同行挤压 ⇒ D 档不能跳过，只能降低优先级。')

if __name__ == '__main__':
    main()
