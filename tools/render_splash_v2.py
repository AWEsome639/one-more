# -*- coding: utf-8 -*-
"""开屏离线近似渲染（2026-11-27，HP）

为什么重写：
  旧 renderer（2026-10-19）解析的是当时 Splash.ets 的常量名（DOT_XR 等），
  Splash.ets 之后重构过，旧脚本已经跑不起来。
  本脚本按**现在的 Splash.ets 分镜表**（2,270ms / 10 层）重画一遍。

它不是逐像素真机：
  · 字体用系统字体近似（真机是 HarmonyOS 默认字体）
  · 光晕/模糊半径是近似值
  · 路径描边用几何近似（O 用椭圆弧、M 用折线）
  ⇒ 用途是给长视频做开场素材/参考，不当作 UI 验收证据。

输出：1080×2340 PNG 序列（60fps，2270ms = 137 帧）+ splash.mp4
"""
import io
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 2340
FPS = 60
TOTAL = 2270.0
INK = (13, 19, 32)
INK_HI = (22, 34, 58)
GOLD = (201, 158, 82)
GOLD_HI = (240, 217, 168)
CREAM = (250, 248, 243)

OM_VIEW_W, OM_VIEW_H = 3675.0, 1855.0
OM_W = int(W * 0.72)
OM_H = int(OM_W / (OM_VIEW_W / OM_VIEW_H))
OM_X = (W - OM_W) // 2
OM_Y = int(H * 0.27)

M_PTS = [(1813.4, 1743.5), (2138.4, 83.5), (2668.4, 1283.5), (3217.4, 83.5), (3509.4, 1743.5)]

FONT_CJK = r'C:\Windows\Fonts\msyh.ttc'
FONT_SERIF = r'C:\Windows\Fonts\georgiab.ttf'


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def ease_out(x):
    return 1 - (1 - x) ** 3


def ease_in_out(x):
    return x * x * (3 - 2 * x)


def seg(pms, start, dur):
    return clamp((pms - start) / dur) if dur > 0 else (1.0 if pms >= start else 0.0)


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def base_layer(pms):
    img = Image.new('RGB', (W, H), INK)
    d = ImageDraw.Draw(img)
    a = seg(pms, 0, 240)
    if a > 0:
        # 底色亮部：中心偏上的径向渐变（近似星云）
        neb = Image.new('RGB', (W, H), INK)
        nd = ImageDraw.Draw(neb)
        for i in range(28, 0, -1):
            r = int(W * 0.9 * i / 28)
            f = i / 28
            col = tuple(int(INK[c] + (INK_HI[c] - INK[c]) * (1 - f) * 0.9) for c in range(3))
            nd.ellipse([W // 2 - r, int(H * 0.34) - r, W // 2 + r, int(H * 0.34) + r], fill=col)
        neb = neb.filter(ImageFilter.GaussianBlur(80))
        img = Image.blend(img, neb, 0.85 * a)
    return img


def stars_layer(img, pms):
    d = ImageDraw.Draw(img, 'RGBA')
    for i in range(24):
        ang = (i * 137.508) % 360
        rr = 0.06 + ((i * 7.3) % 76) / 100.0
        x = W * (0.5 + math.cos(math.radians(ang)) * rr * 0.45)
        y = H * (0.40 + math.sin(math.radians(ang)) * rr * 0.22)
        tw = 0.25 + 0.75 * abs(math.sin(pms / 1000.0 * 3.4 + i * 0.7))
        alpha = int(150 * tw * seg(pms, 170, 900))
        sz = 2 + (i % 4)
        d.ellipse([x - sz, y - sz, x + sz, y + sz], fill=(240, 230, 205, alpha))


def glow_layer(img, pms):
    a = seg(pms, 200, 600) * (1 - 0.4 * seg(pms, 1950, 320))
    if a <= 0:
        return img
    glow = Image.new('RGB', (W, H), INK)
    gd = ImageDraw.Draw(glow)
    r = int(W * 0.55)
    cy = int(OM_Y + OM_H * 0.55)
    for i in range(20, 0, -1):
        rr = int(r * i / 20)
        col = tuple(int(GOLD[c] * (1 - i / 26) + INK[c] * (i / 26)) for c in range(3))
        gd.ellipse([W // 2 - rr, cy - rr, W // 2 + rr, cy + rr], fill=col)
    glow = glow.filter(ImageFilter.GaussianBlur(110))
    return Image.blend(img, glow, 0.55 * a)


def draw_om(img, pms):
    d = ImageDraw.Draw(img, 'RGBA')
    # L4a：O 环描边（近似椭圆，自左下起顺时针画）
    oa = seg(pms, 280, 980)
    if oa > 0:
        # O 在 viewBox 左半（165..1700），M 在右半（1813..3509）—— 以前用整幅宽椭圆，
        # 会把 M 整个包进 O 里，形状就错了。
        sx0 = OM_W / OM_VIEW_W
        sy0 = OM_H / OM_VIEW_H
        cx = OM_X + ((165.0 + 1700.0) / 2) * sx0
        cy = OM_Y + ((170.0 + 1743.0) / 2) * sy0
        rx = ((1700.0 - 165.0) / 2) * sx0
        ry = ((1743.0 - 170.0) / 2) * sy0
        steps = max(2, int(240 * ease_out(oa)))
        pts = []
        start = math.radians(140)
        for k in range(steps + 1):
            t = start + (2 * math.pi * ease_out(oa)) * k / steps
            pts.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
        d.line(pts, fill=GOLD + (235,), width=max(2, int(OM_W * 0.018)), joint='curve')
        if oa >= 1:
            d.line(pts[:len(pts) // 2], fill=GOLD_HI + (170,), width=max(1, int(OM_W * 0.006)), joint='curve')
    # L4a‴：M 山（折线，按长度比例描边）
    ma = seg(pms, 350, 460)
    if ma > 0:
        sx = OM_W / OM_VIEW_W
        sy = OM_H / OM_VIEW_H
        pts = [(OM_X + x * sx, OM_Y + (y - 0) * sy) for (x, y) in M_PTS]
        lens = [0.0]
        for i in range(1, len(pts)):
            lens.append(lens[-1] + math.dist(pts[i - 1], pts[i]))
        total = lens[-1]
        limit = total * ease_out(ma)
        out = [pts[0]]
        for i in range(1, len(pts)):
            if lens[i] <= limit:
                out.append(pts[i])
            else:
                r = (limit - lens[i - 1]) / (lens[i] - lens[i - 1])
                out.append((pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * r,
                            pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * r))
                break
        d.line(out, fill=GOLD + (235,), width=max(2, int(OM_W * 0.018)), joint='curve')
    # L4a'：日出金点（从山脊后升起）
    sun = seg(pms, 280, 420)
    if sun > 0:
        sx = OM_W / OM_VIEW_W
        sy = OM_H / OM_VIEW_H
        x = OM_X + 2668.4 * sx
        ridge = OM_Y + 1283.5 * sy
        y = ridge - (ridge - (OM_Y + 900 * sy)) * ease_out(sun)
        r = OM_W * 0.022
        d.ellipse([x - r, y - r, x + r, y + r], fill=GOLD_HI + (255,))
    # L4b：填充点亮（OM 内部极淡的金色）
    fill = seg(pms, 600, 440)
    if fill > 0:
        d.ellipse([OM_X + OM_W * 0.10, OM_Y + OM_H * 0.10, OM_X + OM_W * 0.90, OM_Y + OM_H * 0.92],
                  fill=GOLD + (int(26 * fill),))


def sweep_layer(img, pms):
    a = seg(pms, 740, 520)
    if a <= 0 or a >= 1:
        return img
    band = Image.new('RGB', (W, H), INK)
    bd = ImageDraw.Draw(band)
    x = int(-W * 0.4 + (W * 1.6) * ease_in_out(a))
    bw = int(W * 0.08)
    bd.polygon([(x, 0), (x + bw, 0), (x + bw + H * 0.3, H), (x + H * 0.3, H)], fill=(255, 240, 200))
    band = band.filter(ImageFilter.GaussianBlur(24))
    return Image.blend(img, band, 0.16 * (1 - abs(a - 0.5) * 2))


def text_layer(img, pms):
    d = ImageDraw.Draw(img, 'RGBA')
    # L6 标题：逐字
    ta = seg(pms, 820, 550)
    if ta > 0:
        f = font(FONT_SERIF, int(W * 0.075))
        s = 'One More'
        widths = [d.textlength(ch, font=f) for ch in s]
        total = sum(widths) + int(W * 0.006) * (len(s) - 1)
        x = (W - total) / 2
        y = OM_Y + OM_H + int(H * 0.035)
        for i, ch in enumerate(s):
            ca = clamp(ta * 1.35 - i * 0.09)
            if ca > 0:
                d.text((x, y), ch, font=f, fill=CREAM + (int(255 * ca),))
            x += widths[i] + int(W * 0.006)
        # 金线
        la = seg(pms, 900, 420)
        if la > 0:
            ly = y + int(W * 0.10)
            half = int(W * 0.24 * ease_out(la))
            d.line([(W // 2 - half, ly), (W // 2 + half, ly)], fill=GOLD + (210,), width=2)
    # L7 副标题
    sa = seg(pms, 1050, 300)
    if sa > 0:
        f = font(FONT_CJK, int(W * 0.042))
        s = '355 款小游戏'
        tw = d.textlength(s, font=f)
        d.text(((W - tw) / 2, OM_Y + OM_H + int(H * 0.115)), s, font=f, fill=CREAM + (int(230 * sa),))
    # L8 标语
    ga = seg(pms, 1180, 300)
    if ga > 0:
        f = font(FONT_CJK, int(W * 0.034))
        s = '碎片时间，随时开局'
        tw = d.textlength(s, font=f)
        d.text(((W - tw) / 2, OM_Y + OM_H + int(H * 0.16)), s, font=f, fill=(180, 168, 140, int(220 * ga)))


def render_frame(i):
    pms = i * 1000.0 / FPS          # 当前毫秒（分镜表用的就是毫秒）
    img = base_layer(pms)
    stars_layer(img, pms)
    img = glow_layer(img, pms)
    draw_om(img, pms)
    img = sweep_layer(img, pms)
    text_layer(img, pms)
    # L9 推出：scale 1→0.94 + 淡出
    out = seg(pms, 1950, 320)
    if out > 0:
        sc = 1 - 0.06 * ease_out(out)
        nw, nh = int(W * sc), int(H * sc)
        canvas = Image.new('RGB', (W, H), INK)
        canvas.paste(img.resize((nw, nh), Image.LANCZOS), ((W - nw) // 2, (H - nh) // 2))
        img = Image.blend(canvas, Image.new('RGB', (W, H), INK), 0.85 * out)
    # 暗角 + 颗粒
    vig = Image.new('L', (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-W * 0.25, -H * 0.15, W * 1.25, H * 1.15], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(160))
    img = Image.composite(img, Image.new('RGB', (W, H), INK), vig)
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else r'C:\biliup\onemore\assets\splash\frames'
    os.makedirs(out, exist_ok=True)
    n = int(TOTAL / 1000.0 * FPS) + 1
    for i in range(n):
        render_frame(i).save(os.path.join(out, 'f%04d.png' % i))
    print('frames:', n, '->', out)
    # 组装 mp4
    try:
        import imageio_ffmpeg
        ff = imageio_ffmpeg.get_ffmpeg_exe()
        mp4 = os.path.join(os.path.dirname(out), 'splash.mp4')
        import subprocess
        subprocess.run([ff, '-y', '-framerate', str(FPS), '-i', os.path.join(out, 'f%04d.png'),
                        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', mp4],
                       capture_output=True, timeout=600)
        print('mp4:', mp4, os.path.getsize(mp4) if os.path.exists(mp4) else 'FAIL')
    except Exception as e:
        print('mp4 failed:', e)


if __name__ == '__main__':
    main()
