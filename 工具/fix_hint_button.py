#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把「提示」按钮的布局修对。

来历：这个错犯了**三次**（考拉兹 / 磁铁 / 黑在哪）。
判据其实只有一条：**看按钮的父容器是 Row 还是 Column。**

  Row    ⇒ 兄弟按钮要 .layoutWeight(1)（按比例分宽）
  Column ⇒ 要用 .width('100%') + 固定 height
           （Column 里 layoutWeight 分的是高度，配 height 会被压成 0 ⇒ 不渲染）

用法：
  python3 工具/fix_hint_button.py GKurodoko.ets        # 只检查并报告
  python3 工具/fix_hint_button.py GKurodoko.ets --fix  # 直接改成"包进 Row"
"""
import io, re, sys

def main():
    if len(sys.argv) < 2:
        print("用法: fix_hint_button.py <文件> [--fix]")
        return 2
    path = sys.argv[1]
    if not path.startswith('/'):
        path = '/Users/a0000/dev/yiju/entry/src/main/ets/games/' + path
    do_fix = '--fix' in sys.argv

    src = io.open(path, encoding='utf-8').read()
    lines = src.split('\n')

    # 找提示按钮
    i0 = None
    for i, l in enumerate(lines):
        if "Button(TG('提示'))" in l:
            i0 = i
            break
    if i0 is None:
        print("  🔴 没有「提示」按钮")
        return 1

    # 往前找最近的 Row( / Column(
    before = '\n'.join(lines[:i0])
    last_row = before.rfind('Row(')
    last_col = max(before.rfind('Column('), before.rfind('Column({'))
    parent = 'Row' if last_row > last_col else 'Column'

    # 这段按钮的属性
    seg = '\n'.join(lines[i0:i0 + 14])
    has_lw = '.layoutWeight(' in seg
    has_full = ".width('100%')" in seg

    print("     按钮在第 %d 行 ｜ 父容器 %s ｜ layoutWeight=%s ｜ width(100%%)=%s"
          % (i0 + 1, parent, has_lw, has_full))

    bad = False
    if parent == 'Column' and has_lw and not has_full:
        print("     🔴 Column 里用了 layoutWeight ⇒ 会被压成 0 高，不渲染")
        bad = True
    if parent == 'Row' and has_full and not has_lw:
        print("     🔴 Row 里用了 width(100%%) ⇒ 会挤掉兄弟按钮")
        bad = True

    if not bad:
        print("     ✅ 布局看起来是对的")
        return 0
    if not do_fix:
        print("     （加 --fix 会自动修）")
        return 1

    # 修法：把「提示」和它后面的那个 Button（重开/认输等）一起包进 Row，
    #       两个都用 layoutWeight(1)
    j = i0 + 1
    while j < len(lines):
        if 'Button(' in lines[j] and 'Button(TG(' not in lines[j]:
            break
        j += 1
    if j >= len(lines):
        print("     🔴 找不到兄弟按钮，放弃自动修")
        return 1
    # 兄弟按钮的属性块结束
    k = j
    depth = 0
    while k < len(lines):
        if '.onClick(' in lines[k] or lines[k].strip().startswith('.height('):
            depth += 1
        if depth > 0 and (lines[k].strip().startswith('}') or
                          (k + 1 < len(lines) and lines[k + 1].strip().startswith('Button('))):
            break
        k += 1
    end = k + 1

    indent = re.match(r'(\s*)', lines[i0]).group(1)
    block = lines[i0:end]
    # 统一：去掉 layoutWeight 和 width(100%)，改成 layoutWeight(1) + 固定高度
    cleaned = []
    for l in block:
        st = l.strip()
        if st == '.layoutWeight(1)' or st == ".width('100%')":
            continue
        if st.startswith('.height('):
            l = re.match(r'(\s*)', l).group(1) + '.height(46)'
        cleaned.append(l)
    # 每个 Button 后面插 layoutWeight
    out = []
    for i, l in enumerate(cleaned):
        out.append(l)
        if l.strip().startswith("Button("):
            out.append(indent + '  ' + '.layoutWeight(1)')
    inner = [('  ' + l if l.strip() else l) for l in out]
    wrapped = [indent + 'Row({ space: Space.sm }) {'] + inner + [indent + '}', indent + ".width('100%')"]

    lines[i0:end] = wrapped
    io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print("     ✅ 已包进 Row，两个按钮都用 layoutWeight(1)")
    return 0

if __name__ == '__main__':
    sys.exit(main())
