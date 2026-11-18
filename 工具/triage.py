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
        # ★ 2026-11-16（判据 2782）：解析 lowest 后面的坐标 ⇒ 得到「最低元素的高度」与「它距屏底的间隙」。
        #   全天手工判断「是不是被切了」靠的就是这两个数：高度远低于设计 ⇒ 被切；y2 贴底 ⇒ 贴边。
        lm = re.search(r"lowest='[^']*'\s*\[(\d+),(\d+)\]\[(\d+),(\d+)\]", ln)
        lowh = (int(lm.group(4)) - int(lm.group(2))) if lm else -1
        lowgap = (1600 - int(lm.group(4))) if lm else -1
        # ★ 2026-11-15（判据 2695/2708）：**真溢出**的两个新字段 —— 11-15 起才有
        #   · over=   子容器比父容器高（容器尺寸矛盾）
        #   · sumover= 子元素高度之和 > 父容器高（父预算不足，最后一个被子元素被压）
        #   ⇒ 这两个 >0 才是**真溢出**；`blk` 只统计「y2>1576 的块」，对父界内的溢出无信息量。
        om = re.search(r'over=(\d+)px', ln)
        sm = re.search(r'sumover=(\d+)px', ln)
        has_over = bool(om)
        over = int(om.group(1)) if om else 0
        sumover = int(sm.group(1)) if sm else 0
        # ★ 2026-11-19（判据 2964）：预先算好分组键（别名/驼峰写法合并），显示仍用原名
        try:
            from ledger_names import canon as _canon, is_junk as _isj
            _k = _canon(name)
            if _isj(name):
                continue          # 垃圾名直接丢，不污染分母
        except Exception:
            _k = name
        rows.append(dict(ts=ts, name=name, key=_k, outcome=outcome, mb=mb, blk=blk, has_blk=has_blk, low=low, lowh=lowh, lowgap=lowgap, cov=(int(cm.group(1)) if cm else None), over=over, sumover=sumover, has_over=has_over))
    return rows

def _key(r):
    """分组键：用规范化名（判据 2964）—— 别名与驼峰写法合并成同一款。"""
    return r.get('key') or r['name']

def main():
    since = None
    if '--since' in sys.argv:
        since = sys.argv[sys.argv.index('--since') + 1]
    rows = parse(since)
    # 同一款取最后一次
    last = {}
    for r in rows:
        last[_key(r)] = r
    rows = list(last.values())
    # ★ 2026-11-19（判据 2963）：**别只看最后一条**。
    #   今天我只读每款最后一行就断定「10 款从未测过、可能坏了」，
    #   实际每款都至少有一次 OK 且 blk=0（Hanoi/FreeCell 各 2 次）。
    #   ⇒ 这里给每款补上「OK 次数 / 历史最大 blk」，最后一条失败但历史 OK 的单独列。
    _all = {}
    for r in parse(since):
        _all.setdefault(_key(r), []).append(r)
    _pseudo = []
    for r in rows:
        recs = _all.get(_key(r), [])
        r['ok_count'] = sum(1 for x in recs if x['outcome'] == 'OK')
        r['max_blk'] = max([x.get('blk', -1) for x in recs if x['outcome'] == 'OK'], default=-1)
        if r['outcome'] != 'OK' and r['ok_count'] > 0:
            _pseudo.append(r)

    env = [r for r in rows if r['outcome'] in ('NOT_HOME', 'NO_CARD', 'DUMP_FAIL', 'TIMEOUT')]
    got = [r for r in rows if r not in env]

    # ★ 2026-11-15（判据 2695/2708）：**真溢出优先** —— `over>0` 或 `sumover>0` 才是
    #   容器尺寸矛盾/父预算不足；`blk` 只统计「y2>1576 的块」，对父界内的溢出零信息量。
    AO = [r for r in got if r.get('over', 0) > 0 or r.get('sumover', 0) > 0]
    AO.sort(key=lambda r: -(r.get('over', 0) + r.get('sumover', 0)))
    _has_over_data = [r for r in got if r.get('has_over')]
    if AO:
        print('=== 真溢出（over>0 或 sumover>0）%d 款 ===' % len(AO))
        for r in AO[:25]:
            print('  %-28s over=%-4d sumover=%-4d %s' % (r['name'], r.get('over', 0), r.get('sumover', 0), r['ts'][:16]))
        print()
    elif _has_over_data:
        print('=== 真溢出：0 款（%d 款有 over/sumover 数据）===\n' % len(_has_over_data))
    else:
        print('=== 真溢出：**无数据** —— 这批测量没有 over=/sumover= 字段（旧 HAP 或旧脚本）===\n')

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

    # ★ 2026-11-16（判据 2782）：`lowest` 高度是全天最好用、却一直靠手工看的线索。
    #   「最低元素贴底 + 高度 < 100px」⇒ 很像被切的文字/按钮（正常按钮 132px、正常文字 42–49px）。
    #   ⚠️ 这是筛选器、不是判决（判据 2773/2774）。
    print('')
    print('== 必看截图清单（lowest 高度新线索，判据 2782）==')
    watch = [r for r in rows if r.get('outcome') == 'OK' and r.get('lowh', -1) >= 0
             and (r.get('blk', 0) > 0 or (r['lowh'] < 100 and r.get('lowgap', -1) <= 24))]
    if not watch:
        print('  ✅ 没有 —— 所有量过的款都不符合「贴底且短」或 blk>0')
    # ★ 2026-11-16（判据 2790）：`lowh ≥ 84` 几乎必然是「块底贴 1600」的结构性误报
    #   （今夜 Skyscrapers 113/115=98%、Dual Coding 132=Cell.tap 精确值、Word Surge 147 均属此类）
    #   ⇒ 排序按 lowh 升序（真危险的在前），并标出「疑似贴底」。
    for r in sorted(watch, key=lambda x: (x.get('lowh', 0), x.get('lowgap', 999)))[:14]:
        tag = ' ⚠️疑似贴底' if r['lowh'] >= 84 else ''
        print('  %-28s lowest_h=%-4d gap=%-4d blk=%-2d %s%s'
              % (r['name'], r['lowh'], r['lowgap'], r.get('blk', 0), (r.get('low') or '')[:20], tag))
    print('  共 %d 款（排序：贴底程度 → 高度）' % len(watch))
    # ★ 2026-11-19（判据 2963）：**伪失败** —— 最后一条失败、但历史上量到过 OK。
    if _pseudo:
        print('')
        print('== ⚠️ 伪失败清单（最后一条失败，但历史上测成功过；判据 2963）==')
        for r in sorted(_pseudo, key=lambda x: -x['ok_count']):
            print('  %-28s 最后=%s  OK %d 次  历史最大 blk=%s'
                  % (r['name'], r['outcome'], r['ok_count'],
                     r['max_blk'] if r['max_blk'] >= 0 else '—'))
        print('  ⇒ 这些**不是「从未测过」**：先看历史 blk，别当新问题去修。')

if __name__ == '__main__':
    main()
