/**
 * 统计页 —— 等级头卡 + 四宫格 + 最近玩过 + 最常玩的 5 款
 *
 * 数据只有两个来源：
 *   ① ProgressStore 的方法（totalPlays / totalMs / playedKinds / favorites /
 *      recent / playsOf / bestOf / streakOf / levelProgress / xpToNext）
 *   ② ProgressStore 写进 AppStorage 的那几个键 —— 本页用 @StorageProp 挂上，
 *      一局结束（xp / totalSolved / totalPlays / totalMs / perGamePlays / favorites…）
 *      页面自动刷新；原始值只进 rev() 当 ForEach 的 key 后缀（与 GamesTab 的 tick 同理）。
 *
 * 视觉取自 Design.ets（FontSize / Space / Radius / Palette / Motion / Theme / Shadow）；
 * 除下面集中声明的两个色值（tint 前缀、徽章次级白）与块尺寸外，行内不留魔法数字。
 *
 * 拾海 2026-10-10
 */

import { TG } from '../core/GameI18n';
import { router } from '@kit.ArkUI';
import { Digits } from '../core/I18n';   // ★ 2026-10-16 数字本地化
import { Bp } from '../core/Bp';
// ★ 2026-10-13「动画拉满」：数字滚动（从 GameHost 提取成公共件，见 core/MotionKit.ets）
import { RollingNumber } from '../core/MotionKit';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Overlay, Layout, Accent, Cell } from '../core/Design';
import { GAMES, GameMeta, GameCategory, CatCount, categoryList, findGame, colorOf, displayName, displayTagline, gamesByCategory } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
import { GameLog, PlayRecord } from '../core/GameLog';   // ★ 2026-11-07：近期板块的数据源（每局日志）
import { LevelHeader, iconOf } from './Common';
import { Haptics } from '../core/Haptics';
import { L, TN } from '../core/I18n';
import { Tv } from '../core/Tv';

/** 最近玩过显示几张 */
const RECENT_LIMIT: number = 6;
/** 最常玩显示几款 */
const TOP_LIMIT: number = 5;
/** 前三名给奖牌色 */
const MEDAL_RANKS: number = 3;
/** 等级封顶（与 ProgressStore.levelOf 一致） */
const MAX_LEVEL: number = 100;
/** 百分比换算 */
const PCT: number = 100;
/** 毫秒 → 分钟；分钟 → 小时 */
const MS_PER_MIN: number = 60000;
const MIN_PER_HOUR: number = 60;
/** ★ 2026-11-07：一天的毫秒数（近期板块按「自然日」切窗口） */
const MS_PER_DAY: number = 86400000;
/** ★ 2026-11-07：取多少条日志算「近期」—— GameLog 内存里最多留 800 条（core/GameLog.ets KEEP_IN_MEM） */
const LOG_WINDOW: number = 800;
/** 12% 透明度（ARGB 前缀），配 tint() 用 */
const TINT_ALPHA: string = '#1A';
/** 徽章上的次级文字（Palette 无此 token，集中放这里） */
const ON_PRIMARY_SOFT: string = Overlay.onColorSoft;
/** 进场动画：延时与上浮距离（Design 只管时长/缓动） */
const ENTER_DELAY_MS: number = 30;
const ENTER_RISE: number = 12;
/** 块尺寸 */
const BADGE_SIZE: number = 64;
const ICON_BOX: number = 44;
const ICON_SM: number = 32;
const RECENT_BOX: number = 72;
const RANK_W: number = 22;
const BAR_H: number = 8;

/** 最常玩榜的一行 */
interface RankItem {
  meta: GameMeta;
  plays: number;
  best: number;
  streak: number;
}

/**
 * ★ 2026-11-07（体验升级点 Top 4）：「近期」板块要用的一次聚合结果
 *   一次遍历 `GameLog.recent()` 同时算出三件事：
 *     · total / solved ⇒ 近 7 天通关率
 *     · todayMs        ⇒ 今日玩了多久
 *     · topId/topCount ⇒ 近 7 天最常玩的那一款
 */
interface WeekStat {
  total: number;
  solved: number;
  todayMs: number;
  topId: string;
  topCount: number;
}

@Component
export struct StatsTab {
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  @State achvExpanded: boolean = false;
  /** ★★★ 2026-11-07 交互死角：智慧屏/键盘焦点环 */
  @State private tvFocus: string = '';
  @State renderRev: number = 0;
  // ★★★ 2026-11-05（第 1345 轮）**修「显示停住」bug（判据 897/898）**：
  //   现象：结算后统计页「🎯 一共玩了 **0** 局」，而成就墙已解锁「初次开局」（2/53）
  //     ⇒ **数据是对的（totalPlays 真的变了），显示停在初值**
  //   根因：`playsShown` / `solvedShown` 是 `@State`，只在 `aboutToAppear` 里滚一次，
  //     而 `StatsTab` 是**页签内容，一直挂着**（切走再切回不重建）
  //     ⇒ `aboutToAppear` 只跑一次 ⇒ 之后再玩多少局，显示永远停在初值
  //   对照：同页的「⏱️ 玩了多久」走 `ProgressStore.totalMs()` **函数调用** ⇒ 永远最新
  //     ⇒ **同一页面两种读法会分叉**（判据 898）
  //   修法：`@Watch` 监听 `@StorageProp` 变化 ⇒ 重新滚到新值
  //     （项目已有先例：`SparkBurst.ets:46` 的 `@Prop @Watch('redraw')`）
  @StorageProp('totalPlays') @Watch('onPlaysChanged') plays: number = 0;      // 累计开局（必须用 StorageProp，函数调用不会触发重渲染）
  @StorageProp('totalMs') totalMs: number = 0;       // 累计时长
  @StorageProp('clearedGames') clearedRaw: string = '';
  @StorageProp('themeDark') dark: boolean = false;
  @StorageProp('xp') xp: number = 0;
  @StorageProp('level') level: number = 1;
  @StorageProp('totalSolved') @Watch('onSolvedChanged') totalSolved: number = 0;
  @StorageProp('superStreak') superStreak: number = 0;
  @StorageProp('bestStreak') bestStreak: number = 0;
  @StorageProp('dailyCount') dailyCount: number = 0;
  @StorageProp('solvedToday') solvedToday: boolean = false;
  // ↓ 数据本体仍走 ProgressStore 的方法，这几个只用来算"数据版本号"触发刷新
  @StorageProp('totalMs') totalMsRaw: number = 0;
  @StorageProp('perGamePlays') perGameRaw: string = '{}';
  @StorageProp('favorites') favRaw: string = '';
  @StorageProp('recent') recentRaw: string = '';

  @State entered: boolean = false;
  /** ★ 2026-10-13「动画拉满」item ④：数字滚动（0 → 实际值）—— 原来数字是"跳"出来的 */
  @State solvedShown: number = 0;
  @State playsShown: number = 0;
  private rollSolved: RollingNumber = new RollingNumber();
  private rollPlays: RollingNumber = new RollingNumber();

  /**
   * ★★★ 2026-11-05（第 1345 轮）：`totalPlays` 变了 ⇒ 重新滚到新值
   *   为什么必须加：`playsShown` 是 `@State`，只在 `aboutToAppear` 里被赋值一次，
   *   而本组件**一直挂着不重建** ⇒ 不重滚的话显示永久停在初值（判据 897/898）。
   *   ⚠️ 不用 `animateTo` 包 —— `RollingNumber.to` 自己逐帧推 @State，
   *     再包一层动画会抢帧（项目纪律：别在后台每帧 setState）。
   */
  onPlaysChanged(): void {
    this.rollPlays.to(this.plays, (v: number) => {
      this.playsShown = v;
    });
  }

  /**
   * ★★★ 2026-11-05（第 1345 轮）：`totalSolved` 变了 ⇒ 重新滚到新值
   *   同一个 bug 的第二个受害者（「🏆 通关了 N 局」原来也停在初值）。
   */
  onSolvedChanged(): void {
    this.rollSolved.to(this.totalSolved, (v: number) => {
      this.solvedShown = v;
    });
  }

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: Motion.slow, curve: Motion.spring() }, () => {
        this.entered = true;
      });
      // ★ 数字滚上去：延迟一点、等页面淡入站稳了再滚（同时滚会互相抢注意力）
      const solved: number = this.totalSolved;
      const plays: number = this.plays;
      this.rollSolved.to(solved, (v: number) => {
        this.solvedShown = v;
      });
      this.rollPlays.to(plays, (v: number) => {
        this.playsShown = v;
      });
    }, ENTER_DELAY_MS);
  }

  /**
   * ⚠️ 必须停掉滚动计时器 —— 否则离开统计页后它还在推帧（本项目"别每帧 setState"那条纪律）
   */
  aboutToDisappear(): void {
    this.rollSolved.stop();
    this.rollPlays.stop();
  }

  // ───────────── 取色 / 取数 ─────────────

  // ★ 性能：theme() 一次渲染被调 40+ 次 ⇒ 按 dark 记忆化
  private themeCache: Theme | null = null;
  private themeCacheDark: boolean = false;

  /**
   * 空态用的「推荐几款」—— 从 355 款里按分类轮转挑 6 款
   *
   * ★ 为什么要它（lead 巡检 ③「统计页底部空一大块」）：
   *   一局没玩时下面只有空态卡片 + 版权字，往上滚有 ~1 屏空白，
   *   看着像"页面坏了"。用"接着玩什么"把它填上 —— 既有内容又有去处。
   *
   * 取数方式：按分类轮转（每类取第 1、第 2 款，凑够 6 款）⇒ 不会 6 款全挤在一个分类里。
   */
  private pickSix(): GameMeta[] {
    const out: GameMeta[] = [];
    // ★ 用 `categoryList()` 拿分类（**别手写 `c as GameCategory` 那种数字转换** ——
    //   `GameCategory` 是字符串枚举，数字转它在 ArkTS 里不成立，而且顺序一改就错位）
    const cats: CatCount[] = categoryList();
    for (let round = 0; round < 2 && out.length < 6; round++) {
      for (let c = 0; c < cats.length && out.length < 6; c++) {
        if (cats[c].cat === GameCategory.ALL) {
          continue;                       // "全部"不是真分类，跳过
        }
        const one: GameMeta[] = gamesByCategory(cats[c].cat);
        if (one.length > round) {
          out.push(one[round]);
        }
      }
    }
    return out;
  }

  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  private t(zh: string, en: string): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    // ★ 2026-10-13（P4）：这里原来是中英二元式 `observed === 'en' ? en : zh` ——
    //   日/韩/西/法/德/葡/俄/意/阿 十种语言全退中文，繁体也被吞。必须走 L()（12 语言 + 简繁转换）。
    return L(zh, en);
  }

  /** 带数字的整句模板（读 langCode 建立依赖；语序随语言走，别在调用点拼片段） */
  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.langCode;
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

  private theme(): Theme {
    if (this.themeCache === null || this.themeCacheDark !== this.dark) {
      this.themeCache = this.dark ? Theme.dark() : Theme.light();
      this.themeCacheDark = this.dark;
    }
    return this.themeCache;
  }

  /** 该色的 12% 底（ARGB 字符串） */
  private tint(accent: string): string {
    return TINT_ALPHA + accent.substring(1);
  }

  /** 数据版本号：@StorageProp 的原始值一拼，变了就让 ForEach 重建 */
  private rev(): string {
    return this.plays + '-' + this.totalMsRaw + '-' + this.perGameRaw.length
      + '-' + this.favRaw + '-' + this.recentRaw.length;
  }
  private nextLevelText(): string {
    if (this.level >= MAX_LEVEL) {
      return 'LV ' + MAX_LEVEL + ' · ' + this.t(TG('满级'), 'Max');
    }
    return 'LV ' + this.level + ' → LV ' + (this.level + 1);
  }

  /** 累计时长 → 「X小时Y分」（不足一小时只显示分） */
  private durationText(): string {
    const mins: number = Math.floor(ProgressStore.totalMs() / MS_PER_MIN);
    const h: number = Math.floor(mins / MIN_PER_HOUR);
    const m: number = mins % MIN_PER_HOUR;
    if (h <= 0) {
      return m + this.t('分', 'min');
    }
    return h + this.t('小时', 'h') + m + this.t('分', 'min');
  }

  // ═══════ ★★★ 2026-11-07（体验升级点 Top 4）：近期 = 今日时长 / 近 7 天通关率 / 近 7 天最常玩 ═══════
  //
  // 为什么要有：本页原来**一个字节都没读过 `GameLog`**（core/GameLog.ets 的每局日志：
  //   结束时间 / 时长 / 成败 / 难度 / 得分）⇒ 只有「累计玩了多久」这一个时间维度，
  //   看不出"今天玩了多久 / 最近一周怎么样"。数据早就在盘上，缺的只是这一屏。
  //
  // ⚠️ 依赖陷阱（必须读一下 @StorageProp）：`GameLog` 是静态类，记录变了**不会通知 ArkUI**；
  //   而本页 `@StorageProp('totalPlays') plays` 每结算一局都会变 ⇒ 在那几个取数方法里读它，
  //   build 才会在每局结束后重算这块（同 `this.t()` 开头 `const observed = this.langCode` 的写法）。
  //   ⛔ 别删那行"依赖声明"，否则打完一局统计页的"近期"永远停在旧数字（判据 897/898 同族）。

  /** 今天 0 点的时间戳（本地时区） */
  private dayStart(): number {
    const d: Date = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /** 近 7 天的下界：含今天在内共 7 个自然日 */
  private weekStart(): number {
    return this.dayStart() - 6 * MS_PER_DAY;
  }

  /** 一次遍历算出「近期」要的三个数（7 天窗口内的局 / 通关数 / 今日时长 / 最常玩那款） */
  private weekStat(): WeekStat {
    const observed: number = this.plays;      // ← 依赖声明，别删（读一下才会重算；同 t() 的 langCode）
    const st: WeekStat = { total: 0, solved: 0, todayMs: 0, topId: '', topCount: 0 };
    const recs: PlayRecord[] = GameLog.recent(LOG_WINDOW);
    const wk: number = this.weekStart();
    const td: number = this.dayStart();
    const cnt: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < recs.length; i++) {
      const r: PlayRecord = recs[i];
      if (r.t < wk) {
        continue;                             // 7 天以前的不算
      }
      st.total++;
      if (r.ok) {
        st.solved++;
      }
      if (r.t >= td) {
        st.todayMs += r.ms;                   // 「今日玩了多久」= 今天这些局的时长之和
      }
      cnt.set(r.g, (cnt.get(r.g) ?? 0) + 1);
    }
    cnt.forEach((n: number, gid: string) => {
      if (n > st.topCount) {
        st.topCount = n;                      // 并列时保留先出现的那款（Map 是插入序）
        st.topId = gid;
      }
    });
    return st;
  }

  /** 毫秒 → 「3 分 24 秒」/「45 秒」/「3 分」（单位走字典：「分」已有、「秒」是本次新增 key） */
  private fmtPlaytime(ms: number): string {
    const sec: number = Math.floor(ms / 1000);
    const m: number = Math.floor(sec / 60);
    const s: number = sec % 60;
    const minU: string = this.t('分', 'min');
    const secU: string = this.t('秒', 'sec');
    if (m <= 0) {
      return Digits(String(s), this.langCode) + ' ' + secU;
    }
    if (s <= 0) {
      return Digits(String(m), this.langCode) + ' ' + minU;
    }
    return Digits(String(m), this.langCode) + ' ' + minU + ' '
      + Digits(String(s), this.langCode) + ' ' + secU;
  }

  /** 今日时长：今天一局都没玩 ⇒ 「—」（绝不显示 0 秒） */
  private todayPlaytimeText(): string {
    const st: WeekStat = this.weekStat();
    if (st.todayMs <= 0) {
      return '—';
    }
    return this.fmtPlaytime(st.todayMs);
  }

  /** 近 7 天通关率：「62%（8/13）」；窗口内没有记录 ⇒ 「—」（绝不出现 0/0 / NaN） */
  private weekRateText(): string {
    const st: WeekStat = this.weekStat();
    if (st.total <= 0) {
      return '—';
    }
    const pct: number = Math.round(st.solved * PCT / st.total);
    return this.t('{p}%（{a}/{b}）', '{p}% ({a}/{b})')
      .replace('{p}', Digits(String(pct), this.langCode))
      .replace('{a}', Digits(String(st.solved), this.langCode))
      .replace('{b}', Digits(String(st.total), this.langCode));
  }

  /** 近 7 天最常玩的那一款：「数独 · 5 局」；没有记录 ⇒ 「—」 */
  private weekTopText(): string {
    const st: WeekStat = this.weekStat();
    if (st.topId.length === 0) {
      return '—';
    }
    const m: GameMeta | undefined = findGame(st.topId);
    const name: string = m !== undefined ? displayName(m) : st.topId;
    return name + ' · ' + this.tn('{n} 局', '{n} rounds', st.topCount);
  }

  /** 极小屏 / 手表的一行版：「今日 3 分 24 秒 · 62%」（塞不下三行，见 recentStats 的注释） */
  private weekLineText(): string {
    const st: WeekStat = this.weekStat();
    if (st.total <= 0) {
      return this.t('还没有记录 —— 玩一局就有了', 'No records yet — play a round');
    }
    const today: string = st.todayMs > 0 ? this.fmtPlaytime(st.todayMs) : '—';
    const pct: string = Digits(String(Math.round(st.solved * PCT / st.total)), this.langCode) + '%';
    return this.t('今日', 'Today') + ' ' + today + ' · ' + pct;
  }
  /** 最近玩过的游戏（最多 6 款） */
  private recentMetas(): GameMeta[] {
    const out: GameMeta[] = [];
    const ids: string[] = ProgressStore.recent();
    for (let i = 0; i < ids.length && out.length < RECENT_LIMIT; i++) {
      const g: GameMeta | undefined = findGame(ids[i]);
      if (g !== undefined) {
        out.push(g);
      }
    }
    return out;
  }

  /** 玩过的 gameId（从 perGamePlays 的键取，省得遍历全部游戏） */
  private playedIds(): string[] {
    const out: string[] = [];
    try {
      const m: Record<string, number> = JSON.parse(this.perGameRaw) as Record<string, number>;
      const ks: string[] = Object.keys(m);
      for (let i = 0; i < ks.length; i++) {
        out.push(ks[i]);
      }
    } catch (e) {
      return [];
    }
    return out;
  }

  /** 最常玩的 5 款（按开局数降序） */
  private topPlayed(): RankItem[] {
    const ids: string[] = this.playedIds();
    const all: RankItem[] = [];
    for (let i = 0; i < ids.length; i++) {
      const g: GameMeta | undefined = findGame(ids[i]);
      if (g === undefined) {
        continue;
      }
      const item: RankItem = {
        meta: g,
        plays: ProgressStore.playsOf(g.id),
        best: ProgressStore.bestOf(g.id),
        streak: ProgressStore.streakOf(g.id),
      };
      all.push(item);
    }
    all.sort((a: RankItem, b: RankItem) => b.plays - a.plays);
    const top: RankItem[] = [];
    for (let i = 0; i < all.length && i < TOP_LIMIT; i++) {
      top.push(all[i]);
    }
    return top;
  }

  private openGame(id: string): void {
    router.pushUrl({ url: 'pages/GameHost', params: { id: id } });
  }

  // ───────────── 页面 ─────────────

    /** 剥掉字典译文自带的尾部箭头（判据 1782：字典有符号时组件不得再画同一个） */
  private stripArrow(s: string): string {
    let t: string = s;
    while (t.length > 0) {
      const last: string = t.charAt(t.length - 1);
      if (last === '▲' || last === '▼' || last === '△' || last === '▽' || last === ' ') {
        t = t.substring(0, t.length - 1);
      } else {
        break;
      }
    }
    return t;
  }

build() {
    Scroll() {
      Column({ space: Space.lg }) {
        // ★ 2026-10-13 巡检发现：统计页缺等级展示（首页有 LV/经验/火焰，这里直接跳到成就）
        //   ⇒ 复用 Common 里现成的 LevelHeader（和首页同一套数据源，不重复实现）
        LevelHeader()
        this.achvWall()
        this.badgeWall()
        // ★★★ 2026-11-07（S-09）：这里原来是 `this.heroCard()` —— 与顶部 `LevelHeader()` 是同一张
        //   等级卡的第二次渲染（LV 圆章/称号/XP 进度条/今日打卡 四项逐字重复，且两者都只服务本页）。
        //   ⇒ 删 heroCard、留顶部 LevelHeader；只把它独有的「累计经验 + 下一等级 + 4 枚 chip」提出来。
        this.statsChips()
        this.statGrid()
        // ★★★ 2026-11-07（体验升级点 Top 4）：近期 = 今日时长 / 近 7 天通关率 / 近 7 天最常玩
        //   位置：等级头卡（LV/XP/连胜/今日打卡）+ 四宫格（累计）之后，最近玩过/最常玩榜之前。
        //   ⚠️ 2026-11-07（S-09）后的 DOM 顺序：「LevelHeader → 成就墙 → 徽章墙 → statsChips → 四宫格 → 近期」，
        //     「等级/连胜/打卡」由顶部 LevelHeader 承担，近期板块仍在它们之后 —— 信息层级：身份 → 累计 → 近期 ✓。
        //     （删 heroCard 之前这里写的是「…→ 等级头卡 → 四宫格」，那张"等级头卡"就是被删掉的重复卡。）
        this.recentStats()
        if (ProgressStore.totalPlays() === 0) {
          this.emptyState()
          this.suggestSection()      // ★ item ③：把底部的空白填上
        } else {
          this.recentSection()
          this.topSection()
        }
        Text(this.t(TG('记录只存在你手机里，不上传、不联网也能看'), 'Everything stays on your phone — no uploads, works offline'))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      // ★★★ 2026-10-30：底部原来写 `Space.xxxl`(=48)，**比导航栏(60)还小**
      //   ⇒ 960×540 下滚到底，「成就」卡片仍被导航栏遮住约 40%，
      //     右侧滚动条已到底 ⇒ **用户永远看不到那两张卡的下半**。
      //   ⇒ 与 SettingsTab 统一：按导航栏实际高度现算（barHeight + 48 余量）。
      //
      // ★★★ 2026-11-05（第 1324 轮）：**试过把这里改成 `Space.xxl`(32)，已回滚**
      //   实验：padding 108 → 32 vp，真机复测 195 滚到底
      //     · 修复前：内容区纯白 **85%**
      //     · 修复后：内容区纯白 **89%**（**反而升了**）
      //   ⇒ **白色的真因不是 padding 太大**，而是「最后一段内容本来就只有三行」
      //     （dump：「🔍 难度自证 / 0 款已记录 / 进过的游戏会记在这里…」）
      //   ⇒ 判据 847：**「纯白占比高」要先分「padding 大」与「内容结束」两种原因**
      //   ⇒ 原值保留（它同时承担「内容不被页签栏贴住」的职责，判据 792）
      .padding({
        left: Space.lg, right: Space.lg, top: Space.xl,
        bottom: (Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48
      })
      .opacity(this.entered ? 1 : 0)
      .translate({ y: this.entered ? 0 : ENTER_RISE })
      .animation({ duration: Motion.slow, curve: Motion.spring() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bg)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * ── ① 统计 chip 条（原 `heroCard()` 的**独有信息**）──
   *
   * ★★★ 2026-11-07（S-09）：`heroCard()` 与顶部 `LevelHeader()` 是同一张等级卡的两次渲染 ——
   *   LV 圆章、称号、XP 进度条、今日打卡这四项逐字重复，而两张卡**都只服务统计页**
   *   （`grep -rn LevelHeader` / `heroCard` 全仓各只有一个使用点，都在本文件）。
   *   ⇒ 删 `heroCard`、留顶部 `LevelHeader`（位置决定谁是重复：身份卡应在页面最顶，
   *     而不是在「成就墙 + 徽章墙」之后再出现一次）。
   *   ⇒ 这里只搬 **heroCard 独有的三项**，不再重复画等级：
   *     · 累计经验「一共攒了 {n} 点经验」（LevelHeader 只有"还差多少"，没有累计）
   *     · 下一等级「LV 9 → LV 10」（LevelHeader 没有）
   *     · 4 枚 chip：连胜 / 最长连 / 今天玩几局 / 收藏
   *   ⚠️ 原来那两行里「再攒 {n} 点经验就升级」与 LevelHeader 的进度行**逐字相同**，
   *     为了不再制造重复，这里换成「LV 9 → LV 10」。
   */
  @Builder
  statsChips() {
    Column({ space: Space.sm }) {
      Row() {
        Text(this.tn(TG('一共攒了 {n} 点经验'), '{n} XP earned', this.xp))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        Text(this.nextLevelText())
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
          .maxLines(1)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        this.chip('🔥', TG('连胜 {n} 天'), 'Streak {n} days', this.superStreak, Palette.orange)
        this.chip('🏅', TG('最长连了 {n} 天'), 'Longest {n} days', this.bestStreak, Palette.amber)
        this.chip('📅', TG('今天玩了 {n} 局'), 'Today {n} rounds', this.dailyCount, Palette.sky)
        this.chip('⭐', TG('收藏 {n} 款'), 'Saved {n}', ProgressStore.favorites().length, Palette.berry)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

  @Builder
  chip(icon: string, zh: string, en: string, n: number, accent: string) {
    Row({ space: Space.xs }) {
      Text(icon)
        .fontSize(FontSize.xs)
      Text(this.tn(zh, en, n))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkSoft)
    }
    .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
    .margin({ right: Space.xs, top: Space.xs })
    .backgroundColor(this.tint(accent))
    .borderRadius(Radius.full)
  }

  /** ── ② 四宫格：通关 / 开局 / 时长 / 款数 ── */
  @Builder
  statGrid() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        // ★★★ 2026-11-05（第 1345 轮）**三层保险显示（判据 902）**：
        //   1. `Math.max(缓存, 真值)` —— 动画没跟上时也显示真值（永不小于真值）
        //   2. `@Watch` —— 处理「运行中变化」
        //   3. `aboutToAppear` 的滚动 —— 处理「首次落位」
        //   为什么必须加 max：`aboutToAppear` 在 `init()`（异步读盘）完成前跑，
        //   那一刻 `totalSolved` 还是 0 ⇒ `rollSolved.to(0)` 直接 `apply(0)`（target<=0 早退）
        //   ⇒ 显示永久停在 0。实测：磁盘上 totalPlays=3，界面显示 0。
        this.statCell('🏆', String(Math.max(this.solvedShown, this.totalSolved)), '局', 'rounds', TG('通关了'), 'Cleared', Palette.amber)
        this.statCell('🎯', String(Math.max(this.playsShown, this.plays)), '局', 'rounds', TG('一共玩了'), 'Played', this.accentColor())
      }
      .width('100%')

      Row({ space: Space.md }) {
        this.statCell('⏱️', this.durationText(), '', '', TG('玩了多久'), 'Time played', Palette.emerald)
        this.statCell('🧩', ProgressStore.playedKinds() + '/' + GAMES.length, '款', 'games', TG('玩过几款'), 'Tried', Palette.violet)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  statCell(icon: string, value: string, unitZh: string, unitEn: string, labelZh: string, labelEn: string, accent: string) {
    Column({ space: Space.sm }) {
      // 上行：小图标 + 名字（大字留给下面的数值，免得「12小时5分」被截断）
      Row({ space: Space.xs }) {
        Stack() {
          Text(icon)
            .fontSize(FontSize.sm)
        }
        .width(ICON_SM)
        .height(ICON_SM)
        .backgroundColor(this.tint(accent))
        .borderRadius(Radius.xs)

        Text(this.t(labelZh, labelEn))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
      }
      .width('100%')

      // 下行：数值 + 单位
      Row({ space: Space.xs }) {
        Text(value)
          .fontSize(FontSize.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.t(unitZh, unitEn).length > 0) {
          Text(this.t(unitZh, unitEn))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
            .margin({ bottom: Space.xs })
        }
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
    .layoutWeight(1)
  }

  /**
   * ── ★★★ 2026-11-07（体验升级点 Top 4）：近期 ──
   *
   * 三行：今日玩了多久 / 近 7 天通关率 / 近 7 天最常玩。数据源是 `core/GameLog.ets` 的每局日志
   * （本页原来一个字节都没读过它 ⇒ 只有"累计时长"，没有时间维度）。
   *
   * 空状态（按严重程度分两档，**绝不出现 0/0 或 NaN**）：
   *   · 全库一条记录都没有 ⇒ **整块不渲染**（本页自己的 emptyState 已经在说"这里还空着"，别叠两张空卡）
   *   · 有记录但近 7 天没有 ⇒ 卡里只有一句「还没有记录 —— 玩一局就有了」
   *   · 窗口内有记录、但今天没玩 ⇒ 「今日 —」（其他两行照常显示）
   *
   * 极小屏 / 手表（233×233 塞不下三行）⇒ 压成**一行**：「今日 3 分 24 秒 · 62%」
   *   （最常玩那款不显示：一行里再塞游戏名会换行/截断，收益不如保住前两个数）
   */
  @Builder
  recentStats() {
    if (GameLog.count() > 0 || this.plays > 0) {
      Column({ space: Space.sm }) {
        Row() {
          Text('📊 ' + this.t(TG('近 7 天'), 'Last 7 days'))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          Blank()
          // 窗口内的局数（0 就不显示，免得空状态里还挂一个「0 局」）
          Text(this.weekStat().total > 0
            ? this.tn(TG('{n} 局'), '{n} rounds', this.weekStat().total) : '')
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
        }
        .width('100%')

        if (Bp.tinyScreen() || Bp.isWatch()) {
          Text(this.weekLineText())
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkSoft)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding(Space.sm)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.md)
        } else {
          Column({ space: Space.sm }) {
            if (this.weekStat().total === 0) {
              Text(this.t(TG('还没有记录 —— 玩一局就有了'), 'No records yet — play a round'))
                .fontSize(FontSize.xs)
                .fontColor(this.theme().inkFaint)
                .width('100%')
            } else {
              this.recentRow('⏱️', TG('今日'), 'Today', this.todayPlaytimeText(), Palette.emerald)
              this.recentRow('🎯', TG('通关率'), 'Clear rate', this.weekRateText(), Palette.amber)
              this.recentRow('🎮', TG('最常玩'), 'Most played', this.weekTopText(), Palette.violet)
            }
          }
          .width('100%')
          .padding(Space.md)
          .backgroundColor(this.theme().surface)
          .borderRadius(Radius.lg)
          .shadow(Shadow.card)
        }
      }
      .width('100%')
    }
  }

  /** 「近期」的一行：图标 + 标签（左）+ 值（右）；值最多占 58%，长游戏名不会把标签挤没 */
  @Builder
  recentRow(icon: string, labelZh: string, labelEn: string, value: string, accent: string) {
    Row({ space: Space.sm }) {
      Stack() {
        Text(icon)
          .fontSize(FontSize.sm)
      }
      .width(ICON_SM)
      .height(ICON_SM)
      .backgroundColor(this.tint(accent))
      .borderRadius(Radius.xs)
      Text(this.t(labelZh, labelEn))
        .fontSize(FontSize.xs)
        .fontColor(this.theme().inkSoft)
        // ★★★ 2026-11-07 溢出审计（S-08）：这里原来只有 layoutWeight(1)，没有 maxLines/截断
        //   ⇒ 德语「Am meisten gespielt」≈122vp、法语「Le plus joué」≈72vp、西语「Más jugado」≈70vp，
        //     而标签可用宽 = 卡内 288 − 图标 22 − 两个间距 20 − 值（≤58%≈167）= **≥79vp**
        //   ⇒ 德语必然折成两行 ⇒ 这一行比「今日/通关率」两行高 ⇒ 三行参差（奥森能看见的"错位"）。
        //   值那一端早就有 maxLines+Ellipsis，这里补齐同一套：单行 + 省略号，三行永远等高。
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(value)
        .fontSize(FontSize.xs)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '58%' })
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  /** ── ③ 最近玩过：横向滑动小卡 ── */
  @Builder
  recentSection() {
    Column({ space: Space.sm }) {
      this.sectionHeader('🕐', TG('最近玩过的'), 'Recently played', TG('点一下直接续上'), 'Tap to pick up where you left off')

      Scroll() {
        Row({ space: Space.md }) {
          ForEach(this.recentMetas(), (g: GameMeta) => {
            this.recentCard(g)
          }, (g: GameMeta) => 'rc-' + g.id + '-' + this.rev())
        }
        .padding({ right: Space.lg })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  recentCard(g: GameMeta) {
    Column({ space: Space.xs }) {
      Stack() {
        Text(g.icon)
          .fontSize(FontSize.xxl)
      }
      .width(RECENT_BOX)
      .height(RECENT_BOX)
      .backgroundColor(colorOf(g))
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(displayName(g))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(RECENT_BOX)

      Text(this.tn('{n} 局', '{n} rounds', ProgressStore.playsOf(g.id)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkFaint)
    }
    .alignItems(HorizontalAlign.Center)
    // ★★★ 2026-10-19 全面自查 A6：统计页「最近玩的」这张卡点开就进游戏，
    //   但原来没有任何按压反馈、也没有触感 ⇒ 与主页 GameCard 的手感不一致
    .stateStyles({
      pressed: { .scale({ x: 0.94, y: 0.94 }).opacity(0.85) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'ST803'; })
    .onBlur(() => { if (this.tvFocus === 'ST803') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'ST803'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
            Haptics.tap();
      this.openGame(g.id);
    
    }); })
    .accessibilityGroup(true)
    .accessibilityText(g.icon)
    .accessibilityLevel('yes')
    .onClick(() => {
      Haptics.tap();
      this.openGame(g.id);
    })
  }

  /** ── ④ 最常玩的 5 款 ── */
  @Builder
  topSection() {
    Column({ space: Space.sm }) {
      this.sectionHeader('📈', TG('玩得最多的'), 'Most played', TG('按玩的次数排'), 'sorted by plays')

      ForEach(this.topPlayed(), (it: RankItem, i: number) => {
        this.rankRow(it, i)
      }, (it: RankItem) => 'tp-' + it.meta.id + '-' + this.rev())
    }
    .width('100%')
  }

  @Builder
  rankRow(it: RankItem, rank: number) {
    Row({ space: Space.md }) {
      Text(Digits(String(rank + 1), this.langCode))
        .fontSize(FontSize.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(rank < MEDAL_RANKS ? Palette.amber : this.theme().inkFaint)
        .width(RANK_W)
        .textAlign(TextAlign.Center)

      Stack() {
        Text(it.meta.icon)
          .fontSize(FontSize.xl)
      }
      .width(ICON_BOX)
      .height(ICON_BOX)
      .backgroundColor(colorOf(it.meta))
      .borderRadius(Radius.md)

      Column({ space: Space.xs }) {
        Text(displayName(it.meta))
          .fontSize(FontSize.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: Space.xs }) {
          Text(this.tn(TG('玩过 {n} 次'), 'Played {n} times', it.plays))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
          if (it.best > 0) {
            Text(this.tn(TG('最高 {n}'), 'Best {n}', it.best))
              .fontSize(FontSize.xxs)
              .fontColor(Palette.sky)
          }
          if (it.streak > 0) {
            Text('🔥 ' + this.tn('{n} 天', '{n} days', it.streak, '{n} день', '{n} дня', '{n} дней'))
              .fontSize(FontSize.xxs)
              .fontColor(Palette.orange)
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'ST873'; })
    .onBlur(() => { if (this.tvFocus === 'ST873') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'ST873'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
            Haptics.tap();   // ★ 2026-10-19 按压反馈
      this.openGame(it.meta.id);
    
    }); })
    .accessibilityGroup(true)
    .accessibilityText(Digits(String(rank + 1), this.langCode))
    .accessibilityLevel('yes')
    .onClick(() => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      this.openGame(it.meta.id);
    })
  }

  @Builder
  sectionHeader(icon: string, titleZh: string, titleEn: string, rightZh: string, rightEn: string) {
    Row() {
      Text(icon + ' ' + this.t(titleZh, titleEn))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Blank()
      Text(this.t(rightZh, rightEn))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkFaint)
    }
    .width('100%')
  }

  /** ── ⑤ 空状态：一局都没玩过 ── */
  // ───────── 成就墙 ─────────

  private unlockedIds(): string[] {
    return ProgressStore.unlocked();
  }

  // ★ 性能：53 项排序 + concat 每次渲染重算多次 ⇒ 记忆化
  private achvCache: string[][] = [];
  private achvCacheKey: string = '\u0000';

  /** 已解锁排前面，这样一眼看到的都是点亮的（带记忆化） */
  private sortedAchv(): string[][] {
    const key: string = this.unlockedIds().join(',') + '#' + this.renderRev;
    if (key === this.achvCacheKey) {
      return this.achvCache;
    }
    this.achvCacheKey = key;
    this.achvCache = this.computeSortedAchv();
    return this.achvCache;
  }

  private computeSortedAchv(): string[][] {
    const all: string[][] = ProgressStore.achievementList();
    const got: string[] = this.unlockedIds();
    const on: string[][] = [];
    const off: string[][] = [];
    for (let i = 0; i < all.length; i++) {
      if (got.indexOf(all[i][0]) >= 0) {
        on.push(all[i]);
      } else {
        off.push(all[i]);
      }
    }
    return on.concat(off);
  }

  @Builder
  achvWall() {
    Column({ space: Space.md }) {
      Row() {
        Text(this.t(TG('🏅 成就'), '🏅 Achievements')).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
        Blank()
        Text(Digits(String(this.unlockedIds().length), this.langCode) + ' / ' +
          Digits(String(ProgressStore.achievementList().length), this.langCode))
          .fontSize(FontSize.xs).fontColor(this.accentColor()).fontWeight(FontWeight.Bold)
      }
      .width('100%')

      // 总进度条
      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).backgroundColor(this.theme().line).borderRadius(Layout.hairline)
        Row()
          .width(this.achvPct() + '%').height(5)
          .backgroundColor(Palette.amber).borderRadius(Layout.hairline)
      }
      .width('100%').height(5)

      // 展开/收起（53 个全铺开会把徽章墙顶到很下面）
      Row({ space: 4 }) {
        // ★★★ 2026-11-07 判据 1782（verifier-dev 扫出的「双符号」）：
        //   `收起` 的 10 语言译文**全都自带 ▲**（ja「閉じる ▲」/ de「Weniger ▲」…），
        //   而下一行又画一个 `▲`/`▼` ⇒ 11 种语言显示「閉じる ▲ ▲」。
        //   ⇒ 剥掉字典里自带的尾部箭头，只留组件画的那一个（方向随展开态）。
        Text(this.stripArrow(this.achvExpanded ? this.t('收起', 'Less')
            : this.tn(TG('看全部 {n} 个'), 'See all {n}', ProgressStore.achievementList().length)))
          .fontSize(FontSize.xxs).fontColor(this.accentColor()).fontWeight(FontWeight.Bold)
        Text(this.achvExpanded ? '▲' : '▼').fontSize(FontSize.micro).fontColor(this.accentColor())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 6, bottom: 2 })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'ST967'; })
      .onBlur(() => { if (this.tvFocus === 'ST967') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'ST967'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
                Haptics.tap();   // ★ 2026-10-19 按压反馈
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.achvExpanded = !this.achvExpanded;
        });
      
      }); })
      .accessibilityGroup(true)
      .accessibilityText(this.stripArrow(this.achvExpanded ? this.t('收起', 'Less')
            : this.tn(TG('看全部 {n} 个'), 'See all {n}', ProgressStore.achievementList().length)))
      .accessibilityLevel('yes')
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.achvExpanded = !this.achvExpanded;
        });
      })

      Grid() {
        ForEach(this.visibleAchv(), (a: string[]) => {
          GridItem() {
            // ★ 内联 + 读 this.totalSolved 建立观察：
            //   ProgressStore 是静态类、不是 @State ⇒ 原来解锁成就后徽章墙不刷新（P3 同族）
            // ★ 2026-10-19 真机实拍后调：原 space.sm(14) + 图标 36
            //   ⇒ 文字区只剩 94vp，而副标题「玩出你的第一局」正好需 94vp
            //   ⇒ 零余量 ⇒ 实拍出看到省略号
            //   收到 Space.xs(13) + 图标 30 ⇒ 文字区 99vp，够了
            Row({ space: Space.xs }) {
              Text(ProgressStore.isUnlocked(a[0]) ? a[1] : '🔒')
                .fontSize(FontSize.xl)
                .width(30).height(30).textAlign(TextAlign.Center)
                .backgroundColor(ProgressStore.isUnlocked(a[0]) ? '#1A6366F1' : this.theme().surfaceAlt)
                .borderRadius(Radius.sm)
              Column({ space: 1 }) {
                Text(this.t(a[2], a.length >= 6 ? a[4] : a[2]))
                  .fontSize(FontSize.xs)
                  .fontWeight(ProgressStore.isUnlocked(a[0]) ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(ProgressStore.isUnlocked(a[0]) ? this.theme().ink : this.theme().inkFaint)
                  .maxLines(1)
                  // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.t(a[3], a.length >= 6 ? a[5] : a[3]))
                  .fontSize(FontSize.micro).fontColor(this.theme().inkFaint).maxLines(1)
                  // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .constraintSize({ minHeight: Cell.of(70) })
            .padding({ left: 6, right: 6 })
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.sm)
            .opacity(ProgressStore.isUnlocked(a[0]) ? 1 : 0.55)
          }
        }, (a: string[]) => a[0])
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(Space.sm)
      .rowsGap(Space.sm)
      .width('100%')
      .height(Math.ceil(this.visibleAchv().length / 2) * 78)
      // ★ 观察源：totalSolved 变化 ⇒ 本区块重建（否则解锁成就后不刷新）
      .opacity(this.totalSolved >= 0 ? 1 : 1)

    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

  /** 收起时只显示前 8 个（解锁的排前面 ⇒ 先看到的都是点亮的） */
  private visibleAchv(): string[][] {
    const all: string[][] = this.sortedAchv();
    if (this.achvExpanded || all.length <= 8) {
      return all;
    }
    return all.slice(0, 8);
  }

  private achvPct(): number {
    const total: number = ProgressStore.achievementList().length;
    if (total === 0) {
      return 0;
    }
    return Math.round(this.unlockedIds().length * 100 / total);
  }

  // ───────── 每游戏徽章墙 ─────────

  @Builder
  badgeWall() {
    Column({ space: Space.md }) {
      Row() {
        Text(this.t(TG('🎖️ 游戏徽章'), '🎖️ Game Badges')).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
        Blank()
        Text(Digits(String(ProgressStore.tierTotal()), this.langCode) + ' / ' +
              Digits(String(GAMES.length * 4), this.langCode))
          .fontSize(FontSize.xs).fontColor(Palette.emerald).fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Text(this.t(TG('每款游戏 4 档：首通 · 熟练 10 次 · 精通 50 次 · 大师 100 次'), 'Each game has 4 tiers: first clear, 10, 50, 100'))
        .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)

      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(5).backgroundColor(this.theme().line).borderRadius(Layout.hairline)
        Row()
          .width(this.badgePct() + '%').height(5)
          .backgroundColor(Palette.emerald).borderRadius(Layout.hairline)
      }
      .width('100%').height(5)

      // 已点亮的徽章（最多显示 12 个，避免刷屏）
      if (ProgressStore.badgeProgress() > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.litBadges(), (g: GameMeta) => {
            Row({ space: 4 }) {
              Text(g.icon).fontSize(FontSize.sm)
              Text(displayName(g)).fontSize(FontSize.xxs).fontColor(this.theme().ink)
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 6, bottom: 6 })
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.full)
          }, (g: GameMeta) => g.id)
        }
        .width('100%')
      } else {
        Text(this.t(TG('还没有徽章——通关任意一局就点亮'), 'No badges yet — clear any game to start'))
          .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          .padding({ top: Space.sm, bottom: Space.sm })
      }
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

  private badgePct(): number {
    return Math.round(ProgressStore.tierTotal() * 100 / (GAMES.length * 4));
  }

  /** 已点亮的徽章对应的游戏（最多 12 个） */
  private litBadges(): GameMeta[] {
    const ids: string[] = ProgressStore.clearedGames();
    const out: GameMeta[] = [];
    for (let i = 0; i < ids.length && out.length < 12; i++) {
      const g: GameMeta | undefined = findGame(ids[i]);
      if (g !== undefined) {
        out.push(g);
      }
    }
    return out;
  }

  @Builder
  achvCell(a: string[]) {
    Row({ space: Space.sm }) {
      Text(ProgressStore.isUnlocked(a[0]) ? a[1] : '🔒')
        .fontSize(FontSize.xl)
        .width(36).height(36).textAlign(TextAlign.Center)
        .backgroundColor(ProgressStore.isUnlocked(a[0]) ? '#1A6366F1' : this.theme().surfaceAlt)
        .borderRadius(Radius.sm)
      Column({ space: 1 }) {
        Text(this.t(a[2], a.length >= 6 ? a[4] : a[2]))
          .fontSize(FontSize.xs)
          .fontWeight(ProgressStore.isUnlocked(a[0]) ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(ProgressStore.isUnlocked(a[0]) ? this.theme().ink : this.theme().inkFaint)
          .maxLines(1)
          // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.t(a[3], a.length >= 6 ? a[5] : a[3])).fontSize(FontSize.micro).fontColor(this.theme().inkFaint).maxLines(1)
        // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    // ★ 2026-10-19 自查 A3：与上面那张徽章卡同一模式 —— 3 行文字 + 写死 70vp
    //   大字模式字号 +25~42% ⇒ 会被裁 ⇒ 改最小高度（可长高）
    .constraintSize({ minHeight: Cell.of(70) })
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.theme().surfaceAlt)
    .borderRadius(Radius.sm)
    .opacity(ProgressStore.isUnlocked(a[0]) ? 1 : 0.55)
  }

  /**
   * 「先从这几款开始」—— 统计页空态下方的推荐（item ③ 补空白）
   *
   * ⚠️ 列表项**内联**（不抽 @Builder 传参）：本项目踩过「@Builder 参数不建立观察」，
   *   而这些行只需要读静态数据，内联最省事也最不会出问题。
   */
  @Builder
  suggestSection() {
    Column({ space: Space.sm }) {
      this.sectionHeader('🎲', TG('先从这几款开始'), 'Start with these', TG('挑不出就先玩这几个'), 'picks to get going')

      ForEach(this.pickSix(), (g: GameMeta) => {
        Row({ space: Space.md }) {
          if (iconOf(g.id) !== undefined) {
            Image(iconOf(g.id))
              .width(40).height(40)
              .objectFit(ImageFit.Contain)
              .draggable(false)
          } else {
            Text(g.icon).fontSize(FontSize.lg).width(40).height(40).textAlign(TextAlign.Center)
          }
          Column({ space: 2 }) {
            Text(displayName(g))
              .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
              .fontColor(this.theme().ink).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(displayTagline(g))
              .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›').fontSize(FontSize.lg).fontColor(this.theme().inkFaint)
            .accessibilityLevel('no')
        }
        .width('100%')
        .padding(Space.md)
        .backgroundColor(this.theme().surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'ST1191'; })
        .onBlur(() => { if (this.tvFocus === 'ST1191') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'ST1191'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
                    Haptics.tap();
          router.pushUrl({ url: 'pages/GameHost', params: { id: g.id } });
        
        }); })
        .accessibilityGroup(true)
        .accessibilityText(g.icon)
        .accessibilityLevel('yes')
        .onClick(() => {
          Haptics.tap();
          router.pushUrl({ url: 'pages/GameHost', params: { id: g.id } });
        })
      }, (g: GameMeta) => 'sg-' + g.id)
    }
    .width('100%')
  }

  @Builder
  emptyState() {
    Column({ space: Space.md }) {
      Text('🌱')
        .accessibilityLevel('no')
        .fontSize(FontSize.hero)
      Text(this.t(TG('这里还空着'), 'Nothing here yet'))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.t('回「游戏」页随便开一局 ——\n通关、时长、连胜都会记在这一页',
                  'Open a game from the Games tab — clears, time and streaks all land here'))
        .fontSize(FontSize.xs)
        .fontColor(this.theme().inkFaint)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(Space.xl)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
    .alignItems(HorizontalAlign.Center)
        // ★ 2026-10-19 自查 ⑦：空白页也要有入场（淡入 + 上浮），不能"啪"一下出现
        .transition(TransitionEffect.OPACITY
          .animation({ duration: Motion.base, curve: Motion.spring() })
          .combine(TransitionEffect.translate({ y: 10 })
            .animation({ duration: Motion.base, curve: Motion.spring() })))
  }
}
