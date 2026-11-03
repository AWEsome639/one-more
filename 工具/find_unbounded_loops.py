#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
主线程阻塞风险扫描（2026-10-23）
================================

来历：
  真机上「倒水排序」切到困难档时进程直接消失，日志只有 onProcessDied。
  根因是 freshDeal() 最多试 60 次 × solvable(16 次 × 160 步)，
  5 色时把 UI 线程占死 ⇒ 系统判 ANR ⇒ 杀进程。

  这条教训推广成规矩：
    **任何在主线程上跑的搜索，都必须有时间上限。**
    出题、提示、AI 走子 —— 一个都不能无限期占着 UI 线程。

扫描三类风险：
  ① while 循环里没有计数器上限
  ② for 循环上界是"看起来很大"的常量（≥ 20）
  ③ 函数体里有递归自调用，且没有深度参数
"""
import io, os, re, sys

GAMES = '/Users/a0000/dev/yiju/entry/src/main/ets/games'

def strip_comments(s):
    out, i, n = [], 0, len(s)
    while i < n:
        if s.startswith('//', i):
            j = s.find('\n', i); i = n if j < 0 else j
        elif s.startswith('/*', i):
            j = s.find('*/', i + 2); i = n if j < 0 else j + 2
        elif s[i] in ('"', "'", '`'):
            q = s[i]; i += 1
            while i < n:
                if s[i] == '\\': i += 2; continue
                if s[i] == q: i += 1; break
                i += 1
        else:
            out.append(s[i]); i += 1
    return ''.join(out)

def find_funcs(code):
    """粗切函数体：从 `private xxx(...) {` 或 `function xxx(...) {` 到配对的 }"""
    funcs = []
    for m in re.finditer(r'(?:private\s+|function\s+)([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)[^{]*\{', code):
        name = m.group(1)
        start = m.end()
        depth, i = 1, start
        while i < len(code) and depth > 0:
            if code[i] == '{': depth += 1
            elif code[i] == '}': depth -= 1
            i += 1
        funcs.append((name, code[start:i]))
    return funcs

def analyze(path):
    src = io.open(path, encoding='utf-8').read()
    code = strip_comments(src)
    hits = []
    for name, body in find_funcs(code):
        # ① while 无计数上限
        for m in re.finditer(r'while\s*\(([^)]*)\)\s*\{', body):
            cond = m.group(1)
            # 带 < / > 比较且右值不是明显的常量小值，认为有界
            if not re.search(r'[<>]', cond):
                hits.append(('while-无界', name, cond.strip()[:40]))
        # ② for 上界是大常量
        for m in re.finditer(r'for\s*\([^;]*;\s*[^;]*<\s*(\d{2,})\s*;', body):
            if int(m.group(1)) >= 20:
                hits.append(('大常量循环', name, '< ' + m.group(1)))
        # ③ 递归自调用且没有 depth 参数
        head = re.search(r'\(([^)]*)\)', code[code.find(name):code.find(name)+200])
        params = head.group(1) if head else ''
        if re.search(r'\b%s\s*\(' % name, body) and 'depth' not in params and 'limit' not in params:
            hits.append(('递归无深度限制', name, params.strip()[:40]))
    return hits

def main():
    print('  ══ 主线程阻塞风险扫描\n')
    total = 0
    for fn in sorted(os.listdir(GAMES)):
        if not fn.endswith('.ets'):
            continue
        hits = analyze(os.path.join(GAMES, fn))
        if hits:
            total += len(hits)
            print('  %s' % fn)
            for kind, fname, detail in hits:
                print('     %-14s %-28s %s' % (kind, fname, detail))
    print('\n  合计 %d 处待人工判断（有界 ≠ 安全，还要看单次迭代多贵）' % total)

if __name__ == '__main__':
    main()
