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


def find_text(n, want):
    """找文本包含 want 的节点（返回**最靠下**的那个）"""
    hits = []

    def w(x):
        if not isinstance(x, dict):
            return
        s = (x.get('attributes', {}).get('text') or '').strip()
        b = bounds(x.get('attributes', {}))
        if s and want in s and b:
            hits.append((b, s))
        for c in x.get('children', []) or []:
            w(c)
    w(n)
    if not hits:
        return None
    hits.sort(key=lambda t: t[0][3], reverse=True)
    return hits[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dump')
    ap.add_argument('--last-section', required=True,
                    help='最后一节的标题文字（如「关于」）')
    ap.add_argument('--expect-min-gap', type=float, default=8.0,
                    help='期望的最小下沿余量（vp），默认 8')
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

    node = find_text(d, args.last_section)
    if node is None:
        print('⚪ 最后一节「%s」**不在 dump 里** ⇒ 没滚到底（判据 796）' % args.last_section)
        print('   ⇒ 这份 dump 不能用来判断「是否被裁」')
        return 2

    nb, text = node
    gap_px = sb[3] - nb[3]
    gap_vp = gap_px / VP_PER_PX

    print('=' * 68)
    print('  最后一项可见性检查（判据 794/796）')
    print('=' * 68)
    print('  Swiper 视口      y=%d ~ %d（高 %d px）' % (sb[1], sb[3], sb[3] - sb[1]))
    print('  「%s」节点        y=%d ~ %d ｜ 文本 %r' % (args.last_section, nb[1], nb[3], text[:24]))
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
