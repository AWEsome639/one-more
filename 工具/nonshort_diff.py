# -*- coding: utf-8 -*-
"""大屏 vs 手机：配对比较 lowest 元素，找出「同一元素被切小」的款。

为什么不能只看 lowh 的绝对值（判据 2826）：
  · 单行提示文字正常就是 42–49px；按钮/格子正常 ≥ 137px。
  · 所以「lowh=44」既可能是正常提示行，也可能是被切烂的按钮 —— 单看数字分不清。
  · 但**同一款、同一个 lowest 文本**在手机与折叠屏上的高度对比，就能分清：
      Mental Mapping 手机 ↙ 96px → 折叠屏 8px ⇒ 真被切。
用法: python3 工具/nonshort_diff.py
"""
import io, re, sys

def parse(path, with_header=True):
    """返回 {game: (lowh, lowest_text, blk)}，取每款最后一次 OK。"""
    out = {}
    for ln in io.open(path, encoding='utf-8', errors='replace'):
        p = ln.rstrip('\n').split('\t')
        if len(p) < 5 or p[1] in ('game', ''):
            continue
        game = p[1]
        status = p[2] if len(p) > 2 else ''
        body = p[4] if len(p) > 4 else ''
        m = re.search(r"lowest='([^']*)'\s*\[(\d+),(\d+)\]\[(\d+),(\d+)\]", body)
        lowh = (int(m.group(5)) - int(m.group(3))) if m else -1
        text = m.group(1) if m else ''
        b = re.search(r'blk=(\d+)/(\d+)px', body)
        blk = int(b.group(2)) if b else -1
        if status == 'OK':
            out[game] = (lowh, text, blk)
    return out

def main():
    phone = parse('_巡检记录/layout-canonical.tsv')
    fold = parse('_巡检记录/layout-nonshort.tsv')
    common = sorted(set(phone) & set(fold))
    print('手机有 %d 款、折叠屏有 %d 款、共同 %d 款' % (len(phone), len(fold), len(common)))
    same, diff_text, shrank, grew = [], [], [], []
    for g in common:
        ph, pt, pb = phone[g]
        fh, ft, fb = fold[g]
        if ph <= 0 or fh <= 0:
            continue
        if pt.strip() == ft.strip():
            if fh < ph * 0.6:
                shrank.append((g, pt, ph, fh, pb, fb))
            elif fh > ph * 1.6:
                grew.append((g, pt, ph, fh))
            else:
                same.append(g)
        else:
            diff_text.append((g, pt, ph, ft, fh))
    print()
    print('=== ⛔ 同一元素、高度缩到 <60%%（真被切）: %d ===' % len(shrank))
    for g, t, ph, fh, pb, fb in shrank:
        print('  %-24s「%s」手机 %3dpx → 折叠 %3dpx  (blk %s→%s)' % (g, t[:18], ph, fh, pb, fb))
    print()
    print('=== ⚠️ lowest 元素变了（可能是被切后露出的另一元素）: %d ===' % len(diff_text))
    for g, pt, ph, ft, fh in diff_text[:12]:
        print('  %-24s 手机「%s」%dpx → 折叠「%s」%dpx' % (g, pt[:14], ph, ft[:14], fh))
    print()
    print('=== ✅ 高度基本一致: %d 款 ===' % len(same))
    print('=== 变大: %d 款 ===' % len(grew))
    return 0

if __name__ == '__main__':
    sys.exit(main())
