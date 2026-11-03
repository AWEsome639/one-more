#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
尺寸口径不一致扫描器（2026-10-23 第二轮）
==========================================

为什么要有这一版：
  前一轮我用 find_size_traps.py 找「按值匹配的常量」，
  然后**人工判语义**，把 5 个候选判成"误报"。
  复审发现其中 3 个是真 bug（GPathFinder / GPaperFolding / GEinsteinRiddle）。

  判错的原因很具体：我读的是**函数内部**，看它自不自洽。
  但真 bug 都长这样：
      A 处（数据构造）用 diffTotal
      B 处（消费/读取）用常量
    ⇒ 两个函数各自都自洽，只是尺寸口径不同。

  ⇒ 所以要扫的不是"常量"，而是**同一个数组的两端用了不同的尺寸来源**。

判据（三条线，必须同源）：
  ① 建：new Array<...>(EXPR) 的 EXPR
  ② 读：下标算式 r * EXPR + c 里的 EXPR
  ③ 界：for (... < EXPR) 的 EXPR

  若同一个数组名，在建/读两侧分别出现 diffTotal 与常量 ⇒ 高危。
"""
import io, os, re, sys

GAMES = '/Users/a0000/dev/yiju/entry/src/main/ets/games'
SIZE_FUN = re.compile(r'GameDiff\.(sizeNow|livesNow)\((\d+)\)')

def strip_comments(s):
    """剥掉注释与字符串，避免"注释里的数字"污染（这已经坑过我两次）"""
    out = []
    i, n = 0, len(s)
    while i < n:
        if s.startswith('//', i):
            j = s.find('\n', i)
            i = n if j < 0 else j
        elif s.startswith('/*', i):
            j = s.find('*/', i + 2)
            i = n if j < 0 else j + 2
        elif s[i] in ('"', "'", '`'):
            q = s[i]
            i += 1
            while i < n:
                if s[i] == '\\':
                    i += 2; continue
                if s[i] == q:
                    i += 1; break
                i += 1
        else:
            out.append(s[i]); i += 1
    return ''.join(out)

def module_consts(code):
    """模块级 number 常量：用于当另一个尺寸来源"""
    out = {}
    for m in re.finditer(r'^const ([A-Z][A-Z0-9_]*): number = (\d+);', code, re.M):
        out[m.group(1)] = int(m.group(2))
    return out

def analyze(path):
    src = io.open(path, encoding='utf-8').read()
    code = strip_comments(src)
    hits = []

    size_m = SIZE_FUN.search(code)
    uses_diff = 'diffTotal' in code and not code.count('diffTotal') == code.count('private diffTotal')
    if not size_m or not uses_diff:
        return hits, None

    consts = module_consts(code)
    if not consts:
        return hits, None

    # ① 建：new Array<...>(EXPR)
    allocs = []
    for m in re.finditer(r'new Array<[^>]+>\(([^)]*)\)', code):
        expr = m.group(1)
        if 'diffTotal' in expr:
            allocs.append(('diffTotal', expr.strip()[:40]))
        else:
            for k in consts:
                if re.search(r'\b%s\b' % k, expr):
                    allocs.append((k, expr.strip()[:40])); break

    # ② 读：下标算式 r * EXPR + c  /  EXPR * r + c
    idx = []
    for m in re.finditer(r'\[\s*([A-Za-z_][A-Za-z0-9_]*)\s*\*\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\+', code):
        idx.append(m.group(2))
    for m in re.finditer(r'\[\s*([A-Za-z_][A-Za-z0-9_.]*)\s*\*\s*([A-Za-z_][A-Za-z0-9_]*)\s*\+', code):
        idx.append(m.group(1))
    idx_kind = set()
    for e in idx:
        if 'diffTotal' in e:
            idx_kind.add('diffTotal')
        elif e in consts:
            idx_kind.add(e)

    # ③ 界：for (... < EXPR)
    bounds = set()
    for m in re.finditer(r'for \([^;]*;\s*[a-zA-Z_]+\s*<\s*([A-Za-z_][A-Za-z0-9_.]*)\s*;', code):
        e = m.group(1)
        if 'diffTotal' in e:
            bounds.add('diffTotal')
        elif e in consts:
            bounds.add(e)

    # 判定：建/读/界三侧是否出现了"两个不同来源"
    sources = set()
    for k, _ in allocs: sources.add(k)
    sources |= idx_kind
    sources |= bounds
    if 'diffTotal' in sources and len(sources) > 1:
        hits.append(('MIX', sorted(sources),
                     [(k, e) for k, e in allocs][:4],
                     sorted(idx_kind), sorted(bounds)))
    return hits, size_m.group(2)

def main():
    print('  ══ 尺寸口径不一致扫描（建/读/界 三条线是否同源）\n')
    risky, clean = [], []
    for fn in sorted(os.listdir(GAMES)):
        if not fn.endswith('.ets'):
            continue
        p = os.path.join(GAMES, fn)
        hits, base = analyze(p)
        if hits:
            risky.append((fn, hits, base))
        elif base is not None:
            clean.append(fn)

    print('  高危 %d 个文件：' % len(risky))
    for fn, hits, base in risky:
        print('     %-28s sizeNow 基准 %s' % (fn, base))
        for kind, sources, allocs, ik, bk in hits:
            print('        来源混用: %s' % ', '.join(sources))
            if allocs:
                print('        建: %s' % '; '.join('%s→%s' % a for a in allocs))
            print('        读的步长: %s ｜ 循环界: %s' % (ik or '-', bk or '-'))
    print('\n  用 diffTotal 但口径一致 %d 个文件' % len(clean))

if __name__ == '__main__':
    main()
