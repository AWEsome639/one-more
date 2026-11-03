#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_emoji_centering.py —— 「emoji 放在有色底上却没垂直微调」的静态检查器

为什么需要它（2026-11-03 第 1014 轮，奥森报「水滴没在圆盘里居中」）：
  · 实测 49 颗宝石的**几何重心**偏差全部 < 0.25px（数学上完美居中）
  · 但 emoji 是彩色字形，**视觉重心 ≠ 几何重心**：
      💧 上尖下圆 ⇒ 视觉重心偏下    💎 上宽下尖 ⇒ 视觉重心偏上
      🔥 火苗上窜 ⇒ 偏下            🔮 球+底座 ⇒ 偏下
  · 于是同一圆心上，它们看起来高低不一。
  · `textAlign` / `align` **无效**（那只管文本框，字形在 em box 里偏哪由字体决定）
  · 唯一有效：`.offset({ y })` 逐字形补偿，或换对称字形。

本检查器做什么：
  找出「单个 emoji 的 Text + 有色背景 + 圆角」的块，报告它有没有 `.offset({ y })`。

用法：
  python3 工具/check_emoji_centering.py          # 只报告
  python3 工具/check_emoji_centering.py --strict # 有未处理项则退出码 1

⚠️ 它只做**静态筛查**，不能代替真机截图：
   有 `.offset()` 也可能调错方向；没有也未必真难看（比如底很大、emoji 很小）。
"""
import io
import os
import re
import sys
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 单个 emoji 字面量（Text('💧') 这种）
EMOJI_LITERAL = re.compile(
    r"Text\(\s*['\"]([\U0001F300-\U0001FAFF\u2600-\u27BF])['\"]"
)
# Text(ARRAY[i] ...) 这种（棋盘类）
# ⚠️ 2026-11-03 第 1019 轮修正：原来写的是 `Text\((?:this\.)?([A-Z]...)`，
#    会**误报** `Text(Digits(...))` / `Text(String(...))` / `Text(About.XXX)` ——
#    实测首版报出 756 处"主路径"，绝大多数根本不是 emoji。
# ⇒ 改成**白名单**：只认名字里能看出是"图形/符号表"的数组，
#    或者内容已被确认全是 emoji 的常量。
EMOJI_ARRAY = re.compile(
    r"Text\(\s*(?:this\.)?("
    r"[A-Z][A-Z0-9_]*"                       # 常量名
    r"(?:\[[^\]]*\])?"                      # 可选的 [i] 下标
    r")\s*[,)]"
)
# 允许的数组/常量名（白名单）——只有这些才可能是 emoji 表格
ALLOWED_NAMES = {
    'GEMS', 'GLYPHS', 'ICONS', 'SYMBOLS', 'TILES', 'EMOJI', 'EMOJIS',
    'PIECES', 'CELLS', 'ACTS', 'FACES', 'MARKS', 'TOKENS',
}
# 明确排除：这些显然不是 emoji
DENY_PREFIXES = ('Digits', 'String', 'About', 'this', 'Lang', 'Palette')
BG = "backgroundColor("
RADIUS = re.compile(r"borderRadius\(\s*(?:Radius\.\w+|\d+)\s*\)")
OFFSET = ".offset("


def scan_file(path):
    """返回 [(行号, 是否有 offset, 片段)]"""
    try:
        lines = io.open(path, encoding="utf-8").read().split("\n")
    except Exception:
        return []
    out = []
    for i, l in enumerate(lines):
        text_m = EMOJI_LITERAL.search(l)
        is_literal = text_m is not None
        if not text_m:
            text_m = EMOJI_ARRAY.search(l)
            if text_m:
                name = text_m.group(1).split('[')[0]
                # ⚠️ 白名单 + 黑名单（第 1019 轮修正误报）
                if name not in ALLOWED_NAMES:
                    continue
                if name.startswith(DENY_PREFIXES):
                    continue
        if not text_m:
            continue
        # 往后看 16 行（一个组件的属性链）
        seg_lines = lines[i : i + 17]
        seg = "\n".join(seg_lines)
        if BG not in seg or not RADIUS.search(seg):
            continue
        # 排除"文字行里夹 emoji"（同一行还有别的中文/英文说明）
        stripped = re.sub(r"Text\([^)]*\)", "", l)
        if re.search(r"[\u4e00-\u9fff]{2,}|[A-Za-z]{6,}", stripped):
            continue
        has_off = OFFSET in seg
        out.append((i + 1, has_off, l.strip()[:78]))
    return out


def main():
    strict = "--strict" in sys.argv
    files = sorted(glob.glob(os.path.join(ROOT, "entry/src/main/ets/**/*.ets"), recursive=True))
    total = 0
    missing = 0
    rows = []
    for f in files:
        if ".bak-" in f:
            continue
        hits = scan_file(f)
        if not hits:
            continue
        rel = f.replace(os.path.join(ROOT, "entry/src/main/ets/"), "")
        bad = [h for h in hits if not h[1]]
        total += len(hits)
        missing += len(bad)
        rows.append((rel, len(hits), len(bad)))

    rows.sort(key=lambda r: -r[2])
    print("=" * 66)
    print("  emoji-in-colored-box 检查（视觉重心 ≠ 几何重心）")
    print("=" * 66)
    print("  候选块 %d 处 ｜ 其中**没有 .offset({y})** 的 %d 处" % (total, missing))
    print()
    print("  %-44s 总数  未处理" % "文件")
    print("  " + "-" * 62)
    for rel, n, bad in rows:
        flag = "  ← 需要看" if bad else ""
        print("  %-44s %3d  %4d%s" % (rel[:44], n, bad, flag))
    print()
    if missing == 0:
        print("  ⇒ 全部已有 offset（但请记住：offset 也可能调错方向，需真机看）")
    else:
        print("  ⇒ 有 %d 处没有 offset。" % missing)
        print("  ⚠️ 不是全都要改：若 emoji 字形本身近似对称（🍀 ⭐ ⚪），不偏移也对；")
        print("     若底很大、emoji 很小，偏差也不明显。**逐个截图判断**，别批量套数。")
    print()
    print("  判据 305：几何居中 ≠ 看起来居中。像素测量证明不了视觉重心。")
    if strict and missing > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
