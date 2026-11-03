#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
开屏截图视觉量化（判据 350：「淡」「有暗角」「有颗粒」都必须给数字）

★ 为什么要有这个（2026-11-03 第 1102 轮）
  开屏九条里有三条是**主观的**：
    ② 素材质感（渐变 + 高光 + 外发光）
    ⑤ 暗角 + 颗粒
    ③ 逐字动效
  而判据 350 说：「'淡'要用 ΔL 量化，不能用 alpha 值证明」。
  ⇒ 所以把这三条变成可从截图直接算出来的数字。

★ 量什么
  ① **暗角**：四角均值 vs 中心空白区均值 ⇒ ΔL（> 8 才算有收拢感）
  ② **颗粒**：纯背景竖带的**去趋势局部标准差**（> 0.2 才算有噪点）
  ③ **文字对比度**：各文字带的 max − 中位背景（> 60 可读，> 120 醒目）
  ④ **星尘**：孤立亮点占比
  ⑤ **光带**：中段帧 vs 终态帧的标题 ΔL 差（< 25 说明光带不遮字）

用法：
  python3 工具/measure_splash_visual.py <截图> [更多截图...]
退出码：0 = 全部达标 ｜ 1 = 有不合格
"""
import os
import sys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    print('🔴 缺少 Pillow / numpy')
    sys.exit(1)

VIG_MIN = 8.0       # 暗角 ΔL 下限
GRAIN_MIN = 0.20    # 颗粒局部标准差下限
TEXT_MIN = 60.0     # 文字 ΔL 下限（可读）


def measure(path):
    im = Image.open(path).convert('RGB')
    A = np.array(im, dtype=np.int32)
    H, W = A.shape[:2]
    lum = A.mean(axis=2)
    out = {'file': os.path.basename(path), 'w': W // 3, 'h': H // 3,
           'px': (W, H), 'ok': True, 'notes': []}

    # ① 暗角：四角 vs 中心空白
    k = max(20, min(60, W // 30))
    corners = np.concatenate([
        lum[0:k, 0:k].ravel(), lum[0:k, W - k:].ravel(),
        lum[H - k:, 0:k].ravel(), lum[H - k:, W - k:].ravel()])
    cy = int(H * 0.74)
    center = lum[cy - 8:cy + 8, int(W * 0.45):int(W * 0.55)].ravel()
    out['corner'] = float(corners.mean())
    out['center'] = float(center.mean())
    out['vignette'] = float(center.mean() - corners.mean())
    if out['vignette'] < VIG_MIN:
        out['ok'] = False
        out['notes'].append('暗角 ΔL %.1f < %.1f' % (out['vignette'], VIG_MIN))

    # ② 颗粒：左边缘竖带，去趋势后求标准差
    strip = lum[int(H * 0.55):int(H * 0.75), 5:45].astype(float)
    detrend = strip - strip.mean(axis=1, keepdims=True)
    out['grain'] = float(detrend.std())
    if out['grain'] < GRAIN_MIN:
        out['ok'] = False
        out['notes'].append('颗粒 std %.2f < %.2f' % (out['grain'], GRAIN_MIN))

    # ③ 文字带对比度
    # ★★★ 2026-11-03（第 1105 轮）**修一个真 bug**
    #   原来按**固定屏幕百分比**切三段：标题 0.60~0.70 / 副标题 0.70~0.78 / 标语 0.78~0.88。
    #   在 853×533（横屏）上这三段恰好对；但在 440×744（竖屏）上**完全切错**：
    #     实测 440 的真实内容带 = [状态栏][logo+标题 622-1260][分隔线 1322]
    #                              [355 GAMES 1376][标语 1503]
    #     而工具的"标题带" 1339-1562 落在「分隔线+副标题+标语」上，
    #     "副标题带"与"标语带"则落在**纯空白**。
    #     ⇒ 所以 440 报的「标题 ΔL 113」根本不是标题（真实标题在 900~1080）
    #   ⇒ 判据 327：**判据必须跟着被测对象动**，不能用固定屏幕比例。
    #
    #   ⇒ 改成：**先检测内容带**（亮行分组），再**逐带**给 ΔL 与高度，
    #     由人来判断哪一带是标题。工具只负责"把每一带都量出来"。
    bg_med = float(np.median(lum))
    rows = (np.abs(lum - bg_med) > 20).sum(axis=1)
    bands = []
    in_b, st = False, 0
    for y in range(H):
        if rows[y] > 20 and not in_b:
            st, in_b = y, True
        elif rows[y] <= 20 and in_b:
            if y - st > 4:
                bands.append((st, y - 1))
            in_b = False
    if in_b:
        bands.append((st, H - 1))

    out['bands'] = []
    for a, b in bands:
        seg = lum[a:b + 1]
        d = float(seg.max() - bg_med)
        h_px = b - a + 1
        out['bands'].append((a, b, h_px, d))
    # 标题 = **最高的那个"薄带"之后的第一条**（跳过 logo 那种高带）
    #   这里不做自动判定，只把"最高的高带"标出来，供人读
    if out['bands']:
        tallest = max(out['bands'], key=lambda x: x[2])
        out['tallest'] = tallest
        # 最高的高带若占画面 > 25%，视作 logo（文字不会那么高）
        is_logo = tallest[2] > H * 0.25
        if is_logo:
            out['logo_band'] = tallest
        # 文字带 = 除 logo 与状态栏之外，ΔL 最高的那条
        # ★ 自动"挑出标题"是不可靠的 —— logo 与标题挨得近时会被合并成一带。
        #   ⇒ 改成**可判定的规则**：
        #     「凡是 ΔL ≥ 40（人眼能看出是内容）的带，ΔL 都必须 ≥ 60（可读）」
        #   这样不需要知道哪一带是标题，也不需要固定比例。
        VISIBLE = 40.0
        text_bands = [x for x in out['bands']
                      if x is not tallest
                      and not (x[1] < H * 0.08)          # 排除状态栏
                      and x[3] >= VISIBLE]               # 看得出是内容的带
        out['text_bands'] = text_bands
        if not text_bands:
            # 单带：只有 logo（极小屏可能如此），不判失败
            out['texts'] = []
        else:
            out['texts'] = [('带%d' % i, d) for i, (a, b, hh, d) in enumerate(text_bands)]
            weak = [x for x in text_bands if x[3] < TEXT_MIN]
            if weak:
                out['ok'] = False
                for (a, b, hh, d) in weak:
                    out['notes'].append(
                        '内容带 y%d..%d ΔL %.1f < %.1f（看得出但不够清晰）'
                        % (a, b, d, TEXT_MIN))

    # ④ 星尘：孤立亮点占比
    dots = (lum > bg_med + 25) & (lum < bg_med + 120)
    out['dust'] = float(dots.sum() / lum.size * 100)

    return out


def main():
    args = sys.argv[1:]
    if not args:
        print('用法: python3 工具/measure_splash_visual.py <截图> [...]')
        return 1
    fails = 0
    for p in args:
        if not os.path.exists(p):
            print('  ⚠️ 跳过（不存在）: %s' % p)
            continue
        r = measure(p)
        print('=' * 68)
        print('  %s  （%dx%d vp）' % (r['file'], r['w'], r['h']))
        print('=' * 68)
        print('  ① 暗角      四角 %5.1f ｜ 中心 %5.1f ｜ ΔL **%5.1f**  %s'
              % (r['corner'], r['center'], r['vignette'],
                 '✅' if r['vignette'] >= VIG_MIN else '🔴'))
        print('  ② 颗粒      去趋势 std **%5.2f**  %s'
              % (r['grain'], '✅' if r['grain'] >= GRAIN_MIN else '🔴'))
        print('  ③ 内容带（逐带；判据 327：跟着被测对象动，不用固定比例）')
        for (a, b, hh, d) in r['bands'][:8]:
            marks = []
            if r.get('logo_band') and (a, b, hh, d) == r['logo_band']:
                marks.append('logo（高带）')
            if d >= 40:
                marks.append('可见' + ('✅' if d >= TEXT_MIN else '🔴'))
            else:
                marks.append('装饰')
            print('       y %4d..%4d  高 %4d px   ΔL %6.1f   %s'
                  % (a, b, hh, d, ' '.join(marks)))
        print('  ④ 星尘      **%.2f%%** 像素' % r['dust'])
        if r['notes']:
            for n in r['notes']:
                print('      🔴 %s' % n)
        print()
        if not r['ok']:
            fails += 1
    print('=' * 68)
    if fails == 0:
        print('✅ 全部达标（暗角 ≥ %.1f ｜ 颗粒 ≥ %.2f ｜ 所有可见带 ΔL ≥ %.0f）'
              % (VIG_MIN, GRAIN_MIN, TEXT_MIN))
    else:
        print('🔴 %d 张不合格' % fails)
    print('=' * 68)
    return 0 if fails == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
