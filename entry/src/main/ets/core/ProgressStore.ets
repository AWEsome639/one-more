/**
 * 进度系统 —— XP / 等级 / 每日打卡 / 双层连胜
 *
 * 等级公式：**已搬到 `core/LevelCurve.ets`（唯一真相源）**
 *   level = clamp(floor((xp/100)^(1/EXP)) + 1, 1, 100)，EXP = **1.3**（2026-11-08 由 2.04 下调）
 *   反解 XP 门槛：xpForLevel(l) = ceil(100 × (l−1)^1.3)
 *   ⇒ 早期升级快（正反馈），后期拉长（耐玩），100 级封顶
 *   ⚠️ 为什么下调：指数 2.04（≈平方增长）下 100 级要 ≈98,000 局 ⇒
 *      `level_80`/`level_100` 两个成就**数学上不可达**。1.3 下是 ≈3,274 局。
 *   ⚠️ 桌面卡片也调同一份数学（`formwidget/StatsCardAbility` → `LevelCurve`），别再各写一遍。
 *
 * 双层连胜：
 *   ① 每个游戏自己的 streak（连续几天玩了这个游戏）
 *   ② 全局 superStreak —— **当天任意解出一局** 就 +1；断一天归 1
 *
 * 持久化：@kit.ArkData 的 preferences（键值对，够用且零依赖）
 * 响应式：状态写进 AppStorage，组件用 @StorageProp/@StorageLink 读
 */

import { HintCost } from './HintCost';
import { GAME_IDS_BY_CAT } from './GameRegistry';
import { I18n, toTrad } from './I18n';
import { Accent } from './Design';
// ★★★ 2026-11-08（成就体系巡检 P0-1）：**等级曲线单一真相源**（桌面卡片也引它）
import { LevelCurve } from './LevelCurve';
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'onemore_progress';
/** ★ 2026-10-25 旧库名。只用于**一次性迁移**：开机时把旧库整库搬到新库，搬完删旧库。
 *   ⚠️ 不许再往这里写数据；迁移失败也绝不影响启动。 */
const LEGACY_STORE: string = 'yiju_progress';
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
  // ★★★ 2026-11-08（成就体系巡检 P1）：**删掉死键 `perfectGames`**
  //   它从声明那天起就是死的 —— 全库只有这一行声明，**没有任何地方读或写**。
  //   后果：玩家/后来人都以为"每款都有 💎 徽章"，实际只有**全局**一个 `perfectCount`
  //   （≥1 就解锁「完美主义 💎」，之后再无任何反馈）。
  //   ⇒ 与其留一个骗人的键，不如删掉；真要做「每款独立 💎」，请**端到端**实现：
  //     在 `finishGame` 的 perfect 分支里 append gameId（去重）+ 游戏卡上渲染 →
  //     两处一起做，别只加键（那又会变成死键）。
  static readonly perGameClears: string = 'perGameClears'; // 每款通关次数 JSON
  static readonly perGameDiff: string = 'perGameDiff';     // 每款选的难度 JSON
  /** ★ 2026-11-08（退出恢复最小版）：上次玩到哪 —— gameId → { level, diff, at } 的 JSON */
  static readonly lastWhere: string = 'lastWhere';
}

/** 单个游戏的连胜记录 */
interface GameStreak {
  current: number;
  lastDay: string;   // YYYY-MM-DD
  solvedToday: boolean;
}

/** ★ 2026-11-08（退出恢复最小版）：「上次玩到哪」的一条记录 */
export interface LastWhere {
  level: number;   // 0 基或 1 基由各游戏自定，只要求">0 = 有进度可续"
  diff: string;    // 难度标识（多数款用 String(GameDiff.of(id))，用不上就 ''）
  at: number;      // 写入时间戳（排查"为什么续到这一关"时看）
}

export class ProgressStore {
  /** ★ 2026-11-01（第 818 轮）：上一局是否刷新了该游戏的最高分。
   *  由 `finishGame` 写入，结算弹窗读取 —— 让「新纪录」能被庆祝。
   *  用静态字段而不是改 `finishGame` 的返回值：355 款都在调它，改签名会动到全部调用点。 */
  /** ★ 2026-11-01（第 830 轮）：**游戏总数改成动态的**。
   *
   *  真机审计发现两处写死 354：
   *    ① 成就文案「354 款一款不落」/「354 款全部通关」
   *    ② **成就判定阈值** `kinds >= 354` / `clearedN >= 354`
   *  而 `GAMES.length` 实际是 **355**（新增一款后没同步）。
   *  ⇒ 后果不只是文案矛盾：**玩过 354 款就算"全收集"**，第 355 款没玩也解锁。
   *  ⇒ 根因：数字被抄进两处而非从唯一来源派生。
   *  ★ 判据：**"总数"这类数字，全项目只能有一个来源** —— 这里就是 `GAMES.length`。
   */
  static totalGames(): number {
    let n: number = 0;
    for (let i = 0; i < GAME_IDS_BY_CAT.length; i++) {
      n += GAME_IDS_BY_CAT[i].length;
    }
    return n;
  }

  static lastWasBest: boolean = false;
  /** 刷新前的最高分（用于显示「1200 → 1980」的进步幅度） */
  static prevBest: number = 0;


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
  /** ★ 2026-11-08：本进程已经"恢复过一次"的游戏（见 shouldRestoreNow） */
  private static restored: string[] = [];

  /** ★ 一次性迁移：旧库 yiju_progress → 新库 onemore_progress（搬完删旧库） */
  private static async migrateLegacy(ctx: common.UIAbilityContext,
                                     dest: preferences.Preferences): Promise<void> {
    try {
      const old: preferences.Preferences = await preferences.getPreferences(ctx, LEGACY_STORE);
      const allRaw: Object = old.getAllSync();
      const all: Record<string, Object> = allRaw as Record<string, Object>;
      const keys: string[] = Object.keys(all);
      if (keys.length === 0) {
        return;
      }
      const curRaw: Object = dest.getAllSync();
      const cur: Record<string, Object> = curRaw as Record<string, Object>;
      if (Object.keys(cur).length > 0) {
        return;                       // 新库已有数据 ⇒ 不覆盖
      }
      for (let i = 0; i < keys.length; i++) {
        dest.putSync(keys[i], all[keys[i]] as preferences.ValueType);
      }
      await dest.flush();
      await preferences.deletePreferences(ctx, LEGACY_STORE);
    } catch (e) {
      // 迁移失败不影响启动（旧库留着，数据还在）
    }
  }

  /** 应用启动时调一次 */
  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (ProgressStore.ready) {
      return;
    }
    try {
      ProgressStore.pref = await preferences.getPreferences(ctx, STORE_NAME);
      const p = ProgressStore.pref;
      await ProgressStore.migrateLegacy(ctx, p);   // ★ 旧库搬家（只在第一次有活干）

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

      // ═════════════════════════════════════════════════════════════════════
      // ★★★ 2026-11-05（第 1339 轮）**修 13 个 key「写了盘却从不读回」**
      //
      // 为什么必须补（判据 878/879）：
      //   这些 key 的写入端都是 `AppStorage.setOrCreate` + `putString`（**写盘成功**），
      //   但读取端全是 `AppStorage.get<…>`（**只读内存**），
      //   而 `init()` 里**从来没有**把这些 key 从磁盘读回 AppStorage
      //   ⇒ **当次会话可用，重启即失**
      //
      // 实证（第 1337 → 1338 轮）：
      //   第 1337 轮：点游戏内 ⭐ ⇒ 首页「收藏 · 1」，收藏列表 1 张卡 card-bejeweled
      //   第 1338 轮重启后：**「收藏 · 0」，0 张卡** ⇒ 收藏丢了
      //
      // 影响范围（这 13 个正好是「玩家的全部进度」）：
      //   收藏 / 成就 / 通关记录 / 每款最高分 / 每款通关次数 /
      //   每款难度 / 每款游玩次数 / 最近游玩 / 今日推荐 / 今日已完成 /
      //   首玩日 / 总时长 / 总局数
      //   ⇒ **玩家第二天打开，什么都不在了**
      //
      // 默认值按「读取点用的类型」定（不是按写入点）：
      //   · `AppStorage.get<string>(…) ?? ''`     ⇒ 默认 `''`
      //   · `AppStorage.get<string>(…) ?? '{}'`   ⇒ 默认 `'{}'`
      //   · `AppStorage.get<boolean>(…) ?? false` ⇒ 默认 `false`
      //   · `AppStorage.get<number>(…) ?? 0`      ⇒ 默认 `0`
      // ⚠️ 特别注意 `Keys.cleared` 的**存储名是 `'clearedGames'`**（不是 'cleared'）
      // ═════════════════════════════════════════════════════════════════════
      const favRaw: string = p.getSync(Keys.favorites, '') as string;
      AppStorage.setOrCreate(Keys.favorites, favRaw);
      const recentRaw: string = p.getSync(Keys.recent, '') as string;
      AppStorage.setOrCreate(Keys.recent, recentRaw);
      const clearedRaw: string = p.getSync(Keys.cleared, '') as string;
      AppStorage.setOrCreate(Keys.cleared, clearedRaw);
      const achRaw: string = p.getSync(Keys.achievements, '') as string;
      AppStorage.setOrCreate(Keys.achievements, achRaw);
      const firstDayRaw: string = p.getSync(Keys.firstDay, '') as string;
      AppStorage.setOrCreate(Keys.firstDay, firstDayRaw);
      const dailyGameRaw: string = p.getSync(Keys.dailyGame, '') as string;
      AppStorage.setOrCreate(Keys.dailyGame, dailyGameRaw);
      // ★★★ 2026-11-05（第 1348 轮）：**`dailyPick` 原来完全没恢复**
      //   ⇒ 重启后 `dailyPick()` 返回 `''` ⇒ `markDaily` 的匹配检查永远失败
      //   ⇒ 「今日挑战」永远完不成（判据 918 的另一半）
      const dailyPickRaw: string = p.getSync('dailyPick', '') as string;
      AppStorage.setOrCreate('dailyPick', dailyPickRaw);
      const dailyBonusRaw: number = p.getSync(Keys.dailyBonus, 0) as number;
      AppStorage.setOrCreate(Keys.dailyBonus, dailyBonusRaw);
      const dailyDoneRaw: string = p.getSync(Keys.dailyDone, '') as string;
      AppStorage.setOrCreate(Keys.dailyDone, dailyDoneRaw === 'true');
      const bestRaw: string = p.getSync(Keys.perGameBest, '{}') as string;
      AppStorage.setOrCreate(Keys.perGameBest, bestRaw);
      const clearsRaw: string = p.getSync(Keys.perGameClears, '{}') as string;
      AppStorage.setOrCreate(Keys.perGameClears, clearsRaw);
      const diffRaw: string = p.getSync(Keys.perGameDiff, '{}') as string;
      AppStorage.setOrCreate(Keys.perGameDiff, diffRaw);
      // ★★★ 2026-11-08 真机 BUG 修复（ai-fixer-b 设备验收发现）：
      //   原来没把 `lastWhere` 从盘里装回 AppStorage ⇒ 两个后果：
      //     ① 重启后 `lastWhere()` 永远读不到 ⇒ **退出恢复完全不生效**；
      //     ② 更糟：`saveLastWhere()` 从空 map 开始写 ⇒ **一存档就把其他游戏的记录全冲掉**（实测 4 条 → 1 条）。
      //   ★ 判据：凡是"读 AppStorage 再整体写回 JSON"的 key，**必须**在 init 里装回来。
      const lastWhereRaw: string = p.getSync(Keys.lastWhere, '{}') as string;
      AppStorage.setOrCreate(Keys.lastWhere, lastWhereRaw);
      const playsRaw: string = p.getSync(Keys.perGamePlays, '{}') as string;
      AppStorage.setOrCreate(Keys.perGamePlays, playsRaw);
      const totalMsRaw: number = p.getSync(Keys.totalMs, 0) as number;
      AppStorage.setOrCreate(Keys.totalMs, totalMsRaw);
      const totalPlaysRaw: number = p.getSync(Keys.totalPlays, 0) as number;
      AppStorage.setOrCreate(Keys.totalPlays, totalPlaysRaw);
      // ★ 另补 2 个「getSync 读了但没 setOrCreate」（判据 879 的半缺口）
      AppStorage.setOrCreate('lastDay', lastDay);
      AppStorage.setOrCreate('streaks', rawStreaks);

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

  /**
   * XP → 等级（1~100）
   * ★★★ 2026-11-08：**数学搬去 `core/LevelCurve.ets`** —— 这里只留转发。
   *   为什么搬：原来这里 `xpForLevel(100)` 写死 `1000000`，而 `levelOf` 真到 100 要
   *   `1,177,866` ⇒ **非单调**（99 级门槛 1,153,722 > 100 级的 1,000,000）
   *   ⇒ `levelProgress()` 走进 `hi <= lo` ⇒ **99 级进度条永远满格**。
   *   现在两个函数从同一条曲线派生（指数 `LevelCurve.EXP = 1.3`），
   *   且 `levelOf(xpForLevel(L)) === L` 对 1~100 全部成立（我逐档验过）。
   */
  static levelOf(xp: number): number {
    return LevelCurve.levelOf(xp);
  }

  static xpForLevel(level: number): number {
    return LevelCurve.xpForLevel(level);
  }

  /** 当前等级内的进度 0~1（进度条用） */
  static levelProgress(xp: number): number {
    return LevelCurve.progress(xp);
  }

  /** 距下一级还差多少 XP */
  static xpToNext(xp: number): number {
    const lv: number = ProgressStore.levelOf(xp);
    return Math.max(0, ProgressStore.xpForLevel(lv + 1) - xp);
  }

  // ---------- 结算 ----------

  /**
   * ★★★ 2026-11-08（game-balancer）「完美主义 💎」的**逐款门槛**。
   *
   * 为什么需要：判定原来是 `score >= baseXp * 10`，而 `baseXp` 355 款**全是 12**
   *   ⇒ 等价于「**绝对 120 分**」。可各款分值口径天差地别（静态 40~1600、实测 400~10440），
   *   有 4 款**最高分到不了 120** ⇒ 那些款**永远拿不到 💎**
   *   （推导见 `_巡检记录/分数与XP-20261108.md` §5.3）。
   *   ⇒ 这 5 款各给一个「本款**普通档**可达」的门槛，其余仍 `baseXp × 10`。
   *
   * ⚠️ 门槛必须 ≤ 该款**普通档**的可达上限，否则等于没修（可达上限已逐款核过）：
   *   · `classic_maze`         `70 + max(0, dmax − steps×0.6)`，dmax=max(2.2×最短路, 3n)
   *                            2000 局/档实测「每局最高分」区间：简单 86~125 / **普通 96~186** / 困难 106~256
   *                            ⇒ 取 **90**：普通、困难**任何迷宫**都够；简单档多数够（短迷宫天花板 86~89，那几张拿不到）
   *   · `graph_coordinate_plot` `40 + step×6 − wrong×10`，step ≤ NEED=8 ⇒ 上限 88 ⇒ 取 80
   *   · `focus_tunnel`         `50 + lives×10`，lives = 5/3/2 ⇒ 上限 100 / 80 / 70 ⇒ 取 70（三档都够）
   *   · `fact_binder`          `60 + (5 − wrong)×10` ⇒ 上限 110 ⇒ 取 100
   *   · `box_completion`       `80 + max(0, 40 − moves×4)`，而生成器强制 `holes ∈ [3,6]`（GBoxCompletion.ets:104）
   *                            ⇒ 最少 moves = 洞数 ⇒ 按洞数分档上限：3洞 108 / 4洞 104 / 5洞 100 / 6洞 **96**
   *                            ⇒ 取 **95**（**任何盘面**都够；取 110 的话 6 洞盘面永远拿不到——那正是要修的 bug）
   *
   * ⚠️ 为什么用 if 链而不是 Map 常量：ArkTS 的静态 Map 只能先 `new Map()` 再 `.set()`
   *   （见 `GameLog.autoCache`），而**字段初始化器里放不了语句**；`new Map([[...]])` 的
   *   元组字面量在严格模式下不稳。if 链零分配、没有初始化顺序问题，5 行也够读。
   */
  private static perfectAt(gameId: string, baseXp: number): number {
    if (gameId === 'classic_maze') {
      return 90;
    }
    if (gameId === 'graph_coordinate_plot') {
      return 80;
    }
    if (gameId === 'focus_tunnel') {
      return 70;
    }
    if (gameId === 'fact_binder') {
      return 100;
    }
    if (gameId === 'box_completion') {
      return 95;
    }
    return baseXp * 10;
  }

  /**
   * 一局结束。**只有 solved 才加 XP、才算打卡**。
   * @returns 本次获得的 XP（用于结算弹窗展示）
   */
  static finishGame(gameId: string, solved: boolean, baseXp: number, difficultyFactor: number,
                    score: number = 0, durationMs: number = 0): number {
    const today: string = ProgressStore.today();

    // ⓪ 统计记账（每局都记，不论输赢）
    ProgressStore.recordPlay(gameId, score, durationMs, solved);

    // ⓪' 今日挑战：完成了给额外经验
    let dailyBonus: number = 0;
    if (solved) {
      dailyBonus = ProgressStore.markDaily(gameId);
      ProgressStore.markCleared(gameId);
    }

    // ① 每个游戏自己的连胜
    // ★ 2026-11-08 ArkTS 严格模式：`if (!gs)` 之后仍可能被判 undefined
    //   ⇒ 显式 `=== undefined` + 重新赋值（编译器才认窄化）
    let gs: GameStreak = { current: 0, lastDay: '', solvedToday: false };
    const found: GameStreak | undefined = ProgressStore.streaks.get(gameId);
    if (found !== undefined) {
      gs = found;
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
    // ★★★ 2026-11-05（第 1393 轮）**「完美」必须同时满足「没用过提示」**
    //   判据 1314/1315：审计发现提示**完全免费**（355 款 0 款记录次数），
    //   而部分提示**直接给答案**（「答案是 X」「解集是 X」）⇒ 点一下就能通关。
    //   而成就「完美主义 💎」原来只看「得分 ≥ 基准 ×10」⇒ 用过提示也能拿。
    //   ⇒ 现在要求 `hintsUsed === 0`。
    //   ⚠️ 计数是**局内**的：`take()` 读走并清零，不会串到下一局。
    const hintsUsed: number = HintCost.take();
    AppStorage.setOrCreate('lastHintsUsed', hintsUsed);
    // 满分通关：得分达到**本款的门槛**（各游戏分值口径不同 ⇒ 走 perfectAt() 查表）
    //   ★ 且这一局**一次提示都没用过**
    //   ★★★ 2026-11-08（game-balancer）：原来写死 `baseXp * 10`，而 baseXp 全 12
    //      ⇒ 绝对 120 分；4 款最高分到不了 120 ⇒ 永远拿不到 💎（详见 perfectAt 的注释）
    const perfectGate: number = ProgressStore.perfectAt(gameId, baseXp);
    if (solved && score > 0 && score >= perfectGate && hintsUsed === 0) {
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
    const raw: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
    const m: Record<string, number> = ProgressStore.parseNumMap(raw);
    return m[gameId] ?? 0;
  }

  /** 每款游戏的最高分 */
  static bestOf(gameId: string): number {
    const raw: string = AppStorage.get<string>(Keys.perGameBest) ?? '{}';
    const m: Record<string, number> = ProgressStore.parseNumMap(raw);
    return m[gameId] ?? 0;
  }

  /** 玩过的不同游戏款数 */
  static playedKinds(): number {
    const raw: string = AppStorage.get<string>(Keys.perGamePlays) ?? '{}';
    const m: Record<string, number> = ProgressStore.parseNumMap(raw);
    return Object.keys(m).length;
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
      ['all_kinds', '🌌', '全收集', '全部一款不落', 'Completionist', 'Try every single game'],

      // ── 深度（通关多少）──
      ['solve_10', '🏆', '通关达人', '通关 10 局', 'Solver', 'Clear 10 games'],
      ['solve_100', '💯', '百局老手', '通关 100 局', 'Hundred Wins', 'Clear 100 games'],
      ['solve_500', '🏅', '五百胜', '通关 500 局', 'Five Hundred', 'Clear 500 games'],
      ['clear_30_kinds', '📚', '通关 30 款', '30 款都通关了', '30 Cleared', 'Clear 30 different games'],
      ['clear_100_kinds', '🏛️', '通关 100 款', '100 款都通关了', '100 Cleared', 'Clear 100 different games'],
      ['clear_all', '👑', '大满贯', '全部通关', 'Grand Slam', 'Clear every game'],

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
      // ★ 2026-11-08：文案原来写「连着 10 天**每天都通关**」，而判定只看 `streak >= 10`
      //   （连续来玩 10 天，**不查有没有通关**）⇒ 文案撒谎。现在改成与判定一致的说法。
      ['super_10', '🚀', '超级十连', '连着 10 天每天都来玩', 'Ten-Day Streak', 'Come back 10 days running'],

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
      ['all_kinds', kinds >= ProgressStore.totalGames() ? '1' : '0'],

      ['solve_10', solved >= 10 ? '1' : '0'],
      ['solve_100', solved >= 100 ? '1' : '0'],
      ['solve_500', solved >= 500 ? '1' : '0'],
      ['clear_30_kinds', clearedN >= 30 ? '1' : '0'],
      ['clear_100_kinds', clearedN >= 100 ? '1' : '0'],
      ['clear_all', clearedN >= ProgressStore.totalGames() ? '1' : '0'],

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
    // ★★★ 2026-11-08（成就体系巡检 P1-3）**批量解锁只弹一条汇总**
    //   背景：等级曲线从 EXP 2.04 下调到 1.3 后，**老玩家首次进游戏会一次性跨好几级**
    //   （旧 L25 的 XP 在新曲线直接 L100）⇒ 结算弹窗一次堆 5 行「🏆 解锁成就 …」。
    //   而判据 842 已经踩过：手表 233×233 上内容一高，「再来一局/返回列表」就被挤出屏幕。
    //   ⇒ 超过 3 个就压成一行：`🌱 初次开局、🎉 首次通关、🕹️ 手熟 等 7 个`
    //   数据层不受影响：`achievements` 里存的是**全量 id**，统计页照旧一个不少。
    if (newly.length > 3) {
      const isCn: boolean = I18n.isZH() || I18n.isHant();
      const sep: string = isCn ? '、' : ', ';
      const head: string = newly.slice(0, 3).join(sep);
      const tail: string = isCn
        ? (' 等 ' + String(newly.length) + ' 个')
        : (' +' + String(newly.length - 3) + ' more');
      return [head + tail];
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
      // ═══════════════════════════════════════════════════════════════
      // 2026-11-05（第 1376 轮）**修「dailyPick 空 ⇒ 今日挑战永久消失」（判据 1173/1177）**
      //
      // 现象（800×1280 真机）：Home 页**没有今日挑战卡**，而 LV 条在（= 展开态）
      //   磁盘 pref 只有 **124 字节**、只有 **1 个 key**：
      //     dailyGame = 2026-11-05
      //     dailyPick = **不存在**
      //
      // 根因（本行以下就是它）：
      //   早退条件只查 `dailyGame`，不查 `dailyPick`
      //   ⇒ 只要 dailyGame 被写过一次（哪怕同一次里 dailyPick 写失败/为空）
      //   ⇒ 之后每次启动都走「已是今天 => 早退」
      //   ⇒ **dailyPick 永远补不上** ⇒ `dailyMeta()` 永远 undefined
      //   ⇒ `dailyCard()` / `dailyStrip()` 的守卫**静默跳过** ⇒ 功能消失且无提示
      //
      // 而 `dailyGameId()` 在 `allIds.length === 0` 时**返回空串**
      //   ⇒ 存在「dailyGame 写了、dailyPick 写成空」的合法路径
      //
      // 修法：早退条件加一条 **dailyPick 非空** ——
      //   这就是「完整性检查」：两个字段必须**同时**成立才算已初始化
      //   ⇒ 若 dailyPick 为空，**继续往下走**，重新挑一局并写盘（自愈）
      // ═══════════════════════════════════════════════════════════════
      // 判据 1175：预置/恢复流程要有**完整性检查**，不能只看一个字段
      if (day === today && ProgressStore.dailyPick().length > 0) {
        return;
      }
    const gid: string = ProgressStore.dailyGameId(allIds);
    AppStorage.setOrCreate(Keys.dailyGame, today);
    AppStorage.setOrCreate('dailyPick', gid);
    AppStorage.setOrCreate(Keys.dailyDone, false);
    AppStorage.setOrCreate(Keys.dailyBonus, 0);
    ProgressStore.putString(Keys.dailyGame, today);
    // ★★★ 2026-11-05（第 1348 轮）**修「今日挑战永远无法完成」（判据 918）**：
    //   原来这里只 `putString(Keys.dailyGame)`，而 `'dailyPick'` **只写了内存**。
    //   ⇒ 重启后 `dailyPick()` 返回 `''`
    //   ⇒ `markDaily()` 里 `if (ProgressStore.dailyPick() !== gameId) { return 0; }`
    //     **永远成立** ⇒ `dailyDone` 永远不会被置 true
    //   ⇒ 「今日挑战」永远显示「通关 +50 经验」，**那 50 经验永远拿不到**
    //   ⚠️ 而 `dailyPick` 是**裸字符串 key**（不是 `Keys.X` 常量）
    //     ⇒ 我的 `check_persist_roundtrip.py` 也漏了它（判据 919）
    ProgressStore.putString('dailyPick', gid);
    ProgressStore.putString(Keys.dailyDone, 'false');
    ProgressStore.putNumber(Keys.dailyBonus, 0);
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
  /**
   * ★★★ 2026-11-08 **性能**（verifier-eng2 的 faultlog 分析）：
   *   返回列表要重建 **355 张卡**，每张都读 `bestOf()` / `playsOf()` / `diffOf()` ——
   *   每个都是 `JSON.parse(整个 perGameBest 串)` ⇒ **一次返回 ≈ 1000+ 次 JSON.parse**。
   *   20:31 那条 `APP_INPUT_BLOCK`（8 秒没处理完一个输入事件）正卡在 `GameHost → Index` 返回瞬间。
   *   （桌面 sceneboard 早 5 秒先冻 ⇒ **根因是模拟器在卡，app 只是放大器**；
   *     但这个放大器是可以拆掉的，成本很低。）
   *   ⇒ 按**原始字符串**做缓存：串没变就直接复用已解析的对象。
   */
  // ★★★ 2026-11-08 **单槽 → 按原始串分槽**（perf-hunter 实测）：
  //   原来只有 1 个槽 —— 而 `playsOf` 读 `perGamePlays`、`bestOf` 读 `perGameBest`，
  //   统计页的 `topPlayed()` 恰好**交替调用** ⇒ **100% 未命中**，每次 StatsTab 构建
  //   = 1 + 2N 次全量 JSON.parse（N=200 → 401 次 ≈ 15~40ms）⇒ 昨晚那刀在统计页上等于白修。
  //   ⇒ 按 raw 分槽（最多 8 个，防无界）。
  private static mapCache: Map<string, Record<string, number>> = new Map<string, Record<string, number>>();

  /**
   * 解析 `Record<string, number>` 型的 JSON 串（带缓存 —— 同一个串只 parse 一次）。
   *
   * ★★★ 2026-11-08 **返回值是缓存对象本体，调用方只读、禁止就地修改**：
   *   `mapCacheVal` 是**跨调用复用**的同一个对象；谁在这里 `m[k] = v`，
   *   就会出现「raw 字符串没变、但内容被改了」的脏缓存（下次读取拿到被污染的值）。
   *
   *   · 现有 3 个调用点（`playsOf` / `bestOf` / `playedKinds`）都**只读**，所以当前是安全的；
   *   · **写路径一律不走这里**：`finishGame` 里 `perGamePlays` / `perGameBest` 都是用
   *     `JSON.parse(raw)` **重新解析**再 `JSON.stringify` 写回（见 :1334 / :1347），
   *     新串 ≠ 旧串 ⇒ 缓存自然失效。**以后要写也照这个套路**。
   *   · 为什么不做浅拷贝：一次返回列表会读 355 卡 × 4 次 ≈ **1400+ 次**，
   *     每次拷贝 355 键的对象 ≈ 50 万次属性复制 —— 这个函数存在的意义就是省这些开销。
   *     ⇒ 用「注释约束 + 写路径重建」换取零成本，比拷贝更合适。
   */
  private static parseNumMap(raw: string): Record<string, number> {
    const hit: Record<string, number> | undefined = ProgressStore.mapCache.get(raw);
    if (hit !== undefined) {
      return hit;
    }
    let val: Record<string, number> = {};
    try {
      val = JSON.parse(raw) as Record<string, number>;
    } catch (e) {
      val = {};
    }
    if (ProgressStore.mapCache.size >= 8) {
      ProgressStore.mapCache.clear();      // 简单防无界：满了就清空（真实场景只有 5 个 key）
    }
    ProgressStore.mapCache.set(raw, val);
    return val;
  }

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
  /**
   * ★★★ 2026-10-23 路线 F：3 → 4
   *   0 简单 / 1 普通 / 2 困难 / **3 自动**
   *   3 不是真实难度，是个"模式"：真正用哪档由 GameLog.autoLevel() 按最近战绩算。
   *   ⚠️ 凡是拿 diff 直接分支的地方（if d===0 / if d===2）都必须先过 GameDiff.of() 映射，
   *      否则 3 会掉进默认分支 ⇒ 自动档静默变成普通档（这是最容易漏的坑）
   */
  static readonly DIFF_COUNT: number = 4;

  /** 各档的名字（中/英） */
  static readonly DIFF_NAME: string[][] = [
    ['简单', 'Easy'], ['普通', 'Normal'], ['困难', 'Hard'], ['自动', 'Auto']
  ];

  /** 各档的经验倍率 */
  // 自动档的倍率用 1.0 打底 —— 真实倍率由结算时的【实际难度】决定
  static readonly DIFF_XP: number[] = [0.8, 1.0, 1.4, 1.0];

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

  // ───────── 上次玩到哪（2026-11-08 · 退出恢复最小版）─────────
  /**
   * 读「上次玩到哪」。**没有记录 / 记录损坏 ⇒ undefined**（调用方按"从第 1 关开始"处理）。
   *
   * ★ 为什么只记 level+diff 而不是完整棋局：
   *   全量序列化要改 355 款的内部状态（成本极高、易漏）；而"上次玩到第几关"是**用户感知最强、
   *   成本最低**的那一项 —— 退出再进直接续关，就已经解决了"每次都要从头点"的痛点。
   */
  static lastWhere(gameId: string): LastWhere | undefined {
    if (!gameId) {
      return undefined;
    }
    const raw: string = AppStorage.get<string>(Keys.lastWhere) ?? '{}';
    try {
      const m: Record<string, LastWhere> = JSON.parse(raw) as Record<string, LastWhere>;
      const row: LastWhere | undefined = m[gameId];
      if (row === undefined || row === null) {
        return undefined;
      }
      // 记录损坏（NaN / 负数）一律当没有：宁可从头开始，也不要续到一个非法关卡
      if (typeof row.level !== 'number' || !(row.level >= 0)) {
        return undefined;
      }
      const d: string = typeof row.diff === 'string' ? row.diff : '';
      return { level: row.level, diff: d, at: typeof row.at === 'number' ? row.at : 0 };
    } catch (e) {
      return undefined;
    }
  }

  /**
   * ★★★ 2026-11-08（退出恢复最小版）**恢复闸门**：每个游戏**每个进程只允许恢复一次**。
   *
   * ★ 为什么必须有它：`再来一局 / 顶栏 ↻` 会切 `diffTick` 奇偶 ⇒ 游戏组件**重建**
   *   ⇒ `aboutToAppear` 又跑一遍。如果在那里无条件恢复，玩家点「再来一局」会被莫名
   *   续回上次那一关 —— 直接破坏「再来一局 = 从头」的语义。
   * ⇒ 用"本进程第一次打开这款游戏才恢复"来区分：
   *   · 杀进程后重进（真正想要的功能）⇒ 静态集合为空 ⇒ 恢复 ✓
   *   · 再来一局 / 换一局 / 返回列表再点进来 ⇒ 已经恢复过 ⇒ 从第 1 关开始 ✓
   */
  static shouldRestoreNow(gameId: string): boolean {
    if (!gameId) {
      return false;
    }
    if (ProgressStore.restored.indexOf(gameId) >= 0) {
      return false;
    }
    ProgressStore.restored.push(gameId);
    return true;
  }

  /** 便捷：只取上次的关卡号（无记录 = 0，正好等于"从第 1 关开始"的入参） */
  static lastLevel(gameId: string): number {
    const w: LastWhere | undefined = ProgressStore.lastWhere(gameId);
    return w === undefined ? 0 : w.level;
  }

  /**
   * 写「上次玩到哪」。
   * ★ `level <= 0` 视为**清除记录** —— 通关最后一关后调 `saveLastWhere(id, 0, diff)`，
   *   下次进来就从头，不会续到"已经不存在的下一关"。
   */
  static saveLastWhere(gameId: string, level: number, diff: string): void {
    if (!gameId) {
      return;
    }
    const raw: string = AppStorage.get<string>(Keys.lastWhere) ?? '{}';
    let m: Record<string, LastWhere> = {};
    try {
      m = JSON.parse(raw) as Record<string, LastWhere>;
    } catch (e) {
      m = {};
    }
    // ★ 2026-11-08 ArkTS **不支持 `delete` 运算符**（`arkts-no-delete`）⇒ 改成重建对象。
    //   （ai-fixer-b 的退出恢复接口原来写的是 `delete m[gameId]`，编译挂在这。）
    let out: Record<string, LastWhere> = {};
    const keys: string[] = Object.keys(m);
    for (let i = 0; i < keys.length; i++) {
      const k: string = keys[i];
      if (k !== gameId) {
        const v: LastWhere = m[k];
        if (v !== undefined) {
          out[k] = v;
        }
      }
    }
    if (level > 0) {
      out[gameId] = { level: Math.floor(level), diff: diff ?? '', at: Date.now() };
    }
    m = out;
    const j: string = JSON.stringify(m);
    AppStorage.setOrCreate(Keys.lastWhere, j);
    ProgressStore.putString(Keys.lastWhere, j);
  }

  // ───────── 每游戏分级成就（奥森 2026-10-11 要求）─────────
  //
  //  每款游戏 4 档，不是只有一个"通关过"徽章：
  //    ① 首通   通关 1 次
  //    ② 熟练   通关 10 次
  //    ③ 精通   通关 50 次
  //    ④ 大师   通关 100 次
  //  全部游戏 × 4 档（= `totalGames() × 4`，现在 355 款 ⇒ **1420** 枚），
  //  所以**不塞进成就墙**（会撑爆），
  //  而是：① 在每款游戏的玩法说明页显示它的 4 档进度；② 统计页只显示总进度 `x / (totalGames × 4)`。
  //  ★ 2026-11-08：原来这里写死「x/1416」—— 那是 354 款时代的数，加了一款就陈旧了。
  //    凡是"分母"都别写字面量，用 `totalGames()`（UI 里那处用的就是 `GAMES.length * 4` ✓）。

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

  /** 全应用一共点亮了多少枚分级徽章（上限 = `totalGames() × 4`，现在 1420 —— 别写死分母） */
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

  /**
   * 徽章墙进度：**通关过的款数**（分母是 `totalGames()`，现在 355 —— 别在这里写死数字）
   * ⚠️ 实现是 `clearedGames().length`，即**每次都 split 整个已通关串** ⇒ 别在 `build()`
   *    里逐帧调用；统计页已改成走自己的缓存（`StatsTab.refreshBadge()`），不再每帧打这里。
   */
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

  /**
   * 记「已看过欢迎引导」（项目 D ⑤）。
   * ★ 2026-10-29：原来**根本没有首次引导** —— 用户第一次打开只看到一屏卡片，
   *   不知道「提示 / AI 代打 / 演示」这三个按钮干嘛用的，也不知道能搜索分类。
   *   ⇒ 加一个一次性的欢迎卡，看过就落盘，不再打扰。
   */
  static saveOnboarded(): void {
    ProgressStore.putString('onboarded', '1');
  }

  /** 看过欢迎引导了吗（没读过 ⇒ false ⇒ 会显示一次） */
  static onboarded(): boolean {
    const pr: preferences.Preferences | null = ProgressStore.pref;
    if (pr === null) {
      return false;
    }
    try {
      return (pr.getSync('onboarded', '') as string) === '1';
    } catch (e) {
      return false;
    }
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
  private static recordPlay(gameId: string, score: number, durationMs: number, solved: boolean): void {
    const plays: number = ProgressStore.totalPlays() + 1;
    AppStorage.setOrCreate(Keys.totalPlays, plays);
    ProgressStore.putNumber(Keys.totalPlays, plays);

    const ms: number = ProgressStore.totalMs() + (durationMs > 0 ? durationMs : 0);
    AppStorage.setOrCreate(Keys.totalMs, ms);
    ProgressStore.putNumber(Keys.totalMs, ms);
    // 单日累计（马拉松成就用）
    // ★★★ 2026-11-08（成就体系巡检 P0-2）：**原来从不跨天清零** ——
    //   `todayMs` 全库只有"判成就"和"这里累加"两处 ⇒ 它实际是「**累计**玩了多久」，
    //   于是成就 `marathon`（文案「一天玩了 2 小时」）判的其实是「累计 2 小时」，
    //   与 `hour_1`/`hour_10` 同义，且额外多给一个徽章。
    //   ⇒ 现在用 `todayMsDay` 记住"这份累计属于哪一天"，跨天就归零。
    //   ⚠️ 这个值只在 AppStorage 里（不落盘）—— 重启后从 0 起算，比"跨天还带着昨天的数"安全。
    const msDay: string = AppStorage.get<string>('todayMsDay') ?? '';
    const nowDay: string = ProgressStore.today();
    let baseMs: number = AppStorage.get<number>('todayMs') ?? 0;
    if (msDay !== nowDay) {
      baseMs = 0;
      AppStorage.setOrCreate('todayMsDay', nowDay);
    }
    const todayMs: number = baseMs + (durationMs > 0 ? durationMs : 0);
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
      // ★★★ 2026-11-01（第 818 轮）：这里原来**只写不报** ——
      //   最高分被记下来了，但结算弹窗完全不知道"这一局是不是新纪录"。
      //   玩家打出 1980 分，屏幕上和打出 600 分长得一模一样。
      //   ⇒ 置一个静态标志，由 GameHost 在弹窗里读；`prevBest` 也留下，
      //     让界面能显示"从 1200 到 1980"这种进步幅度。
      const rawB: string = AppStorage.get<string>(Keys.perGameBest) ?? '{}';
      const mb: Record<string, number> = JSON.parse(rawB) as Record<string, number>;
      const prevBest: number = mb[gameId] ?? 0;
      ProgressStore.prevBest = prevBest;
      // ★★★ 2026-11-08（game-balancer）**输局不再弹「🏆 新纪录」**：
      //   原来只看分数高低，而 recordPlay 对**每一局**都调用（含输局），
      //   且很多款的输局也给分（`this.steps*3`、`this.bound()*12`…）
      //   ⇒ 输一局拿 60 分、上一把赢局只拿 40 分 ⇒ 结算页庆祝一场失败。
      //   ⇒ 新纪录必须同时满足「这局赢了」。
      //   ⚠️ 已知残留：下面的 `mb[gameId] = score` 仍会记输局的分数——
      //     若某款「输比赢分多」（如未修的 classic_maze）会把最高分刷成失败分。
      //     那属于各款分数公式的问题，不在这里做二次裁决。
      ProgressStore.lastWasBest = solved && score > prevBest;
      if (score > prevBest) {
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
    // ★★★ 2026-11-08 perf-hunter：**先把整张连胜表同步进 AppStorage**，再落盘。
    //   根因：`'streaks'` 这个键此前**只在 `init()` 里写过一次**（:263），之后永不更新
    //     ⇒ 卡片的 🔥连胜 /「今日已玩」永远是启动那一刻的快照。
    //     （原来这两个值靠父组件传 `@Prop`，而 ForEach/LazyForEach 同 key 不重跑 itemGenerator
    //       ⇒ 玩完一局回到首页**不会刷新**。现在改成卡片自己 `@StorageProp('streaks')` 订阅。）
    //   ⚠️ 这一行**必须放在 `if (!p) return` 之前**：pref 没就绪时内存态已经是新的，
    //     若先 return，UI 就永远等不到那次通知（判据 879 的同类坑：只写一半的同步链）。
    const obj: Record<string, GameStreak> = {};
    ProgressStore.streaks.forEach((v: GameStreak, k: string) => {
      obj[k] = v;
    });
    let raw: string = '{}';
    try {
      raw = JSON.stringify(obj);
    } catch (e) {
      raw = '{}';
    }
    AppStorage.setOrCreate('streaks', raw);
    const p = ProgressStore.pref;
    if (!p) {
      return;
    }
    // ★★★ 存储满时 putSync 会抛 ⇒ 静默失败（内存态已更新）
    try {
      p.putSync('streaks', raw);
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
