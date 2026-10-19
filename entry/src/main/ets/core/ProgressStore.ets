/**
 * 进度系统 —— XP / 等级 / 每日打卡 / 双层连胜
 *
 * 等级公式（对标体验）：level = clamp(floor((xp/100)^(1/2.04)) + 1, 1, 100)
 *   反解 XP 门槛：xpForLevel(l) = floor(100 * (l-1)^2.04)
 *   ⇒ 早期升级快（正反馈），后期拉长（耐玩），100 级封顶
 *
 * 双层连胜：
 *   ① 每个游戏自己的 streak（连续几天玩了这个游戏）
 *   ② 全局 superStreak —— **当天任意解出一局** 就 +1；断一天归 1
 *
 * 持久化：@kit.ArkData 的 preferences（键值对，够用且零依赖）
 * 响应式：状态写进 AppStorage，组件用 @StorageProp/@StorageLink 读
 */

import { GAME_IDS_BY_CAT } from './GameRegistry';
import { I18n, toTrad } from './I18n';
import { Accent } from './Design';
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'yiju_progress';
/** 语言 / 主题色的落盘键（2026-10-13：从 PersistentStorage 改成吃这个库 —— 见 saveLang 注释） */

/** AppStorage 键名（组件只认这些） */
export class Keys {
  static readonly xp: string = 'xp';
  static readonly level: string = 'level';
  static readonly totalSolved: string = 'totalSolved';
  static readonly superStreak: string = 'superStreak';
  static readonly solvedToday: string = 'solvedToday';
  static readonly bestStreak: string = 'bestStreak';
  static readonly dailyCount: string = 'dailyCount';       // 今日已解局数
  static readonly streak: string = 'streak';               // 当前这款游戏的连胜局数
  static readonly themeDark: string = 'themeDark';         // 解析后的实际深浅（UI 只读这个）
  static readonly themeMode: string = 'themeMode';         // 用户选择：light / dark / system
  static readonly favorites: string = 'favorites';         // 收藏的 gameId，逗号分隔
  static readonly recent: string = 'recent';               // 最近玩过，逗号分隔
  static readonly totalPlays: string = 'totalPlays';       // 累计开局数
  static readonly totalMs: string = 'totalMs';             // 累计游玩毫秒
  static readonly perGamePlays: string = 'perGamePlays';   // 每款开局数 JSON
  static readonly perGameBest: string = 'perGameBest';     // 每款最高分 JSON
  static readonly firstDay: string = 'firstDay';           // 首次使用日期
  static readonly dailyGame: string = 'dailyGame';         // 今日挑战的 gameId
  static readonly dailyDone: string = 'dailyDone';         // 今日挑战是否已完成
  static readonly dailyBonus: string = 'dailyBonus';       // 今日已拿到的挑战奖励
  static readonly achievements: string = 'achievements';   // 已解锁的成就 id，逗号分隔

  static readonly cleared: string = 'clearedGames';        // 已通关过的 gameId，逗号分隔（每游戏徽章）
  static readonly perfect: string = 'perfectGames';        // 满分/零失误通关的 gameId
  static readonly perGameClears: string = 'perGameClears'; // 每款通关次数 JSON
  static readonly perGameDiff: string = 'perGameDiff';     // 每款选的难度 JSON
}

/** 单个游戏的连胜记录 */
interface GameStreak {
  current: number;
  lastDay: string;   // YYYY-MM-DD
  solvedToday: boolean;
}

export class ProgressStore {

  /**
   * ★ 手感：本局**新解锁的成就**（finishGame 跑完后被填上）
   *
   * 为什么需要它：`checkAchievements()` 本来就在 finishGame 内部被调用，
   * 但**返回值原先被丢掉了** ⇒ GameHost 无从知道"刚刚解锁了什么"，
   * 所以成就解锁从来没有庆祝过。这里留一个静态字段当**信使**，结算时读它。
   * ⚠️ 语义：**只反映最近一局**；handleFinish 读完即可，不要跨局复用。
   */
  static lastNewAch: string[] = [];
  private static pref: preferences.Preferences | null = null;
  private static streaks: Map<string, GameStreak> = new Map<string, GameStreak>();
  private static ready: boolean = false;

  /** 应用启动时调一次 */
  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (ProgressStore.ready) {
      return;
    }
    try {
      ProgressStore.pref = await preferences.getPreferences(ctx, STORE_NAME);
      const p = ProgressStore.pref;

      const xp: number = p.getSync(Keys.xp, 0) as number;
      const totalSolved: number = p.getSync(Keys.totalSolved, 0) as number;
      const superStreak: number = p.getSync(Keys.superStreak, 0) as number;
      const bestStreak: number = p.getSync(Keys.bestStreak, 0) as number;
      const lastDay: string = p.getSync('lastDay', '') as string;
      const dark: boolean = p.getSync(Keys.themeDark, false) as boolean;
      // 三态：没存过 themeMode 就默认「跟随系统」—— 这是最合直觉的默认（奥森要求）
      const savedMode: string = p.getSync(Keys.themeMode, '') as string;
      const mode: string = savedMode.length > 0 ? savedMode : 'system';
      const rawStreaks: string = p.getSync('streaks', '{}') as string;

      // 读回每个游戏的连胜
      try {
        const obj: Record<string, GameStreak> = JSON.parse(rawStreaks) as Record<string, GameStreak>;
        Object.keys(obj).forEach((k: string) => {
          ProgressStore.streaks.set(k, obj[k]);
        });
      } catch (e) {
        ProgressStore.streaks = new Map<string, GameStreak>();
      }

      const today: string = ProgressStore.today();
      // 跨天：把所有 solvedToday 归零；superStreak 若断档则归零显示
      ProgressStore.streaks.forEach((v: GameStreak, k: string) => {
        if (v.lastDay !== today) {
          v.solvedToday = false;
        }
      });
      const gap: number = ProgressStore.dayGap(lastDay, today);
      const showStreak: number = (gap > 1) ? 0 : superStreak;

      AppStorage.setOrCreate(Keys.xp, xp);
      AppStorage.setOrCreate(Keys.level, ProgressStore.levelOf(xp));
      AppStorage.setOrCreate(Keys.totalSolved, totalSolved);
      AppStorage.setOrCreate(Keys.superStreak, showStreak);
      AppStorage.setOrCreate(Keys.bestStreak, bestStreak);
      AppStorage.setOrCreate(Keys.solvedToday, false);
      AppStorage.setOrCreate(Keys.dailyCount, 0);
      AppStorage.setOrCreate(Keys.themeMode, mode);
      ProgressStore.applyThemeMode(mode);

      // ★ 2026-10-13：语言 / 主题色恢复 —— 走 preferences（与进度同一个库）
      //   为什么不用 PersistentStorage：模拟器实测「写进去 ✅、重启读不回来 ✗」
      //   （文件里存着 zh-Hant，#EF4444 也在，但启动后 UI 仍是默认值；而且它会在启动时把文件覆盖回默认）
      //   这条 preferences 通道就是存进度的同一条，实测跨重启可靠。
      const savedLang: string = p.getSync('lang', '') as string;
      if (savedLang.length > 0) {
        I18n.set(savedLang);
      } else {
        // ★★★ 2026-10-17 20:1x：用户还没选过语言 ⇒ 首启跟随系统语言（原来一律中文）
        I18n.set(I18n.detectSystemLang());
      }
      const savedAccent: string = p.getSync('accent', '') as string;
      if (savedAccent.length > 0) {
        Accent.set(savedAccent);
      }
      ProgressStore.ready = true;
    } catch (e) {
      // 兜底：内存态也要能跑（持久化失败不该让 app 起不来）
      AppStorage.setOrCreate(Keys.xp, 0);
      AppStorage.setOrCreate(Keys.level, 1);
      AppStorage.setOrCreate(Keys.totalSolved, 0);
      AppStorage.setOrCreate(Keys.superStreak, 0);
      AppStorage.setOrCreate(Keys.bestStreak, 0);
      AppStorage.setOrCreate(Keys.solvedToday, false);
      AppStorage.setOrCreate(Keys.dailyCount, 0);
      AppStorage.setOrCreate(Keys.themeDark, false);
    }
  }

  // ---------- 等级数学 ----------

  static levelOf(xp: number): number {
    if (xp <= 0) {
      return 1;
    }
    const l: number = Math.floor(Math.pow(xp / 100, 1 / 2.04)) + 1;
    return Math.min(100, Math.max(1, l));
  }

  static xpForLevel(level: number): number {
    if (level <= 1) {
      return 0;
    }
    if (level >= 100) {
      return 1000000;
    }
    return Math.floor(100 * Math.pow(level - 1, 2.04));
  }

  /** 当前等级内的进度 0~1（进度条用） */
  static levelProgress(xp: number): number {
    const lv: number = ProgressStore.levelOf(xp);
    const lo: number = ProgressStore.xpForLevel(lv);
    const hi: number = ProgressStore.xpForLevel(lv + 1);
    if (hi <= lo) {
      return 1;
    }
    const p: number = (xp - lo) / (hi - lo);
    return Math.min(1, Math.max(0, p));
  }

  /** 距下一级还差多少 XP */
  static xpToNext(xp: number): number {
    const lv: number = ProgressStore.levelOf(xp);
    return Math.max(0, ProgressStore.xpForLevel(lv + 1) - xp);
  }

  // ---------- 结算 ----------

  /**
   * 一局结束。**只有 solved 才加 XP、才算打卡**。
   * @returns 本次获得的 XP（用于结算弹窗展示）
   */
  static finishGame(gameId: string, solved: boolean, baseXp: number, difficultyFactor: number,
                    score: number = 0, durationMs: number = 0): number {
    const today: string = ProgressStore.today();

    // ⓪ 统计记账（每局都记，不论输赢）
    ProgressStore.recordPlay(gameId, score, durationMs);

    // ⓪' 今日挑战：完成了给额外经验
    let dailyBonus: number = 0;
    if (solved) {
      dailyBonus = ProgressStore.markDaily(gameId);
      ProgressStore.markCleared(gameId);
    }

    // ① 每个游戏自己的连胜
    let gs: GameStreak | undefined = ProgressStore.streaks.get(gameId);
    if (!gs) {
      gs = { current: 0, lastDay: '', solvedToday: false };
    }
    const gap: number = ProgressStore.dayGap(gs.lastDay, today);
    if (solved && !gs.solvedToday) {
      gs.current = (gap === 1) ? gs.current + 1 : 1;
      gs.solvedToday = true;
      gs.lastDay = today;
    } else if (gs.lastDay !== today) {
      gs.solvedToday = false;
    }
    ProgressStore.streaks.set(gameId, gs);

    if (!solved) {
      ProgressStore.persistStreaks();
      // ★ 没通关也要结算成就 —— 否则「初次开局」「手熟」这类"玩过就算"的成就永远解不开
      //   （真踩过：玩完整整一局，成就墙还是 0/53）
      ProgressStore.lastNewAch = ProgressStore.checkAchievements();
      return 0;
    }

    // ② 全局打卡（今天第一次解出）
    const alreadyToday: boolean = AppStorage.get<boolean>(Keys.solvedToday) === true;
    let superStreak: number = AppStorage.get<number>(Keys.superStreak) ?? 0;
    if (!alreadyToday) {
      const lastDay: string = (ProgressStore.pref?.getSync('lastDay', '') as string) ?? '';
      const sgap: number = ProgressStore.dayGap(lastDay, today);
      superStreak = (sgap === 1) ? superStreak + 1 : 1;
      AppStorage.setOrCreate(Keys.solvedToday, true);
      AppStorage.setOrCreate(Keys.superStreak, superStreak);
      const best: number = AppStorage.get<number>(Keys.bestStreak) ?? 0;
      if (superStreak > best) {
        AppStorage.setOrCreate(Keys.bestStreak, superStreak);
      }
      // ★★★ 存储满时 putSync 会抛 ⇒ 兜住（内存态已更新，界面照常）
      try {
        ProgressStore.pref?.putSync('lastDay', today);
      } catch (e) {
      }
    }

    // ③ XP = 基数 × 难度 × 连胜加成（连胜越多给得越多，封顶 2×）
    const streakBonus: number = 1 + Math.min(1, superStreak * 0.1);
    const gained: number = Math.round(baseXp * difficultyFactor * streakBonus) + dailyBonus;

    const xp: number = (AppStorage.get<number>(Keys.xp) ?? 0) + gained;
    const totalSolved: number = (AppStorage.get<number>(Keys.totalSolved) ?? 0) + 1;
    const dailyCount: number = (AppStorage.get<number>(Keys.dailyCount) ?? 0) + 1;

    const oldLevel: number = AppStorage.get<number>(Keys.level) ?? 1;
    const newLevel: number = ProgressStore.levelOf(xp);
    AppStorage.setOrCreate('levelUpFrom', oldLevel);
    AppStorage.setOrCreate('levelUpTo', newLevel > oldLevel ? newLevel : 0);
    AppStorage.setOrCreate(Keys.xp, xp);
    AppStorage.setOrCreate(Keys.level, newLevel);
    if (newLevel > (AppStorage.get<number>('bestLevel') ?? 1)) {
      AppStorage.setOrCreate('bestLevel', newLevel);
    }
    AppStorage.setOrCreate(Keys.totalSolved, totalSolved);
    AppStorage.setOrCreate(Keys.dailyCount, dailyCount);

    // 本款连胜局数（单游戏连胜成就用）—— gs 就是本款刚更新后的连胜
    AppStorage.setOrCreate(Keys.streak, gs);
    // 满分通关：得分达到该局基准的 10 倍以上（各游戏分值口径不同，用相对值判定）
    if (solved && score > 0 && score >= baseXp * 10) {
      const pc: number = (AppStorage.get<number>('perfectCount') ?? 0) + 1;
      AppStorage.setOrCreate('perfectCount', pc);
      ProgressStore.putNumber('perfectCount', pc);
    }
    // 累计打卡天数
    const td: number = ProgressStore.totalDays() + 1;
    if (AppStorage.get<string>('lastDayCounted') !== ProgressStore.today()) {
      AppStorage.setOrCreate('lastDayCounted', ProgressStore.today());
      AppStorage.setOrCreate('totalDays', td);
      ProgressStore.putNumber('totalDays', td);
    }

    ProgressStore.persist(xp, totalSolved, superStreak);
    ProgressStore.persistStreaks();
    ProgressStore.checkAchievements();
    return gained;
  }

  /** 某游戏当前连胜（卡片角标用） */
  static streakOf(gameId: string): number {
    const gs: GameStreak | undefined = ProgressStore.streaks.get(gameId);
    return gs ? gs.current : 0;
  }

  /** 某游戏今天玩过没 */
  static playedToday(gameId: string): boolean {
    const gs: GameStreak | undefined = ProgressStore.streaks.get(gameId);
    return gs ? (gs.solvedToday && gs.lastDay === ProgressStore.today()) : false;
  }

  // ───────── 收藏 ─────────

  /** 收藏列表 */
  static favorites(): string[] {
    const raw: string = AppStorage.get<string>(Keys.favorites) ?? '';
    if (raw.length === 0) {
      return [];
    }
    return raw.split(',');
  }

  static isFavorite(gameId: string): boolean {
    return ProgressStore.favorites().indexOf(gameId) >= 0;
  }

  /** 切换收藏，返回切换后是否已收藏 */
  static toggleFavorite(gameId: string): boolean {
    const list: string[] = ProgressStore.favorites();
    const i: number = list.indexOf(gameId);
    if (i >= 0) {
      list.splice(i, 1);
    } else {
      list.push(gameId);
    }
    const joined: string = list.join(',');
    AppStorage.setOrCreate(Keys.favorites, joined);
    ProgressStore.putString(Keys.favorites, joined);
    return i < 0;
  }

  // ───────── 最近玩过 ─────────

  /** 最近玩过的 gameId（最新的在前，最多 20 个） */
  static recent(): string[] {
    const raw: string = AppStorage.get<string>(Keys.recent) ?? '';
    if (raw.length === 0) {
      return [];
    }
    return raw.split(',');
  }

  private static pushRecent(gameId: string, cur: string[]): string {
    const out: string[] = [gameId];
    for (let i = 0; i < cur.length && out.length < 20; i++) {
      if (cur[i] !== gameId && cur[i].length > 0) {
        out.push(cur[i]);
      }
    }
    return out.join(',');
  }

  // ───────── 统计 ─────────

  static totalPlays(): number {
    return AppStorage.get<number>(Keys.totalPlays) ?? 0;
  }

  static totalMs(): number {
    return AppStorage.get<number>(Keys.totalMs) ?? 0;
  }

  /** 每款游戏的开局数 */
  static playsOf(gameId: string): number {
    try {
      const raw: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      return m[gameId] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /** 每款游戏的最高分 */
  static bestOf(gameId: string): number {
    try {
      const raw: string = AppStorage.get<string>(Keys.perGameBest) ?? '{}';
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      return m[gameId] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /** 玩过的不同游戏款数 */
  static playedKinds(): number {
    try {
      const raw: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      return Object.keys(m).length;
    } catch (e) {
      return 0;
    }
  }

  // ───────── 成就 ─────────

  /** 成就定义（id | emoji | 名称 | 说明）—— 判定条件写在 checkAchievements 里 */
  /** 等级称号（与 StatsCardAbility 里的口径一致） */
  static titleOf(l: number): string {
    if (l >= 60) {
      return '游戏宗师';
    }
    if (l >= 40) {
      return '解谜高手';
    }
    if (l >= 25) {
      return '益智达人';
    }
    if (l >= 15) {
      return '小有所成';
    }
    if (l >= 8) {
      return '渐入佳境';
    }
    if (l >= 3) {
      return '初窥门径';
    }
    return '新手上路';
  }

  static achievementList(): string[][] {
    return [
      // ── 入门 ──
      ['first_play', '🌱', '初次开局', '玩出你的第一局', 'First Game', 'Play your very first game'],
      ['first_solve', '🎉', '首次通关', '第一次通关', 'First Win', 'Clear a game for the first time'],
      ['ten_plays', '🕹️', '手熟', '玩满 10 局', 'Getting Warm', 'Play 10 games'],
      ['fifty_plays', '🎮', '常客', '玩满 50 局', 'Regular', 'Play 50 games'],
      ['two_hundred_plays', '🕹', '老玩家', '玩满 200 局', 'Veteran', 'Play 200 games'],
      ['thousand_plays', '🎰', '千局不倦', '玩满 1000 局', 'A Thousand Games', 'Play 1000 games'],

      // ── 广度（玩过多少款）──
      ['ten_kinds', '🎮', '博览群游', '玩过 10 款不一样的', 'Sampler', 'Try 10 different games'],
      ['fifty_kinds', '🗺️', '半百猎手', '玩过 50 款不一样的', 'Explorer', 'Try 50 different games'],
      ['hundred_kinds', '🎯', '百款猎手', '玩过 100 款不一样的', 'Century Hunter', 'Try 100 different games'],
      ['two_hundred_kinds', '🧭', '两百款巡礼', '玩过 200 款不一样的', 'Two Hundred Club', 'Try 200 different games'],
      ['all_kinds', '🌌', '全收集', '354 款一款不落', 'Completionist', 'Try all 354 games'],

      // ── 深度（通关多少）──
      ['solve_10', '🏆', '通关达人', '通关 10 局', 'Solver', 'Clear 10 games'],
      ['solve_100', '💯', '百局老手', '通关 100 局', 'Hundred Wins', 'Clear 100 games'],
      ['solve_500', '🏅', '五百胜', '通关 500 局', 'Five Hundred', 'Clear 500 games'],
      ['clear_30_kinds', '📚', '通关 30 款', '30 款都通关了', '30 Cleared', 'Clear 30 different games'],
      ['clear_100_kinds', '🏛️', '通关 100 款', '100 款都通关了', '100 Cleared', 'Clear 100 different games'],
      ['clear_all', '👑', '大满贯', '354 款全部通关', 'Grand Slam', 'Clear all 354 games'],

      // ── 打卡连胜 ──
      ['streak_3', '🔥', '三日连击', '连着 3 天来玩', 'Three in a Row', 'Come back 3 days running'],
      ['streak_7', '⚡', '七日连击', '连着 7 天来玩', 'Week Streak', 'Come back 7 days running'],
      ['streak_30', '🌟', '满月连击', '连着 30 天来玩', 'Full Month', 'Come back 30 days running'],
      ['streak_100', '☄️', '百日连击', '连着 100 天来玩', 'Hundred Days', 'Come back 100 days running'],
      ['days_30', '📅', '月度常客', '一共来了 30 天', 'Month Regular', 'Visit on 30 days'],
      ['days_100', '🗓️', '百日之约', '一共来了 100 天', 'Hundred Visits', 'Visit on 100 days'],

      // ── 等级 ──
      ['level_10', '📈', '小有所成', '等级到 10 级', 'Level 10', 'Reach level 10'],
      ['level_25', '🧗', '渐入佳境', '等级到 25 级', 'Level 25', 'Reach level 25'],
      ['level_50', '👑', '登峰造极', '等级到 50 级', 'Level 50', 'Reach level 50'],
      ['level_80', '🌠', '一代宗师', '等级到 80 级', 'Level 80', 'Reach level 80'],
      ['level_100', '🏔️', '满级', '满级啦（100 级）', 'Maxed Out', 'Reach level 100'],

      // ── 时长 ──
      ['hour_1', '🕐', '时间旅人', '一共玩了 1 小时', 'One Hour In', 'Play for a total of 1 hour'],
      ['hour_10', '⏳', '光阴似箭', '一共玩了 10 小时', 'Ten Hours', 'Play for a total of 10 hours'],
      ['hour_50', '🌗', '半百小时', '一共玩了 50 小时', 'Fifty Hours', 'Play for a total of 50 hours'],
      ['hour_100', '🌕', '百日之功', '一共玩了 100 小时', 'Hundred Hours', 'Play for a total of 100 hours'],

      // ── 收藏 ──
      ['fav_1', '⭐', '第一个收藏', '收藏第一个游戏', 'First Save', 'Save your first game'],
      ['fav_10', '💫', '收藏家', '收藏 10 款', 'Collector', 'Save 10 games'],
      ['fav_50', '✨', '珍藏家', '收藏 50 款', 'Curator', 'Save 50 games'],

      // ── 每日挑战 ──
      ['daily_1', '🎯', '挑战者', '完成一次今天这一局', 'Challenger', 'Finish one of the daily pick'],
      ['daily_7', '🏅', '挑战常客', '完成 7 次今天这一局', 'Daily Habit', 'Finish 7 of the daily pick'],
      ['daily_30', '🎖️', '挑战达人', '完成 30 次今天这一局', 'Daily Devotee', 'Finish 30 of the daily pick'],
      ['daily_100', '🏵️', '挑战之王', '完成 100 次今天这一局', 'Daily Legend', 'Finish 100 of the daily pick'],

      // ── 分类专精（玩遍某一类）──
      ['cat_classic', '🎲', '经典通', '玩过 30 款经典', 'Classic Buff', 'Play 30 classic games'],
      ['cat_logic', '🧩', '逻辑通', '玩过 30 款逻辑', 'Logic Buff', 'Play 30 logic games'],
      ['cat_math', '🧮', '算术通', '玩过 30 款数字', 'Number Buff', 'Play 30 number games'],
      ['cat_memory', '🧠', '记忆通', '玩过 40 款记忆', 'Memory Buff', 'Play 40 memory games'],
      ['cat_word', '🔤', '文字通', '玩过 30 款文字', 'Word Buff', 'Play 30 word games'],
      ['cat_spatial', '📐', '空间通', '玩过 40 款空间', 'Spatial Buff', 'Play 40 spatial games'],

      // ── 单游戏连胜 ──
      ['streak_game_5', '🎯', '五连霸', '同一个游戏连赢 5 局', 'Five Straight', 'Win 5 in a row in one game'],
      ['streak_game_10', '💥', '十连霸', '同一个游戏连赢 10 局', 'Ten Straight', 'Win 10 in a row in one game'],
      ['super_10', '🚀', '超级十连', '连着 10 天每天都通关', 'Ten-Day Run', 'Clear something 10 days running'],

      // ── 挑战类 ──
      ['night_owl', '🦉', '夜猫子', '凌晨 0–5 点还在玩', 'Night Owl', 'Playing between midnight and 5am'],
      ['early_bird', '🐦', '早起鸟', '清晨 5–7 点就开玩', 'Early Bird', 'Playing between 5am and 7am'],
      ['marathon', '🏃', '马拉松', '一天玩了 2 小时', 'Marathon', 'Play 2 hours in one day'],
      ['perfectionist', '💎', '完美主义', '拿过一次满分', 'Perfectionist', 'Score a perfect run'],
      ['explorer', '🧳', '探索者', '六大类各玩过 5 款以上', 'All-Rounder', 'Play 5+ games in every category']
    ];
  }

  static unlocked(): string[] {
    const raw: string = AppStorage.get<string>(Keys.achievements) ?? '';
    return raw.length === 0 ? [] : raw.split(',');
  }

  static isUnlocked(id: string): boolean {
    return ProgressStore.unlocked().indexOf(id) >= 0;
  }

  /** 每次开局后调：检查并解锁新成就，返回本次新解锁的成就名 */
  static checkAchievements(): string[] {
    const got: string[] = ProgressStore.unlocked();
    const newly: string[] = [];

    const level: number = AppStorage.get<number>(Keys.level) ?? 1;
    const solved: number = AppStorage.get<number>(Keys.totalSolved) ?? 0;
    const plays: number = ProgressStore.totalPlays();
    const streak: number = AppStorage.get<number>(Keys.superStreak) ?? 0;
    const gameStreak: number = AppStorage.get<number>(Keys.streak) ?? 0;
    const kinds: number = ProgressStore.playedKinds();
    const favs: number = ProgressStore.favorites().length;
    const hours: number = ProgressStore.totalMs() / 3600000;
    const daily: number = AppStorage.get<number>('dailyTotal') ?? 0;
    const cleared: string[] = ProgressStore.clearedGames();
    const clearedN: number = cleared.length;
    const days: number = ProgressStore.totalDays();
    const hour: number = new Date().getHours();
    const maxLv: number = AppStorage.get<number>('bestLevel') ?? level;

    // 六大门类各玩过几款
    const perCat: number[] = ProgressStore.kindsPerCategory();
    const catMin: number = Math.min(
      Math.min(perCat[0], perCat[1]), Math.min(perCat[2], perCat[3]),
      Math.min(perCat[4], perCat[5]));
    const catMax: number[] = perCat;

    const rules: string[][] = [
      ['first_play', plays >= 1 ? '1' : '0'],
      ['first_solve', solved >= 1 ? '1' : '0'],
      ['ten_plays', plays >= 10 ? '1' : '0'],
      ['fifty_plays', plays >= 50 ? '1' : '0'],
      ['two_hundred_plays', plays >= 200 ? '1' : '0'],
      ['thousand_plays', plays >= 1000 ? '1' : '0'],

      ['ten_kinds', kinds >= 10 ? '1' : '0'],
      ['fifty_kinds', kinds >= 50 ? '1' : '0'],
      ['hundred_kinds', kinds >= 100 ? '1' : '0'],
      ['two_hundred_kinds', kinds >= 200 ? '1' : '0'],
      ['all_kinds', kinds >= 354 ? '1' : '0'],

      ['solve_10', solved >= 10 ? '1' : '0'],
      ['solve_100', solved >= 100 ? '1' : '0'],
      ['solve_500', solved >= 500 ? '1' : '0'],
      ['clear_30_kinds', clearedN >= 30 ? '1' : '0'],
      ['clear_100_kinds', clearedN >= 100 ? '1' : '0'],
      ['clear_all', clearedN >= 354 ? '1' : '0'],

      ['streak_3', streak >= 3 ? '1' : '0'],
      ['streak_7', streak >= 7 ? '1' : '0'],
      ['streak_30', streak >= 30 ? '1' : '0'],
      ['streak_100', streak >= 100 ? '1' : '0'],
      ['days_30', days >= 30 ? '1' : '0'],
      ['days_100', days >= 100 ? '1' : '0'],

      ['level_10', maxLv >= 10 ? '1' : '0'],
      ['level_25', maxLv >= 25 ? '1' : '0'],
      ['level_50', maxLv >= 50 ? '1' : '0'],
      ['level_80', maxLv >= 80 ? '1' : '0'],
      ['level_100', maxLv >= 100 ? '1' : '0'],

      ['hour_1', hours >= 1 ? '1' : '0'],
      ['hour_10', hours >= 10 ? '1' : '0'],
      ['hour_50', hours >= 50 ? '1' : '0'],
      ['hour_100', hours >= 100 ? '1' : '0'],

      ['fav_1', favs >= 1 ? '1' : '0'],
      ['fav_10', favs >= 10 ? '1' : '0'],
      ['fav_50', favs >= 50 ? '1' : '0'],

      ['daily_1', daily >= 1 ? '1' : '0'],
      ['daily_7', daily >= 7 ? '1' : '0'],
      ['daily_30', daily >= 30 ? '1' : '0'],
      ['daily_100', daily >= 100 ? '1' : '0'],

      ['cat_classic', catMax[0] >= 30 ? '1' : '0'],
      ['cat_logic', catMax[1] >= 30 ? '1' : '0'],
      ['cat_math', catMax[2] >= 30 ? '1' : '0'],
      ['cat_memory', catMax[3] >= 40 ? '1' : '0'],
      ['cat_word', catMax[4] >= 30 ? '1' : '0'],
      ['cat_spatial', catMax[5] >= 40 ? '1' : '0'],

      ['streak_game_5', gameStreak >= 5 ? '1' : '0'],
      ['streak_game_10', gameStreak >= 10 ? '1' : '0'],
      ['super_10', streak >= 10 ? '1' : '0'],

      ['night_owl', (hour >= 0 && hour < 5) ? '1' : '0'],
      ['early_bird', (hour >= 5 && hour < 7) ? '1' : '0'],
      ['marathon', (AppStorage.get<number>('todayMs') ?? 0) >= 7200000 ? '1' : '0'],
      ['perfectionist', (AppStorage.get<number>('perfectCount') ?? 0) >= 1 ? '1' : '0'],
      ['explorer', catMin >= 5 ? '1' : '0']
    ];

    const all: string[][] = ProgressStore.achievementList();
    for (let i = 0; i < rules.length; i++) {
      const id: string = rules[i][0];
      if (rules[i][1] === '1' && got.indexOf(id) < 0) {
        got.push(id);
        for (let j = 0; j < all.length; j++) {
          if (all[j][0] === id) {
            // ★ ArkTS 不允许用变量下标取字段（arkts-no-props-by-index）⇒ 显式分支
            const row: string[] = all[j];
            const emoji: string = row[1];
            // ★ 2026-10-13（P4）：以前只判 isEN ⇒ 日语/韩语/西语… 的成就弹窗全是中文。
            //   现在：非中文系一律用英文列；繁体把简体名转成繁体；简体用原文。
            if (!I18n.isZH() && row.length >= 6) {
              newly.push(emoji + ' ' + row[4]);
            } else if (I18n.isHant()) {
              newly.push(emoji + ' ' + toTrad(row[2]));
            } else {
              newly.push(emoji + ' ' + row[2]);
            }
            break;
          }
        }
      }
    }
    if (newly.length > 0) {
      const joined: string = got.join(',');
      AppStorage.setOrCreate(Keys.achievements, joined);
      ProgressStore.putString(Keys.achievements, joined);
    }
    return newly;
  }

  /** 累计打卡天数 */
  static totalDays(): number {
    return AppStorage.get<number>('totalDays') ?? 0;
  }

  /** 六大门类各玩过多少款（下标对应 GameCategory 顺序） */
  static kindsPerCategory(): number[] {
    const raw: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
    const out: number[] = [0, 0, 0, 0, 0, 0];
    // perGamePlays 是 {id:次数}；这里按注册表分类统计"玩过至少一次"的款数
    for (let i = 0; i < GAME_IDS_BY_CAT.length; i++) {
      let n: number = 0;
      const ids: string[] = GAME_IDS_BY_CAT[i];
      for (let j = 0; j < ids.length; j++) {
        if (raw.indexOf('"' + ids[j] + '"') >= 0) {
          n++;
        }
      }
      out[i] = n;
    }
    return out;
  }

  // ───────── 每日挑战 ─────────

  /** 今日挑战是哪一款 —— 用日期做种子，同一天恒定（不随刷新变） */
  static dailyGameId(allIds: string[]): string {
    if (allIds.length === 0) {
      return '';
    }
    const d: string = ProgressStore.today();
    let h: number = 0;
    for (let i = 0; i < d.length; i++) {
      h = (h * 31 + d.charCodeAt(i)) % 1000003;
    }
    return allIds[h % allIds.length];
  }

  /** 今日挑战是否已完成 */
  static dailyDoneToday(): boolean {
    const day: string = AppStorage.get<string>(Keys.dailyGame) ?? '';
    return day === ProgressStore.today() && (AppStorage.get<boolean>(Keys.dailyDone) ?? false);
  }

  /** 今日挑战的游戏 id（ensureDaily 之后有效） */
  static dailyPick(): string {
    return AppStorage.get<string>('dailyPick') ?? '';
  }

  /** 每天第一次打开时定下今日挑战 */
  static ensureDaily(allIds: string[]): void {
    const today: string = ProgressStore.today();
    const day: string = AppStorage.get<string>(Keys.dailyGame) ?? '';
    if (day === today) {
      return;
    }
    const gid: string = ProgressStore.dailyGameId(allIds);
    AppStorage.setOrCreate(Keys.dailyGame, today);
    AppStorage.setOrCreate('dailyPick', gid);
    AppStorage.setOrCreate(Keys.dailyDone, false);
    AppStorage.setOrCreate(Keys.dailyBonus, 0);
    ProgressStore.putString(Keys.dailyGame, today);
  }

  /** 标记今日挑战完成，返回奖励 XP（没完成/已领过 ⇒ 0） */
  private static markDaily(gameId: string): number {
    const today: string = ProgressStore.today();
    const day: string = AppStorage.get<string>(Keys.dailyGame) ?? '';
    if (day !== today || ProgressStore.dailyDoneToday()) {
      return 0;
    }
    if (ProgressStore.dailyPick() !== gameId) {
      return 0;   // 今天玩的不是挑战那款
    }
    AppStorage.setOrCreate(Keys.dailyDone, true);
    const bonus: number = 50;
    AppStorage.setOrCreate(Keys.dailyBonus, bonus);
    ProgressStore.putString(Keys.dailyDone, 'true');
    const dt: number = (AppStorage.get<number>('dailyTotal') ?? 0) + 1;
    AppStorage.setOrCreate('dailyTotal', dt);
    ProgressStore.putNumber('dailyTotal', dt);
    return bonus;
  }

  // ───────── 每游戏徽章 ─────────

  /** 通关过的游戏 id 列表 */
  static clearedGames(): string[] {
    const raw: string = AppStorage.get<string>(Keys.cleared) ?? '';
    return raw.length === 0 ? [] : raw.split(',');
  }

  /** 这款通关过吗（→ 徽章墙上亮不亮） */
  static hasCleared(gameId: string): boolean {
    return ProgressStore.clearedGames().indexOf(gameId) >= 0;
  }

  /** 记一次通关（每款只记一次） */
  private static markCleared(gameId: string): void {
    // ★ 分级成就：每次通关都累加（不是只记第一次）
    ProgressStore.bumpClears(gameId);
    if (ProgressStore.hasCleared(gameId)) {
      return;
    }
    const list: string[] = ProgressStore.clearedGames();
    list.push(gameId);
    const joined: string = list.join(',');
    AppStorage.setOrCreate(Keys.cleared, joined);
    ProgressStore.putString(Keys.cleared, joined);
  }

  // ───────── 每游戏难度（奥森 2026-10-11 要求）─────────
  //
  //  三档：0 简单 / 1 普通 / 2 困难
  //  · 记忆在本地（每款各记各的，下次进来自动用上次那档）
  //  · 影响：① 经验倍率 ×0.8 / ×1.0 / ×1.4
  //          ② 游戏可以读它来改初始条件（时限、棋盘大小、生命数…）

  /** 难度档位数 */
  static readonly DIFF_COUNT: number = 3;

  /** 各档的名字（中/英） */
  static readonly DIFF_NAME: string[][] = [
    ['简单', 'Easy'], ['普通', 'Normal'], ['困难', 'Hard']
  ];

  /** 各档的经验倍率 */
  static readonly DIFF_XP: number[] = [0.8, 1.0, 1.4];

  /** 这款游戏当前选的难度（0/1/2，默认 1 普通） */
  static diffOf(gameId: string): number {
    const raw: string = AppStorage.get<string>(Keys.perGameDiff) ?? '{}';
    try {
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      const v: number = m[gameId] ?? 1;
      return (v >= 0 && v < ProgressStore.DIFF_COUNT) ? v : 1;
    } catch (e) {
      return 1;
    }
  }

  /** 切这款游戏的难度 */
  static setDiff(gameId: string, d: number): void {
    const raw: string = AppStorage.get<string>(Keys.perGameDiff) ?? '{}';
    let m: Record<string, number> = {};
    try {
      m = JSON.parse(raw) as Record<string, number>;
    } catch (e) {
      m = {};
    }
    m[gameId] = d;
    const j: string = JSON.stringify(m);
    AppStorage.setOrCreate(Keys.perGameDiff, j);
    ProgressStore.putString(Keys.perGameDiff, j);
  }

  // ───────── 每游戏分级成就（奥森 2026-10-11 要求）─────────
  //
  //  每款游戏 4 档，不是只有一个"通关过"徽章：
  //    ① 首通   通关 1 次
  //    ② 熟练   通关 10 次
  //    ③ 精通   通关 50 次
  //    ④ 大师   通关 100 次
  //  354 款 × 4 档 = 1416 枚，所以**不塞进成就墙**（会撑爆），
  //  而是：① 在每款游戏的玩法说明页显示它的 4 档进度；② 统计页只显示总进度 x/1416。

  /** 4 档的门槛 */
  static readonly TIER_NEED: number[] = [1, 10, 50, 100];
  static readonly TIER_NAME: string[][] = [
    ['首通', 'First Clear'], ['熟练', 'Skilled'], ['精通', 'Expert'], ['大师', 'Master']
  ];

  /** 某款游戏通关了几次 */
  static clearsOf(gameId: string): number {
    const raw: string = AppStorage.get<string>(Keys.perGameClears) ?? '{}';
    try {
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      return m[gameId] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /** 某款游戏解锁到第几档（0 = 一档都没到，4 = 四档全开） */
  static tierOf(gameId: string): number {
    const n: number = ProgressStore.clearsOf(gameId);
    let t: number = 0;
    for (let i = 0; i < ProgressStore.TIER_NEED.length; i++) {
      if (n >= ProgressStore.TIER_NEED[i]) {
        t = i + 1;
      }
    }
    return t;
  }

  /** 全应用一共点亮了多少枚分级徽章 / 1416 */
  static tierTotal(): number {
    const raw: string = AppStorage.get<string>(Keys.perGameClears) ?? '{}';
    let sum: number = 0;
    try {
      const m: Record<string, number> = JSON.parse(raw) as Record<string, number>;
      const keys: string[] = Object.keys(m);
      for (let i = 0; i < keys.length; i++) {
        const n: number = m[keys[i]];
        for (let k = 0; k < ProgressStore.TIER_NEED.length; k++) {
          if (n >= ProgressStore.TIER_NEED[k]) {
            sum++;
          }
        }
      }
    } catch (e) {
      sum = 0;
    }
    return sum;
  }

  /** 记一次通关次数 */
  private static bumpClears(gameId: string): void {
    const raw: string = AppStorage.get<string>(Keys.perGameClears) ?? '{}';
    let m: Record<string, number> = {};
    try {
      m = JSON.parse(raw) as Record<string, number>;
    } catch (e) {
      m = {};
    }
    m[gameId] = (m[gameId] ?? 0) + 1;
    const j: string = JSON.stringify(m);
    AppStorage.setOrCreate(Keys.perGameClears, j);
    ProgressStore.putString(Keys.perGameClears, j);
  }

  /** 徽章墙进度：通关过的款数 / 354 */
  static badgeProgress(): number {
    return ProgressStore.clearedGames().length;
  }

  /** 一键重置全部进度（设置页用）—— 含内存里的连胜 Map，否则旧连胜会被写回磁盘 */
  static resetAll(): void {
    ProgressStore.streaks.clear();
    if (ProgressStore.pref !== null) {
      const pr: preferences.Preferences = ProgressStore.pref;
      try {
        pr.clearSync();
        pr.flushSync();
      } catch (e) {
        // ★★★ 清库失败就退回逐键清 —— ★ 这里本身也要兜：存储满时逐键清照样会抛
        //   （原来 catch 里的 putSync 无保护 ⇒ 在 catch 里再抛 ⇒ 直接崩）
        try {
          pr.putSync(Keys.xp, 0);
          pr.putSync(Keys.totalSolved, 0);
          pr.putSync(Keys.superStreak, 0);
          pr.putSync(Keys.bestStreak, 0);
          pr.putSync(Keys.favorites, '');
          pr.putSync(Keys.recent, '');
          pr.putSync(Keys.totalPlays, 0);
          pr.putSync(Keys.totalMs, 0);
          pr.putSync(Keys.perGamePlays, '{}');
          pr.putSync(Keys.perGameBest, '{}');
          pr.putSync('streaks', '{}');
          pr.flush();
        } catch (e2) {
          // 逐键清也失败 ⇒ 内存态已清（上面 AppStorage.setOrCreate 会执行），界面是干净的
        }
      }
    }
    AppStorage.setOrCreate(Keys.xp, 0);
    AppStorage.setOrCreate(Keys.totalSolved, 0);
    AppStorage.setOrCreate(Keys.superStreak, 0);
    AppStorage.setOrCreate(Keys.bestStreak, 0);
    AppStorage.setOrCreate(Keys.level, 1);
    AppStorage.setOrCreate(Keys.solvedToday, false);
    AppStorage.setOrCreate(Keys.dailyCount, 0);
    AppStorage.setOrCreate(Keys.favorites, '');
    AppStorage.setOrCreate(Keys.recent, '');
    AppStorage.setOrCreate(Keys.totalPlays, 0);
    AppStorage.setOrCreate(Keys.totalMs, 0);
    AppStorage.setOrCreate(Keys.perGamePlays, '{}');
    AppStorage.setOrCreate(Keys.perGameBest, '{}');
    AppStorage.setOrCreate(Keys.dailyGame, '');
    AppStorage.setOrCreate('dailyPick', '');
    AppStorage.setOrCreate(Keys.dailyDone, false);
    AppStorage.setOrCreate(Keys.dailyBonus, 0);
    AppStorage.setOrCreate('dailyTotal', 0);
    AppStorage.setOrCreate(Keys.achievements, '');
    AppStorage.setOrCreate(Keys.cleared, '');
    AppStorage.setOrCreate(Keys.perGameClears, '{}');
    AppStorage.setOrCreate(Keys.perGameDiff, '{}');
    AppStorage.setOrCreate('bestLevel', 1);
  }

  /**
   * 语言落盘（设置页/顶栏切语言时调）
   *
   * ★ 2026-10-13 模拟器实测：`PersistentStorage.persistProp` 在本工程**只写不读**
   *   —— 切完语言文件里确实有 `lang="zh-Hant"`，但 force-stop 重启后界面照旧是简体，
   *   而且它启动时会把文件覆盖回默认值。改成吃本类这条 preferences 通道（存进度用的同一条），
   *   由 `ProgressStore.init()` 在 UI 起来之前恢复。
   */
  static saveLang(lang: string): void {
    ProgressStore.putString('lang', lang);
  }

  /** 主题色落盘（点色块时调）—— 同 saveLang 的理由 */
  static saveAccent(id: string): void {
    ProgressStore.putString('accent', id);
  }

  /**
   * ★ 隐私政策同意标记（2026-10-13 · AGC 上架硬要求）
   *   首次启动弹一次；同意后写 '1'，之后不再弹。
   *   ⚠️ **同意之前不许有任何网络请求** —— 游戏本身纯离线，联网只发生在对局区的局域网对战
  *   与华为游戏服务账号校验（两者都在同意之后才可触发），
   *      但**局域网对战**的 UDP socket 必须在同意之后才允许创建（见 Lan.ets 的守卫）。
   */
  static savePrivacyAgreed(): void {
    ProgressStore.putString('privacyAgreed', '1');
  }

  /** 读同意标记；返回 true 表示已同意（或用户在旧版本已用过 ⇒ 视为已同意） */
  static privacyAgreed(): boolean {
    const pr: preferences.Preferences | null = ProgressStore.pref;
    if (pr === null) {
      // ★ 2026-10-13 实测修正：init() 是**异步**的 ⇒ 首次读取时 pref 可能还是 null。
      //   原来这里 return true（"别打扰老用户"）⇒ **导致全新安装也不弹窗** ✗（合规风险）
      //   ⇒ 改成 return false：**宁可多弹一次，也不能漏掉"首次启动征求同意"**
      //     （用户点过同意后就有标记了，第二次起正常走 false 分支之外）
      return false;
    }
    try {
      const v: string = pr.getSync('privacyAgreed', '') as string;
      return v === '1';
    } catch (e) {
      return false;
    }
  }

  private static putString(key: string, value: string): void {
    // 直接落盘（preferences 句柄在 init 时拿到）
    const pr: preferences.Preferences | null = ProgressStore.pref;
    if (pr !== null) {
      // ★★★ 2026-10-17 21:0x 真 BUG 修复（判据④「存储不足」）：
      //   putSync/flush 在【存储满】时会抛 BusinessError ⇒ 未捕获 ⇒ app 崩
      //   ⇒ 所有落盘一律 try/catch【静默失败】：内存态已经更新，界面照常可用
      try {
        pr.putSync(key, value);
        pr.flush();
      } catch (e) {
        // 写不进去就算了 —— 用户这一局照样能玩完，只是下次启动丢了这条记录
      }
    }
  }

  /** 每局都调：记开局数、时长、最高分、最近玩过 */
  private static recordPlay(gameId: string, score: number, durationMs: number): void {
    const plays: number = ProgressStore.totalPlays() + 1;
    AppStorage.setOrCreate(Keys.totalPlays, plays);
    ProgressStore.putNumber(Keys.totalPlays, plays);

    const ms: number = ProgressStore.totalMs() + (durationMs > 0 ? durationMs : 0);
    AppStorage.setOrCreate(Keys.totalMs, ms);
    ProgressStore.putNumber(Keys.totalMs, ms);
    // 单日累计（马拉松成就用）
    const todayMs: number = (AppStorage.get<number>('todayMs') ?? 0) + durationMs;
    AppStorage.setOrCreate('todayMs', todayMs);

    // 每款开局数
    try {
      const rawP: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
      const mp: Record<string, number> = JSON.parse(rawP) as Record<string, number>;
      mp[gameId] = (mp[gameId] ?? 0) + 1;
      const jp: string = JSON.stringify(mp);
      AppStorage.setOrCreate(Keys.perGamePlays, jp);
      ProgressStore.putString(Keys.perGamePlays, jp);

      // 每款最高分
      const rawB: string = AppStorage.get<string>(Keys.perGameBest) ?? '{}';
      const mb: Record<string, number> = JSON.parse(rawB) as Record<string, number>;
      if (score > (mb[gameId] ?? 0)) {
        mb[gameId] = score;
        const jb: string = JSON.stringify(mb);
        AppStorage.setOrCreate(Keys.perGameBest, jb);
        ProgressStore.putString(Keys.perGameBest, jb);
      }
    } catch (e) {
      // 解析失败就当第一次，不阻塞游戏
    }

    // 最近玩过
    const rj: string = ProgressStore.pushRecent(gameId, ProgressStore.recent());
    AppStorage.setOrCreate(Keys.recent, rj);
    ProgressStore.putString(Keys.recent, rj);

    // 首次使用日期
    const fd: string = AppStorage.get<string>(Keys.firstDay) ?? '';
    if (fd.length === 0) {
      AppStorage.setOrCreate(Keys.firstDay, ProgressStore.today());
      ProgressStore.putString(Keys.firstDay, ProgressStore.today());
    }
  }

  private static putNumber(key: string, value: number): void {
    const pr: preferences.Preferences | null = ProgressStore.pref;
    if (pr !== null) {
      // ★★★ 同上：存储满时 putSync 会抛 ⇒ 静默失败
      try {
        pr.putSync(key, value);
        pr.flush();
      } catch (e) {
      }
    }
  }

  // ───────── 外观模式（三态） ─────────

  /** 用户选的是哪一态：light / dark / system（默认 system） */
  static themeMode(): string {
    return AppStorage.get<string>(Keys.themeMode) ?? 'system';
  }

  /** 选外观模式。system ⇒ 立刻按当前系统深浅解析 */
  static setThemeMode(mode: string): void {
    AppStorage.setOrCreate(Keys.themeMode, mode);
    ProgressStore.putString(Keys.themeMode, mode);
    ProgressStore.applyThemeMode(mode);
    // 通知系统：跟随系统时才让系统接管状态栏等
    try {
      const ctx = getContext();
      const cm = ctx.getApplicationContext();
      if (mode === 'dark') {
        cm.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === 'light') {
        cm.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        cm.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (e) {
      // 拿不到 context 就只改应用内部主题，不影响使用
    }
  }

  /** 把三态解析成实际深浅，写进 themeDark（UI 只读 themeDark） */
  static applyThemeMode(mode: string): void {
    if (mode === 'dark') {
      AppStorage.setOrCreate(Keys.themeDark, true);
      return;
    }
    if (mode === 'light') {
      AppStorage.setOrCreate(Keys.themeDark, false);
      return;
    }
    // system：读系统当前深浅
    AppStorage.setOrCreate(Keys.themeDark, ProgressStore.systemIsDark());
  }

  /** 系统当前是不是深色 */
  static systemIsDark(): boolean {
    // 由 EntryAbility 在启动与 onConfigurationUpdate 时写入
    return AppStorage.get<boolean>('systemDark') ?? false;
  }

  /** 兼容旧接口：直接切深浅 = 选 light/dark 那一态 */
  static setThemeDark(dark: boolean): void {
    ProgressStore.setThemeMode(dark ? 'dark' : 'light');
  }

  // ---------- 落盘 ----------

  private static persist(xp: number, totalSolved: number, superStreak: number): void {
    const p = ProgressStore.pref;
    if (!p) {
      return;
    }
    // ★★★ 存储满时 putSync 会抛 ⇒ 静默失败（内存态已更新）
    try {
      p.putSync(Keys.xp, xp);
      p.putSync(Keys.totalSolved, totalSolved);
      p.putSync(Keys.superStreak, superStreak);
      p.putSync(Keys.bestStreak, AppStorage.get<number>(Keys.bestStreak) ?? 0);
      p.flush();
    } catch (e) {
    }
  }

  private static persistStreaks(): void {
    const p = ProgressStore.pref;
    if (!p) {
      return;
    }
    const obj: Record<string, GameStreak> = {};
    ProgressStore.streaks.forEach((v: GameStreak, k: string) => {
      obj[k] = v;
    });
    // ★★★ 存储满时 putSync 会抛 ⇒ 静默失败（内存态已更新）
    try {
      p.putSync('streaks', JSON.stringify(obj));
      p.flush();
    } catch (e) {
    }
  }

  // ---------- 日期工具 ----------

  static today(): string {
    const d: Date = new Date();
    const m: string = (d.getMonth() + 1 < 10 ? '0' : '') + (d.getMonth() + 1);
    const day: string = (d.getDate() < 10 ? '0' : '') + d.getDate();
    return d.getFullYear() + '-' + m + '-' + day;
  }

  /** 两个 YYYY-MM-DD 相差几天；a 为空返回一个大数 */
  private static dayGap(a: string, b: string): number {
    if (!a) {
      return 999;
    }
    const pa: string[] = a.split('-');
    const pb: string[] = b.split('-');
    if (pa.length !== 3 || pb.length !== 3) {
      return 999;
    }
    const ta: number = new Date(Number(pa[0]), Number(pa[1]) - 1, Number(pa[2])).getTime();
    const tb: number = new Date(Number(pb[0]), Number(pb[1]) - 1, Number(pb[2])).getTime();
    return Math.round((tb - ta) / 86400000);
  }
}
