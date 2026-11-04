#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
圆屏裁切检查（判据 479）

★ 为什么要有这个
  目标要求「六设备全支持」里包含**手表**，而真手表常是**圆屏**，
  模拟器是方的 ⇒ 方屏上看着没问题的布局，圆屏上**四角会被裁掉**。
  没有圆屏设备时，可以用几何直接判断：
    「内容的最远点是否落在内切圆内」

★ 判据
  屏幕 w×h 的内切圆半径 R = min(w,h) / 2
  任何**有信息**的像素（非背景）到中心的距离 > R ⇒ 圆屏上会被裁

用法：python3 工具/check_round_screen.py <截图.png> [...]
退出码：0 = 全部落在内切圆内 ｜ 1 = 有元素超出 ｜ 2 = 脚本问题
"""
import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print('🔴 缺少 Pillow / numpy')
    sys.exit(1)


def check(path, bg_tol=18):
    """返回 (是否安全, 超出占比, 最远点距离比, 说明)"""
    im = Image.open(path).convert('RGB')
    A = np.array(im, dtype=np.int32)
    h, w = A.shape[:2]
    # 背景色 = 四角像素的中位色（开屏是墨蓝 #0D1320）
    corners = np.array([A[2, 2], A[2, w - 3], A[h - 3, 2], A[h - 3, w - 3]])
    bg = np.median(corners, axis=0)
    # 与背景差异 > tol 的像素算「有内容」
    diff = np.abs(A - bg).sum(axis=2)
    content = diff > bg_tol

    cy, cx = h / 2.0, w / 2.0
    ys, xs = np.mgrid[0:h, 0:w]
    dist = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    R = min(w, h) / 2.0

    outside = content & (dist > R)
    n_content = content.sum()
    n_out = outside.sum()
    ratio = (n_out / n_content * 100) if n_content else 0.0

    if n_out:
        # 最远的内容像素
        dmax = dist[content].max()
        far = dmax / R
    else:
        dmax = dist[content].max() if n_content else 0
        far = (dmax / R) if R else 0

    return (n_out == 0), ratio, far, (w, h, R)


def main():
    paths = [a for a in sys.argv[1:] if not a.startswith('-')]
    if not paths:
        print('用法: python3 工具/check_round_screen.py <截图.png> [...]')
        return 1
    rc = 0
    print('=' * 70)
    print('  圆屏裁切检查（内切圆 R = min(w,h)/2）')
    print('=' * 70)
    # ★★★ 2026-11-04（第 1247 轮，判据 655）**「没查」不能算「通过」**
    #   原来：截图不存在 ⇒ 打印「⚠️ 跳过（不存在）」⇒ continue
    #   ⇒ 这张截图**没被检查**，而 rc 仍是 0 ⇒ 报告会说"全部通过"
    #   修：计入 `missing`，最后由它决定 rc=2（区分"脚本问题"与"检查不合格"）
    missing = []
    for p in paths:
        if not os.path.exists(p):
            print('  🔴 **截图不存在，无法检查**: %s' % p)
            missing.append(p)          # ← 必须计入
            continue
        ok, ratio, far, (w, h, R) = check(p)
        name = os.path.basename(p)
        print()
        print('  %s' % name)
        print('    尺寸 %d×%d px ｜ 内切圆半径 %.1f px' % (w, h, R))
        if ok:
            print('    ✅ **全部内容落在内切圆内**（最远点 %.3f × R）' % far)
        else:
            print('    🔴 **有 %.3f%% 的内容像素落在内切圆外**（最远点 %.3f × R）' % (ratio, far))
            print('       ⇒ 圆屏上这部分会被裁掉')
            rc = 1
    print()
    print('=' * 70)
    print('  ⚠️ 本工具的判据：「有内容」= 与四角背景色差异 > 18')
    print('  ⚠️ 圆屏还会有一圈边框/弧度 ⇒ 建议留 3% 余量（far ≤ 0.97）')
    print()
    print('  🔴 **本工具只对「可能是圆屏的设备」有意义（手表）**')
    print('     手机 / 平板 / 智慧屏都是矩形屏 ⇒ 不用跑这个检查')
    print('     （否则任何矩形布局都会"超出一大片"，那是假警报）')
    print('=' * 70)
    if missing:
        print()
        print('  🔴 **%d 张截图不存在，未做检查**：' % len(missing))
        for p in missing:
            print('     · %s' % p)
        print('  ⇒ 退出码 2（**未检查 ≠ 通过**，判据 655/546）')
        return 2
    return rc


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException:
        import traceback
        traceback.print_exc()
        print('🔴 脚本异常退出（退出码 2 = 脚本问题，不是"检查不合格"）', file=sys.stderr)
        sys.exit(2)
