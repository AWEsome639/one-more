#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_outline_owner.py —— 焦点描边「挂载位置」审计

用途
====
`Tv.focusOutline()` 是 `.outline()` 的参数，而 `.outline()` 是**外描边**：
它画在「所属元素」的边界外面。如果所属元素是个**尺寸由父容器决定的布局容器**
（例如没有 `.height()` 的 `Stack`，被 `GridItem.height(...)` 撑高），
而真正「用户看得见的那个盒子」是它内部的 `Row`（有 backgroundColor + borderRadius），
那么描边就会**比可见内容大一圈** ⇒ 视觉上「多出来一块」。

第 1182 轮真机踩过这个坑（**根因后来更正过，见下**）：
  症状：`GameCard` 的焦点描边读起来"多出一块"
  最初误判：`Stack`（被 GridItem 撑高）挂了 outline，而可见胶囊是内层 `Row`
  **1184 轮用括号深度追踪更正**：
      `Row({ space: 8 }) {` 在 L766 **开始**、L883 **结束**；
      `.backgroundColor` / `.borderRadius` / `.outline` 全在 L884 之后
      ⇒ **它们都属于外层 Stack** ⇒ Stack 就是可见胶囊
      ⇒ **"描边挂错盒子"这个判断是错的**
  真根因：`Tv.focusOutline` 的默认 `Radius.md` ≠ 胶囊的 `Radius.lg`
      ⇒ 描边画成**直角矩形** ⇒ 在胶囊圆角处"多出四块"
      ⇒ 改成 `Radius.lg` 后描边跟着圆角走 ⇒ 视觉贴合 ✅

  ★ 这个工具仍然有价值：它防的是"描边真的挂在**无背景无圆角的布局容器**上"，
    即 `Row/Column/Stack` 上没有 backgroundColor 也没有 borderRadius 的情形。
    那是另一类真实风险（描边会包住一个不可见的大盒子）。

判据（本系列第 536 条）
====================
`.outline()` 必须画在「有背景色和圆角」的那个盒子上，不能画在它的外层容器上。

判据（本系列第 539 条）
====================
审计脚本报出「大面积全错」时，第一反应必须是「脚本错了」——
因为全错几乎不可能。先人工核对最小的一个具体实例。

适用范围（判据 480）
==================
· 只扫 `entry/src/main/ets/**/*.ets`
· 只认**静态可判**的情形：`.outline(Tv.focusOutline(...))`
· 判不了的情形一律标 `UNKNOWN`，**不假装通过**
· **分类规则**（第 1184 轮修正）：
    - 归属元素有 `backgroundColor` / `borderRadius`            ⇒ OK（可见盒子）
    - 归属元素是**内容控件**（Button/Text/Image/…）且无视觉属性 ⇒ OK（盒子=内容本身）
    - 归属元素是**布局容器**（Row/Column/Stack/…）且无视觉属性 ⇒ **SUSPECT**（可能被父容器撑大）
    - 归属元素认不出                                             ⇒ UNKNOWN
  ⚠️ 第 1183 轮我曾经把「内容控件无 backgroundColor」也算 SUSPECT，
     结果 `GConnectFour` 的 `Text('▼')` 被误报 —— 它的盒子就是它自己，没有缺陷。
· 已知盲区：
    - 属性链里通过变量/函数间接设置 backgroundColor 的（如 `.backgroundColor(this.cardColor())`
      是能认的，但 `.backgroundColor(theme.bg)` 里 `theme` 是运行时算的也照样能认，
      因为只认"有没有这个调用"，不认值）
    - `@Builder` 里跨函数拼接的属性链（无法静态追踪）
    - `if/else` 两个分支各挂一次 outline 的情形（只会取第一个）

输出
====
三类：
  OK        归属元素自身（或它到 outline 之间）有 backgroundColor 或 borderRadius
  SUSPECT   归属元素两者都没有                 ← 需要人工看
  UNKNOWN   找不到归属元素                     ← 需要人工看

退出码
======
  0  没有 SUSPECT（OK + UNKNOWN 可通过；UNKNOWN 会打印警告）
  1  有 SUSPECT
"""

import io
import os
import re
import sys
import collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'entry', 'src', 'main', 'ets')

# ArkUI 元素起始行：`Button(...)` / `Row() {` / `Stack({...}) {` 等
EL_START = re.compile(
    r'^\s*(?:'
    r'Button|Text|TextInput|TextArea|Row|Column|Stack|Flex|Image|Grid|GridItem|'
    r'List|ListItem|Scroll|Progress|Divider|Blank|Shape|Path|Circle|Rect|Line|'
    r'Canvas|Video|Web|Swiper|Tabs|TabContent|Badge|Toggle|Slider|Checkbox|Radio|'
    r'Select|Search|Navigation|NavDestination|Refresh|Sheet|Dialog|CustomDialog'
    r')\s*[\(\.]'
)

# 判断「可见盒子」的两个关键属性
VISUAL = ('.backgroundColor(', '.borderRadius(')

# 「布局容器」——尺寸可能由父容器决定，挂 outline 才可疑（判据 536 的成因）
LAYOUT_BOX = {
    'Row', 'Column', 'Stack', 'Flex', 'Grid', 'GridItem', 'List', 'ListItem',
    'Scroll', 'Swiper', 'Tabs', 'TabContent', 'Navigation', 'Refresh',
    'Badge', 'Blank', 'Divider', 'Shape', 'Path', 'Canvas',
}

# 「内容控件」——盒子就是内容本身（尺寸由文字/图片或显式 width/height 决定）
#   它们没有 backgroundColor 是**正常的**，不算缺陷
CONTENT_BOX = {
    'Button', 'Text', 'TextInput', 'TextArea', 'Image', 'Progress',
    'Circle', 'Rect', 'Line', 'Video', 'Web', 'Toggle', 'Slider',
    'Checkbox', 'Radio', 'Select', 'Search', 'CustomDialog', 'Dialog',
    'NavDestination', 'Sheet',
}

# 属性行：以 `.` 开头
ATTR = re.compile(r'^\s*\.')


def strip_comments_from_lines(lines):
    """把块注释内容抹成空格（保持行号不变），再返回新列表。
    这样后面所有正则都不会被注释里的字样骗到（判据 532）。"""
    out = []
    in_block = False
    for raw in lines:
        line = raw
        if in_block:
            j = line.find('*/')
            if j < 0:
                out.append('')
                continue
            line = ' ' * (j + 2) + line[j + 2:]
            in_block = False
        while True:
            i = line.find('/*')
            if i < 0:
                break
            j = line.find('*/', i + 2)
            if j < 0:
                line = line[:i]
                in_block = True
                break
            line = line[:i] + ' ' * (j + 2 - i) + line[j + 2:]
        i = line.find('//')
        if i >= 0:
            line = line[:i]
        out.append(line)
    return out


def find_owner(lines, idx):
    """找 `.outline` 所在属性链的**归属元素**。

    第 1189 轮改进：改用**括号深度**而不是纯缩进。
    原因：属性链可以跨 `}`（例如 `Row{...}` 收尾后，后面的 `.width()` `.outline()`
    其实是**外层 Stack** 的属性）。纯缩进在那种情况下会误判成"越界" ⇒ 报 UNKNOWN。

    算法：从 idx 往回走，维护括号平衡 `depth`（遇到 `}` +1、遇到 `{` -1）。
    当 depth 变成 -1 时，说明刚跨出当前块 ⇒ 该块的**起始行**就是归属元素。
    """
    depth = 0
    for k in range(idx - 1, max(-1, idx - 300), -1):
        l = lines[k]
        # 抹掉属性行里的 `{`/`}` 噪声（如 `.stateStyles({ ... })` 是一行内成对的）
        opens = l.count('{')
        closes = l.count('}')
        depth += closes - opens
        if depth < 0:
            # 刚跨出当前块 ⇒ k 这一行是"开块"的那行？
            # 注意：真正的开块行是**同一次循环里**让 depth 从 -1 变 0 的那行
            if EL_START.match(l):
                return k, l.strip()[:60]
            # 不是元素起始（可能是 if/ForEach/{}）⇒ 继续往外找
            depth = 0
            continue
        if depth == 0 and EL_START.match(l) and '}' not in l:
            # 同一层里更上面的元素起始（说明 outline 属于它）
            return k, l.strip()[:60]
    return None, None


def scan():
    ok, suspect, unknown, radius_bad = [], [], [], []

    for root, _, fs in os.walk(ROOT):
        for f in sorted(fs):
            if not f.endswith('.ets'):
                continue
            path = os.path.join(root, f)
            raw = io.open(path, encoding='utf-8', errors='ignore').read().split('\n')
            lines = strip_comments_from_lines(raw)
            for i, l in enumerate(lines):
                if 'Tv.focusOutline' not in l:
                    continue
                oi, otxt = find_owner(lines, i)
                rel = os.path.relpath(path, ROOT)
                if oi is None:
                    unknown.append((rel, i + 1, ''))
                    continue
                seg = lines[oi:i + 1]
                has_visual = any(any(v in x for v in VISUAL) for x in seg)
                kind = re.match(r'([A-Za-z]+)', otxt)
                kind = kind.group(1) if kind else ''
                if has_visual:
                    ok.append((rel, i + 1, otxt))
                elif kind in CONTENT_BOX:
                    # 内容控件：盒子就是内容本身，没有 backgroundColor 是正常的
                    ok.append((rel, i + 1, otxt))
                elif kind in LAYOUT_BOX:
                    # 布局容器：若**自己有明确的 width/height**，
                    # 则盒子边界 = 它自己，描边会贴合 ⇒ 算 OK
                    # （第 1189 轮：GSolitaire/SpiderSolitaire 的牌位 Stack 就是这样，
                    #   有 `.height(CARD_H)` + `.position(...)`，盒子=可见牌位）
                    seg2 = lines[oi:i + 1]
                    has_size = any(
                        ('.height(' in x or '.width(' in x) and not x.strip().startswith('//')
                        for x in seg2)
                    if has_size:
                        ok.append((rel, i + 1, otxt))
                    else:
                        suspect.append((rel, i + 1, otxt))
                else:
                    unknown.append((rel, i + 1, otxt))

                # ── 附加：圆角一致性（判据 537/544）──
                if oi is not None:
                    mm = re.search(r'focusOutline\([^,()]+\)', l)
                    if mm:
                        passed = 'Radius.md'          # 未传 ⇒ 默认 md
                    else:
                        mm2 = re.search(r'focusOutline\([^,]+,\s*([A-Za-z.]+)\s*\)', l)
                        passed = mm2.group(1).strip() if mm2 else None
                    if passed and passed.startswith('Radius.'):
                        rr = []
                        for x in lines[oi:i + 1]:
                            m3 = re.search(r'\.borderRadius\(\s*(Radius\.[a-z]+)\s*\)', x)
                            if m3:
                                rr.append(m3.group(1))
                        if rr and rr[-1] != passed:
                            radius_bad.append((rel, i + 1, rr[-1], passed))
    return ok, suspect, unknown, radius_bad


def report_three(checked, passed, skipped, label):
    """判据 546：输出必须区分「已检查 / 通过 / 未检查」，
    且通过率只按**已检查数**算（不能按总数算）。"""
    failed = checked - passed
    rate = (passed / checked * 100) if checked else 0.0
    print('  [%s] 已检查 **%d** ｜ 通过 **%d** ｜ 失败 **%d** ｜ 未检查 **%d**'
          % (label, checked, passed, failed, skipped))
    print('        ⇒ 通过率 = %d / %d = **%.1f%%**（**按已检查数算，未检查不计入**）'
          % (passed, checked, rate))
    if skipped:
        print('        ⚠️ 那 %d 处**没查过**，不能当成通过（判据 546）' % skipped)
    print()
    return failed


def main():
    if not os.path.isdir(ROOT):
        print('找不到目录: %s' % ROOT)
        return 2

    ok, suspect, unknown, radius_bad = scan()
    tot = len(ok) + len(suspect) + len(unknown)

    print('══ `.outline()` 挂载位置审计（共 %d 处）══' % tot)
    print('  ✅ OK      （归属元素有 backgroundColor 或 borderRadius）: %d' % len(ok))
    print('  ⚠️  SUSPECT （两者都没有，需人工看）                    : %d' % len(suspect))
    print('  ❓ UNKNOWN （找不到归属元素，需人工看）                  : %d' % len(unknown))
    print()

    if suspect:
        print('── SUSPECT 明细 ──')
        for rel, ln, txt in suspect:
            print('  %-46s L%-5d %s' % (rel, ln, txt))
        print()
        kinds = collections.Counter(t.split('(')[0] for _, _, t in suspect)
        print('  按元素类型: %s' % dict(kinds.most_common()))
        print()

    if unknown:
        print('── UNKNOWN 明细（前 20）──')
        for rel, ln, _ in unknown[:20]:
            print('  %-46s L%d' % (rel, ln))
        if len(unknown) > 20:
            print('  … 还有 %d 处' % (len(unknown) - 20))
        print()
        print('  ⚠️ UNKNOWN 不等于「已通过」——它是**本工具的盲区**（判据 480）。')
        print('     人工核对时：看那一行的属性链里 `.borderRadius(` / `.backgroundColor(` 在不在。')
        print()

    # ── 判据 546：三段式统计 ──
    print('── 判据 546：已检查 / 通过 / 未检查 三段式 ──')
    # 挂载位置：OK + SUSPECT 都算"查过"；UNKNOWN 是没查
    pos_checked = len(ok) + len(suspect)
    pos_passed = len(ok)
    report_three(pos_checked, pos_passed, len(unknown), '挂载位置')
    # 圆角一致性：只有在 oi 认得出时才查 ⇒ 与 UNKNOWN 同一批没查
    rad_checked = pos_checked
    rad_passed = pos_checked - len(radius_bad)
    report_three(rad_checked, rad_passed, len(unknown), '圆角一致性')

    # 参考数据：有多少归属元素「附近有明确 width+height」
    sized = 0
    for root, _, fs in os.walk(ROOT):
        for f in fs:
            if not f.endswith('.ets'):
                continue
            raw = io.open(os.path.join(root, f), encoding='utf-8', errors='ignore').read().split('\n')
            lines = strip_comments_from_lines(raw)
            for i, l in enumerate(lines):
                if 'Tv.focusOutline' not in l:
                    continue
                seg = '\n'.join(lines[max(0, i - 40):i + 1])
                if '.height(' in seg and '.width(' in seg:
                    sized += 1
    if tot:
        print('── 参考 ──')
        print('  outline 前后 40 行内同时有 width 与 height 的比例: %d / %d = %.1f%%'
              % (sized, tot, sized / tot * 100))
        print('  ⇒ 比例高说明大多数焦点目标是「有明确尺寸的格子/按钮」，')
        print('    不存在「布局容器被父容器撑高」这种结构性问题（判据 536 的成因）。')
    print()

    if radius_bad:
        print('── RADIUS_BAD 明细（描边圆角 ≠ 元素圆角，判据 537）──')
        aggr = collections.Counter((br, ps) for _, _, br, ps in radius_bad)
        for (br, ps), n in aggr.most_common():
            print('  元素 %-12s vs 描边 %-12s ⇒ **%d 处**' % (br, ps, n))
        print()
        for rel, ln, br, ps in radius_bad[:12]:
            print('  %-46s L%-5d 元素 %-12s 描边 %s' % (rel, ln, br, ps))
        if len(radius_bad) > 12:
            print('  … 还有 %d 处' % (len(radius_bad) - 12))
        print()

    if suspect:
        print('结论: ❌ 有 %d 处 SUSPECT —— 描边可能挂在纯布局容器上，需人工核对' % len(suspect))
        return 1
    if radius_bad:
        print('结论: ❌ 有 %d 处 RADIUS_BAD —— 描边圆角与元素圆角不一致' % len(radius_bad))
        return 2
    print('结论: ✅ 没有 SUSPECT、没有 RADIUS_BAD'
          + ('（但仍有 %d 处 UNKNOWN 需人工看）' % len(unknown) if unknown else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
