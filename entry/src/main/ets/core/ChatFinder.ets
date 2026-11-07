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
import { GAMES, GameMeta, GameCategory, Difficulty } from './GameRegistry';
import { TG } from './GameI18n';

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
  /** 想「棋牌类」（tags 里有 board/card） */
  board: boolean;
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
  ['逻辑', '推理', '动脑', '解谜', '谜题', '拼图', '脑筋', 'logic', 'puzzle', 'riddle', 'denken', 'logique', 'lógica', 'логик', 'منطق'],
  ['数字', '数学', '算', 'math', 'number', 'zahlen', 'nombre', 'числ', 'أرقام'],
  ['记忆', '记', 'memory', 'memor', 'gedächtnis', 'mémoire', 'memória', 'памят', 'ذاكرة'],
  ['文字', '词', 'word', 'letter', 'wort', 'mot', 'palabra', 'слов', 'كلمات'],
  ['空间', '旋转', '图形', 'spatial', 'shape', 'rotation', 'raum', 'espace', 'espacio', 'простран', 'مكان'],
  ['经典', 'classic', 'klassisch', 'classique', 'clásico', 'классик', 'كلاسيك'],
];
const CATS: GameCategory[] = [GameCategory.LOGIC, GameCategory.MATH, GameCategory.MEMORY,
  GameCategory.WORD, GameCategory.SPATIAL, GameCategory.CLASSIC];

/** 难度关键词 */
const EASY_WORDS: string[] = ['简单', '轻松', '不太难', '随便', '休闲', '摸鱼', 'easy', 'casual', 'relax', 'leicht', 'facile', 'fácil', 'легк', 'سهل'];
const HARD_WORDS: string[] = ['难', '挑战', '烧脑', '硬核', 'hard', 'challenge', 'schwer', 'difficile', 'difícil', 'сложн', 'صعب'];

/** 时长关键词 */
const SHORT_WORDS: string[] = ['三五分钟', '几分钟', '短', '快', '一会儿', '碎片', 'short', 'quick', 'brief', 'kurz', 'court', 'corto', 'коротк', 'قصير'];
const LONG_WORDS: string[] = ['长', '久', '一直玩', '耐玩', 'long', 'endless', 'lange', 'longtemps', 'долг', 'طويل'];

export class ChatFinder {
  /**
   * 把一句人话解析成意图。
   * ★ 这是「规则版」的 NLU —— 不追求理解一切，只追求**把常见说法接住**。
   */
  static parse(text: string): Intent {
    const s: string = text.toLowerCase();
    const it: Intent = {
      category: null, difficulty: null, short: false, long: false,
      pausable: false, untimed: false, multiplayer: false, board: false, hits: []
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
    if (s.indexOf('暂停') >= 0 || s.indexOf('电话') >= 0 || s.indexOf('pause') >= 0 || s.indexOf('unterbr') >= 0) { it.pausable = true; it.hits.push('可暂停'); }
    if (s.indexOf('不限时') >= 0 || s.indexOf('慢慢') >= 0 || s.indexOf('untimed') >= 0 || s.indexOf('ohne zeit') >= 0) { it.untimed = true; it.hits.push('不限时'); }
    if (s.indexOf('联机') >= 0 || s.indexOf('对打') >= 0 || s.indexOf('朋友') >= 0 || s.indexOf('multi') >= 0 || s.indexOf('freund') >= 0) { it.multiplayer = true; it.hits.push('联机'); }
    // ★ 2026-11-07 模拟验证抓到：「棋/牌」原来被映射到 CLASSIC 类别 ⇒ 推荐出「宝石迷阵／打砖块」
    //   因为 CLASSIC 是「经典」不是「棋牌」。改成 **tag 意图**（tags 里有 board/card 的才是棋牌）。
    if (s.indexOf('棋') >= 0 || s.indexOf('牌') >= 0 || s.indexOf('board') >= 0 || s.indexOf('card') >= 0
        || s.indexOf('brett') >= 0 || s.indexOf('carte') >= 0 || s.indexOf('juego de mesa') >= 0) {
      it.board = true; it.hits.push('棋牌');
    }
    return it;
  }

  /** 意图是否「什么都没抽到」（这时该追问，而不是乱推） */
  static isEmpty(it: Intent): boolean {
    return it.category === null && it.difficulty === null && !it.short && !it.long
      && !it.pausable && !it.untimed && !it.multiplayer && !it.board;
  }

  /** 按意图给一款游戏打分（越高越合适） */
  private static scoreOf(g: GameMeta, it: Intent): number {
    let sc: number = 0;
    if (it.category !== null && g.category === it.category) { sc += 40; }
    if (it.difficulty !== null && g.difficulty === it.difficulty) { sc += 25; }
    if (it.short && (g.tags.indexOf('quick') >= 0 || g.tags.indexOf('timed') >= 0 || g.tags.indexOf('endless') >= 0)) { sc += 15; }
    if (it.long && (g.tags.indexOf('endless') >= 0 || g.tags.indexOf('untimed') >= 0)) { sc += 15; }
    if (it.pausable && g.tags.indexOf('pausable') >= 0) { sc += 12; }
    if (it.untimed && g.tags.indexOf('untimed') >= 0) { sc += 12; }
    if (it.multiplayer && (g.tags.indexOf('multiplayer') >= 0 || g.tags.indexOf('board') >= 0)) { sc += 10; }
    // ★ 2026-11-07 模拟验证：355 款的 tags 里**根本没有 board/card** ⇒ 改用「名称含棋/牌」判断
    //   （`9 路围棋`/`跳棋`/`五子棋`/`四子棋`/`黑白棋` 全命中，而 `宝石迷阵` 不会）
    if (it.board) {
      const nm: string = g.name;
      if (nm.indexOf('棋') >= 0 || nm.indexOf('牌') >= 0 || nm.indexOf('麻将') >= 0) { sc += 30; }
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
      if (it.category !== null && g.category === it.category) { why = TG('是「' + it.category + '」类'); }
      else if (it.difficulty !== null && g.difficulty === it.difficulty) { why = TG('难度正好是「' + it.difficulty + '」'); }
      else if (it.pausable && g.tags.indexOf('pausable') >= 0) { why = TG('可以随时暂停'); }
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
  static echo(it: Intent): string {
    if (it.hits.length === 0) { return ''; }
    return TG('按「' + it.hits.join('、') + '」找：');
  }
}
