#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 354 个图标资源的查找表注入 `components/Common.ets`（拾海 2026-10-13）

## 为什么不用「动态 $r」

ArkUI 的 `$r()` 在 DevEco 里是**编译期**解析的（ets-loader 把它换成资源 id）。
`$r('app.media.gico_' + id)` 这种**拼出来的字符串**能不能在运行时解析，
没法在本机验证（真机不在、模拟器没起）——**不能拿没验证过的东西上真机**。
⇒ 这里改成给每款游戏写一行**字面量** `$r('app.media.gico_<id>')`，
   编译器逐条校验、失败在构建期就暴露；只是代码长一点（354 行，可接受）。

## 用法

    python3 tools/gen_icon_map.py            # 重新生成并注入
    python3 tools/gen_icon_map.py --check    # 只校验（表是否与 registry 一致）

注入位置由 Common.ets 里这对标记圈定：

    // ─── ICON_MAP:BEGIN（由 tools/gen_icon_map.py 生成，勿手改）───
    // ─── ICON_MAP:END ───
"""

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
COMMON = os.path.join(ROOT, 'entry/src/main/ets/components/Common.ets')
MEDIA = os.path.join(ROOT, 'entry/src/main/resources/base/media')

BEGIN = '// ─── ICON_MAP:BEGIN（由 tools/gen_icon_map.py 生成，勿手改）───'
END = '// ─── ICON_MAP:END ───'


def game_ids():
    src = open(REGISTRY, encoding='utf-8').read()
    ids = re.findall(r"\{ id: '([^']+)'", src)
    if not ids:
        raise SystemExit('❌ 没解析出 id —— GameRegistry.ets 的字段顺序可能变了')
    return ids


def build_block(ids):
    lines = [
        BEGIN,
        '/**',
        ' * 游戏图标资源表（354 款，每款一张预渲染位图）。',
        ' *',
        ' * 图标由 `tools/gen_game_icons.py` 生成到 `resources/base/media/gico_<id>.png`：',
        ' *   · 改前 354 款共用 69 个 emoji（327 款跟别人撞脸）',
        ' *   · 改后每款一张 192px 位图，感知哈希 354/354 互不相同',
        ' * 这里是**字面量**表（不是 `$r(\'app.media.\' + id)`）：',
        ' * `$r()` 走编译期解析，拼出来的字符串没法保证在真机上能解析。',
        ' */',
        'const ICON_MAP: Record<string, Resource> = {',
    ]
    for i in ids:
        lines.append(f"  '{i}': $r('app.media.gico_{i}'),")
    lines.append('};')
    lines.append('')
    lines.append('/** 取某款游戏的图标资源；查不到返回 undefined（调用方自己兜底） */')
    lines.append('export function iconOf(id: string): Resource | undefined {')
    lines.append('  return ICON_MAP[id];')
    lines.append('}')
    lines.append('')
    lines.append('/**')
    lines.append(' * ★ 按 id 记忆化卡片底色')
    lines.append(' *')
    lines.append(' * ⚠️ 本块依赖 `ACCENT_TAG` / `ACCENT_DEEP_TAG`（来自 GameRegistry）—— 别删那两个 import。')
    lines.append(' *')
    lines.append(' * `colorOf(this.meta)` 每次返回同一个字符串，`@Prop` 值比较不会触发重渲染；')
    lines.append(' * 但它在 build 里被调 354 次、每次进一次函数调用。这里用一张表降到一次查表，')
    lines.append(' * 顺带保证**同一款游戏永远拿到同一个字符串**（ArkUI 的 @Prop 才认"没变"）。')
    lines.append(' */')
    lines.append('const CARD_COLOR: Record<string, string> = {};')
    lines.append('')
    lines.append('export function cardColorOf(g: GameMeta): string {')
    lines.append('  // ★ 2026-10-13（P5 · i18n-theme 加，勿删）：59 款"跟随主题色"的卡片**不能进缓存** ——')
    lines.append('  //   缓存会把主题色冻在第一次取色的那一刻，用户改色后它们永远是旧色。')
    lines.append('  if (g.color === ACCENT_TAG || g.color === ACCENT_DEEP_TAG) {')
    lines.append('    return colorOf(g);')
    lines.append('  }')
    lines.append('  const hit: string | undefined = CARD_COLOR[g.id];')
    lines.append('  if (hit !== undefined) {')
    lines.append('    return hit;')
    lines.append('  }')
    lines.append('  const c: string = colorOf(g);')
    lines.append('  CARD_COLOR[g.id] = c;')
    lines.append('  return c;')
    lines.append('}')
    lines.append(END)
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()

    ids = game_ids()
    missing = [i for i in ids if not os.path.exists(os.path.join(MEDIA, f'gico_{i}.png'))]
    if missing:
        print(f'❌ {len(missing)} 款没有图标文件（先跑 tools/gen_game_icons.py）: {missing[:5]}')
        return 1

    src = open(COMMON, encoding='utf-8').read()
    if BEGIN not in src or END not in src:
        print('❌ Common.ets 里找不到 ICON_MAP 标记')
        return 1
    head, rest = src.split(BEGIN, 1)
    _, tail = rest.split(END, 1)

    block = build_block(ids)
    current = (BEGIN + rest.split(END, 1)[0] + END)

    if args.check:
        ok = current.strip() == block.strip()
        print(f'{"✅" if ok else "❌"} ICON_MAP 与 GameRegistry 一致（{len(ids)} 条）'
              if ok else '❌ ICON_MAP 与 GameRegistry 不一致 —— 跑 python3 tools/gen_icon_map.py 重新注入')
        return 0 if ok else 1

    new_src = head + block + tail
    if new_src == src:
        print(f'✓ 无需改动（{len(ids)} 条已是最新）')
        return 0
    open(COMMON, 'w', encoding='utf-8').write(new_src)
    print(f'✅ 已注入 {len(ids)} 条图标映射 → {os.path.relpath(COMMON, ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
