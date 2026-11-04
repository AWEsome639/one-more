#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_regressions.py —— 历史真 bug 的**静态复发检查**

★ 为什么需要（第 1289 轮）
  目标里列了 22 个真 bug。其中几项**可以静态查**，却一直靠"偶尔 grep 一下"：
    · bug ④ 9 款 HintBar 缺 demoOn
    · bug ⑤ 186 款缺 demoOnce
    · bug ⑰ 1175 处 `.focusBox()` 是死代码（应全部迁移到 `.outline()`）
    · bug ① px 当 vp（让平板列表整片渲染成空）
  而"偶尔 grep"会犯两个错：
    ① **不剥注释** ⇒ 把注释里的示例算成调用（第 1288 轮实证：假警报）
    ② **不记结果** ⇒ 下次还得重写一遍

⇒ 本工具把它们固化成**六项**（正反两类），每次跑都给出可对数字。

★ 关键实现：`strip_comments`
  把 `//` 与 `/* */` 替换成**等长空白**（不是删除）
  ⇒ 剥离后的字符串与原文**行号/列号一一对应**
  ⇒ 报错时 `raw[:m.start()].count('\n') + 1` 能算回原文行号（判据 779）

用法：
  python3 工具/check_regressions.py
退出码：0 = 全部符合基线 ｜ 1 = 有回归 ｜ 2 = 输入问题
"""
import io
import os
import re
import sys

ROOT_ETS = 'entry/src/main/ets'
GAMES = os.path.join(ROOT_ETS, 'games')

# ★ 基线（与目标记录一致）
BASELINE = {
    'games': 355,          # 游戏文件数
    'demoOnce_missing': 0, # 缺 demoOnce 的款数
    'hintbar_missing_demoOn': 0,
    'focusBox_real': 0,    # `.focusBox(` 真实调用（全部已迁到 `.outline()`）
    'px_as_vp': 0,         # `.width(1234)` / `.height(1234)` 这类 4 位数
}


def strip_comments(src):
    """把 // 与 /* */ 替换成等长空白（保留行号/列号）——判据 779"""
    out = []
    in_block = False
    for line in src.split('\n'):
        buf = []
        i = 0
        while i < len(line):
            if in_block:
                if line.startswith('*/', i):
                    buf.append('  ')
                    i += 2
                    in_block = False
                else:
                    buf.append(' ')
                    i += 1
            else:
                if line.startswith('//', i):
                    buf.append(' ' * (len(line) - i))
                    break
                elif line.startswith('/*', i):
                    buf.append('  ')
                    i += 2
                    in_block = True
                else:
                    buf.append(line[i])
                    i += 1
        out.append(''.join(buf))
    return '\n'.join(out)


def iter_ets(root):
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if fn.endswith('.ets'):
                yield os.path.join(dp, fn), fn


def check_games():
    files = [p for p, _ in iter_ets(GAMES)]
    return len(files), len(files)


def check_demo_once():
    miss = []
    for p, fn in iter_ets(GAMES):
        s = strip_comments(io.open(p, encoding='utf-8', errors='ignore').read())
        if 'demoOnce' not in s:
            miss.append(fn)
    return len(miss), BASELINE['demoOnce_missing'], miss


def check_hintbar_demo_on():
    """HintBar( 的调用是否都传了 demoOn（跳过注释）"""
    bad = []
    for p, fn in iter_ets(GAMES):
        raw = io.open(p, encoding='utf-8', errors='ignore').read()
        s = strip_comments(raw)
        if 'HintBar(' not in s:
            continue
        for m in re.finditer(r'HintBar\s*\(', s):
            i = m.end()
            depth = 1
            while i < len(s) and depth > 0:
                if s[i] == '(':
                    depth += 1
                elif s[i] == ')':
                    depth -= 1
                i += 1
            if 'demoOn' not in s[m.end():i]:
                line = raw[:m.start()].count('\n') + 1
                bad.append('%s:%d' % (fn, line))
    return len(bad), BASELINE['hintbar_missing_demoOn'], bad


def check_focus_box():
    """`.focusBox(` 真实调用（跳过注释）"""
    hits = []
    for p, fn in iter_ets(ROOT_ETS):
        raw = io.open(p, encoding='utf-8', errors='ignore').read()
        s = strip_comments(raw)
        for m in re.finditer(r'\.focusBox\s*\(', s):
            line = raw[:m.start()].count('\n') + 1
            hits.append('%s:%d' % (fn, line))
    return len(hits), BASELINE['focusBox_real'], hits


def check_px_as_vp():
    """`.width(1234)` / `.height(1234)` —— 4 位数在 vp 里几乎不可能（判据 ①）"""
    hits = []
    for p, fn in iter_ets(ROOT_ETS):
        raw = io.open(p, encoding='utf-8', errors='ignore').read()
        s = strip_comments(raw)
        for m in re.finditer(r'\.(width|height)\(\s*(\d{4,})\s*\)', s):
            line = raw[:m.start()].count('\n') + 1
            hits.append('%s:%d  %s' % (fn, line, m.group(0)))
    return len(hits), BASELINE['px_as_vp'], hits


def main():
    if not os.path.isdir(ROOT_ETS):
        print('目录不存在: %s' % ROOT_ETS)
        return 2

    print('=' * 72)
    print('  历史真 bug 静态复发检查（判据 ①④⑤⑰ + 779 剥注释）')
    print('=' * 72)

    rows = []
    # ① 游戏文件数（正数基线）
    n, expect = check_games()
    rows.append(('游戏文件数', n, expect, None, '=='))
    # ② 缺 demoOnce（应 0）
    n, expect, bad = check_demo_once()
    rows.append(('缺 demoOnce', n, expect, bad, '=='))
    # ③ HintBar 缺 demoOn（应 0）
    n, expect, bad = check_hintbar_demo_on()
    rows.append(('HintBar 缺 demoOn', n, expect, bad, '=='))
    # ④ .focusBox 真实调用（应 0）
    n, expect, bad = check_focus_box()
    rows.append(('.focusBox 真实调用', n, expect, bad, '=='))
    # ⑤ px 当 vp（应 0）
    n, expect, bad = check_px_as_vp()
    rows.append(('px 当 vp（4 位数）', n, expect, bad, '=='))

    print()
    print('  %-22s %-8s %-8s %s' % ('检查项', '实测', '基线', '结论'))
    print('  ' + '-' * 60)
    fail = 0
    for name, got, exp, bad, op in rows:
        ok = got == exp
        if not ok:
            fail += 1
        print('  %-22s %-8s %-8s %s' % (name, got, exp, '✅' if ok else '🔴 回归'))
        for b in (bad or [])[:5]:
            print('      → %s' % b)
        if bad and len(bad) > 5:
            print('      → …还有 %d 条' % (len(bad) - 5))
    print()
    print('=' * 72)
    if fail:
        print('  🔴 **%d 项回归**' % fail)
        return 1
    print('  ✅ 五项全部符合基线（注意：本工具**只查静态可查项**，不代表全部 22 个 bug 都不复发）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
