#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「一局」分层图标生成器（拾海 2026-10-13 · numpy 重写版）

## 为什么重写

旧版是**纯 Python 三重循环**（1024² × 3×3 超采样 + 每像素 4 次圆角判定），
跑一次要几十分钟 —— 慢到没法迭代、没法自查。这版用 numpy 向量化，
**一次 3~5 秒**，代价是依赖 numpy（本机 Python 3.14 自带 2.5.3 ✓）。

## 产物（路径与旧版一致，构建脚本不用改）

    AppScope/resources/base/media/{background,foreground}.png
    entry/src/main/resources/base/media/{background,foreground}.png
    ~/Desktop/学业规划/鸿蒙小游戏合集 20261010/上架材料/图标/icon-{background,foreground}-1024.png

另外多导一张**预览图**（模拟桌面上的圆角图标）到上架材料目录，方便肉眼验收。

## 设计（P11「图像配置拉满」）

· **背景层**：深靛蓝 → 紫罗兰对角渐变（锚在 App 品牌色 #6366F1 上）＋ 中心柔光
· **前景层**：2×2 四块圆角砖（天蓝/品红/翡翠/琥珀 —— 与 App 内 Palette 同源），
  每块带竖向渐变 + 左上高光 + 柔和投影，右下那块倾斜 10°（「一局未完」的暗示）
· 前景内容控制在中心 ~62% 内（鸿蒙会把前景层按安全区缩放）
· 4× 超采样 ⇒ 边缘干净；1024×1024 输出

用法：python3 tools/gen_icon.py
"""

import math
import os
import struct
import zlib

import numpy as np

# ── 参数 ──────────────────────────────────────────────
SIZE = 1024          # 输出边长
SS = 4               # 超采样倍数（4×4 = 16 样本/像素）
BIG = SIZE * SS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIRS = [
    os.path.join(ROOT, 'AppScope/resources/base/media'),
    os.path.join(ROOT, 'entry/src/main/resources/base/media'),
]
STORE_DIR = os.path.expanduser('~/Desktop/学业规划/鸿蒙小游戏合集 20261010/上架材料/图标')

# 品牌色（与 Design.ets 的 Palette 同源）
BG_INNER = (0x63, 0x66, 0xF1)     # #6366F1 靛蓝（App 主色）
BG_OUTER = (0x2A, 0x21, 0x6B)     # 深紫罗兰
BRICKS = [
    (0x38, 0xBD, 0xF8),   # 天蓝
    (0xEC, 0x48, 0x99),   # 品红
    (0x10, 0xB9, 0x81),   # 翡翠
    (0xF5, 0x9E, 0x0B),   # 琥珀
]


def rounded_rect_mask(xx, yy, x0, y0, x1, y1, r):
    """点阵 (xx,yy) 是否落在圆角矩形内（numpy 版）

    ★ 做法：把点夹到「内矩形」(四周各缩进 r)，算它到夹点的距离。
       距离 ≤ r ⇒ 在圆角矩形内 —— 这一条**同时**覆盖直边与圆角，
       **不需要**再写「在包围盒内就算命中」的兜底（那句会把圆角覆盖成直角）。
       （2026-10-10 真踩过：第一版图标出来是四个直角方块）
    """
    cx = np.clip(xx, x0 + r, x1 - r)
    cy = np.clip(yy, y0 + r, y1 - r)
    return ((xx - cx) ** 2 + (yy - cy) ** 2) <= r * r


def render_background():
    """对角渐变 + 中心柔光 + 极淡的暗角"""
    y, x = np.mgrid[0:BIG, 0:BIG].astype(np.float32)
    t = (x / BIG) * 0.5 + (y / BIG) * 0.5                 # 左上 0 → 右下 1
    inner = np.array(BG_INNER, dtype=np.float32)
    outer = np.array(BG_OUTER, dtype=np.float32)
    img = inner[None, None, :] * (1 - t[..., None]) + outer[None, None, :] * t[..., None]

    # 中心柔光：中心 +16% 亮度（视线收拢）
    cx = cy = BIG / 2.0
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / math.hypot(cx, cy)
    glow = np.clip(1.0 - d * 1.7, 0, 1) ** 2 * 0.16
    img = img + 255.0 * glow[..., None]

    # 暗角：四角压 8%（让图标边缘"收"住，不散）
    vig = np.clip(d, 0, 1) ** 2 * 0.08
    img = img * (1.0 - vig[..., None])

    out = np.zeros((BIG, BIG, 4), dtype=np.uint8)
    out[..., :3] = np.clip(img, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    return out


def render_foreground():
    """2×2 四块圆角砖：竖向渐变 + 左上高光 + 柔和投影，右下倾斜 9°"""
    y, x = np.mgrid[0:BIG, 0:BIG].astype(np.float32)

    span = BIG * 0.60                       # 安全区：中心 60%
    left = (BIG - span) / 2.0
    gap = span * 0.13
    brick = (span - gap) / 2.0
    rad = brick * 0.30

    acc = np.zeros((BIG, BIG, 3), dtype=np.float32)
    acc_a = np.zeros((BIG, BIG), dtype=np.float32)

    def composite(rgb, alpha):
        nonlocal acc, acc_a
        a = alpha[..., None]
        acc = rgb * a + acc * (1 - a)
        acc_a = alpha + acc_a * (1 - alpha)

    tilt = math.radians(10.0)
    for r in range(2):
        for c in range(2):
            col = np.array(BRICKS[r * 2 + c], dtype=np.float32)
            x0 = left + c * (brick + gap)
            y0 = left + r * (brick + gap)
            x1, y1 = x0 + brick, y0 + brick
            tilted = (r == 1 and c == 1)

            # 倾斜：绕自身中心转 −9°（把采样坐标反向旋转即可）
            if tilted:
                mx, my = x0 + brick / 2, y0 + brick / 2
                dx, dy = x - mx, y - my
                ca, sa = math.cos(-tilt), math.sin(-tilt)
                sx = mx + dx * ca - dy * sa
                sy = my + dx * sa + dy * ca
            else:
                sx, sy = x, y

            # ① 投影：向下向右偏一点，柔边（用两次判定近似"柔"）
            for k, (ox, oy, op) in enumerate([(0.045, 0.075, 0.26), (0.020, 0.036, 0.30)]):
                sh = rounded_rect_mask(sx + brick * ox, sy + brick * oy,
                                       x0, y0, x1, y1, rad)
                if sh.any():
                    composite(np.array([10.0, 8.0, 34.0])[None, None, :].repeat(BIG, 0).repeat(BIG, 1),
                              sh.astype(np.float32) * op)

            # ② 砖本体：竖向渐变（上亮下暗）+ 左上高光
            hit = rounded_rect_mask(sx, sy, x0, y0, x1, y1, rad).astype(np.float32)
            if not hit.any():
                continue
            ty = np.clip((sy - y0) / brick, 0, 1)[..., None]
            top = np.clip(col * 1.30, 0, 255)
            bot = col * 0.66
            base = top[None, None, :] * (1 - ty) + bot[None, None, :] * ty
            # 左上 → 右下的一道柔和高光
            hl = np.clip(1.0 - (((sx - x0) / brick) + ((sy - y0) / brick)) * 1.25, 0, 1)
            base = base + (255.0 * hl * 0.28)[..., None]
            composite(np.clip(base, 0, 255), hit)

    out = np.zeros((BIG, BIG, 4), dtype=np.uint8)
    safe = np.maximum(acc_a, 1e-6)
    out[..., :3] = np.clip(acc / safe[..., None], 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(acc_a * 255.0, 0, 255).astype(np.uint8)
    return out


def downsample(buf):
    """BIG×BIG → SIZE×SIZE 盒式降采样（这一步就是抗锯齿）

    ★ alpha 要按**预乘**加权平均，否则半透明边缘会出现黑边
      （直接把 RGB 平均会把"透明区的黑"混进来）
    """
    a = buf[..., 3].astype(np.float32) / 255.0
    rgb = buf[..., :3].astype(np.float32) * a[..., None]
    blocks = (SIZE, SS, SIZE, SS)
    a_s = a.reshape(blocks).mean(axis=(1, 3))
    rgb_s = rgb.reshape(blocks + (3,)).mean(axis=(1, 3))
    out = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    safe = np.maximum(a_s, 1e-6)
    out[..., :3] = np.clip(rgb_s / safe[..., None], 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(a_s * 255.0, 0, 255).astype(np.uint8)
    return out


def write_png(path, rgba):
    h, w = rgba.shape[:2]
    raw = bytearray()
    stride = w * 4
    flat = rgba.tobytes()
    for yy in range(h):
        raw.append(0)                       # filter type 0
        raw += flat[yy * stride:(yy + 1) * stride]

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    return len(png)


def launcher_preview(bg, fg, path, side=288):
    """把两层合成一张「桌面上的样子」预览（鸿蒙会自己加圆角与投影，这里近似）"""
    try:
        from PIL import Image
    except ImportError:
        return None
    b = Image.fromarray(bg, 'RGBA').resize((side, side), Image.LANCZOS)
    f = Image.fromarray(fg, 'RGBA').resize((side, side), Image.LANCZOS)
    canvas = Image.new('RGBA', (side * 2 + 30, side), (230, 236, 245, 255))
    canvas.alpha_composite(b, (0, 0))
    canvas.alpha_composite(f, (0, 0))
    # 右：圆角裁切（模拟启动器）
    from PIL import ImageDraw
    mask = Image.new('L', (side, side), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, side - 1, side - 1], radius=int(side * 0.235), fill=255)
    rounded = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    rounded.paste(canvas.crop((0, 0, side, side)), (0, 0), mask)
    canvas.alpha_composite(rounded, (side + 30, 0))
    canvas.convert('RGB').save(path)
    return path


def main():
    print(f'  渲染背景层…（{SIZE}×{SIZE}, {SS}× 超采样）')
    bg = downsample(render_background())
    print('  渲染前景层…')
    fg = downsample(render_foreground())

    for d in OUT_DIRS:
        os.makedirs(d, exist_ok=True)
        n1 = write_png(os.path.join(d, 'background.png'), bg)
        n2 = write_png(os.path.join(d, 'foreground.png'), fg)
        print(f'  ✅ {d}/{{background,foreground}}.png  ({n1/1024:.0f} KB + {n2/1024:.0f} KB)')

    os.makedirs(STORE_DIR, exist_ok=True)
    write_png(os.path.join(STORE_DIR, 'icon-background-1024.png'), bg)
    write_png(os.path.join(STORE_DIR, 'icon-foreground-1024.png'), fg)
    print(f'  ✅ {STORE_DIR}/（上架素材 2 张）')

    pv = launcher_preview(bg, fg, os.path.join(STORE_DIR, 'icon-预览-启动器效果.png'))
    if pv:
        print(f'  ✅ 预览图：{pv}')


if __name__ == '__main__':
    main()
