#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""「一局」354 款游戏图标生成器（拾海 2026-10-13）

## 它解决什么（P10 / P11 / P1）

**改前**：354 款共用 69 个 emoji（`GameRegistry.ets` 的 `icon` 字段），
其中 **327 款**跟别人撞脸——🧠 一款图标被 54 款游戏共用。
而且 emoji 走**字体**渲染：鸿蒙上的 emoji 字体（Noto Color Emoji）跟 macOS 的
（Apple Color Emoji）不是一套 ⇒ 同一个码位在两端长得不一样，我们**没法保证效果**。

**改后**：每款一张**预渲染位图**（`gico_<id>.png`），
唯一性由三层保证（已用感知哈希两两验证：354/354 互不相同）：
  ① 游戏自带 emoji（彩色 emoji 压上去）
  ② 游戏自带主题色（12 色调色板）＋ 哈希色相微扰（±6°）
  ③ **哈希指纹**：渐变方向 16 档 × 缎带角度 8 档 × 缎带宽度 3 档 ×
     光斑角落 4 档 × 角标点数 3 档 × 角标相位 4 档 ⇒ 撞脸概率可忽略

## 画质（P11「图像配置拉满」）

· 192×192 RGBA，Swift/CoreText **3× 超采样**后降采样 ⇒ 边缘无锯齿
· 圆角方砖 + 对角渐变 + 中心柔光 + 左上玻璃高光 + 内描边
· emoji 按**实测墨迹框**缩放居中（字体自带 bounds 每个 emoji 留白不同）
· 单色字形（♟️ ½ ％ …，实测 sat<0.10 且对比度<3.0）自动垫一块
  自适应底板（浅底白板、深底深板 + 字形提亮）⇒ 不会变成"黑洞"
· 256 色量化后 PNG：354 张共 ~2.4 MB（不量化的无损要 16 MB）

## 用法

    python3 tools/gen_game_icons.py            # 生成 + 写进 resources + 自检
    python3 tools/gen_game_icons.py --check    # 只自检（不重新生成）

输出：
    entry/src/main/resources/base/media/gico_<id>.png   × 354
    <验收截图目录>/游戏图标一览-354.png                    （给奥森看的一览图）
"""

import argparse
import json
import os
import re
import subprocess
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
DESIGN = os.path.join(ROOT, 'entry/src/main/ets/core/Design.ets')
RENDERER = os.path.join(ROOT, 'tools/icongen/RenderIcons.swift')
MEDIA_DIR = os.path.join(ROOT, 'entry/src/main/resources/base/media')
PREVIEW_DIR = os.path.expanduser('~/Desktop/学业规划/鸿蒙小游戏合集 20261010/验收截图')
TMP = '/tmp/yiju_icons_raw'

ICON_PX = 192          # 渲染尺寸（卡片上 52vp，3x 屏 = 156px ⇒ 1.23× 余量）
QUANT_COLORS = 256     # PNG 调色板色数（实测 mean-diff 3.1/255，肉眼无感）


def parse_games():
    """从 GameRegistry.ets 抽 354 款的 id / emoji / 主题色

    ★ 色板真值在 **Design.ets**（`Palette.primary = '#6366F1'` 那一堆），
      GameRegistry.ets 只是 `import { Palette } from './Design'`。
      第一版我在 GameRegistry 里找 hex ⇒ 一个 token 都找不到（2026-10-13 踩过）。
    """
    reg = open(REGISTRY, encoding='utf-8').read()
    des = open(DESIGN, encoding='utf-8').read()
    # 色板：`static primary:`（可变量，2026-10-13 起）与 `static readonly berry:` 都要匹配
    palette = dict(re.findall(r"static (?:readonly )?(\w+): string = '(#[0-9A-Fa-f]{6})'", des))
    # 颜色字段有两种写法：
    #   · `color: Palette.xxx`  —— 固定色
    #   · `color: ACCENT_TAG` / `ACCENT_DEEP_TAG` —— 跟随主题色（colorOf() 实时解析成
    #     Palette.primary / primaryDeep）。**生成期只能取默认值**（图标是静态位图，
    #     没法跟着 Accent 走）；用户没换主题色时与卡片底色一致，换了会略有差异。
    rows = re.findall(r"\{ id: '([^']+)'.*?icon: '([^']*)'.*?color: (Palette\.\w+|ACCENT_DEEP_TAG|ACCENT_TAG)", reg)
    if len(rows) != len(re.findall(r"\{ id: '", reg)):
        raise SystemExit(f'❌ 只解析出 {len(rows)} 款，但 GAMES 里有 '
                         f'{len(re.findall(chr(123) + " id: ", reg))} 款 —— 字段顺序可能变了')
    accent_default = palette.get('primary', '#6366F1')
    accent_deep_default = palette.get('primaryDeep', '#4F46E5')
    out = []
    for gid, emoji, token in rows:
        if token == 'ACCENT_TAG':
            hexv = accent_default
        elif token == 'ACCENT_DEEP_TAG':
            hexv = accent_deep_default
        else:
            hexv = palette.get(token.split('.')[-1])
        if hexv is None:
            raise SystemExit(f'❌ 解析不出颜色: {token}（{gid}）')
        out.append({'id': gid, 'emoji': emoji, 'hex': hexv})
    return out


def baseline_stats(games):
    """改前基线：多少款共用同一个 emoji"""
    from collections import Counter
    c = Counter(g['emoji'] for g in games)
    shared = sum(v for v in c.values() if v > 1)
    top = c.most_common(5)
    return {
        'games': len(games),
        'distinct_emoji': len(c),
        'games_sharing': shared,
        'games_unique': len(games) - shared,
        'worst': top,
    }


def render(games):
    os.makedirs(TMP, exist_ok=True)
    spec = os.path.join(TMP, 'spec.json')
    for i, g in enumerate(games):
        g['idx'] = i
    with open(spec, 'w', encoding='utf-8') as f:
        json.dump(games, f, ensure_ascii=False)
    print(f'  ▸ Swift/CoreText 渲染 {len(games)} 张（{ICON_PX}px, 3× 超采样）…')
    r = subprocess.run(['swift', RENDERER, spec, TMP, str(ICON_PX)],
                       capture_output=True, text=True)
    print('   ', r.stdout.strip())
    if r.returncode != 0:
        print(r.stderr[-3000:])
        raise SystemExit('❌ 渲染失败')
    if r.stderr.strip():
        print('   ', r.stderr.strip()[:600])


def quantize_and_install(games):
    from PIL import Image
    os.makedirs(MEDIA_DIR, exist_ok=True)
    total = 0
    for g in games:
        src = os.path.join(TMP, f"gico_{g['id']}.png")
        dst = os.path.join(MEDIA_DIR, f"gico_{g['id']}.png")
        im = Image.open(src).convert('RGBA')
        q = im.quantize(colors=QUANT_COLORS, method=Image.FASTOCTREE)
        q.save(dst, format='PNG', optimize=True)
        total += os.path.getsize(dst)
    return total


def verify(games):
    """★ 自查自纠：① 每款都有图 ② 两两可区分 ③ 尺寸/格式对"""
    from PIL import Image
    problems = []
    ids = [g['id'] for g in games]
    if len(set(ids)) != len(ids):
        problems.append('GameRegistry 里有重复 id')

    missing = [i for i in ids if not os.path.exists(os.path.join(MEDIA_DIR, f'gico_{i}.png'))]
    if missing:
        problems.append(f'{len(missing)} 款缺图: {missing[:8]}')

    # 感知哈希（16×16 dHash）两两比对
    def dhash(path, n=16):
        im = Image.open(path).convert('L').resize((n + 1, n), Image.LANCZOS)
        px = list(im.getdata())
        return ''.join('1' if px[y * (n + 1) + x] > px[y * (n + 1) + x + 1] else '0'
                       for y in range(n) for x in range(n))

    hashes = {}
    for i in ids:
        p = os.path.join(MEDIA_DIR, f'gico_{i}.png')
        if os.path.exists(p):
            hashes[i] = dhash(p)
    dup = {}
    for i, h in hashes.items():
        dup.setdefault(h, []).append(i)
    collisions = {h: v for h, v in dup.items() if len(v) > 1}
    if collisions:
        problems.append(f'{len(collisions)} 组图标长得一样: {list(collisions.values())[:3]}')

    # 尺寸 / 模式
    bad_size = []
    for i in ids[:400]:
        p = os.path.join(MEDIA_DIR, f'gico_{i}.png')
        if os.path.exists(p):
            im = Image.open(p)
            if im.size != (ICON_PX, ICON_PX):
                bad_size.append((i, im.size))
    if bad_size:
        problems.append(f'{len(bad_size)} 张尺寸不对: {bad_size[:3]}')

    total = sum(os.path.getsize(os.path.join(MEDIA_DIR, f'gico_{i}.png'))
                for i in ids if os.path.exists(os.path.join(MEDIA_DIR, f'gico_{i}.png')))
    return {
        'icons': len(hashes),
        'distinct_hashes': len(dup),
        'total_bytes': total,
        'problems': problems,
    }


def preview(games, stats, out_path):
    """生成一张 354 款的一览图（给奥森看：每款都不一样）"""
    from PIL import Image, ImageDraw, ImageFont
    COLS, CELL, PAD, LH = 18, 96, 4, 14
    rows = (len(games) + COLS - 1) // COLS
    W = COLS * (CELL + PAD) + PAD
    H = rows * (CELL + LH + PAD) + PAD + 34
    sheet = Image.new('RGB', (W, H), (248, 250, 252))
    d = ImageDraw.Draw(sheet)
    try:
        f = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', 10)
        ft = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', 15)
    except Exception:
        f = ft = ImageFont.load_default()
    d.text((PAD + 2, 8),
           f'「一局」{stats["games"]} 款游戏图标一览 · 每款独立图标'
           f'（emoji 语义：{stats["distinct_emoji"]} 种，最大共用 {stats["worst"][0][1]} 款）',
           fill=(15, 23, 42), font=ft)
    for i, g in enumerate(games):
        p = os.path.join(MEDIA_DIR, f"gico_{g['id']}.png")
        im = Image.open(p).convert('RGBA').resize((CELL, CELL), Image.LANCZOS)
        bg = Image.new('RGBA', (CELL, CELL), (255, 255, 255, 255))
        bg.alpha_composite(im)
        x = PAD + (i % COLS) * (CELL + PAD)
        y = PAD + 34 + (i // COLS) * (CELL + LH + PAD)
        sheet.paste(bg.convert('RGB'), (x, y))
        d.text((x + 1, y + CELL + 1), g['id'][:14], fill=(70, 80, 95), font=f)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='只自检，不重新生成')
    args = ap.parse_args()

    games = parse_games()
    base = baseline_stats(games)
    print(f'▸ 改前基线：{base["games"]} 款共用 {base["distinct_emoji"]} 个 emoji，'
          f'其中 {base["games_sharing"]} 款跟别人撞脸、{base["games_unique"]} 款本来独一份')
    print(f'  撞得最狠的：' + '、'.join(f'{e}×{n}' for e, n in base['worst']))

    if not args.check:
        render(games)
        total = quantize_and_install(games)
        print(f'  ▸ 写入 {MEDIA_DIR} —— {len(games)} 张共 {total/1e6:.2f} MB')

    v = verify(games)
    print(f'▸ 自检：{v["icons"]} 张图标，{v["distinct_hashes"]} 个互不相同的指纹，'
          f'共 {v["total_bytes"]/1e6:.2f} MB')
    if v['problems']:
        print('❌ 有问题：')
        for p in v['problems']:
            print('   -', p)
        return 1
    print(f'✅ {len(games)} 款每款独立图标，两两可区分')
    # ★ 顺带报"语义分散度"：奥森 2026-10-13 追加的诉求 ——
    #   不只是"两张图不一样"，而是"这张图跟这个游戏**有关系**"
    from collections import Counter as _C
    _c = _C(g['emoji'] for g in games)
    print(f'▸ emoji 语义分布：{len(_c)} 种 / {len(games)} 款，'
          f'最大共用 {_c.most_common(1)[0][1]} 款（{_c.most_common(1)[0][0]}）')

    if not args.check:
        out = preview(games, base, os.path.join(
            PREVIEW_DIR, f'游戏图标一览-{len(games)}款.png'))
        print('▸ 一览图：', out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
