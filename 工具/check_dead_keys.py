#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_dead_keys.py —— I18n 字典死条目检测器（第 2 版）
================================================================
为什么要有第 2 版（第 873 轮，判据 227）：
  第 1 版是一个临时脚本，跑出「22 条 0 引用的死 key」。
  抽查 4 条 —— **4 条全是活的**：
    · `'作者 '`（带尾随空格）≠ `"作者"`
    · `'成就解锁'` 包含 `"成就"`，但那是另一条 key
  ⇒ 判据 227：「删 0 引用的东西之前，先手工验证 3 条；
     3 条里有 1 条是活的 ⇒ 整个检测作废，**去改检测**而不是删条目。」

第 2 版怎么改：
  ① **字面量边界匹配**：只认 `'<key>'` / `"<key>"` 这种**完整字符串**，
     不再用 `in blob` 的子串判断。
  ② **容忍尾随/前导空格**：`'作者 '` 视为命中了 `"作者"`。
  ③ **容忍拼接**：`'解锁成就 ' + a` 这种，key 作为前缀也算命中。
  ④ **还查 TG/L/TN 的调用点**：不只查字面量，还查出现在 `L(` `TG(` `t(` 参数位置的。
  ⑤ **报告分三栏**：确认死 / 疑似活（变体命中） / 真死。

用法：
  python3 工具/check_dead_keys.py            # 全量
  python3 工具/check_dead_keys.py --limit 30

退出码：
  0 = 没有"确认死"的条目
  1 = 有"确认死"的条目（需人工再核）
  2 = 环境不可用
"""
import glob
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
I18N = os.path.join(ROOT, 'entry/src/main/ets/core/I18n.ets')


def load_keys():
    src = io.open(I18N, encoding='utf-8').read()
    # 顶层 key 形如：  "中文": { "ja": ... }
    return re.findall(r'^\s{2}"([^"]{2,80})":\s*\{', src, re.M)


def load_code():
    """所有 .ets 的非注释行（排除 I18n.ets 本身）。"""
    out = []
    for f in glob.glob(os.path.join(ROOT, 'entry/src/main/ets/**/*.ets'), recursive=True):
        if f.endswith('core/I18n.ets'):
            continue
        for l in io.open(f, encoding='utf-8').read().split('\n'):
            s = l.strip()
            if s.startswith('//') or s.startswith('*') or s.startswith('/*'):
                continue
            out.append(l)
    return '\n'.join(out)


def norm(s):
    """归一化：去掉所有空白（容忍尾随/前导/中间空格的差异）。"""
    return re.sub(r'\s+', '', s)


def main():
    args = sys.argv[1:]
    limit = 30
    if '--limit' in args:
        i = args.index('--limit')
        if i + 1 < len(args):
            limit = int(args[i + 1])

    if not os.path.exists(I18N):
        print('  ❌ 环境不可用：找不到 %s' % I18N)
        return 2

    keys = load_keys()
    code = load_code()
    code_norm = norm(code)
    # 所有字符串字面量（单引号/双引号）
    literals = set(re.findall(r"'([^'\\]*)'", code)) | set(re.findall(r'"([^"\\]*)"', code))
    lit_norm = {norm(x) for x in literals}

    print('  字典 key: %d ｜ 代码字面量: %d' % (len(keys), len(literals)))
    print()

    confirmed_dead = []
    variant_hit = []
    for k in keys:
        k_n = norm(k)
        # ① 归一化后精确等于某个字面量 ⇒ 命中
        if k_n in lit_norm:
            continue
        # ② 归一化后是某个字面量的前缀/被包含 ⇒ 变体命中（可能是拼接）
        hit = False
        for lit in lit_norm:
            if k_n and lit and (lit.startswith(k_n) or k_n in lit):
                hit = True
                break
        # ③ 归一化后在整段代码里出现 ⇒ 也算变体命中
        if not hit and k_n and k_n in code_norm:
            hit = True
        if hit:
            variant_hit.append(k)
        else:
            confirmed_dead.append(k)

    print('  ══ 三栏 ══')
    print('  ① 确认死（归一化后全项目找不到）: **%d 条**' % len(confirmed_dead))
    print('  ② 变体命中（带空格/被拼接/是子串）: **%d 条** ← **不删**' % len(variant_hit))
    print('  ③ 精确命中: %d 条' % (len(keys) - len(confirmed_dead) - len(variant_hit)))
    print()

    if confirmed_dead:
        print('  ① 清单（前 %d 条）：' % min(limit, len(confirmed_dead)))
        for k in confirmed_dead[:limit]:
            print('    %s' % k)
        if len(confirmed_dead) > limit:
            print('    …还有 %d 条' % (len(confirmed_dead) - limit))
        print()
        print('  ⚠️ 按判据 227：删之前必须手工验证 3 条。')
        print('     3 条里有 1 条是活的 ⇒ 回来改检测，不要删。')
        return 1

    print('  ✅ 没有"确认死"的条目')
    return 0


if __name__ == '__main__':
    sys.exit(main())
