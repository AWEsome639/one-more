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
