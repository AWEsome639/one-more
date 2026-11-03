#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
尺寸陷阱扫描器 · 精确版（2026-10-23 第二期）

这是第二版的扫描器。第一版（audit_size_consts.py / 临时脚本）有两个毛病：

  ① **把注释和字符串当代码** —— 命中的 9 个里有 4 个是假的，
     因为 N 只出现在注释里（"原 N=6" 这种）。
  ② **按名字筛常量** —— 只认 N/CELLS/SIDE，漏掉了名字不同但值相同的常量
     （比如 `const TOTAL = 36` 配 `sizeNow(6)`）。

第二版改成：
  · 先用词法扫描把注释与字符串**替换成等长空白**（保留换行，行号不变），
    这样后面所有匹配都只看真正的代码；
  · 再**按值匹配**：任何模块级数值常量的值 == sizeNow 的基数，就算候选
    （名字不重要，值对上才重要）；
  · 最后检查这个常量在代码里被用来做
      ① for 循环上界  ② 数组长度  ③ 算术（尤其是除以它）
    三者任一 ⇒ 进候选清单。

⚠️ 这仍然是**候选清单**，不是结论。
   常量的语义可能就该是固定值；要人看一眼它是不是"本该跟着尺寸变"的那个量。
"""

import io
import os
import re

ROOT = '/Users/a0000/dev/yiju'
GAMES = os.path.join(ROOT, 'entry/src/main/ets/games')


def mask(src):
    """把注释和字符串替换成等长空白（保留换行），返回 masked。"""
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # 行注释
        if c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            if j < 0:
                j = n
            for k in range(i, j):
                out[k] = ' '
            i = j
            continue
        # 块注释
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        # 字符串（' " `）
        if c in ('"', "'", '`'):
            q = c
            j = i + 1
            while j < n:
                if src[j] == '\\' and j + 1 < n:
                    j += 2
                    continue
                if src[j] == q:
                    j += 1
                    break
                j += 1
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


SIZENOW = re.compile(r'GameDiff\.sizeNow\((\d+)\)')
CONST_NUM = re.compile(r'^\s*const\s+([A-Z][A-Z0-9_]*)\s*:\s*number\s*=\s*(\d+)\s*;', re.M)


def main():
    cands = []
    for f in sorted(os.listdir(GAMES)):
        if not f.endswith('.ets') or '.bak' in f:
            continue
        src = io.open(os.path.join(GAMES, f), encoding='utf-8', errors='ignore').read()
        bases = {int(x) for x in SIZENOW.findall(src)}
        if not bases:
            continue
        code = mask(src)                      # ★ 只看代码
        consts = {}
        for m in CONST_NUM.finditer(code):
            consts[m.group(1)] = int(m.group(2))
        hits = []
        for name, val in consts.items():
            if val not in bases:
                continue
            # ① for 循环上界
            in_loop = bool(re.search(
                r'for\s*\([^;]*;\s*[^;<]*<\s*' + re.escape(name) + r'\s*;', code))
            # ② 数组长度
            in_arr = bool(re.search(r'new\s+Array\s*(<[^>]*>)?\s*\(\s*' + re.escape(name), code))
            # ③ 除法（做分母）
            in_div = bool(re.search(r'/\s*' + re.escape(name) + r'\b', code)) or \
                     bool(re.search(re.escape(name) + r'\s*/', code))
            if in_loop or in_arr or in_div:
                hits.append((name, val, in_loop, in_arr, in_div))
        if hits:
            cands.append((f, bases, hits))

    print('  ══ 精确扫描（词法剥离 + 按值匹配）：\n')
    print('  命中 %d 个文件\n' % len(cands))
    for f, bases, hits in cands:
        print('  %s   sizeNow(%s)' % (f, ','.join(map(str, sorted(bases)))))
        for name, val, loop, arr, div in hits:
            tag = []
            if loop:
                tag.append('循环上界')
            if arr:
                tag.append('数组长度')
            if div:
                tag.append('当分母')
            print('     %-16s = %-4d  %s' % (name, val, ' + '.join(tag)))
        print()
    print('  ⚠️ 候选清单，不是结论。常量的语义可能就该是固定值。')


if __name__ == '__main__':
    main()
