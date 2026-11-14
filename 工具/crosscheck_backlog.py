#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""**改动清单 × 最新溢出名单** 的交叉核对（判据 `2027`）。

**为什么需要它**
我那 `37` 处改动来自当时的三份补丁计划，而补丁计划是按**当时**的溢出名单出的。
**⇒ 后来名单变了（新量出 `Wordle`/`Mandelbrot`/`Magnets`/`Mastermind` 都是 `blk=48`），
而我的改动清单不会自己跟上 ⇒ 这 `4` 款被漏到现在。**

**它做什么**
① 从 `verify_changes_present.py` 读出「我改过哪些款」（类名 → 英文名）
② 从台账读每款最新 `blk` / `max_bottom`
③ 分三档报：
   · **A 档没碰过**（`blk ≥ 24` 但我没改）⇒ **明天要新做**
   · **C 档没碰过**（`blk = 0` 但 `max_bottom ≥ GESTURE`）⇒ 要查
   · **改过但仍溢出** ⇒ 改动没生效或不够

用法：`python3 工具/crosscheck_backlog.py`
退出码：`0` = 无遗漏；`1` = 有 A 档遗漏（值得注意）
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
VC = os.path.join(ROOT, '工具', 'verify_changes_present.py')
REG = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'core', 'GameRegistry.ets')
GESTURE = 1584


def touched_names():
    """从 `verify_changes_present.CHECKS` 拿到我改过的英文名集合。"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('vc', VC)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    reg = io.open(REG, encoding='utf-8').read()
    id2en = dict(re.findall(r"id: '([^']+)'[^}]*?enName: '([^']+)'", reg))
    out = set()
    for cls, _sig, _desc in m.CHECKS:
        p = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'games', '%s.ets' % cls)
        if not os.path.exists(p):
            continue
        src = io.open(p, encoding='utf-8').read()
        mm = re.search(r"(?:id|gameId)\s*[:=]\s*'([a-z0-9_]+)'", src)
        if mm and mm.group(1) in id2en:
            out.add(id2en[mm.group(1)])
    return out, len(m.CHECKS)


def main():
    touched, nchk = touched_names()
    last = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 4:
            continue
        mb = re.search(r'blk=(\d+)/(\d+)px', ln)
        if mb:
            last[f[1]] = (int(mb.group(2)), int(f[3]) if f[3].isdigit() else 0)

    A_un = sorted([(b, mx, n) for n, (b, mx) in last.items() if b >= 24 and n not in touched],
                  reverse=True)
    C_un = sorted([(mx, n) for n, (b, mx) in last.items()
                   if b == 0 and mx >= GESTURE and n not in touched], reverse=True)
    A_still = sorted([(b, mx, n) for n, (b, mx) in last.items() if b >= 24 and n in touched],
                     reverse=True)

    print('== 改动清单 × 最新溢出名单（判据 2027）==')
    print('   我改过 %d 处（%d 个英文名）｜ 台账有数据 %d 款' % (nchk, len(touched), len(last)))
    print()
    print('【A 档没碰过】%d 款（`blk ≥ 24` 但我没改 ⇒ **要新做**）' % len(A_un))
    for b, mx, n in A_un:
        print('   %-30s blk=%-3d max_bottom=%d' % (n, b, mx))
    print()
    print('【C 档没碰过】%d 款（`blk=0` 但 `max_bottom ≥ %d`）' % (len(C_un), GESTURE))
    for mx, n in C_un[:15]:
        print('   %-30s max_bottom=%d' % (n, mx))
    print()
    print('【改过但仍溢出】%d 款 —— ⚠️ 这一档要看**测量时间**' % len(A_still))
    print('   ⇒ 若台账里那些行是**改动之前**测的，则它们不代表「没修好」；')
    print('   ⇒ 今晚重测之后再看这一档，才算「改动生效了吗」。判据 `2012`。')
    for b, mx, n in A_still[:15]:
        print('   %-30s blk=%-3d max_bottom=%d' % (n, b, mx))
    print()
    if A_un:
        print('⚠️ 有 %d 款 A 档从未改过 ⇒ 明天要补进清单' % len(A_un))
        return 1
    print('✅ A 档无遗漏')
    return 0


if __name__ == '__main__':
    sys.exit(main())
