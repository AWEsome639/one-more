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
  'algebraic_balance': {
    zh: [
      '屏幕上一个一元一次方程，形如 a·x + b = c（也可能出现减号）',
      '从 4 个候选值里点出 x 的解',
      '一共 10 题，答对 7 题以上算通关'
    ],
    en: [
      'A one-variable linear equation appears, shaped like a·x + b = c (the sign may be a minus too)',
      'Solve for x and tap it among four candidates',
      'Ten questions in all — get at least seven right to clear it'
    ]
  },
  'arithmetic_chain': {
    zh: [
      '从一个起始数出发，依次点运算符，最多 4 步',
      '每点一个运算符，当前数就按它变一次',
      '让结果正好落到目标数上；5 关过 4 关算通关'
    ],
    en: [
      'Start from a given number and tap operators one after another, at most four steps',
      'Each operator you tap transforms the running value',
      'Land exactly on the target; clear 4 of the 5 stages to pass'
    ]
  },
  'balance_scale': {
    zh: [
      '左盘放着要称的物体，重量已经标出来了',
      '右盘自己挑砝码 —— 点一下放上，再点一下拿回',
      '右盘砝码刚好等于物体重量就过关，连过 5 关算通关；任何一关右盘超重，天平立刻翻，直接失败'
    ],
    en: [
      'The object to weigh sits on the left pan with its weight shown',
      'Load the right pan with weights yourself — tap to add one, tap again to take it back',
      'Match the weight exactly to pass; clear 5 rounds in a row, but overload the pan even once and the scale tips and you fail on the spot'
    ]
  },
  'base_conversion_run': {
    zh: [
      '十进制和二进制、八进制、十六进制之间互相换算',
      '四选一作答；答对连击加分，答错扣 3 秒',
      '60 秒内答对 10 题算通关；时间归零还没达标就失败'
    ],
    en: [
      'Convert between decimal and binary, octal or hexadecimal',
      'Pick one of four answers; right answers build a combo, wrong ones cost 3 seconds',
      'Get 10 right within 60 seconds to clear it; when the clock hits zero short of that, you fail'
    ]
  },
  'binary_code': {
    zh: [
      '给出一个目标数（十进制 1~255）',
      '点亮 8 个位开关拼出它 —— 每个开关就是一个二进制位',
      '拼对自动进下一关；60 秒内拼对 6 关算通关'
    ],
    en: [
      'A target number appears, from 1 to 255 in decimal',
      'Light up the eight bit switches to build it — each switch is one binary digit',
      'A correct total advances you automatically; clear 6 rounds within 60 seconds to pass'
    ]
  },
  'binomial_match': {
    zh: [
      '给定 (a+b)ⁿ，左列是 4 个展开项 aᵏb^(n−k)，右列是打乱的 4 个系数',
      '左边点一个、右边点一个，配对正确就锁定',
      '4 组全配对算通关；错满 3 次就失败'
    ],
    en: [
      'Given (a+b)ⁿ, the left column holds four expansion terms aᵏb^(n−k) and the right column their four coefficients, shuffled',
      'Tap one on each side — a correct pairing locks in',
      'Match all four to clear it; three mistakes and you fail'
    ]
  },
  'calculation_sprint': {
    zh: [
      '加减乘除心算，一题接一题',
      '四选一作答；答对连击加分，答错扣 3 秒',
      '60 秒内答对 15 题算通关；时间归零还没达标就失败'
    ],
    en: [
      'Mental arithmetic — add, subtract, multiply, divide — one question after another',
      'Pick one of four answers; right answers build a combo, wrong ones cost 3 seconds',
      'Get 15 right within 60 seconds to clear it; when the clock runs out short of that, you fail'
    ]
  },
  'collatz': {
    zh: [
      '从随机起点出发，每一步从 4 个候选里选出正确的下一项',
      '规则很简单：偶数除以 2，奇数乘 3 加 1',
      '一路推到 1 算通关；错满 3 次就失败'
    ],
    en: [
      'Start from a random number and pick the correct next term from four candidates each step',
      'The rule is simple: halve an even number, or triple an odd one and add 1',
      'Reach 1 to clear it; three mistakes and you fail'
    ]
  },
  'countdown_math': {
    zh: [
      '点一个数字 → 点一个运算符 → 再点一个数字，一步步算出目标数',
      '目标数显示在屏幕上方；中间结果会保留下来继续运算',
      '90 秒内解出 3 题以上算通关'
    ],
    en: [
      'Tap a number, then an operator, then another number — build your way to the target',
      'The target sits at the top of the screen, and intermediate results carry over for the next operation',
      'Solve at least 3 within 90 seconds to clear it'
    ]
  },
  'crypto_arithmetic': {
    zh: [
      '一个竖式里几个字母各代表一个数字，同一个字母代表同一个数字',
      '给五个字母指派互不相同的数字，而且多位数首位不能是 0',
      '5 题里解出 4 题以上算通关'
    ],
    en: [
      'In a column sum each letter stands for one digit, and the same letter is always the same digit',
      'Assign five distinct digits to the letters, keeping in mind a multi-digit number cannot start with 0',
      'Solve at least 4 of the 5 puzzles to clear it'
    ]
  },
  'digit_swap_eq': {
    zh: [
      '屏幕上是几个「被交换了数字」的错误等式',
      '点两个数字块就能交换它们的位置',
      '把等式改对；60 秒内改对 5 个以上算通关'
    ],
    en: [
      'Several equations sit on screen with digits swapped into the wrong places',
      'Tap two digit tiles to swap their positions',
      'Fix the equations — get at least 5 right within 60 seconds to clear it'
    ]
  },
  'divisibility_dash': {
    zh: [
      '屏幕上一个数和一个除数',
      '快速判断「能整除」还是「不能整除」',
      '45 秒内答对 12 题以上算通关'
    ],
    en: [
      'A number and a divisor appear together',
      'Quickly decide whether the division comes out exact',
      'Get at least 12 right within 45 seconds to clear it'
    ]
  },
  'exponent_tower': {
    zh: [
      '屏幕上一个幂塔 a^(b^c)',
      '要算出它的值，从 4 个候选里选一个',
      '注意是从上往下算：先算 b^c，再拿它当指数。8 题答对 6 题以上算通关'
    ],
    en: [
      'A power tower a^(b^c) appears on screen',
      'Work out its value and pick from four candidates',
      'Remember it stacks upward: compute b^c first, then raise a to that. Get at least 6 of 8 right to clear it'
    ]
  },
  'factor_finder': {
    zh: [
      '屏幕上有一个数 n，下面 12 格候选数',
      '点出 n 的所有因数；踩到非因数就扣一条命',
      '3 条命内闯完 4 关算通关'
    ],
    en: [
      'A number n appears with twelve candidate values below it',
      'Tap every factor of n; touching a non-factor costs one life',
      'Clear all 4 levels without losing your 3 lives to pass'
    ]
  },
  'fibonacci_merge': {
    zh: [
      '点两个相邻的格子',
      '如果两数之和也是斐波那契数，它们就合并成那个和，另一格补一个新数',
      '合出 21 算通关；错 3 次就失败'
    ],
    en: [
      'Tap two neighbouring cells',
      'If their sum is also a Fibonacci number they merge into it, and a fresh number takes the other cell',
      'Merge your way up to 21 to clear it; three mistakes and you fail'
    ]
  },
  'fraction_match': {
    zh: [
      '8 张牌两两成对，每一对是两个等值的分数（比如 1/2 和 2/4）',
      '每次翻两张，配成就锁定',
      '60 秒内配齐 4 对算通关；超时就失败'
    ],
    en: [
      'Eight cards form four pairs — each pair is two fractions of equal value, like 1/2 and 2/4',
      'Flip two at a time; a match locks in',
      'Match all 4 pairs within 60 seconds to clear it; run over and you fail'
    ]
  },
  'inequality_dash': {
    zh: [
      '屏幕上一个不等式 ax + c ⋚ k',
      '把它解成 x 的范围，四选一',
      '60 秒内答对 8 题算通关；时间到还没达标就失败'
    ],
    en: [
      'An inequality ax + c ⋚ k appears',
      'Solve it into a range for x and pick one of four answers',
      'Get 8 right within 60 seconds to clear it; run out of time short of that and you fail'
    ]
  },
  'magic_squares': {
    zh: [
      '3×3 的幻方挖掉了 4 格，要从托盘里选数字填回去',
      '填满后会校验八条线（3 行 + 3 列 + 2 条对角线）的和是否都相等',
      '120 秒内过 3 关算通关；超时或错满 4 次就失败'
    ],
    en: [
      'Four cells are missing from a 3×3 magic square — pick numbers from the tray to fill them',
      'Once full, all eight lines (three rows, three columns, two diagonals) must share the same sum',
      'Clear 3 levels within 120 seconds; timing out or four mistakes means failure'
    ]
  },
  'mental_abacus': {
    zh: [
      '屏幕上一串数连着加减（像算盘上的珠子那样罗列）',
      '五个数的连加连减，心算最终结果',
      '四选一作答；60 秒内答对 8 题算通关'
    ],
    en: [
      'A chain of numbers is added and subtracted in a row, laid out like abacus beads',
      'Work out the final result of the five-term sum in your head',
      'Pick one of four answers; get 8 right within 60 seconds to clear it'
    ]
  },
  'mental_calendar': {
    zh: [
      '给一个日期（1995 到 2035 年之间的任意一天）',
      '从七个星期里选出它真实是星期几',
      '90 秒内答对 6 题算通关'
    ],
    en: [
      'Any date between 1995 and 2035 appears',
      'Pick the weekday it really fell on from the seven',
      'Get 6 right within 90 seconds to clear it'
    ]
  },
  'modulo_clock': {
    zh: [
      '现在是 N 点，再过 M 小时（或者 M 小时前）是几点？',
      '按模 12 算 —— 过了 12 点就绕回来',
      '四选一作答，一共 8 题；答对 6 题以上算通关'
    ],
    en: [
      'It is N o’clock — what time will it be in M hours (or M hours ago)?',
      'Work modulo 12, so the clock wraps around',
      'Eight questions with four choices each; get at least 6 right to clear it'
    ]
  },
  'number_bonds': {
    zh: [
      '一个目标数要拆成两部分',
      '其中一部分已经给出，从四个选项里补上另一部分',
      '一共 10 题，答对 8 题以上算通关'
    ],
    en: [
      'A target number must split into two parts',
      'One part is given — pick the missing part from four options',
      'Ten questions in all; get at least 8 right to clear it'
    ]
  },
  'numerical_estimation': {
    zh: [
      '给一个乘法、除法或百分数的算式',
      '不用算精确值 —— 从四个选项里挑出最接近的估算结果',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'A multiplication, division or percentage expression appears',
      'No need for the exact value — pick the closest estimate from four options',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'percentage_peak': {
    zh: [
      '45 秒内连答百分比题：求百分之几、或者求占比',
      '四选一作答',
      '答对 12 题算通关；时间归零还没达标就失败'
    ],
    en: [
      'Answer percentage questions nonstop for 45 seconds — find a percentage, or find the share',
      'Four choices each time',
      'Get 12 right to clear it; when the clock runs out short of that, you fail'
    ]
  },
  'algebraic_inequality_solver': {
    zh: [
      '屏幕上一个一元一次不等式',
      '算出它的解集，从 4 个解集里点出正确的一个',
      '一共 10 题，答对 7 题以上算通关'
    ],
    en: [
      'A one-variable linear inequality appears',
      'Work out its solution set and pick the right one from four',
      'Ten questions in all — get at least seven right to clear it'
    ]
  },
  'base_shift': {
    zh: [
      'b 进制下把一个数「左移 k 位」，也就是末尾添上 k 个 0',
      '选出它对应的十进制值 —— 添 k 个 0 相当于乘以 b 的 k 次方',
      '四选一，10 题答对 7 题以上算通关；答错 3 次就失败'
    ],
    en: [
      'A number in base b is shifted left by k places — k zeros appended',
      'Pick its decimal value: appending k zeros multiplies it by b to the k-th power',
      'Four choices, ten questions; get at least 7 right to clear it, but three wrong answers and you fail'
    ]
  },
  'binary_matrix_rank': {
    zh: [
      '给一个 4×4 的 0/1 矩阵',
      '算它在模 2（GF(2)）下的秩，也就是高斯消元后非零行的个数',
      '模 2 下「同列相消」就是按位异或；四选一，8 题答对 6 题以上算通关'
    ],
    en: [
      'A 4×4 matrix of zeros and ones appears',
      'Find its rank over GF(2) — the number of non-zero rows after Gaussian elimination',
      'Over GF(2) elimination is just bitwise XOR; four choices, eight questions, get at least 6 right to clear it'
    ]
  },
  'binary_scale_balance': {
    zh: [
      '右盘只有 1、2、4、8、16、32、64 各一枚砝码',
      '每枚「放 = 1、不放 = 0」，把开关拨到加起来刚好等于物体重量',
      '连过 6 关算通关；任何一关超重，天平立刻翻，直接失败'
    ],
    en: [
      'The right pan has one weight each of 1, 2, 4, 8, 16, 32 and 64',
      'Each is “in = 1, out = 0”; set the switches so the total matches the object exactly',
      'Clear 6 rounds in a row; overload any one of them and the scale tips and you fail at once'
    ]
  },
  'common_denominator': {
    zh: [
      '给两个分数',
      '选出它们的最小公分母（最小公倍数 = 两分母相乘 ÷ 最大公因数）',
      '四选一，选完会顺带显示通分结果；8 题答对 6 题以上算通关'
    ],
    en: [
      'Two fractions appear',
      'Pick their least common denominator — the lcm, which is the two denominators multiplied and divided by their gcd',
      'Four choices, and the converted fractions are shown afterwards; get at least 6 of 8 right to clear it'
    ]
  },
  'fraction_matcher': {
    zh: [
      '给出一个分数',
      '从四个分数里选出与它等值的那个（比如 1/2 与 2/4）',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'One fraction is shown',
      'Pick the fraction among four that equals it, like 1/2 and 2/4',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'fractional_pizza': {
    zh: [
      '题目给出一个分数',
      '按那个分数点亮同样多的披萨片，点「确认」判定',
      '题数按难度（简单 4 / 普通 6 / 困难 8），答对到通关线（3 / 5 / 7）算通关'
    ],
    en: [
      'A fraction is given',
      'Light up that many pizza slices and press confirm to check',
      'The number of rounds depends on difficulty (4 easy, 6 normal, 8 hard) — reach the pass line of 3, 5 or 7 to clear it'
    ]
  },
  'inequality_balance_ops': {
    zh: [
      '天平两边各是一个算式',
      '比较它们的大小，选出正确的 < 、= 或 >',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'Each side of the balance holds an expression',
      'Compare them and pick the correct <, = or >',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'matrix_multiplier': {
    zh: [
      '给两个 2×2 矩阵 A 和 B',
      '求乘积 C 的指定元素 —— A 的那一行和 B 的那一列会高亮出来',
      '60 秒内答对 8 题算通关；时间归零就失败'
    ],
    en: [
      'Two 2×2 matrices A and B are shown',
      'Find one specified entry of the product C — the relevant row of A and column of B are highlighted',
      'Get 8 right within 60 seconds to clear it; when the clock hits zero you fail'
    ]
  },
  'matrix_multiplier_match': {
    zh: [
      '左边 3 个「A × B」算式，下边 3 个打乱顺序的乘积矩阵',
      '左边点一个、右边点一个，配对正确就锁定',
      '90 秒内完成 3 块题板（每块 3 对）算通关'
    ],
    en: [
      'Three “A × B” expressions sit on the left, three shuffled product matrices below',
      'Tap one on each side — a correct pairing locks in',
      'Finish three boards of three pairs each within 90 seconds to clear it'
    ]
  },
  'matrix_reasoning': {
    zh: [
      '一个 3×3 的数阵，其中一格被挖掉',
      '每一行的第三个数，都是由前两个按同一个规律算出来的',
      '找出这个规律，补上缺的那格；60 秒内答对 8 题算通关'
    ],
    en: [
      'A 3×3 number grid with one cell removed',
      'In every row the third number comes from the first two by the same rule',
      'Find the rule and fill the gap; get 8 right within 60 seconds to clear it'
    ]
  },
  'modular_clock_arithmetic': {
    zh: [
      '钟面指着某个点',
      '往前或往后拨若干小时，选出最后落在哪个钟点上（按模 12 算）',
      '60 秒内答对 10 题算通关；时间归零就失败'
    ],
    en: [
      'A clock face points at some hour',
      'Wind it forward or back a given number of hours and pick where it lands, modulo 12',
      'Get 10 right within 60 seconds to clear it; when the clock hits zero you fail'
    ]
  },
  'modulo_path': {
    zh: [
      '5×5 的格子里藏着一条路，起点已经给出',
      '每次只能走到上下左右相邻、并且数值恰好 +1 的格子（满 8 就归 0）',
      '把整条路走出来；走满 6 格算通关，踩错 3 次就失败'
    ],
    en: [
      'A hidden path runs through a 5×5 grid, with its start given',
      'You may only step to an edge-neighbour whose value is exactly one higher, wrapping from 8 back to 0',
      'Walk the whole path — 6 cells clears it, three wrong steps and you fail'
    ]
  },
  'number_bonds_all': {
    zh: [
      '目标数是 n，棋盘上 1 到 n 每个数各出现两次',
      '每次点两块，只要两块之和 = n 就拆出一组，这两块随即作废',
      '把所有拆法找齐算通关；点错 3 次就失败'
    ],
    en: [
      'The target is n, and every number from 1 to n appears twice on the board',
      'Tap two tiles — if they add up to n they form a pair and both are removed',
      'Find every pairing to clear it; three wrong taps and you fail'
    ]
  },
  'pattern_sequence_draw': {
    zh: [
      '3×3 的格子按 1 到 9 编号',
      '从 1 出发，每次前进 k 格（数到 9 就回到 1），按这个规律依次点格子',
      '9 格全部按顺序点亮算通关；点错 3 次就失败'
    ],
    en: [
      'A 3×3 grid numbered 1 through 9',
      'Start at 1 and each time advance k cells, wrapping past 9 back to 1 — tap them in that order',
      'Light all 9 in sequence to clear it; three wrong taps and you fail'
    ]
  },
  'percentage_shopping': {
    zh: [
      '屏幕上一件商品的原价和折扣',
      '从 4 个选项里算出折后价',
      '一共 6 件商品，答对 5 件以上算通关'
    ],
    en: [
      'An item’s original price and a discount appear',
      'Work out the sale price and pick it from four options',
      'Six items in all; get at least 5 right to clear it'
    ]
  },
  'prime_factor_trees': {
    zh: [
      '屏幕上一个合数，要把它一路拆成质因数',
      '每次都选能整除它的质数，拆到底',
      '5 棵质因数树里拆对 4 棵算通关'
    ],
    en: [
      'A composite number must be broken down into prime factors',
      'Each time pick a prime that divides it and keep going to the bottom',
      'Split 4 of the 5 factor trees correctly to clear it'
    ]
  },
  'prime_gap_hunt': {
    zh: [
      '找出相邻两个素数之间的差',
      '比如 7 和 11 之间隔 4',
      '一共 10 题，答对 7 题以上算通关'
    ],
    en: [
      'Find the gap between two neighbouring primes',
      'For example 7 and 11 are 4 apart',
      'Ten questions in all; get at least 7 right to clear it'
    ]
  },
  'prime_hunter': {
    zh: [
      '一个 5×5 的数字阵',
      '把里面所有素数都点掉，注意别误点合数',
      '3 关里猎到 2 关算通关'
    ],
    en: [
      'A 5×5 grid of numbers',
      'Tap away every prime in it, and take care not to hit a composite',
      'Clear 2 of the 3 rounds to pass'
    ]
  },
  'pythagorean_triple_builder': {
    zh: [
      '要构造出一组勾股数（三条边满足 a² + b² = c²）',
      '按题目要求凑出三条边的长度',
      '关数按难度（简单 4 / 普通 6 / 困难 8），解出到通关线（3 / 5 / 7）算通关'
    ],
    en: [
      'Build a Pythagorean triple — three sides satisfying a² + b² = c²',
      'Assemble the side lengths the puzzle asks for',
      'Rounds depend on difficulty (4 easy, 6 normal, 8 hard); reach the pass line of 3, 5 or 7 to clear it'
    ]
  },
  'radical_roots': {
    zh: [
      '把一个根式 √n 化成 a√b 的形式',
      '要把 n 里所有平方因子都提出来',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'Simplify a radical √n into the form a√b',
      'Pull every perfect-square factor out of n',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'roman_arithmetic': {
    zh: [
      '屏幕上是罗马数字写的算式',
      '算出结果，或者选出正确的罗马数字答案',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'An arithmetic problem written in Roman numerals',
      'Work out the result, or pick the correct Roman numeral answer',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'sequence_sleuth': {
    zh: [
      '屏幕上前五项排成一列',
      '找出它们背后的规律，推出第六项',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'The first five terms of a sequence are laid out',
      'Spot the rule behind them and work out the sixth',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'sequence_stack': {
    zh: [
      '屏幕给出已经堆好的数列',
      '从 4 个候选里选出下一项（规律是等差或等比）',
      '堆满 8 层算通关；错 3 次就失败'
    ],
    en: [
      'A sequence is shown already stacked up',
      'Pick the next term from four candidates — the rule is arithmetic or geometric',
      'Stack all 8 levels to clear it; three mistakes and you fail'
    ]
  },
  'set_theory_venn': {
    zh: [
      '给出集合 A、B 和一个数字',
      '判断这个数字落在哪个区域：只在 A、只在 B、都在、都不在',
      '一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'Two sets A and B are given along with a number',
      'Decide where it lands: only in A, only in B, in both, or in neither',
      'Eight questions in all; get at least 6 right to clear it'
    ]
  },
  'sum_pyramid': {
    zh: [
      '底层 4 个数已经给出',
      '自下而上把金字塔填满 —— 每个格子是它下面相邻两数之和',
      '6 格全部填对算通关；错 3 次就失败'
    ],
    en: [
      'The bottom row of four numbers is given',
      'Fill the pyramid upward — each cell is the sum of the two below it',
      'Fill all 6 cells correctly to clear it; three mistakes and you fail'
    ]
  },
  'target_10': {
    zh: [
      '4×5 的数字格',
      '点两块相加正好是 10 的牌，把它们消掉',
      '75 秒内全部消完算通关；时间到还剩牌就失败'
    ],
    en: [
      'A 4×5 grid of numbers',
      'Tap two tiles that add up to exactly 10 to clear them',
      'Clear them all within 75 seconds to win; any left when time runs out and you fail'
    ]
  },
  'unit_converter_pro': {
    zh: [
      '给一个带单位的数值',
      '从 4 个选项里选出换算后的正确结果',
      '一共 10 题，答对 8 题以上算通关'
    ],
    en: [
      'A value arrives with its unit',
      'Pick the correctly converted result from four options',
      'Ten questions in all; get at least 8 right to clear it'
    ]
  },
  'vector_dot_product': {
    zh: [
      '给出两个向量（2 维或 3 维）',
      '算出它们的点积',
      '从 4 个选项里选；一共 8 题，答对 6 题以上算通关'
    ],
    en: [
      'Two vectors are given, either 2D or 3D',
      'Compute their dot product',
      'Pick from four options; eight questions, at least 6 right to clear it'
    ]
  },
  'vector_grid_alignment': {
    zh: [
      '网格上给出起点和目标格',
      '按方向键走「向量 (dx, dy)」那么多步，把点走进目标格里',
      '5 个向量全部对齐算通关；某一回合步数用尽还没对齐就失败'
    ],
    en: [
      'A start and a target cell are marked on a grid',
      'Step by the vector (dx, dy) to move the point into the target',
      'Align all 5 vectors to clear it; if a round runs out of steps before you do, you fail'
    ]
  },
  'vektor_vector': {
    zh: [
      '给出两个平面向量',
      '算出 a ± b，从四个候选里选出正确的分量',
      '8 题里拿到 600 分以上算通关'
    ],
    en: [
      'Two plane vectors are given',
      'Compute a ± b and pick the correct components from four candidates',
      'Score above 600 across the 8 questions to clear it'
    ]
  },
  'venn_numbers': {
    zh: [
      '两个集合：A 是 3 的倍数，B 是偶数',
      '把每个数字点进它该在的区域',
      '6 个数字全部归位、且答错不超过 3 次算通关'
    ],
    en: [
      'Two sets: A holds multiples of 3, B holds even numbers',
      'Drag each number into the region it belongs to',
      'Place all 6 correctly with no more than 3 mistakes to clear it'
    ]
  },
  'associative_pairs': {
    zh: [
      '屏幕给出一个词',
      '从四个词里挑出跟它成对的那个（联想关系，比如「笔」对「纸」）',
      '8 题里拿到 600 分以上算通关'
    ],
    en: [
      'One word appears on screen',
      'Pick the word among four that pairs with it — an associative link, like pen with paper',
      'Score above 600 across the 8 questions to clear it'
    ]
  },
  'attentional_blink': {
    zh: [
      '一串字符一个接一个快速闪过',
      '其中有一个是数字，你要找出它是几',
      '5 轮里答对 4 轮以上算通关，每一轮间隔会再快 40ms'
    ],
    en: [
      'A stream of characters flashes past one at a time',
      'Exactly one of them is a digit — work out which',
      'Get at least 4 of 5 rounds right to clear it, with each round arriving 40 ms faster'
    ]
  },
  'card_counting_memory': {
    zh: [
      '8 张牌会快速闪过一遍，其中有一张出现了两次',
      '闪完之后点出那张重复的牌',
      '8 轮里答对 6 轮以上算通关'
    ],
    en: [
      'Eight cards flash past quickly, and one of them appears twice',
      'Afterwards, tap the card that repeated',
      'Get at least 6 of 8 rounds right to clear it'
    ]
  },
  'change_blindness': {
    zh: [
      '九宫格先闪 1.3 秒让你记住',
      '画面翻动后第二次呈现时，会悄悄换掉其中一格',
      '指出是哪一格被换了；6 轮答对 4 轮以上算通关'
    ],
    en: [
      'A 3×3 grid flashes for 1.3 seconds to memorise',
      'After the screen flips, one cell comes back changed',
      'Point out which cell — get at least 4 of 6 rounds right to clear it'
    ]
  },
  'conjunction_search': {
    zh: [
      '要在一个颜色与形状都混杂的场里找出目标',
      '颜色和形状两个特征都要对上，不能只看其中一个',
      '连过 6 关算通关；点错 3 次就判负'
    ],
    en: [
      'Find the target in a field where both colour and shape vary',
      'Both features must match — watching only one will mislead you',
      'Clear 6 rounds in a row; three wrong taps and you lose'
    ]
  },
  'corsi_blocks': {
    zh: [
      '方块会依次亮起',
      '按同样的顺序点回来（正着点，不用倒过来）',
      '答对长度为 6 的一轮算通关；2 条命用完就判负'
    ],
    en: [
      'Blocks light up one after another',
      'Tap them back in the same order — forwards, no reversing',
      'Correctly repeat a run of 6 to clear it; lose both lives and you fail'
    ]
  },
  'counting_span': {
    zh: [
      '边数边记：每张卡上有若干黄点，先数出来',
      '全部数完之后，再按顺序回忆每张卡的数目',
      '全对且张数到 5 算通关；2 条命用完就判负'
    ],
    en: [
      'Count and remember at once: each card holds some yellow dots — count them first',
      'When all the cards are done, recall each count in order',
      'Get everything right up to 5 cards to clear it; lose both lives and you fail'
    ]
  },
  'd2_attention': {
    zh: [
      '划消测验：在一屏字符里点出所有「带正好两个小撇的 d」',
      '撇数不对或者字母不对都不能点',
      '30 秒内找齐 6 个目标算通关；时间到就判负'
    ],
    en: [
      'A cancellation test: tap every “d” carrying exactly two small marks',
      'Wrong mark count or wrong letter must be left alone',
      'Find all 6 targets within 30 seconds to clear it; when time runs out you fail'
    ]
  },
  'delayed_match_sample': {
    zh: [
      '先看一眼样例图形',
      '隔一小会儿之后，从 4 个图形里挑出刚才那个',
      '8 题答对 6 题以上算通关；错满 3 题就判负'
    ],
    en: [
      'Study a sample shape for a moment',
      'After a short delay, pick that same shape out of four',
      'Get at least 6 of 8 right to clear it; three wrong answers and you fail'
    ]
  },
  'divided_attention': {
    zh: [
      '左右两路符号会同时跳变',
      '哪一边出现了 🎯 就点哪一边',
      '12 拍里命中 7 次以上、且误报不超过 2 次算通关'
    ],
    en: [
      'Two streams of symbols change at once, left and right',
      'Whichever side shows a 🎯 is the side to tap',
      'Clear it with at least 7 hits across 12 beats and no more than 2 false alarms'
    ]
  },
  'dnms': {
    zh: [
      '先记住一组样例图形',
      '然后从选项里挑出那个「你刚才没见过」的',
      '6 轮答对 5 轮以上算通关；样例数会一轮比一轮多'
    ],
    en: [
      'Memorise a set of sample shapes',
      'Then pick the one among the options that you have not just seen',
      'Get at least 5 of 6 rounds right to clear it, with more samples each round'
    ]
  },
  'double_n_back': {
    zh: [
      '位置和字母两条通道同时跟进',
      '每一条都要和 N 步之前的那个比，看是否相同',
      'N = 2，20 个判断里答对 15 个以上算通关'
    ],
    en: [
      'Two channels run at once — one for positions, one for letters',
      'Each must be compared with what it was N steps back',
      'With N = 2, get at least 15 of 20 judgments right to clear it'
    ]
  },
  'dual_coding': {
    zh: [
      '词和图片会一起呈现，你要两条通道都记住',
      '然后按词找出它对应的那张图',
      '一共 6 题，答对 5 题以上算通关'
    ],
    en: [
      'Words come paired with pictures — remember both channels at once',
      'Afterwards you are given a word and must find its picture',
      'Six questions in all; get at least 5 right to clear it'
    ]
  },
  'dual_task_memory': {
    zh: [
      '先记住 4 位数字',
      '中途会插入一段心算，你要边算边守住那 4 位',
      '最后回忆数字；3 轮共 12 位，答对 9 位以上算通关'
    ],
    en: [
      'Memorise four digits first',
      'Then mental arithmetic interrupts — must hold those digits while you calculate',
      'Finally recall them; across 3 rounds (12 digits), get at least 9 right to clear it'
    ]
  },
  'event_timeline_memory': {
    zh: [
      '几个事件会按顺序逐个登场',
      '之后它们被打乱，你要照原来的顺序点回来',
      '3 轮里答对 2 轮以上算通关 —— 一轮里 4 个事件全对才算这轮对'
    ],
    en: [
      'Several events appear in order, one after another',
      'Then they are shuffled and you must tap them back in the original order',
      'Clear it with at least 2 of 3 rounds right — and a round only counts if all 4 events are in order'
    ]
  },
  'face_name_association': {
    zh: [
      '先记住 6 张脸各自的名字',
      '之后会逐一给出脸，让你配上正确的名字',
      '6 题答对 5 题以上算通关'
    ],
    en: [
      'First memorise the names attached to six faces',
      'Then each face appears and you must pair it with the right name',
      'Get at least 5 of 6 right to clear it'
    ]
  },
  'face_trait_association': {
    zh: [
      '先记住 6 张脸各自的「特质」（比如职业或爱好的标签）',
      '之后凭脸回想它对应的是哪一个',
      '6 题答对 5 题以上算通关'
    ],
    en: [
      'First memorise the trait attached to each of six faces — a job or hobby label, say',
      'Then look at a face and recall which trait belongs to it',
      'Get at least 5 of 6 right to clear it'
    ]
  },
  'feature_matrix_recall': {
    zh: [
      '4×4 的格子里会亮起 3 个红格和 3 个蓝格',
      '遮蔽之后，只点出被指定的那一种颜色',
      '选中的 3 格全对算通关'
    ],
    en: [
      'Three red and three blue cells light up on a 4×4 grid',
      'Once they are hidden, tap only the colour you were asked for',
      'All three of your picks must be right to clear it'
    ]
  },
  'flanker_test': {
    zh: [
      '一排箭头出现，只中间那个才是目标',
      '两侧的箭头可能跟它同向也可能反向 —— 要忽略它们',
      '12 题答对 11 题以上、且平均反应低于 900ms 算通关'
    ],
    en: [
      'A row of arrows appears; only the middle one is your target',
      'The flanking arrows may agree with it or point the other way — ignore them',
      'Clear it with at least 11 of 12 right and an average reaction under 900 ms'
    ]
  },
  'frequency_tap': {
    zh: [
      '跟着 100 BPM 的节拍点圆盘',
      '要尽量踩在拍点上，系统会记录你每次的误差',
      '20 拍命中 16 拍以上算通关'
    ],
    en: [
      'Tap the disc in time with a 100 BPM beat',
      'Aim for the beat itself — your timing error is recorded on every tap',
      'Clear it with at least 16 hits out of 20 beats'
    ]
  },
  'ghost_tap': {
    zh: [
      '4×4 的格子里会有幽灵一闪即逝',
      '趁它还在的时候点中它；越往后它闪得越快',
      '15 只幽灵里抓到 12 只以上算通关'
    ],
    en: [
      'A ghost flashes briefly somewhere on a 4×4 grid',
      'Tap it while it is still there — and it gets faster as you go',
      'Catch at least 12 of the 15 ghosts to clear it'
    ]
  },
  'grocery_list': {
    zh: [
      '先记住一份购物清单',
      '之后逐题判断「这件东西在单子上吗」',
      '3 轮里答对 75% 以上算通关'
    ],
    en: [
      'First memorise a grocery list',
      'Then answer one question at a time: was this item on the list?',
      'Get at least 75% right across 3 rounds to clear it'
    ]
  },
  'mandala_recall': {
    zh: [
      '彩格会亮起 2 秒然后熄灭',
      '凭记忆把亮过的格子全部点回来',
      '连过 4 关算通关；错一次就判负'
    ],
    en: [
      'Coloured cells light up for 2 seconds, then go dark',
      'Tap back every cell that was lit, from memory',
      'Clear 4 rounds in a row to win; a single mistake and you lose'
    ]
  },
  'memory_matrix': {
    zh: [
      '一组格子会闪一下',
      '凭记忆把它们全部点出来',
      '过 5 关算通关；点错 3 次就失败'
    ],
    en: [
      'A set of cells flashes once',
      'Tap all of them back from memory',
      'Clear 5 rounds to win; three wrong taps and you fail'
    ]
  },
  'multiple_object_tracking': {
    zh: [
      '几个圆点会先高亮一下，那就是要盯住的目标',
      '高亮消失后它们混进其他圆点里一起移动',
      '停下后指出刚才那几个目标；3 轮里全对 2 轮以上算通关'
    ],
    en: [
      'A few dots light up briefly — those are the targets to watch',
      'The highlight fades and they move around among all the other dots',
      'When everything stops, point out the original targets; get at least 2 of 3 rounds fully right to clear it'
    ]
  },
  'n_back': {
    zh: [
      '字母一个一个出现',
      '每次判断：当前这个字母，和 2 步之前的那个是否相同',
      '一共 12 个试次，答对 9 个以上算通关'
    ],
    en: [
      'Letters appear one at a time',
      'Each time, decide whether the current letter matches the one from 2 steps back',
      'Twelve trials in all; get at least 9 right to clear it'
    ]
  },
  'narrative_recall': {
    zh: [
      '读一篇很短的小故事',
      '读完后凭记忆回答细节题（每篇 3 题）',
      '难度决定通关线：简单 4 题 / 普通 5 题 / 困难 6 题（全场可答 6 题）'
    ],
    en: [
      'Read a very short story',
      'Then answer detailed questions from memory — three per story',
      'The pass line depends on difficulty: 4 easy, 5 normal, 6 hard (six questions are available in all)'
    ]
  },
  'negative_space_detection': {
    zh: [
      '满屏都是色块，但留白部分拼出了一个形状',
      '要认出这个「负空间」形状是哪一个',
      '关数按难度（简单 4 / 普通 6 / 困难 8），答对到通关线（3 / 5 / 7）算通关'
    ],
    en: [
      'The screen is filled with colour blocks, but the gaps between them outline a shape',
      'Recognise which shape that negative space forms',
      'Rounds depend on difficulty (4 easy, 6 normal, 8 hard); reach the pass line of 3, 5 or 7 to clear it'
    ]
  },
  'object_displacement': {
    zh: [
      '6 个格子里摆着 5 个物件',
      '遮罩一闪之后，其中一个偷偷换了格子',
      '指出是谁动了；8 轮答对 6 轮以上算通关'
    ],
    en: [
      'Five objects sit in six cells',
      'A cover flashes, and one of them sneaks to a different cell',
      'Point out which one moved; get at least 6 of 8 rounds right to clear it'
    ]
  },
  'object_shuffle': {
    zh: [
      '先看清 💎 在哪只盒子底下',
      '盒子开始两两换位，你要一直盯住它的落点',
      '8 轮里猜中 6 轮以上算通关'
    ],
    en: [
      'First watch which box the 💎 is under',
      'The boxes start swapping in pairs — keep your eye on where it ends up',
      'Get at least 6 of 8 rounds right to clear it'
    ]
  },
  'operation_span': {
    zh: [
      '一组小题会按顺序出现，你要一道道算出来',
      '算完的每个结果都要记住',
      '题目全部结束后，按原来的顺序把这些结果回忆出来；组长度从 2 → 3 → 4 全部走通算通关'
    ],
    en: [
      'A set of small problems appears in order — work each one out',
      'Remember every result as you go',
      'When they are all done, recall those results in the original order; get through set sizes 2 → 3 → 4 to clear it'
    ]
  },
  'peripheral_focus': {
    zh: [
      '眼睛盯住屏幕中心的 ➕ 不要移开',
      '用余光辨认周边一闪而过的符号',
      '14 次里答对 10 次以上算通关'
    ],
    en: [
      'Keep your eyes fixed on the ➕ in the centre',
      'Identify the symbol flashing in your peripheral vision without looking at it',
      'Get at least 10 of 14 right to clear it'
    ]
  },
  'posner_spatial_cueing': {
    zh: [
      '先盯住中心的注视点',
      '然后会给出一个方位提示，接着目标出现',
      '尽快点目标所在的那一侧；16 次答对 12 次以上算通关（越快分越高）'
    ],
    en: [
      'Fix your gaze on the centre point',
      'A directional cue appears, then the target does',
      'Tap the side the target appeared on as fast as you can; get at least 12 of 16 right to clear it, and faster scores higher'
    ]
  },
  'reading_span': {
    zh: [
      '一句一句地读，每句判断它通不通顺',
      '一组读完，要按顺序回忆每句的关键词',
      '组长度从 2 → 3 → 4 全部走通算通关；判断错或回忆顺序错都算失败'
    ],
    en: [
      'Read sentences one at a time, judging whether each makes sense',
      'After the set, recall the key word of each sentence in order',
      'Get through set sizes 2 → 3 → 4 to clear it; a wrong judgment or a wrong recall order fails you'
    ]
  },
  'relational_memory': {
    zh: [
      '先记住 6 组配对',
      '之后给出其中一半，凭记忆点出正确的那一半',
      '6 题答对 5 题以上算通关'
    ],
    en: [
      'First memorise six pairs',
      'Then you are shown one half of each and must tap the matching half from memory',
      'Get at least 5 of 6 right to clear it'
    ]
  },
  'rhythm_master': {
    zh: [
      '先看 4 下示范拍，注意它们的间隔',
      '然后照同样的间隔自己敲 4 下',
      '平均间隔误差不超过 150ms 算通关'
    ],
    en: [
      'Watch four demonstration beats and note the interval between them',
      'Then tap four beats yourself at the same interval',
      'Clear it if your average timing error stays within 150 ms'
    ]
  },
  'attentional_blink_probe': {
    zh: [
      '一串字符快速闪过，其中有一个数字（T1）',
      '要回答两件事：那个数字是几？它之后有没有闪过一个「探针 ✦」？',
      '4 轮共 8 分，拿到 6 分以上算通关'
    ],
    en: [
      'A stream of characters flashes past, containing one digit (T1)',
      'Two questions: what was that digit, and did a ✦ probe flash after it?',
      'Four rounds worth 8 points in all — score at least 6 to clear it'
    ]
  },
  'corsi_backward_span': {
    zh: [
      '方块会依次亮起',
      '这次要按相反的顺序点回来（倒背，不是正着点）',
      '答对长度为 5 的一轮算通关；2 条命用完就判负'
    ],
    en: [
      'Blocks light up one after another',
      'This time tap them back in REVERSE order — backwards, not forwards',
      'Clear a run of length 5 to win; lose both lives and you fail'
    ]
  },
  'feature_matrix_recall_all': {
    zh: [
      '4×4 的格子里会亮起 6 格',
      '遮蔽之后，要把这 6 格「全部」点回来',
      '6 格完全正确算通关'
    ],
    en: [
      'Six cells light up on a 4×4 grid',
      'Once they are hidden, tap back ALL six of them',
      'All six must be exactly right to clear it'
    ]
  },
  'memory_palace': {
    zh: [
      '3 件物品会被摆进 9 个格子里，你先记住位置',
      '它们熄灭后，凭位置回忆',
      '3 轮共 9 问，答对 7 问以上算通关'
    ],
    en: [
      'Three objects are placed into nine cells — memorise where',
      'They disappear, and you recall their positions',
      'Three rounds of nine questions; get at least 7 right to clear it'
    ]
  },
  'rule_switcher': {
    zh: [
      '规则每 3 题就换一次：在「判奇偶」和「比大小」之间来回切',
      '要看清当前用的是哪条规则再作答',
      '15 题答对 12 题以上、且平均反应低于 1600ms 算通关'
    ],
    en: [
      'The rule flips every three questions, alternating between odd-or-even and bigger-or-smaller',
      'Check which rule is in force before answering',
      'Clear it with at least 12 of 15 right and an average reaction under 1600 ms'
    ]
  },
  'running_memory_span': {
    zh: [
      '数字一个接一个闪过，全程都要跟住',
      '最后只需按顺序点出「最后 N 个」',
      '连过广度 3 → 4 → 5 三关算通关'
    ],
    en: [
      'Digits flash past one after another and you must track them the whole way',
      'At the end, tap back only the LAST N of them, in order',
      'Get through spans of 3 → 4 → 5 to clear it'
    ]
  },
  'sdmt': {
    zh: [
      '屏幕上方有一张图例：每个符号对应一个数字',
      '照着图例把符号换成数字，一题接一题',
      '90 秒内答对 25 题算通关'
    ],
    en: [
      'A key sits at the top of the screen pairing each symbol with a digit',
      'Use it to convert symbols into digits, one after another',
      'Get 25 right within 90 seconds to clear it'
    ]
  },
  'sopt': {
    zh: [
      '9 个方格上随机布着 1 到 9 的数字',
      '按 1→9 的顺序依次点，每轮序号都会重新打乱',
      '撑过 3 轮算通关；点错 3 次就失败'
    ],
    en: [
      'The digits 1 to 9 are scattered across nine squares',
      'Tap them in order from 1 to 9, and the layout is reshuffled each round',
      'Survive 3 rounds to clear it; three wrong taps and you fail'
    ]
  },
  'spatial_cabinet_memory': {
    zh: [
      '六个格子里会亮出几件物品，停留 1.5 秒',
      '之后收起，然后问你「某件物品在哪一格」',
      '6 轮答对 5 轮以上算通关'
    ],
    en: [
      'Several objects appear in six cells for 1.5 seconds',
      'They are then hidden, and you are asked which cell a given object was in',
      'Get at least 5 of 6 rounds right to clear it'
    ]
  },
  'spotlight_track': {
    zh: [
      '一块亮斑在 4×5 的网格里来回移动',
      '停下后点出它最后落脚的格子',
      '8 轮答对 6 轮以上算通关；轮次越高它挪得越多'
    ],
    en: [
      'A bright spot moves around a 4×5 grid',
      'When it stops, tap the cell it ended on',
      'Get at least 6 of 8 rounds right to clear it, and it moves more each round'
    ]
  },
  'staircase_memory': {
    zh: [
      '六级台阶会逐级点亮，形成一段升序的路线',
      '暗下之后，照着顺序点回来',
      '4 关从 3 级加到 6 级，全过算通关；错一级就失败'
    ],
    en: [
      'Six steps light up one by one, tracing an ascending route',
      'Once they go dark, tap the steps back in that order',
      'Four rounds grow from 3 steps to 6 — clear them all; one wrong step and you fail'
    ]
  },
  'subitizing_rush': {
    zh: [
      '一团圆点只亮 420 毫秒',
      '来不及一个个数，只能「一眼看出」有几个',
      '10 题答对 8 题以上算通关'
    ],
    en: [
      'A cluster of dots shows for only 420 ms',
      'Too fast to count one by one — you have to just see how many there are',
      'Get at least 8 of 10 right to clear it'
    ]
  },
  'switch_task': {
    zh: [
      '同一个数字，按屏幕上的提示来决定怎么答',
      '提示会在「比大小」和「判奇偶」之间来回切换',
      '12 轮答对 9 轮以上算通关'
    ],
    en: [
      'The same number appears, and the on-screen prompt decides how to answer',
      'The prompt switches back and forth between bigger-or-smaller and odd-or-even',
      'Get at least 9 of 12 rounds right to clear it'
    ]
  },
  'symbol_digit_assoc': {
    zh: [
      '屏幕上方有对照表：每个符号对应一个数字',
      '给一个符号，选出它对应的数字',
      '12 题答对 9 题以上算通关'
    ],
    en: [
      'A key at the top of the screen pairs each symbol with a digit',
      'A symbol appears — pick the digit it maps to',
      'Get at least 9 of 12 right to clear it'
    ]
  },
  'symbol_logic': {
    zh: [
      '用符号代替数字的代数题',
      '由给出的两条线索，推出第一个符号是几（加或减的题型）',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'Algebra where symbols stand in for numbers',
      'Two clues are given — work out what the first symbol equals (addition or subtraction)',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'symbolic_flanker': {
    zh: [
      '一排箭头出现，只看正中间那个的方向',
      '两侧的箭头一律是干扰项，不管它们朝哪边',
      '16 轮答对 13 轮以上算通关'
    ],
    en: [
      'A row of arrows appears — judge only the direction of the middle one',
      'The flanking arrows are pure distraction, whichever way they point',
      'Get at least 13 of 16 rounds right to clear it'
    ]
  },
  'task_switching': {
    zh: [
      '同一个刺激，按提示在「判形状」和「判颜色」之间切换',
      '系统会对比「重复同一规则」和「刚切换过」两种情况的反应时',
      '16 轮答对 12 轮以上算通关'
    ],
    en: [
      'One stimulus, and the prompt makes you switch between judging shape and judging colour',
      'The game compares your reaction time when the rule repeats versus when it just switched',
      'Get at least 12 of 16 rounds right to clear it'
    ]
  },
  'trail_making': {
    zh: [
      '要按「1 → A → 2 → B → …」这样数字和字母交替的顺序点格子',
      '一直连到 13 和 L',
      '25 个全部连上、错误不超过 4 次算通关；错第 5 次立即失败'
    ],
    en: [
      'Tap the cells alternating between numbers and letters: 1 → A → 2 → B and so on',
      'Keep going all the way to 13 and L',
      'Connect all 25 with no more than 4 errors to clear it; a fifth error ends it at once'
    ]
  },
  'visual_crowding_acuity': {
    zh: [
      '只回答正中间那个字母是什么',
      '两侧的干扰字母会越挤越近，越挤越难认',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'Answer only what the middle letter is',
      'Flanking letters crowd in closer and closer, making it harder to read',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'visual_search': {
    zh: [
      '满屏干扰项里，有一个跟其他都不一样',
      '一眼把它找出来点掉',
      '8 局里找出 6 个以上算通关；每局 8 秒，点错罚 1.2 秒'
    ],
    en: [
      'Among a screenful of distractors, one stands out',
      'Spot it and tap it',
      'Clear at least 6 of 8 rounds; each gives 8 seconds, and a wrong tap costs 1.2'
    ]
  },
  'visual_search_conjunction': {
    zh: [
      '目标要「形状 + 颜色」两个特征同时对上',
      '干扰项各自只占其中一个 —— 所以只看一样会找错',
      '6 局里找对 5 局以上算通关；每局 9 秒，点错罚 1.5 秒'
    ],
    en: [
      'The target must match on BOTH shape and colour',
      'Each distractor matches only one of the two, so watching a single feature misleads you',
      'Clear at least 5 of 6 rounds; each gives 9 seconds, and a wrong tap costs 1.5'
    ]
  },
  'wisconsin_card_sorting': {
    zh: [
      '按一条隐藏的规则把卡片归堆',
      '规则藏在「颜色 / 形状 / 数量」三者之一，参考堆的三个特征正好对应三张卡片',
      '连续答对 4 次之后，规则会悄悄换掉 —— 要跟着改'
    ],
    en: [
      'Sort cards into piles following a hidden rule',
      'The rule is one of colour, shape or number, and the three reference piles each show one of them',
      'After four correct in a row the rule silently changes — you must follow it'
    ]
  },
  'word_pair_associate_memory': {
    zh: [
      '先记住 6 组词对',
      '之后给出一个词，凭记忆选出它的搭档',
      '6 题答对 5 题以上算通关'
    ],
    en: [
      'First memorise six word pairs',
      'Then a word appears, and you pick its partner from memory',
      'Get at least 5 of 6 right to clear it'
    ]
  },
  'affix_factory': {
    zh: [
      '屏幕给出一个词根，还有中文释义',
      '给词根接上正确的词缀（前缀或后缀），造出符合释义的那个单词',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'A root and its Chinese meaning appear',
      'Attach the right affix — prefix or suffix — to build the word that matches the meaning',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'anagram_definition': {
    zh: [
      '屏幕给出一个中文释义',
      '按顺序点字母，把对应的单词拼出来',
      '6 题答对 4 题以上算通关；每题有倒计时，点错罚 3 秒'
    ],
    en: [
      'A Chinese definition appears',
      'Tap the letters in order to spell the matching word',
      'Get at least 4 of 6 right to clear it; each has a timer and a wrong tap costs 3 seconds'
    ]
  },
  'category_fluency': {
    zh: [
      '限时列举同一类别的词',
      '打字输入后回车提交 —— 重复的和词库外的不算分',
      '4 个类别一共列出 8 个有效词以上算通关'
    ],
    en: [
      'List words from a given category before time runs out',
      'Type each one and press enter — duplicates and words outside the list do not count',
      'List at least 8 valid words across 4 categories to clear it'
    ]
  },
  'chalk_and_talk': {
    zh: [
      '双任务：一边判断词语的类别（说出来），一边等光标踩中 ✦ 时落笔（写下来）',
      '说对 +2、说错 −2；写对 +1、写歪 −1',
      '得分 12 以上且成功落笔 3 次以上算通关'
    ],
    en: [
      'Two tasks at once: judging each word’s category (the “talk”), and writing when the cursor crosses the ✦ (the “chalk”)',
      'Right judgment +2, wrong −2; well-placed write +1, mistimed −1',
      'Clear it with a score of at least 12 and at least 3 successful writes'
    ]
  },
  'chimp_test': {
    zh: [
      '数字会出现在不同位置上，你先点 1',
      '点下 1 之后所有数字全部隐藏，但你仍要按升序把它们点完',
      '连过 7 关（数字从 4 个加到 10 个）算通关；点错扣一条命，命尽即失败'
    ],
    en: [
      'Numbers appear scattered around — start by tapping 1',
      'The moment you tap 1 every number is hidden, yet you must still finish them in ascending order',
      'Clear 7 rounds (growing from 4 numbers to 10) to win; a wrong tap costs a life, and losing them all fails you'
    ]
  },
  'cognate_catch': {
    zh: [
      '屏幕给出一对词',
      '判断它们是否同源（是否来自同一个古词根）',
      '12 题答对 8 题以上算通关；每题答完会给一句词源小注'
    ],
    en: [
      'A pair of words appears',
      'Decide whether they are cognates — descended from the same ancient root',
      'Get at least 8 of 12 right to clear it, and each answer comes with a short etymology note'
    ]
  },
  'consonant_reconstruct': {
    zh: [
      '单词里的元音全部被挖成下划线',
      '靠剩下的辅音骨架加上中文提示，把整个词还原出来',
      '6 个词全部还原算通关；答错或跳过扣一条命，命尽即失败'
    ],
    en: [
      'Every vowel in the word is replaced by an underscore',
      'Use the consonant skeleton and the Chinese hint to rebuild the whole word',
      'Restore all 6 words to clear it; a wrong answer or a skip costs a life, and losing them all fails you'
    ]
  },
  'context_clues': {
    zh: [
      '读一句英文例句',
      '从语境推断其中生词的意思，四选一',
      '10 题答对 8 题以上算通关；错 3 次即失败'
    ],
    en: [
      'Read an English example sentence',
      'Infer the meaning of the unfamiliar word from context — four choices',
      'Get at least 8 of 10 right to clear it; three wrong answers and you fail'
    ]
  },
  'conundrum_anagram': {
    zh: [
      '读一则英文谜面，猜出一个单词',
      '卡住可以看字母乱序（anagram）当提示',
      '6 则谜语猜中 5 则以上算通关；错 3 次或一直放弃即失败'
    ],
    en: [
      'Read an English riddle and guess the word it describes',
      'Stuck? Reveal the anagram as a hint',
      'Solve at least 5 of 6 riddles to clear it; three mistakes or giving up repeatedly fails you'
    ]
  },
  'crossword': {
    zh: [
      '5×5 的迷你填字，按线索从词库里挑词',
      '逐个填满每一行',
      '秘密在于：前五个词横着和竖着都成词（词方阵）'
    ],
    en: [
      'A 5×5 mini crossword — pick words from the bank to match the clues',
      'Fill the rows one at a time',
      'The secret: the first five words read as words both across and down, forming a word square'
    ]
  },
  'cryptogram': {
    zh: [
      '整段文字被凯撒位移加密（每个字母平移若干位）',
      '靠已经揭出来的明文映射，把剩下的密文还原',
      '8 关解出 6 关以上算通关；错 3 次即失败；每揭一条「密文→明文」映射扣 30 分'
    ],
    en: [
      'The text is Caesar-shifted — every letter moved along the alphabet by the same amount',
      'Use the plaintext mappings you have already found to decode the rest',
      'Solve at least 6 of 8 rounds to clear it; three mistakes fail you, and each revealed cipher-to-plain pair costs 30 points'
    ]
  },
  'definition_dash': {
    zh: [
      '限时选释义，整局 60 秒',
      '答得越快分越高，答完立刻换下一题',
      '答对 8 题以上算通关；错 3 次或时间耗尽即失败'
    ],
    en: [
      'Pick the right definition against a 60-second clock',
      'The faster you answer the more you score, and the next question comes straight away',
      'Get at least 8 right to clear it; three mistakes or running out of time fails you'
    ]
  },
  'etymology_origin': {
    zh: [
      '屏幕给出一个英语单词',
      '猜它当初借自哪一门语言',
      '60 秒内答对 8 题以上算通关；答错扣 3 秒，错满 4 次判负'
    ],
    en: [
      'An English word appears',
      'Guess which language it was borrowed from',
      'Get at least 8 right within 60 seconds; a wrong answer costs 3 seconds, and four of them fail you'
    ]
  },
  'etymon_oddball': {
    zh: [
      '屏幕给出四个词',
      '挑出那个「词根不属于同一族」的异类',
      '8 轮答对 5 轮以上算通关'
    ],
    en: [
      'Four words appear',
      'Pick the odd one out — the one whose root belongs to a different family',
      'Get at least 5 of 8 rounds right to clear it'
    ]
  },
  'find_word': {
    zh: [
      '6×6 的字母盘里藏着词库中的单词',
      '按顺序连点字母，把它们拼出来',
      '60 秒内找出 5 个以上算通关'
    ],
    en: [
      'Words from the bank are hidden in a 6×6 letter grid',
      'Tap letters in sequence to spell them out',
      'Find at least 5 within 60 seconds to clear it'
    ]
  },
  'grammar_police': {
    zh: [
      '每句里有一个词用错了',
      '把它挑出来；如果这句话本身没错，就点「无错误」',
      '8 题答对 5 题以上算通关；点错罚 3 秒'
    ],
    en: [
      'Each sentence contains one wrongly used word',
      'Pick it out — or tap “no error” if the sentence is actually fine',
      'Get at least 5 of 8 right to clear it; a wrong tap costs 3 seconds'
    ]
  },
  'grammar_sort': {
    zh: [
      '给出一批单词',
      '把它们分进「名词 / 动词 / 形容词 / 副词」四个桶里',
      '16 个词里正确分类 12 个以上算通关'
    ],
    en: [
      'A batch of words appears',
      'Sort each into one of four buckets: noun, verb, adjective or adverb',
      'Classify at least 12 of the 16 correctly to clear it'
    ]
  },
  'letter_bridge': {
    zh: [
      '单词缺了一个字母',
      '从四个候选里把缺的那个补上',
      '8 题答对 5 题以上算通关；点错罚 2 秒'
    ],
    en: [
      'A word is missing one letter',
      'Pick the missing letter from four candidates',
      'Get at least 5 of 8 right to clear it; a wrong tap costs 2 seconds'
    ]
  },
  'letter_cancellation': {
    zh: [
      '字母盘里散布着指定的目标字母',
      '把它们一个个划掉；漏点会扣剩余时间，点错直接罚 3 秒',
      '划满 3 盘算通关'
    ],
    en: [
      'Target letters are scattered through a letter grid',
      'Cross them out one by one; missed ones drain your clock and a wrong tap costs 3 seconds outright',
      'Complete 3 grids to clear it'
    ]
  },
  'letter_frequency_scan': {
    zh: [
      '屏幕上一串字母',
      '数出某个字母在其中出现了几次',
      '8 题答对 5 题以上算通关'
    ],
    en: [
      'A string of letters appears',
      'Count how many times a particular letter occurs in it',
      'Get at least 5 of 8 right to clear it'
    ]
  },
  'letter_grid_swapper': {
    zh: [
      '3×3 的格子里排着一组字母',
      '点两个字母就能交换它们的位置',
      '把每一行都排成目标单词算通关；步数用尽就失败'
    ],
    en: [
      'A 3×3 grid holds a set of letters',
      'Tap two letters to swap their positions',
      'Arrange every row into the target word to clear it; run out of moves and you fail'
    ]
  },
  'missing_vowels': {
    zh: [
      '单词里的元音全部被挖空',
      '按顺序把它们补回去',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Every vowel in the word has been removed',
      'Put them back in the right order',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'one_letter_shift': {
    zh: [
      '两个单词只差一个字母',
      '限时点出需要换掉的那一位',
      '8 题答对 5 题以上算通关'
    ],
    en: [
      'Two words differ by a single letter',
      'Tap the position that needs changing before time runs out',
      'Get at least 5 of 8 right to clear it'
    ]
  },
  'oxymoron_hunt': {
    zh: [
      '屏幕给出四个搭配',
      '挑出那个自相矛盾的（比如「震耳欲聋的沉默」）',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Four phrases appear',
      'Pick the self-contradictory one — like “deafening silence”',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'palindrome_builder': {
    zh: [
      '屏幕给出一组字母',
      '用它们摆出一个回文（正着读和倒着读一样）',
      '6 题解出 4 题以上算通关'
    ],
    en: [
      'A set of letters is given',
      'Arrange them into a palindrome — one that reads the same backwards',
      'Solve at least 4 of 6 to clear it'
    ]
  },
  'pangram_sprint': {
    zh: [
      '一个全字母句被抠掉了几个字母',
      '从 A 到 Z 里挑出缺的那些补回去',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'A pangram has several letters removed',
      'Pick the missing ones from A to Z to restore it',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'portmanteau_split': {
    zh: [
      '屏幕给出一个混合词（比如 brunch）',
      '选出它是由哪两个词拼成的',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'A portmanteau word appears, like brunch',
      'Pick the two words it was blended from',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'rhyme_master': {
    zh: [
      '屏幕给出一个目标词',
      '四选一，挑出跟它押韵的那个词',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'A target word appears',
      'Pick the word among four that rhymes with it',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'semantic_association': {
    zh: [
      '屏幕给出一个线索词',
      '从候选里挑出与它关系最紧密的搭档词',
      '10 题答对 7 题以上算通关'
    ],
    en: [
      'A cue word appears',
      'Pick the candidate most tightly associated with it',
      'Get at least 7 of 10 right to clear it'
    ]
  },
  'semantic_distance': {
    zh: [
      '屏幕给出一个锚点词和两个候选词',
      '判断哪一个离锚点词在意思上更近',
      '10 题答对 7 题以上算通关'
    ],
    en: [
      'An anchor word and two candidates appear',
      'Decide which candidate is closer in meaning to the anchor',
      'Get at least 7 of 10 right to clear it'
    ]
  },
  'semantic_link': {
    zh: [
      '一条语义链一环扣一环',
      '每次挑出能接上下一环的词',
      '把整条 6 词链接通算通关；生命耗尽即失败'
    ],
    en: [
      'A semantic chain runs link by link',
      'Each time pick the word that connects to the next link',
      'Complete the whole six-word chain to clear it; lose all your lives and you fail'
    ]
  },
  'sentence_unscramble': {
    zh: [
      '6 个单词被打乱了顺序',
      '按正确的语序把它们一个个点回去',
      '5 句答对 4 句以上算通关；错 3 次就失败'
    ],
    en: [
      'Six words arrive in scrambled order',
      'Tap them back into the correct sentence order',
      'Get at least 4 of 5 sentences right to clear it; three mistakes and you fail'
    ]
  },
  'silent_letter_search': {
    zh: [
      '一个字母格里藏着一个不发音的字母',
      '把那个不发音的字母点出来',
      '10 题答对 7 题以上算通关；错 3 次就失败'
    ],
    en: [
      'A silent letter hides somewhere in a grid of letters',
      'Tap the letter that is not pronounced',
      'Get at least 7 of 10 right to clear it; three mistakes and you fail'
    ]
  },
  'spelling_sprint': {
    zh: [
      '看着中文释义',
      '在 60 秒内把对应的英文单词敲出来',
      '答对 8 题以上算通关；超时或错满 3 次就失败'
    ],
    en: [
      'A Chinese definition appears',
      'Type out the matching English word within 60 seconds',
      'Get at least 8 right to clear it; running out of time or three mistakes fails you'
    ]
  },
  'spoonerism_solver': {
    zh: [
      '首音互换（Spoonerism）：把两个词的开头辅音对调',
      '挑出互换之后得到的那一对词',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'A spoonerism swaps the opening sounds of two words',
      'Pick the pair you get after the swap',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'story_builder': {
    zh: [
      '几个句子被打乱，讲的是同一件事',
      '按「事情发生的先后」一段段接回完整故事',
      '接完 3 段故事算通关；错接 3 次就失败'
    ],
    en: [
      'Several sentences from one story arrive out of order',
      'Reorder them by when things happened to rebuild the whole story',
      'Assemble 3 stories to clear it; three wrong connections and you fail'
    ]
  },
  'syllable_stack': {
    zh: [
      '屏幕给出中文提示和一组打乱的音节',
      '把音节按正确顺序叠起来，拼成一个英文单词',
      '6 个词全部叠对算通关；错叠 3 次就失败'
    ],
    en: [
      'A Chinese hint and a set of shuffled syllables appear',
      'Stack the syllables in the right order to build the English word',
      'Build all 6 words correctly to clear it; three wrong stacks and you fail'
    ]
  },
  'typing_speed': {
    zh: [
      '屏幕上一句话，照着它打一遍',
      '系统会实时统计你的 WPM（每分钟词数）和正确率',
      '5 句都在 25 秒内打完、且正确率 90% 以上算通关'
    ],
    en: [
      'A sentence appears — type it out exactly',
      'Your words per minute and accuracy are tracked live',
      'Finish all 5 sentences within 25 seconds each at 90% accuracy or better to clear it'
    ]
  },
  'verbal_analogies': {
    zh: [
      '题目是「A 比 B，等于 C 比 ?」',
      '从四个候选里挑出关系对得上的那个',
      '8 题答对 6 题以上算通关；答错 3 次就失败'
    ],
    en: [
      'The prompt reads “A is to B as C is to ?”',
      'Pick the candidate that completes the relationship',
      'Get at least 6 of 8 right to clear it; three wrong answers and you fail'
    ]
  },
  'vocabulary_builder': {
    zh: [
      '给出中文释义和词性',
      '在同一个词根的派生词里挑出对的那个（要辨析前缀/后缀）',
      '8 题答对 6 题以上算通关；答错 3 次就失败'
    ],
    en: [
      'A Chinese definition and part of speech appear',
      'Pick the right derivative of the same root — you must tell the prefixes and suffixes apart',
      'Get at least 6 of 8 right to clear it; three wrong answers and you fail'
    ]
  },
  'vowel_reconstruct': {
    zh: [
      '单词里的元音在 AEIOU 里被整体挪了若干格',
      '点亮元音，把它一格一格转回正确的位置',
      '题数按难度（简单 4 / 普通 6 / 困难 8），还原到通关线（3 / 5 / 7）个算通关'
    ],
    en: [
      'Every vowel has been rotated a fixed number of places around AEIOU',
      'Tap a vowel to turn it back one step at a time',
      'Rounds depend on difficulty (4 easy, 6 normal, 8 hard); restore the pass line of 3, 5 or 7 to clear it'
    ]
  },
  'word_association_recall': {
    zh: [
      '先记住 6 组「词 — 关联词」',
      '之后凭记忆把每个词和它的关联词配回来',
      '6 题里回忆对 4 题以上算通关'
    ],
    en: [
      'First memorise six word-and-associate pairs',
      'Then pair each word back with its associate from memory',
      'Recall at least 4 of 6 correctly to clear it'
    ]
  },
  'word_grid_connection': {
    zh: [
      '4×4 的词格里散布着若干词',
      '点两个意思相近的词，把它们连成一对',
      '连完 8 对算通关；连错 5 次就失败'
    ],
    en: [
      'Words are scattered through a 4×4 grid',
      'Tap two words with similar meaning to link them into a pair',
      'Link all 8 pairs to clear it; five wrong links and you fail'
    ]
  },
  'word_ladder': {
    zh: [
      '从起点词走到目标词',
      '每步只能换一个字母，而且换完必须是词库里的真实单词',
      '在步数上限内到达目标词算通关；步数用尽还没到就失败'
    ],
    en: [
      'Travel from the start word to the target word',
      'Each step changes exactly one letter, and the result must be a real word',
      'Reach the target within the move limit to clear it; run out of moves and you fail'
    ]
  },
  'word_ladder_step': {
    zh: [
      '每题给出四个候选词',
      '挑出那个「只改一个字母、而且本身是真实单词」的',
      '10 题内生命不耗尽算通关；生命耗尽就失败'
    ],
    en: [
      'Four candidate words appear',
      'Pick the one that differs by a single letter and is itself a real word',
      'Survive 10 questions without losing your lives to clear it'
    ]
  },
  'word_mastermind': {
    zh: [
      '一个 5 字母的单词藏着，你要猜出来',
      '每次猜完逐格给反馈：位置对 / 字母在但位置不对 / 都没有',
      '7 次之内猜中算通关；次数用完还没中就失败'
    ],
    en: [
      'A five-letter word is hidden and you must guess it',
      'After each guess every cell reports: right spot, right letter wrong spot, or absent',
      'Guess it within 7 tries to clear it; run out and you fail'
    ]
  },
  'word_scramble': {
    zh: [
      '字母被打乱了，中文释义给出线索',
      '把字母按正确顺序点回去，拼成单词',
      '150 秒内拼对 8 个词算通关；超时就失败'
    ],
    en: [
      'The letters are scrambled and a Chinese definition gives the clue',
      'Tap the letters back in order to spell the word',
      'Build 8 words correctly within 150 seconds to clear it'
    ]
  },
  'word_search': {
    zh: [
      '8×8 的字母阵里藏着 4 个单词',
      '点每个词的首尾两格，把它圈出来',
      '90 秒内找齐 4 个算通关；超时就失败'
    ],
    en: [
      'Four words hide in an 8×8 letter grid',
      'Tap the first and last cell of each word to circle it',
      'Find all 4 within 90 seconds to clear it'
    ]
  },
  'word_snake_trail': {
    zh: [
      '用方向键操纵小蛇在格子里移动',
      '按顺序去吃字母，拼出目标单词',
      '拼完 3 个词算通关；生命用完（吃错/撞墙/咬自己）就失败'
    ],
    en: [
      'Steer a snake around the grid with the arrow keys',
      'Eat the letters in the right order to spell the target word',
      'Spell 3 words to clear it; losing all lives — wrong letter, wall or your own tail — fails you'
    ]
  },
  'word_surge': {
    zh: [
      '60 秒内按中文释义抢答英文单词',
      '答得越快、连击越长，分越高',
      '答对 12 个算通关；时间耗尽就失败'
    ],
    en: [
      'Answer English words from their Chinese definitions for 60 seconds',
      'The faster you answer and the longer your streak, the higher you score',
      'Get 12 right to clear it; running out of time fails you'
    ]
  },
  'word_wheel': {
    zh: [
      '从 6 个字母里拼出英文单词',
      '每个字母在每一轮里只能用一次',
      '找齐 5 个词算通关；拼错 3 次就失败'
    ],
    en: [
      'Build English words from six letters',
      'Each letter may be used only once per round',
      'Find all 5 words to clear it; three wrong attempts and you fail'
    ]
  },
  'ab_reversal_oddball': {
    zh: [
      '圆和菱形会交替出现，偶尔会连续两次相同 —— 那就是「反转」',
      '看到反转立刻点「反转！」；正常交替时不要点（点了算误报）',
      '24 帧内命中 5 次以上、且误报不超过 2 次算通关'
    ],
    en: [
      'Circles and diamonds alternate, and now and then the same one appears twice in a row — that is the reversal',
      'Tap “reversal!” the moment you spot one; on normal alternation do not tap — tapping then counts as a false alarm',
      'Clear it with at least 5 hits across 24 frames and no more than 2 false alarms'
    ]
  },
  'angle_finder': {
    zh: [
      '题目给一个多边形，其中几个角的度数已知',
      '用内角和公式 (n−2)×180° 减去已知角，求出最后一个角',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'A polygon appears with several of its angles given',
      'Use the interior-sum formula (n−2)×180° and subtract the known angles to find the last one',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'area_perimeter_match': {
    zh: [
      '屏幕上有两个矩形，长宽按真实比例画出，可以直接目测',
      '题目随机问比面积（长×宽）还是比周长（2×(长+宽)）',
      '10 题答对 7 题以上算通关'
    ],
    en: [
      'Two rectangles are drawn to true scale, so you can judge by eye',
      'The prompt randomly asks you to compare areas (length × width) or perimeters (2 × (length + width))',
      'Get at least 7 of 10 right to clear it'
    ]
  },
  'block_count_3d': {
    zh: [
      '3×3 的底座上叠着高度不等的方块塔',
      '数出一共有多少块 —— 每根塔的高度相加就是总数',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'Towers of different heights stand on a 3×3 base',
      'Count how many blocks there are in all — add up the height of every tower',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'box_completion': {
    zh: [
      '盘上零散分布着一些格子，其中恰好 12 格能拼成一个矩形的边框',
      '点亮空格把边框补齐',
      '恰好点亮 12 格、而且全落在同一个矩形边框上算通关；超过 12 格就失败'
    ],
    en: [
      'Scattered cells sit on the board, and exactly 12 of them outline one rectangle',
      'Light up cells to complete that outline',
      'Clear it by lighting exactly 12 cells all on one rectangle’s border; going past 12 fails you'
    ]
  },
  'circuit_connect': {
    zh: [
      '4×4 的元件盘，点一下就把该元件顺时针转 90°',
      '电源从左上角的左边进入，目标是让电流通到右下角那一格',
      '电流通到右下角、并且朝右出去算通关；步数用尽还没接通就失败'
    ],
    en: [
      'A 4×4 component board — each tap rotates that component 90° clockwise',
      'Power enters from the left edge of the top-left cell; your goal is to carry it to the bottom-right cell',
      'Clear it when current reaches the bottom-right cell and exits rightward; run out of moves and you fail'
    ]
  },
  'classic_maze': {
    zh: [
      '9×9 的迷宫，只有唯一一条通路',
      '滑动屏幕或用方向键走球，撞墙就不动',
      '走到右下角的出口算通关；步数超过上限就失败'
    ],
    en: [
      'A 9×9 maze with exactly one path through',
      'Swipe or use the arrow keys to move the ball; walking into a wall leaves you in place',
      'Reach the exit in the bottom-right corner to clear it; exceeding the move limit fails you'
    ]
  },
  'color_maze_nav': {
    zh: [
      '6×6 的彩砖盘，起点随机',
      '只能走进「与脚下同色」的上下左右相邻砖 —— 每走一步，颜色基准就换成新踩的那块',
      '踩到终点 🏁 算通关；步数超过上限就失败'
    ],
    en: [
      'A 6×6 board of coloured tiles, with a random start',
      'You may only step onto a neighbouring tile of the SAME colour as the one you stand on, and the colour baseline changes with every step',
      'Reach the 🏁 exit to clear it; exceeding the move limit fails you'
    ]
  },
  'compass_maze': {
    zh: [
      '7×7 的迷宫，保证有路可走',
      '底部是一条指南针指令带：点「走一步」就按当前指令的方向走，撞墙也会白扣一步',
      '点 ⇄ 可以反转整条指令带（用来排错，不扣步数）；走到右下角出口算通关，步数用尽就失败'
    ],
    en: [
      'A 7×7 maze that is guaranteed solvable',
      'A compass ribbon runs along the bottom: tap “step” to move in the direction it currently shows, and a wall still costs you the step',
      'Tap ⇄ to reverse the whole ribbon (for untangling it — costs no steps); reach the bottom-right exit to clear it, or run out of steps and fail'
    ]
  },
  'cube_net_fold': {
    zh: [
      '一个立方体的展开图，六个面两两成对',
      '点格子循环切换 A / B / C，把配对的字母放进正确的格子里',
      '全部放对算过关；6 关过 4 关以上算通关'
    ],
    en: [
      'A cube is unfolded flat, with its six faces paired up',
      'Tap a cell to cycle its letter between A, B and C, placing matching letters in the right cells',
      'Get every placement right to pass a round; clear 4 of 6 rounds to win overall'
    ]
  },
  'gear_rotation': {
    zh: [
      'A 是主动轮，转向已经给出；B 是你要判断的那个轮',
      '看 A 和 B 之间是「啮合」（齿轮直接咬合）还是「皮带相连」',
      '口诀：啮合反向、皮带同向；8 题全过算通关，答错 3 题就失败'
    ],
    en: [
      'Gear A is the driver and its direction is given; B is the one you must judge',
      'Check whether A and B are meshed directly or joined by a belt',
      'The rule: meshed turns opposite, belted turns the same way; clear all 8 to win, three wrong answers and you fail'
    ]
  },
  'grid_displacement': {
    zh: [
      '屏幕给出一个起点和一串位移指令（上/下/左/右各几步）',
      '在脑子里执行这串指令，算出最后落在哪一格',
      '点出那个格子；6 题答对 4 题以上算通关'
    ],
    en: [
      'A starting cell and a series of displacement steps appear — so many up, down, left or right',
      'Run those steps through your head to work out the final cell',
      'Tap that cell; get at least 4 of 6 right to clear it'
    ]
  },
  'hue_sort': {
    zh: [
      '16 个色块被打乱排在一格里',
      '点两个格子就能交换它们的位置',
      '在步数上限内把色块按色相排成一道严格递增的彩虹算通关（简单 27 步 / 普通 18 / 困难 15）'
    ],
    en: [
      'Sixteen colour tiles sit scrambled in a grid',
      'Tap two cells to swap their contents',
      'Arrange them into a strictly ascending rainbow within the move limit (27 easy, 18 normal, 15 hard) to clear it'
    ]
  },
  'interlock_puzzle': {
    zh: [
      '几块卡榫互相咬住，压在一起',
      '只能先抽出「没有被别人压着」的那一块',
      '在步数预算内全部抽出来算通关（简单 12 步 / 普通 8 / 困难 6）'
    ],
    en: [
      'Several interlocking parts are wedged together',
      'You may only pull out a part that nothing else is pressing on',
      'Extract every part within the move budget to clear it (12 easy, 8 normal, 6 hard)'
    ]
  },
  'laser_link': {
    zh: [
      '棋盘上摆着镜子和两束激光',
      '点镜子让它旋转，把激光折进各自的探头（／ 右→上、上→右；＼ 右→下、下→右）',
      '14 步内点亮全部探头算通关'
    ],
    en: [
      'Mirrors and two laser beams sit on the board',
      'Tap a mirror to rotate it and steer each beam into its own receiver (／ turns right to up and up to right; ＼ turns right to down and down to right)',
      'Light every receiver within 14 moves to clear it'
    ]
  },
  'laser_reflect': {
    zh: [
      '这一版光路更长更绕，需要用六块镜子导两束光',
      '点镜子旋转，把两束激光都折进探头',
      '18 步内点亮全部探头算通关'
    ],
    en: [
      'This version has longer, twistier paths — six mirrors steer two beams',
      'Tap mirrors to rotate them and bend both beams into their receivers',
      'Light every receiver within 18 moves to clear it'
    ]
  },
  'mental_mapping': {
    zh: [
      '屏幕先亮出几个地点（emoji）在九宫格上的位置，记住后它们会隐去',
      '然后题目会问「从 A 走到 B 要往哪个方向」',
      '凭记忆点出那个方向'
    ],
    en: [
      'Several landmarks light up on a 3×3 grid — memorise where, then they vanish',
      'You are then asked which direction it is from A to B',
      'Tap that direction from memory'
    ]
  },
  'mental_rotation': {
    zh: [
      '左边是一组图形，右边是另一组',
      '判断右边那组是左边的「纯旋转」，还是被偷偷镜像过了',
      '10 题答对 8 题以上算通关'
    ],
    en: [
      'A shape sits on the left, another on the right',
      'Decide whether the right one is a pure rotation of the left, or has been secretly mirrored',
      'Get at least 8 of 10 right to clear it'
    ]
  },
  'mirror_image': {
    zh: [
      '左边一个图形，右边一个图形',
      '判断右边是不是左边沿中轴翻转出来的真镜像',
      '10 题答对 8 题以上算通关'
    ],
    en: [
      'One shape on the left, one on the right',
      'Decide whether the right one is a true mirror image of the left, flipped across the axis',
      'Get at least 8 of 10 right to clear it'
    ]
  },
  'mirror_maze': {
    zh: [
      '屏幕是镜中的世界 —— 世界左右颠倒',
      '所以按「左」其实会往右走，「右」其实往左',
      '走到 🏁 算通关；步数耗尽就失败'
    ],
    en: [
      'The screen shows a mirrored world — left and right are swapped',
      'So pressing “left” actually goes right, and “right” goes left',
      'Reach the 🏁 to clear it; run out of steps and you fail'
    ]
  },
  'mirror_tracing': {
    zh: [
      '你在一面镜子上描线 —— 点左边，画出来的却在右边',
      '沿着目标形状一点点描过去',
      '3 关全部画完算通关；笔数耗尽就失败（可以「擦掉」反悔）'
    ],
    en: [
      'You are tracing on a mirror — tap on the left and the line appears on the right',
      'Trace your way around the target shape',
      'Complete all 3 rounds to clear it; run out of strokes and you fail (you can erase to undo)'
    ]
  },
  'navon_hierarchical': {
    zh: [
      '一张图里，大图形是一个字母，而构成它的小图形又是另一个字母',
      '每题两问都要答：大图是什么？小图是什么？',
      '12 题里每题两问全对才算这一题得分；答对 8 题以上算通关'
    ],
    en: [
      'In one image the large shape is one letter, while the small shapes composing it spell another',
      'Each question asks both: what is the big letter, and what is the small one?',
      'A question only scores if both answers are right; score 8 of 12 to clear it'
    ]
  },
  'odd_one_out': {
    zh: [
      '一格里密密麻麻排着一堆相同字符',
      '其中混进了一个「不一样的字符」',
      '把它点出来；10 题答对 8 题以上算通关'
    ],
    en: [
      'A grid is packed with identical characters',
      'One different character is hidden among them',
      'Tap it out; get at least 8 of 10 right to clear it'
    ]
  },
  'paper_folding': {
    zh: [
      '纸被对折了两次，所以你看到的是左上角那四分之一',
      '在折好的纸上打孔',
      '展开后孔会镜像成四份；与目标图案完全一致算通关，步数用尽还没对上就失败'
    ],
    en: [
      'The paper is folded twice, so you only see the top-left quarter',
      'Punch holes into the folded paper',
      'When unfolded each hole mirrors into four — match the target exactly to clear it, or run out of moves and fail'
    ]
  },
  'perspective_taking': {
    zh: [
      '房间里站着一位观察者，箭头表示他面朝的方向',
      '要按他看到的方位来选，不是按你的',
      '选出他视野里对应的那个物品；8 题答对 6 题以上算通关'
    ],
    en: [
      'An observer stands in the room, with an arrow showing which way he faces',
      'Answer from HIS point of view, not yours',
      'Pick the object in his view; get at least 6 of 8 right to clear it'
    ]
  },
  'pixel_mimic': {
    zh: [
      '左边是一张目标像素图',
      '在右边点格子，画出一样的图案（再点一次可以擦掉）',
      '64 格全部对上算通关；步数用尽还没画对就失败'
    ],
    en: [
      'A target pixel image sits on the left',
      'Tap cells on the right to reproduce it — tapping again erases',
      'Match all 64 cells to clear it; run out of moves before you do and you fail'
    ]
  },
  'polyomino_tiling': {
    zh: [
      '挑一块骨牌，再点棋盘把它放下（点已经铺好的格子能拿起来）',
      '灰色的格子是墙，放不了',
      '把所有空格都铺满算通关；步数用尽还没铺满就失败'
    ],
    en: [
      'Pick a polyomino and tap the board to place it; tapping a placed piece picks it back up',
      'Grey cells are walls and cannot be used',
      'Cover every empty cell to clear it; run out of moves before that and you fail'
    ]
  },
  'shadow_pivot': {
    zh: [
      '给出一个原形，以及光源转过的角度',
      '从 4 张剪影里挑出「正好转过这个角度」的那一张',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'An original shape is shown, along with the angle the light source has turned',
      'Pick the shadow among four that shows exactly that rotation',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'shape_shifter': {
    zh: [
      '依次给出 4 个方格图',
      '找出它们之间的变换规律（每步转 90°？右移一格？多长一格？）',
      '挑出第 5 个；6 题答对 4 题以上算通关'
    ],
    en: [
      'Four grid figures appear in sequence',
      'Work out the transformation between them — each step rotates 90°, shifts right one, or grows by one?',
      'Pick the fifth; get at least 4 of 6 right to clear it'
    ]
  },
  'silhouette_match': {
    zh: [
      '积木的颜色和花纹都不算数',
      '剪影只看轮廓 —— 挑出轮廓完全相同的那一张（转过的不算）',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Colour and pattern do not count here',
      'Only the outline matters — pick the silhouette whose shape matches exactly (a rotated one does not count)',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'symmetry': {
    zh: [
      '屏幕上一个 4×4 的图案',
      '判断它关于哪一条轴对称',
      '每题正确答案只有一条；8 题答对 6 题以上算通关'
    ],
    en: [
      'A 4×4 pattern appears',
      'Decide which axis it is symmetrical about',
      'Each question has exactly one right answer; get at least 6 of 8 right to clear it'
    ]
  },
  'tangram': {
    zh: [
      '用 4 块砖把阴影严丝合缝地铺满',
      '点已经铺好的砖可以把它取回来重放',
      '铺满算通关；12 次机会用完还没铺满就失败'
    ],
    en: [
      'Fit four tiles into the silhouette with no gaps',
      'Tap a placed tile to take it back and reposition it',
      'Cover it completely to clear it; run out of your 12 attempts and you fail'
    ]
  },
  'topology': {
    zh: [
      '不看形状，只看「洞」',
      '两张图的洞数相同，就是拓扑等价（可以互相拉伸变过去）',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'Ignore the shape and count the holes',
      'Two figures with the same number of holes are topologically equivalent — one can be stretched into the other',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'tower_of_hanoi': {
    zh: [
      '把整摞盘子从最左边的柱子搬到最右边那根',
      '大盘不能压在小盘上面，一次只能搬一个',
      '搬完算通关；40 步还搬不完就失败'
    ],
    en: [
      'Move the whole stack of discs from the leftmost peg to the rightmost one',
      'A larger disc may never sit on a smaller one, and you move one at a time',
      'Finish the move to clear it; if 40 steps are not enough, you fail'
    ]
  },
  'tower_of_london': {
    zh: [
      '一次搬一个球，而且大球不许压小球',
      '把三个球摆成目标的样子',
      '摆成算通关；步数超过「最少步数 + 5」就失败'
    ],
    en: [
      'Move one ball at a time, and a larger ball may never sit on a smaller one',
      'Arrange the three balls to match the goal',
      'Match it to clear it; exceed the minimum number of moves plus 5 and you fail'
    ]
  },
  'trace_path': {
    zh: [
      '先看一遍亮起的路线，然后它会灭掉',
      '从 🚩 出发，按原来的路线一格一格点下去；点错就断线重来',
      '3 条路线全部描完算通关；断线 4 次就失败'
    ],
    en: [
      'Watch a route light up once, then it goes dark',
      'Starting from the 🚩, tap the route back cell by cell; a wrong tap breaks the line and restarts it',
      'Trace all 3 routes to clear it; four breaks and you fail'
    ]
  },
  'action_sequence_recall': {
    zh: [
      '屏幕上一个机器人依次做几个动作',
      '看清顺序，然后按同样的顺序把动作点一遍',
      '6 关全过算通关；错 3 次就失败'
    ],
    en: [
      'A robot performs a few actions in sequence',
      'Watch the order, then tap those same actions back in that order',
      'Clear all 6 rounds to win; three mistakes and you fail'
    ]
  },
  'binary_matrix_rank_all': {
    zh: [
      '一个 6×6 的 0/1 矩阵',
      '点一行选中、再点另一行，就把后者异或上前者（秩不变；同样两行再点一遍即复原）',
      '用这个办法算出矩阵在模 2 下的秩；6 题答对 4 题以上算通关'
    ],
    en: [
      'A 6×6 matrix of zeros and ones',
      'Tap one row to select it, then another to XOR it into that one — the rank is unchanged, and repeating the same two rows restores it',
      'Use that to find the matrix rank over GF(2); get at least 4 of 6 right to clear it'
    ]
  },
  'block_stacking_physics': {
    zh: [
      '三根柱子，各有自己的内宽和限高',
      '方块的宽度必须与柱子的内宽完全相等才塞得进 —— 不许悬空压边',
      '把清单上的方块全部放完算通关；某一根柱超高失衡就失败'
    ],
    en: [
      'Three columns, each with its own inner width and height limit',
      'A block only fits where its width exactly matches the column’s inner width — no overhanging edges',
      'Place every block on the list to clear it; if any column is overloaded and topples, you fail'
    ]
  },
  'chain_reaction': {
    zh: [
      '棋盘每格有自己的容量（等于它的邻居数）',
      '点一下给某格加一个光点；一旦超过容量就「炸」—— 那格清空，四邻各 +1，可以连锁下去',
      '一次点击让全盘每一格都炸开算通关；步数用尽就失败'
    ],
    en: [
      'Each cell has a capacity equal to its number of neighbours',
      'A tap adds one light to that cell; once it exceeds capacity it bursts — the cell empties and each neighbour gains one, which can chain',
      'Clear it with a single tap that sets the whole board bursting; run out of moves and you fail'
    ]
  },
  'color_match': {
    zh: [
      '5×5 的彩盘',
      '点中的格子如果和四邻有同色，就连同那一整片同色一起消掉',
      '消完会塌落、空列左移、顶部补新色；在步数内达到目标分算通关'
    ],
    en: [
      'A 5×5 board of colours',
      'If the tapped cell touches a neighbour of the same colour, that whole connected patch clears together',
      'The rest collapses, empty columns shift left and new colours drop in; hit the target score within the move limit to clear it'
    ]
  },
  'complex_folding_nets': {
    zh: [
      '一条纸条沿标线依次对折（折痕可能在中间或四分之一处）',
      '每一次对折都会让纸层叠起来',
      '问标记处一共叠了几层；8 题答对 6 题以上算通关'
    ],
    en: [
      'A strip of paper is folded along marked lines one after another, at the middle or the quarter mark',
      'Each fold doubles up the layers of paper',
      'Say how many layers sit at the marked point; get at least 6 of 8 right to clear it'
    ]
  },
  'counting_sheep': {
    zh: [
      '狼披着羊皮混进了羊圈：一只羊 🐑 占 1 格，一头狼 🐺 占 2 格',
      '题型一「按格数」：一共占了几格；题型二「按只数」：真正的羊有几只',
      '10 题答对 7 题以上算通关'
    ],
    en: [
      'Wolves are hiding among the sheep: each sheep 🐑 takes one cell, each wolf 🐺 takes two',
      'One question type asks how many cells are occupied; the other asks how many actual sheep there are',
      'Get at least 7 of 10 right to clear it'
    ]
  },
  'cross_section_slice': {
    zh: [
      '5×5×5 的方块堆，只画出第 h 层的平面图（黑格有方块、灰格是空的）',
      '要靠这张平面图逆推这一层一共有几个方块',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'A 5×5×5 stack of blocks, with only layer h drawn as a plan view (black cells hold blocks, grey are empty)',
      'Deduce from that plan how many blocks are on this layer',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'cryptogram_all': {
    zh: [
      '一段凯撒移位密文 —— 每个字母都被整体平移了 k 位',
      '密钥只露出其中几位，其余要靠四个候选词反推',
      '推出原词；8 题答对 6 题以上算通关'
    ],
    en: [
      'A Caesar-shifted ciphertext where every letter has been moved by k places',
      'Only a few key letters are revealed — recover the rest by working back from four candidate words',
      'Recover the original word; get at least 6 of 8 right to clear it'
    ]
  },
  'directions_recall': {
    zh: [
      '一串箭头依次闪出',
      '凭记忆按原来的顺序把它们点回来',
      '共 5 关，长度从 3 加到 7；点错本关就失败，自动进下一关（回放不扣分）'
    ],
    en: [
      'A string of arrows flashes past in order',
      'Tap them back in the original order from memory',
      'Five rounds growing from 3 arrows to 7; a wrong tap fails that round and moves you on (replays cost nothing)'
    ]
  },
  'distractor_matrix': {
    zh: [
      '4×4 的符号矩阵里混着两种符号',
      '要在限时内数出目标那一种的个数',
      '干扰项会越来越多；8 题答对 6 题以上算通关'
    ],
    en: [
      'Two kinds of symbol are mixed in a 4×4 matrix',
      'Count how many of the target kind there are, against the clock',
      'Distractors increase as you go; get at least 6 of 8 right to clear it'
    ]
  },
  'einstein_riddle': {
    zh: [
      '三栋排屋、三种宠物，谜面给出若干线索',
      '所有线索合起来只能推出唯一答案',
      '点格子循环切换宠物（🐱🐟🐦，不能重复）；三项都填对算通关'
    ],
    en: [
      'Three houses in a row and three pets, with a handful of clues',
      'Together the clues admit exactly one arrangement',
      'Tap a cell to cycle its pet (🐱🐟🐦, no repeats); fill all three correctly to clear it'
    ]
  },
  'fact_binder': {
    zh: [
      '左栏 5 条事实，右栏 5 个答案（已经打乱）',
      '左右各点一个就完成一次配对，配对正确会变绿',
      '5 组全部绑定算通关；失误满 3 次就失败'
    ],
    en: [
      'Five facts on the left, their five answers shuffled on the right',
      'Tap one on each side to bind them; a correct pairing turns green',
      'Bind all 5 pairs to clear it; three mistakes and you fail'
    ]
  },
  'gear_train_direction': {
    zh: [
      '一串齿轮首尾相接',
      '看每个连接处是啮合（反向）还是皮带（同向）',
      '一段段推理下去，判断末端那个齿轮的转向；8 题全过算通关，答错 3 题就失败'
    ],
    en: [
      'A train of gears joins end to end',
      'Check whether each link is meshed (reverses) or belted (same direction)',
      'Reason along the chain to the last gear’s direction; clear all 8 to win, three wrong answers and you fail'
    ]
  },
  'geometric_vision': {
    zh: [
      'A、B 两块图形，各自由 12 个小方格里的若干格拼成',
      '比一比哪一块占的格子更多',
      '10 题全过算通关；答错 3 题就失败'
    ],
    en: [
      'Two shapes A and B, each assembled from some of the cells in a 12-cell grid',
      'Decide which one covers more cells',
      'Clear all 10 to win; three wrong answers and you fail'
    ]
  },
  'graph_coordinate_plot': {
    zh: [
      '网格是一张 5×5 的画布',
      '按给出的坐标顺序依次点格子',
      '8 个点全部按顺序点亮，会围出一个菱形；全部点上算通关，点错 3 次就失败'
    ],
    en: [
      'The grid is a 5×5 canvas',
      'Tap the cells in the coordinate order given',
      'Light all 8 in sequence and a diamond takes shape; plot them all to clear it, three wrong taps and you fail'
    ]
  },
  'gravity_sort': {
    zh: [
      '点一列，整列会按重力塌落下来',
      '同色叠在一起就会被消掉',
      '22 步内清空棋盘算通关'
    ],
    en: [
      'Tap a column and it collapses under gravity',
      'Same colours landing together are cleared away',
      'Empty the board within 22 moves to clear it'
    ]
  },
  'logical_syllogisms': {
    zh: [
      '给出两个前提和一个结论',
      '判断这个推理是否站得住（结论是不是真的能从前提推出来）',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Two premises and a conclusion are given',
      'Decide whether the reasoning holds — does the conclusion really follow from the premises?',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'maze_nav_3d': {
    zh: [
      '一个 5×5×3 的立体迷宫',
      '用方向键在水平面上移动，用 ↑↓ 按钮换一层',
      '从起点走到终点算通关；步数越少分越高'
    ],
    en: [
      'A 5×5×3 three-dimensional maze',
      'Use the arrow keys to move within a level and the ↑↓ buttons to change floors',
      'Get from start to finish to clear it; fewer steps scores higher'
    ]
  },
  'multi_track_counter': {
    zh: [
      '三条轨道上各有东西在持续增加',
      '你不能一条条数完 —— 要凭眼力同时跟住三路，报出总数',
      '3 轮，每轮速度 +1；误差不超过 2 算通关'
    ],
    en: [
      'Things keep growing along three separate tracks',
      'You cannot count them one by one — track all three at once and report the total',
      'Three rounds, each a little faster; finish within an error of 2 to clear it'
    ]
  },
  'odd_rotation': {
    zh: [
      '一格里排着一堆相同图形',
      '其中只有一个转了 90°，其余都停在同一角度',
      '把转过的那个点出来；10 题答对 8 题以上算通关'
    ],
    en: [
      'A grid is filled with identical shapes',
      'Exactly one of them is rotated 90° while the rest sit at the same angle',
      'Tap the rotated one; get at least 8 of 10 right to clear it'
    ]
  },
  'path_recall': {
    zh: [
      '格子会依次亮起，连成一条路径',
      '看完之后，按同样的顺序把这条路径点出来',
      '连过 6 轮（路径从 3 格加到 8 格）算通关；点错一格就失败'
    ],
    en: [
      'Cells light up one after another, tracing a path',
      'Afterwards, tap that path back in the same order',
      'Clear 6 rounds (paths growing from 3 cells to 8) to win; one wrong cell and you fail'
    ]
  },
  'perspective_shift_view': {
    zh: [
      '给一张俯视图，以及一个观察方向',
      '选出「从那一侧看过去」会看到的排列',
      '8 题答对 6 题以上算通关'
    ],
    en: [
      'A top-down view is shown along with a viewing direction',
      'Pick the arrangement you would see looking in from that side',
      'Get at least 6 of 8 right to clear it'
    ]
  },
  'room_inspector': {
    zh: [
      '屏幕上下各有一间房间',
      '下面那间有 3 处摆设和上面不一样',
      '把 3 处都点出来算通关；错点 3 次或超过 60 秒就失败'
    ],
    en: [
      'Two rooms are shown, one above the other',
      'The lower room has 3 items arranged differently',
      'Spot all 3 to clear it; three wrong taps or more than 60 seconds and you fail'
    ]
  },
  'rotating_maze': {
    zh: [
      '7×7 的迷宫，但你每走 2 步，整个迷宫会顺时针转 90°',
      '所以刚记住的路会在脚下转走',
      '走到出口 🏁 算通关；步数用尽就失败'
    ],
    en: [
      'A 7×7 maze — but every 2 steps the whole maze rotates 90° clockwise',
      'So the route you just memorised turns away beneath you',
      'Reach the 🏁 exit to clear it; run out of steps and you fail'
    ]
  },
  'silhouette_match_ortho': {
    zh: [
      '三层 3×3 的方块叠在一起',
      '从正上方看下去（正投影）会得到哪个剪影？只要那一格有方块就算',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Three 3×3 layers of blocks are stacked',
      'Which silhouette do you get looking straight down from above? A cell counts if any layer has a block there',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'simon_command': {
    zh: [
      '屏幕陆续给出指令',
      '只有以「西蒙说」开头的才照做；没有这句话就必须点「不做动作 ✋」',
      '每题限时 2.2 秒；答对 10 题算通关，失误 3 次就失败'
    ],
    en: [
      'Instructions appear one after another',
      'Obey only those starting with “Simon says”; if it is absent you must tap “do nothing ✋”',
      'Each has a 2.2-second limit; get 10 right to clear it, three mistakes and you fail'
    ]
  },
  'simon_sequence': {
    zh: [
      '6 个数字格会按顺序亮起',
      '照着亮起的顺序点回去',
      '每过一关序列就加长一位；长度撑到 8 算通关，点错就失败'
    ],
    en: [
      'Six numbered cells light up in sequence',
      'Tap them back in the order they lit',
      'Each round adds one more step; reach a length of 8 to clear it, one wrong tap and you fail'
    ]
  },
  'source_monitoring': {
    zh: [
      '先记住 5 条消息各自是谁说的（限时 8 秒）',
      '之后逐条给出消息，问你「这话是谁说的」',
      '5 题答对 4 题以上算通关'
    ],
    en: [
      'Memorise who said each of 5 messages, in 8 seconds',
      'Each message then appears and you are asked who said it',
      'Get at least 4 of 5 right to clear it'
    ]
  },
  'sternberg_task': {
    zh: [
      '先记住一组 4 个水果',
      '然后看一个探针水果，判断它是否在你记住的那组里',
      '10 次答对 7 次以上算通关（越快分越高）'
    ],
    en: [
      'Memorise a set of four fruits',
      'A probe fruit then appears — decide whether it was in your set',
      'Get at least 7 of 10 right to clear it, and faster scores higher'
    ]
  },
  'symmetry_span': {
    zh: [
      '一个左右对称的图案',
      '先记住其中 4 格亮块，然后凭记忆把它们复原',
      '6 题复原对 4 题以上算通关'
    ],
    en: [
      'A left-right symmetrical pattern appears',
      'Memorise the four lit cells, then restore them from memory',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'temporal_order': {
    zh: [
      '4 件事被打乱了顺序',
      '按它们「发生的先后」依次点出来',
      '5 题答对 4 题以上算通关'
    ],
    en: [
      'Four events appear out of order',
      'Tap them in the sequence they happened',
      'Get at least 4 of 5 right to clear it'
    ]
  },
  'temporal_order_judgment': {
    zh: [
      '左右两侧会先后各亮起一个图形',
      '判断哪一个先出现',
      '10 次答对 7 次以上算通关（越快分越高）'
    ],
    en: [
      'A shape lights up on the left and another on the right, one after the other',
      'Decide which one appeared first',
      'Get at least 7 of 10 right to clear it, and faster scores higher'
    ]
  },
  'triple_sequence': {
    zh: [
      '三行光点各自按自己的固定节拍循环（周期 2 / 3 / 4 不等）',
      '一次要猜出三行各自的下一拍位置',
      '5 拍里猜中 11 个以上算通关'
    ],
    en: [
      'Three rows of lights each cycle at their own fixed beat (periods of 2, 3 or 4)',
      'You must guess the next position on all three rows at once',
      'Get at least 11 of the 15 right to clear it'
    ]
  },
  'triplets_logic': {
    zh: [
      '题目给出三句「谁比谁高」',
      '从三句里挑出唯一说得通的「从高到低」排序',
      '6 题答对 4 题以上算通关'
    ],
    en: [
      'Three statements about who is taller than whom are given',
      'Pick the one ordering from tallest to shortest that fits all of them',
      'Get at least 4 of 6 right to clear it'
    ]
  },
  'visual_search_all': {
    zh: [
      '满屏相似的水果里混着若干 🍎',
      '把每一个 🍎 都点掉，点错会扣 2 秒',
      '每过一轮目标更多、时间重置；3 轮全找完算通关，任一环超时就失败'
    ],
    en: [
      'A screenful of similar fruit hides several 🍎',
      'Tap every one of them; a wrong tap costs 2 seconds',
      'Each round has more targets with the clock reset; finish all 3 rounds to clear it, but timing out anywhere fails you'
    ]
  },
  'visual_statistical_learning': {
    zh: [
      '一串图形逐个闪过',
      '其中某三个图形总是连着一起出现',
      '看完后从四个组合里挑出那一组；3 轮答对 2 轮以上算通关'
    ],
    en: [
      'Shapes flash past one at a time',
      'Three of them always appear together in a row',
      'Afterwards pick that trio from four options; get at least 2 of 3 rounds right to clear it'
    ]
  },
  'wireframe_3d_rotation': {
    zh: [
      '题面是 4 块方块搭成的立体形状',
      '四个点阵里，只有一个是它「转了个方向」之后的正交投影',
      '4 题答对 3 题以上算通关'
    ],
    en: [
      'A solid shape built from four blocks is shown',
      'Only one of four dot patterns is its orthographic projection after a rotation',
      'Get at least 3 of 4 right to clear it'
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
