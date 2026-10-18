#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从命名表生成 ArkTS 游戏目录（拾海 2026-10-10）

输入：tools/names_part*.txt   格式  id|中文名|一句话玩法
输出：entry/src/main/ets/core/GameCatalog.ets

分类与配色按「玩法族」自动分配，emoji 按关键词匹配，匹配不到用分类默认。
"""
import os
import re
import glob
import json

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# ── 玩法族 → (分类枚举, 分类中文, 默认 emoji, 配色键) ──
FAMILIES = {
    'names_part1.txt': ('LOGIC',   '格点逻辑', '🧩', 'primary'),
    'names_part2.txt': ('MATH',    '数字数学', '🔢', 'sky'),
    'names_part3.txt': ('MEMORY',  '记忆注意', '🧠', 'violet'),
    'names_part4.txt': ('WORD',    '语言文字', '📖', 'emerald'),
    'names_part5.txt': ('SPATIAL', '空间视觉', '📐', 'amber'),
    'names_part6.txt': ('CLASSIC', '经典原创', '🎮', 'berry'),
}

# ── 关键词 → emoji（按顺序匹配，先命中先用）──
EMOJI = [
    ('数独', '🔢'), ('扫雷', '💣'), ('2048', '🔢'), ('华容道', '🧊'), ('推箱子', '📦'),
    ('汉诺塔', '🗼'), ('舒尔特', '⏱️'), ('记忆', '🃏'), ('贪吃蛇', '🐍'), ('打砖块', '🧱'),
    ('五子棋', '⚫'), ('数织', '🖼️'), ('明灯', '💡'), ('灯塔', '🗼'), ('磁铁', '🧲'),
    ('迷宫', '🌀'), ('管道', '🚰'), ('灭灯', '🔌'), ('倒水', '💧'), ('桥梁', '🌉'),
    ('填字', '📝'), ('单词', '🔤'), ('字母', '🔠'), ('词', '📖'), ('语法', '✏️'),
    ('谜', '❓'), ('密文', '🔐'), ('回文', '🔄'), ('押韵', '🎵'), ('打字', '⌨️'),
    ('记忆', '🧠'), ('注意', '👁️'), ('反应', '⚡'), ('点击', '👆'), ('追踪', '🎯'),
    ('旋转', '🔄'), ('对称', '🪞'), ('镜像', '🪞'), ('折', '📄'), ('方块', '🧊'),
    ('角度', '📐'), ('坐标', '📊'), ('颜色', '🎨'), ('色', '🎨'), ('排序', '🔀'),
    ('棋', '♟️'), ('牌', '🃏'), ('龙', '🐉'), ('消', '💥'), ('泡泡', '🫧'),
    ('素数', '🔺'), ('因数', '➗'), ('矩阵', '🔲'), ('向量', '➡️'), ('分数', '½'),
    ('百分', '％'), ('天秤', '⚖️'), ('天平', '⚖️'), ('钟', '🕐'), ('日历', '📅'),
    ('金字塔', '🔺'), ('斐波', '🌀'), ('幻方', '✨'), ('逻辑', '🧠'), ('推理', '🔍'),
    ('时间', '⏳'), ('序列', '📈'), ('规律', '📈'), ('齿轮', '⚙️'), ('激光', '🔦'),
    ('电路', '🔋'), ('生命', '🧬'), ('分形', '🌀'), ('俄罗斯', '🟦'), ('纸牌', '🃏'),
    ('接龙', '🃏'), ('麻将', '🀄'), ('井字', '⭕'), ('黑白', '⚫'), ('跳棋', '⚪'),
    ('孔明', '⚫'), ('博弈', '🎲'), ('珠玑', '🎨'), ('像素', '👾'), ('跳', '🦘'),
    ('乒乓', '🏓'), ('方块', '🟦'), ('猜', '🎲'), ('骰', '🎲'),
    ('宝石', '💎'), ('泡泡', '🫧'), ('麻将', '🀄'), ('纸牌', '🃏'),
    ('鸟', '🐦'), ('跳一', '🦘'), ('生活', '🧬'), ('生命', '🧬'),
    ('水管', '🚰'), ('管道', '🚰'), ('数回', '➰'), ('斜线', '➰'),
    ('帐篷', '⛺'), ('树', '🌳'), ('皇冠', '👑'), ('磁', '🧲'),
    ('皇', '👑'), ('黑白', '⚫'), ('和', '➕'), ('壹', '⬛'),
]


def pick_emoji(name: str, default: str) -> str:
    for kw, e in EMOJI:
        if kw in name:
            return e
    return default


def emit_cat_ids(games, path):
    """产出 GAME_IDS_BY_CAT —— 六大门类的 id 清单（成就判定要用）"""
    order = ['CLASSIC', 'LOGIC', 'MATH', 'MEMORY', 'WORD', 'SPATIAL']
    lines = ['\n/** 六大门类的游戏 id 清单（下标同 GameCategory 顺序） */\nexport const GAME_IDS_BY_CAT: string[][] = [\n']
    for cat in order:
        ids = [g['id'] for g in games if g['cat'] == cat]
        lines.append('  [' + ', '.join(chr(39) + i + chr(39) for i in ids) + '],\n')
    lines.append('];\n')
    open(path, 'a', encoding='utf-8').write(''.join(lines))
    print('  已追加 GAME_IDS_BY_CAT')


def main():
    tagmap = {}
    if os.path.exists('/tmp/game_tags.json'):
        tagmap = json.load(open('/tmp/game_tags.json', encoding='utf-8'))
    enmap = {}
    if os.path.exists('/tmp/game_en.json'):
        enmap = json.load(open('/tmp/game_en.json', encoding='utf-8'))
    games = []
    seen = set()
    for i in range(1, 7):
        path = os.path.join(HERE, f'names_part{i}.txt')
        if not os.path.exists(path):
            continue
        cat, cat_cn, dflt_emoji, color = FAMILIES[f'names_part{i}.txt']
        for line in open(path, encoding='utf-8'):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split('|')
            if len(parts) != 3:
                continue
            gid, name, tag = parts
            if gid in seen:
                continue
            seen.add(gid)
            games.append({
                'id': gid, 'name': name, 'tag': tag,
                'cat': cat, 'catCn': cat_cn, 'color': color,
                'icon': pick_emoji(name, dflt_emoji),
            })

    # 按分类排序，保证同族相邻
    order = ['CLASSIC', 'LOGIC', 'MATH', 'MEMORY', 'WORD', 'SPATIAL']
    games.sort(key=lambda g: (order.index(g['cat']), g['id']))
    # ★ 配色按索引轮转 12 色 —— 348 张卡片全同色会很难看
    WHEEL = ['primary', 'berry', 'emerald', 'amber', 'teal', 'violet',
             'sky', 'rose', 'lime', 'orange', 'cyan', 'primaryDeep']
    for i, g in enumerate(games):
        g['color'] = WHEEL[i % len(WHEEL)]

    out = []
    out.append("""/**
 * 「一局」游戏总目录（自动生成，勿手改）
 *
 * 生成器：tools/gen_catalog.py
 * 数据源：tools/names_part1..6.txt
 *
 * ★ 合规声明：本文件只描述"有哪些经典玩法"（玩法本身属公有领域），
 *   全部代码为原生 ArkTS 原创实现，未复制任何第三方项目的代码/美术/名称。
 */

import { Palette } from './Design';

/** 玩法分类 */
export enum GameCategory {
  ALL = '全部',
  CLASSIC = '经典',
  LOGIC = '逻辑',
  MATH = '数字',
  MEMORY = '记忆',
  WORD = '文字',
  SPATIAL = '空间',
}

/** 难度 */
export enum Difficulty {
  EASY = '轻松',
  NORMAL = '普通',
  HARD = '烧脑',
}

/** 一局的结果（所有游戏统一口径） */
export interface GameResult {
  gameId: string;
  solved: boolean;
  score: number;
  durationMs: number;
  levelReached?: number;
}

/** 游戏元数据 */
export interface GameMeta {
  id: string;
  name: string;
  tagline: string;
  category: GameCategory;
  icon: string;
  color: string;
  difficulty: Difficulty;
  baseXp: number;
  tags: string[];
  enName: string;
  enTagline: string;
}

""")

    out.append(f"/** 全部 {len(games)} 款游戏 */\n")
    out.append("export const GAMES: GameMeta[] = [\n")
    for g in games:
        out.append(
            f"  {{ id: '{g['id']}', name: '{g['name']}', tagline: '{g['tag']}', "
            f"category: GameCategory.{g['cat']}, icon: '{g['icon']}', "
            f"color: Palette.{g['color']}, difficulty: Difficulty.NORMAL, baseXp: 12, "
            f"tags: [{', '.join(repr(x) for x in tagmap.get(g['id'], []))}], "
            f"enName: {enmap.get(g['id'], {}).get('name', g['id'])!r}, "
            f"enTagline: {enmap.get(g['id'], {}).get('tagline', 'A quick puzzle')!r} }},\n"
        )
    out.append("];\n\n")

    out.append("""/** 难度系数 —— 影响一局获得的经验值 */
export function difficultyFactor(d: Difficulty): number {
  if (d === Difficulty.HARD) {
    return 1.5;
  }
  if (d === Difficulty.EASY) {
    return 0.8;
  }
  return 1.0;
}

/** 按分类取游戏（ALL 返回全部） */
export function gamesByCategory(cat: GameCategory): GameMeta[] {
  if (cat === GameCategory.ALL) {
    return GAMES;
  }
  const out: GameMeta[] = [];
  for (let i = 0; i < GAMES.length; i++) {
    if (GAMES[i].category === cat) {
      out.push(GAMES[i]);
    }
  }
  return out;
}

/** 按关键词搜索（匹配中文名 / 英文 id / 玩法描述） */
export function searchGames(q: string): GameMeta[] {
  const key: string = q.trim().toLowerCase();
  if (key.length === 0) {
    return GAMES;
  }
  const out: GameMeta[] = [];
  for (let i = 0; i < GAMES.length; i++) {
    const g: GameMeta = GAMES[i];
    if (g.name.indexOf(key) >= 0 || g.id.toLowerCase().indexOf(key) >= 0
      || g.tagline.indexOf(key) >= 0) {
      out.push(g);
    }
  }
  return out;
}

/** 按 id 找 */
export function findGame(id: string): GameMeta | undefined {
  for (let i = 0; i < GAMES.length; i++) {
    if (GAMES[i].id === id) {
      return GAMES[i];
    }
  }
  return undefined;
}

/** 分类清单（含数量，用于筛选条） */
export interface CatCount {
  cat: GameCategory;
  count: number;
}

export function categoryList(): CatCount[] {
  const cats: GameCategory[] = [
    GameCategory.ALL, GameCategory.CLASSIC, GameCategory.LOGIC,
    GameCategory.MATH, GameCategory.MEMORY, GameCategory.WORD, GameCategory.SPATIAL,
  ];
  const out: CatCount[] = [];
  for (let i = 0; i < cats.length; i++) {
    out.push({ cat: cats[i], count: gamesByCategory(cats[i]).length });
  }
  return out;
}

/** 取色（hex 字符串） */
export function colorOf(g: GameMeta): string {
  return g.color;
}

/** 进场动画的错峰延时（毫秒），最多 400ms */
export function enterDelay(index: number): number {
  const d: number = index * 40;
  return d > 400 ? 400 : d;
}
""")

    dst = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(''.join(out))
    print(f'✅ 生成 {dst}')
    print(f'   游戏总数: {len(games)}')
    emit_cat_ids(games, dst)
    from collections import Counter
    for k in order:
        n = sum(1 for g in games if g['cat'] == k)
        print(f"   {k:9s} {n:4d}")


if __name__ == '__main__':
    main()
