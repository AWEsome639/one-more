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
        # ★ 2026-11-14（判据 2003）：**必须区分「blk=0」与「没有 blk 数据」**
        #   旧行（11-12/11-13 测的）没有 `blk=` 字段 ⇒ 原来一律默认 0
        #   ⇒ 那 6 款被算进 D 档「看起来干净」，实际**根本没量过溢出**。
        #   ⇒ 缺数据 ≠ 干净；这类必须重测。
        has_blk = False
        m = re.search(r'blk=(\d+)/(\d+)px', ln)
        # 2026-11-14（判据 2001）：**被遮挡文字节点数** —— 抓「内容太高把上方元素盖住」
        cm = re.search(r'cov=(-?\d+)', ln)
        if m:
            blk = int(m.group(2))
            has_blk = True
        low = ''
        m2 = re.search(r"lowest='([^']*)'", ln)
        if m2:
            low = m2.group(1)
        rows.append(dict(ts=ts, name=name, outcome=outcome, mb=mb, blk=blk, has_blk=has_blk, low=low, cov=(int(cm.group(1)) if cm else None)))
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
    # ★ 2026-11-14（判据 2003）：D 档必须**排除「无 blk 数据」**的
    #   —— 否则缺数据的款会被算成「干净」，而那正是这条判据要防的事。
    _noblk = [r for r in got if r['outcome'] in ('OK','TIGHT','OVER','NEAR') and not r.get('has_blk')]
    D = [r for r in got if r['blk'] == 0 and r['mb'] not in ('-',) and int(r['mb']) < GESTURE
         and r['name'] not in {x['name'] for x in _noblk}]
    for lst in (A, B, C, D):
        lst.sort(key=lambda r: -r['blk'] if 'blk' in r else 0)

    print('== %d 款有测量结果，%d 款是环境失败（要重测）==' % (len(got), len(env)))

    # ★ 2026-11-14（判据 2001）：**被遮挡**优先于所有档位 —— 因为这类 `blk` 往往最小却最严重
    #   （`Memory` 24 / `Schulte Table` 24 / `Simon Says` 48 / `Number Bonds All` 22）
    # ★ 2026-11-14（判据 2007）：**`cov = -1` 是「测不出来」，不能当成「没遮挡」**
    #   而这个指标今天才发现一直是坏的（只数文字压文字 ⇒ 恒 0）⇒
    #   **`10:00` 之前所有行的 `cov=0` 都不可信**，只是当时看不出来。
    # ★ 判据 2003/2007：三种状态必须分开 —— **没有 field** / **算了但失败** / **算出来了**
    COV_NODATA = [r for r in got if r.get('cov') is None]
    COV_FAIL = [r for r in got if r.get('cov') == -1]
    COV = [r for r in got if (r.get('cov') or 0) > 0]
    if COV_NODATA:
        print('\n【⚠️ cov 无数据】%d 款（旧行没这个字段 ⇒ 那时指标还没加，**不是「没遮挡」**）'
              % len(COV_NODATA))
        print('  ⇒ 今晚重测后就会有；在此之前 **不要**把它们算进「干净」。')
    if COV_FAIL:
        print('\n【⚠️ cov 算失败】%d 款（字段在但值为 `-1`：超时或异常）' % len(COV_FAIL))
        for r in COV_FAIL[:10]:
            print('  %-30s cov=-1  max=%-5s' % (r['name'], r['mb']))
    if COV:
        print('\n【⚠️ 被遮挡】cov > 0（有元素被别的元素整个覆盖）%d 款' % len(COV))
        print('   ⇒ **必须看截图判真假**：可能是真缺陷（盘面盖住统计行），也可能是**正常浮层**（徽标/角标叠在卡片上）')
        print('   ⇒ 合成测试实证：正常布局 cov=0 / 被盖住 cov=2 / **浮层(设计如此) cov=1** ⇒ 天生有误报')
        for r in COV:
            print('  %-30s cov=%-3d blk=%-3d max=%-5s' % (r['name'], r['cov'], r['blk'], r['mb']))
    # ★ 2026-11-14：**「无 blk 数据」单独一档** —— 缺数据不等于干净
    NOBLK = [r for r in got if r['outcome'] in ('OK', 'TIGHT', 'OVER', 'NEAR') and not r.get('has_blk')]
    if NOBLK:
        print('\n【⚠️ 无 blk 数据】状态 OK 但旧格式行没有 blk= ⇒ **没量过溢出，要重测** %d 款' % len(NOBLK))
        for r in NOBLK:
            print('  %-30s max=%-5s 测于 %s' % (r['name'], r['mb'], r['ts'][:10]))
        print('  ⇒ 判据 2003：**缺数据 ≠ 干净**。这 %d 款不算在 D 档里。' % len(NOBLK))

    print('\n【A 档】blk ≥ 24px（真越界，先看这些）%d 款' % len(A))
    for r in A:
        print('  %-30s blk=%-3d max=%-5s lowest=%s' % (r['name'], r['blk'], r['mb'], r['low'][:26]))
    print('\n【B 档】0 < blk < 24px（轻微）%d 款' % len(B))
    for r in B:
        print('  %-30s blk=%-3d max=%-5s' % (r['name'], r['blk'], r['mb']))
    # ★ 2026-11-14 补（判据 2062）：**C 档是「嫌疑名单」，不是「待办名单」**
    #   实证：`7` 款 C 档全部早已有矮屏降档，`blk=0` 是硬指标；
    #   而 `max_bottom` 只统计**有文字**的节点（`shot_game.py:134 texts()`），
    #   一个满屏游戏的说明行/按钮行**本来就该**排到 1584 以下
    #   （手势线 1584、屏底 1600，中间还有 16px）。
    #   ⇒ 还有判据 `1973`：「`max_bottom` 变大 ≠ 变差 —— 是『最低节点换人』」。
    print('\n【C 档 · 嫌疑名单】blk=0 但 max_bottom ≥ %d（有文字排到近屏底）%d 款' % (GESTURE, len(C)))
    print('  ⇒ **多数是正常满屏**，不是缺陷：`blk=0` 是硬指标，而 `max_bottom` 只量**有文字**的节点。')
    print('  ⇒ 只看截图确认（判据 1998）；**不要按 max_bottom 去改代码**（判据 1973）。')
    for r in C:
        print('  %-30s max=%-5s lowest=%s' % (r['name'], r['mb'], r['low'][:26]))
    print('\n【D 档】blk=0 且 max < %d（看起来干净，仍需扫一眼截图）%d 款' % (GESTURE, len(D)))
    print('\n【环境失败】要重测 %d 款：%s' % (len(env), ', '.join(r['name'] for r in env[:20])))

    print('\n== 结论 ==')
    print('A+B+C = %d 款需要**优先看截图**；D = %d 款可抽样看。' % (len(A) + len(B) + len(C), len(D)))
    print('⚠️ 但判据 1998：`blk=0` 也可能有横向裁切/同行挤压 ⇒ D 档不能跳过，只能降低优先级。')

if __name__ == '__main__':
    main()
