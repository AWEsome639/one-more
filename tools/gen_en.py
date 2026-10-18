#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""游戏英文名与英文一句话描述（拾海 2026-10-11）

来源策略：
  · **英文名**：直接用注册表里的 `id`（它本来就是对标项目的英文标识，如 bejeweled /
    bubble_shooter / connect_four），转成 Title Case。少量特例手工修正。
  · **英文描述**：按 id 关键词规则生成 —— 规则表覆盖常见玩法族，
    命中不了就按分类给一句通用描述（保证 354 款个个都有，不会出现空白）。

输出：/tmp/game_en.json  →  {id: {name, tagline}}
"""

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG = os.path.join(ROOT, 'entry/src/main/ets/core/GameRegistry.ets')
OUT = '/tmp/game_en.json'

# ── 英文名特例（id → 显示名）──
NAME_FIX = {
    'n_back': 'N-Back',
    'd2_attention': 'd2 Attention',
    '2048': '2048',
    'tetris': 'Tetris',
    'g2048': '2048',
    'go_no_go': 'Go / No-Go',
    'tic_tac_toe': 'Tic-Tac-Toe',
    'life_game': "Conway's Life",
    'simon_says': 'Simon Says',
    'mastermind': 'Mastermind',
    'wordle': 'Wordle',
    'flappy': 'Flappy',
    'pong': 'Pong',
    'nim': 'Nim',
    'mancala': 'Mancala',
    'reversi': 'Reversi',
    'checkers': 'Checkers',
    'peg_solitaire': 'Peg Solitaire',
    'mahjong_solitaire': 'Mahjong Solitaire',
    'spider_solitaire': 'Spider Solitaire',
    'freecell': 'FreeCell',
    'solitaire': 'Solitaire',
    'match3': 'Match 3',
    'bejeweled': 'Bejeweled',
    'breakout_classic': 'Breakout Classic',
    'snake_classic': 'Snake Classic',
    'snake_3d': 'Snake 3D',
    'sorting_visualizer': 'Sorting Visualizer',
    'sieve_visualizer': 'Sieve Visualizer',
    'mandelbrot': 'Mandelbrot',
    'sudoku': 'Sudoku',
    'nonogram': 'Nonogram',
    'kakuro': 'Kakuro',
    'kenken': 'KenKen',
    'hitori': 'Hitori',
    'heyawake': 'Heyawake',
    'slitherlink': 'Slitherlink',
    'nurikabe': 'Nurikabe',
    'tapa': 'Tapa',
    'yajilin': 'Yajilin',
    'shikaku': 'Shikaku',
    'masyu': 'Masyu',
    'dominosa': 'Dominosa',
    'fillomino': 'Fillomino',
    'akari': 'Akari (Light Up)',
    'kurodoko': 'Kurodoko',
    'norinori': 'Norinori',
    'gokigen': 'Gokigen',
    'kakurasu': 'Kakurasu',
    'bridges': 'Bridges',
    'tents': 'Tents',
    'magnets': 'Magnets',
    'futoshiki': 'Futoshiki',
    'skyscraper': 'Skyscrapers',
    'binary_puzzle': 'Binary Puzzle',
    'tower_of_hanoi': 'Tower of Hanoi',
    'tower_of_london': 'Tower of London',
    'einstein': 'Einstein Riddle',
    'lights_out': 'Lights Out',
    'minesweeper': 'Minesweeper',
    'klotski': 'Klotski',
    'sokoban': 'Sokoban',
    'tangram': 'Tangram',
    'jigsaw': 'Jigsaw',
    'maze': 'Maze',
    'sokoban_all': 'Sokoban+',
    'mental_rotation': 'Mental Rotation',
    'mental_calendar': 'Mental Calendar',
    'subitizing': 'Subitizing',
    'stroop': 'Stroop Test',
    'schulte': 'Schulte Table',
    'corsi': 'Corsi Blocks',
    'sternberg': 'Sternberg Task',
    'n_back_all': 'N-Back+',
}

# ── 英文描述规则（按 id 关键词，顺序即优先级）──
TAG_RULES = [
    (r'bubble_shooter', 'Shoot bubbles, match three or more'),
    (r'bejewel|match3|match_3|candy', 'Swap gems to line up three or more'),
    (r'breakout|brick', 'Bounce the ball, clear every brick'),
    (r'tetris|block_fall|falling_block', 'Stack falling blocks, clear full lines'),
    (r'snake', 'Eat, grow, and never bite yourself'),
    (r'flappy|doodle_jump|runner|endless_run', 'Tap to stay airborne, dodge everything'),
    (r'pong', 'Keep the ball in play, beat the paddle'),
    (r'2048|merge_number|number_merge', 'Slide and merge tiles to reach 2048'),
    (r'water_sort|color_sort|tube_sort', 'Pour colors until every tube is one shade'),
    (r'color_flood', 'Flood the board with one color'),
    (r'solitaire|freecell|spider', 'Classic card patience, one game at a time'),
    (r'mahjong', 'Match tiles and clear the board'),
    (r'peg_solitaire', 'Jump pegs until only one is left'),
    (r'tic_tac_toe', 'Three in a row wins'),
    (r'connect_four|connect4', 'Four in a row wins'),
    (r'reversi|othello', 'Flip your opponent off the board'),
    (r'checkers|draughts', 'Jump and capture your way to the top'),
    (r'chess', 'Classic chess puzzles'),
    (r'nim\b', 'Take the last piece and win'),
    (r'mancala', 'Sow stones, harvest the most'),
    (r'hanoi', 'Move the whole tower, one disc at a time'),
    (r'sudoku', 'Fill the grid so every row, column and box has 1–9'),
    (r'nonogram|picross|griddler', 'Fill cells from the number clues to reveal a picture'),
    (r'kakuro', 'Cross-sum number puzzle'),
    (r'kenken', 'Arithmetic cages in a grid'),
    (r'hitori', 'Shade cells so no number repeats'),
    (r'heyawake|nurikabe|slitherlink|tapa|yajilin|shikaku|masyu|dominosa|fillomino|akari|kurodoko|norinori|gokigen|kakurasu|bridges|tents|magnets|futoshiki|skyscraper|binary_puzzle',
     'A grid logic puzzle — read the clues, deduce the rest'),
    (r'minesweeper', 'Flag the mines, clear the field'),
    (r'lights_out|akari', 'Light every cell, no overlaps'),
    (r'klotski|block_escape|slide_block', 'Slide the blocks to free the way out'),
    (r'sokoban|box_push', 'Push every crate onto its target'),
    (r'tangram|jigsaw|polyomino', 'Fit the pieces into the shape'),
    (r'maze|path_find', 'Find your way to the exit'),
    (r'cube_net|paper_folding|folding', 'Fold the flat net into a 3D shape'),
    (r'mental_rotation|perspective|block_count|wireframe', 'Picture the object in your head and rotate it'),
    (r'n_back|nback', 'Remember what you saw N steps back'),
    (r'stroop', 'Name the color, not the word'),
    (r'schulte', 'Find the numbers in order, as fast as you can'),
    (r'corsi|spatial_span', 'Repeat the sequence of blocks'),
    (r'sternberg', 'Was this item in the list you just saw?'),
    (r'reaction|reflex|go_no_go|stop_signal', 'React the instant the signal appears'),
    (r'vigilance|d2_attention', 'Stay focused — spot the target among distractors'),
    (r'subitiz', 'How many dots? Answer without counting'),
    (r'memory|recall|paired_associate|face|word_pairs', 'Remember and match'),
    (r'attention_blink|attentional_blink', 'Catch the second target in the stream'),
    (r'anagram|scramble', 'Rearrange the letters into a word'),
    (r'wordle', 'Guess the five-letter word in six tries'),
    (r'crossword', 'Fill the grid from the clues'),
    (r'word_search|find_word', 'Hunt down every hidden word'),
    (r'word_ladder|ladder', 'Change one letter at a time'),
    (r'palindrome', 'Words that read the same both ways'),
    (r'rhyme', 'Find the words that rhyme'),
    (r'typing|keyboard', 'Type it before the timer runs out'),
    (r'spelling|spell', 'Spell it right'),
    (r'hangman', 'Guess the word before you run out of tries'),
    (r'math|arithmetic|calculation|equation|addition|subtraction|multiplication|division',
     'Solve the arithmetic before time runs out'),
    (r'prime', 'Hunt for prime numbers'),
    (r'fraction|percent|decimal', 'Work the numbers, find the answer'),
    (r'matrix', 'Matrix math, quick'),
    (r'calendar', 'Work out the date in your head'),
    (r'unit_convert|conversion', 'Convert the units'),
    (r'count(ing)?_sheep', 'Count the sheep, drift off'),
    (r'tower_of_london|einstein', 'Work out the hidden order from the clues'),
    (r'mandelbrot|life_game|sorting_visualizer|sieve_visualizer', 'A living algorithm you can watch'),
    (r'blackjack|poker|card', 'Card game'),
    (r'dice|yahtzee', 'Roll the dice'),
    # ── 认知/心理实验类（对标项目里占很大一块）──
    (r'change_blindness', 'Did anything change? Spot it'),
    (r'inattentional|attention', 'Pay attention — you will miss things'),
    (r'visual_search|search_array', 'Find the target among the crowd'),
    (r'feature_search|conjunction_search', 'Spot the odd one out, fast'),
    (r'dual_task|multitask', 'Do two things at once'),
    (r'flanker', 'Ignore the neighbours, answer the middle'),
    (r'priming|masking', 'Was it primed, or just shown?'),
    (r'wason|selection_task|logic_reasoning', 'Test the rule with the fewest cards'),
    (r'belief_bias|syllogism', 'Does the logic hold up?'),
    (r'base_rate|bayes|probability', 'Work out the odds'),
    (r'anchor|framing|prospect', 'Would you take the bet?'),
    (r'delay_discount|temporal', 'Now or later — pick one'),
    (r'ultimatum|dictator|public_goods|trust_game', 'A quick decision about fairness'),
    (r'prisoner|nash|equilibrium', 'Pick a strategy, live with it'),
    (r'monty_hall', 'Should you switch doors?'),
    (r'wisconsin|card_sort|set_shift', 'Sort by the rule — but the rule changes'),
    (r'stroop_variant|emotional_stroop', 'Name the colour, ignore the meaning'),
    (r'go_no_go_variant|inhibitory', 'Hold back when you should'),
    (r'trail_making', 'Connect the dots in order, fast'),
    (r'digit_span|letter_span|word_span', 'How many can you hold at once?'),
    (r'operation_span|reading_span', 'Remember and compute at the same time'),
    (r'prospective_memory', 'Do not forget to do the thing'),
    (r'autobiographical|flashbulb', 'How well do you recall it?'),
    (r'face_recognition|face_memory|face_feature', 'Study the face, then pick it out'),
    (r'emotion_recognition|micro_expression', 'Read the expression'),
    (r'gaze|cueing|posner', 'Follow the cue — or do not'),
    (r'aftereffect|adaptation|tilt_after', 'Stare, then look away'),
    (r'illusion|muller_lyer|ponzo|ebbinghaus|zollner|poggendorff', 'Can you trust your eyes?'),
    (r'blind_spot|filling_in', 'Your eyes have a hole — find it'),
    (r'contrast|brightness|hue|saturation', 'Judge the colour, carefully'),
    (r'simon_effect|task_switching', 'Switch rules without slipping'),
    (r'motion|apparent_motion|phi', 'Watch the motion illusion'),
    (r'audio|tone|pitch|rhythm|beat', 'Listen closely'),
    (r'spatial_working|visuospatial', 'Hold the layout in your head'),
    (r'number_line|numerosity|approximate', 'Estimate the quantity, fast'),
    (r'serial|ordering|sequence', 'Put it back in order'),
    (r'odd_one_out|spot_difference', 'Find what does not belong'),
    (r'pattern|matrix_reasoning|raven', 'Complete the pattern'),
    (r'analogy', 'A is to B as C is to …'),
    (r'categor|semantic|word_fluency', 'Name as many as you can'),
    (r'vocabulary|definition|synonym|antonym', 'Pick the right word'),
    (r'idiom|proverb|metaphor', 'Say it another way'),
    (r'grammar|syntax|sentence', 'Fix the sentence'),
    (r'punctuation|capital', 'Punctuate it right'),
    (r'translation|language', 'Match the meaning across languages'),
    (r'cryptogram|cipher|decode', 'Break the code'),
    (r'morse|binary_code', 'Decode the signal'),
    (r'logic_gate|circuit|boolean', 'Wire the logic'),
    (r'graph|chart|data', 'Read the chart'),
    (r'geometry|angle|area|perimeter', 'Geometry, quick'),
    (r'probability_dice|coin_flip', 'Heads or tails?'),
    (r'sequence_number|fibonacci|series', 'What comes next?'),
    (r'ratio|proportion|scale', 'Work the ratio'),
    (r'time_zone|clock|analog', 'Read the clock'),
    (r'money|change|discount|shopping', 'Do the mental arithmetic'),
    (r'tip|split_bill', 'Work out the share'),
    (r'temperature|speed|distance', 'Convert and compute'),
    (r'physics|gravity|projectile|pendulum', 'A little physics playground'),
    (r'chemistry|element|periodic', 'Element puzzle'),
    (r'biology|cell|dna', 'Life science puzzle'),
    (r'astronomy|orbit|planet|star', 'Look up at the sky'),
    (r'geography|country|capital_city|flag', 'Where in the world?'),
    (r'history|timeline|date_order', 'Put history in order'),
    (r'art|colour_mix|palette', 'Mix the colours'),
    (r'music|note|chord|interval', 'An ear-training puzzle'),
    (r'rhythm_tap|metronome', 'Keep the beat'),
    (r'dance|gesture|pose', 'Match the pose'),
    (r'balance|steady_hand|precision', 'Steady hands only'),
    (r'aim|target|dart', 'Take your best shot'),
    (r'parking|traffic|drive', 'Get out of the jam'),
    (r'fishing|garden|farm|cook', 'A cosy little task'),
    (r'puzzle_boxes|inventory|craft', 'Sort it out'),
    (r'mahjong_solitaire', 'Match tiles and clear the board'),
]

CAT_FALLBACK = {
    'CLASSIC': 'A classic you already know how to play',
    'LOGIC': 'Think it through, step by step',
    'MATH': 'A quick number challenge',
    'MEMORY': 'A short test for your memory',
    'WORD': 'A word puzzle to chew on',
    'SPATIAL': 'A puzzle about shape and space',
}


def to_title(gid):
    if gid in NAME_FIX:
        return NAME_FIX[gid]
    # 数字开头的（2048、24_game）原样
    parts = gid.split('_')
    out = []
    for p in parts:
        if p.isdigit():
            out.append(p)
        elif p in ('n', 'd', 'ai', 'ar', 'vr', '3d', '2d', '4d', 'rgb', 'hsv', 'ui', 'iq'):
            out.append(p.upper())
        else:
            out.append(p[:1].upper() + p[1:])
    s = ' '.join(out)
    return s


def main():
    s = open(REG, encoding='utf-8').read()
    games = re.findall(
        r"id: '([^']+)', name: '([^']*)', tagline: '([^']*)', category: GameCategory\.(\w+)", s)
    data = {}
    hit = 0
    for gid, zh, tag, cat in games:
        en_name = to_title(gid)
        en_tag = None
        hay = gid.lower()
        for pat, phrase in TAG_RULES:
            if re.search(pat, hay):
                en_tag = phrase
                hit += 1
                break
        if en_tag is None:
            en_tag = CAT_FALLBACK.get(cat, 'A quick puzzle')
        data[gid] = {'name': en_name, 'tagline': en_tag}
    json.dump(data, open(OUT, 'w'), ensure_ascii=False, indent=0)
    print(f'✅ {OUT}（{len(data)} 款）')
    print(f'   规则命中 {hit} 款 · 分类兜底 {len(data) - hit} 款')


if __name__ == '__main__':
    main()
