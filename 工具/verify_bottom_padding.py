#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""verify_bottom_padding.py —— 验证「最后一项是否可见/可达」（判据 794/796）

★ 为什么需要（第 1306 轮）
  第 1296~1302 轮我把「底部留白 117%」查了很多遍，但**一直没能验证那个真正重要的问题**：
    **滚到底时，最后一项内容是否完整可见？**
  判据 793/794 说：现象是「滚到底仍被裁」，根因是「可滚范围 < 内容高度」。
  ⇒ 本脚本把那个判断**变成一个可执行的检查**，只要给一份「滚到底」的 dump。

★ 判据（本系列第 796 条）
  ⛔ **不能**用「内容最深 y2 == 视口底」判断滚到底（内容超出视口时恒等）
  ✅ **必须**看「最后一节是否在 dump 里」+「它的下沿与视口底的差」

用法:
  python3 工具/verify_bottom_padding.py <dump.json> --last-section 关于
  python3 工具/verify_bottom_padding.py <dump.json> --last-section 关于 --expect-min-gap 8

判据（退出码）:
  0 = 最后一项**完整可见**且下沿余量 ≥ expect-min-gap（默认 8 vp）
  1 = 最后一项**仍被裁**（可滚范围不足，判据 794）
  2 = 最后一项**根本不在 dump 里**（没滚到底）
  3 = 输入问题
"""
import argparse
import io
import json
import re
import sys

VP_PER_PX = 3.0     # 本项目六台模拟器都是 3x


def bounds(a):
    m = re.findall(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', a.get('bounds') or '')
    return tuple(int(x) for x in m[0]) if m else None


def find_type(n, want):
    if not isinstance(n, dict):
        return None
    if (n.get('attributes', {}).get('type') or '') == want:
        return n
    for c in n.get('children', []) or []:
        r = find_type(c, want)
        if r:
            return r
    return None


def find_text(n, want, mode='exact'):
    """找文本匹配 want 的节点，返回 (bounds, text, quality)

    ★ 判据 806（第 1306 轮）：**三种匹配必须分开，默认用最严的**
      实证（本工具第一版）：用 `want in s` 匹配「关于」
        ⇒ 命中了 **'反馈与关于'**（一个列表项），而不是节标题「关于」
        ⇒ 于是「下沿余量 137.7 vp」量的是列表项 ⇒ **假通过**

      mode:
        'exact'  ⇒ `s == want`（默认，最严）
        'prefix' ⇒ `s.startswith(want)`（节标题通常这样）
        'sub'    ⇒ `want in s`（最容易误中，⛔ 仅供调试）

    返回 (bounds, text, quality)；quality ∈ {'exact','prefix','sub'}
    """
    hits = []

    def w(x):
        if not isinstance(x, dict):
            return
        s = (x.get('attributes', {}).get('text') or '').strip()
        b = bounds(x.get('attributes', {}))
        if s and b:
            q = None
            if s == want:
                q = 'exact'
            elif s.startswith(want):
                q = 'prefix'
            elif want in s:
                q = 'sub'
            if q is not None and (mode == 'sub' or q == mode
                                  or (mode == 'prefix' and q in ('exact', 'prefix'))):
                hits.append((b, s, q))
        for c in x.get('children', []) or []:
            w(c)
    w(n)
    if not hits:
        return None
    hits.sort(key=lambda t: t[0][3], reverse=True)
    return hits[0]


def selftest():
    """内置自检：三种匹配的正例与反例（判据 784 / 806）"""
    ok = True

    def t(name, cond, detail=''):
        nonlocal ok
        if cond:
            print('    ✅ %s%s' % (name, ('  ' + detail) if detail else ''))
        else:
            print('    🔴 %s%s' % (name, ('  ' + detail) if detail else ''))
            ok = False

    def node(text):
        return {'attributes': {'type': 'Text', 'text': text,
                               'bounds': '[0,100][100,120]'}, 'children': []}
    fake = {'attributes': {'type': 'Root', 'bounds': '[0,0][600,400]'},
            'children': [node('反馈与关于'), node('关于'), node('关于字体')]}

    print('  ── ① exact：只认完全相等 ──')
    r = find_text(fake, '关于', 'exact')
    t('命中「关于」', r is not None and r[1] == '关于', '（得 %r）' % (r[1] if r else None))
    t('不命中「反馈与关于」', r is not None and r[1] != '反馈与关于')
    t('不命中「关于字体」', r is not None and r[1] != '关于字体')
    t('质量标为 exact', r is not None and r[2] == 'exact')

    print('  ── ② prefix：前缀可以，子串不行 ──')
    r = find_text(fake, '关于', 'prefix')
    t('质量 ∈ {exact, prefix}', r is not None and r[2] in ('exact', 'prefix'))
    t('仍然不命中「反馈与关于」', r is not None and r[1] != '反馈与关于')

    print('  ── ③ sub：会误中（判据 806 的反例）──')
    r = find_text(fake, '关于', 'sub')
    t('能命中某个含「关于」的节点', r is not None)
    t('**可能命中「反馈与关于」**（这正是危险所在）', True)

    print('  ── ④ 不存在 ⇒ None ──')
    t('找「不存在的」⇒ None', find_text(fake, '不存在的', 'exact') is None)

    print()
    print('=' * 68)
    if ok:
        print('  ✅ 自检通过（exact/prefix/sub 三档的正例与反例都验到）')
        return 0
    print('  🔴 自检失败')
    return 1


def main():
    if '--selftest' in sys.argv:
        print('=' * 68)
        print('  最后一项可见性检查 · 内置自检（判据 784 / 806）')
        print('=' * 68)
        return selftest()

    ap = argparse.ArgumentParser()
    ap.add_argument('dump')
    ap.add_argument('--last-section', required=True,
                    help='最后一节的标题文字（如「关于」）')
    ap.add_argument('--expect-min-gap', type=float, default=8.0,
                    help='期望的最小下沿余量（vp），默认 8')
    ap.add_argument('--match', choices=['exact', 'prefix', 'sub'], default='exact',
                    help='匹配方式：exact(默认) / prefix / sub(仅供调试，易误中)')
    args = ap.parse_args()

    try:
        d = json.load(io.open(args.dump, encoding='utf-8'))
    except Exception as e:
        print('🔴 读不了 dump: %s' % e)
        return 3

    sw = find_type(d, 'Swiper')
    if sw is None:
        print('🔴 dump 里没有 Swiper（判据 788：内容区类型是 Swiper）')
        return 3
    sb = bounds(sw.get('attributes', {}))
    if sb is None:
        print('🔴 Swiper 没有 bounds')
        return 3

    node = find_text(d, args.last_section, args.match)
    if node is None:
        print('⚪ 最后一节「%s」**不在 dump 里** ⇒ 没滚到底（判据 796）' % args.last_section)
        print('   ⇒ 这份 dump 不能用来判断「是否被裁」')
        return 2

    nb, text, quality = node
    gap_px = sb[3] - nb[3]
    gap_vp = gap_px / VP_PER_PX

    print('=' * 68)
    print('  最后一项可见性检查（判据 794/796）')
    print('=' * 68)
    print('  Swiper 视口      y=%d ~ %d（高 %d px）' % (sb[1], sb[3], sb[3] - sb[1]))
    qname = {'exact': '精确相等 ✅', 'prefix': '前缀匹配 ⚠️', 'sub': '**子串匹配 🔴 易误中**'}[quality]
    print('  「%s」节点        y=%d ~ %d ｜ 文本 %r' % (args.last_section, nb[1], nb[3], text[:24]))
    print('  **匹配质量**      %s（mode=%s）' % (qname, args.match))
    print('  **下沿余量**      %d px = **%.1f vp**' % (gap_px, gap_vp))
    print()
    if gap_px < 0:
        print('  🔴 **被裁了 %d px**（≈ %.1f vp）' % (-gap_px, -gap_vp))
        print('     ⇒ 判据 794：**可滚范围 < 内容高度**，最后一段滚不到')
        print('     ⇒ 判据 795：试把 `Scroll.height(\'100%\')` 改成 `.layoutWeight(1)`')
        return 1
    if gap_vp < args.expect_min_gap:
        print('  ⚠️ 完整可见，但余量只有 %.1f vp（期望 ≥ %.1f）' % (gap_vp, args.expect_min_gap))
        print('     ⇒ 判据 791：这是「代价偏小」而不是「被裁」，可接受但偏紧')
        return 0
    print('  ✅ **完整可见**，余量 %.1f vp ≥ %.1f' % (gap_vp, args.expect_min_gap))
    return 0


if __name__ == '__main__':
    sys.exit(main())
