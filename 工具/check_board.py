#!/usr/bin/env python3
"""校验台账里的 `board=WxH@x,y` 是否**真的是棋盘**（而不是大按钮/弹窗/卡片）。

背景（`fixed_audit.py` 自己标注的局限）：
    「最大方形块」不一定是棋盘（大按钮/弹窗也可能）⇒ 名单要人工确认。

判据（不需要知道格子数，只用几何）：
    棋盘在横屏 2560×1600 上通常：
      ① 足够宽      W >= 480px（160vp）
      ② 近似方形    H/W ∈ [0.85, 1.18]
      ③ 水平居中    |x − (SCREEN_W − W)/2| <= 120px   ← 按钮/卡片常偏左或偏右
    三条全过 ⇒ 判「像棋盘」；否则判「可疑」并给出原因。

用法：
    python3 工具/check_board.py            # 查台账第一份带 board= 的最新行
    python3 工具/check_board.py --all      # 每款一行
    python3 工具/check_board.py --susp     # 只看可疑的
"""
import io
import os
import re
import sys

TSV = '_巡检记录/layout-canonical.tsv'
SCREEN_W = int(os.environ.get('SHOT_SCREEN_W', '2560'))
SCREEN_H = int(os.environ.get('SHOT_SCREEN_H', '1600'))

MIN_W = 480          # px（160vp）
AR_LO, AR_HI = 0.85, 1.18
CENTER_TOL = 120     # px


SCREEN_H = int(os.environ.get('SHOT_SCREEN_H', '1600'))


def board_bottom(y, h):
    """盘底 y+H 距屏底的差（正 = 超出屏底，即盘面被切）"""
    return (y + h) - SCREEN_H


def verdict(w, h, x, y):
    """返回 (ok, reasons)"""
    bad = []
    if w < MIN_W:
        bad.append('宽 %dpx < %dpx（太窄，像按钮）' % (w, MIN_W))
    ar = h / w if w else 0
    if not (AR_LO <= ar <= AR_HI):
        bad.append('高宽比 %.2f 不在 [%.2f, %.2f]' % (ar, AR_LO, AR_HI))
    ideal = (SCREEN_W - w) / 2.0
    off = abs(x - ideal)
    if off > CENTER_TOL:
        bad.append('水平偏移 %dpx（居中应在 x≈%d）' % (off, int(ideal)))
    return (not bad, bad)


def main():
    if not os.path.exists(TSV):
        print('❌ 找不到台账：%s' % TSV)
        return 2
    latest = {}
    for ln in io.open(TSV, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) < 5:
            continue
        m = re.search(r'board=(\d+)x(\d+)@(\d+),(\d+)', f[4])
        if m:
            latest[f[1]] = (int(m.group(1)), int(m.group(2)),
                            int(m.group(3)), int(m.group(4)))
    if not latest:
        print('⚠️ 台账里还没有带 `board=` 的测量 ⇒ 今晚跑完再来。')
        return 0

    show_all = '--all' in sys.argv
    only_susp = '--susp' in sys.argv
    ok_n = bad_n = 0
    print('%-28s %-18s %s' % ('游戏', 'board=WxH@x,y', '判定'))
    print('-' * 76)
    for g in sorted(latest):
        w, h, x, y = latest[g]
        ok, bad = verdict(w, h, x, y)
        if ok:
            ok_n += 1
        else:
            bad_n += 1
        if only_susp and ok:
            continue
        if not (show_all or only_susp) and ok:
            continue
        cut = board_bottom(y, h)
        cut_s = '✅ 完整' if cut <= 0 else '❌ 被切 %dpx' % cut
        print('%-28s %-18s %-14s %s' % (g, '%dx%d@%d,%d' % (w, h, x, y), cut_s,
                                        '✅ 像棋盘' if ok else '⚠️ ' + '；'.join(bad)))
    print()
    print('⇒ ✅ 像棋盘 %d 款 ｜ ⚠️ 可疑 %d 款 ｜ 合计 %d 款'
          % (ok_n, bad_n, ok_n + bad_n))
    print('⚠️ 「可疑」不等于「不能修」—— 只是要先看一眼是不是别的元素（卡/弹窗/按钮）。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
