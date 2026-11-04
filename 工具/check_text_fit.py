#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文字能不能放下 —— 按判据 589 把「放不下」的风险量化排序

★ 为什么要有这个（第 1212 轮）
  第 1210 轮在 195×195 上**看图**才发现「AI 代打」被截成「AI ...」，
  而 `dump` 里 `text` 是完整的（判据 588）。
  第 1211 轮做算式时，算式说「可用 51.5 vp > 需要 47.6 vp ⇒ 勉强够」，
  **实测却被截**（判据 589）：
    · 按钮内 padding 不在算式里
    · 中文实际字宽 > 1.0em
    · ArkUI 的省略号触发阈值不是「刚好放不下」，而是「余量不足就截」
  ⇒ 结论：**算式只能筛候选，不能下「够」的结论**；
    判「够」的门槛要 **≥ 1.3 倍余量**。

  ⇒ 本工具就做这一件事：把每个带文字的控件，
    在六种屏幕宽度下算 `avail / need`，按比值升序排，
    把落在 **1.0~1.3** 的列为「必须看图」，< 1.0 的列为「会截」。

★ 适用范围（必须声明，判据 507）
  · 只扫**字面量**标签（`TG('…')` / `this.t('…','…')` / `Button('…')`）。
    变量拼接、`${}` 模板串**不扫** ⇒ 报 skipped 计数。
  · 宽度模型是**保守近似**：中文 1.0em、拉丁 0.55em、空格 0.30em；
    按钮内 padding 按 12 vp 估；行内 `space` 按 12 vp 估。
    ⇒ 因此**只能用来排序**，结论一律以截图为准（判据 588/589）。
  · 不认识 `layoutWeight` 之外的布局（如 Grid 内多列、自定义 `Row` 宽度）。
    ⇒ 对这类控件本工具**给不出可用宽度**，会报 skipped。

用法：
  python3 工具/check_text_fit.py            # 全项目扫
  python3 工具/check_text_fit.py <file.ets> # 只扫一个文件

退出码：0 = 没有 < 1.0 的；1 = 有 < 1.0（会截）；2 = 有 1.0~1.3（必须看图）
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'entry/src/main/ets')

# 六种屏幕（仅宽度影响；高度不影响横向放不放得下）
SCREENS = [('195×195', 195), ('233×233', 233), ('440×744', 440),
           ('800×1280', 800), ('853×533', 853), ('960×540', 960)]

FONT_SM = 14.0          # FontSize.sm（按钮默认基准）
BTN_PAD = 24.0          # 按钮左右内 padding 合计（保守）
ROW_GAP = 12.0          # Row 内 space
PAGE_PAD = 32.0         # 页面左右 padding 合计

SAFE = 1.30             # 判「够」的余量门槛（判据 589）
CRITICAL = 1.00         # 低于它就判「会截」


def strip_comments(s):
    out = []
    inb = False
    for raw in s.split('\n'):
        line = raw
        if inb:
            i = line.find('*/')
            if i < 0:
                out.append('')
                continue
            line = line[i + 2:]
            inb = False
        while True:
            i = line.find('/*')
            if i < 0:
                break
            j = line.find('*/', i + 2)
            if j < 0:
                line = line[:i]
                inb = True
                break
            line = line[:i] + line[j + 2:]
        i = line.find('//')
        if i >= 0:
            line = line[:i]
        out.append(line)
    return '\n'.join(out)


def em_width(t):
    """估算文字宽度（单位 em）。中文 1.0、拉丁 0.55、空格 0.30、emoji 1.2"""
    if not t:
        return 0.0
    w = 0.0
    for ch in t:
        o = ord(ch)
        if 0x2E80 <= o <= 0x9FFF or 0x3000 <= o <= 0x303F or 0xFF00 <= o <= 0xFFEF:
            w += 1.0
        elif o > 0x1F000:                      # emoji
            w += 1.2
        elif ch == ' ':
            w += 0.30
        else:
            w += 0.55
    return w


# ★ 判据 591：**只扫 `Button`** —— 它单行不换行，放不下就是截断；
#   `Text` 会换行/省略，长段落是**正常**的，混进来会产生大量假阳性
#   （第 1212 轮实测：把 Text 也扫进来会报 400 个「会截」，
#     其中几乎全是提示正文/隐私条款这类本来就该多行的文字。）
PAT = re.compile(
    r"Button\(\s*(?:\(?\s*)?(?:TG|L|this\.t)\(\s*'([^'\\]{1,80})'(?:\s*,\s*'([^'\\]{1,80})')?",
    re.M)


def scan(paths):
    hits = []
    skipped = 0
    files = 0
    for p in paths:
        s = strip_comments(io.open(p, encoding='utf-8', errors='ignore').read())
        files += 1
        rel = os.path.relpath(p, SRC)
        # 统计跳过的（含 ${} 或变量）
        for m in re.finditer(r"Button\(([^\n]{1,120})", s):
            body = m.group(1)
            if ('${' in body or 'this.' in body) and not re.search(r"(TG|L|this\.t)\('", body):
                skipped += 1
        # 取行号
        line_of = {}
        off = 0
        for idx, ln in enumerate(s.split('\n'), 1):
            line_of[off] = idx
            off += len(ln) + 1
        for m in PAT.finditer(s):
            zh = m.group(1)
            en = m.group(2) or ''
            em = max(em_width(zh), em_width(en)) if en else em_width(zh)
            if em <= 0:
                continue
            # 取最近的行号
            ln = 1
            for off2 in sorted(line_of):
                if off2 <= m.start():
                    ln = line_of[off2]
                else:
                    break
            hits.append({'file': rel, 'line': ln, 'zh': zh, 'en': en, 'em': em,
                         'kind': 'Button'})
    return hits, skipped, files


def report(paths, label='全项目'):
    hits, skipped, files = scan(paths)
    if not hits:
        print('  没有可分析的标签')
        return 0

    # 六尺寸下逐条算 avail/need
    rows = []
    for h in hits:
        need = h['em'] * FONT_SM
        per = {}
        worst = 99.0
        worst_screen = ''
        for name, w in SCREENS:
            # 两种布局：整行宽（layoutWeight/100%） vs 半行宽（Row 两个按钮）
            avail_full = w - PAGE_PAD - BTN_PAD
            avail_half = (w - PAGE_PAD - ROW_GAP) / 2.0 - BTN_PAD
            # 工具不知道实际是哪种 ⇒ 取**两者中较大的**作为乐观值，
            # 结果里标注「乐观」，真实情况由人看图确认（判据 589）
            ratio = avail_full / need if need else 99
            ratio_half = avail_half / need if need else 99
            per[name] = (ratio_half, ratio)
            # ★ 只按**整行**判「会截」，半行只作为附加信息
            if ratio < worst:
                worst = ratio
                worst_screen = name
        rows.append((worst, h, per, worst_screen))

    rows.sort(key=lambda r: r[0])

    print('=' * 70)
    print('  文字放得下吗 · %s（判据 589：≥1.3 才判「够」）' % label)
    print('=' * 70)
    print()
    print('  扫了 %d 个文件 ｜ 可分析标签 %d 个 ｜ **跳过 %d 个**（含 ${} 或变量，判据 546）'
          % (files, len(hits), skipped))
    print('  ⚠️ 宽度模型是**保守近似**（中文 1.0em / 拉丁 0.55em / 内 padding 24vp）')
    print('     ⇒ **只能用来排序**；结论一律以截图为准（判据 588/589）')
    print('  ⚠️ 不知道控件是「整行」还是「半行」⇒ 表里按**半行**（最坏情况）算')
    print()

    bad = [r for r in rows if r[0] < CRITICAL]
    crit = [r for r in rows if CRITICAL <= r[0] < SAFE]
    ok = [r for r in rows if r[0] >= SAFE]

    print('  ══ 🔴 会截（ratio < 1.0）% d 个 ══' % len(bad))
    if bad:
        print('  %-38s %-5s %-16s %8s %s' % ('文件', '行', '文字', 'em', '最坏尺寸'))
        for worst, h, per, ws in bad[:20]:
            print('  %-38s %-5d %-16s %8.1f ratio=%.2f @%s'
                  % (h['file'][-38:], h['line'], h['zh'][:15], h['em'], worst, ws))
    else:
        print('    （无）')
    print()

    print('  ══ 🟡 必须看图（1.0 ≤ ratio < 1.3）% d 个 ══' % len(crit))
    if crit:
        print('  %-38s %-5s %-16s %8s %s' % ('文件', '行', '文字', 'em', '最坏尺寸'))
        for worst, h, per, ws in crit[:24]:
            print('  %-38s %-5d %-16s %8.1f ratio=%.2f @%s'
                  % (h['file'][-38:], h['line'], h['zh'][:15], h['em'], worst, ws))
    else:
        print('    （无）')
    print()

    print('  ══ ✅ 余量够（ratio ≥ 1.3）% d 个（不逐个列）══' % len(ok))
    if ok:
        worst_ok = ok[0]
        print('    最小余量的一条：%s:%d 「%s」ratio=%.2f @%s'
              % (worst_ok[1]['file'], worst_ok[1]['line'], worst_ok[1]['zh'], worst_ok[0], worst_ok[3]))
    print()

    print('  ══ 汇总（判据 546：通过 / 失败 / 没查）══')
    print('    已分析 %d ｜ 🔴 会截 %d ｜ 🟡 必须看图 %d ｜ ✅ 够 %d ｜ ⚪ 没查 %d'
          % (len(hits), len(bad), len(crit), len(ok), skipped))
    if skipped > len(hits) * 0.10:
        print('    ⚠️ 跳过 %d > 已分析×10%% ⇒ 按判据 548，**先改进本工具再下结论**'
              % skipped)

    if bad:
        return 1
    if crit:
        return 2
    return 0


def main():
    args = sys.argv[1:]
    if args:
        paths = [a if os.path.isabs(a) else os.path.join(ROOT, a) for a in args]
        paths = [p for p in paths if os.path.exists(p)]
        return report(paths, label='指定文件（%d 个）' % len(paths))
    paths = []
    for root, _, fs in os.walk(SRC):
        for f in fs:
            if f.endswith('.ets'):
                paths.append(os.path.join(root, f))
    return report(sorted(paths))


if __name__ == '__main__':
    sys.exit(main())
