#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从「开屏最后一帧」生成应用图标（拾海 2026-10-19）

奥森：「应用图标应该要和开屏画面差不多吧，可以改改」

开屏最后一帧 = 深墨蓝底 + 金色 O + **O 中心一颗金点** + 象牙白 M
旧图标（tools/make_icon.py，10-10 版）的 O 是空心环，**没有那颗粒** ⇒ 两者不是同一个东西。

本脚本用【与 Splash.ets 完全相同的路径数据】重画，保证字形/配色同源。

产出：
  AppScope + entry 两处的 foreground.png / background.png（鸿蒙分层图标，两处都要写 —— 铁律 122）
  上架材料/app-icon-1024.png、app-icon-216.png（AGC 上传，不透明全幅方块）
  桌面 OneMore-图标-1024.png / -216.png

用法：python3 tools/icon-from-splash.py
"""
import io
import os
import re

from PIL import Image, ImageDraw, ImageFilter

ROOT = '/Users/a0000/dev/One More'
SPLASH = ROOT + '/entry/src/main/ets/pages/Splash.ets'
APP_MEDIA = ROOT + '/AppScope/resources/base/media'
ENTRY_MEDIA = ROOT + '/entry/src/main/resources/base/media'
AGC_DIR = ROOT + '/上架材料'
DESKTOP = os.path.expanduser('~/Desktop')

INK = (0x0D, 0x13, 0x20)
GOLD = (0xC9, 0x9E, 0x52)
CREAM = (0xFA, 0xF8, 0xF3)

S = 1024
SUBJECT_W = 0.62      # 鸿蒙分层图标：主体占 62% 安全区


def load():
    s = io.open(SPLASH, encoding='utf-8').read()
    return {
        'O': re.search(r"O_PATH:\s*string\s*=\s*'([^']*)'", s).group(1),
        'M': re.search(r"M_PATH:\s*string\s*=\s*'([^']*)'", s).group(1),
    }


def parse_path(cmds):
    tokens = re.findall(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+', cmds)
    out = []
    i = 0
    cur = [0.0, 0.0]
    start = [0.0, 0.0]

    def n():
        nonlocal i
        v = float(tokens[i]); i += 1
        return v

    while i < len(tokens):
        c = tokens[i]; i += 1
        if c in 'Mm':
            cur = [n(), n()]; start = cur[:]; out.append(('M', cur[:]))
            while i < len(tokens) and re.match(r'-?\d', tokens[i]):
                p = [n(), n()]; cur = p[:]; out.append(('L', p[:]))
        elif c in 'Ll':
            p = [n(), n()]; cur = p[:]; out.append(('L', p[:]))
        elif c in 'Zz':
            cur = start[:]; out.append(('Z', []))
        elif c in 'Qq':
            pts = [n() for _ in range(4)]; cur = [pts[2], pts[3]]; out.append(('Q', pts))
        elif c in 'Cc':
            pts = [n() for _ in range(6)]; cur = [pts[4], pts[5]]; out.append(('C', pts))
        else:
            break
    return out


def flatten(parsed, samples=64):
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
                pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * x1 + t * t * x,
                            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * y1 + t * t * y))
            cur = (x, y)
        elif op == 'C':
            x1, y1, x2, y2, x, y = p
            p0 = cur
            for k in range(1, samples + 1):
                t = k / samples
                pts.append(((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3 * x,
                            (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3 * y))
            cur = (x, y)
        elif op == 'Z':
            if cur and start:
                pts.append(start); cur = start
    return pts


def build(d):
    o_pts = flatten(parse_path(d['O']))
    m_pts = flatten(parse_path(d['M']))

    allx = [p[0] for p in o_pts] + [p[0] for p in m_pts]
    ally = [p[1] for p in o_pts] + [p[1] for p in m_pts]
    x0, x1 = min(allx), max(allx)
    y0, y1 = min(ally), max(ally)
    w = x1 - x0
    h = y1 - y0
    scale = (S * SUBJECT_W) / w
    offx = (S - w * scale) / 2 - x0 * scale
    offy = (S - h * scale) / 2 - y0 * scale

    def to_px(p):
        return (p[0] * scale + offx, p[1] * scale + offy)

    # 前景：透明底
    fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    mo = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mo).polygon([to_px(p) for p in o_pts], fill=255)
    mm = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mm).polygon([to_px(p) for p in m_pts], fill=255)

    fg = Image.composite(Image.new('RGBA', (S, S), GOLD + (255,)), fg, mo)
    fg = Image.composite(Image.new('RGBA', (S, S), CREAM + (255,)), fg, mm)

    # ★ 关键：O 中心那颗金点（开屏最后一帧落下的那一颗）
    oxs = [p[0] for p in o_pts]
    oys = [p[1] for p in o_pts]
    cx, cy = to_px(((min(oxs) + max(oxs)) / 2, (min(oys) + max(oys)) / 2))
    o_diam = (max(oxs) - min(oxs)) * scale
    # ★ 2026-10-19：从 0.065 提到 0.09 ——
    #   尺寸阶梯实测：0.065 在 48px 时几乎看不见；0.09 能守住到 48px，
    #   且仍然是“O 里一颗点”而不是“实心 O”
    dot_r = o_diam * 0.09
    ImageDraw.Draw(fg).ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
                               fill=GOLD + (255,))

    # 背景：深墨蓝 + 极淡中心光晕（与开屏同一套观感）
    bg = Image.new('RGB', (S, S), INK)
    glow = Image.new('RGB', (S, S), INK)
    gd = ImageDraw.Draw(glow)
    gr = int(S * 0.52)
    gd.ellipse([S // 2 - gr, int(S * 0.44) - gr, S // 2 + gr, int(S * 0.44) + gr],
               fill=(0x1A, 0x26, 0x3E))
    glow = glow.filter(ImageFilter.GaussianBlur(int(S * 0.12)))
    bg = Image.blend(bg, glow, 0.55)

    return fg, bg


def main():
    d = load()
    fg, bg = build(d)

    # ① 分层图标：两处都要写（铁律 122：真正生效的是 AppScope）
    for media in (APP_MEDIA, ENTRY_MEDIA):
        if not os.path.isdir(media):
            os.makedirs(media, exist_ok=True)
        fg.save(os.path.join(media, 'foreground.png'))
        bg.save(os.path.join(media, 'background.png'))
        print('  ✅ %s/{foreground,background}.png' % media.replace(ROOT + '/', ''))

    # ② AGC 上传（不透明全幅方块）
    flat = Image.alpha_composite(bg.convert('RGBA'), fg).convert('RGB')
    os.makedirs(AGC_DIR, exist_ok=True)
    p1024 = os.path.join(AGC_DIR, 'app-icon-1024.png')
    flat.save(p1024)
    flat.resize((216, 216), Image.LANCZOS).save(os.path.join(AGC_DIR, 'app-icon-216.png'))
    flat.save(os.path.join(DESKTOP, 'OneMore-图标-1024.png'))
    flat.resize((216, 216), Image.LANCZOS).save(os.path.join(DESKTOP, 'OneMore-图标-216.png'))
    flat.resize((512, 512), Image.LANCZOS).save('/tmp/icon-new-512.png')

    print('  ✅ 上架材料/app-icon-1024.png + -216.png')
    print('  ✅ 桌面 OneMore-图标-1024.png + -216.png')
    print('  ✅ 预览 /tmp/icon-new-512.png')


if __name__ == '__main__':
    main()
