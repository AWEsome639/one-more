#!/usr/bin/env python3
"""slack_scan.py —— 从 node dump 里量「棋盘下方剩余空间」，把「偏小」分成 A/B 两类。

判据 `2981`：东西太小有两种 ——
  A 类：周围有地方但没用（`slack` 大）⇒ 去掉顶对齐就见效，便宜活
  B 类：确实没地方（`slack` ≈ 0）  ⇒ 只能削 chrome，硬活

用法：
  python3 工具/slack_scan.py                    # 扫 _巡检记录/dumps/
  python3 工具/slack_scan.py --dir <目录> --top 30
  python3 工具/slack_scan.py --terse            # 只出 A 类清单

口径（与 shot_game.py 一致）：
  屏 `2560×1600 px`、`3px = 1vp`；「主棋盘」= 最大的近似方形块（边长差 ≤ 15%）。
  ⚠️ 这是启发式：可能误取到别的方形控件（色块、按钮组）。看得出可疑就人工核。
"""
import argparse, csv, glob, io, os, sys

SCR_W_PX, SCR_H_PX, PX_PER_VP = 2560, 1600, 3


def find_board(rows):
    best = None
    for r in rows:
        try:
            x1, y1, x2, y2 = int(r['x1']), int(r['y1']), int(r['x2']), int(r['y2'])
        except (KeyError, TypeError, ValueError):
            continue
        w, h = x2 - x1, y2 - y1
        if w < 200 or h < 200:
            continue
        if abs(w - h) > max(w, h) * 0.15:
            continue
        area = w * h
        if best is None or area > best[0]:
            best = (area, w, h, x1, y1, x2, y2)
    return best


def scan(paths):
    out = []
    for p in paths:
        try:
            rows = list(csv.DictReader(io.open(p, encoding='utf-8', errors='replace'), delimiter='\t'))
        except OSError:
            continue
        b = find_board(rows)
        if not b:
            continue
        _, w, h, x1, y1, x2, y2 = b
        slack_px = SCR_H_PX - y2
        out.append({
            'name': os.path.basename(p).replace('nodes-', '').replace('.tsv', '').replace('.stale', ''),
            'board_vp': round(w / PX_PER_VP),
            'y2': y2,
            'slack_vp': round(slack_px / PX_PER_VP),
            'width_pct': round(w / SCR_W_PX * 100),
            'path': p,
        })
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', default='_巡检记录/dumps')
    ap.add_argument('--top', type=int, default=0, help='只显示前 N 条（按 slack 降序）')
    ap.add_argument('--terse', action='store_true', help='只出 A 类（slack ≥ 30vp）')
    a = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(a.dir, '*.tsv*')))
    if not paths:
        print('没找到 dump：%s/ *.tsv*' % a.dir, file=sys.stderr)
        print('⇒ 跑批时设 SHOT_SAVE_DUMP=1 才会有。', file=sys.stderr)
        return 1

    rows = scan(paths)
    if not rows:
        print('扫了 %d 份，一份都没量到近似方形块。' % len(paths), file=sys.stderr)
        return 1

    rows.sort(key=lambda r: -r['slack_vp'])
    if a.terse:
        rows = [r for r in rows if r['slack_vp'] >= 30]
    if a.top:
        rows = rows[:a.top]

    print('%-4s %-28s %8s %6s %6s %7s' % ('#', '款', '棋盘vp', 'y2', 'slack', '占屏宽'))
    for i, r in enumerate(rows, 1):
        print('%-4d %-28s %8d %6d %5dvp %6d%%' % (
            i, r['name'][:28], r['board_vp'], r['y2'], r['slack_vp'], r['width_pct']))

    a_cnt = sum(1 for r in rows if r['slack_vp'] >= 30)
    print('\n共 %d 份 · A 类（slack ≥ 30vp，便宜活）%d 份 · B 类 %d 份' % (len(rows), a_cnt, len(rows) - a_cnt))
    print('⇒ 先做 A 类：去掉顶对齐即可，预期收益 70%+（判据 2981）。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
