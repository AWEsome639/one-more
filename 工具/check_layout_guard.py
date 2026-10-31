#!/usr/bin/env python3
"""静态守卫：`width('100%') + aspectRatio(X)` 必须配高度上限。

来历（2026-10-31）：
  真机在 **853×533 横屏**上连抓三次「内容被裁」：
    · 9 路围棋：maxWidth 写死 300 ⇒ 竖屏只占 24% 宽（第 590 轮）
    · 华容道  ：无任何 constraintSize ⇒ 棋盘撑到 813vp 高，
                方向键「←↓→」和「重开」**全部点不到**（第 595 轮）
    · 四子棋 / 落方：同类

  根因是同一句话：
    `.width('100%').aspectRatio(X)` 且**没有任何 constraintSize**
    ⇒ 高度完全由宽度决定 ⇒ 屏幕越宽，内容越高 ⇒ 矮屏必然溢出。

判据：**宽驱动必须配高度上限**（maxHeight 或 maxWidth）。
"""
import glob, io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = 0
TOT = 0

for f in sorted(glob.glob(os.path.join(ROOT, 'entry/src/main/ets/games/*.ets'))):
    s = io.open(f, encoding='utf-8').read()
    n = os.path.basename(f)
    # ★ 2026-10-31：原来只认「跨行」写法（.width 换行 .aspectRatio），
    #   而 28 款是**同一行** `}.width('100%').aspectRatio(1).padding(...)`
    #   ⇒ 守卫全漏。两种写法都要认。
    PATTERNS = [
        r"\.width\('100%'\)\s*\n\s*\.aspectRatio\(([^)]*)\)",
        r"\.width\('100%'\)\.aspectRatio\(([^)]*)\)",
    ]
    for m in (mm for pat in PATTERNS for mm in re.finditer(pat, s)):
        # ── 假阳性过滤 ①：注释里的伪代码（GGo9:16 / :927 就踩过）──
        line_start = s.rfind('\n', 0, m.start()) + 1
        line_text = s[line_start: m.end()]
        if '//' in line_text or line_text.strip().startswith('*'):
            continue
        # ── 假阳性过滤 ②：layoutWeight 决定高度 ⇒ 不是"宽驱动" ──
        #   （GCorsiBlocks:289 / GPong:496 这种：高度由 layoutWeight 分配，不溢出）
        if '.layoutWeight(' in line_text:
            continue
        # ── 假阳性过滤 ③：Grid/GridItem 里的 cell，父 Grid 有定高 ──
        #   这类 aspectRatio 只决定"格子的形状"，高度由 Grid 的轨道定。
        #   判据：往回 30 行内若有 `Grid(` 或 `GridItem(`，跳过。
        head = s[max(0, m.start() - 3000): m.start()]
        tail_head = head[-3000:]
        if ('Grid(' in tail_head or 'GridItem(' in tail_head):
            continue
        TOT += 1
        # 看该块后续**有效代码行**（跳过注释与空行，最多看 12 行代码）内有没有 constraintSize
        tail = s[m.end(): m.end() + 2000]
        code_lines = []
        for w in tail.split('\n'):
            t = w.strip()
            if not t or t.startswith('//') or t.startswith('*') or t.startswith('/*'):
                continue
            code_lines.append(t)
            if len(code_lines) >= 12:
                break
        has_cap = any('constraintSize' in w for w in code_lines)
        if not has_cap:
            line = s[:m.start()].count('\n') + 1
            print('  🔴 %s:%d  宽驱动 aspectRatio(%s) 缺高度上限' % (n, line, m.group(1)[:22]))
            FAIL += 1

print()
print('  宽驱动块：%d 处 ｜ 缺高度上限：%d 处' % (TOT, FAIL))
if FAIL == 0:
    print('  ✅ 全部有上限')
sys.exit(1 if FAIL else 0)
