#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
One More · 全面自查扫描器（拾海 2026-10-19）

奥森亲令：「其他地方也全面自查」「完美不仅是没错误，动画、细节什么的也要拉满」

这个脚本只做【缩小范围】：把可疑点全列出来，结论必须一条条核实。
（铁律：扫描器只缩小范围，结论必须抽样核实 —— 假警报至少 15 次）

用法：python3 tools/audit.py [--sev] [--check N]
"""
import os
import re
import sys
import io
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(ROOT, 'entry/src/main/ets')

# 界面模式会重写这三组常量 ⇒ 硬编码尺寸在 elder 模式下会与字号脱节
SIZE_CONSTS = ('FontSize', 'Space', 'Radius', 'Cell')

# 允许出现裸数字的地方（不算问题）
SKIP_FILES = (
    'core/Design.ets',      # 常量定义本身
    'core/UiMode.ets',      # 数值表本身
    'core/I18n.ets',        # 翻译表
    'core/GameI18n.ets',
)

CJK = re.compile(r'[一-鿿]')


def walk():
    for dirpath, _, files in os.walk(ETS):
        for fn in files:
            if fn.endswith('.ets') and not fn.endswith('.bak-20261013'):
                yield os.path.join(dirpath, fn)


def rel(p):
    return os.path.relpath(p, ROOT)


def read(p):
    try:
        return io.open(p, encoding='utf-8').read()
    except Exception:
        return ''


def line_of(text, idx):
    return text.count('\n', 0, idx) + 1


# ═══════════════════════════════════════════════════════════
# A1  @StorageProp 被赋值 —— 应该用 @StorageLink
#     后果：本地改了但 AppStorage 没改（或反过来），两处显示不一致
# ═══════════════════════════════════════════════════════════
def check_storage_prop(paths):
    out = []
    for p in paths:
        t = read(p)
        # 收集 @StorageProp 声明的变量名
        props = set(re.findall(r'@StorageProp\(\s*[\'"][^\'"]+[\'"]\s*\)\s+(\w+)', t))
        for name in props:
            for m in re.finditer(r'this\.' + name + r'\s*=(?!=)', t):
                out.append((rel(p), line_of(t, m.start()),
                            f'@StorageProp("{name}") 被赋值 —— 应用 @StorageLink') )
    return out


# ═══════════════════════════════════════════════════════════
# A2  界面里的硬编码中文（没走 t()）
#     判据：Text('中文...') 或 .text('中文...')
# ═══════════════════════════════════════════════════════════
def check_hardcoded_cjk(paths):
    out = []
    pat = re.compile(r"""\bText\(\s*'([^']*[\u4e00-\u9fff][^']*)'""")
    for p in paths:
        if any(s in p.replace('\\', '/') for s in SKIP_FILES):
            continue
        t = read(p)
        for m in pat.finditer(t):
            s = m.group(1)
            # 注释里的不算（Text 后面紧跟 // 不太可能），排除纯符号
            if CJK.search(s):
                out.append((rel(p), line_of(t, m.start()), f"Text('{s[:24]}') 未走 t()"))
    return out


# ═══════════════════════════════════════════════════════════
# A3  硬编码尺寸 —— 数字直接写在 fontSize/padding/width 里
#     判据：.fontSize(<数字>) 等；但 0/1/2 这种"零值/描边"不算
# ═══════════════════════════════════════════════════════════
def check_hardcoded_size(paths):
    out = []
    pat = re.compile(
        r'\.(fontSize|margin|padding|width|height|borderRadius)\(\s*(\d{2,}|"\d+")'
    )
    for p in paths:
        if any(s in p.replace('\\', '/') for s in SKIP_FILES):
            continue
        t = read(p)
        for m in pat.finditer(t):
            out.append((rel(p), line_of(t, m.start()),
                        f'.{m.group(1)}({m.group(2)}) 硬编码尺寸'))
    return out


# ═══════════════════════════════════════════════════════════
# A4  maxLines(1) 没配 textOverflow —— 溢出会被硬切
# ═══════════════════════════════════════════════════════════
def check_maxlines(paths):
    out = []
    for p in paths:
        t = read(p)
        lines = t.split('\n')
        for i, ln in enumerate(lines):
            if 'maxLines(1)' in ln or 'maxLines(2)' in ln:
                # 看后面 6 行内有没有 textOverflow
                tail = '\n'.join(lines[i:i + 7])
                if 'textOverflow' not in tail:
                    out.append((rel(p), i + 1, f'maxLines 缺 textOverflow'))
    return out


# ═══════════════════════════════════════════════════════════
# A5  相对性文案 —— "现在的样子""当前""目前"这类会在状态变化后失真
# ═══════════════════════════════════════════════════════════
def check_relative_wording(paths):
    out = []
    bad = ('现在的样子', '目前的样子', '当前的样子', 'Comme maintenant',
           'As it is now', 'Wie jetzt', 'Como ahora', '今のまま', '지금 그대로')
    for p in paths:
        t = read(p)
        for b in bad:
            for m in re.finditer(re.escape(b), t):
                ln = line_of(t, m.start())
                # 注释里提到不算
                src = t.split('\n')[ln - 1]
                if src.strip().startswith(('//', '*', '/*')):
                    continue
                out.append((rel(p), ln, f'相对性文案「{b}」'))
    return out


# ═══════════════════════════════════════════════════════════
# A6  可点元素里，onClick 没有任何触感/反馈
#
# ★★★ 2026-11-03（第 900 轮）**重写：原判据方向错了，222 处里真缺只有 3 处**。
#
#   旧判据：「`.onClick` **前** 12 行内既无 Haptics 也无 scale/opacity」
#   ⇒ 但按压反馈在本项目里的写法是：
#       .onClick(() => {
#         Haptics.tap();      // ← **在回调体内部**
#         ...
#       })
#     ⇒ 旧判据往**前**看，永远看不到它 ⇒ 假警率 98.6%（222 报，真缺 3）。
#
#   新判据（两条都要满足才记一处）：
#     ① `.onClick(...)` 的**回调体内部**既无 `Haptics.` / `animateTo(` / `Pressed`
#     ② `.onClick` 之前的一段属性链里无 `.stateStyles(` / `.focusBox(` / `pressed`
#   ⇒ 改后：1221 个 onClick 里只报 **0 处**（3 处真缺已在第 899 轮补上）。
#
#   ⚠️ 光看"前 12 行"和"回调体"的区别，就是 1.35% 与 98.6% 的差别（判据 253）。
# ═══════════════════════════════════════════════════════════
def _paren_end(src, i, limit):
    """从 src[i]（必须是 '('）出发，返回配平后的右括号下标；找不到返回 -1。

    ★ 2026-11-03（判据 243）：用真正的括号配平，不用 `[^}]*` 这类正则。
    正确处理字符串字面量与行注释。
    """
    if i < 0 or i >= limit or src[i] != '(':
        return -1
    depth = 0
    j = i
    while j < limit:
        c = src[j]
        if c == '/' and j + 1 < limit and src[j + 1] == '/':
            k = src.find('\n', j)
            j = limit if k < 0 else k
            continue
        if c in ('"', "'"):
            q = c
            j += 1
            while j < limit:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == q:
                    j += 1
                    break
                j += 1
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def check_click_feedback(paths):
    out = []
    import re as _re
    for p in paths:
        t = read(p)
        for m in _re.finditer(r'\.onClick\s*\(', t):
            oi = t.find('(', m.start())
            ci = _paren_end(t, oi, len(t))
            if ci < 0:
                continue
            body = t[oi + 1:ci]
            # ① 回调体内部有没有反馈
            if ('Haptics.' in body or 'animateTo(' in body or 'Pressed' in body):
                continue
            # ② 属性链上有没有状态驱动的视觉反馈
            head = t[max(0, m.start() - 1500):m.start()]
            if _re.search(r'\.stateStyles\(|\.focusBox\(|pressed', head):
                continue
            out.append((rel(p), t[:m.start()].count('\n') + 1, '可点元素缺按下反馈'))
    return out



# ═══════════════════════════════════════════════════════════
# A11 版本号一致性 —— app.json5 的 versionName 必须等于 About.VERSION
#     （两处不一致 ⇒ 设置页显示的版本和商店里的对不上）
# ═══════════════════════════════════════════════════════════
def check_version(paths):
    out = []
    appj = os.path.join(ROOT, 'AppScope/app.json5')
    about = os.path.join(ETS, 'core/About.ets')
    aj = read(appj)
    ab = read(about)
    m1 = re.search(r'"versionName"\s*:\s*"([^"]+)"', aj)
    m2 = re.search(r"VERSION:\s*string\s*=\s*'([^']+)'", ab)
    if m1 and m2 and m1.group(1) != m2.group(1):
        out.append(('AppScope/app.json5',
                    int(aj[:m1.start()].count('\n')) + 1,
                    'versionName=%s ≠ About.VERSION=%s' % (m1.group(1), m2.group(1))))
    return out


def main():
    args = sys.argv[1:]
    only = None
    if '--check' in args:
        only = args[args.index('--check') + 1]

    paths = list(walk())
    checks = [
        ('A1 @StorageProp 被赋值', check_storage_prop),
        ('A2 硬编码中文', check_hardcoded_cjk),
        ('A3 硬编码尺寸', check_hardcoded_size),
        ('A4 maxLines 缺 textOverflow', check_maxlines),
        ('A5 相对性文案', check_relative_wording),
        ('A6 可点元素缺反馈', check_click_feedback),
        ('A11 版本号一致性', check_version),
    ]

    print('=' * 62)
    print('One More · 全面自查   （%d 个 .ets 文件）' % len(paths))
    print('=' * 62)

    total = 0
    agg = defaultdict(list)
    for name, fn in checks:
        if only and not name.startswith(only):
            continue
        rows = fn(paths)
        total += len(rows)
        for r in rows:
            agg[r[0]].append((name, r[1], r[2]))
        print('\n【%s】%d 处' % (name, len(rows)))
        if rows:
            for f, ln, msg in rows[:12]:
                print('   %-46s %5d  %s' % (f, ln, msg))
            if len(rows) > 12:
                print('   … 另有 %d 处（见下方按文件汇总）' % (len(rows) - 12))

    print('\n' + '=' * 62)
    print('按文件汇总（问题最多的前 12 个）')
    print('=' * 62)
    for f, rows in sorted(agg.items(), key=lambda kv: -len(kv[1]))[:12]:
        print('   %-50s %3d 处' % (f, len(rows)))
        for name, ln, msg in rows[:3]:
            print('        %s  %s' % (name.split()[0], msg))

    print('\n合计 %d 处待核实' % total)


if __name__ == '__main__':
    main()
