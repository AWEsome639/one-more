/**
 * 对话找游戏 —— 「我想找个不太难的、能玩三五分钟的解谜」
 *
 * ★ 2026-11-07（奥森的第八个想法）：「软件内内置大语言模型，用户可以与其对话……
 *   找到自己想玩的游戏」。
 *
 * 路线判定（写在代码里，免得下个「拾海」重走一遍）：
 *   · **端侧 LLM**（MindSpore Lite + 0.5B~1.5B 量化模型）：技术上可行、不联网、
 *     包可以几百 MB（奥森说「大一点没关系」）—— 但**模型转换/量化/首启加载**是好几天工程，
 *     且 355 款的元数据（category/difficulty/tags）本身就已经是**结构化标签**，
 *     LLM 的价值主要在「自由对话」，而不是「查标签」。
 *   · **云端 API**：❌ 不用 —— 奥森明令「不能需要网络！我们做的就是不需要联网的游戏！」
 *   · **规则 + 标签检索**：✅ 先做这个。零模型、零网络、零包体积，覆盖「找游戏」这个主诉求。
 *     LLM 留作 v2（`ChatFinder.llmHook` 就是给未来挂模型留的口）。
 *
 * 设计：
 *   输入 → parse() 抽意图（类别/难度/时长/tag/是否限时）→ search() 打分排序 → 回 3 条
 *   意图抽不出来 ⇒ 回一句追问（不是「找不到」）
 */
import { GAMES, GameMeta, GameCategory, Difficulty, catLabelEn } from './GameRegistry';
import { TG } from './GameI18n';
import { L } from './I18n';
import { LocalLLM } from './LocalLLM';

/** 一次对话解析出来的意图 */
export interface Intent {
  category: GameCategory | null;
  difficulty: Difficulty | null;
  /** 想「短一点」（几分钟能玩完） */
  short: boolean;
  /** 想「长一点／能一直玩」 */
  long: boolean;
  /** 想「能随时暂停」（接电话不判负） */
  pausable: boolean;
  /** 想「不限时」 */
  untimed: boolean;
  /** 想「多人/联机」 */
  multiplayer: boolean;
  /** 想「棋牌类」（按**名字**判：棋/牌/麻将/博弈 —— tags 里没有 board/card） */
  board: boolean;
  /** ★ 2026-11-08：「像 XX 那样的」—— 用户提到的那款游戏的 id（找不到就空串） */
  similar: string;
  /** 命中意图的词（给用户看「我是根据这几个词找的」） */
  hits: string[];
}

/** 一条推荐 */
export interface Suggestion {
  game: GameMeta;
  score: number;
  /** 为什么推荐它（一句话，已翻译） */
  why: string;
}

/** 类别关键词表（中英都收，因为用户可能用任意语言） */
const CAT_WORDS: string[][] = [
  // ★ 2026-11-07 模拟验证抓到：「解谜」是中文里**最常见**的说法，原来没在表里 ⇒ 「不太难的解谜」抽不出类别
  ['逻辑', '推理', '动脑', '解谜', '谜题', '拼图', '脑筋', 'logic', 'puzzle', 'riddle', 'denken', 'logique', 'lógica', 'логик', 'منطق',
   // ★ 2026-11-08 补：德 Rätsel/Denkspiel、俄 головоломка 是各自语言里最自然的说法（原来只有 denken/логик）
   'rätsel', 'denkspiel', 'головолом', 'パズル', '論理', '퍼즐', '논리'],
  ['数字', '数学', '算', 'math', 'number', 'zahlen', 'nombre', 'числ', 'أرقام',
   'rechnen', 'матем', '数字', '計算', '숫자', '계산'],
  ['记忆', '记', 'memory', 'memor', 'gedächtnis', 'mémoire', 'memória', 'памят', 'ذاكرة',
   'merken', 'память', '記憶', '기억'],
  ['文字', '词', 'word', 'letter', 'wort', 'mot', 'palabra', 'слов', 'كلمات',
   'buchstab', 'wörter', 'букв', '言葉', '단어', '글자'],
  ['空间', '旋转', '图形', 'spatial', 'shape', 'rotation', 'raum', 'espace', 'espacio', 'простран', 'مكان',
   'räumlich', 'drehen', 'фигур', '空間', '回転', '공간', '회전'],
  ['经典', 'classic', 'klassisch', 'classique', 'clásico', 'классик', 'كلاسيك',
   'klassiker', 'クラシック', '클래식'],
];
const CATS: GameCategory[] = [GameCategory.LOGIC, GameCategory.MATH, GameCategory.MEMORY,
  GameCategory.WORD, GameCategory.SPATIAL, GameCategory.CLASSIC];

/** 难度关键词 */
// ★★★ 2026-11-08 **否定式修复**（code-hunter 实测）：
//   `parse()` 是**子串包含**匹配，而 HARD 词表里英/德/俄用的是**词干**（hard/schwer/сложн）
//   ⇒ `not hard` / `nicht schwer` / `несложная` 全部命中 HARD ⇒ **用户说「不难」却给最难的**。
//   中文靠枚举整句 `'不太难'` 绕过了，其它语言全中招。
//   ⇒ 把否定短语放进 EASY（代码里 EASY 先于 HARD 判 ⇒ 必然优先命中）。
const EASY_WORDS: string[] = [
  '简单', '轻松', '不太难', '随便', '休闲', '摸鱼',
  'not hard', 'not difficult', 'no hard', 'nicht schwer', 'nicht schwierig',
  'pas difficile', 'no difícil', 'несложн', 'не сложн', 'ليس صعب',
  // ★ 2026-11-08：日语/韩语的「简单」（原来一个都没有 ⇒ 「簡単なパズル」抽不到难度）
  '簡単', 'かんたん', '優しい', '쉬운', '간단',
  'easy', 'casual', 'relax', 'leicht', 'facile', 'fácil', 'легк', 'سهل'
];
const HARD_WORDS: string[] = ['难', '挑战', '烧脑', '硬核', 'hard', 'challenge', 'schwer', 'difficile', 'difícil', 'сложн', 'صعب',
  // ★ 2026-11-08 补：日语/韩语（「難しい」「어려운」原来一个都没有 ⇒ 整句空）
  '難しい', 'むずかしい', '어려운', '어렵'];

/** 时长关键词 */
const SHORT_WORDS: string[] = ['三五分钟', '几分钟', '短', '快', '一会儿', '碎片', 'short', 'quick', 'brief', 'kurz', 'court', 'corto', 'коротк', 'قصير',
  // ★ 2026-11-08 补：日语/韩语（「短い」「짧은」原来都没有 ⇒「短いゲーム」「짧은 게임」整句空）
  '短い', '짧은', 'すぐ'];
const LONG_WORDS: string[] = ['长', '久', '一直玩', '耐玩', 'long', 'endless', 'lange', 'longtemps', 'долг', 'طويل',
  // ★ 2026-11-08 补：日语/韩语的「长」（与 SHORT 对称）
  '長い', '긴'];

/** 真·联机对打：引用 `LanMatch` 的 8 款（355 款都有 LanRace 竞速，那不算对打） */
const MULTI_IDS: string[] = [
  'checkers', 'connect_four', 'go9', 'gomoku', 'mancala', 'nim', 'reversi', 'tic_tac_toe'
];

/**
 * ★★★ 2026-11-08（game-balancer）取一款的**玩法标签**（`ps_*`，每款恰好 1 个）。
 *   为什么不用 `new field`：`tags` 里已经带上了，零新增字段、零迁移。
 *   ArkTS 没有 `Array.some` 的惯用写法 ⇒ 老实用 for + indexOf('ps_') === 0。
 */
function styleOf(g: GameMeta): string {
  for (let i = 0; i < g.tags.length; i++) {
    if (g.tags[i].indexOf('ps_') === 0) {
      return g.tags[i];
    }
  }
  return '';
}

/**
 * ★★★ 2026-11-08：**20 款热门游戏的俄语/德语别名**（聊天找游戏用）
 *
 * 为什么需要：`similar` 只认**中文名 + 英文名**，所以
 *   `как сапёр`（俄语「像扫雷」）、`wie Minesweeper` 都匹配不到 ⇒ 整句空。
 *
 * 为什么只做 20 款：其余 335 款被用户「拿名字点名」的概率极低，
 *   标 355 款的成本收益不划算（判据：覆盖头部就够）。
 *
 * 为什么用 **game id** 当键（而不是中文名）：id 是不可变的，中文名可能被改；
 *   而且中文名在 `displayName()` 里会随语言变，当键不稳。
 *
 * ⚠️ 别名一律小写（`parse()` 里 `s` 已经 toLowerCase），且**避开太常见的词**
 *   （如不把德语 'dame' 收进来 —— 它在英语里也是常见词，会误命中）。
 */
// ★ 2026-11-08 ArkTS 严格模式**不支持 `Record` 字面量**（只能 `{}` 空对象再赋值）
//   ⇒ 改成**二维数组**：`[gameId, 别名1, 别名2, ...]`，查找时遍历。40 条数据，遍历开销可忽略。
const ALIAS: string[][] = [
  ['minesweeper', 'сапёр', 'сапер', 'минное поле', 'minensucher', 'minenfeld'],
  ['snake', 'змейка', 'змейку', 'schlange'],
  ['bejeweled', 'три в ряд', 'ювелир', 'juwelen', 'edelsteine'],
  ['breakout', 'арканоид', 'арканойд', 'mauerbrecher', 'klötze'],
  ['sudoku', 'судоку'],
  ['reversi', 'реверси', 'отэлло', 'othello'],
  ['gomoku', 'гомоку', 'пять в ряд', 'fünf in einer reihe'],
  ['checkers', 'шашки', 'шашках', 'damespiel'],
  ['connect_four', 'четыре в ряд', 'vier gewinnt'],
  ['tic_tac_toe', 'крестики-нолики', 'крестики', 'drei gewinnt'],
  ['go9', 'вэйци'],
  ['sokoban', 'сокобан', 'ящики', 'kisten'],
  ['freecell', 'косынка', 'солитер', 'solitär'],
  ['mahjong_solitaire', 'маджонг', 'mahjong'],
  ['bubble_shooter', 'шарики', 'пузыри', 'seifenblasen'],
  ['nonogram', 'нонограмма', 'японский кроссворд', 'nonogramm', 'kreuzworträtsel'],
  ['slide_puzzle', 'пятнашки', 'schiebepuzzle'],
  ['klotski', 'клотски'],
  ['classic_maze', 'лабиринт', 'labyrinth', 'irrgarten'],
  ['snake_3d', 'змейка 3д'],
];

export class ChatFinder {
  /**
   * 把一句人话解析成意图。
   * ★ 这是「规则版」的 NLU —— 不追求理解一切，只追求**把常见说法接住**。
   */
  static parse(text: string): Intent {
    const s: string = text.toLowerCase();
    const it: Intent = {
      category: null, difficulty: null, short: false, long: false,
      pausable: false, untimed: false, multiplayer: false, board: false, similar: '', hits: []
    };
    // 类别
    for (let i = 0; i < CAT_WORDS.length; i++) {
      for (let k = 0; k < CAT_WORDS[i].length; k++) {
        if (s.indexOf(CAT_WORDS[i][k].toLowerCase()) >= 0) {
          it.category = CATS[i];
          it.hits.push(CAT_WORDS[i][k]);
          break;
        }
      }
      if (it.category !== null) { break; }
    }
    // 难度
    for (let k = 0; k < EASY_WORDS.length; k++) {
      if (s.indexOf(EASY_WORDS[k].toLowerCase()) >= 0) { it.difficulty = Difficulty.EASY; it.hits.push(EASY_WORDS[k]); break; }
    }
    if (it.difficulty === null) {
      for (let k = 0; k < HARD_WORDS.length; k++) {
        if (s.indexOf(HARD_WORDS[k].toLowerCase()) >= 0) { it.difficulty = Difficulty.HARD; it.hits.push(HARD_WORDS[k]); break; }
      }
    }
    // 时长
    for (let k = 0; k < SHORT_WORDS.length; k++) {
      if (s.indexOf(SHORT_WORDS[k].toLowerCase()) >= 0) { it.short = true; it.hits.push(SHORT_WORDS[k]); break; }
    }
    for (let k = 0; k < LONG_WORDS.length; k++) {
      if (s.indexOf(LONG_WORDS[k].toLowerCase()) >= 0) { it.long = true; it.hits.push(LONG_WORDS[k]); break; }
    }
    // 可暂停 / 不限时 / 联机
    // ★ 2026-11-08 补：日/韩/俄的「暂停」（原来只认 中文/英/德）
    if (s.indexOf('暂停') >= 0 || s.indexOf('电话') >= 0 || s.indexOf('pause') >= 0 || s.indexOf('unterbr') >= 0
        || s.indexOf('一時停止') >= 0 || s.indexOf('일시정지') >= 0 || s.indexOf('паузу') >= 0 || s.indexOf('пауза') >= 0) { it.pausable = true; it.hits.push(TG('可暂停')); }
    if (s.indexOf('不限时') >= 0 || s.indexOf('慢慢') >= 0 || s.indexOf('untimed') >= 0 || s.indexOf('ohne zeit') >= 0) { it.untimed = true; it.hits.push(TG('不限时')); }
    if (s.indexOf('联机') >= 0 || s.indexOf('对打') >= 0 || s.indexOf('朋友') >= 0 || s.indexOf('multi') >= 0 || s.indexOf('freund') >= 0) { it.multiplayer = true; it.hits.push(TG('联机')); }
    // ★ 2026-11-07 模拟验证抓到：「棋/牌」原来被映射到 CLASSIC 类别 ⇒ 推荐出「宝石迷阵／打砖块」
    //   因为 CLASSIC 是「经典」不是「棋牌」。改成 **tag 意图**（tags 里有 board/card 的才是棋牌）。
    if (s.indexOf('棋') >= 0 || s.indexOf('牌') >= 0 || s.indexOf('board') >= 0 || s.indexOf('card') >= 0
        || s.indexOf('brett') >= 0 || s.indexOf('carte') >= 0 || s.indexOf('juego de mesa') >= 0) {
      it.board = true; it.hits.push(TG('棋牌'));
    }
    // ★★★ 2026-11-08 **「像 XX 那样的」**（v2 第一个新维度）——
    //   这是用户最常问的一类（「有没有像 2048 的」「跟扫雷差不多的」），v1 完全没接住。
    //   识别法：句子里**直接出现某款游戏的名字**（去掉空格/标点后包含即可）。
    //   ⚠️ 只在**没有更明确的意图**时启用（用户说「想玩不太难的解谜，像 2048 那样」时以解谜为主）。
    // ★★★ 2026-11-08（模拟验证抓到的**真 bug**）：
    //   上面的注释写着「⚠️ 只在**没有更明确的意图**时启用（用户说『想玩不太难的解谜，像 2048 那样』时以解谜为主）」，
    //   但**实现里根本没有这个判断** ⇒ 只要句子里出现某个游戏的英文名，similar 就会覆盖掉主意图。
    //   实例：`memory training` 里的 `memory` 命中了游戏英文名 `Memory` ⇒ similar 生效
    //        ⇒ 353 款全被拉进来（原本「找记忆类」只要 74 款，且排序也乱了）。
    //   ⇒ 按注释的本意补上：只有「别的意图一个都没抽到」时才做 similar 匹配。
    const hasIntent: boolean =
      it.category !== null || it.difficulty !== null || it.short || it.long
      || it.pausable || it.untimed || it.multiplayer || it.board;
    const nmClean: string = s.replace(/\s/g, '');
    for (let i = 0; hasIntent === false && i < GAMES.length; i++) {
      const gn: string = GAMES[i].name.replace(/\s/g, '').toLowerCase();
      if (gn.length >= 2 && nmClean.indexOf(gn) >= 0) {
        it.similar = GAMES[i].id;
        it.hits.push(GAMES[i].name);
        break;
      }
      // ★★★ 2026-11-08：**英文名也参与匹配** —— 原来只收中文名，
      //   所以 `like minesweeper` / `как сапёр` 完全匹配不到「扫雷」（必空）。
      //   ⚠️ 拉丁名**必须词边界匹配**：`Nim`（尼姆博弈）不加边界会命中 `animal`，
      //      `Pong` 会命中 `pingpong`（这个反而是想要的，见 wordIn 的注释）。
      const en: string = GAMES[i].enName.toLowerCase();
      if (en.length >= 3 && ChatFinder.wordIn(s, en)) {
        it.similar = GAMES[i].id;
        it.hits.push(GAMES[i].enName);   // ★ 用户用英文问，就把英文名回显给他
        break;
      }
      // ★ 2026-11-08：俄语/德语别名（见 ALIAS）。命名一致 ⇒ 不做词边界，纯子串即可：
      //   西里尔字母不会像拉丁字母那样撞进英文单词里。
      const al: string[] = ChatFinder.aliasOf(GAMES[i].id);
      if (al.length > 0) {
        let hit: string = '';
        for (let a = 0; a < al.length; a++) {
          if (s.indexOf(al[a]) >= 0) { hit = al[a]; break; }
        }
        if (hit.length > 0) {
          it.similar = GAMES[i].id;
          it.hits.push(hit);
          break;
        }
      }
    }
    return it;
  }

  /** 从二维数组里取某款的别名（ArkTS 不支持 Record 字面量，只能遍历） */
  private static aliasOf(id: string): string[] {
    for (let i = 0; i < ALIAS.length; i++) {
      if (ALIAS[i][0] === id) {
        return ALIAS[i].slice(1);
      }
    }
    return [];
  }

  /** 意图是否「什么都没抽到」（这时该追问，而不是乱推） */
  static isEmpty(it: Intent): boolean {
    // ★★★ 2026-11-08（game-balancer）：`pausable` / `untimed` 已**退出打分**（覆盖 91%，没有筛选力）
    //   ⇒ 它们不能再算「听懂了」：只有这两个命中时必须**走追问**，而不是返回 323 款。
    return it.category === null && it.difficulty === null && !it.short && !it.long
      && !it.multiplayer && !it.board && it.similar.length === 0;
  }

  /** 按意图给一款游戏打分（越高越合适） */
  private static scoreOf(g: GameMeta, it: Intent): number {
    let sc: number = 0;
    if (it.category !== null && g.category === it.category) { sc += 40; }
    // ★★★ 2026-11-08 **难度数据修复**（verifier-eng2 实测：`EASY` 只有 **0 款**、`HARD` 1 款，
    //   355 款里 354 款是 NORMAL）⇒ 「简单点 / 太难了 / 适合小孩」这三类最常见问法**永远答不出**。
    //   `difficulty` 字段本身是坏的（全 NORMAL），但 **`tags` 里有 `easy`(48) / `hard`(58) / `medium`(103)**
    //   ⇒ 匹配时**两个都看**：字段对上 +25，tag 对上 +20（不重复加，取较高那档）。
    if (it.difficulty !== null) {
      const tagHit: boolean =
        (it.difficulty === Difficulty.EASY && g.tags.indexOf('easy') >= 0)
        || (it.difficulty === Difficulty.HARD && g.tags.indexOf('hard') >= 0)
        || (it.difficulty === Difficulty.NORMAL && g.tags.indexOf('medium') >= 0);
      if (g.difficulty === it.difficulty) {
        sc += 25;
      } else if (tagHit) {
        sc += 20;
      }
    }
    // ★ 2026-11-08 **死判据修复**（verifier-eng2 实测）：数据里 **`quick` 是 0 款**，
    //   真实存在的是 **`short`(166)** 与 `timed`(32) ⇒ 「十分钟/短一局」原来**永远匹配不到**。
    if (it.short && (g.tags.indexOf('short') >= 0 || g.tags.indexOf('timed') >= 0)) { sc += 15; }
    // ★★★ 2026-11-08 二级排序（修「195 款同分、靠 id 字典序」）：
    //   `short` 命中 195 款，其中只有 **32 款带 timed/speed**（有明确计时/限时玩法），
    //   其余 163 款只是"标了 short"（可能只是时长短）。
    //   ⇒ 给带 timed/speed 的再加 6 分，把并列从 195 路压到 32 路。
    //   ⚠️ **不能用 baseXp 当二级键** —— 355 款全是 12（常量）；
    //      `GameMeta` 也没有时长/步数这类字段，`tags` 是唯一可用杠杆。
    if (it.short && (g.tags.indexOf('timed') >= 0 || g.tags.indexOf('speed') >= 0)) { sc += 6; }
    // ★★★ 2026-11-08（game-balancer）**「长局」改用真·时长 tag**：
    //   原来是 `endless | untimed` ⇒ untimed 覆盖 323 款 ⇒ 「找个长局」返回 **332 款**（等于没筛）。
    //   改成 `long`(64) | `endless`(22) ⇒ **78 款**，正好落在 20~80 的理想筛选区间。
    if (it.long && (g.tags.indexOf('long') >= 0 || g.tags.indexOf('endless') >= 0)) { sc += 15; }
    // ★ 同上（对称）：长局 78 款里只有 22 款是真正的 endless ⇒ 同样 +6 托到前面
    if (it.long && g.tags.indexOf('endless') >= 0) { sc += 6; }
    // ★★★ 2026-11-08（game-balancer）**「能暂停 / 不限时」不再参与打分**。
    //   判据：`pausable` 覆盖 147 款、`untimed` 覆盖 **323 款（91%）**
    //   ⇒ 加分等于给整个库加同一个常数，对排序**零贡献**；
    //     单独问「找个能暂停的」还会把 323 款全捞出来（等于没筛）。
    //   ⇒ 这两个字段现在只用于文案；**只命中它们时会走追问**（见 isEmpty）。
    //   （依据：_巡检记录/tag分布-20261108.md §2 / §6）

    // ★★★ 2026-11-08（game-balancer）**死查表修复**：原来查 `multiplayer` / `board` 两个 tag，
    //   而 GameTags 的 40 个 tag 里**这两个都不存在（0 款）** ⇒ 「联机对打」永远返回 0 结果。
    //   改成**静态名单**：真·联机对打 = 引用 `LanMatch` 的 8 款（其余 355 款只有 LanRace 竞速、不算对打）。
    //   重新生成：`grep -l LanMatch entry/src/main/ets/games/*.ets`
    if (it.multiplayer && MULTI_IDS.indexOf(g.id) >= 0) { sc += 10; }
    // ★ 2026-11-07 模拟验证：355 款的 tags 里**根本没有 board/card** ⇒ 改用「名称含棋/牌」判断
    //   （`9 路围棋`/`跳棋`/`五子棋`/`四子棋`/`黑白棋` 全命中，而 `宝石迷阵` 不会）
    if (it.board) {
      const nm: string = g.name;
      if (nm.indexOf('棋') >= 0 || nm.indexOf('牌') >= 0 || nm.indexOf('麻将') >= 0 || nm.indexOf('博弈') >= 0) { sc += 30; }
    }
    // ★ 2026-11-08「像 XX 那样」：同类别 +18、同难度 +8、共享 tags 每个 +4（最多 +16）
    //   ⚠️ **不推荐它自己**（用户说「像 2048」意思是要「别的」，不是「再玩一次 2048」）
    if (it.similar.length > 0 && g.id !== it.similar) {
      let ref: GameMeta | undefined = undefined;
      for (let i = 0; i < GAMES.length; i++) {
        if (GAMES[i].id === it.similar) { ref = GAMES[i]; break; }
      }
      if (ref !== undefined) {
        // ★★★ 2026-11-08（game-balancer）**玩法相同是主信号，且与「同类别」互斥**。
        //   为什么必须互斥 + 给到 40：非同类候选的上限是 `18(类别) + 8(难度) + 16(共享tag) = 42`。
        //   实测（_巡检记录/playStyle方案-20261108.md §5）：只给 +25 时，「像 2048」的
        //   ps_merge 候选只有 37 分 < 三消的 42 ⇒ **top-3 一分不变**；
        //   改成 +40 且互斥后，候选最低 `40 + 8 = 48 > 42` ⇒ 必然胜出（实测 52 vs 42）。
        const gs: string = styleOf(g);
        const rs: string = styleOf(ref);
        const sameStyle: boolean = gs.length > 0 && gs === rs;
        if (sameStyle) {
          sc += 40;
        } else if (g.category === ref.category) {
          sc += 18;
        }
        // ★ 2026-11-08 **「同难度 +8」不再白送**：`difficulty` 字段 354/355 都是 NORMAL
        //   ⇒ 原来等于给所有候选加同一个常数。现在只在双方都是**非普通**档时才给。
        if (g.difficulty === ref.difficulty && g.difficulty !== Difficulty.NORMAL) { sc += 8; }
        // ★ 2026-11-08 **操作方式相同 +10**：`tap/swipe/drag/type` 是手感维度，
        //   「2048 和 数字蛇 都是 swipe」确实比「考拉兹（点按）」更像。
        for (let t = 0; t < g.tags.length; t++) {
          const tt: string = g.tags[t];
          if ((tt === 'tap' || tt === 'swipe' || tt === 'drag' || tt === 'type')
            && ref.tags.indexOf(tt) >= 0) {
            sc += 10;
            break;
          }
        }
        let shared: number = 0;
        for (let t = 0; t < g.tags.length; t++) {
          if (ref.tags.indexOf(g.tags[t]) >= 0) { shared = shared + 1; }
        }
        sc += Math.min(16, shared * 4);
      }
    }
    // 毫无倾向时给「轻松」一点偏好（新手友好）
    if (ChatFinder.isEmpty(it) && g.difficulty === Difficulty.EASY) { sc += 3; }
    return sc;
  }

  /**
   * 推荐 Top N。
   * ★ 排序稳定（同分按 id 字典序），保证同一句话每次给同一批 —— 用户不会觉得「它在乱跳」。
   */
  static suggest(text: string, n: number): Suggestion[] {
    const it: Intent = ChatFinder.parse(text);
    const scored: Suggestion[] = [];
    for (let i = 0; i < GAMES.length; i++) {
      const g: GameMeta = GAMES[i];
      const sc: number = ChatFinder.scoreOf(g, it);
      if (sc <= 0) { continue; }
      let why: string = '';
      if (it.category !== null && g.category === it.category) { why = L('是「{0}」类', 'Category: {0}').replace('{0}', ChatFinder.catLabel(it.category)); }
      else if (it.difficulty !== null && (g.difficulty === it.difficulty || g.tags.indexOf(it.difficulty === Difficulty.EASY ? 'easy' : (it.difficulty === Difficulty.HARD ? 'hard' : 'medium')) >= 0)) { why = L('难度对得上', 'Difficulty matches'); }
      else if (it.pausable && g.tags.indexOf('pausable') >= 0) { why = TG('可以随时暂停'); }
      else if (it.similar.length > 0 && g.id !== it.similar) { why = L('和你说的那款相近', 'Similar to the one you named'); }
      else { why = TG('符合你的口味'); }
      scored.push({ game: g, score: sc, why: why });
    }
    scored.sort((a: Suggestion, b: Suggestion): number => {
      if (b.score !== a.score) { return b.score - a.score; }
      return a.game.id < b.game.id ? -1 : (a.game.id > b.game.id ? 1 : 0);
    });
    return scored.slice(0, n);
  }

  /** 追问（什么都没听懂时） */
  static ask(): string {
    return TG('想玩点什么样的？比如「不太难的解谜」「能玩三五分钟的」「烧脑的」');
  }

  /** 把抽到的意图回给用户看（让他知道我是按什么找的） */
  /**
   * ★★★ 2026-11-08：类别标签。
   *   `GameCategory` 的枚举值是**中文**（`LOGIC = '逻辑'`），直接拼进文案会变成
   *   「是「逻辑」类」—— 非中文用户看到的永远是中文。
   *   ⇒ 6 个类别中文值**都在 EXTRA 字典里**，走 `L()` 查表即可；
   *     英文用 `catLabelEn()`（GameRegistry 已有），因为 `L()` 对英文直接用第二个参数。
   */
  /**
   * ★★★ 2026-11-08 拉丁词边界匹配（`parse` 的英文名识别用）。
   *   为什么必需：英文名里有 `Nim`（3 字符）这种，纯子串匹配会命中 `animal` 的 'nim'
   *   ⇒ 用户说 "animal games" 被当成「想玩尼姆博弈」。
   *   判据：前后字符都不是 a-z 才算命中；`ping pong` 里的 `pong` 前后是空格 ⇒ 通过 ✓
   */
  private static wordIn(s: string, w: string): boolean {
    const latin: RegExp = /[a-z]/;
    let from: number = 0;
    while (from + w.length <= s.length) {
      const i: number = s.indexOf(w, from);
      if (i < 0) { return false; }
      const before: string = i > 0 ? s.charAt(i - 1) : ' ';
      const after: string = i + w.length < s.length ? s.charAt(i + w.length) : ' ';
      if (!latin.test(before) && !latin.test(after)) { return true; }
      from = i + 1;
    }
    return false;
  }

  private static catLabel(c: GameCategory): string {
    return L(c, catLabelEn(c));
  }

  static echo(it: Intent): string {
    if (it.hits.length === 0) { return ''; }
    // ★★★ 2026-11-08 **恒中文 bug**（code-hunter 抓到）：原来 `TG('按「' + hits.join('、') + '」找：')`
    //   是**动态 key** —— 永远不可能命中字典 ⇒ `TG` 走最后一行 `return zh` ⇒ **恒中文**。
    //   ⇒ 拆成「模板（静态，可翻译）+ 命中词（来自用户原话，不译）」两段。
    // ⚠️ 用 L() 而不是 TG()：这条 key 在 **EXTRA**（core/I18n.ets），不在 DICT。
    //   `TG()` 只读 DICT ⇒ 查不到就 `return zh` ⇒ 恒中文（我上一版就是这么失效的）。
    return L('按「{0}」找：', 'Found for "{0}":').replace('{0}', it.hits.join('、'));
  }

  // ══════════════════════════════════════════════════════════════════════
  //  端侧 LLM 抽意图（2026-11-08）—— **可选路径，规则版永远是保底**
  //
  //  ★ 为什么不改 parse()：`parse()` 是**断网/无模型/无权限**时唯一能用的路径，
  //    它的行为必须冻结（有 20 句模拟基线：见 _巡检记录/ChatFinder覆盖-20261108.md）。
  //  ★ 只换「理解」，不换「检索」：LLM 只吐 `{category, difficulty, short}`，
  //    排序仍走现有 scoreOf()（355 款数据、可测、稳定）。
  //  ★ prompt <1KB：**不塞 355 款目录**（中文名就要 ~3.5KB，会贴 4500 字节上限），
  //    只放 6 类别 + 3 难度 + 时长词表。
  // ══════════════════════════════════════════════════════════════════════

  /** 给端侧 LLM 的抽取 prompt（静态模板 + 用户原话；<1KB） */
  private static llmPrompt(text: string): string {
    return '你是游戏筛选助手。只输出一行 JSON，不要解释，不要 markdown。\n'
      + '字段：\n'
      + '- category：LOGIC(逻辑解谜) / MATH(数字数学) / MEMORY(记忆) / WORD(文字词) / SPATIAL(空间旋转) / CLASSIC(经典)，或 null\n'
      + '- difficulty：EASY(简单轻松) / NORMAL(普通) / HARD(烧脑挑战)，或 null\n'
      + '- short：布尔，想玩几分钟的短局为 true\n'
      + '示例：{"category":"LOGIC","difficulty":"EASY","short":true}\n'
      + '用户说：' + text;
  }

  /**
   * 用端侧 LLM 抽意图；**任何失败都回落 `parse()`**（规则保底，绝不抛）。
   * 调用方：`const it: Intent = await ChatFinder.parseWithLLM(userText);`
   */
  static async parseWithLLM(text: string): Promise<Intent> {
    const base: Intent = ChatFinder.parse(text);
    try {
      const ready: boolean = await LocalLLM.init();
      if (!ready) {
        return base;
      }
      let acc: string = '';
      const ok: boolean = await LocalLLM.chat(ChatFinder.llmPrompt(text), (piece: string) => {
        acc += piece;
      });
      if (!ok) {
        return base;
      }
      return ChatFinder.mergeLLM(base, acc);
    } catch (e) {
      // 兜底中的兜底：连 LocalLLM 都抛了（不该发生），仍然用规则版
      return base;
    }
  }

  /** 把 LLM 吐的 JSON 合进意图；解析/校验任何一环失败就原样返回 base */
  private static mergeLLM(base: Intent, raw: string): Intent {
    const i: number = raw.indexOf('{');
    const j: number = raw.lastIndexOf('}');
    if (i < 0 || j <= i) {
      return base;
    }
    let out: LlmOut;
    try {
      // ★ 用显式接口而不是 Record 索引：ArkTS 严格模式下更稳，也自带字段校验
      out = JSON.parse(raw.substring(i, j + 1)) as LlmOut;
    } catch (e) {
      return base;
    }
    if (out === undefined || out === null) {
      return base;
    }
    // 显式拷贝（ArkTS 不用对象展开）
    // ⚠️ 字段必须与 `interface Intent` 完全一致：加字段时这里也要加（漏了就是编译错）
    const it: Intent = {
      category: base.category, difficulty: base.difficulty,
      short: base.short, long: base.long,
      pausable: base.pausable, untimed: base.untimed,
      multiplayer: base.multiplayer, board: base.board,
      similar: base.similar,
      hits: base.hits.slice()
    };
    if (out.category === 'LOGIC') {
      it.category = GameCategory.LOGIC;
    } else if (out.category === 'MATH') {
      it.category = GameCategory.MATH;
    } else if (out.category === 'MEMORY') {
      it.category = GameCategory.MEMORY;
    } else if (out.category === 'WORD') {
      it.category = GameCategory.WORD;
    } else if (out.category === 'SPATIAL') {
      it.category = GameCategory.SPATIAL;
    } else if (out.category === 'CLASSIC') {
      it.category = GameCategory.CLASSIC;
    }
    if (out.difficulty === 'EASY') {
      it.difficulty = Difficulty.EASY;
    } else if (out.difficulty === 'NORMAL') {
      it.difficulty = Difficulty.NORMAL;
    } else if (out.difficulty === 'HARD') {
      it.difficulty = Difficulty.HARD;
    }
    if (out.short === true) {
      it.short = true;
    } else if (out.short === false) {
      it.short = false;
    }
    return it;
  }
}

/** LLM 期望吐出的 JSON（解析后用它校验字段类型） */
interface LlmOut {
  category?: string;
  difficulty?: string;
  short?: boolean;
}
