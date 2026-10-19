#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
颜色对比度审计（拾海 2026-10-19）

为什么要有它：
  前几轮我靠「扫到浅色 + 扫到白字」猜对比度问题 —— 结果三次都是误报。
  正确的做法是：**只看同一元素上同时写了 fontColor 和 backgroundColor 的地方**，
  把两边都解析成 hex，算 WCAG 对比度。这样每一条都是真的能判定的。

判定标准（WCAG 2.1）：
  · 正文文字      ≥ 4.5 : 1   （< 18.66px bold 且 < 24px 都算正文）
  · 大字号文字    ≥ 3.0 : 1   （≥ 24px，或 ≥ 18.66px 且加粗）
  · 图形/界面元素 ≥ 3.0 : 1

本工具分三级报：
  🔴 严重  < 3.0                —— 任何字号都不合格
  🟠 正文不足 3.0–4.5 且字号 < 18.66px（未加粗） —— 低于 AA 正文标准
  🟡 提示    3.0–4.5 但字号够大或加粗 —— 按大字号标准是合格的

★ 2026-10-19 的结论（写在这里，免得以后再纠结）：
  六个强调色已从 Tailwind 500 档降到 600 档，🔴 归零。
  剩下的 🟠 几乎全是【按钮上的 16px 白字标签】(3.09–4.10)。
  试过 700 档：全部过 4.5，但 lime 变橄榄、amber 变褐，观感明显变沉 —— 离线渲染对比过。
  ⇒ 因此停在 600 档，作为**有意识的取舍**记录在此，不是遗漏。
  若要彻底过 AA，最省事的做法是把按钮标签字号提到 19px 加粗（即成为"大字号"），
  而不是继续压暗配色。

解析范围：
  · Palette.xxx            → Design.ets 里的色值
  · this.theme.xxx         → Theme 构造里的映射（浅色/深色各一套）
  · '#RRGGBB' / '#AARRGGBB' → 直读（带 alpha 的按叠加到背景处理不了，跳过并标注）

用法：python3 tools/contrast_audit.py [--top N] [--dir games|components|pages|all]
"""
import io
import os
import re
import sys

ETS = '/Users/a0000/dev/yiju/entry/src/main/ets'
DESIGN = os.path.join(ETS, 'core/Design.ets')


def hex_to_rgb(h):
    h = h.lstrip('#')
    if len(h) == 8:          # #AARRGGBB → 取后 6 位（alpha 另算不了，先按不透明处理并标注）
        h = h[2:]
    if len(h) != 6:
        return None
    try:
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    except ValueError:
        return None


def luminance(rgb):
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def load_palette():
    s = io.open(DESIGN, encoding='utf-8').read()
    pal = {}
    for name, val in re.findall(r"static readonly (\w+): string = '(#[0-9A-Fa-f]{6,8})'", s):
        pal[name] = val
    for name, val in re.findall(r"static (\w+): string = '(#[0-9A-Fa-f]{6,8})'", s):
        pal.setdefault(name, val)
    return pal


def load_theme_map():
    """Theme 构造里 this.x = isDark ? Palette.a : Palette.b 的映射"""
    s = io.open(DESIGN, encoding='utf-8').read()
    m = re.search(r'constructor\(isDark: boolean\) \{(.*?)\n  \}', s, re.S)
    if not m:
        return {}
    body = m.group(1)
    mp = {}
    for field, dark, light in re.findall(
            r'this\.(\w+) = isDark \? Palette\.(\w+) : Palette\.(\w+);', body):
        mp[field] = (dark, light)
    for field, light in re.findall(r'this\.(\w+) = Palette\.(\w+);', body):
        mp.setdefault(field, (light, light))
    return mp


def resolve(tok, pal, thememap, dark):
    """把一个颜色表达式解析成 hex；解析不了返回 None"""
    tok = tok.strip()
    m = re.fullmatch(r"'(#[0-9A-Fa-f]{6,8})'", tok)
    if m:
        return m.group(1)
    m = re.fullmatch(r'Palette\.(\w+)', tok)
    if m:
        return pal.get(m.group(1))
    # this.theme.x / this.theme().x / theme.x
    m = re.fullmatch(r"(?:this\.)?theme\(?\)?\.(\w+)", tok)
    if m:
        f = m.group(1)
        if f in thememap:
            d, l = thememap[f]
            key = d if dark else l
            return pal.get(key)
    return None


def main():
    top = 24
    if '--top' in sys.argv:
        top = int(sys.argv[sys.argv.index('--top') + 1])
    which = 'all'
    if '--dir' in sys.argv:
        which = sys.argv[sys.argv.index('--dir') + 1]

    pal = load_palette()
    thememap = load_theme_map()
    print('  Palette %d 色 ｜ Theme 映射 %d 项' % (len(pal), len(thememap)))

    subs = ['games', 'components', 'pages'] if which == 'all' else [which]
    rows = []

    for sub in subs:
        d = os.path.join(ETS, sub)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith('.ets') or '.bak' in fn:
                continue
            p = os.path.join(d, fn)
            lines = io.open(p, encoding='utf-8').read().split('\n')
            # 一个元素 = 从某行开始、连续以 '.' 开头的修饰链
            i = 0
            while i < len(lines):
                if not lines[i].lstrip().startswith('.'):
                    i += 1
                    continue
                j = i
                chain = []
                while j < len(lines) and (lines[j].lstrip().startswith('.') or j == i):
                    chain.append(lines[j])
                    j += 1
                block = '\n'.join(chain)
                fg = re.search(r'\.fontColor\(([^)]+)\)', block)
                bg = re.search(r'\.backgroundColor\(([^)]+)\)', block)
                if fg and bg:
                    fsz = re.search(r'\.fontSize\((FontSize\.\w+|\d+)\)', block)
                    bold = '.fontWeight(FontWeight.Bold)' in block
                    for dark in (False, True):
                        f = resolve(fg.group(1), pal, thememap, dark)
                        b = resolve(bg.group(1), pal, thememap, dark)
                        if f and b:
                            fa, ba = hex_to_rgb(f), hex_to_rgb(b)
                            if fa and ba:
                                rows.append((contrast(fa, ba), sub, fn, i + 1,
                                             fg.group(1).strip(), bg.group(1).strip(),
                                             'dark' if dark else 'light',
                                             fsz.group(1) if fsz else '', bold))
                i = j if j > i else i + 1

    rows.sort(key=lambda r: r[0])
    FS_PX = {'FontSize.hero': 36, 'FontSize.xxxl': 28, 'FontSize.xxl': 24, 'FontSize.xl': 20,
             'FontSize.lg': 18, 'FontSize.md': 16, 'FontSize.sm': 14, 'FontSize.xs': 13,
             'FontSize.xxs': 12, 'FontSize.micro': 10, 'FontSize.badge': 8}

    def is_large(fsname, bold):
        px = FS_PX.get(fsname)
        if px is None:
            try:
                px = int(fsname)
            except (TypeError, ValueError):
                return False
        return px >= 24 or (bold and px >= 18.66)

    bad = [r for r in rows if r[0] < 3.0]
    body_bad = [r for r in rows if 3.0 <= r[0] < 4.5 and not is_large(r[7], r[8])]
    hint = [r for r in rows if 3.0 <= r[0] < 4.5 and is_large(r[7], r[8])]
    print()
    print('  ══ 能判定字色×底色的元素：%d 条' % len(rows))
    print('     🔴 严重（<3.0，任何字号都不合格）: %d 条' % len(bad))
    print('     🟠 正文不足（3.0–4.5 且字号不够大）: %d 条' % len(body_bad))
    print('     🟡 提示（3.0–4.5 但算大字号，合格）: %d 条' % len(hint))
    print('     ✅ 直接过 4.5 : %d 条' % (len(rows) - len(bad) - len(body_bad) - len(hint)))
    print()
    print('  ══ 最差的 %d 条：' % min(top, len(bad)))
    print('  %-6s %-7s %-30s %-24s %s' % ('对比度', '模式', '位置', '字色', '底色'))
    seen = set()
    shown = 0
    for r in bad:
        cr, sub, fn, ln, fg, bg, mode = r
        key = (fn, ln)
        if key in seen:
            continue
        seen.add(key)
        print('  %-6.2f %-7s %-30s %-24s %s' % (cr, mode, '%s:%d' % (fn, ln), fg[:22], bg[:22]))
        shown += 1
        if shown >= top:
            break

    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
