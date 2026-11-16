# -*- coding: utf-8 -*-
"""从截图算「内容占用」与「纵向空白」—— 量「大屏有没有浪费空间」（判据 2829）。

为什么用截图而不是 dump：
  dump 只给每个节点的 bounds，算不出「内容之间的大段空白」；
  而截图逐行看「有没有非背景像素」，能直接给出「内容底在哪」「哪里空了一大块」。

用法:
  python3 工具/measure_waste.py 截图1.jpeg [截图2 ...]
  python3 工具/measure_waste.py --glob '_巡检记录/截图-*-13*.jpeg'
"""
import sys, glob, os
from PIL import Image


def analyze(path):
    im = Image.open(path).convert('RGB')
    W, H = im.size
    im = im.resize((W // 8, H // 8))       # 降采样，够用且快
    W, H = im.size
    px = im.load()
    # 背景色：取四角 + 边缘的众数
    from collections import Counter
    edge = []
    for x in range(0, W, max(1, W // 40)):
        edge.append(px[x, 0]); edge.append(px[x, H - 1])
    for y in range(0, H, max(1, H // 40)):
        edge.append(px[0, y]); edge.append(px[W - 1, y])
    bg = Counter(edge).most_common(1)[0][0]
    # 逐行判定「有没有内容」（与背景差异 > 18 的像素占比 > 1.5%）
    rows = []
    for y in range(H):
        n = 0
        for x in range(0, W, 2):
            r, g, b = px[x, y]
            # ★ 判据 2831：阈值 18 太高 ⇒ 淡色元素（如 Path Recall 的淡黄格子）被当成空白。
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 8:
                n += 1
        rows.append(n / (W / 2.0) > 0.010)
    # 内容底：最后一个有内容的行
    last = max((i for i, v in enumerate(rows) if v), default=-1)
    # 最大的内部空白段（在首个内容行与 last 之间）
    first = min((i for i, v in enumerate(rows) if v), default=-1)
    gap, cur = 0, 0
    for i in range(first + 1, last):
        if not rows[i]:
            cur += 1
            gap = max(gap, cur)
        else:
            cur = 0
    return {
        'file': os.path.basename(path),
        'fill': (last + 1) / H if last >= 0 else 0.0,
        'max_gap': gap / H if H else 0.0,
    }


def main():
    args = sys.argv[1:]
    files = []
    if args and args[0] == '--glob':
        files = sorted(glob.glob(args[1]))
    else:
        files = args
    if not files:
        print('用法: python3 工具/measure_waste.py --glob "pattern"'); return 1
    print('%-46s %6s %8s %s' % ('文件', '占用', '最大空白', '判定'))
    waste = 0
    for f in files:
        try:
            r = analyze(f)
        except Exception as e:
            print('%-46s 失败: %s' % (os.path.basename(f), e)); continue
        verdict = ''
        if r['fill'] < 0.75:
            verdict = '⚠ 浪费（内容只到 %.0f%%）' % (r['fill'] * 100); waste += 1
        elif r['max_gap'] > 0.15:
            verdict = '⚠ 中间空 %.0f%%' % (r['max_gap'] * 100); waste += 1
        else:
            verdict = 'ok'
        print('%-46s %5.0f%% %7.0f%% %s' % (r['file'][:44], r['fill'] * 100, r['max_gap'] * 100, verdict))
    print()
    print('共 %d 张，可疑 %d 张' % (len(files), waste))
    return 0


if __name__ == '__main__':
    sys.exit(main())
