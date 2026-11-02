/**
 * 每款游戏的具体玩法要点 —— 说明页「玩法要点」区的数据源。
 *
 * ★★★ 为什么要有这个文件（2026-11-02 · 判据 126/128）
 *   说明页原先把「tagline + 分类通用提示」当成「玩法要点」，
 *   结果 4 条里 3 条与这款游戏无关，第 1 条还是重复的 tagline。
 *   改成「通用玩法」是不说谎，但**玩家还是学不会一款陌生玩法**。
 *   ⇒ 真正需要的是"这一款具体怎么下"。
 *
 * ★ 内容纪律（很重要）
 *   每一条都必须**从该游戏的源码注释/常量里读出来**，不许凭名字猜。
 *   例：打砖块的「清空 40 块砖」来自 `GBreakout.ets` 里 `5 行 × 8 列` 的常量，
 *       跳棋的「有吃子可走时必须吃」来自 `GCheckers.ets` 的注释。
 *
 * ★ 增量填充（不必一次写完）
 *   没有条目的游戏 ⇒ 说明页自动退回「通用玩法」（诚实降级，不是显示空白）。
 *   建议顺序：① 首屏/精选 24 款（曝光最高）② 已有规则行的 49 款（有底稿）
 *            ③ 其余按分类铺满。
 *
 * ★ 语言
 *   中文 + 英文两版；其余语言由 `L()` 的英文兜底（这是**已知边界**，
 *   不是静默漏翻 —— 已在台账记录，后续按需补）。
 */

/** 一款游戏的具体玩法要点 */
export interface HowTo {
  /** 中文要点（3 条左右） */
  zh: string[];
  /** 英文要点（与 zh 一一对应） */
  en: string[];
}

/**
 * gameId ⇒ 玩法要点。
 * ⚠️ 只放**读过源码确认过**的规则；宁可不写，也不许编。
 */
export const HOW_TO: Record<string, HowTo> = {
  'bejeweled': {
    zh: [
      '点一颗宝石，再点它相邻的一颗，两颗就交换',
      '交换后 3 颗以上同色连成直线就会消掉；每消一颗 +10，一次连消越多倍率越高',
      '20 步（普通难度）内拿到 600 分算通关'
    ],
    en: [
      'Tap one gem, then a neighbour — the two swap places',
      'Three or more of the same colour in a line clear away; each gem is +10, chains multiply',
      'Reach 600 points within 20 moves (Normal) to clear it'
    ]
  },
  'g2048': {
    zh: [
      '四向滑动整个棋盘，所有数字块一起往那个方向挤',
      '两块数字相同且相撞时合并成一块，数字翻倍',
      '每次有效移动后，空位里随机长出一个 2 或 4'
    ],
    en: [
      'Swipe up, down, left or right — every tile slides that way at once',
      'Two tiles with the same number merge into one, doubling the value',
      'After each valid move a new 2 or 4 appears in a random empty cell'
    ]
  },
  'breakout': {
    zh: [
      '手指按住屏幕横向拖动，挡板跟着手指走',
      '球打在挡板的哪个位置，决定它往回弹的角度',
      '清空 5 行 × 8 列共 40 块砖算赢；球落到底就输'
    ],
    en: [
      'Hold and drag sideways — the paddle follows your finger',
      'Where the ball hits the paddle decides the angle it bounces back',
      'Clear all 40 bricks (5 rows × 8) to win; if the ball falls past you, you lose'
    ]
  },
  'bubble_shooter': {
    zh: [
      '点泡泡墙的任意一列，底部那颗待发射的泡泡就沿该列升上去',
      '它停在最下面那颗泡泡的下方；落点周围同色相连 3 颗以上就一起炸掉',
      '每颗 10 分，一炸一团再额外 +50；发射次数用完还没清空就算输'
    ],
    en: [
      'Tap any column of the bubble wall — the loaded bubble flies up that column',
      'It stops just below the lowest bubble there; three or more touching of the same colour pop together',
      'Each popped bubble is 10 points, plus 50 for the cluster; run out of shots before clearing the wall and you lose'
    ]
  },
  'compound_connect': {
    zh: [
      '从上往下左角出发，点相邻格把线接长（只能上下左右接在当前末端）',
      '要同时满足两个条件才算到终点：路径上数字的和 = 目标值，且步数 ≤ 上限',
      '点一下末端那格可以回退一步；一局最多失败 5 次'
    ],
    en: [
      'Start at the top-left corner and tap neighbouring cells to extend the line (only up, down, left or right from its end)',
      'To finish you must satisfy both conditions at once: the digits along the path add up to the target, and the step count stays within the limit',
      'Tap the last cell again to undo one step; you get at most 5 failed attempts per round'
    ]
  },
  'connect_four': {
    zh: [
      '点任意一列，你的 🔴 就落到该列最底下的空位',
      '然后电脑立刻回一手 🟡；双方轮流',
      '先连成四个（横、竖、斜都算）的人赢；棋盘填满还没连成就是和局算你输'
    ],
    en: [
      'Tap any column and your 🔴 drops to the lowest empty slot there',
      'The computer answers immediately with a 🟡; you take turns',
      'Whoever first lines up four — across, down or diagonally — wins; if the board fills with no four, you lose'
    ]
  },
  'continuous_recognition': {
    zh: [
      '屏幕上一个接一个出现图形，你要判断「它刚才出现过没有」',
      '一共 24 题，答对 17 题以上算通关',
      '累计答错 6 题就判负'
    ],
    en: [
      'Shapes appear one after another; decide whether you have just seen this one before',
      'There are 24 in total — get at least 17 right to clear it',
      'Six wrong answers and you lose'
    ]
  },
  'doodle_jump': {
    zh: [
      '踩到平台就会自动弹起来，不用点跳',
      '用屏幕上的 ◀ ▶ 左右平移，去找下一块平台',
      '爬到标着 GOAL 的高度就算通关；掉出屏幕底部就结束'
    ],
    en: [
      'Landing on a platform bounces you up automatically — there is no jump button',
      'Use the ◀ ▶ buttons to slide left and right and line up the next platform',
      'Reach the GOAL height to clear it; fall off the bottom of the screen and it is over'
    ]
  },
  'block_escape': {
    zh: [
      '先点一个方块选中它，再用 ← ↑ ↓ → 沿它自己的方向推一格（车只能顺着车身走）',
      '目标是把 🚗 挪到最右侧的出口',
      '步数太多可以直接重来，「认输」也能结束本局'
    ],
    en: [
      'Tap a block to select it, then press ← ↑ ↓ → to push it one step along its own axis (a car only moves lengthwise)',
      'Your goal is to slide the 🚗 out through the exit on the right edge',
      'Too many moves and you can restart; “give up” also ends the round'
    ]
  },
  'continuous_paired_associate': {
    zh: [
      '先看 4 组配对（左侧和右侧各自对应），记牢后点「记住了」开始答题',
      '之后连出 8 题：给出左边那一项，从 4 个右项里挑出刚才配对的它',
      '中途错满 3 题就失败；答完 8 题算通关'
    ],
    en: [
      'First you see 4 pairs (each left item matched to a right one); memorise them, then tap “got it” to start',
      'Then 8 questions come in a row: you are shown the left item and must pick its partner from 4 right items',
      'Three wrong answers and you fail; answer all 8 to clear it'
    ]
  },
  'double_trouble': {
    zh: [
      '一屏同时出两个任务：左边算算术，右边认颜色',
      '颜色题给一个「字义与颜色不符」的字（比如“红”用绿墨水写），要点的是墨水颜色，不是字',
      '每轮两个都答对才算过；错 3 次生命用尽，撑过 8 轮通关'
    ],
    en: [
      'Two tasks at once on one screen: arithmetic on the left, colour naming on the right',
      'The colour task shows a word whose meaning fights its ink (say “red” printed in green) — tap the ink colour, not the word',
      'Both must be right to pass a round; three mistakes cost you all your lives, and surviving 8 rounds clears it'
    ]
  },
  'dual_mirror': {
    zh: [
      '两块 4×4 灯板，点一下会让两块同时翻转，而且左右是镜像位置',
      '点左板 (行,列) 就会同时翻转左板这一格和右板的镜像格；点右板同理',
      '目标是把两块的灯全部熄灭；步数用完还没灭就算输'
    ],
    en: [
      'Two 4×4 light boards; one tap flips a cell on both boards, at mirrored positions',
      'Tap a cell on the left board and it flips together with its mirror on the right board; the reverse also holds',
      'Your goal is to switch every light off on both boards; run out of moves before that and you lose'
    ]
  },
  'flappy': {
    zh: [
      '每点一下给一个向上的冲力，不点就一直往下掉',
      '穿过一根根管道，碰管道或撞地就结束',
      '穿过指定根数的管道就算通关'
    ],
    en: [
      'Each tap gives an upward kick — stop tapping and you fall',
      'Fly through the pipes; touching a pipe or the ground ends the run',
      'Pass the required number of pipes to clear it'
    ]
  },
  'freecell': {
    zh: [
      '两门花色各 A~8 共 16 张牌，右上角的「家」按 A→8 的顺序收牌',
      '列内只能压「刚好小一点」的牌（黑红天然交替），4 个自由格各能暂存 1 张',
      '两门花色全部归位算通关；再也走不动就输了'
    ],
    en: [
      'Two suits, A to 8, 16 cards in all; the “home” slots at the top right collect them in A→8 order',
      'Within a column a card may only sit on one exactly one rank higher (black and red alternate naturally); the 4 free cells each hold one card',
      'Get both suits fully home to clear it; if nothing can move any more, you lose'
    ]
  },
  'reflex_tap': {
    zh: [
      '屏幕上一个圆点亮起来时，立刻去点它',
      '一共 8 次，会算你的平均反应时和最快一次',
      '平均反应低于 550ms 且点偏不超过 2 次算通关'
    ],
    en: [
      'As soon as a dot lights up on screen, tap it right away',
      'Eight rounds in total; your average and fastest reaction are tracked',
      'Clear it with an average under 550 ms and no more than 2 misses'
    ]
  },
  'choice_reaction_time': {
    zh: [
      '数字一亮就立刻判断它是奇数还是偶数，按「奇」或「偶」',
      '一共 10 题，会算你的平均反应时',
      '平均低于 900ms 且答错不超过 1 次算通关'
    ],
    en: [
      'When a number appears, decide at once whether it is odd or even and press 奇 or 偶',
      'Ten rounds in total; your average reaction time is tracked',
      'Clear it with an average under 900 ms and at most one wrong answer'
    ]
  },
  'odd_even_flash': {
    zh: [
      '数字在屏幕上一闪就消失，你要判断它刚才是奇数还是偶数',
      '闪现的时间会越来越短，越往后越看不清',
      '一共 18 题，答对 13 题以上算通关'
    ],
    en: [
      'A number flashes and vanishes; decide whether it was odd or even',
      'The flash gets shorter and shorter as you go, so later rounds are harder to catch',
      'Eighteen rounds in all — get at least 13 right to clear it'
    ]
  },
  'go_no_go': {
    zh: [
      '绿灯出现就快点，红灯出现要忍住不点',
      '点红灯就是误点，会扣分',
      '20 试里答对 17 次以上、误点不超过 1 次算通关'
    ],
    en: [
      'Tap when the light is green; hold back and do not tap on red',
      'Tapping on red is a false alarm and counts against you',
      'Clear it with at least 17 correct out of 20 trials and no more than 1 false alarm'
    ]
  },
  'stop_signal': {
    zh: [
      '大多数回合是「冲」—— 看到就立刻点',
      '偶尔会亮红灯，那时候按下去就算错',
      '12 回合里答对 10 次以上，且「冲」的平均反应低于 800ms 算通关'
    ],
    en: [
      'Most rounds say go — tap as soon as you see it',
      'Now and then a red stop signal appears; tapping then is an error',
      'Clear it with at least 10 correct out of 12 and an average go-reaction under 800 ms'
    ]
  },
  'vigilance_task': {
    zh: [
      '符号一个接一个闪现，只有看到 ◆ 才点按钮',
      '看到别的符号必须忍住 —— 点了就是误报',
      '40 个刺激里命中 6 次以上、误报不超过 3 次算通关'
    ],
    en: [
      'Symbols flash one after another; tap only when you see ◆',
      'For any other symbol you must hold back — tapping is a false alarm',
      'Clear it with at least 6 hits out of 40 stimuli and no more than 3 false alarms'
    ]
  },
  'stroop_test': {
    zh: [
      '屏幕上是一个颜色词，却用另一种颜色印出来（比如“红”字印成绿色）',
      '要答的是它的墨色，不是字写的是什么',
      '12 题答对 10 题以上算通关'
    ],
    en: [
      'A colour word appears, printed in a different colour (the word “red” in green ink, say)',
      'Answer with the INK colour, not the word',
      'Clear it with at least 10 correct out of 12'
    ]
  },
  'reverse_stroop': {
    zh: [
      '同样是「字义与墨色不符」的字，但这一次反过来',
      '要答的是字写的是什么，不是它的墨色',
      '12 题答对 10 题以上、且平均反应低于 1800ms 算通关'
    ],
    en: [
      'Same kind of word — meaning and ink disagree — but this time it is the other way round',
      'Answer with what the word SAYS, not the ink colour',
      'Clear it with at least 10 correct out of 12 and an average under 1800 ms'
    ]
  },
  'stroop_number_size': {
    zh: [
      '一个数字出现，但它的字号大小故意捣乱（小的印得大、大的印得小）',
      '只看数字本身 —— 它比 5 大还是小',
      '12 题答对 10 题以上算通关'
    ],
    en: [
      'A digit appears, but its font size is deliberately misleading (small values huge, large values tiny)',
      'Ignore the size — just judge the value: is it bigger or smaller than 5?',
      'Clear it with at least 10 correct out of 12'
    ]
  },
  'color_word_match_up': {
    zh: [
      '斯特鲁普式的「词义 vs 墨色」判断，两种问法会交替出现',
      '看清题目问的是「字」还是「墨色」，再看选项',
      '一共 24 题，答对 16 题以上算通关；错满 6 题判负'
    ],
    en: [
      'Stroop-style judging of word meaning versus ink colour, and the question alternates between the two',
      'Read carefully whether the prompt asks about the word or the ink, then choose',
      'Twenty-four rounds in all — at least 16 right to clear it; six wrong and you fail'
    ]
  },
  'dynamic_salience': {
    zh: [
      '一屏方块里有一个会发亮，点它就得分',
      '点掉之后它会自己换个位置再亮起来',
      '20 秒内命中 10 次以上算通关；点错不扣时间，但会计误点'
    ],
    en: [
      'One square among many lights up — tap it to score',
      'After you hit it, it moves somewhere else and lights up again',
      'Clear it with at least 10 hits inside 20 seconds; wrong taps cost no time but are counted'
    ]
  },
  'blink_detector': {
    zh: [
      '屏幕上的眼睛偶尔会很快眨一下（大约 0.2 秒）',
      '看到眨眼就立刻点按钮，没眨就别点',
      '10 次眨眼内命中 6 次以上、误报不超过 3 次算通关'
    ],
    en: [
      'The eyes on screen blink quickly now and then — about 0.2 seconds',
      'Tap as soon as you catch a blink; hold back when there is none',
      'Clear it with at least 6 hits across 10 blinks and no more than 3 false alarms'
    ]
  },
  'focus_tunnel': {
    zh: [
      '5×5 的暗场里只有中央「隧道」半径内的格子是亮的，目标 🎯 一定藏在亮区里',
      '每找到一次，隧道就收窄一圈，周围干扰项越来越暗',
      '找到 6 个目标算通关；点错 3 次就失败'
    ],
    en: [
      'On a 5×5 dark board only the cells inside a central “tunnel” are lit, and the 🎯 is always inside that glow',
      'Each time you find it the tunnel narrows a ring, so the surrounding distractors get dimmer',
      'Find 6 targets to clear it; three wrong taps and you fail'
    ]
  },
  'spatial_conflict': {
    zh: [
      '箭头的「指向 / 文字 / 位置」三样互相捣乱（比如写着左、画着右、位置在上）',
      '只准跟箭头的实际指向走，别管它写的什么字',
      '12 题答对 9 题以上算通关'
    ],
    en: [
      'An arrow messes with you three ways at once: where it points, what its label says, and where it sits',
      'Follow the arrow’s actual direction and ignore the label',
      'Clear it with at least 9 correct out of 12'
    ]
  },
  'typoglycemia_decoder': {
    zh: [
      '每个词只留首尾字母，中间全部打乱（比如 tihs 这种）',
      '靠语感把整句读出来，再从选项里挑出正确的那一句',
      '6 句里读对 4 句以上算通关'
    ],
    en: [
      'Each word keeps its first and last letter with the middle shuffled (like tihs)',
      'Read the sentence by feel, then pick the matching option',
      'Clear it by getting at least 4 of 6 sentences right'
    ]
  },
  'homophone_hunt': {
    zh: [
      '给出发音提示（比如 /aɪ/），从四个词里挑出与它同音的那个',
      '同一题会混进拼写相近但读音不同的词',
      '10 题答对 6 题以上算通关；点错罚 2 秒'
    ],
    en: [
      'You are shown a sound like /aɪ/ and must pick the word from four that shares it',
      'Look-alike words with a different sound are mixed in on purpose',
      'Clear it with at least 6 correct out of 10; a wrong tap costs 2 seconds'
    ]
  },
  'math_guess': {
    zh: [
      '秘密数字在 1 到 100 之间，你有 7 次机会',
      '每次猜完会告诉你偏大还是偏小，用二分法收窄范围',
      '7 次内猜中算通关；次数用尽就失败'
    ],
    en: [
      'A secret number sits between 1 and 100 and you get 7 guesses',
      'After each guess you learn whether you went too high or too low — narrow it like a binary search',
      'Guess it within 7 tries to clear it; run out and you fail'
    ]
  },
  'quick_math': {
    zh: [
      '60 秒限时心算抢答，一题接一题',
      '答对加分、答错扣时间，节奏越快分越高',
      '拿到 100 分算过关'
    ],
    en: [
      'Sixty seconds of rapid-fire mental arithmetic, one question after another',
      'Right answers score, wrong ones cost time — the faster you go the higher you climb',
      'Reach 100 points to clear it'
    ]
  },
  'target_number': {
    zh: [
      '给你三个数和一个目标值，下面有 4 个式子',
      '挑出结果正好等于目标值的那个式子',
      '6 题答对 5 题以上算通关'
    ],
    en: [
      'You get three numbers and a target value, plus four expressions below',
      'Pick the expression whose result is exactly the target',
      'Clear it with at least 5 correct out of 6'
    ]
  },
  'missing_operator': {
    zh: [
      '等式里缺了一个 + − × ÷，挑出能让它成立的那个',
      '一共 60 秒，答得越快题数越多',
      '60 秒内答对 10 题算通关；时间归零就失败'
    ],
    en: [
      'An equation is missing one of + − × ÷ — pick the one that makes it true',
      'You have 60 seconds, and the faster you answer the more questions you see',
      'Get 10 right within 60 seconds to clear it; when the clock hits zero you fail'
    ]
  },
  'digit_span_reverse': {
    zh: [
      '数字一个接一个闪现，闪完凭记忆倒序点回去（正着是 1 2 3，你要点 3 2 1）',
      '一共 6 轮，每两轮位数加长一位',
      '答对 5 轮以上算通关'
    ],
    en: [
      'Digits flash one after another; afterwards tap them back in reverse order (1 2 3 becomes 3 2 1)',
      'Six rounds in all, with one more digit added every two rounds',
      'Clear it with at least 5 rounds right'
    ]
  },
  'probe_digit_span': {
    zh: [
      '数字一位一位闪现，闪完之后问你「第 k 位是几」',
      '用屏幕键盘答出来，答对就加长一位继续',
      '从 3 位一路答到 8 位算通关；中途答错就失败'
    ],
    en: [
      'Digits flash one at a time; once they are gone you are asked “what was the k-th digit?”',
      'Type it on the keypad — a correct answer adds one more digit',
      'Clear it by going from 3 digits all the way to 8; one wrong answer ends the run'
    ]
  },
  'shell_game': {
    zh: [
      '先看清球在哪个碗底下',
      '然后碗开始洗牌，停下来后点出球的位置',
      '连中 5 关算通关，每过一关多洗 2 次'
    ],
    en: [
      'First watch which cup the ball is under',
      'Then the cups shuffle; when they stop, tap where the ball is',
      'Clear it by getting 5 in a row, with two more shuffles added each level'
    ]
  },
  'orbit_tap': {
    zh: [
      '环形轨道上排着 12 个落脚点，目标 🛰️ 每 1.1 秒跳到别处',
      '点中一次 +1，点空会计数',
      '25 秒内点中 10 次算通关；时间耗尽就失败'
    ],
    en: [
      'Twelve points sit on a ring and the 🛰️ target hops somewhere else every 1.1 seconds',
      'Each hit is +1, and misses are counted',
      'Clear it with 10 hits inside 25 seconds; when time runs out you fail'
    ]
  },
  'game24': {
    zh: [
      '开局给你 4 个数，用 ＋ − × ÷ 把它们的全部用上、凑出 24',
      '点一个数、再点另一个数、最后点运算符，两个数就合并成一个结果',
      '每一局都穷举校验过，保证一定有解'
    ],
    en: [
      'You get four numbers — combine all of them with + − × ÷ to reach exactly 24',
      'Tap one number, then another, then an operator, and the two merge into one result',
      'Every puzzle is exhaustively verified, so a solution always exists'
    ]
  },
  'gomoku': {
    zh: [
      '15×15 棋盘，你执黑先下，目标是把五颗子连成一条线（横竖斜都算）',
      '电脑会用启发式评分：能成五就直接赢，你要成五就先堵',
      '谁先连成五颗谁赢'
    ],
    en: [
      'A 15×15 board; you play black and move first — line up five in a row, any direction',
      'The computer scores heuristically: it wins immediately if it can, and blocks you if you can',
      'Whoever makes five first wins'
    ]
  },
  'hanoi': {
    zh: [
      '一次只能移动一个盘子，而且大盘不能压在小盘上面',
      '目标是把所有盘子从最左边的柱子搬到最右边那根',
      '右边柱子上的盘数等于总数时通关'
    ],
    en: [
      'Move one disc at a time, and a larger disc may never sit on a smaller one',
      'Your goal is to move every disc from the leftmost peg to the rightmost peg',
      'You clear it when the right peg holds all the discs'
    ]
  },
  'mahjong_solitaire': {
    zh: [
      '4×4 共 16 张牌（萬/筒各 1~4 各两张），点两张相同的牌配对',
      '两张牌之间要能用不超过两个拐弯、且只经过空格的路连起来才能消',
      '全部消完算通关；重排多次仍无解就失败'
    ],
    en: [
      'Sixteen tiles in a 4×4 grid (1–4 of two suits, two of each); tap two matching tiles to pair them',
      'They clear only if a path connects them with at most two turns, passing over empty spaces',
      'Clear every tile to win; if reshuffles leave you stuck, you fail'
    ]
  },
  'mancala': {
    zh: [
      '轮到你时选一个自己的坑，把里面的石子一颗颗撒进后面的坑（跳过对手的库）',
      '最后一颗落进自己的库，就能再来一次',
      '最后一颗落进自己的空坑，就把对家正对那个坑的石子一起收走'
    ],
    en: [
      'On your turn pick one of your pits and sow its stones one by one into the following pits, skipping your opponent’s store',
      'If the last stone lands in your own store, you get another turn',
      'If it lands in an empty pit of yours, you also capture the stones in your opponent’s pit directly opposite'
    ]
  },
  'mastermind': {
    zh: [
      '4 个位置、6 种颜色，颜色可以重复；每轮摆出一组猜的组合',
      '提交后给反馈：● 位置和颜色都对，○ 颜色对但位置不对',
      '10 次之内猜中算通关；用完 10 次还没中就失败'
    ],
    en: [
      'Four positions, six colours, repeats allowed — set down a guess each round',
      'After you submit you get feedback: ● right colour and right spot, ○ right colour but wrong spot',
      'Guess it within 10 tries to clear; run out and you fail'
    ]
  },
  'kakuro_mini': {
    zh: [
      '3×3 每格填 1~9，每行、每列的数字都不能重复',
      '每一行、每一列的数字和必须等于旁边给出的提示数',
      '六条线（3 行 3 列）全部满足算通关；超过 40 步还没解出就失败'
    ],
    en: [
      'Fill a 3×3 grid with 1–9, no repeats within any row or column',
      'Each row and column must add up to the clue shown beside it',
      'Satisfy all six lines (three rows, three columns) to clear it; more than 40 moves and you fail'
    ]
  },
  'life_game': {
    zh: [
      '每个细胞看它周围 8 格：活细胞有 2~3 个活邻居就继续活，死细胞恰好 3 个活邻居就诞生',
      '点格子可以随时人工干预，加上或拿掉一个细胞',
      '撑满 60 代不灭绝算通关；中途全部死光就失败'
    ],
    en: [
      'Each cell looks at its 8 neighbours: a live cell with 2–3 live neighbours survives, a dead cell with exactly 3 is born',
      'Tap cells any time to interfere by hand — add one or remove one',
      'Survive 60 generations without dying out to clear it; if everything dies, you fail'
    ]
  },
  'lock_pattern': {
    zh: [
      '3×3 一共九个点，系统先闪一遍图案，然后你来画出同样的图案',
      '必须按同样的顺序连，点错一个就结束',
      '连对 5 关算通关，图案会从 3 个点一路加到 7 个点'
    ],
    en: [
      'Nine dots in a 3×3 grid; the game flashes a pattern, then you draw the same one',
      'Follow the same order — one wrong dot ends the run',
      'Clear 5 rounds in a row, with the pattern growing from 3 dots all the way to 7'
    ]
  },
  'mandelbrot': {
    zh: [
      '每一题给一张放大后的分形局部图，画面正中的 ＋ 就是那个待判定的点',
      '判断这个点是否属于曼德博集合（迭代不逃逸就属于）',
      '凭图形边缘的纹路判断 —— 越靠近边界越难'
    ],
    en: [
      'Each round shows a magnified slice of the fractal; the ＋ at the very centre marks the point in question',
      'Decide whether that point belongs to the Mandelbrot set (it does if the iteration never escapes)',
      'Judge by the texture around the edges — the closer to the boundary, the harder it gets'
    ]
  },
  'match3': {
    zh: [
      '点一个果子，再点它上下左右相邻的一个，两者交换位置',
      '交换后能连成 3 个以上同色才会生效并消掉，否则会换回去',
      '消掉后上方的果子落下补新，一次连消越多得分越高'
    ],
    en: [
      'Tap one fruit, then a neighbour above, below, left or right — the two swap places',
      'The swap only counts if it lines up three or more of a colour; otherwise it swaps back',
      'Cleared fruit drops in from above and chains score more the longer they run'
    ]
  },
  'minesweeper': {
    zh: [
      '9×9 的雷区里埋着 10 颗雷，点格子翻开',
      '第一次点击一定安全，而且周围会自动留出一片空白',
      '数字表示它周围 8 格里有几颗雷，据此推断剩下的雷在哪'
    ],
    en: [
      'Ten mines hide in a 9×9 field — tap a cell to open it',
      'Your first tap is always safe and automatically clears an opening area around it',
      'A number tells how many of its 8 neighbours are mines; deduce where the rest sit'
    ]
  },
  'peg_solitaire': {
    zh: [
      '点一颗棋子选中，再点同一条直线上隔一格的空位',
      '跳过去之后，被跳过的那颗棋子就拿掉',
      '全盘没有任何可跳的走法时结算；只剩 1 颗算通关'
    ],
    en: [
      'Tap a peg to select it, then tap an empty hole two steps away in the same line',
      'The peg jumps over, and the peg it jumped is removed',
      'The game settles when no jump remains; finish with exactly one peg to clear it'
    ]
  },
  'go9': {
    zh: [
      '9×9 的交叉点上落子（不是格子里），你执黑先行，AI 执白',
      '气就是上下左右相邻的空点；一块棋没气就会被提掉',
      '按中国规则数子，占地多的一方赢'
    ],
    en: [
      'Play on the 9×9 intersections (not the squares); you take black and move first, the AI plays white',
      'Liberties are the empty points next to a stone; a group with no liberties is captured',
      'Scoring follows Chinese rules — whoever holds more territory wins'
    ]
  },
  'tetris': {
    zh: [
      '← → 左右移动，↻ 旋转，⤓ 速降；方块落到底就固定住',
      '一整行填满就会被消掉，消满 10 行算通关',
      '等级越高落得越快；方块堆到顶就失败'
    ],
    en: [
      '← → move sideways, ↻ rotates, ⤓ drops fast; a piece locks once it lands',
      'A completely filled row clears away — clear 10 rows to pass',
      'Higher levels fall faster; if the stack reaches the top, you fail'
    ]
  },
  'snake': {
    zh: [
      '蛇每 200ms 自动走一格，滑动棋盘或点方向键来转向',
      '吃到食物身体就变长一格',
      '吃满目标个数的食物算通关；撞墙或咬到自己就结束'
    ],
    en: [
      'The snake advances one cell every 200 ms — swipe the board or tap an arrow to turn',
      'Eating food makes it one segment longer',
      'Eat the target number of food items to clear it; hitting a wall or your own body ends the run'
    ]
  },
  'pong': {
    zh: [
      '手指在球场上上下拖动，移动左边的球拍',
      '右边的球拍由电脑控制，它会跟着球走',
      '你先拿到 5 分算通关；电脑先到 5 分就失败'
    ],
    en: [
      'Drag up and down on the court to move your left paddle',
      'The right paddle is computer-controlled and tracks the ball',
      'Reach 5 points first to clear it; if the computer gets to 5 first, you fail'
    ]
  },
  'tic_tac_toe': {
    zh: [
      '你执 ✕ 先下，电脑执 ○，点空格落子',
      '电脑用极小化极大算法（minimax）应对 —— 它不会犯错',
      '你先连成三子算通关；电脑连成或平局都算这一局没赢'
    ],
    en: [
      'You play ✕ and move first, the computer plays ○ — tap an empty square',
      'The computer answers with minimax, so it never makes a mistake',
      'Line up three first to clear it; a computer win or a draw counts as a loss'
    ]
  },
  'slide15': {
    zh: [
      '4×4 的格子里放着 1~15，右下角留空',
      '点空格旁边的一块就能把它滑进空位',
      '把 1~15 按顺序归位、右下角还是空，就算通关'
    ],
    en: [
      'Fifteen numbered tiles sit in a 4×4 grid with the bottom-right corner empty',
      'Tap a tile next to the gap to slide it into the space',
      'Get 1–15 back in order with the gap still in the corner to clear it'
    ]
  },
  'sokoban': {
    zh: [
      '箱子只能推、不能拉，走到箱子旁边朝它的方向走就能推一格',
      '目标是把所有箱子都推到标记点上',
      '一关全部箱子归位就过关，可以接着打下一关'
    ],
    en: [
      'Boxes can only be pushed, never pulled — walk up to one and step toward it to shove it along',
      'Your goal is to get every box onto a marked spot',
      'Put all boxes in place and the level is done; then the next one begins'
    ]
  },
  'reversi': {
    zh: [
      '你执黑先行，落子后把同一条线上被夹住的全部白子翻成黑子',
      '必须能夹住对方的子才能落，无处可下就自动跳过',
      '双方都无处可下（或棋盘下满）时数子，黑多算通关'
    ],
    en: [
      'You play black and move first; a move flips every white piece caught in a line between yours',
      'You may only play where you trap something — if you have no legal move, you pass',
      'When neither side can move (or the board fills), count: more black means you clear it'
    ]
  },
  'sudoku_hex': {
    zh: [
      '6×6 的格子，每行、每列都要出现 1~6 且不重复',
      '2 行 × 3 列为一宫，每一宫里也要 1~6 不重复',
      '点空格选中再点下方 1~6 填入，点「✕」擦除；失误满 5 次就失败'
    ],
    en: [
      'A 6×6 grid where every row and column must contain 1–6 with no repeats',
      'Each 2×3 box must also contain 1–6 exactly once',
      'Tap a cell then a digit below to fill it, or ✕ to erase; five mistakes and you fail'
    ]
  },
  'wordle': {
    zh: [
      '猜一个 5 个字母的英文单词，一共 5 次机会',
      '用屏幕键盘输入后点 ⏎ 提交',
      '绿色 = 字母和位置都对，黄色 = 字母对但位置错，灰色 = 这个词里没有它'
    ],
    en: [
      'Guess a five-letter English word, with five tries in total',
      'Type it on the on-screen keyboard and press ⏎',
      'Green means right letter in the right spot, yellow means right letter in the wrong spot, grey means the word has no such letter'
    ]
  },
  'schulte': {
    zh: [
      '一张方格里打乱排着 1~25，你要按 1 到 25 的顺序依次点',
      '点错会闪红，用时会被记录',
      '点完最后一个数算通关'
    ],
    en: [
      'The numbers 1–25 are scattered across a grid; tap them in order from 1 to 25',
      'A wrong tap flashes red, and your time is recorded',
      'Tap the final number to clear it'
    ]
  },
  'simon_says': {
    zh: [
      '四个色块会依次亮起，你要按同样的顺序点回去',
      '每过一关，序列就加长一位',
      '按错一次就失败；撑到第 12 关算通关'
    ],
    en: [
      'Four coloured pads light up one after another — tap them back in the same order',
      'Each round you pass adds one more step to the sequence',
      'One wrong tap ends the run; survive to round 12 to clear it'
    ]
  },
  'solitaire': {
    zh: [
      '7 列牌堆要按「颜色相反、点数递减」的方式叠放',
      '空出来的列只能放 K',
      '52 张牌全部进基础堆算通关；没牌可翻又无处可放就失败'
    ],
    en: [
      'The seven columns build down in alternating colours',
      'Only a King may move into an empty column',
      'Get all 52 cards onto the foundations to clear it; if you can neither flip nor move, you fail'
    ]
  },
  'memory': {
    zh: [
      '一次翻两张牌，牌面用 emoji 表示',
      '两张图案相同就保留翻开，不同就翻回去',
      '全部配成对算通关'
    ],
    en: [
      'Flip two cards at a time; the faces are emoji',
      'Matching pairs stay face up, mismatches flip back',
      'Pair up every card to clear it'
    ]
  },
  'nim': {
    zh: [
      '三堆石子，分别有 3、5、7 颗；轮流从任意一堆拿走任意多颗',
      '点第 k 颗石子 = 从这一堆拿走 k 颗',
      '谁拿走最后一颗谁就输 —— 让 AI 拿走最后一颗算通关'
    ],
    en: [
      'Three piles of 3, 5 and 7 stones; take turns removing any number from any single pile',
      'Tapping the k-th stone takes k stones from that pile',
      'Whoever takes the last stone loses — make the AI take it to clear the round'
    ]
  },
  'phonetic_guess': {
    zh: [
      '给一个国际音标，从 4 个单词里选出对应的那一个',
      '一共 8 题',
      '答对 6 题以上算通关'
    ],
    en: [
      'You are shown a phonetic transcription — pick the matching word from four',
      'There are 8 questions in total',
      'Clear it with at least 6 correct'
    ]
  },
  'sieve_visualizer': {
    zh: [
      '看埃拉托斯特尼筛怎么把素数筛出来',
      '找到最小的未划掉数 p（它就是素数），把从 p² 起的倍数一个个划掉',
      'p² 超过 100 就收工；筛完算通关，积分按找出的素数个数给'
    ],
    en: [
      'Watch the Sieve of Eratosthenes uncover the primes',
      'Find the smallest unmarked number p (that is a prime), then cross out its multiples from p² upward',
      'Stop once p² passes 100; finishing clears it, and your score counts the primes found'
    ]
  },
  'snake_3d': {
    zh: [
      '3 层 × 4×4 共 48 格的立体盒子，用上下左右移动，另有「升层 / 降层」两个键',
      '吃到食物身体变长',
      '长到 8 节算通关；撞墙或咬到自己就失败'
    ],
    en: [
      'A 3D box of 3 layers × 4×4 (48 cells); move with up/down/left/right plus two extra keys to rise or drop a layer',
      'Eating food makes you longer',
      'Reach 8 segments to clear it; hitting a wall or yourself ends the run'
    ]
  },
  'sorting_visualizer': {
    zh: [
      '12 根柱子随机高低，选一个算法（冒泡 / 插入 / 选择 / 快速）',
      '自动或单步播放每一次「比较」与「交换」—— 橙色是正在比，绿色是已排好',
      '整列排好算通关；比较和交换次数越少分越高'
    ],
    en: [
      'Twelve bars of random height — pick an algorithm (bubble, insertion, selection or quick)',
      'Play back each comparison and swap, automatically or step by step; orange is being compared, green is sorted',
      'Fully sorted clears it, and fewer comparisons and swaps score higher'
    ]
  },
  'spider_solitaire': {
    zh: [
      '8 副黑桃 A~K 共 104 张牌，铺成 10 列',
      '可以整段搬「点数递减」的正面牌，放到比它大一点的牌上；空列能放任意牌',
      '集齐 K→A 一整组就自动收走；收满本档组数算通关'
    ],
    en: [
      'Eight decks of spades, A to K, 104 cards laid out in 10 columns',
      'Move any run of descending face-up cards onto one rank higher; an empty column takes anything',
      'A complete K→A run is collected automatically — collect the required number of runs to clear it'
    ]
  },
  'akari': {
    zh: [
      '灯的照亮范围是自己所在格，并向上下左右直照，遇到黑墙就停',
      '两盏灯不能互相照到（中间必须有墙挡着）',
      '墙上的数字 = 紧挨着它的灯数，必须刚好相等；所有空格都被照亮、数字全满足算通关，违规满 8 次失败'
    ],
    en: [
      'A lamp lights its own cell and shines straight up, down, left and right until a black wall blocks it',
      'Two lamps may never see each other — a wall must sit between them',
      'A wall’s number must equal exactly how many lamps touch it; light every empty cell and satisfy every number to clear it, eight violations and you fail'
    ]
  },
  'binary_puzzle': {
    zh: [
      '6×6 的盘，每格填 0 或 1',
      '每行、每列都要正好有 3 个 0 和 3 个 1',
      '任何一行或一列都不能出现连续三个相同的数'
    ],
    en: [
      'A 6×6 grid where every cell holds a 0 or a 1',
      'Each row and column must contain exactly three 0s and three 1s',
      'No row or column may contain three identical digits in a row'
    ]
  },
  'bridges': {
    zh: [
      '同一行或同一列上的两个岛才能连桥，中间不能有别的岛',
      '两座岛之间最多 2 座桥，桥也不能交叉',
      '岛上的数字 = 连到它的桥数，必须刚好相等；全部满足且所有岛连成一片算通关'
    ],
    en: [
      'Only two islands in the same row or column can be bridged, with no other island between them',
      'At most two bridges may join a pair, and bridges never cross',
      'An island’s number must equal exactly how many bridges reach it; satisfy all of them and keep every island connected to clear it'
    ]
  },
  'color_flood': {
    zh: [
      '左上角是「洪水」起点，每步选一种颜色',
      '与左上角连通的一整块会被染成那个颜色',
      '在步数上限内把整盘染成同一个颜色算通关；步数用尽还没统一就失败'
    ],
    en: [
      'The flood starts in the top-left corner; each move you pick a colour',
      'Everything connected to the top-left region turns that colour',
      'Unify the whole board within the move limit to clear it; run out of moves and you fail'
    ]
  },
  'crown': {
    zh: [
      '每行、每列、每个同色分区里都各放恰好一个皇冠',
      '任意两个皇冠不能相邻 —— 上下左右和斜角都不行',
      '全部要求满足算通关'
    ],
    en: [
      'Every row, every column and every coloured region holds exactly one crown',
      'No two crowns may touch, not even diagonally',
      'Satisfy all of it to clear the board'
    ]
  },
  'dominosa': {
    zh: [
      '点两个相邻的格子，把它们配成一块骨牌',
      '每种点数组合（0-0 到 3-3，共 10 种）只能用一次',
      '铺满棋盘且 10 种骨牌各不相同算通关；步数用尽就失败'
    ],
    en: [
      'Tap two adjacent cells to pair them into a domino',
      'Each number pair (0-0 through 3-3, ten kinds in all) may be used only once',
      'Cover the board using all ten different pairs to clear it; run out of moves and you fail'
    ]
  },
  'futoshiki': {
    zh: [
      '5×5 每行、每列都要填 1~5 且不重复',
      '还要满足格与格之间标出的不等号',
      '填满且行列不重复、所有不等号成立算通关；步数用尽就失败'
    ],
    en: [
      'A 5×5 grid where every row and column holds 1–5 with no repeats',
      'The inequality signs between cells must hold as well',
      'Fill it with no repeats and every sign satisfied to clear it; run out of moves and you fail'
    ]
  },
  'gokigen_naname': {
    zh: [
      '每个方格里画一条斜线（╲ 或 ╱）',
      '每个圆点上的数字 = 交汇在这个点的斜线条数',
      '所有斜线不能围成任何闭合回路；全部满足算通关'
    ],
    en: [
      'Draw one diagonal in every square, either ╲ or ╱',
      'The number on each dot equals how many diagonals meet at that point',
      'The diagonals must never form a closed loop; satisfy everything to clear it'
    ]
  },
  'heyawake': {
    zh: [
      '涂黑一些格子：每个分区里的黑格数要等于角上标的数字',
      '黑格之间不能上下左右相邻；所有白格必须连成一片',
      '一行或一列里连续的白格不能跨越两条以上分区边界'
    ],
    en: [
      'Blacken some cells so that each region holds exactly the number of black cells shown in its corner',
      'Black cells may not touch edge-to-edge, and all white cells must stay connected',
      'A run of white cells in any row or column may not cross more than one region border'
    ]
  },
  'hitori': {
    zh: [
      '涂黑一些格子，使每行每列没被涂黑的数字都不重复',
      '涂黑的格子不能上下左右相邻',
      '所有没涂黑的格子要连成一片；三条全满足算通关'
    ],
    en: [
      'Blacken cells so that the unblackened numbers in every row and column never repeat',
      'Black cells may not touch edge-to-edge',
      'Every white cell must stay connected — satisfy all three to clear it'
    ]
  },
  'kakurasu_sums': {
    zh: [
      '每格可以涂黑或留白，行列号都从 1 数起',
      '第 r 行左边的数字 = 这一行黑格所在列号之和',
      '第 c 列上边的数字 = 这一列黑格所在行号之和'
    ],
    en: [
      'Blacken or leave each cell blank; rows and columns are numbered from 1',
      'The number left of row r is the sum of the column numbers of that row’s black cells',
      'The number above column c is the sum of the row numbers of that column’s black cells'
    ]
  },
  'kakuro': {
    zh: [
      '4×4 的十字盘，白格里填 1~9，黑格是提示位',
      '每条横向或竖向的连续串里数字不能重复，且和要等于串首那个提示数',
      '四条串全部满足算通关；步数用尽就失败'
    ],
    en: [
      'A 4×4 crossword-style grid — fill the white cells with 1–9, the black cells hold the clues',
      'Within each horizontal or vertical run the digits never repeat, and they add up to the clue at its start',
      'Satisfy all four runs to clear it; run out of moves and you fail'
    ]
  },
  'kenken': {
    zh: [
      '4×4 的盘，每行、每列都要出现 1~4 各一次',
      '每个同色的「笼」（一组相邻格）里的数字用左上角标出的运算算出目标值',
      '单格笼就是这个数字本身；行列合法且所有笼都满足算通关'
    ],
    en: [
      'A 4×4 grid where every row and column contains 1–4 exactly once',
      'Each coloured cage of adjacent cells must reach its target using the operation shown in its corner',
      'A one-cell cage simply holds that number; satisfy the rows, columns and every cage to clear it'
    ]
  },
  'klotski': {
    zh: [
      '经典的「横刀立马」布局：曹操 2×2 在上中，四员大将竖在两侧，关羽横在中间，四卒守底',
      '点一个方块选中，再点方向键把它推进相邻的空格（一次一格）',
      '曹操的左上角走到最底部中央那格算通关；步数超过上限就失败'
    ],
    en: [
      'The classic Klotski layout: the 2×2 Cao Cao sits top-centre, four generals stand upright on the sides, Guan Yu lies across the middle, four soldiers guard the bottom',
      'Tap a block to select it, then press a direction key to slide it into the neighbouring empty space, one step at a time',
      'Move Cao Cao’s top-left corner to the bottom-centre gap to clear it; exceed the move limit and you fail'
    ]
  },
  'kurodoko': {
    zh: [
      '每格可涂黑或留白；带数字的格子一定是白格',
      '数字 = 从这个格子朝上下左右看出去能看见的黑格数（视线撞到第一个黑格就停）',
      '两个黑格不能上下左右相邻，而且所有白格必须连成一片'
    ],
    en: [
      'Blacken or leave each cell blank; any cell with a number is always white',
      'The number counts the black cells visible from that cell in all four directions, stopping at the first black one',
      'Black cells may not touch edge-to-edge, and every white cell must stay connected'
    ]
  },
  'lighthouses': {
    zh: [
      '海面上散布着礁石 🪨 和船只 🚢，要在空水格里放灯塔 💡',
      '每艘船都必须被至少一座灯塔照到（灯光沿上下左右直射，遇礁石被挡）',
      '两座灯塔不能互相照到；船全亮且灯塔互不照算通关'
    ],
    en: [
      'Reefs 🪨 and ships 🚢 dot the sea — place lighthouses 💡 in the empty water cells',
      'Every ship must be lit by at least one lighthouse, whose beam runs straight until a reef blocks it',
      'No two lighthouses may see each other; light every ship with lighthouses that never meet to clear it'
    ]
  },
  'lights_out': {
    zh: [
      '5×5 的灯盘，点一格会让它自己和上下左右四格一起「亮 ↔ 灭」翻转',
      '每点一下都是这五格同时翻转，没有例外',
      '全盘熄灭算通关；步数用尽就失败'
    ],
    en: [
      'On a 5×5 board, tapping a cell toggles it and its four edge-neighbours between lit and dark',
      'Every tap flips exactly those five cells at once',
      'Switch everything off to clear it; run out of moves and you fail'
    ]
  },
  'magnets': {
    zh: [
      '棋盘被切成 8 组横向相邻的两格，每一组就是一块磁铁的两端',
      '每块磁铁必须一端是正极 ＋、另一端是负极 －，不能两端同极',
      '最右一列数字 = 该行的正极个数，最下一行数字 = 该列的正极个数'
    ],
    en: [
      'The board is cut into eight horizontal pairs — each pair is the two poles of one magnet',
      'Every magnet must have one ＋ pole and one － pole; both ends can never be the same',
      'The rightmost column counts the ＋ poles in that row, and the bottom row counts them in that column'
    ]
  },
  'masyu': {
    zh: [
      '用一条不交叉、不自交的闭合回路穿过所有圆圈',
      '⚫ 黑圈处必须拐弯（前后两格在它的垂直方向上）',
      '⚪ 白圈处必须直行（前后两格在同一直线上）；回路闭合且所有圆圈规则都满足算通关'
    ],
    en: [
      'Thread one closed loop through every circle — no crossings, no self-intersections',
      'At a ⚫ black circle the loop must turn, with the two neighbouring cells perpendicular to each other',
      'At a ⚪ white circle it must run straight; close the loop with every circle rule satisfied to clear it'
    ]
  },
  'math_maze': {
    zh: [
      '从左上角走到右下角 🏁，只能上下左右走，而且不能走回头路',
      '走过的格子数字会全部累加',
      '到达终点时总路径和必须恰好等于目标数；中途超出、步数用尽、或到了终点但和不对都算失败'
    ],
    en: [
      'Travel from the top-left corner to the 🏁 bottom-right, moving only up, down, left or right, without retracing',
      'The digits of every cell you cross are added up along the way',
      'Your total must equal the target exactly when you arrive; overshooting, running out of moves, or arriving with the wrong sum all fail'
    ]
  },
  'nurikabe': {
    zh: [
      '每个数字是一块「岛」，岛的格数必须恰好等于那个数字',
      '其余格子涂黑，全部黑格要连成一整片墙',
      '墙里不能出现 2×2 的整块黑格；不可逆的错手满 3 次就失败'
    ],
    en: [
      'Each number seeds an island whose size must equal that number exactly',
      'Every other cell is blackened, and all black cells must form one connected wall',
      'The wall may never contain a solid 2×2 block; three irreversible mistakes and you fail'
    ]
  },
  'norinori': {
    zh: [
      '每块区域里恰好放 2 个黑格',
      '所有黑格必须两两拼成多米诺（每对横向或竖向相邻）',
      '4 块区域各 2 个黑格、黑格全部成对算通关；非法落子满 5 次就失败'
    ],
    en: [
      'Each region holds exactly two black cells',
      'All black cells must pair up into dominoes — each pair adjacent horizontally or vertically',
      'Two black cells in every region with all of them paired clears it; five illegal placements and you fail'
    ]
  },
  'shikaku': {
    zh: [
      '把整盘切成若干个矩形',
      '每块矩形里恰好有一个数字，而且矩形的格数要等于那个数字',
      '25 格全部被合法矩形覆盖算通关；非法尝试满 3 次就失败'
    ],
    en: [
      'Cut the whole board into rectangles',
      'Each rectangle must contain exactly one number, and its cell count must equal that number',
      'Cover all 25 cells with legal rectangles to clear it; three illegal attempts and you fail'
    ]
  },
  'alphabet_sudoku': {
    zh: [
      '6×6 的盘，用 A~F 代替数字，3 行 × 2 列为一宫',
      '点空格选中，再点下方 A~F 填入；点「✕」擦除',
      '36 格填满且行、列、宫都不重复算通关；失误满 5 次就失败'
    ],
    en: [
      'A 6×6 grid using A–F instead of digits, with 3×2 boxes',
      'Tap a cell then a letter below to fill it, or ✕ to erase',
      'Fill all 36 cells with no repeats in any row, column or box to clear it; five mistakes and you fail'
    ]
  },
  'bridges_all': {
    zh: [
      '7×7 的大棋盘、11 座岛，规则和「桥梁」一样，只是更密',
      '同一行或同一列、中间没有别的岛才能连；两岛之间最多 2 座桥，桥不交叉',
      '岛上的数字 = 连到它的桥数；全部满足且所有岛连成一片算通关'
    ],
    en: [
      'A bigger 7×7 board with eleven islands — same rules as Bridges, just denser',
      'Only islands sharing a row or column with nothing between them can connect; at most two bridges per pair, never crossing',
      'An island’s number must equal its bridge count; satisfy all of them and keep every island connected to clear it'
    ]
  },
  'fillomino': {
    zh: [
      '把空格都填上数字',
      '同数字的连通块，格数必须恰好等于那个数字',
      '例如数字 4 只能出现在由 4 格连成的一块里'
    ],
    en: [
      'Fill every empty cell with a number',
      'A connected block of identical numbers must contain exactly that many cells',
      'So a 4 can only live inside a block of four connected cells'
    ]
  },
  'hitori_all': {
    zh: [
      '8×8 的进阶版数壹，规则与 5×5 相同',
      '涂黑后每行、每列没被涂黑的数字都不重复',
      '黑格不能上下左右相邻，而且所有白格必须连成一片'
    ],
    en: [
      'An 8×8 version of Hitori with the same rules as the smaller board',
      'After blackening, the remaining numbers in every row and column must be unique',
      'Black cells may not touch edge-to-edge, and every white cell must stay connected'
    ]
  },
  'math_path': {
    zh: [
      '4×4 的格子里是数字或运算符（＋ － ×）',
      '从任意格出发，依次点相邻的格子拼出一条路径',
      '路径必须是「数字 → 运算符 → 数字 → … → 数字」这样交替'
    ],
    en: [
      'A 4×4 grid holding either numbers or operators (+, −, ×)',
      'Start anywhere and tap neighbouring cells one after another to build a path',
      'The path must alternate strictly: number → operator → number → … → number'
    ]
  },
  'nonogram': {
    zh: [
      '5×5 的格子，行首和列首给出数字线索',
      '线索表示这一行/列里连续涂黑的段长（比如「2 1」= 先涂 2 格、隔开、再涂 1 格）',
      '行列线索全部满足、涂出图案算通关；错涂满 3 次就失败'
    ],
    en: [
      'A 5×5 grid with number clues along the top and left',
      'A clue gives the lengths of consecutive filled runs in that line (so “2 1” means two filled, a gap, then one)',
      'Satisfy every clue to reveal the picture and clear it; three wrong fills and you fail'
    ]
  },
  'path_finder': {
    zh: [
      '7×7 的迷宫，从左上角走到右下角',
      '点相邻的格子一步步移动',
      '走到终点算通关；步数超过上限就失败'
    ],
    en: [
      'A 7×7 maze — travel from the top-left corner to the bottom-right',
      'Tap neighbouring cells to step along',
      'Reach the goal to clear it; exceed the move limit and you fail'
    ]
  },
  'path_intersect': {
    zh: [
      '5×5 的盘上有 4 组同色端点',
      '把每一组的两端用线连起来',
      '线不许共用格子（不能交叉），4 组全部连通算通关'
    ],
    en: [
      'Four pairs of matching endpoints sit on a 5×5 board',
      'Connect each pair with a line',
      'Lines may never share a cell — get all four pairs connected to clear it'
    ]
  },
  'pipes': {
    zh: [
      '5×5 的管道，点格子会把它旋转 90°',
      '目标是把所有接口都对接上',
      '所有开口两两对接、水不漏算通关；步数用完就失败'
    ],
    en: [
      'A 5×5 pipe grid — tapping a cell rotates it 90°',
      'Your goal is to join every connector',
      'Every opening must meet its partner with no leak to clear it; run out of moves and you fail'
    ]
  },
  'skyscrapers': {
    zh: [
      '4×4 的盘，每行每列都要填 1~4 且不重复',
      '盘外的数字，是从那个方向看过去能看见的楼数（高的会挡住矮的）',
      '拉丁方成立且四边提示全对算通关；错手 5 次就失败'
    ],
    en: [
      'A 4×4 grid where every row and column holds 1–4 with no repeats',
      'The numbers outside the grid count the buildings visible from that direction, since taller ones hide shorter ones',
      'A valid Latin square with every edge clue satisfied clears it; five mistakes and you fail'
    ]
  },
  'slide_puzzle': {
    zh: [
      '3×3 的八数码，1~8 打乱摆放，右下角留空',
      '点空格旁边的一块就能把它滑进空位',
      '1~8 依次归位算通关；步数用完就失败'
    ],
    en: [
      'A 3×3 sliding puzzle with tiles 1–8 shuffled and the bottom-right corner empty',
      'Tap a tile next to the gap to slide it in',
      'Get 1–8 back in order to clear it; run out of moves and you fail'
    ]
  },
  'slitherlink': {
    zh: [
      '5×5 的盘，在格子边上画线，拼成一条闭合回路',
      '每格里的数字 = 这一格四条边中被画上的边数',
      '线索全对且回路闭合、只有一个环算通关'
    ],
    en: [
      'Draw along cell edges on a 5×5 board to form one closed loop',
      'A number inside a cell says how many of its four edges carry a line',
      'Match every clue and close a single loop to clear it'
    ]
  },
  'sudoku': {
    zh: [
      '9×9 的数独，每行、每列都要出现 1~9 且不重复',
      '3×3 为一宫，每一宫里也要 1~9 各一次',
      '填满且行列宫都不冲突算通关'
    ],
    en: [
      'Classic 9×9 sudoku — every row and column must contain 1–9 exactly once',
      'Each 3×3 box must also hold 1–9 exactly once',
      'Fill the board with no conflicts in any row, column or box to clear it'
    ]
  },
  'sum_snake': {
    zh: [
      '4×4 的盘上有一条蛇，从蛇头出发沿相邻格延伸',
      '路径上经过的数字会累加',
      '和正好等于目标算通关；超过目标就撑爆失败（数字全为正，只能回退）'
    ],
    en: [
      'A snake starts at its head on a 4×4 board and extends through neighbouring cells',
      'The numbers along its path add up as it grows',
      'Hit the target exactly to clear it; overshoot and it bursts, since all numbers are positive and you can only back up'
    ]
  },
  'tangle_fix': {
    zh: [
      '六个节点排成一行，中间有很多连线互相交叉',
      '点两个节点就能交换它们的位置',
      '把交叉数降到 0 算通关；步数用完还有交叉就失败'
    ],
    en: [
      'Six nodes sit in a row with many lines crossing between them',
      'Tap two nodes to swap their positions',
      'Reduce the crossings to zero to clear it; run out of moves with any crossing left and you fail'
    ]
  },
  'tapa': {
    zh: [
      '5×5 的盘，涂黑一些格子',
      '每个数字格的八邻域里，黑格要按数字连成相应段数（比如「1 2」= 一段 1 格、隔开、再一段 2 格）',
      '黑格连成一片、不许出现 2×2 黑块、数字格本身不能涂黑；180 秒倒计时归零就失败'
    ],
    en: [
      'Blacken some cells on a 5×5 board',
      'Around each clue cell the black cells must form runs matching its digits (so “1 2” means a run of one, a gap, then a run of two)',
      'Black cells must stay connected with no 2×2 block, and clue cells stay white; the 180-second timer running out means failure'
    ]
  },
  'tenner_grid': {
    zh: [
      '10×10 的盘，每行、每列都要恰好含 0~9 各一次',
      '点空格选中，再点数字键盘填入；再点同一个数字就是擦掉',
      '填满 100 格且无冲突算通关；冲突满 3 次就失败（冲突的数不会落盘）'
    ],
    en: [
      'A 10×10 grid where every row and column must contain 0–9 exactly once',
      'Tap a cell then a digit to fill it; tapping the same digit again erases',
      'Fill all 100 cells with no conflict to clear it; three conflicts and you fail — a conflicting digit never lands'
    ]
  },
  'tents_and_trees': {
    zh: [
      '6×6 的盘上，每棵树旁边要放恰好一顶帐篷',
      '帐篷之间不能相邻 —— 上下左右和斜角都不行',
      '行列边上的数字是该行/该列的帐篷总数；全部满足算通关，违规摆放 3 次就失败'
    ],
    en: [
      'On a 6×6 board each tree needs exactly one tent beside it',
      'Tents may never touch, not even diagonally',
      'The numbers outside count tents in that row or column; satisfy everything to clear it, and three illegal placements mean failure'
    ]
  },
  'water_sort': {
    zh: [
      '试管里的颜色一层层叠着',
      '点一根试管选中，再点另一根把最上面那层倒过去（同色或空管才收）',
      '每根试管都只剩一种颜色算通关；一步都走不动就失败'
    ],
    en: [
      'Test tubes hold layers of coloured liquid',
      'Tap a tube to select it, then tap another to pour the top layer across — only onto the same colour or an empty tube',
      'Get every tube down to a single colour to clear it; if nothing can move, you fail'
    ]
  },
  'yajilin': {
    zh: [
      '点白格把它涂黑',
      '带箭头的线索格不能取消，它告诉你那个方向上有几个黑格',
      '4 道题全部做成合法的环算通关'
    ],
    en: [
      'Tap white cells to blacken them',
      'Arrow clues cannot be cancelled — each tells how many black cells lie in that direction',
      'Complete all four puzzles as valid loops to clear it'
    ]
  },
  'checkers': {
    zh: [
      '点自己的棋子，再点高亮的可走格 —— 斜走一格',
      '跳过对方棋子落到它后面的空格就能吃掉它；能连跳就一直跳',
      '只要能吃子就必须吃；走到对方底线升王，王可以往回走',
      '对方没子或没子可动，你就赢了'
    ],
    en: [
      'Tap your piece, then a highlighted square — you move one step diagonally',
      'Hop over an opponent into the empty square beyond to capture it; keep hopping if you can',
      'If a capture is available you must take it; reach the far edge to become a king, which can move backwards',
      'You win when your opponent has no pieces or no legal move'
    ]
  }
};

/** 取某款游戏的玩法要点；没有则返回 null（说明页据此降级到「通用玩法」） */
export function howToOf(id: string): HowTo | null {
  const h: HowTo | undefined = HOW_TO[id];
  return h !== undefined ? h : null;
}
