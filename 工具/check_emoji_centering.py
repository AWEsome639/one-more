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
  python3 工具/check_emoji_centering.py           # 默认严格：有未处理项退出码 1
  python3 工具/check_emoji_centering.py --lenient # 只看报告（CI 里别用）

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
# ★★★ 2026-11-03（第 1122 轮）**收窄到真 emoji 区间**
#   原来还包含 `\u2600-\u27BF`（杂项符号区），把下面这些也当成了 emoji：
#     ✓(2713) ✕(2715) ♛(265B) ⚖(2696) ⚙(2699)
#   ⇒ 它们**不是彩色 emoji**，字形在字框里本来就更接近居中
#   ⇒ 判据 305 讲的「emoji 字形偏下」对它们**不适用**
#   ⇒ 结果：检查器报了 5 处假阳性 ⇒ 一旦默认严格，CI 就永远红 ⇒ 严格模式等于没用
#   ⚠️ 边界说明：`❓❤➕➗⚠✉` 这几个是"带 VS16 才会彩色呈现"的，
#      本检查器**不再报告**它们（它们大多出现在文字里，不是独占色块）；
#      若将来真的单独放进色块，请手工判断并用 .offset({y:-1}) 修。
EMOJI_LITERAL = re.compile(
    r"Text\(\s*['\"]([\U0001F300-\U0001FAFF])['\"]"
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
        # ★★★ 2026-11-03（第 1122 轮）**只看"这个 Text 自己"的属性链**
        #   原来取 `lines[i : i+17]`，那 17 行里可能包含**下一个 Text** 或**父容器**，
        #   于是把"跟文字并排的 emoji"（父容器有底色）也当成了"emoji 独占色块"。
        #   实测误报：Common.ets:446 的 🔥、StatsTab.ets:969 的 🌱
        #     · 🔥 在 Row 里跟「{n} 天」并排 ⇒ 色块是 Row 的，emoji 只是行内字符
        #     · 🌱 是 Column 的第一个元素 ⇒ 同样不是独占色块
        #   ⇒ 正确的判据：**这个 Text 自己**有 width + height + backgroundColor
        #     才是"emoji 放进一个按它尺寸画的色块里"，才需要 offset。
        seg_lines = []
        for l2 in lines[i : i + 17]:
            seg_lines.append(l2)
            # 遇到下一处 **独立的** Text( 就停（不含）
            #   ⚠️ 不能用 `'Text(' in l2` —— `accessibilityText(` 里也含 "Text("，
            #      会把属性链在第 2 行就截断，导致 width/height 找不到、全部漏报。
            #   （判据 419 同一个坑：子串匹配会把"形名相似的东西"算进来）
            if len(seg_lines) > 1 and re.search(r'(?<![A-Za-z])Text\(', l2):
                seg_lines.pop()
                break
        seg = "\n".join(seg_lines)
        if BG not in seg or not RADIUS.search(seg):
            continue
        # 必须**自己**有 width 与 height（父容器的尺寸不会写在这个 Text 的属性链里）
        if 'width(' not in seg or 'height(' not in seg:
            continue
        # 排除"文字行里夹 emoji"（同一行还有别的中文/英文说明）
        stripped = re.sub(r"Text\([^)]*\)", "", l)
        if re.search(r"[\u4e00-\u9fff]{2,}|[A-Za-z]{6,}", stripped):
            continue
        has_off = OFFSET in seg
        out.append((i + 1, has_off, l.strip()[:78]))
    return out


def main():
    # ★★★ 2026-11-03（第 1122 轮）**默认改为严格**（判据 423）
    #   原来「默认宽松、加 --strict 才失败」⇒ 不带参数时永远退出 0，
    #   在自动化里完全失效。改为一律严格，要宽松请显式 --lenient。
    strict = "--lenient" not in sys.argv
    files = sorted(glob.glob(os.path.join(ROOT, "entry/src/main/ets/**/*.ets"), recursive=True))
    total = 0
    missing = 0
    details = {}      # ★ 第 1122 轮：记录每处的行号，供输出用
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
        details[rel] = hits

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
        # ★ 2026-11-03（第 1122 轮）**必须打出具体行号**，否则"需要看"无从下手
        for ln, has_off, frag in details.get(rel, []):
            if not has_off:
                print("      L%-5d %s" % (ln, frag[:70]))
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
    # ★★★ 2026-11-03（第 1124 轮）**崩溃与判定失败用不同退出码**（判据 428）
    #   原来 `sys.exit(main())`：main 里抛异常就变成非 0 的 traceback 退出（也是 1）
    #   ⇒ **"检测到不合格"和"脚本自己崩了"退出码一样**
    #   ⇒ 看到 1 时无法判断该去改代码还是该去查环境
    #   ⇒ 约定：**0 = 合格 ｜ 1 = 判定不合格 ｜ 2 = 脚本异常**
    try:
        _rc = main()
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
    sys.exit(_rc if isinstance(_rc, int) else 0)
