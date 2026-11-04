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

第 1182 轮真机踩过这个坑：
  `GameCard` 的 `Stack`（被 GridItem 撑到 126 vp）挂了 `.outline()`，
  而可见胶囊是内层 `Row`（只有 61 vp）
  ⇒ 描边在胶囊上方多出一大块直角框（奥森：「宝石迷阵卡片旁边又有多余的东西了」）

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

    规则：从 idx 往回走，跳过属性行（以 `.` 开头）与空行，
    第一个「非属性、非空、缩进 <= outline 缩进」的行就是归属元素
    （它可能自己就是元素起始行，也可能是 `if (...) {` 之类的包裹——后者算 UNKNOWN）。
    """
    base = len(lines[idx]) - len(lines[idx].lstrip())
    for k in range(idx - 1, max(-1, idx - 200), -1):
        l = lines[k]
        s = l.strip()
        if not s:
            continue
        if ATTR.match(l):
            continue
        ind = len(l) - len(l.lstrip())
        if ind > base:
            # 更深的非属性行（比如内层元素的属性）——继续往上
            continue
        if EL_START.match(l):
            return k, l.strip()[:60]
        # 缩进相同或更浅，但不是元素起始 ⇒ 不是这个属性链的归属
        return None, None
    return None, None


def scan():
    ok, suspect, unknown = [], [], []
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
                    # 布局容器：尺寸可能由父容器决定 ⇒ 可疑
                    suspect.append((rel, i + 1, otxt))
                else:
                    unknown.append((rel, i + 1, otxt))
    return ok, suspect, unknown


def main():
    if not os.path.isdir(ROOT):
        print('找不到目录: %s' % ROOT)
        return 2

    ok, suspect, unknown = scan()
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

    if suspect:
        print('结论: ❌ 有 %d 处 SUSPECT —— 描边可能挂在纯布局容器上，需人工核对' % len(suspect))
        return 1
    print('结论: ✅ 没有 SUSPECT' + ('（但仍有 %d 处 UNKNOWN 需人工看）' % len(unknown) if unknown else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
