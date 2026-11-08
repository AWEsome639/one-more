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
    # 玩法（playStyle）
    'ps_match': 'Match', 'ps_merge': 'Merge', 'ps_push': 'Push', 'ps_maze': 'Maze',
    'ps_fill': 'Fill-in', 'ps_board': 'Board', 'ps_word': 'Words', 'ps_memory': 'Memory',
    'ps_reaction': 'Reaction', 'ps_quiz': 'Quiz', 'ps_search': 'Spotting',
    'ps_spatial': 'Spatial', 'ps_attention': 'Attention', 'ps_run': 'Run',
    'ps_card': 'Cards', 'ps_other': 'Other',
}

GRP_EN = {'时长': 'Length', '难度': 'Difficulty', '操作': 'Controls',
          '节奏': 'Pace', '脑力': 'Skills', '场景': 'Vibe', '玩法': 'Playstyle'}

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

    # ── 玩法（playStyle）★★ 2026-11-08（game-balancer）──
    #   为什么加：355 款按「类别 + tag」只剩 62~64 种签名、最大一组 54 款完全不可区分
    #   （三消/发射消泡的 tag 一模一样）⇒ 「像 2048」只能把三消排在前面。
    #   规则见下方 PLAY_STYLE_RULES：**每款恰好 1 个（划分，不是多标签）**，兜底 ps_other。
    #   方案与数字：_巡检记录/playStyle方案-20261108.md
    ('玩法', 'ps_match',    '💥', '消除配对'),
    ('玩法', 'ps_merge',    '🔢', '合并滚雪球'),
    ('玩法', 'ps_push',     '📦', '挪块推箱'),
    ('玩法', 'ps_maze',     '🌀', '走格寻路'),
    ('玩法', 'ps_fill',     '🧩', '填格谜题'),
    ('玩法', 'ps_board',    '♟️', '棋类对弈'),
    ('玩法', 'ps_word',     '🔤', '拼词文字'),
    ('玩法', 'ps_memory',   '🧠', '记忆回忆'),
    ('玩法', 'ps_reaction', '⚡', '反应手速'),
    ('玩法', 'ps_quiz',     '🧮', '答题估算'),
    ('玩法', 'ps_search',   '🔍', '眼力搜寻'),
    ('玩法', 'ps_spatial',  '📐', '折转空间'),
    ('玩法', 'ps_attention','🎯', '注意力任务'),
    ('玩法', 'ps_run',      '🏃', '跑分局'),
    ('玩法', 'ps_card',     '🃏', '纸牌接龙'),
    ('玩法', 'ps_other',    '❓', '其它玩法'),
]

# ★★★ 2026-11-08：**款数 <10、只服务于「像 XX」打分的细类** —— 筛选面板不显示（hidden: true）。
#   规则：hidden = 款数 <10 **且** 不是兜底桶（ps_other）、**不是**高辨识度意图（ps_board「下棋」）。
#   ⚠️ ps_other(7) / ps_board(8) 也在 10 以下，但**故意不隐藏**：
#      ps_other 是兜底桶（藏了那 7 款就再也筛不出来）；ps_board 是用户会主动找的一类。
HIDDEN_TAGS = {'ps_merge', 'ps_match', 'ps_run', 'ps_card'}   # 4 款，属「细类」

# ── 打标规则 ──

# 1) 分类 → 默认脑力标签
CAT_ATTR = {
    'CLASSIC': ['logic'],
    'LOGIC':   ['logic'],
    'MATH':    ['calc'],
    'MEMORY':  ['memory'],
    'WORD':    ['word'],
    'SPATIAL': ['space'],
}

# 3) 玩法（playStyle）——★ 顺序即优先级，首个命中即定 ⇒ 每款恰好 1 个（划分）
#   匹配面与 tags_for 里的 hay 完全一致（id + tagline + name 小写），不新增任何输入。
#   实测：325/355 = 91.5% 自动命中，剩 30 款落 ps_other（纸牌接龙/算法可视化/序列记忆…）。
PLAY_STYLE_RULES = [
    ('ps_board',     r'gomoku|checkers|connect_four|reversi|mancala|\bnim\b|tic_tac|go9|chess'),
    # 注：water_sort / hue_sort / gravity_sort 是**排序类**不是消除，2026-11-08 挪到 ps_push
    # 纸牌接龙：单机清盘类。麻将连连看**排在 match 之前**（否则会被 mahjong 抢走）
    ('ps_card',      r'freecell|solitaire|spider|mahjong'),
    ('ps_match',     r'match3|bejewel|bubble|color_flood|chain_reaction|jewel|collaps'),
    # ⚠️ 2026-11-08 收窄（code-hunter 抽检）：原来 11 款里只有 3 款是**真·合并**，
    #   其余 8 款（考拉兹/指数塔/幻方/数字键/数字拆分/质因数树/金字塔/目标数字）是**数字计算**
    #   ⇒ 全部让给 ps_quiz（见下方 quiz 正则 + PIN 表），否则「像 2048」会推出考拉兹。
    ('ps_merge',     r'2048|fibonacci_merge|merge|sum_snake'),
    ('ps_push',      r'sokoban|klotski|slide1|block_escape|tangram|polyomino|hanoi|peg_solitaire|block_stacking|block_count|box_completion|tower_of_london|water_sort|hue_sort|gravity_sort'),
    ('ps_maze',      r'maze|path_finder|trace_path|pipes|laser|circuit_connect|wire|vector_grid|path_intersect|path_recall|lock_pattern|grid_displacement'),
    ('ps_fill',      r'sudoku|kakuro|kenken|nonogram|hitori|heyawake|slitherlink|nurikabe|yajilin|tapa|akari|magnet|lighthouse|kurodoko|norinori|gokigen|kakurasu|dominosa|fillomino|futoshiki|crown|shikaku|bridges|masyu|tents|tenner|skyscraper|binary_puzzle|lights_out|minesweeper|dominosa'),
    ('ps_word',      r'word|anagram|cryptogram|letter|vowel|rhyme|homophone|spelling|typing|scramble|palindrome|pangram|portmanteau|spoonerism|consonant|crossword|affix|etymolog|grammar|silent_letter|semantic|vocabulary|analog|definition|context_clues|oxymoron|cognate|typoglyc|syllable|category_fluency|story_builder|chalk|phonetic'),
    ('ps_memory',    r'memory|n_back|corsi|span|recall|chimp|simon|delayed_match|dnms|card_counting|spatial_cabinet|word_pair|paired_associate'),
    ('ps_reaction',  r'reflex|blink|flash|reaction|subitiz|go_no_go|stop_signal|vigilance|orbit|ghost_tap|whack|frequency|rhythm'),
    ('ps_quiz',      r'estimat|guess|mental_calendar|mental_abacus|percentage|fraction|angle|numeric|currency|unit_converter|radical|roman|arithmetic|algebra|inequality|base_conversion|base_shift|binary_code|modular|modulo|divisibility|matrix|vector|dot_product|pythagor|prime|factor|gcd|common_denominator|venn|set_theory|balance_scale|digit_swap|missing_operator|calculation_sprint|countdown_math|quick_math|target_10|math_path|binomial'
                     r'|collatz|exponent_tower|magic_square|number_bond|sum_pyramid|target_number'),
    ('ps_search',    r'visual_search|schulte|odd_one_out|silhouette|shape_shifter|shadow_pivot|symmetry|topology|color_match|area_perimeter|geometric_vision|navon|negative_space|spotlight|multiple_object|visual_crowding|ab_reversal|cross_section|room_inspector|find_word'),
    ('ps_spatial',   r'fold|cube_net|paper_folding|rotation|perspective|gear_|mirror|pixel_mimic|graph_coordinate|triplets_logic|temporal_order'),
    ('ps_attention', r'stroop|flanker|d2_attention|sdmt|trail_making|task_switch|switch_task|posner|divided_attention|dual_coding|dual_task|change_blindness|conjunction_search|continuous_recognition|dynamic_salience|visual_statistical|source_monitoring|sopt|wisconsin|rule_switcher|sternberg|object_shuffle|object_displacement|shell_game|grocery_list|face_|associative_pairs'),
    ('ps_run',       r'breakout|doodle|flappy|pong|snake|tetris'),
]


# ★★★ 2026-11-08（game-labancer → code-hunter 抽检 88%）**人工矫正表**：关键词打不准的一条条钉死。
#   优先级最高（先查 PIN，再走正则）。加一行的成本 = 改一个分类，别再往正则里堆长词。
PLAY_STYLE_PIN = {
    # ★ 2026-11-08 二轮抽检（code-hunter 看源码判的，不看名字）：
    #   判据 =「玩家实际在做什么操作」，不是「游戏名像什么」。
    'dynamic_salience': 'ps_reaction',    # 20 秒内点掉会自己换位置的亮方块 = 追移动目标
    'polyomino_tiling': 'ps_fill',        # 铺满网格（polyomino tiling）⇒ 与多米诺拼盘同源
    # ═══ 2026-11-08 四轮抽检（98.0%）：**ps_search 被类别兜底系统性污染**（22 款里 13 款不是「找目标」）═══
    #   根因：这批游戏 category 几乎全是 SPATIAL，被 `space` 的兜底顺带塞进 search。
    #   ✅ 判据（code-hunter 记）：**某类抽样错误率 >25% 时必须全量看**，别只抽 —— 这轮就是抽样漏掉的。
    'cross_section_slice': 'ps_spatial',      # 5×5×5 方块堆只画第 h 层，逆推几个 = 空间想象
    'shadow_pivot': 'ps_spatial',             # 光源转角度挑对应影子 = 心理旋转
    'symmetry': 'ps_spatial',                 # 判断关于哪条轴对称
    'silhouette_match': 'ps_spatial',         # 剪影匹配
    'silhouette_match_ortho': 'ps_spatial',   # 正投影剪影
    'shape_shifter': 'ps_spatial',            # 形状变换
    'geometric_vision': 'ps_quiz',            # 几何直觉 = 比两块图形谁占的格子多 ⇒ 与「面积周长」同源（不是在脑内转形）
    'topology': 'ps_spatial',                 # 拓扑等价判断
    'area_perimeter_match': 'ps_quiz',        # 两个矩形比面积/周长，10 题答对 ≥7 = 答题
    'color_match': 'ps_match',                # 点中同色连同整片消掉 = 三消
    'navon_hierarchical': 'ps_attention',     # 大图字母+小图字母 = Navon 整体/局部冲突
    'visual_crowding_acuity': 'ps_attention', # 拥挤视力 = 外周辨认（不是"找目标"）
    'ab_reversal_oddball': 'ps_reaction',     # AB 反转 = 交替刺激+24 帧限时点「反转」⇒ 与「注意瞬脱/奇偶闪现」同族
    # 反向：这两款**真的是 search / memory**，却被 attention 正则吃了
    'conjunction_search': 'ps_search',        # 联合特征搜索 = 多特征找目标
    'dual_coding': 'ps_memory',               # 图文双通道 = 记忆编码
    # 麻将连连看：4×4 共 16 张、点两张相同的牌 = **配对**，不是纸牌接龙
    'mahjong_solitaire': 'ps_match',
    # ═══ 2026-11-08 第五轮：**ps_quiz 全量看 68 款**（抽样 8 款错 4 = 50% > 25% ⇒ 按判据全量）═══
    #   判据：`ps_quiz` = 玩家在「读题 → 判/算 → 选答案」，**不需要在棋盘上挪动/点选物件**。
    #   下列 18 款实际是**操作棋盘**，不是在答题（其余 50 款保留）。
    #   —— 摆放/拖拽/交换 ⇒ ps_push
    'balance_scale': 'ps_push',
    'binary_scale_balance': 'ps_push',
    'digit_swap_eq': 'ps_push',
    'tangle_fix': 'ps_push',
    #   —— 填格/点亮 ⇒ ps_fill
    'sum_pyramid': 'ps_fill',
    'magic_squares': 'ps_fill',
    'fractional_pizza': 'ps_fill',
    'venn_numbers': 'ps_fill',
    #   —— 走格 ⇒ ps_maze
    'math_path': 'ps_maze',
    'modulo_path': 'ps_maze',
    #   —— 配对 ⇒ ps_match
    'binomial_match': 'ps_match',
    'matrix_multiplier_match': 'ps_match',
    'fraction_match': 'ps_match',
    'number_bonds_all': 'ps_match',
    'target_10': 'ps_match',
    #   —— 在阵里点选目标 ⇒ ps_search
    'factor_finder': 'ps_search',
    'prime_hunter': 'ps_search',
    #   —— 计数+抑制干扰 ⇒ ps_attention
    'distractor_matrix': 'ps_attention',
    # ⚠️ 'peg_solitaire'（孔明棋）**不是纸牌**，但它含 solitaire 会被 ps_card 正则抢走 ⇒ 钉回 ps_push
    'peg_solitaire': 'ps_push',
    # ① ps_other 里本可归类的 23 款（真·other 只留 7：4 款可视化 + 3 款纸牌）
    'game24': 'ps_quiz',
    'mastermind': 'ps_quiz',
    'sequence_sleuth': 'ps_quiz',
    'symbol_logic': 'ps_quiz',
    'sequence_stack': 'ps_quiz',
    'logical_syllogisms': 'ps_quiz',
    'peripheral_focus': 'ps_attention',
    'focus_tunnel': 'ps_attention',
    'multi_track_counter': 'ps_attention',
    'double_trouble': 'ps_attention',
    'einstein_riddle': 'ps_fill',
    'pattern_sequence_draw': 'ps_fill',
    'slide_puzzle': 'ps_spatial',
    'interlock_puzzle': 'ps_spatial',
    'spatial_conflict': 'ps_attention',   # 2026-11-08 二轮：箭头方向/文字/位置互相捣乱 = Stroop 式干扰
    'etymon_oddball': 'ps_word',
    'compound_connect': 'ps_maze',
    'counting_sheep': 'ps_attention',     # 2026-11-08 二轮：狼披羊皮混进羊圈，数羊/数格 = 计数+辨别
    'symbol_digit_assoc': 'ps_memory',
    'fact_binder': 'ps_memory',
    'mental_mapping': 'ps_memory',
    'triple_sequence': 'ps_memory',
    # ⑤ MEMORY 类别里**其实是记忆**的 9 款（原来被 attention 正则吃掉）
    'associative_pairs': 'ps_memory',
    'continuous_recognition': 'ps_memory',
    'face_name_association': 'ps_memory',
    'face_trait_association': 'ps_memory',
    'grocery_list': 'ps_memory',
    'object_displacement': 'ps_memory',
    'object_shuffle': 'ps_memory',
    'shell_game': 'ps_memory',
    'sopt': 'ps_memory',
}

def _check_pin_dups():
    """★ 2026-11-08：Python 字典字面量里重复的 key 会**静默覆盖**（后者赢）。
    这张表已经 68 条，手工追加时踩过一次（binary_scale_balance 被旧条目盖掉，
    ps_push 没生效、只在 17/18 行里体现）⇒ 生成前先查重，重复就报错。"""
    from collections import Counter
    src = open(__file__, encoding='utf-8').read()
    keys = re.findall(r"^    '([a-z0-9_]+)': 'ps_[a-z]+',$", src, re.M)
    dup = [k for k, c in Counter(keys).items() if c > 1]
    if dup:
        raise SystemExit('❌ PLAY_STYLE_PIN 有重复 key（后者会静默覆盖前者）：%s' % ', '.join(sorted(dup)))


def play_style_for(gid, hay):
    """玩法归类：① 先查人工矫正表 ② 再按 PLAY_STYLE_RULES 顺序首命中 ③ 兜底 ps_other。"""
    pin = PLAY_STYLE_PIN.get(gid)
    if pin is not None:
        return pin
    for pid, pat in PLAY_STYLE_RULES:
        if re.search(pat, hay):
            return pid
    return 'ps_other'


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
    # 焦点：只给「持续注意 / 抑制控制」类
    # ★ 2026-11-08（game-balancer）：原来 focus 直接由 CAT_ATTR 给整个 MEMORY 类 ⇒
    #   `focus ≡ memory`（74 款完全相同，两个 tag 一条信息）。改成按关键词认。
    if re.search(r'attention|vigilance|stroop|flanker|go_no_go|stop_signal|distractor|neglect|'
                 r'peripheral|change_blindness|d2_attention|divided_attention|dual_task|'
                 r'tunnel|salience|cueing|blink', hay):
        t.add('focus')

    # ── ② 时长（分类主导 + 关键词覆盖）──
    #   极速：反应/闪现/限时点击类
    if re.search(r'reflex|blink|flash|reaction|subitiz|speed|sprint|dash|rush|frequency|go_no_go|stop_signal|ghost|orbit|probe', hay):
        t.add('speed')
    #   长时间：格点逻辑谜题（数织/数回/数独这类一盘要坐一会儿）
    elif cat == 'LOGIC' or re.search(r'go9|nonogram|slitherlink|nurikabe|yajilin|tapa|heyawake|kakuro|kenken|hitori|shikaku|bridges|masyu|dominosa|fillomino|akari|lighthouse|magnet|kurodoko|norinori|gokigen|kakurasu|crown|futoshiki|solitaire|freecell|spider|mahjong|crossword|maze|tangram|sokoban|klotski|slither|paper_folding|cube_net|polyomino|wireframe|jigsaw', hay):
        t.add('long')
    #   短：单题式的数字/记忆/文字小游戏
    elif cat in ('MATH', 'MEMORY', 'WORD'):
        t.add('short')
    else:
        t.add('medium')

    # ── ③ 难度（分类主导 + 关键词覆盖）──
    if re.search(r'go9|nurikabe|slitherlink|yajilin|tapa|heyawake|gokigen|hitori|nonogram|kakuro|kenken|einstein|tower_of_london|n_back|double_n_back|corsi|sternberg|wireframe|mental_rotation|perspective|block_count_3d|cube_net|complex_folding', hay):
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

    # ── ⑥ 场景 ──
    if re.search(r'onehand|reflex|flash|reaction|subitiz|speed|sprint|tap|click', hay):
        t.add('onehand')
    if re.search(r'tetris|snake|breakout|pong|flappy|doodle|endless|runner|counting_sheep|life_game|mandelbrot|sorting|sieve|maze', hay):
        t.add('endless')
    if re.search(r'zen|relax|mandala|counting_sheep|color|hue|sort|sand|garden|aquarium|breath|pixel|shape_shifter|kaleido', hay):
        t.add('zen')
    if 'hard' in t and 'long' in t:
        t.add('brainy')
    if re.search(r'2048|match3|bejewel|bubble|solitaire|spider|freecell|mahjong|nonogram|sudoku|color_flood|water_sort|pixel|tangram|jigsaw|mandala', hay):
        t.add('cozy')

    # 可暂停：不限时 ∧ 不是跑分局 ∧ 这局要坐一会儿（30 秒的局不需要暂停）
    # ★ 2026-11-08（game-balancer）：原来与 untimed 在同一个 else 里一起 add ⇒
    #   `pausable ≡ untimed`（323 款完全相同）。改成 untimed 的真子集。
    if 'untimed' in t and 'endless' not in t and ('medium' in t or 'long' in t):
        t.add('pausable')

    # ── ⑦ 兜底：四类必须各有一个 ──
    if not (t & {'speed', 'short', 'medium', 'long'}):
        t.add('medium')
    if not (t & {'easy', 'normal', 'hard'}):
        t.add('normal')
    if not (t & {'tap', 'swipe', 'drag', 'type'}):
        t.add('tap')
    if not (t & {'timed', 'untimed'}):
        t.add('untimed')

    # ── ⑧ 玩法（playStyle）：每款恰好 1 个（划分，兜底 ps_other）──
    t.add(play_style_for(gid, hay))

    return sorted(t)


def main():
    import json
    _check_pin_dups()
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
  /** ★ 2026-11-08：款数 <10 的细类只用于「像 XX」打分，筛选面板不显示（缺省不写 = 显示） */
  hidden?: boolean;
}

/** 全部特征（按组排列） */
export const TAGS: GameTag[] = [
""")
    for grp, tid, icon, label in TAGS:
        hid = ', hidden: true' if tid in HIDDEN_TAGS else ''
        out.append(f"  {{ group: '{grp}', id: '{tid}', icon: '{icon}', label: '{label}', "
                   f"enLabel: '{EN.get(tid, label)}', enGroup: '{GRP_EN.get(grp, grp)}'{hid} }},\n")
    out.append("""];

/** 分组清单（按出现顺序）—— 只收「至少有一个可见 tag」的组 */
export function tagsByGroup(): string[] {
  const out: string[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    const g: string = TAGS[i].group;
    if (out.indexOf(g) < 0 && TAGS[i].hidden !== true) {
      out.push(g);
    }
  }
  return out;
}

/** 某组下的特征 */
export function tagsIn(group: string): GameTag[] {
  const out: GameTag[] = [];
  for (let i = 0; i < TAGS.length; i++) {
    if (TAGS[i].group === group && TAGS[i].hidden !== true) {
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
