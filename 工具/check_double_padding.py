#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_double_padding.py —— 找「双层 padding」风险（判据 722 的工具化）

★ 为什么需要（第 1280 轮）
  第 1272 轮修 195×195 的标题截断时，真因是**双重 padding**：
    `StatsTab` 的 Column `.padding({left/right: Space.lg})` = 20 vp 每边
    + `LevelHeader` 自己 `.padding(Space.lg)`             = 20 vp 每边
    ⇒ 每边 **40 vp** ⇒ 585 px 屏幕只剩 345 px ⇒ 标题被压成 129 px
  实测指纹：**Row 宽 345 px，内容区 465 px，差 120 = 2 × Space.lg**

⇒ 本工具做的事：
  ① 列出所有「自定义组件的根容器带 `.padding(`」的组件
  ② 列出这些组件**被谁调用**，并检查调用处的外层容器是否**也带 padding**
  ③ 两边都有 ⇒ **风险**（内边距会叠加）

为什么不直接报"文件里有 padding"：
  单个 padding 是正常的（卡片内边距就是要有）；
  只有**同一个元素同时吃到两层 padding** 才是 bug。

用法：
  python3 工具/check_double_padding.py              # 扫 entry/src/main/ets
  python3 工具/check_double_padding.py <目录>
退出码：0 = 无风险 ｜ 1 = 有风险 ｜ 2 = 输入问题
"""
import io
import os
import re
import sys


def read(p):
    return io.open(p, encoding='utf-8', errors='ignore').read()


def skip_comments_to_modifiers(lines, end):
    """从块结束行往后跳过注释，尽量延伸到修饰符链末尾（判据 764）"""
    q = end + 1
    last_mod = end
    while q < len(lines):
        t = lines[q]
        st = t.strip()
        if st.startswith('.'):
            last_mod = q
            q += 1
            continue
        if st.startswith('//') or st.startswith('/*') or st.startswith('*') or st == '':
            q += 1
            continue
        break
    return last_mod


def structs_with_padded_root(src):
    """返回 [(struct 名, 根容器 padding 行号)]

    ★ 判据 760（第 1280 轮）：**只认「与根容器同缩进的 `.padding(`」**
      —— 那是挂在最外层容器上的内边距；
      更深的 padding 属于内部子元素，不属于「组件根容器」。
      放宽版曾报 **676 个候选**（含大量内部 padding）⇒ 不可用。
    """
    out = []
    lines = src.split('\n')
    seen = set()

    i = 0
    while i < len(lines):
        l = lines[i]
        # 三种声明形式都要识别（判据 759）
        if not (re.match(r'\s*(@Component\s*)?(export\s+)?struct\s+\w+', l)
                or re.match(r'\s*@Component\s*$', l)):
            i += 1
            continue

        # 找 struct 名（同行或后几行）
        name = None
        for j in range(i, min(len(lines), i + 6)):
            ms = re.search(r'struct\s+(\w+)', lines[j])
            if ms:
                name = ms.group(1)
                break
        if name is None or name in seen:
            i += 1
            continue
        seen.add(name)

        # 找 build() 与根容器
        k = i
        while k < len(lines) and 'build()' not in lines[k]:
            k += 1
        if k >= len(lines):
            i += 1
            continue

        root_line = None
        root_indent = None
        for q in range(k, min(len(lines), k + 20)):
            t = lines[q]
            # ★ 判据 761（第 1280 轮）：**必须跳过 `build()` 自身**
            #   否则 `(\s*)(\w+)\s*\(` 会匹配到 `build() {`
            #   ⇒ 根容器 indent 取到 build 的缩进 ⇒ 与实际的 `.padding(` 缩进不符
            #   ⇒ 一度报「0 个组件」（过严）
            if 'build()' in t or t.strip().startswith('//'):
                continue
            mm = re.match(r'(\s*)([A-Z][\w]*|if|ForEach|Scroll|Column|Row|Stack|Flex|Grid|List|Tabs|Swiper|Text|Circle|Path|Canvas|Shape)\s*\(', t)
            if mm:
                root_line = q
                root_indent = len(mm.group(1))
                break
        if root_line is None:
            i += 1
            continue

        # 根容器块的范围
        depth = 0
        began = False
        root_end = None
        for q in range(root_line, min(len(lines), root_line + 800)):
            depth += lines[q].count('{') - lines[q].count('}')
            if '{' in lines[q]:
                began = True
            if began and depth <= 0:
                root_end = q
                break
        if root_end is None:
            i += 1
            continue

        # ★ 判据 762（第 1280 轮）：**ArkUI 的修饰符链在闭括号之后**
        #   `.padding(...)` 属于**根容器**，但写在其 `}` 的下一行起
        #   ⇒ 范围必须一直延伸到「不再以 `.` 开头的行」
        #   （否则 `LevelHeader` 的 `.padding(Space.lg)` 会被漏掉）
        # ★ 判据 764（第 1280 轮）：**修饰符链之间可能夹注释**
        #   实证：StatsTab 的 `Column { … }` 结束于 L326，
        #     而 `.padding({...})` 在 **L332**，中间 L327~L331 是注释
        #     ⇒ 「遇到非 `.` 就停」会漏掉真正的 padding
        root_end = skip_comments_to_modifiers(lines, root_end)

        # ★ 只认「缩进 == root_indent」的 .padding(
        pad = None
        for q in range(root_line, root_end + 1):
            t = lines[q]
            if '.padding(' not in t or t.strip().startswith('//'):
                continue
            ind = len(t) - len(t.lstrip())
            if ind == root_indent:
                pad = q + 1
                break
        if pad:
            out.append((name, pad))
        i += 1
    return out



def calls_of(src, name):
    """返回该组件被调用的行号列表（排除定义处）"""
    out = []
    for i, l in enumerate(src.split('\n')):
        if re.search(r'\b%s\s*\(' % re.escape(name), l) and not re.match(r'\s*struct\s+%s' % re.escape(name), l):
            if l.strip().startswith('//'):
                continue
            out.append(i + 1)
    return out


def enclosing_has_padding(src, call_line, window=None):
    """判断「调用该组件的父容器」是否也带 padding

    ★ 判据 763（第 1280 轮）：**不能用固定 ±12 行窗口**
      实证：`StatsTab.ets:309` 调用 `LevelHeader()`，
        而 `StatsTab` 的 Column `.padding({...})` 在 **L332**（相隔 23 行）
        ⇒ ±12 窗口漏掉 ⇒ 风险报 0（假的）

    ⇒ 做法：
      ① 从调用行**往上**找最近一个「缩进更小且以 `容器名(` 开头」的行 ⇒ 父容器
      ② 从父容器行**往下**扫到「缩进回到父容器缩进」为止，
         找**缩进 == 父容器缩进**的 `.padding(`（修饰符链，判据 762）
    """
    lines = src.split('\n')
    idx = call_line - 1
    if idx < 0 or idx >= len(lines):
        return None
    call_indent = len(lines[idx]) - len(lines[idx].lstrip())

    container_re = re.compile(r'^(\s*)(Scroll|Column|Row|Stack|Flex|Grid|List|Tabs|Swiper)\s*\(')
    parent_line = None
    parent_indent = None
    for q in range(idx - 1, max(-1, idx - 400), -1):
        mm = container_re.match(lines[q])
        if not mm:
            continue
        ind = len(mm.group(1))
        if ind < call_indent:
            parent_line = q
            parent_indent = ind
            break
    if parent_line is None:
        return None

    # 从父容器往下扫，直到缩进回到 parent_indent 的闭括号之后
    depth = 0
    began = False
    end = None
    for q in range(parent_line, min(len(lines), parent_line + 800)):
        depth += lines[q].count('{') - lines[q].count('}')
        if '{' in lines[q]:
            began = True
        if began and depth <= 0:
            end = q
            break
    if end is None:
        return None
    end = skip_comments_to_modifiers(lines, end)

    for q in range(parent_line, end + 1):
        t = lines[q]
        if '.padding(' not in t or t.strip().startswith('//'):
            continue
        ind = len(t) - len(t.lstrip())
        if ind == parent_indent:
            return q + 1
    return None



def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'entry/src/main/ets'
    if not os.path.isdir(root):
        print('目录不存在: %s' % root); return 2

    files = []
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if fn.endswith('.ets'):
                files.append(os.path.join(dp, fn))

    print('=' * 74)
    print('  双层 padding 审计（判据 722）  根目录: %s' % root)
    print('=' * 74)

    # ① 收集所有「根容器带 padding」的组件
    padded = []
    for f in files:
        src = read(f)
        for name, line in structs_with_padded_root(src):
            padded.append((name, f, line))

    print('  ① 根容器带 padding 的组件：%d 个' % len(padded))
    for name, f, line in padded:
        print('     %-26s %s:%d' % (name, os.path.basename(f), line))
    print()

    # ② 检查每个组件被调用的地方，外层是否也有 padding
    risks = []
    for name, f, line in padded:
        for g in files:
            if os.path.abspath(g) == os.path.abspath(f):
                continue
            src = read(g)
            for cl in calls_of(src, name):
                pl = enclosing_has_padding(src, cl)
                if pl:
                    risks.append((name, f, line, g, cl, pl))

    print('  ② 调用处外层也有 padding（⇒ 内边距叠加）：%d 处' % len(risks))
    for name, f, line, g, cl, pl in risks:
        print('     🔴 %s（自身 padding @%s:%d）' % (name, os.path.basename(f), line))
        print('        被 %s:%d 调用，外层 padding @%s:%d'
              % (os.path.basename(g), cl, os.path.basename(g), pl))
    print()
    print('=' * 74)
    if risks:
        print('  ⚠️ **%d 处风险**：内层组件的 padding 会与外层叠加' % len(risks))
        print('  ⇒ 逐条确认：若外层是「卡片」而内层是「内容」，叠加是**有意的**；')
        print('     若两层都是「同一张卡的内边距」，就是 bug（判据 722）')
        return 1
    print('  ✅ 未发现「组件根容器 padding + 调用处外层 padding」叠加')
    return 0


if __name__ == '__main__':
    sys.exit(main())
