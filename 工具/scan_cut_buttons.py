#!/usr/bin/env python3
"""扫描台账，找出「最底元素被屏底切掉」的款（判据 2710）。

用法:
  python3 工具/scan_cut_buttons.py            # 全部
  python3 工具/scan_cut_buttons.py --top 20   # 只显示前 20

判据:
  · 按钮期望高 = 44vp = 132px（触控下限）；lowest 高 < 132 且 y2 ≥ 1580 ⇒ 被切，差额 = 132 - 高
  · 文字行没有固定规格，按高度排序仅作参考（< 40px 视为可疑）

⚠️ 只覆盖「最底那一个元素」；中间区域的裁切仍只能靠截图（判据 2708/2709）。
"""
import io, re, sys, os

LEDGER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      '_巡检记录', 'layout-canonical.tsv')
BTN_H_PX = 132          # 44vp × 3
BTN_WORDS = ('提示', '重开', '换一题', '开始', '暂停', '确认', '提交', '继续',
             '下一题', '下一关', '跳过', '再来', '重新开始', '完成', '发送', '作答', '重玩')

def main():
    top = 99
    if '--top' in sys.argv:
        top = int(sys.argv[sys.argv.index('--top') + 1])
    last = {}
    for line in io.open(LEDGER, encoding='utf-8'):
        p = line.rstrip('\n').split('\t')
        if len(p) >= 5:
            last[p[1]] = p
    btn, txt = [], []
    for g, p in last.items():
        m = re.search(r"lowest='((?:[^'\\]|\\.)*)'\s+\[(\d+),(\d+)\]\[(\d+),(\d+)\]", p[4])
        if not m:
            continue
        s, y1, y2 = m.group(1), int(m.group(3)), int(m.group(5))
        h = y2 - y1
        if y2 < 1580:
            continue
        # ★ 判据 2714：按钮标签很短（≤ 8 字）且不含「：」；
        #   「提示：面积看长宽之积…」这种长句子是提示文字，不是按钮。
        is_btn = (len(s) <= 8 and '：' not in s and any(w in s for w in BTN_WORDS))
        if is_btn:
            btn.append((h, g, s[:18]))
        elif h < 40:
            txt.append((h, g, s[:18]))
    btn.sort(); txt.sort()
    print('=== 按钮被切（期望 %dpx，差额即缺口）%d 款 ===' % (BTN_H_PX, len(btn)))
    print('%-6s %-26s %-16s %s' % ('高', '游戏', '文字', '缺口'))
    for h, g, s in btn[:top]:
        print('%-6d %-26s %-16r %dpx' % (h, g, s, BTN_H_PX - h))
    print('\n=== 文字被挤（无规格，仅作可疑清单）%d 款 ===' % len(txt))
    for h, g, s in txt[:top]:
        print('%-6d %-26s %r' % (h, g, s))
    print('\n盘点：全库 %d 款有测量；按钮被切 %d；文字被挤 %d' % (len(last), len(btn), len(txt)))

if __name__ == '__main__':
    main()
