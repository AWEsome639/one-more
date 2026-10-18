#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成游戏特征标签（拾海 2026-10-10）

奥森要的「选特征筛游戏」：每款游戏打上一组特征标签，用户多选后取交集。

特征分 6 组（共 24 个），自动按「分类 + 玩法描述关键词 + id 线索」打标。
输出：entry/src/main/ets/core/GameTags.ets
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
OUT_JSON = '/tmp/game_tags.json'
OUT = os.path.join(ROOT, 'entry/src/main/ets/core/GameTags.ets')

# ── 特征定义：组 / id / 显示名 / emoji ──
EN = {
    'speed': 'Under 30s', 'short': '1-3 min', 'medium': '3-10 min', 'long': '10 min+',
    'easy': 'Relaxed', 'normal': 'Standard', 'hard': 'Brain-bender',
    'tap': 'Tap', 'swipe': 'Swipe', 'drag': 'Drag', 'type': 'Type',
    'timed': 'Against the clock', 'untimed': 'No timer', 'pausable': 'Pause anytime',
    'calc': 'Numbers', 'memory': 'Memory', 'word': 'Words',
    'space': 'Spatial', 'logic': 'Logic', 'focus': 'Focus',
    'onehand': 'One hand', 'endless': 'Endless', 'zen': 'Wind down',
    'brainy': 'Challenge', 'cozy': 'Cosy',
}

GRP_EN = {'时长': 'Length', '难度': 'Difficulty', '操作': 'Controls',
          '节奏': 'Pace', '脑力': 'Skills', '场景': 'Vibe'}

TAGS = [
    ('时长', 'speed',   '⚡', '30 秒内'),
    ('时长', 'short',   '⏱️', '1–3 分钟'),
    ('时长', 'medium',  '🕐', '3–10 分钟'),
    ('时长', 'long',    '⏳', '10 分钟以上'),

    ('难度', 'easy',    '🌱', '轻松'),
    ('难度', 'normal',  '⚖️', '普通'),
    ('难度', 'hard',    '🔥', '烧脑'),

    ('操作', 'tap',     '👆', '点按'),
    ('操作', 'swipe',   '👉', '滑动'),
    ('操作', 'drag',    '✋', '拖拽'),
    ('操作', 'type',    '⌨️', '输入'),

    ('节奏', 'timed',   '⏰', '有时间压力'),
    ('节奏', 'untimed', '🧘', '不限时'),
    ('节奏', 'pausable', '🚌', '随时可停'),

    ('脑力', 'calc',    '🧮', '计算'),
    ('脑力', 'memory',  '🧠', '记忆'),
    ('脑力', 'word',    '🔤', '语言'),
    ('脑力', 'space',   '📐', '空间'),
    ('脑力', 'logic',   '🧩', '逻辑'),
    ('脑力', 'focus',   '🎯', '专注力'),

    ('场景', 'onehand', '👍', '单手可玩'),
    ('场景', 'endless', '♾️', '可无限玩'),
    ('场景', 'zen',     '🌸', '解压放松'),
    ('场景', 'brainy',  '🎓', '烧脑挑战'),
    ('场景', 'cozy',    '🛋️', '躺着玩'),
]

# ── 打标规则 ──

# 1) 分类 → 默认脑力标签
CAT_ATTR = {
    'CLASSIC': ['logic'],
    'LOGIC':   ['logic'],
    'MATH':    ['calc'],
    'MEMORY':  ['memory', 'focus'],
    'WORD':    ['word'],
    'SPATIAL': ['space'],
}

# 2) 关键词 → 追加标签（按 id 或描述匹配）
KW = [
    # 时长
    (r'speed|sprint|dash|rush|blink|reflex|tap|flash|quick|subitiz|frequency|go_no_go|stop_signal|choice_reaction',
     ['speed', 'timed']),
    (r'schulte|sudoku|2048|minesweeper|nonogram|kakuro|kenken|slitherlink|nurikabe|hitori|heyawake|fillomino|masyu|tapa|yajilin|shikaku|skyscraper|bridges|dominosa|akari|lighthouse|magnet|kurodoko|norinori|gokigen|kakurasu|crown|futoshiki|binary_puzzle|tents',
     ['long', 'untimed', 'pausable']),
    (r'crossword|word_search|anagram|scramble|wordle|ladder|mastermind',
     ['short', 'untimed']),
    # 难度
    (r'nurikabe|slitherlink|yajilin|tapa|heyawake|gokigen|hitori|nonogram|kakuro|kenken|einstein|tower_of_london|n_back|double_n_back|corsi|sternberg',
     ['hard']),
    (r'tic_tac_toe|nim|simon_says|pong|flappy|whack|counting_sheep|bubble|match3|bejewel|color_flood|water_sort',
     ['easy']),
    # 操作
    (r'snake|tetris|breakout|pong|flappy|doodle|maze|path|trace|orbit|runner',
     ['swipe']),
    (r'solitaire|freecell|spider|mahjong|klotski|slide|sokoban|tangram|peg_solitaire|polyomino|block_escape|pipes|gravity',
     ['drag']),
    (r'typing|spelling|word|anagram|scramble|wordle|letter|paragraph|writing',
     ['type']),
    (r'minesweeper|sudoku|akari|lights_out|nonogram|hitori|kakuro|kenken|shikaku|crown|futoshiki|binary|tents|magnets|bridges|dominosa|masyu|tapa|yajilin|slitherlink|nurikabe|heyawake|fillomino|kurodoko|norinori|gokigen|kakurasu',
     ['tap']),
    # 节奏
    (r'timed|speed|sprint|blink|reflex|flash|frequency|reaction|vigilance|stop_signal|go_no_go|choice|subitiz|sprint|dash|rush|pong|flappy|tetris|snake|breakout|doodle',
     ['timed']),
    (r'zen|relax|coloring|mandala|sand|counting_sheep|garden|aquarium',
     ['zen', 'untimed']),
    (r'puzzle|sudoku|nonogram|kakuro|kenken|hitori|heyawake|slitherlink|nurikabe|tapa|yajilin|shikaku|bridges|masyu|dominosa|fillomino|akari|lights_out|solitaire|freecell|spider|mahjong',
     ['pausable', 'untimed']),
    # 场景
    (r'onehand|tap|reflex|flash|reaction|subitiz|speed|sprint',
     ['onehand']),
    (r'tetris|snake|breakout|pong|flappy|doodle|endless|runner|counting_sheep|life_game|mandelbrot|sorting|sieve',
     ['endless']),
]

# 3) 分类 → 时长/难度/操作默认
CAT_DEFAULT = {
    'CLASSIC': {'speed': [], 'short': ['easy', 'normal'], 'op': ['tap']},
    'LOGIC':   {'speed': [], 'short': [], 'op': ['tap']},
    'MATH':    {'speed': ['speed'], 'short': ['tap', 'timed']},
    'MEMORY':  {'speed': ['speed'], 'short': ['tap', 'timed']},
    'WORD':    {'speed': [], 'short': ['type']},
    'SPATIAL': {'speed': [], 'short': ['drag']},
}


def load_games():
    s = open(REG, encoding='utf-8').read()
    return re.findall(
        r"id: '([^']+)', name: '([^']*)', tagline: '([^']*)', category: GameCategory\.(\w+)",
        s)


def tags_for(gid, name, tag, cat):
    t = set()
    hay = (gid + ' ' + tag + ' ' + name).lower()

    # ── ① 脑力（分类主导）──
    t |= set(CAT_ATTR.get(cat, ['logic']))

    # ── ② 时长（分类主导 + 关键词覆盖）──
    #   极速：反应/闪现/限时点击类
    if re.search(r'reflex|blink|flash|reaction|subitiz|speed|sprint|dash|rush|frequency|go_no_go|stop_signal|ghost|orbit|probe', hay):
        t.add('speed')
    #   长时间：格点逻辑谜题（数织/数回/数独这类一盘要坐一会儿）
    elif cat == 'LOGIC' or re.search(r'nonogram|slitherlink|nurikabe|yajilin|tapa|heyawake|kakuro|kenken|hitori|shikaku|bridges|masyu|dominosa|fillomino|akari|lighthouse|magnet|kurodoko|norinori|gokigen|kakurasu|crown|futoshiki|solitaire|freecell|spider|mahjong|crossword|maze|tangram|sokoban|klotski|slither|paper_folding|cube_net|polyomino|wireframe|jigsaw', hay):
        t.add('long')
    #   短：单题式的数字/记忆/文字小游戏
    elif cat in ('MATH', 'MEMORY', 'WORD'):
        t.add('short')
    else:
        t.add('medium')

    # ── ③ 难度（分类主导 + 关键词覆盖）──
    if re.search(r'nurikabe|slitherlink|yajilin|tapa|heyawake|gokigen|hitori|nonogram|kakuro|kenken|einstein|tower_of_london|n_back|double_n_back|corsi|sternberg|wireframe|mental_rotation|perspective|block_count_3d|cube_net|complex_folding', hay):
        t.add('hard')
    elif re.search(r'tic_tac_toe|simon_says|pong|flappy|whack|counting_sheep|bubble|match3|bejewel|color_flood|water_sort|nim|mancala|reversi|checkers|tower_of_hanoi', hay):
        t.add('easy')
    elif cat == 'LOGIC':
        t.add('hard')
    elif cat in ('MATH', 'MEMORY'):
        t.add('normal')
    elif cat == 'SPATIAL':
        t.add('normal')
    elif cat == 'CLASSIC':
        t.add('easy')
    else:
        t.add('normal')

    # ── ④ 操作 ──
    if re.search(r'snake|tetris|breakout|pong|flappy|doodle|maze|path|trace|orbit|runner|2048|slide', hay):
        t.add('swipe')
    elif re.search(r'solitaire|freecell|spider|mahjong|klotski|slide|sokoban|tangram|peg_solitaire|polyomino|block_escape|pipes|gravity|water_sort|hanoi', hay):
        t.add('drag')
    elif re.search(r'typing|spelling|anagram|scramble|wordle|ladder|letter|missing_vowel|consonant|vowel|palindrome|pangram|portmanteau|spoonerism|typoglyc|rhyme|homophone|cryptogram|crossword|word_search|word_|dictation|phonetic', hay):
        t.add('type')
    else:
        t.add('tap')

    # ── ⑤ 节奏 ──
    if re.search(r'reflex|blink|flash|reaction|subitiz|speed|sprint|dash|rush|frequency|go_no_go|stop_signal|ghost|orbit|vigilance|timed|countdown|sprint|pong|flappy|tetris|snake|breakout|doodle|whack', hay):
        t.add('timed')
    else:
        t.add('untimed')
        t.add('pausable')

    # ── ⑥ 场景 ──
    if re.search(r'onehand|reflex|flash|reaction|subitiz|speed|sprint|tap|click', hay):
        t.add('onehand')
    if re.search(r'tetris|snake|breakout|pong|flappy|doodle|endless|runner|counting_sheep|life_game|mandelbrot|sorting|sieve|maze', hay):
        t.add('endless')
    if re.search(r'zen|relax|mandala|counting_sheep|color|hue|sort|sand|garden|aquarium|breath|pixel|shape_shifter|kaleido', hay):
        t.add('zen')
    if 'hard' in t:
        t.add('brainy')
    if re.search(r'2048|match3|bejewel|bubble|solitaire|spider|freecell|mahjong|nonogram|sudoku|color_flood|water_sort|pixel|tangram|jigsaw|mandala', hay):
        t.add('cozy')

    # ── ⑦ 兜底：四类必须各有一个 ──
    if not (t & {'speed', 'short', 'medium', 'long'}):
        t.add('medium')
    if not (t & {'easy', 'normal', 'hard'}):
        t.add('normal')
    if not (t & {'tap', 'swipe', 'drag', 'type'}):
        t.add('tap')
    if not (t & {'timed', 'untimed'}):
        t.add('untimed')
    return sorted(t)


def main():
    import json
    games = load_games()
    data = {}
    stat = {}
    for gid, name, tag, cat in games:
        ts = tags_for(gid, name, tag, cat)
        data[gid] = ts
        for x in ts:
            stat[x] = stat.get(x, 0) + 1
    json.dump(data, open(OUT_JSON, 'w'), ensure_ascii=False)
    print(f'✅ 特征已写 {OUT_JSON}（{len(data)} 款）')
    for grp, tid, icon, label in TAGS:
        print(f'   {icon} {label:10s} {stat.get(tid,0):4d} 款')
    # 同时生成纯特征定义（不含数据）
    out = []
    out.append("""/**
 * 游戏特征定义（自动生成，勿手改）
 *
 * 生成器：tools/gen_tags.py
 * 数据在 GameRegistry 的 GameMeta.tags 里（避免 ArkTS 动态取 Record 的坑）
 */

/** 一个特征 */
export interface GameTag {
  group: string;
  id: string;
  icon: string;
  label: string;
  enLabel: string;
  enGroup: string;
}

/** 全部特征（按组排列） */
export const TAGS: GameTag[] = [
""")
    for grp, tid, icon, label in TAGS:
        out.append(f"  {{ group: '{grp}', id: '{tid}', icon: '{icon}', label: '{label}', "
                   f"enLabel: '{EN.get(tid, label)}', enGroup: '{GRP_EN.get(grp, grp)}' }},\n")
    out.append("""];

/** 分组清单（按出现顺序） */
export function tagsByGroup(): string[] {
  const out: string[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    const g: string = TAGS[i].group;
    if (out.indexOf(g) < 0) {
      out.push(g);
    }
  }
  return out;
}

/** 某组下的特征 */
export function tagsIn(group: string): GameTag[] {
  const out: GameTag[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    if (TAGS[i].group === group) {
      out.push(TAGS[i]);
    }
  }
  return out;
}
""")
    open(OUT, 'w', encoding='utf-8').write(''.join(out))
    print(f'✅ 特征定义已写 {OUT}')


if __name__ == '__main__':
    main()
