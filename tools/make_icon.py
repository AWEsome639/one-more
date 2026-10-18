#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一局 · 应用图标生成（拾海 2026-10-10）

设计思路（**原创**，不抄任何现成图标）：
  「一局」= 一屏很多小游戏，随手挑一个开一局。
  ⇒ 图形语言：**2×2 四块圆角砖**，代表"一堆小游戏"；
     右下那块**微微翘起**（旋转+抬高），代表"就它了，来一局"。
  底图：品牌渐变 靛蓝 → 紫罗兰（横贯），四块砖各用品牌色板里的一个强调色。

HarmonyOS 分层图标规范：
  background.png  —— 1024×1024 满幅（会被系统裁成圆/方轮廓）
  foreground.png  —— 1024×1024 透明底，内容压在**中央安全区**（约 60%），
                     否则被遮罩切掉边角
"""
from PIL import Image, ImageDraw, ImageFilter
import os
import math

S = 1024                      # 画布
OUT = os.path.dirname(os.path.abspath(__file__))

INDIGO = (67, 56, 202)      # 底图深靛
VIOLET = (109, 40, 217)      # 底图深紫
BERRY = (236, 72, 153)
EMERALD = (16, 185, 129)
AMBER = (245, 158, 11)
SKY = (14, 165, 233)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(size, c1, c2, diagonal=True):
    """对角线性渐变"""
    img = Image.new('RGB', (size, size), c1)
    d = ImageDraw.Draw(img)
    for y in range(size):
        for_t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=lerp(c1, c2, for_t))
    if diagonal:
        # 叠一层横向渐变做对角感
        img2 = Image.new('RGB', (size, size), c1)
        d2 = ImageDraw.Draw(img2)
        for x in range(size):
            t = x / (size - 1)
            d2.line([(x, 0), (x, size)], fill=lerp((0, 0, 0), (255, 255, 255), 0))
        img = Image.blend(img, img2, 0.0)
    return img


def rounded_tile(size, radius, color):
    """一块圆角方砖（带 alpha）"""
    t = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=color + (255,))
    return t


def make_background():
    """底图：靛蓝 → 紫罗兰 对角渐变 + 轻微光晕"""
    bg = Image.new('RGB', (S, S))
    px = bg.load()
    for y in range(S):
        for x in range(0, S, 4):          # 步进 4 提速，后面 resize 抹平
            t = (x + y) / (2 * (S - 1))
            c = lerp(INDIGO, VIOLET, t)
            for dx in range(4):
                if x + dx < S:
                    px[x + dx, y] = c
    bg = bg.filter(ImageFilter.GaussianBlur(2))

    # 左上角一团柔光，让底不呆板
    glow = Image.new('L', (S, S), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-S * 0.25, -S * 0.30, S * 0.72, S * 0.62], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    white = Image.new('RGB', (S, S), (255, 255, 255))
    bg = Image.composite(white, bg, glow)
    return bg


def make_foreground():
    """前景：2×2 四块圆角砖，右下那块翘起"""
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))

    card = int(S * 0.215)         # 单块边长
    gap = int(S * 0.045)
    radius = int(card * 0.30)
    total = card * 2 + gap
    ox = (S - total) // 2
    oy = (S - total) // 2

    spots = [
        (ox, oy, SKY, 0),
        (ox + card + gap, oy, BERRY, 0),
        (ox, oy + card + gap, EMERALD, 0),
        (ox + card + gap, oy + card + gap, AMBER, -9),   # 右下：翘 9°
    ]

    for (x, y, color, angle) in spots:
        tile = rounded_tile(card, radius, color)
        # 每块加一点内高光，显得有厚度
        hl = Image.new('RGBA', (card, card), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hl)
        hd.rounded_rectangle([int(card * 0.07), int(card * 0.07), int(card * 0.93), int(card * 0.55)],
                             radius=int(radius * 0.85), fill=(255, 255, 255, 38))
        tile = Image.alpha_composite(tile, hl)

        if angle:
            tile = tile.rotate(angle, resample=Image.BICUBIC, expand=True)
            # 翘起的那块稍微抬高
            px = x - (tile.size[0] - card) // 2
            py = y - (tile.size[1] - card) // 2 - int(S * 0.012)
        else:
            px, py = x, y

        # 阴影
        sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle([px + 6, py + 10, px + tile.size[0] - 6, py + tile.size[1] - 4],
                             radius=radius, fill=(15, 12, 60, 90))
        sh = sh.filter(ImageFilter.GaussianBlur(14))
        fg = Image.alpha_composite(fg, sh)
        fg.alpha_composite(tile, (px, py))

    return fg


def make_start_icon():
    """启动图标：底图 + 前景合成，再压成方图"""
    bg = make_background().convert('RGBA')
    fg = make_foreground()
    return Image.alpha_composite(bg, fg).convert('RGB')


if __name__ == '__main__':
    bg = make_background()
    fg = make_foreground()
    start = make_start_icon()

    bg.save(os.path.join(OUT, 'background.png'))
    fg.save(os.path.join(OUT, 'foreground.png'))
    start.save(os.path.join(OUT, 'startIcon.png'))

    # 预览图（1024 合成 + 圆形裁切预览 + 小尺寸预览）
    prev = Image.new('RGB', (S, S), (255, 255, 255))
    prev.paste(start, (0, 0))
    prev.save(os.path.join(OUT, '_preview_full.png'))

    small = start.resize((216, 216), Image.LANCZOS)
    small.save(os.path.join(OUT, '_preview_216.png'))

    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    circ = Image.new('RGB', (S, S), (255, 255, 255))
    circ.paste(start, (0, 0), mask)
    circ.resize((420, 420), Image.LANCZOS).save(os.path.join(OUT, '_preview_circle.png'))

    print('✅ 图标已生成：background.png / foreground.png / startIcon.png')
