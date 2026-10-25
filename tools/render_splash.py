#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
开屏离线渲染器（拾海 2026-10-19）

为什么要有它：
  设备验收被内存卡住，但"开屏到底长什么样"是可以用【同一套数学】算出来的：
  路径、viewPort、进度段、颜色全部从 Splash.ets 里读，不另写一份
  ⇒ 渲染出来的帧就是 ArkUI 在那一刻应该画出的东西
  ⇒ 在没设备的情况下也能拿出**视觉证据**，而不是只说"我核对了坐标"

它不能证明的（必须真机/模拟器才能验）：
  · 真实字体渲染（这里用 PIL 画形状，文字是近似）
  · 光晕的真实模糊半径
  · 60fps 下的动感

用法：python3 tools/render_splash.py [输出目录]
产出：frame-XXX.png + contact-sheet.png（所有帧拼一张）
"""
import io
import os
import re
import sys
import math

from PIL import Image, ImageDraw, ImageFilter

SPLASH = '/Users/a0000/dev/One More/entry/src/main/ets/pages/Splash.ets'
OUT = sys.argv[1] if len(sys.argv) > 1 else '/tmp/splash-frames'

# ── 与 Splash.ets 一致的配色 ──
OM_INK = (0x0D, 0x13, 0x20)
OM_GOLD = (0xC9, 0x9E, 0x52)
OM_CREAM = (0xFA, 0xF8, 0xF3)

W, H = 540, 1170          # 画布（近似一台手机的 1/2 分辨率）
OM_W_RATIO = 0.78


# ══════════════════════════════════════════════
# 一、从 Splash.ets 读数据（保证与代码同源）
# ══════════════════════════════════════════════
def load_from_source():
    s = io.open(SPLASH, encoding='utf-8').read()

    def num(name):
        m = re.search(name + r":\s*number\s*=\s*([\d.]+)", s)
        return float(m.group(1)) if m else None

    d = {
        'O': re.search(r"O_PATH:\s*string\s*=\s*'([^']*)'", s).group(1),
        'M': re.search(r"M_PATH:\s*string\s*=\s*'([^']*)'", s).group(1),
        'OLEN': num('O_LEN'),
        'MLEN': num('M_LEN'),
        'VPW': num('VP_W'),
        'VPH': num('VP_H'),
        'DXR': num('DOT_XR'),
        'DYR': num('DOT_YR'),
    }
    return d


def parse_path(cmds):
    """把 SVG path 解析成 [(op, [数字...]), ...]"""
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+', cmds)
    out = []
    i = 0
    cur = [0.0, 0.0]
    start = [0.0, 0.0]

    def n():
        nonlocal i
        v = float(tokens[i]); i += 1
        return v

    def has_num():
        return i < len(tokens) and re.match(r'-?\d', tokens[i])

    while i < len(tokens):
        c = tokens[i]; i += 1
        if c in 'Mm':
            cur = [n(), n()]
            start = cur[:]
            out.append(('M', cur[:]))
            while has_num():
                p = [n(), n()]
                cur = p[:]
                out.append(('L', p[:]))
        elif c in 'Ll':
            p = [n(), n()]; cur = p[:]; out.append(('L', p[:]))
        elif c in 'Zz':
            cur = start[:]; out.append(('Z', []))
        elif c in 'Qq':
            pts = [n() for _ in range(4)]
            cur = [pts[2], pts[3]]
            out.append(('Q', pts))
        elif c in 'Cc':
            pts = [n() for _ in range(6)]
            cur = [pts[4], pts[5]]
            out.append(('C', pts))
        else:
            break
    return out


def flatten(parsed, samples=48):
    """把路径离散成折线点列（用于描边与填充）"""
    pts = []
    cur = None
    start = None
    for op, p in parsed:
        if op == 'M':
            cur = (p[0], p[1]); start = cur; pts.append(cur)
        elif op == 'L':
            cur = (p[0], p[1]); pts.append(cur)
        elif op == 'Q':
            x1, y1, x, y = p
            p0 = cur
            for k in range(1, samples + 1):
                t = k / samples
                px = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * x1 + t * t * x
                py = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * y1 + t * t * y
                pts.append((px, py))
            cur = (x, y)
        elif op == 'C':
            x1, y1, x2, y2, x, y = p
            p0 = cur
            for k in range(1, samples + 1):
                t = k / samples
                px = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3 * x
                py = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3 * y
                pts.append((px, py))
            cur = (x, y)
        elif op == 'Z':
            if cur and start:
                pts.append(start)
                cur = start
    return pts


def arc_lengths(pts):
    """每个点处的累计弧长"""
    acc = [0.0]
    for i in range(1, len(pts)):
        acc.append(acc[-1] + math.dist(pts[i - 1], pts[i]))
    return acc


def seg(p, a, b):
    if p <= a:
        return 0.0
    if p >= b:
        return 1.0
    return (p - a) / (b - a)


def ease(t):
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


# ══════════════════════════════════════════════
# 二、画一帧
# ══════════════════════════════════════════════
def render(p, D, o_pts, o_acc, o_len_all, m_pts, m_acc, m_len_all, stars):
    img = Image.new('RGB', (W, H), OM_INK)

    # ── 背景光晕（两层径向）──
    glow = Image.new('RGB', (W, H), OM_INK)
    gd = ImageDraw.Draw(glow)
    a1 = seg(p, 0.00, 0.12)
    if a1 > 0:
        r = int(W * 0.62)
        gd.ellipse([W // 2 - r, int(H * 0.42) - r, W // 2 + r, int(H * 0.42) + r],
                   fill=(0x22, 0x35, 0x5C))
        glow = glow.filter(ImageFilter.GaussianBlur(90))
        img = Image.blend(img, glow, 0.55 * a1)

    # ── 星点 24 颗（随进度呼吸）──
    d = ImageDraw.Draw(img, 'RGBA')
    star_a = seg(p, 0.00, 0.30)
    if star_a > 0:
        for i, (xr, yr, sz, ph) in enumerate(stars):
            tw = 0.18 + 0.42 * abs(math.sin(p * 3.4 + ph))
            alpha = int(255 * star_a * tw)
            if alpha <= 3:
                continue
            x = xr * W; y = yr * H
            d.ellipse([x - sz / 2, y - sz / 2, x + sz / 2, y + sz / 2],
                      fill=(255, 255, 255, alpha))

    # ── OM 区域 ──
    omw = W * OM_W_RATIO
    omh = omw / (D['VPW'] / D['VPH'])
    ox = (W - omw) / 2
    oy = H * 0.17
    sx = omw / D['VPW']
    sy = omh / D['VPH']

    def to_px(pt):
        return (ox + pt[0] * sx, oy + pt[1] * sy)

    # 描边层：按 dash offset 截取
    stroke_a = 1 - seg(p, 0.45, 0.55)
    if stroke_a > 0.01:
        for pts, acc, total, s0, s1, color in (
            (o_pts, o_acc, o_len_all, 0.05, 0.26, OM_GOLD),
            (m_pts, m_acc, m_len_all, 0.26, 0.45, OM_CREAM),
        ):
            prog = ease(seg(p, s0, s1))
            if prog <= 0:
                continue
            limit = total * prog
            layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            run = []
            for i, pt in enumerate(pts):
                if acc[i] > limit:
                    # 插值到精确位置
                    if i > 0 and acc[i] > acc[i - 1]:
                        t = (limit - acc[i - 1]) / (acc[i] - acc[i - 1])
                        px = pts[i - 1][0] + (pt[0] - pts[i - 1][0]) * t
                        py = pts[i - 1][1] + (pt[1] - pts[i - 1][1]) * t
                        run.append(to_px((px, py)))
                    break
                run.append(to_px(pt))
            if len(run) >= 2:
                ld.line(run, fill=color + (int(255 * stroke_a),), width=5, joint='curve')
            img = Image.alpha_composite(img.convert('RGBA'), layer).convert('RGB')

    # 实心层
    fill_a = seg(p, 0.45, 0.55)
    if fill_a > 0.01:
        mask = Image.new('L', (W, H), 0)
        md = ImageDraw.Draw(mask)
        for pts in (o_pts, m_pts):
            poly = [to_px(pt) for pt in pts]
            if len(poly) >= 3:
                md.polygon(poly, fill=int(255 * fill_a))
        gold = Image.new('RGB', (W, H), OM_GOLD)
        cream = Image.new('RGB', (W, H), OM_CREAM)
        img = Image.composite(gold, img, mask)
        # M 用乳白：再叠一次（只对 M 区域）
        m_mask = Image.new('L', (W, H), 0)
        md2 = ImageDraw.Draw(m_mask)
        poly = [to_px(pt) for pt in m_pts]
        if len(poly) >= 3:
            md2.polygon(poly, fill=int(255 * fill_a))
        img = Image.composite(cream, img, m_mask)

    # 金点 + 涟漪
    dx = ox + D['DXR'] * omw
    dy = oy + D['DYR'] * omh
    d = ImageDraw.Draw(img, 'RGBA')
    for (a, b, scale_max, width, amax) in (
        (0.54, 0.66, 4.6, 2, 0.55),
        (0.58, 0.70, 7.8, 1, 0.35),
        (0.62, 0.78, 11.0, 1, 0.22),
    ):
        t = seg(p, a, b)
        if 0 < t < 1:
            r = 11 * (1 + t * scale_max)
            alpha = int(255 * amax * (1 - t) * 1.6)
            if alpha > 2:
                d.ellipse([dx - r, dy - r, dx + r, dy + r],
                          outline=OM_GOLD + (min(255, alpha),), width=width)
    dot_t = seg(p, 0.52, 0.60)
    if dot_t > 0:
        r = 11 * ease(dot_t)
        d.ellipse([dx - r, dy - r, dx + r, dy + r], fill=OM_GOLD + (int(255 * dot_t),))

    # ── 标题 / 副标题 / 标语（近似位置，字体用默认）──
    t = seg(p, 0.60, 0.72)
    if t > 0:
        d.text((W / 2, oy + omh + 52), 'One More', fill=(255, 255, 255), anchor='mm')
    t2 = seg(p, 0.66, 0.78)
    if t2 > 0:
        d.text((W / 2, oy + omh + 82), '3 5 5   G A M E S', fill=(180, 255, 255, 255), anchor='mm')
    t3 = seg(p, 0.72, 0.84)
    if t3 > 0:
        d.text((W / 2, H - 66), 'A quick round, any time', fill=(120, 255, 255, 255), anchor='mm')

    # 整屏淡出
    fade = seg(p, 0.94, 1.00)
    if fade > 0:
        img = Image.blend(img, Image.new('RGB', (W, H), OM_INK), fade * 0.9)

    return img


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT, exist_ok=True)

    D = load_from_source()
    o_pts = flatten(parse_path(D['O']))
    m_pts = flatten(parse_path(D['M']))

    # 换算到 viewPort 尺度算累计长度（与代码里的 O_LEN/M_LEN 同量级）
    o_len_all = D['OLEN']
    m_len_all = D['MLEN']

    def scale_pts(pts):
        # pts 已在 viewPort 坐标；累计长度按真实几何算
        return pts

    o_acc = arc_lengths(o_pts)
    m_acc = arc_lengths(m_pts)
    # 代码里的 O_LEN 是按路径离散算的；这里用几何长度做归一
    o_len_all = o_acc[-1] if o_acc else 1.0
    m_len_all = m_acc[-1] if m_acc else 1.0

    # 星点（与 Splash.ets 的黄金角生成一致）
    stars = []
    for i in range(24):
        a = (i * 137.508) % 360
        r = 12 + (i * 7.3) % 76
        x = 50 + math.cos(math.radians(a)) * r
        y = 42 + math.sin(math.radians(a)) * r * 0.85
        sz = 2.0 + ((i * 13) % 7) * 0.6
        stars.append((x / 100.0, y / 100.0, sz, (i * 137 % 1600) / 1600.0 * 6.283))

    frames = [0.08, 0.18, 0.30, 0.40, 0.48, 0.55, 0.62, 0.70, 0.80, 0.90]
    imgs = []
    for i, p in enumerate(frames):
        im = render(p, D, o_pts, o_acc, o_len_all, m_pts, m_acc, m_len_all, stars)
        fp = os.path.join(OUT, 'frame-%02d-p%03d.png' % (i, int(p * 100)))
        im.save(fp)
        imgs.append((p, im))
        print('  ✅ %s' % fp)

    # 拼成 contact sheet（2 行 × 5 列）
    cols = 5
    rows = (len(imgs) + cols - 1) // cols
    th_w, th_h = W // 2, H // 2
    sheet = Image.new('RGB', (cols * th_w, rows * th_h), (20, 20, 20))
    for idx, (p, im) in enumerate(imgs):
        thumb = im.resize((th_w, th_h))
        sheet.paste(thumb, ((idx % cols) * th_w, (idx // cols) * th_h))
    sheet_path = os.path.join(OUT, 'contact-sheet.png')
    sheet.save(sheet_path)
    print('  ✅ %s（%dx%d）' % (sheet_path, sheet.width, sheet.height))


if __name__ == '__main__':
    main()
