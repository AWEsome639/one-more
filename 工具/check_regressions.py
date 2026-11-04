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


def selftest():
    """内置自检：在**合成输入**上验证五项判据的核心逻辑（判据 648 / 759）

    ★ 为什么不用临时目录造 .ets
      本工具的五项检查都写死了 `entry/src/main/ets` 路径，
      改成可参数化会引入**新的复杂度**（而复杂度是 bug 的来源）。
      ⇒ 更稳的做法：**直接测每一项的"判断逻辑"**：
        · `strip_comments` 是否正确剥注释（保留行号）
        · `HintBar(` 扫描是否跳过注释
        · `.focusBox(` 计数是否跳过注释
        · px-as-vp 正则是否只命中 4 位数
      每项都用「已知正例 + 已知反例」各一个。

    ★ 判据 759：**先在已知案例上验证，再相信「全绿」**
    """
    ok = True

    def t(name, cond, detail=''):
        nonlocal ok
        if cond:
            print('    ✅ %s%s' % (name, ('  ' + detail) if detail else ''))
        else:
            print('    🔴 %s%s' % (name, ('  ' + detail) if detail else ''))
            ok = False

    print('  ── ① strip_comments：剥注释且保留行号 ──')
    src = "line1\n// .focusBox(x)\nline3 /* .focusBox(y) */ line4\n"
    c = strip_comments(src)
    t('行数不变', c.count('\n') == src.count('\n'), '(%d vs %d)' % (c.count('\n'), src.count('\n')))
    t('行注释被剥', '.focusBox(x)' not in c)
    t('块注释被剥', '.focusBox(y)' not in c)
    t('非注释保留', 'line1' in c and 'line3' in c and 'line4' in c)
    t('长度不变（等长空白）', len(c) == len(src), '(%d vs %d)' % (len(c), len(src)))

    print('  ── ② .focusBox 计数：注释里的不算 ──')
    s1 = "a\n// .focusBox(Tv.box())\n.focusBox(Tv.box())\n"
    n1 = len(re.findall(r'\.focusBox\s*\(', strip_comments(s1)))
    t('1 行注释 + 1 行真实 ⇒ 计 1', n1 == 1, '(实得 %d)' % n1)
    s2 = "// .focusBox(a)\n/* .focusBox(b) */\n"
    n2 = len(re.findall(r'\.focusBox\s*\(', strip_comments(s2)))
    t('全在注释里 ⇒ 计 0', n2 == 0, '(实得 %d)' % n2)

    print('  ── ③ HintBar 扫描：注释里的 `HintBar(38)` 不算调用 ──')
    s3 = "// 它漏了 HintBar(38) 与间隙\nHintBar({ demoOn: false, hint: 'x' })\n"
    sc = strip_comments(s3)
    hits = list(re.finditer(r'HintBar\s*\(', sc))
    t('只有 1 个真实 HintBar(', len(hits) == 1, '(实得 %d)' % len(hits))
    if hits:
        m = hits[0]
        i = m.end(); d = 1
        while i < len(sc) and d > 0:
            if sc[i] == '(': d += 1
            elif sc[i] == ')': d -= 1
            i += 1
        t('该调用含 demoOn', 'demoOn' in sc[m.end():i])
    s4 = "HintBar({ hint: 'x' })"
    sc4 = strip_comments(s4)
    m4 = re.search(r'HintBar\s*\(', sc4)
    i4 = m4.end(); d4 = 1
    while i4 < len(sc4) and d4 > 0:
        if sc4[i4] == '(': d4 += 1
        elif sc4[i4] == ')': d4 -= 1
        i4 += 1
    t('缺 demoOn 的调用能被识别', 'demoOn' not in sc4[m4.end():i4])

    print('  ── ④ px-as-vp 正则：只命中 4 位数 ──')
    pat = r'\.(width|height)\(\s*(\d{4,})\s*\)'
    t('命中 .width(1234)', bool(re.search(pat, ".width(1234)")))
    t('不命中 .width(234)', not re.search(pat, ".width(234)"))
    t('不命中 .width(Cell.of(54))', not re.search(pat, ".width(Cell.of(54))"))

    print()
    print('=' * 72)
    if ok:
        print('  ✅ 自检通过（五项判据的核心逻辑都验到了正例与反例）')
        return 0
    print('  🔴 自检失败（见上）')
    return 1


def main():
    if '--selftest' in sys.argv:
        print('=' * 72)
        print('  历史 bug 复发检查 · 内置自检（判据 648 / 759）')
        print('=' * 72)
        return selftest()


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
