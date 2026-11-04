#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bottom_padding.py —— 底部留白占比审计（判据 777 / 778）

★ 为什么需要（第 1295 轮，来自第 1287 轮的手工发现）
  195×195 上统计页的底部留白是 `(tinyScreen ? 36 : 60) + 48` = **84 vp**
  而实测可见滚动区只有 **92 vp** ⇒ **84 / 92 = 91%**
  ⇒ 用户滚到底时，**一整屏的 91% 是空白**

  根因（判据 778）：`TabContent` 的可见区**已经排除了页签栏**
    （实测：`Scroll` 结束于 393，`TabBar` 起始于 393 ⇒ 零重叠）
    ⇒ 底部 padding **不需要再加一次 `barHeight`**

★ 本工具做什么
  ① 扫所有 `.padding({... bottom: ... })`，抽出 bottom 的**最坏情况 vp**
  ② 与「最小屏的实测可见高度 **92 vp**」比，算占比
  ③ 占比 > 60% ⇒ 报「滚到底几乎全空」

★ 为什么分母用 **92 vp** 而不是「屏高 − 状态栏 − 页签栏」
  判据 777：**必须用实测容器高度作分母**。
  195×195 的统计页实测：`Scroll` = 585×276 px = **195×92 vp**
  （而「195−39−36 = 120 vp」的估算会低估问题 21 个百分点）

用法：
  python3 工具/check_bottom_padding.py [--selftest]
退出码：0 = 无超标 ｜ 1 = 有超标 ｜ 2 = 输入问题
"""
import glob
import io
import json
import os
import re
import sys

ROOT = 'entry/src/main/ets'

# 六设备（vp 宽 × 高）
DEVICES = [('195×195', 195, 195), ('233×233', 233, 233), ('440×744', 440, 744),
           ('853×533', 853, 533), ('960×540', 960, 540), ('800×1280', 800, 1280)]

# 195 上统计页的**实测**可见滚动高度（判据 777：用实测值作分母）
MEASURED_MIN_VIEWPORT_VP = 92.0

SPACE = {'xs': 6, 'sm': 10, 'md': 16, 'lg': 20, 'xl': 28, 'xxl': 32, 'xxxl': 48}

# ★ 判据 791（第 1298 轮）：**这个数不是「bug 阈值」，是「代价阈值」**
#   历史两次真实故障记录都说「留白不够」：
#     · StatsTab  ：`Space.xxxl`(48) ⇒ 960×540 下「成就」卡片被遮 40%
#     · SettingsTab：写死 84       ⇒ 960×540 下「界面模式」按钮被遮约 20vp
#   ⇒ 留白是**为了修「被遮」而付的代价**
#   ⇒ 占比偏大 = **代价偏大**，⛔ 不等于 bug
#   ⇒ 真正的判据是「最后一项是否可见/可达」——那**必须真机验证**
THRESHOLD = 60.0


def strip_comments(src):
    """把 // 与 /* */ 替换成等长空白（保留行号）——判据 779"""
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


def _bounds(a):
    m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds') or '')
    return tuple(int(x) for x in m[0]) if m else None


def _find_type(n, want):
    if not isinstance(n, dict):
        return None
    if (n.get('attributes', {}).get('type') or '') == want:
        return n
    for c in n.get('children', []) or []:
        r = _find_type(c, want)
        if r:
            return r
    return None


def measured_viewport(paths):
    """从 dump 里读**实测可见滚动高度**（vp）

    ★ 判据 772/788（第 1297 轮）：**分母必须是实测值，且类型名是 `Swiper`**
      实证：63 份 dump 里，内容区类型是 **`Swiper`**，页签栏是 **`TabBar`**
        （按 `TabContent` / `Column` 找**一份都匹配不到**）

    返回 (最小可见高度 vp, 来源描述) 或 (None, 失败原因)
    """
    best = None
    best_src = None
    seen_types = set()
    for f in paths:
        if not os.path.exists(f) or os.path.getsize(f) < 500:
            continue
        try:
            d = json.load(io.open(f, encoding='utf-8'))
        except Exception:
            continue
        sw = _find_type(d, 'Swiper')
        if sw is None:
            # 判据 788：先记录「有哪些类型」，避免把「名字写错」当成「没有数据」
            tabs = _find_type(d, 'Tabs')
            if tabs:
                for k in tabs.get('children', []) or []:
                    seen_types.add(k.get('attributes', {}).get('type') or '?')
            continue
        b = _bounds(sw.get('attributes', {}))
        if not b:
            continue
        h_px = b[3] - b[1]
        if h_px <= 0:
            continue
        h_vp = h_px / 3.0
        if best is None or h_vp < best:
            best = h_vp
            best_src = '%s（Swiper %d px）' % (os.path.basename(f), h_px)
    if best is None:
        if seen_types:
            return None, '未找到 Swiper；Tabs 的子类型是 %s（判据 788：名字可能写错）' % sorted(seen_types)
        return None, '未找到含 Tabs 的 dump'
    return best, best_src


def worst_case_bottom(expr):
    """从 bottom 的表达式里取**最坏情况（最大）** vp

    支持：
      `(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48`  ⇒ 60 + 48 = 108
      `Space.lg`                                          ⇒ 20
      `48`                                                ⇒ 48
      `(… ? 2 : Space.lg)`                                ⇒ max(2, 20) = 20
    取不到 ⇒ None（**不猜**）
    """
    if expr is None:
        return None
    expr = expr.strip()

    # ★ 判据 786（第 1295 轮）：**`+` 表达式要按各分支相加，⛔ 不能取整体最大值**
    #   实证：`(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48`
    #     · 取 max(36, 60, 48) = **60**  ← 旧实现（错）
    #     · 正确最坏情况 = **60 + 48 = 108**
    #   差 48 vp ⇒ 占比从 65% 变成 117%，严重程度完全不同
    #
    #   做法：
    #     ① 按顶层 `+` 切开（忽略括号内的 `+`）
    #     ② 每段各自取「该段的（三元）最大分支」
    #     ③ 把各段相加
    def top_level_addends(e):
        parts = []
        depth = 0
        cur = []
        for ch in e:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            if ch == '+' and depth == 0:
                parts.append(''.join(cur))
                cur = []
            else:
                cur.append(ch)
        parts.append(''.join(cur))
        return [x.strip() for x in parts if x.strip()]

    def seg_max(e):
        # 该段内所有 Space.xxx 与裸数字，取最大（三元的两分支都在里面）
        vals = [SPACE[v] for v in re.findall(r'Space\.(\w+)', e) if v in SPACE]
        vals += [int(v) for v in re.findall(r'(?<![\w.])(\d{1,3})(?![\w.])', e)]
        return max(vals) if vals else None

    parts = top_level_addends(expr)
    if not parts:
        return None
    total = 0
    for part in parts:
        v = seg_max(part)
        if v is None:
            return None          # 有一段取不到 ⇒ 整体不猜
        total += v
    return total


def scan(root):
    """返回 [(文件, 行号, 表达式, bottom_vp)]"""
    hits = []
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if not fn.endswith('.ets'):
                continue
            p = os.path.join(dp, fn)
            raw = io.open(p, encoding='utf-8', errors='ignore').read()
            s = strip_comments(raw)
            # 找 `.padding({` … `})` 块，抽 bottom
            for m in re.finditer(r'\.padding\(\{([^}]*)\}\)', s, re.S):
                body = m.group(1)
                bm = re.search(r'bottom:\s*([^,\n]+)', body)
                if not bm:
                    continue
                expr = bm.group(1).strip()
                vp = worst_case_bottom(expr)
                line = raw[:m.start()].count('\n') + 1
                hits.append((p, line, expr, vp))
    return hits


def report(hits, viewport=None, src=None):
    """输出表格；返回超标条数

    viewport：**实测可见高度（vp）**。None ⇒ 用默认 92 vp（195 上实测）
    """
    den = viewport if viewport else MEASURED_MIN_VIEWPORT_VP
    how = ('**实测 %.1f vp**（%s）' % (den, src)) if viewport else \
          '**195×195 实测可见滚动高度 %.0f vp**（默认值；可用 --from-dumps 覆盖）' % den
    print('=' * 78)
    print('  底部留白占比审计（判据 777/778）')
    print('  分母 = %s' % how)
    print('  阈值 = %.0f%%（超过 ⇒ 滚到底时几乎全是空白）' % THRESHOLD)
    print('=' * 78)
    print()
    if not hits:
        print('  未找到 `.padding({... bottom: ... })`')
        return 0
    print('  %-38s %-5s %-9s %-8s %s' % ('文件', '行', 'bottom(vp)', '占比', '结论'))
    print('  ' + '-' * 74)
    over = 0
    for p, line, expr, vp in sorted(hits, key=lambda x: (x[1] or 0), reverse=True):
        rel = p.replace(ROOT + '/', '')
        if vp is None:
            print('  %-38s %-5d %-9s %-8s ⚠️ 取不到值（不猜）' % (rel[:38], line, '?', '?'))
            continue
        pct = vp / den * 100.0
        flag = '⚠️ 代价偏大' if pct > THRESHOLD else '✅'
        if pct > THRESHOLD:
            over += 1
        print('  %-38s %-5d %-9d %-8.1f%% %s' % (rel[:38], line, vp, pct, flag))
        if pct > THRESHOLD:
            print('      表达式: %s' % expr[:66])
    print()
    print('=' * 78)
    print('  📖 判据 778：`TabContent` 的可见区**已排除页签栏** ⇒')
    print('     底部 padding **不需要再加一次 `barHeight`**（36/60）。')
    print('     实测：`Scroll` 结束于 393，`TabBar` 起始于 393 ⇒ **零重叠**。')
    print()
    print('  📖 判据 791：**留白占比大 ≠ bug**。')
    print('     历史两次真实故障都因「留白不够」而内容被遮')
    print('     ⇒ 留白是**为修「被遮」而付的代价**；')
    print('     真正的判据是「最后一项是否可见/可达」——**必须真机验证**。')
    print()
    if over:
        print('  ⚠️ **%d 处留白代价偏大**（占比 > %.0f%%）' % (over, THRESHOLD))
        print('     ⇒ ⛔ 不要直接改小；先确认「最后一项仍可见」（判据 790/791）')
        return over
    print('  ✅ 未发现留白代价偏大的项')
    return 0


def selftest():
    """内置自检：正例 + 反例（判据 784）"""
    ok = True

    def t(name, cond, detail=''):
        nonlocal ok
        if cond:
            print('    ✅ %s%s' % (name, ('  ' + detail) if detail else ''))
        else:
            print('    🔴 %s%s' % (name, ('  ' + detail) if detail else ''))
            ok = False

    print('  ── ① strip_comments ──')
    src = "a\n// bottom: 999\nb /* bottom: 888 */ c\n"
    c = strip_comments(src)
    t('行数不变', c.count('\n') == src.count('\n'))
    t('长度不变', len(c) == len(src))
    t('注释里的 999 被剥', '999' not in c)
    t('非注释保留', 'a' in c and 'b' in c and 'c' in c)

    print('  ── ② worst_case_bottom：正例 ──')
    t('Space.lg ⇒ 20', worst_case_bottom('Space.lg') == 20)
    t('48 ⇒ 48', worst_case_bottom('48') == 48)
    t('三元 + 常量 ⇒ **108**（60 + 48，判据 786）',
      worst_case_bottom('(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48') == 108,
      '（实得 %s）' % worst_case_bottom('(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48'))

    print('  ── ③ worst_case_bottom：反例（判据 784）──')
    t('空串 ⇒ None', worst_case_bottom('') is None)
    t('无数字 ⇒ None', worst_case_bottom('this.compute()') is None)
    t('不把 4 位数当 vp（1234 不该进来）',
      worst_case_bottom('1234') is None or worst_case_bottom('1234') != 1234)

    print('  ── ④ 占比计算：195 上 84 vp ÷ 92 vp ──')
    pct = 84 / MEASURED_MIN_VIEWPORT_VP * 100
    t('应 ≈ 91.3%%（实得 %.1f%%）' % pct, abs(pct - 91.3) < 0.5)
    t('84 vp 超过阈值', pct > THRESHOLD)
    t('12 vp 不超阈值', 12 / MEASURED_MIN_VIEWPORT_VP * 100 < THRESHOLD)

    print()
    print('=' * 78)
    if ok:
        print('  ✅ 自检通过（四项判据都验到了正例与反例）')
        return 0
    print('  🔴 自检失败')
    return 1


def main():
    if '--selftest' in sys.argv:
        print('=' * 78)
        print('  底部留白审计 · 内置自检（判据 648 / 784）')
        print('=' * 78)
        return selftest()
    if not os.path.isdir(ROOT):
        print('目录不存在: %s' % ROOT)
        return 2

    # ★ 判据 777（第 1297 轮）：**分母最好用实测值**
    #   `--from-dumps` 会扫 /tmp/dump_*.json，取**最小的** Swiper 高度
    #   ⇒ 用「最坏设备」作分母 ⇒ 结论最保守
    viewport = None
    src = None
    paths = []
    for i, a in enumerate(sys.argv):
        if a == '--from-dump' and i + 1 < len(sys.argv):
            paths.append(sys.argv[i + 1])
        elif a == '--from-dumps':
            paths += sorted(glob.glob('/tmp/dump_*.json'))
    if paths:
        vp_meas, why = measured_viewport(paths)
        if vp_meas:
            viewport, src = vp_meas, why
        else:
            print('  ⚠️ 读不到实测高度：%s' % why)
            print('     ⇒ 回落到默认 %.0f vp（判据 777：这会让结论偏乐观）'
                  % MEASURED_MIN_VIEWPORT_VP)
            print()

    hits = scan(ROOT)
    over = report(hits, viewport, src)
    return 1 if over else 0


if __name__ == '__main__':
    sys.exit(main())
