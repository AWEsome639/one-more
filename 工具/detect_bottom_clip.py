#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""detect_bottom_clip.py —— 用**截图本身**判断「底部内容是否被切」

════ 为什么需要它（判据 3100 的教训）════
`blk` 在竖屏上被证明**不可靠**：`Sudoku Hex blk=12468px`、`Bridges blk=7078px`、
`Peg Solitaire blk=3133px` 三款打开截图后**视觉全部完好**（`3/3` 伪影）。
⇒ 「底部有没有被切」这件事，`blk` 答不了，只有像素能答。

════ 判据 ════
一张**没被切**的截图，底部通常有两类安全形态：
  (a) 留白：最底若干行的非背景像素占比很低
  (b) 细文字：只有一行窄文字（提示语），横向覆盖率也不高
而**被切**的截图特征是：**最底一行被一整块内容横向铺满**（面板/按钮/网格被屏沿切断）。

⇒ 指标 `edge_cov`：最底 `k` 行里，非背景像素的**横向覆盖率**（每行先算 x 方向 span，
   再取这些行的最大值）。取「最大」而不是「平均」，是因为只要有一行被铺满就说明切了。


⚠️⚠️ **必须只扫「当前构建拍的截图」**（判据 `3102`）：
   全库 `356` 张「每款最新一张」里 `277` 张被标 `cov ≥ 0.60` —— **全是陈旧截图**
   （旧版本 UI、搜索页、首页、键盘盖屏）。而**今天新拍的 `19` 张里 `0` 张被标**。
   ⇒ 拿旧截图跑这个工具，得到的是一堆与当前代码无关的误报。

⚠️ 只作为「值得看一眼」的筛子，**不能当结论**（判据 3088/3100 的同构教训）。

用法：
  python3 工具/detect_bottom_clip.py 截图1.jpeg [截图2 ...]
  python3 工具/detect_bottom_clip.py --dir _巡检记录 --limit 40
  python3 工具/detect_bottom_clip.py --selftest     # 用已知案例做回归
"""
import io
import os
import re
import sys


def analyze(path, bottom_rows=6, bg_tol=18):
    """返回 dict：bottom_cov（最底若干行的最大横向覆盖率 0~1）、height、width。"""
    from PIL import Image
    im = Image.open(path).convert('RGB')
    w, h = im.size
    px = im.load()

    # 用四角的中位色估「背景色」
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    corners.sort(key=lambda c: sum(c))
    bg = corners[len(corners) // 2]

    def is_fg(c):
        return (abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2])) > bg_tol * 3

    worst = 0.0
    for dy in range(1, bottom_rows + 1):
        y = h - dy
        if y < 0:
            break
        left, right = None, None
        # 每 4 像素采一次，够快也够准
        for x in range(0, w, 4):
            if is_fg(px[x, y]):
                if left is None:
                    left = x
                right = x
        if left is not None:
            span = (right - left + 1) / float(w)
            worst = max(worst, span)
    return {'bottom_cov': worst, 'w': w, 'h': h, 'bg': bg}


def selftest():
    """用已知案例做回归：两款修好后正常、一款本来就正常、一款修前被切。"""
    cases = [
        ('_巡检记录/截图-Simon_Says-224823.jpeg', True,  '西蒙说 修前（C/D 被切）'),
        ('_巡检记录/截图-Simon_Says-103213.jpeg', False, '西蒙说 修后（四块完整）'),
        ('_巡检记录/截图-Sudoku_Hex-104914.jpeg', False, '六宫数独（视觉完好）'),
        ('_巡检记录/截图-Peg_Solitaire-104806.jpeg', False, '孔明棋（视觉完好）'),
        ('_巡检记录/截图-Bridges-105133.jpeg', False, '桥梁（视觉完好）'),
    ]
    print('== 自检（阈值 0.60）==')
    ok = 0
    n = 0
    for p, expect_clip, label in cases:
        if not os.path.exists(p):
            print('  ? 缺文件:', p); continue
        r = analyze(p)
        got = r['bottom_cov'] >= 0.60
        n += 1
        hit = (got == expect_clip)
        ok += hit
        print('  %s %-26s cov=%.2f 期望%s 实际%s' % (
            '✅' if hit else '❌', label, r['bottom_cov'],
            '被切' if expect_clip else '正常', '被切' if got else '正常'))
    print()
    print('  回归 %d/%d' % (ok, n))
    return 0 if ok == n else 1


def main():
    args = sys.argv[1:]
    if not args or args[0] == '--selftest':
        return selftest()
    threshold = 0.60

    if args and args[0] == '--today':
        import time as _t
        d = args[1] if len(args) > 1 else '_巡检记录'
        today = _t.strftime('%Y-%m-%d')
        latest = {}
        for n in sorted(os.listdir(d)):
            if not (n.startswith('截图-') and n.endswith('.jpeg')):
                continue
            p = os.path.join(d, n)
            if _t.strftime('%Y-%m-%d', _t.localtime(os.path.getmtime(p))) != today:
                continue
            m = re.match(r'截图-(.+)-(\d{6})\.jpeg$', n)
            if not m:
                continue
            g, ts = m.group(1), m.group(2)
            if g not in latest or ts > latest[g][0]:
                latest[g] = (ts, p)
        print('  --today：今天拍过截图的 %d 款（每款取最新）' % len(latest))
        flag = []
        for g, (ts, p) in sorted(latest.items()):
            try:
                r = analyze(p)
            except Exception as e:
                print('  ! %s: %s' % (g, e)); continue
            if r['bottom_cov'] >= threshold:
                flag.append((g, ts, r['bottom_cov']))
        for g, ts, c in sorted(flag, key=lambda x: -x[2]):
            print('  ⚠️ %-28s %s cov=%.2f' % (g, ts, c))
        print()
        print('  cov ≥ %.2f: %d / %d' % (threshold, len(flag), len(latest)))
        return 0
    paths = []
    if args and args[0] == '--dir':
        d = args[1]
        limit = 60
        if '--limit' in args:
            limit = int(args[args.index('--limit') + 1])
        files = []
        for n in sorted(os.listdir(d)):
            if n.startswith('截图-') and n.endswith('.jpeg'):
                files.append(os.path.join(d, n))
        files.sort(key=lambda p: -os.path.getmtime(p))
        paths = files[:limit]
    else:
        paths = args
    flagged = []
    for p in paths:
        try:
            r = analyze(p)
        except Exception as e:
            print('  ! %s: %s' % (os.path.basename(p), e))
            continue
        tag = '⚠️' if r['bottom_cov'] >= threshold else '  '
        print('%s %-46s cov=%.2f' % (tag, os.path.basename(p)[:46], r['bottom_cov']))
        if r['bottom_cov'] >= threshold:
            flagged.append(p)
    print()
    print('  共 %d 张，疑似底部被切 %d 张（阈值 %.2f）' % (len(paths), len(flagged), threshold))
    return 0


if __name__ == '__main__':
    sys.exit(main())
