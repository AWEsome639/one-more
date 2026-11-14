#!/usr/bin/env python3
"""跑批之后的第一份报告：**先说证据新不新，再说哪款有问题**（判据 2300/2301/2302）。

产出四节：
  ① 证据新鲜度 —— 截图 mtime vs HAP mtime（用 mtime，不用文件名时间）
  ② 盘面是否被切 —— board= 的 (y+H) − 1600（blk/lowest 都看不见的那一维）
  ③ 文字是否到边 —— lowest.y2 == 1600 且可见高度 < 20px
  ④ 被遮挡 —— cov > 0

用法：
    python3 工具/morning_report.py            # 全部
    python3 工具/morning_report.py --fresh    # 只看证据是否新鲜
"""
import io
import os
import re
import sys
import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, '_巡检记录', 'layout-canonical.tsv')
SHOTDIR = os.path.join(ROOT, '_巡检记录')
HAP = os.path.join(ROOT, 'entry/build/default/outputs/default/entry-default-signed.hap')
SCREEN_H = int(os.environ.get('SHOT_SCREEN_H', '1600'))


def hap_mtime():
    try:
        return os.path.getmtime(HAP)
    except OSError:
        return None


def screenshot_mtimes():
    """{游戏英文名: mtime}，取每款最新一张"""
    out = {}
    for fn in os.listdir(SHOTDIR):
        if not (fn.startswith('截图-') and fn.endswith('.jpeg')):
            continue
        m = re.match(r'^截图-(.+)-(\d{6})\.jpeg$', fn)
        if not m:
            continue
        name = m.group(1).replace('_', ' ')
        t = os.path.getmtime(os.path.join(SHOTDIR, fn))
        if name not in out or t > out[name]:
            out[name] = t
    return out


def latest_rows():
    """每款返回 (最后一次**成功**测量的时间, outcome, extra, 最新一次的 outcome)。

    ⚠️ 为什么要分开：最新一行可能是 `NO_CARD`/`NOT_HOME`（测量失败，无 lowest）
    ⇒ 若直接取「最后一行」，那些款会被静默跳过（实锤：Visual Search All / Word Ladder 最新行是 NO_CARD，
      而它们上一次成功测量是有 lowest 数据的）。
    ⇒ 所以：数值取「最后一次成功测量」，同时把「最新一次 outcome」带出来供人判断新鲜度。
    """
    GOOD = ('OK', 'TIGHT', 'OVER', 'NEAR')
    rows = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) <= 4:
            continue
        g, ts, oc, ex = f[1], f[0], f[2], f[4]
        prev = rows.get(g)
        last_oc = oc if prev is None else oc
        if oc in GOOD:
            rows[g] = (ts, oc, ex, last_oc)
        elif g not in rows:
            rows[g] = ('', oc, '', oc)
        else:
            t0, o0, e0, _ = rows[g]
            rows[g] = (t0, o0, e0, oc)
    return rows


def parse_board(ex):
    m = re.search(r'board=(\d+)x(\d+)@(\d+),(\d+)', ex)
    if not m:
        return None
    w, h, x, y = (int(g) for g in m.groups())
    return w, h, x, y


def parse_lowest(ex):
    """返回 (文字, x1, y1, x2, y2)。

    ⚠️ 判据 2306：x2−x1 很大时，bounds 是**一整行**而不是单个元素
    ⇒ 此时的「可见高度」只说明那一行露了多少，不说明行内每个元素露了多少。
    """
    m = re.search(r"lowest='([^']*)'\s*\[\s*(-?\d+),(-?\d+)\]\[\s*(-?\d+),(-?\d+)\]", ex)
    if not m:
        return None
    return m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))


def main():
    only_fresh = '--fresh' in sys.argv
    hm = hap_mtime()
    shots = screenshot_mtimes()
    rows = latest_rows()

    print('== ① 证据新鲜度 ==')
    if hm is None:
        print('  ⚠️ 找不到 HAP ⇒ 无法判断新旧')
    else:
        print('  HAP mtime: %s' % datetime.datetime.fromtimestamp(hm).strftime('%m-%d %H:%M'))
        fresh = [n for n, t in shots.items() if t >= hm]
        print('  截图共 %d 款；晚于 HAP 的 %d 款' % (len(shots), len(fresh)))
        if not fresh:
            print('  ⛔ 零张新图 ⇒ 下面所有结论都基于**旧包**，只能当「曾经的现象」')
        else:
            print('  ✅ 有 %d 款是新图' % len(fresh))
            for n in sorted(fresh)[:10]:
                print('     %s  %s' % (n, datetime.datetime.fromtimestamp(shots[n]).strftime('%m-%d %H:%M')))
    if only_fresh:
        return 0

    print()
    print('== ② 盘面是否被切（board 的 y+H − %d）==' % SCREEN_H)
    any_cut = False
    for g, (_ts, _oc, ex, _last) in sorted(rows.items()):
        b = parse_board(ex)
        if not b:
            continue
        w, h, x, y = b
        cut = (y + h) - SCREEN_H
        if cut > 0:
            any_cut = True
            print('  ❌ %-26s board=%dx%d@%d,%d ⇒ 盘底 %d，超出 %dpx' % (g, w, h, x, y, y + h, cut))
    if not any_cut:
        print('  ✅ 台账里没有「盘底超出」的款（或还没有 board= 数据）')

    print()
    print('== ③ 文字到边且可见高度 < 20px ==')
    print('   ⚠️ 「宽度」列很大 ⇒ bounds 是**一整行**（判据 2306），可见高度是行的不是元素的')
    hit = False
    rows3 = []
    for g, (_ts, _oc, ex, _last) in sorted(rows.items()):
        lo = parse_lowest(ex)
        if not lo:
            continue
        txt, x1, y1, x2, y2 = lo
        vis = SCREEN_H - y1 if y1 < SCREEN_H else 0
        if y2 >= SCREEN_H and vis < 20:
            hit = True
            wid = x2 - x1
            flag = ' ← 整行' if wid > 1000 else ''
            rows3.append((g, txt, vis, wid))
            print('  ⚠️ %-26s %-12r 可见 %3dpx  宽度 %4dpx%s' % (g, txt[:10], vis, wid, flag))
    if not hit:
        print('  ✅ 没有')
    # ★ 判据 2308/2310：按 bounds 宽度几何分档（不读语义）
    func = [(g, t, v, w) for g, t, v, w in rows3 if w < 100]
    vis = [(g, t, v, w) for g, t, v, w in rows3 if w > 1000]
    mid = [(g, t, v, w) for g, t, v, w in rows3 if 100 <= w <= 1000]
    print()
    print('  ── 几何分档（判据 2308：宽度即「元素跨了多宽」）──')
    print('  功能级（宽 <100px，单元素，**高优先**）: %d 款' % len(func))
    for g, t, v, w in func:
        print('     %-24s %-12r 可见 %3dpx 宽 %4dpx' % (g, t[:10], v, w))
    print('  视觉级（宽 >1000px，整行说明，低优先）: %d 款' % len(vis))
    for g, t, v, w in vis:
        print('     %-24s %-14r 可见 %3dpx' % (g, t[:12], v))
    if mid:
        print('  待看（100~1000px，可能是行也可能是大元素）: %d 款' % len(mid))
        for g, t, v, w in mid:
            print('     %-24s %-12r 可见 %3dpx 宽 %4dpx' % (g, t[:10], v, w))

    print()
    print('== ④ 被遮挡（cov > 0）==')
    hit = False
    for g, (_ts, _oc, ex, _last) in sorted(rows.items()):
        m = re.search(r'cov=(-?\d+)', ex)
        if m and int(m.group(1)) > 0:
            hit = True
            print('  ⚠️ %-26s cov=%s' % (g, m.group(1)))
    if not hit:
        print('  ✅ 没有')

    print()
    print('⚠️ ②③④ 的结论都要配**新图**看（判据 2300：证据早于构建 ⇒ 待复验）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
