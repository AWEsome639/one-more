#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ets_parse.py —— 给所有「代码结构检测器」用的共用解析工具
================================================================
来历（判据 243，第 889 轮）：
  我在三个不同的检测器里，犯了同一个错 —— **用正则解析嵌套结构**：
    ① 第 873 轮：`in blob`      —— 子串匹配，无边界
    ② 第 882 轮：链式解析        —— 遇 `if {` 就停
    ③ 第 889 轮：`[^}]*`        —— 遇第一个 `}` 就停
  三次都在问「这段代码里有没有 X」，三次都因为**不知道块的边界**答错。

  ⇒ 判据 243：**要么用真正的括号配平（栈），要么只做行级判断（不跨行）；
     绝不用 `[^}]*` 这类"非贪婪到第一个 `}`"的写法。**

本模块提供三样东西（都是纯函数，无副作用）：
  ① `match_paren(src, i)`   —— 从 `src[i]` 的 `(` / `{` / `[` 出发，返回配平后的下标
  ② `strip_comments(src)`   —— 去掉注释（保留换行，行号不变）
  ③ `iter_blocks(src, opener)` —— 迭代所有 `Text(` / `Button(` 这类调用的完整块

用法：
  import sys; sys.path.insert(0, '工具')
  from ets_parse import match_paren, strip_comments

  src = open('x.ets').read()
  code = strip_comments(src)          # 行号不变
  i = code.find('static tap(')
  end = match_paren(code, code.index('{', i))   # ← 真正配平的终点
  body = code[i:end+1]
"""
import re

PAIRS = {'(': ')', '{': '}', '[': ']'}


def match_paren(src, i):
    """从 `src[i]`（必须是 `(` / `{` / `[`）出发，返回配平的右括号下标。

    正确处理：字符串字面量（'...' / "..." / `...`）、行注释 //、块注释 /* */。
    找不到配平 ⇒ 返回 -1。

    ★ 这就是判据 243 说「30 行的 match_paren」—— 它比任何正则都可靠。
    """
    if i < 0 or i >= len(src):
        return -1
    op = src[i]
    cl = PAIRS.get(op)
    if cl is None:
        return -1

    depth = 0
    j = i
    n = len(src)
    while j < n:
        c = src[j]
        # 行注释
        if c == '/' and j + 1 < n and src[j + 1] == '/':
            k = src.find('\n', j)
            j = n if k < 0 else k
            continue
        # 块注释
        if c == '/' and j + 1 < n and src[j + 1] == '*':
            k = src.find('*/', j + 2)
            j = n if k < 0 else k + 2
            continue
        # 字符串字面量
        if c in ('"', "'", '`'):
            quote = c
            j += 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == quote:
                    j += 1
                    break
                j += 1
            continue
        if c == op:
            depth += 1
        elif c == cl:
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def strip_comments(src):
    """去掉 `//` 与 `/* */` 注释，**保留换行**（行号不变）。

    ★ 这样后续所有行级判断的行号仍然对得上原文件。
    """
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            k = src.find('\n', i)
            if k < 0:
                break
            i = k            # 保留那个换行
            continue
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            k = src.find('*/', i + 2)
            if k < 0:
                break
            # 用等量换行替换，保持行号
            seg = src[i:k + 2]
            out.append('\n' * seg.count('\n'))
            i = k + 2
            continue
        if c in ('"', "'", '`'):
            quote = c
            out.append(c)
            i += 1
            while i < n:
                out.append(src[i])
                if src[i] == '\\' and i + 1 < n:
                    out.append(src[i + 1])
                    i += 2
                    continue
                if src[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def iter_blocks(src, opener_re, with_attrs=True):
    """迭代所有匹配 `opener_re` 的调用，返回 (start, end, text)。

    `opener_re` 例：r'\\bText\\s*\\('  /  r'\\bButton\\s*\\('
    `with_attrs=True` 时，`end` 会继续吃掉后面的 `.xxx(...)` 属性链
    （遇到 `}` 或 `,` 或非 `.` 开头的新行就停）。

    ★ 这就是「只做行级判断」与「上栈」之间的正确做法：
      用 `match_paren` 找到调用的右括号，再按规则向后吃属性链。
    """
    for m in opener_re.finditer(src):
        open_i = src.find('(', m.start())
        if open_i < 0:
            continue
        close_i = match_paren(src, open_i)
        if close_i < 0:
            continue
        end = close_i
        if with_attrs:
            j = close_i + 1
            n = len(src)
            while j < n:
                while j < n and src[j] in ' \t':
                    j += 1
                if j < n and src[j] == '\n':
                    k = j + 1
                    while k < n and src[k] in ' \t':
                        k += 1
                    if k < n and src[k] == '.':
                        j = k
                        continue
                    break
                if j < n and src[j] == '.':
                    while j < n and src[j] != '\n':
                        j += 1
                    continue
                break
            end = j
        yield (m.start(), end, src[m.start():end])


if __name__ == '__main__':
    # 自检：三个曾经误报的场景
    a = "static tap(): void { if (x) { return; } Sound.play(1); }"
    i = a.index('{')
    e = match_paren(a, i)
    print('① 嵌套大括号：%s' % ('✅' if e == len(a) - 1 else '❌'))

    b = "Text(a).maxLines(1); if (c) { Text(b).maxLines(2); }"
    print('② 条件块：需要调用方按 match_paren 分段（本模块提供工具）')

    c = "x = 'a}b'; y = 1;"
    e2 = match_paren("{" + c + "}", 0)
    print('③ 字符串里的 } 被跳过：%s' % ('✅' if e2 == len(c) + 1 else '❌'))

    d = "// } not a brace\n{ a }"
    e3 = match_paren(d, d.index('{'))
    print('④ 注释里的 } 被跳过：%s' % ('✅' if e3 == len(d) - 1 else '❌'))
