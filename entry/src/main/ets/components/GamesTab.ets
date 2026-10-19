/**
 * 游戏页 —— 等级条 + 搜索 + 今日挑战 + 随机 + 分段 + 分类 + 游戏网格
 *
 * ★ 354 款的两条硬约束：
 *   ① Grid 自带虚拟化 ⇒ **不能嵌在 Scroll 里**（否则 354 张卡一次全渲染）
 *   ② list() 每渲染会被调多次 ⇒ 写成一遍扫，别做深层嵌套
 *
 * 拾海 2026-10-10（本版为**清理重写**：前几轮的正则补丁把结构改坏了，症状是
 *   「一搜索整个列表区就不渲染」——根因是补丁残留，不是逻辑）
 */

import { router } from '@kit.ArkUI';
import { About } from '../core/About';
import { Haptics } from '../core/Haptics';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Overlay, Layout, Accent } from '../core/Design';
import {GAMES, GameMeta, GameCategory, gamesByCategory, categoryList, findGame, displayName, displayTagline, catLabelEn, BUILD_TAG } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
import { I18n, L, TN, Digits } from '../core/I18n';
import { TAGS as ALL_TAGS, GameTag, tagsByGroup, tagsIn } from '../core/GameTags';
import { GameCard, CategoryBar, iconOf } from './Common';
// ★ 按字母排序：中文要拼音首字母，英文/其它语言 displayName 本来就是 enName ⇒ 天然 A-Z
//   （表由 Lead 2026-10-13 用 macOS `CFStringTransformMandarinLatin` 生成，355 条）
import { firstLetterOf, LETTERS } from '../core/GamePinyin';
// ★ 2026-10-13「动画拉满」item ④：图标按下弹一下（统一倍率，别每处各写一个）
import { IconPress } from '../core/MotionKit';

/** 顶部分段 */
enum Seg {
  ALL = '全部',
  FAV = '收藏',
  RECENT = '最近',
}

/** 列表视图：网格 / 字母表（2026-10-13 奥森：「应该再加一个游戏列表，按字母排序」） */
enum ViewMode {
  GRID = 'grid',
  AZ = 'az',
}

/**
 * 字母分节（A-Z 列表用）
 *
 * ★ 为什么按 `enName` 排而不是中文名：中文要拼音，而"拼音"在 ArkTS 里没有可靠实现
 *   （`localeCompare('zh')` 依赖平台 ICU，鸿蒙上结果不稳定）。`enName` 355 款全有 ⇒ 直接比字母最稳。
 */
class AzSection {
  letter: string = '';
  games: GameMeta[] = [];
  constructor(letter: string) {
    this.letter = letter;
  }
}

@Component
export struct GamesTab {
  @StorageProp('themeDark') dark: boolean = false;
  @StorageProp('totalSolved') totalSolved: number = 0;
  @StorageProp('superStreak') streak: number = 0;
  @StorageProp('level') level: number = 1;
  @StorageProp('xp') xp: number = 0;
  @StorageProp('solvedToday') playedTodayAll: boolean = false;

  @State category: GameCategory = GameCategory.ALL;
  @State seg: Seg = Seg.ALL;
  @State tick: number = 0;
  // ★★★ 2026-10-14 奥森新要求：「主界面的上面那些东西应该可以收起来，留更多空间给下面的游戏列表」
  //   +「手指向上滑动（游戏列表往下走）时自动收起」
  //   ⇒ 收起后只留【当前分类 + 展开按钮】一条（他确认的设计：「保留最重要的和一个展开按钮」）
  // ★★★ 2026-10-14 加 uiMode 观察源 —— cardH() 要按模式返回高度（大字模式不能裁字）
  @StorageProp('uiMode') uiMode: string = 'normal';
  // ★★★ 2026-10-15 实测发现（大字模式）：
  //   奥森要我注意"模式切换后的界面"⇒ 实拍发现：【大字模式下顶部 UI 占满整屏，
  //   游戏网格被完全挤出屏幕，首屏一个游戏都看不到】（GridItem 0 个）
  //   ⇒ 修法：大字模式【默认就收起顶部】⇒ 直接把空间让给游戏列表
  //   （normal/simple 仍默认展开 —— 那是 app 的门面）
  @State topCollapsed: boolean = false;
  // ★★★ 2026-10-14 奥森：「也要能手动收起（加一个按钮）」⇒ 手动切换后 2 秒内不被自动逻辑抢回
  @State private manualUntil: number = 0;
  // ★★★ 2026-10-14 自动收起的【防抖闸门】：两次切换至少隔 900ms，杜绝甩动中反复重排
  @State private lastToggle: number = 0;
  @State dailyId: string = '';
  @State dailyDone: boolean = false;
  @State toast: string = '';
  @State renderRev: number = 0;
  @StorageProp('lang') langCode: string = 'zh';
  /**
   * ★ 2026-10-13（P5）：主题色观察源 —— 有它，设置页改色这一页**立刻**重绘；
   *   没有它就只在页面重建时才跟色（ArkUI 的 TabContent 建好即缓存）。
   *   它是 **id**（可能是 'system'），当颜色用要走 `this.accentColor()`。
   */
  @StorageProp('accent') accentId: string = Palette.primary;
  @State picked: string[] = [];        // 选中的特征
  @State showFilter: boolean = false;  // 是否展开筛选面板
  @State viewMode: ViewMode = ViewMode.GRID;   // 网格 ⇄ 字母表
  // ★★★ 2026-10-19「动画拉满」第 1 层：内容刷新脉冲
  //   奥森：「全部拉满，拉满到手机性能不支持」
  //   问题：切分类 / 切片段 / 切视图模式时，网格内容【瞬间换掉】，没有"换了一批"的实感
  //   ⇒ 切换瞬间网格收紧到 0.972 + 透明度 0.62，然后弹簧弹回 ⇒ "内容被刷新了"
  @State private gridPulse: boolean = false;
  /** A-Z 首屏进场的错峰开关：切到字母表后 30ms 置 true ⇒ 触发动效 */
  @State azShown: boolean = true;
  /**
   * ★ 动画 ① 共享元素转场：**正在"长大"的那张卡**
   *
   * 机制（ArkUI `geometryTransition`）：同一个 id 绑定两个组件（"出场件"和"入场件"），
   * 系统自动把它们的位置/尺寸做补间。这里：
   *   · 出场件 = 首页那张 `GameCard`（id = `card-<gid>`）
   *   · 入场件 = `GameHost` 的整页容器（**同名 id**，从路由参数带过去）
   * ⚠️ 一个 id 只能绑**两个**组件 ⇒ 必须**每款唯一**，所以带 gid 后缀。
   * ⚠️ 只在"点开这一张"时挂 id ⇒ 其余 354 张不参与，避免系统给它们都建配对。
   */
  @State private flyingId: string = '';

  /** 顶栏两个图标按钮的按下态（按下放大 1.08 —— item ④「图标按下弹一下」） */
  @State private darkPressed: boolean = false;
  @State private langPressed: boolean = false;
  /** A-Z 索引条当前高亮（跟着列表滚动走） */
  @State azCurrent: number = 0;
  /** 列表滚动控制器（字母条要能跳） */
  private azScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // ★ 大字模式默认收起顶部（否则网格被挤出屏幕 —— 实测）
    if (this.uiMode === 'elder') {
      this.topCollapsed = true;
    }
    const ids: string[] = [];
    for (let i = 0; i < GAMES.length; i++) {
      ids.push(GAMES[i].id);
    }
    ProgressStore.ensureDaily(ids);
    this.dailyId = ProgressStore.dailyPick();
    this.dailyDone = ProgressStore.dailyDoneToday();
  }

  /**
   * ★ 动画 ① 配套：回到首页时解除"出场件"绑定
   *
   * 为什么要清：`flyingId` 不清 ⇒ 那张卡一直挂着 geometryTransition，
   * 下次从别的入口（今日挑战/随机）进游戏时，它会跟 GameHost 抢同一个 id。
   * ⚠️ 延迟 260ms 再清：**返回时那一下反向补间还没走完**，立刻清会把动画掐断。
   */
  onPageShow(): void {
    // ★ 2026-10-13：这里的清理现在是【兜底】——
    //   正常情况下进游戏后 400ms 就已经清掉了（见 openGame），
    //   返回时 flyingId 本就是空 ⇒ 不会有幽灵共享元素。
    //   万一 400ms 定时器被系统压掉（后台/卡顿），这里再补一次。
    if (this.flyingId === '') {
      return;
    }
    this.flyingId = '';
  }

  // ★ 性能：theme() 在一次渲染里被调 28+ 次，每次都 new Theme 对象 ⇒ 按 dark 记忆化
  private themeCache: Theme | null = null;
  private themeCacheDark: boolean = false;

  /** 直接从 @StorageProp 读，保证语言一变 UI 一定重渲染 */
  private isEN(): boolean {
    return this.langCode === 'en';
  }

  /**
   * 顶栏语言徽标（显示**当前**语言，不是固定的「中/EN」）
   * 2026-10-13（P4）：旧版在繁体/日语下也显示「中」，一点就把语言打回简体。
   */
  private langBadge(): string {
    const c: string = this.langCode;   // ← 依赖声明
    if (c === 'zh') {
      return '中';
    }
    if (c === 'zh-Hant') {
      return '繁';
    }
    if (c === 'en') {
      return 'EN';
    }
    return c.toUpperCase();            // JA / KO / ES / FR / DE / PT / RU / IT / AR
  }

  /**
   * 当前主题色（可直接当颜色用）
   * ★ 读一次 `this.accentId` 就是"依赖声明" —— 设置页改主题色，本页立刻重绘；
   *   `Accent.color()` 负责把 id `'system'` 解析成系统品牌色。
   */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  /**
   * ★ 取当前语言的文案（组件版）
   *
   * 为什么不用模块级的 L()：
   *   ArkUI 的**依赖追踪只认 `@StorageProp` 的读取**。若 build 里只调 `L()`
   *   （它读的是 I18n 的静态缓存），ArkUI **看不到这个节点依赖语言** ⇒
   *   语言一变，按钮会更新（它读了 langCode），而标题不会（它只读了静态字段）。
   *   （2026-10-11 真踩过：切英文后按钮变 ENe、标题却还是中文）
   *   ⇒ 组件内一律用 `this.t(...)`：它先读 `this.langCode`，把依赖显式建立起来。
   */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;   // ← 这一行就是"依赖声明"，别删
    // ★ 走 L() 而不是三元 —— L() 会查 EXTRA 字典支持 12 种语言，
    //   三元只能中英两态（否则日/韩/西… 全都会退成英文）
    return L(zh, en);
  }

  private theme(): Theme {
    if (this.themeCache === null || this.themeCacheDark !== this.dark) {
      this.themeCache = this.dark ? Theme.dark() : Theme.light();
      this.themeCacheDark = this.dark;
    }
    return this.themeCache;
  }

  private levelPct(): number {
    const p: number = ProgressStore.levelProgress(this.xp);
    return Math.max(0, Math.min(100, Math.round(p * 100)));
  }

  private xpToNext(): number {
    return ProgressStore.xpToNext(this.xp);
  }

  private dailyName(): string {
    const m: GameMeta | undefined = this.dailyMeta();
    if (m === undefined) {
      return '';
    }
    // ★ 非中英语言用**国际通用英文名**（奥森要求），不要退回中文
    const zhLike: boolean = this.langCode === 'zh' || this.langCode === 'zh-Hant';
    // ★ 2026-10-13 模拟器抓到：繁體下这里直接拼 m.name/m.tagline（简体）⇒ 显示「辅音重建 · 还原辅音」
    //   改用 displayName/displayTagline（它们内部对 zh-Hant 走 toTrad）
    // ★★★ 2026-10-16 实拍日语发现：原来非中文走 enName/enTagline ⇒ 日语玩家看到英文
    //   displayName/displayTagline 现在支持 12 语言（GAME_NAME/GAME_TAGLINE），全语言统一走它们
    return displayName(m) + ' · ' + displayTagline(m);
  }

  private segEn(): string {
    if (this.seg === Seg.FAV) {
      return 'Saved';
    }
    if (this.seg === Seg.RECENT) {
      return 'Played';
    }
    return 'All';
  }

  private dailyMeta(): GameMeta | undefined {
    return this.dailyId.length > 0 ? findGame(this.dailyId) : undefined;
  }

  private byIds(ids: string[]): GameMeta[] {
    const out: GameMeta[] = [];
    for (let i = 0; i < ids.length; i++) {
      const g: GameMeta | undefined = findGame(ids[i]);
      if (g !== undefined) {
        out.push(g);
      }
    }
    return out;
  }

  // ★ 性能：list() 在 build 里被调 4 次，每次遍历 354 款 ⇒ 按输入记忆化
  private listCache: GameMeta[] = [];
  private listCacheKey: string = '\u0000';

  /** 当前该显示哪些游戏（带记忆化） */
  private list(): GameMeta[] {
    const key: string = this.seg + '|' + this.category + '|' + this.picked.join(',');
    if (key === this.listCacheKey) {
      return this.listCache;
    }
    this.listCacheKey = key;
    this.listCache = this.computeList();
    return this.listCache;
  }

  /**
   * ★「动画拉满」内容刷新脉冲
   *   切换分类/片段/视图模式时调用：网格先收紧，再弹簧弹回
   *   120ms 收紧（快而狠）+ 420ms 弹回（有回弹，落得住）
   */
  private pulseGrid(): void {
    animateTo({ duration: 120, curve: Curve.FastOutSlowIn }, () => {
      this.gridPulse = true;
    });
    setTimeout(() => {
      animateTo({ duration: 420, curve: Motion.spring() }, () => {
        this.gridPulse = false;
      });
    }, 130);
  }

  private computeList(): GameMeta[] {
    let base: GameMeta[];
    if (this.seg === Seg.FAV) {
      base = this.byIds(ProgressStore.favorites());
    } else if (this.seg === Seg.RECENT) {
      base = this.byIds(ProgressStore.recent());
    } else {
      base = gamesByCategory(this.category);
    }
    if (this.picked.length === 0) {
      return base;
    }
    // ★ 多选取交集：每款游戏的 tags 必须包含所有已选特征
    const out: GameMeta[] = [];
    for (let i = 0; i < base.length; i++) {
      const gt: string[] = base[i].tags;
      let all: boolean = true;
      for (let k = 0; k < this.picked.length; k++) {
        if (gt.indexOf(this.picked[k]) < 0) {
          all = false;
          break;
        }
      }
      if (all) {
        out.push(base[i]);
      }
    }
    return out;
  }

  private countLabel(): string {
    const n: number = this.list().length;
    if (this.seg !== Seg.ALL) {
      // ★★★ 2026-10-16 实拍日语发现：键拼上了 ' · ' ⇒ 永远查不到字典 ⇒ 退英文
      //   改成【键不带后缀】，后缀在拼接时加
      return this.t(this.seg, this.segEn()) + ' · ' + n;
    }
    if (this.picked.length > 0) {
      // ★ 2026-10-19 自查修：原来是动态拼接 ⇒ key 永远查不到 ⇒ 非中英用户退英文
      //   改为 {a}/{b} 占位符 ⇒ key 静态可命中 12 语言表
      return this.t('符合这 {a} 个条件的有 {b} 款', '{a} filters · {b} matches')
        .replace('{a}', String(this.picked.length))
        .replace('{b}', String(n));
    }
    const observed: string = this.langCode;
    const cat: string = L(this.category, catLabelEn(this.category));   // ★ 繁體走 toTrad
    return Digits(cat + ' · ' + this.tn('{n} 款', '{n} games', n, '{n} игра', '{n} игры', '{n} игр'), this.langCode);

  }

  // ★ 性能：面板里 25 个芯片各调一次 tagCountIn ⇒ 25 × 354 = 8850 次遍历/渲染
  //   改成"一次遍历算完 25 个计数"并缓存
  private tagCountCache: number[] = [];
  private tagCountKey: string = '\u0000';

  private rebuildTagCounts(): void {
    const key: string = this.seg + '|' + this.category + '|' + this.picked.join(',');
    if (key === this.tagCountKey) {
      return;
    }
    this.tagCountKey = key;

    let base: GameMeta[];
    if (this.seg === Seg.FAV) {
      base = this.byIds(ProgressStore.favorites());
    } else if (this.seg === Seg.RECENT) {
      base = this.byIds(ProgressStore.recent());
    } else {
      base = gamesByCategory(this.category);
    }
    const tags: GameTag[] = ALL_TAGS;
    const counts: number[] = [];
    for (let i = 0; i < tags.length; i++) {
      counts.push(0);
    }
    for (let g = 0; g < base.length; g++) {
      const gt: string[] = base[g].tags;
      // 已选特征必须全中，才计入
      let pass: boolean = true;
      for (let k = 0; k < this.picked.length; k++) {
        if (gt.indexOf(this.picked[k]) < 0) {
          pass = false;
          break;
        }
      }
      if (!pass) {
        continue;
      }
      for (let t = 0; t < tags.length; t++) {
        if (gt.indexOf(tags[t].id) >= 0) {
          counts[t]++;
        }
      }
    }
    this.tagCountCache = counts;
  }

  /** 这个特征在当前池子里有多少款（读缓存） */
  private tagCountIn(id: string): number {
    this.rebuildTagCounts();
    for (let i = 0; i < ALL_TAGS.length; i++) {
      if (ALL_TAGS[i].id === id) {
        return this.tagCountCache[i] ?? 0;
      }
    }
    return 0;
  }

  private tagCountInSlow(id: string): number {
    let base: GameMeta[];
    if (this.seg === Seg.FAV) {
      base = this.byIds(ProgressStore.favorites());
    } else if (this.seg === Seg.RECENT) {
      base = this.byIds(ProgressStore.recent());
    } else {
      base = gamesByCategory(this.category);
    }
    let n: number = 0;
    for (let i = 0; i < base.length; i++) {
      const gt: string[] = base[i].tags;
      let all: boolean = true;
      // 已选特征 + 这一个，都要满足
      for (let k = 0; k < this.picked.length; k++) {
        if (gt.indexOf(this.picked[k]) < 0) {
          all = false;
          break;
        }
      }
      if (all && gt.indexOf(id) >= 0) {
        n++;
      }
    }
    return n;
  }

  private toggleTag(id: string): void {
    const i: number = this.picked.indexOf(id);
    const next: string[] = this.picked.slice();
    if (i >= 0) {
      next.splice(i, 1);
    } else {
      next.push(id);
    }
    this.picked = next;
  }

  private openGame(id: string): void {
    Haptics.tap();   // ★ 手感：进游戏这一下要有"按到了"的确认
    // ★ item ①：把"这张卡"标记为出场件，让 GameHost 能用工名 id 接上
    this.flyingId = 'card-' + id;
    router.pushUrl({ url: 'pages/GameHost', params: { id: id, sharedId: this.flyingId } });
    // ★★★ 2026-10-13 修复（奥森：「退出小游戏回主界面的切换动画十分诡异」）：
    //   根因：`flyingId` 原来在 onPageShow（= 返回时）才清 ⇒ **返回过程中它仍然挂着**
    //        ⇒ 卡片带着 geometryTransition，而游戏页正在退出 ⇒ 两端共享元素【匹配不上】
    //        ⇒ 出现"从虚无处飞回来"的怪动画 ✗
    //   修法：进入动画一结束就清（Motion.base 260ms + 余量 ⇒ 400ms）
    //        ⇒ 返回时 flyingId 已是空 ⇒ 只有干净的页面转场，没有幽灵共享元素 ✅
    setTimeout(() => {
      this.flyingId = '';
    }, 400);
  }

  // ─────────── 字母表视图（A-Z）───────────

  private azCache: AzSection[] = [];
  /** 缓存判据 = 当前列表的输入（分段|分类|特征）＋ tick（收藏/长按会 +1） */
  private azCacheKey: string = '\u0000';

  /**
   * 分组字母 —— **按当前语言显示名**取
   *
   * · 中文（简/繁）：`displayName()` 返回中文名 ⇒ `firstLetterOf` 查 `PY_FIRST` 得**拼音首字母**
   * · 其余 10 种语言：`displayName()` 返回 `enName` ⇒ 天然按英文 A-Z
   * · 数字开头（2048 / 24 点 / 9 路围棋…）⇒ `'#'` 组，排在最前
   *
   * ⚠️ 必须读一次 `this.langCode`：换语言时排序依据会变（中文按拼音、英文按英文字母）,
   *    不建立这个依赖，切语言后列表不会重排。
   */
  private azLetterOf(m: GameMeta): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return firstLetterOf(this.azSortName(m));
  }

  /** 排序/取字母用的显示名（中文走 displayName＝中文名，其余语言走 enName） */
  private azSortName(m: GameMeta): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return (observed === 'zh' || observed === 'zh-Hant') ? displayName(m) : m.enName;
  }

  /**
   * 按 `enName` 排好序、分好节的数据（带记忆化）
   *
   * ★ 缓存键 = 分段|分类|特征|tick|**语言**（换语言会换排序依据，必须重算）。
   */
  private azSections(): AzSection[] {
    // ★ 缓存键必须包含**筛选/分段**（list() 自己的缓存键就是这三样）——
    //   第一版我只用 renderRev 当键 ⇒ 切分类后字母表还是旧数据（自查抓到的）
    const key: string = this.seg + '|' + this.category + '|' + this.picked.join(',')
      + '|' + this.tick + '|' + this.langCode;   // ★ 带上语言：中文按拼音、英文按英文字母
    if (key === this.azCacheKey && this.azCache.length > 0) {
      return this.azCache;
    }
    this.azCacheKey = key;
    const arr: GameMeta[] = this.list().slice();   // 跟随当前筛选/分段
    // ★ 不用 localeCompare：它在不同平台（mac / 鸿蒙 ICU）结果不一致。
    //   直接比"拼音首字母 + 显示名"的字符串，跨平台一致。
    //   第三键用 enName：中文里有 2 对重名（汉诺塔 / 数字华容道）⇒ 没它顺序不稳定。
    arr.sort((a: GameMeta, b: GameMeta): number => {
      const ka: string = this.azLetterOf(a) + '\u0001' + this.azSortName(a) + '\u0001' + a.enName;
      const kb: string = this.azLetterOf(b) + '\u0001' + this.azSortName(b) + '\u0001' + b.enName;
      if (ka < kb) {
        return -1;
      }
      return ka > kb ? 1 : 0;
    });
    const out: AzSection[] = [];
    for (let i = 0; i < arr.length; i++) {
      const L: string = this.azLetterOf(arr[i]);
      if (out.length === 0 || out[out.length - 1].letter !== L) {
        out.push(new AzSection(L));
      }
      out[out.length - 1].games.push(arr[i]);
    }
    this.azCache = out;
    return out;
  }

  /**
   * 索引条的字母表（`'#'` + A–Z，共 27 项）—— 直接用 `core/GamePinyin` 的 `LETTERS`
   * （★ 不要自己 `String.fromCharCode` 拼：那样和拼音表的字母集可能不一致）
   */
  private azLetters(): string[] {
    return LETTERS;
  }

  private azCountCache: number[] = [];
  private azCountKey: string = '\u0000';

  /**
   * 每个字母下有几款（与 `azLetters()` 等长）—— **0 就是空组 ⇒ 索引条上置灰**
   * 带记忆化：27 项 × 每次 build 都算一遍没必要
   */
  private azCounts(): number[] {
    const key: string = this.azCacheKey;
    if (key === this.azCountKey && this.azCountCache.length > 0) {
      return this.azCountCache;
    }
    const secs: AzSection[] = this.azSections();
    const letters: string[] = this.azLetters();
    const out: number[] = [];
    for (let i = 0; i < letters.length; i++) {
      let n: number = 0;
      for (let k = 0; k < secs.length; k++) {
        if (secs[k].letter === letters[i]) {
          n = secs[k].games.length;
          break;
        }
      }
      out.push(n);
    }
    this.azCountCache = out;
    this.azCountKey = key;
    return out;
  }

  /** 点索引条：跳到该字母那一组（0 = `#`） */
  private azScrollTo(letter: string): void {
    Haptics.tap();
    const secs: AzSection[] = this.azSections();
    // ★ 先把字母表取到局部变量：`azLetters()` 每次调用都新建 27 元数组，
    //   放在循环里会被 codelinter 判「循环内频繁读状态」（且确实是白建 26 次）
    const letters: string[] = this.azLetters();
    const target: number = letters.indexOf(letter);
    if (target < 0) {
      return;
    }
    // ★ 状态只写一次、且在循环**外** —— codelinter 的 @performance/hp-arkui-no-state-var-access-in-loop
    //   对"循环里读/写 @State"会告警（每次访问都要过一遍依赖收集）
    let group: number = -1;
    for (let i = 0; i < secs.length; i++) {
      if (secs[i].letter === letter) {
        group = i;
        break;
      }
    }
    if (group < 0) {
      return;
    }
    this.azScroller.scrollToIndex(group, true, ScrollAlign.START);
    this.azCurrent = target;
  }

  /** 字母表里那一行的中文名（繁體要走 toTrad，跟别处口径一致） */
  private azZhName(m: GameMeta): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return (observed === 'zh' || observed === 'zh-Hant') ? displayName(m) : m.enName;
  }

  /** 字母表里那一行的副名（英文名；若主名已是英文则不重复显示） */
  private azEnName(m: GameMeta): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    if (observed === 'zh' || observed === 'zh-Hant') {
      return m.enName;
    }
    // 非中文语言：主名就是 enName ⇒ 副名用中文原名，方便对照
    return m.name;
  }

    /** 整句模板（读语言字段建立 ArkUI 依赖）—— 例：tn('{n} 局', '{n} games', 3) */
  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.langCode;
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column() {
      // ★★★ 2026-10-14 奥森：「我看到了你的自动收起，图标还是会闪现，并且收起动画有点不太好」
      //   ⇒ 根因：上一版用 if/else 切换 ⇒ 展开态组件被【销毁再重建】
      //      ⇒ ☀️🌐🎛️ 这些 emoji 图标要【重新渲染一遍】= 那一闪
      //   ⇒ 修法：两块【都常驻、不销毁】+ 透明度/位移做交叉淡入 ⇒ 图标不重渲染、动画也顺
      Column() {
        this.topBar()
        this.levelStrip()
        this.tagEntry()
        if (this.showFilter) {
          // ★ 展开筛选时收起下面的卡片：面板较高，不收起来会把计数行与网格挤出屏幕
          this.tagPanel()
        } else {
          this.dailyCard()
          this.randomCard()
        }
        this.segRow()
        if (this.seg === Seg.ALL && !this.showFilter) {
          CategoryBar({
            items: categoryList(),
            selected: this.category,
            theme: this.theme(),
            onPick: (c: GameCategory) => {
              this.pulseGrid();   // ★ 拉满：内容刷新脉冲
              animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
                this.category = c;
              });
            }
          })
        }
        this.countRow()
      }
      .width('100%')
      .visibility(this.effCollapsed() ? Visibility.None : Visibility.Visible)
      .opacity(this.effCollapsed() ? 0 : 1)
      .translate({ y: this.effCollapsed() ? -14 : 0 })

      // ★ 收起态的细条（常驻）：左边当前分类，右边【统一切换按钮】
      this.collapsedBar()

      if (this.list().length === 0) {
        this.emptyState()
      } else if (this.viewMode === ViewMode.AZ) {
        this.azList()
      } else {
        Grid() {
          ForEach(this.list(), (g: GameMeta, i: number) => {
            GridItem() {
              GameCard({
                meta: g,
                // ★ item ①：只有正在点开的那张卡参与共享元素补间
                sharedId: this.flyingId === ('card-' + g.id) ? this.flyingId : '',
                // ★ 2026-10-13「动画拉满」item ③：**只给首屏可见的前几款**排错峰。
                //   全量传 i 的后果：Grid 虚拟化 ⇒ 滚到第 100 款时它"刚创建"，
                //   enterDelay(100) 会再让它延迟进场 = 一边滚一边动，又乱又掉帧。
                // ★★★ 2026-10-14 奥森反馈「主界面滑动时下面的游戏总是闪现出来」⇒ 修：
                //   原来是 `i < 8 ? i : 8` —— 第 9 张之后【全部是 index=8】⇒ GameCard 的
                //   aboutToAppear 里 `enterDelay(8)` = 320ms 延迟 ⇒ 配合 Grid 的 cachedCount(6)
                //   一边滚一边新建卡片 ⇒ ★ 每张新卡都 opacity 0 起步、320ms 后才淡入 = "闪现"！
                //   ⇒ 改成 -1：★ 首屏之外【不做入场动画，直接显示】
                index: i < 8 ? i : -1,
                theme: this.theme(),
                streak: ProgressStore.streakOf(g.id),
                playedToday: ProgressStore.playedToday(g.id),
                onOpen: (id: string) => {
                  this.openGame(id);
                },
                onLongPress: (id: string) => {
                  // 长按 = 收藏 / 取消收藏，顺手给个提示
                  ProgressStore.toggleFavorite(id);
                  this.toast = ProgressStore.isFavorite(id)
                    ? this.t('⭐ 已收藏', '⭐ Saved') : this.t('已取消收藏', 'Removed');
                  this.tick = this.tick + 1;
                  setTimeout(() => {
                    this.toast = '';
                  }, 1400);
                }
              })
            }
            // ★★★★★ 2026-10-14 闪现【第 9 层 · 跳着走的真因】
            //   奥森原话：「突然出现一大块，而不是从下面连贯的滑上来（好比手表的指针，
            //             有些是跳着走的，有些走的比较连贯）」
            //   实测：卡片自然高度【不一致】= 212 / 240 / 288
            //     ⇒ 因为不同游戏的副标题行数不同 ⇒ Grid 每行都要【重新测量】
            //     ⇒ 无法预知行位置 ⇒ 滚动只能"整块跳" ⇒ ★ 他看到的"跳着走"
            //   ⇒ 修法：给 GridItem 一个【统一的确定高度】
            //   ★★★★★ 2026-10-14 奥森截图指出「这怎么间隔这么大啊？」⇒ 我犯了【单位错误】：
            //     dumpLayout 给的是【px】，而 .height() 收的是【vp】！
            //     屏幕 1320px ÷ 360vp ⇒ 1vp ≈ 3.67px
            //     卡片真实高度 212~288px ⇒ ÷3.67 ≈ 58~78vp
            //     我写了 232（当成 px 用了）⇒ 232vp × 3.67 = 851px ⇒ ★ 行距变 3 倍
            //   ⇒ 正确值：84vp（略高于最高的 78vp，留一点余量）
            // ★★★★★ 2026-10-14 奥森：「你也要注意语言切换和模式（大字和紧凑）后的界面噢」
            //   查出真问题：UiMode 的【elder 档把字号放大 30~42%】（md 16→21、xxs 12→17）
            //     而我这里写死 84 ⇒ ★ 大字模式下卡片文字会被裁掉！
            //   ⇒ 修法：高度【跟着模式算】
            //      normal 84 ｜ elder 112（×1.33）｜ simple 76（×0.9）
            .height(this.cardH())
          }, (g: GameMeta) => g.id + this.tick)
        }
        // ★★★ 2026-10-19 真机大字模式实拍后改：大字模式改【单列】
        //   实拍：副标题「一板一球，清空全场」在大字模式下被截成「一板一球，清…」
        //   算过：9 字 × 17px = 153vp，可用宽度只有 156-48-12-32 ≈ 64vp ⇒ 怎么缩都不够
        //   ⇒ 大字模式单列（卡片通栏 328vp，文字区 236vp）
        .columnsTemplate(this.uiMode === 'elder' ? '1fr' : '1fr 1fr')
        .columnsGap(Space.md)
        .rowsGap(Space.md)
        // ★ 拉满：内容刷新脉冲的视觉（收紧 + 半透 ⇒ 弹回）
        .scale({ x: this.gridPulse ? 0.972 : 1.0, y: this.gridPulse ? 0.972 : 1.0 })
        .opacity(this.gridPulse ? 0.62 : 1.0)
        .padding({ left: Space.lg, right: Space.lg, bottom: Space.xxxl })
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        // ★★★ 2026-10-14 奥森新要求：上滑时【自动收起】顶部，滑回顶部自动展开
        //   用 onScrollIndex（首个可见项序号）判定 —— 不依赖 Scroller，最稳
        .onScrollIndex((first: number) => {
          // ★ 手动切换后 2 秒内不抢（奥森要求手动与自动并存）
          if (Date.now() < this.manualUntil) {
            return;
          }
          // ★★★ 2026-10-14 奥森：「游戏图标整个都会闪，就是那一整个小游戏的方块」
          //   ⇒ 我查出的【自引入】根因：甩动中 first 会在 2~3 之间抖动
          //      ⇒ topCollapsed 反复翻转 ⇒ Grid 高度反复变化 ⇒ 【整块重排】= 方块闪
          //   ⇒ 修法①：防抖 —— 两次切换至少间隔 900ms（慢动画也顺理成章）
          const now: number = Date.now();
          if (now - this.lastToggle < 900) {
            return;
          }
          //   ⇒ 修法②：迟滞（收起要滚过 2 行，展开要回到 1 行以内，中间不动）
          //   ★ 2026-10-14 奥森要「留更多空间给下面的游戏列表」+ 首屏网格只有 1 行
          //     ⇒ 门槛 4 行 → 2 行：一滑就收起，立刻把空间让给列表
          let want: boolean = this.topCollapsed;
          if (first >= 2) {
            want = true;
          } else if (first <= 1) {
            want = false;
          }
          if (want !== this.topCollapsed) {
            this.lastToggle = now;
            // ★ 奥森：「收起动画有点快了，动态效果不太好」⇒ 520ms + 极缓减速，慢而"落得住"
            animateTo({ duration: 520, curve: Curve.ExtremeDeceleration }, () => {
              this.topCollapsed = want;
            });
          }
        })
        // ★★★ 2026-10-14 奥森反馈「应该先都加载好，往下快速滑动时也能连贯显示」：
      //   6 ⇒ 20：多预加载 14 张卡 ⇒ 快速滑动时内容【已经建好】，不必边滚边建 ⇒ 连贯 ✓
      //   （配合上面 index 的修改：预加载的卡片走 index<0 快速路径 ⇒ 一就位就是可见的）
      .cachedCount(20)
      }
    }
    .width('100%')
    .height('100%')

    // 长按收藏后的小提示（浮在底部导航之上）
    if (this.toast.length > 0) {
      Text(this.toast)
        .fontSize(FontSize.sm).fontColor(Color.White)
        .padding({ left: Space.lg, right: Space.lg, top: Space.sm, bottom: Space.sm })
        .backgroundColor(Overlay.scrim)
        .borderRadius(Radius.full)
        .margin({ bottom: 96 })
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast }))
    }
    }
    .width('100%')
    .height('100%')
  }

  // ─────────── 各区块 ───────────

  // ★★★ 2026-10-14 奥森要求：「也要能手动收起（加一个按钮）」「就和那个展开按钮在一个地方」
  //   +「加一个两种按钮的切换小动画（配置要拉满）」
  //   ⇒ 一个【位置固定】的切换按钮：展开态朝上（收起）／收起态朝下（展开）
  //   ⇒ 两个块共用一个视觉位置 ⇒ 切换时图标【原地翻转 180°】+ 弹簧 ⇒ 动画拉满
  @Builder
  collapseToggle() {
    Row({ space: 4 }) {
      Text(this.topCollapsed
        ? this.t('展开', 'Expand')
        : this.t('收起', 'Collapse'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkFaint)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('⌄')
        .accessibilityLevel('no')
        .fontSize(FontSize.md)
        .fontColor(this.theme().inkFaint)
        // ★★★ 切换小动画（奥森：「配置要拉满」）：收起态朝下(0°)、展开态朝上(180°)
        //   450ms + 弹簧 ⇒ 原地翻转有回弹，观感更好（原来 240ms 太快）
        .rotate({ angle: this.topCollapsed ? 0 : 180 })
        .animation({ duration: 520, curve: Motion.spring() })
    }
    .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
    .backgroundColor(this.theme().surfaceAlt)
    .borderRadius(Radius.full)
    .onClick(() => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      const now: number = Date.now();
      animateTo({ duration: 520, curve: Curve.ExtremeDeceleration }, () => {
        this.topCollapsed = !this.topCollapsed;
        // ★ 手动操作后 2 秒内不被自动收起逻辑抢回（体验）
        this.manualUntil = now + 2000;
        this.lastToggle = now;
      });
    })
  }

  @Builder
  collapsedBar() {
    Row({ space: Space.sm }) {
      // 左边：收起时显示当前分类；展开时显示游戏总数（两边都不重复、都有信息量）
      Text(this.topCollapsed
        ? L(this.category, catLabelEn(this.category))
        : Digits(String(this.list().length) + this.t(' 款', ' games'), this.langCode))
        .fontSize(FontSize.xs)
        .fontColor(this.topCollapsed ? this.theme().ink : this.theme().inkFaint)
        .fontWeight(this.topCollapsed ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      // 右边：★ 位置固定的统一切换按钮（常驻，不随状态销毁 ⇒ 图标不闪）
      this.collapseToggle()
    }
    .width('100%')
    // ★ 大字/紧凑模式下高度也要跟着变（否则字会被裁）
    .height(this.collapsedH())
    .padding({ left: Space.lg, right: Space.lg })
    // ★ 展开态【不占位】（Visibility.None 不参与布局），但组件常驻 ⇒ 图标不重渲染
    .visibility(this.effCollapsed() ? Visibility.Visible : Visibility.None)
    .opacity(this.effCollapsed() ? 1 : 0)
    .translate({ y: this.effCollapsed() ? 0 : 10 })
  }

  @Builder
  topBar() {
    Row() {
      Column({ space: 2 }) {
        Text('One More')
          .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
        // ★ 2026-10-13：加了 9 路围棋后写死的 354 就露馅了 ⇒ 改成动态（同页 SettingsTab 已是动态）
        // ★★★ 2026-10-14 加构建水印（奥森连说三次"还是闪现"而我看不到他的屏）：
        //   目的：他能一眼看出模拟器/真机里装的是【哪一版】⇒ 不再"版本不确定"
        //   水印 = 构建日期时分（用 BUILD_TAG 常量）
        Text(Digits(this.tn('{n} 款小游戏，不用联网也能玩', '{n} games. No Wi-Fi needed.', GAMES.length), this.langCode) + '  ·  ' + 'v' + About.VERSION)
          .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: Space.xs }) {
      Text(this.dark ? '🌙' : '☀️')
        .fontSize(FontSize.lg).width(Layout.touchMin).height(Layout.touchMin).textAlign(TextAlign.Center)
        .backgroundColor(this.theme().surface).borderRadius(Radius.full)
        .shadow(Shadow.card)
        // ★ item ④：按下弹一下（1 → 1.08 → 1），松手弹回
        .scale({ x: this.darkPressed ? IconPress.scale : 1, y: this.darkPressed ? IconPress.scale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
          this.darkPressed = IconPress.onTouch(this.darkPressed, e);
        })
        .onClick(() => {
          Haptics.tap();   // ★ 2026-10-19 按压反馈
          ProgressStore.setThemeDark(!this.dark);
        })

      // 语言快切（当前语言 ⇄ English）
      // ★ 2026-10-13（P4）：旧版是**中英二元** —— 顶栏永远显示「中/EN」，在繁体/日语/韩语…下
      //   点一下会**强制切回简体**（用户的语言被静默改掉）。现在：
      //   ① 徽标显示**当前**语言；② 只在「当前语言 ⇄ English」之间走，回程恢复原来那门语言。
      Text(this.langBadge())
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(this.isEN() ? this.accentColor() : this.theme().inkSoft)
        .width(Layout.touchMin).height(Layout.touchMin).textAlign(TextAlign.Center)
        .backgroundColor(this.theme().surface).borderRadius(Radius.full)
        .shadow(Shadow.card)
        .margin({ left: Space.xs })
        .scale({ x: this.langPressed ? IconPress.scale : 1, y: this.langPressed ? IconPress.scale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
          this.langPressed = IconPress.onTouch(this.langPressed, e);
        })
        .onClick(() => {
          Haptics.tap();
          const cur: string = this.langCode;
          let next: string = 'en';
          if (cur === 'en') {
            // 回程：恢复切到英文之前的那门语言（默认简体）
            next = AppStorage.get<string>('langPrevNonEn') ?? 'zh';
          } else {
            // 记住"非英文"的那门语言，回程才不会把繁体/日语打回简体
            AppStorage.setOrCreate('langPrevNonEn', cur);
          }
          I18n.set(next);          // I18n.set 内部已经写 AppStorage，别重复写
          ProgressStore.saveLang(next);   // ★ 落盘
          this.renderRev = this.renderRev + 1;
        })
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xl, bottom: Space.sm })
  }

  @Builder
  levelStrip() {
    Row({ space: Space.md }) {
      Stack() {
        Circle({ width: 38, height: 38 }).fill(this.accentColor())
        Column() {
          Text('LV').fontSize(FontSize.badge).fontColor(Overlay.onColorSoft)
          Text(Digits(String(this.level), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
      }
      .width(38).height(38)

      Column({ space: 4 }) {
        Row() {
          Text(Digits(this.tn('再攒 {n} 点经验就升级', '{n} XP to next level', this.xpToNext()), this.langCode))
            .fontSize(FontSize.xxs).fontColor(this.theme().inkSoft)
          Blank()
          Text(Digits(this.levelPct() + '%', this.langCode))
            .fontSize(FontSize.xxs).fontColor(this.accentColor()).fontWeight(FontWeight.Bold)
        }
        .width('100%')
        Stack({ alignContent: Alignment.Start }) {
          Row().width('100%').height(4).backgroundColor(this.theme().line).borderRadius(Layout.hairline)
          Row().width(this.levelPct() + '%').height(4).backgroundColor(this.accentColor()).borderRadius(Layout.hairline)
        }
        .width('100%').height(4)
      }
      .layoutWeight(1)

      Row({ space: 3 }) {
        Text('🔥').fontSize(FontSize.sm)
          .accessibilityLevel('no')
        Text(Digits(this.tn('{n} 天', '{n} d', this.streak, '{n} день', '{n} дня', '{n} дней'), this.langCode)).fontSize(FontSize.xs).fontWeight(FontWeight.Bold)
          .fontColor(this.streak > 0 ? Palette.amber : this.theme().inkFaint)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(this.playedTodayAll ? '#1AF59E0B' : this.theme().surfaceAlt)
      .borderRadius(Radius.full)
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  dailyCard() {
    if (this.dailyMeta() !== undefined) {
      Row({ space: Space.md }) {
        Text(this.dailyDone ? '✅' : '🎯')
          .fontSize(FontSize.xxl)
          .width(46).height(46).textAlign(TextAlign.Center)
          .backgroundColor(Overlay.chipSoft)
          .borderRadius(Radius.md)
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(this.t('今天这一局', 'Today\'s pick')).fontSize(FontSize.xxs).fontColor(Overlay.onColorSoft)
            Text(this.dailyDone ? this.t('今天已完成', 'Done today') : this.t('通关 +50 经验', 'Clear it: +50 XP'))
              .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold)
              .fontColor(this.dailyDone ? '#A7F3D0' : '#FDE68A')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(Overlay.chip)
              .borderRadius(Radius.full)
          }
          Text(this.dailyName())
            .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
            .fontColor(Overlay.onColor).maxLines(1)
            // ★★★ 2026-10-16 实拍西语抓到 BUG：只有 maxLines(1) 没有 textOverflow
            //   ⇒ 长文案被卡片边缘【硬切】（西语「Encuentra la palabra · Encuentra la」）
            //   ⇒ 修：加 Ellipsis ⇒ 变成「Encuentra la palabra · Encuen…」
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.dailyDone ? this.t('再看看', 'View') : this.t('开始 ›', 'Play ›'))
          .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).fontColor(Overlay.onColor)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(Overlay.chip)
          .borderRadius(Radius.full)
      }
      .width('100%')
      .padding(Space.md)
      .margin({ left: Space.lg, right: Space.lg, top: Space.sm })
      .backgroundColor(this.accentColor())
      .borderRadius(Radius.md)
      .shadow(Shadow.card)
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        this.openGame(this.dailyId);
      })
    }
  }

  @Builder
  randomCard() {
    Row({ space: Space.sm }) {
      Text('🎲').fontSize(FontSize.md)
        .accessibilityLevel('no')
      Text(this.t('随机来一局', 'Surprise me')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Blank()
      Text(this.t('挑不出来？交给运气', 'Can\'t decide? Let luck pick')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
    .margin({ left: Space.lg, right: Space.lg, top: Space.sm })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .onClick(() => {
      const pool: GameMeta[] = this.list();
      if (pool.length === 0) {
        return;
      }
      const pick: GameMeta = pool[Math.floor(Math.random() * pool.length)];
      this.openGame(pick.id);
    })
  }

  /** 「按特征挑游戏」入口 */
  @Builder
  tagEntry() {
    Row({ space: Space.sm }) {
      Text('🎛️').fontSize(FontSize.md)
        .accessibilityLevel('no')
      Text(this.picked.length === 0
        ? this.t('按喜好挑游戏', 'Pick by taste')
        : this.t('已选 {n} 个条件', '{n} filters on').replace('{n}', String(this.picked.length)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(this.picked.length > 0 ? this.accentColor() : this.theme().ink)
      Blank()
      if (this.picked.length > 0) {
        Text(this.t('清空', 'Clear'))
          .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.theme().surfaceAlt)
          .borderRadius(Radius.full)
          .onClick(() => {
            Haptics.tap();   // ★ 2026-10-19 按压反馈
            this.picked = [];
          })
      }
      Text(this.showFilter ? this.t('收起 ▲', 'Less ▲') : this.t('展开 ▼', 'More ▼'))
        .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
    }
    .width('100%')
    .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
    .margin({ left: Space.lg, right: Space.lg, top: Space.sm })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .onClick(() => {
      animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
        this.showFilter = !this.showFilter;
      });
    })
  }

  /** 特征筛选面板：6 组，每组的特征做成可点芯片 */
  @Builder
  tagPanel() {
    Scroll() {
      Column({ space: Space.sm }) {
      ForEach(tagsByGroup(), (grp: string) => {
        Column({ space: 6 }) {
          Text(L(grp, tagsIn(grp).length > 0 ? tagsIn(grp)[0].enGroup : grp))   // ★ 繁體走 toTrad
            .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(tagsIn(grp), (t: GameTag) => {
              this.tagChip(t)
            }, (t: GameTag) => t.id)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (grp: string) => grp)
      }
      .width('100%')
      .padding(Space.md)
    }
    .width('100%')
    .constraintSize({ maxHeight: 300 })
    .margin({ left: Space.lg, right: Space.lg, top: Space.sm })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  tagChip(t: GameTag) {
    Text(t.icon + ' ' + L(t.label, t.enLabel) + ' ' + this.tagCountIn(t.id))   // ★ 繁體走 toTrad
      .fontSize(FontSize.xxs)
      .fontWeight(this.picked.indexOf(t.id) >= 0 ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.picked.indexOf(t.id) >= 0 ? Color.White : this.theme().inkSoft)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .margin({ right: 6, bottom: 6 })
      .backgroundColor(this.picked.indexOf(t.id) >= 0 ? this.accentColor() : this.theme().surfaceAlt)
      .borderRadius(Radius.full)
      .animation({ duration: Motion.fast, curve: Motion.spring() })
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
          this.toggleTag(t.id);
        });
      })
  }

  @Builder
  segRow() {
    Row({ space: Space.md }) {   // ★ 2026-10-13 奥森：「要隔开一定距离」⇒ 10vp → 16vp

      this.segBtn(Seg.ALL, '🎮 全部', '🎮 All')
      this.segBtn(Seg.FAV, '⭐ 我收藏的 ', '⭐ Saved ')
      this.segBtn(Seg.RECENT, '🕐 玩过的', '🕐 Played')
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.sm })
  }

  @Builder
  segBtn(s: Seg, zh: string, en: string) {
    // ★ 在 Builder **内部**取词，不要在调用处取 ——
    //   @Builder 的参数会被 ArkUI 记忆化，传进去的字符串换语言时不会重算
    Text(this.t(zh, en))
      .fontSize(FontSize.xs)
      .fontWeight(this.seg === s ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.seg === s ? Color.White : this.theme().inkSoft)
      .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
      .backgroundColor(this.seg === s ? this.accentColor() : this.theme().surface)
      .borderRadius(Radius.full)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.spring() })
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        this.pulseGrid();   // ★ 拉满：内容刷新脉冲
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.seg = s;
        });
      })
  }

  /**
   * ★★★ 2026-10-14 新增：卡片高度【跟随界面模式】——
   *   起因：奥森要我注意"大字/紧凑模式后的界面"；
   *   查得 UiMode.elder 会把字号放大 30~42%，而格子高度原来写死 84 ⇒ 大字模式会裁字。
   *   normal 84 ｜ elder 112 ｜ simple 76
   */
  /**
   * ★★★ 2026-10-15 大字模式修复（第二版 —— 第一版用 aboutToAppear 没生效）：
   *   实测：大字模式下顶部 UI 占满整屏 ⇒ 网格 GridItem 0 个（首屏看不到任何游戏）
   *   第一版在 aboutToAppear 里判 uiMode ⇒ 不生效（那时 @StorageProp 可能还是旧值）
   *   ⇒ 这一版改成【渲染时算】：effCollapsed() 直接读 uiMode（@StorageProp）
   *     ⇒ ArkUI 的依赖追踪能看到 ⇒ 一定重算 ✓
   *   ★ 尊重用户：大字模式下他手点"展开"后就不再强制收起（elderExpanded）
   */
  @State private elderExpanded: boolean = false;

  private effCollapsed(): boolean {
    if (this.uiMode === 'elder' && !this.elderExpanded) {
      return true;
    }
    return this.topCollapsed;
  }

  /** ★ 收起条高度：同样跟随模式（大字模式要更高才放得下） */
  private collapsedH(): number {
    if (this.uiMode === 'elder') {
      return 60;
    }
    if (this.uiMode === 'simple') {
      return 42;
    }
    return 46;
  }

  private cardH(): number {
    // ★★★ 2026-10-19 真机大字模式实拍后重算（奥森：「任何地方都要注意」）
    //   实拍现象：elder 下「宝石迷阵」被挤成两行、「打砖块」副标题被截
    //
    //   按 elder 档真实数值算：
    //     padding Space.md 21×2 = 42 ＋ 标题 2 行(21×1.4×2) 58.8
    //     ＋ 间隔 Space.xs 18 ＋ 副标题 1 行(17×1.4) 23.8  = 142.6 vp
    //   而写死的是 112 ⇒ 差 30.6 vp ⇒ 就是实拍那个样子
    //
    //   normal / simple 也是零余量：normal 需 84 恰好写 84，simple 需 76 恰好写 76
    //   ⇒ 三档全部加 8–31 vp 余量（不会明显变稀，因为多的是留白）
    if (this.uiMode === 'elder') {
      return 146;   // 需 142.6，给 3.4 余量
    }
    if (this.uiMode === 'simple') {
      return 84;    // 需 76，给 8 余量
    }
    return 92;      // 需 84，给 8 余量
  }

  @Builder
  countRow() {
    Row({ space: Space.sm }) {
      Text(this.countLabel())
        .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
      Blank()
      // ★ 视图切换：网格 ⇄ 字母表（奥森 2026-10-13「再加一个游戏列表，按字母排序」）
      //   放在这一行是因为它字最少；两个小胶囊，选中态跟随主题色
      this.viewPill(ViewMode.GRID, '▦', '网格', 'Grid')
      this.viewPill(ViewMode.AZ, '🔤', 'A-Z', 'A-Z')
      Text(this.tn('通关 {n} 局', 'Cleared {n}', this.totalSolved))
        .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
      // ★★★ 2026-10-14 奥森截图「这怎么间隔这么大啊？」⇒ 真问题是【顶部太长，网格只剩 1 行】
      //   我上一版把 collapsedBar 常驻 ⇒ 展开态白占一行（46vp ≈ 170px）
      //   ⇒ 把「收起」按钮【并入计数行右侧】—— 与收起态的「展开」按钮同一视觉位置
      //     ⇒ 展开态省下一行 ⇒ 网格多一行
      this.collapseToggle()
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xs, bottom: Space.xs })
  }

  /** 视图切换的小胶囊 */
  @Builder
  viewPill(mode: ViewMode, icon: string, zh: string, en: string) {
    // ★★★ 2026-10-16 实拍德语抓到 BUG：原来收的是【已解析好的 label】⇒
    //   @Builder 参数被 ArkUI 记忆化 ⇒ 换语言后不重算 ⇒
    //   ★ 德语界面里「网格」停在上一门语言（俄语「Сетка」）！
    //   ⇒ 修：收 (zh, en)，在 Builder **内部**取词（这才与下面这行注释一致）
    Text(icon + ' ' + this.t(zh, en))
      .fontSize(FontSize.xxs)
      .fontWeight(this.viewMode === mode ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.viewMode === mode ? Color.White : this.theme().inkSoft)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(this.viewMode === mode ? this.accentColor() : this.theme().surfaceAlt)
      .border({ width: 1, color: this.viewMode === mode ? this.accentColor() : this.theme().line })
      .borderRadius(Radius.full)
      .animation({ duration: Motion.fast, curve: Motion.spring() })
      .onClick(() => {
        Haptics.tap();
        // ★ 每次切到 A-Z 都重放一次首屏错峰（先归零再置起，否则第二次进来不动）
        this.azShown = (mode !== ViewMode.AZ);
        this.pulseGrid();   // ★ 拉满：内容刷新脉冲（网格 ⇄ 字母表）
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.viewMode = mode;
        });
        if (mode === ViewMode.AZ) {
          setTimeout(() => {
            this.azShown = true;
          }, 30);
        }
      })
  }

  /** 空态标题（走字典，12 语言；繁体由 L() 内部转换） */
  private emptyTitle(): string {
    if (this.picked.length > 0) {
      return this.t('没有同时满足这些条件的游戏', 'No game matches all those filters');
    }
    if (this.seg === Seg.FAV) {
      return this.t('还没收藏过游戏', 'No saved games yet');
    }
    if (this.seg === Seg.RECENT) {
      return this.t('还一局都没玩过', 'You have not played a round yet');
    }
    return this.t('这一类还没有游戏', 'No games in this category yet');
  }

  /** 空态提示 */
  private emptyHint(): string {
    if (this.picked.length > 0) {
      return this.t('少挑几个条件试试？', 'Try picking fewer filters');
    }
    if (this.seg === Seg.FAV) {
      return this.t('进任意一局，点右上角 ⭐ 就收藏了', 'Open any game and tap ⭐ in the corner to save it');
    }
    if (this.seg === Seg.RECENT) {
      return this.t('随便挑一局，这里就记上了', 'Play any round and it shows up here');
    }
    return this.t('换个分类看看', 'Try another category');
  }

  // ─────────── 字母表视图 ───────────

  /**
   * A-Z 游戏列表（奥森 2026-10-13「应该再加一个游戏列表，按字母排序」）
   *
   * 三条性能/正确性约束：
   *   ① **List 自带虚拟化** ⇒ 355 行不会一次性全渲染（和 Grid 同理，别塞进 Scroll）
   *   ② 分组用 `ListItemGroup` + 组内 `ForEach` ⇒ **组头不能是 @Builder 传参**（ArkUI 不建观察），
   *      这里组头是内联 `Text`，直接读 `sec.letter` 这个普通字段
   *   ③ 列表项也**内联**（`azRow` 只做视觉，参数是数据对象不是"值快照"）
   */
  @Builder
  azList() {
    Row() {
      List({ scroller: this.azScroller }) {
        ForEach(this.azSections(), (sec: AzSection, secIndex: number) => {
          ListItemGroup({
            header: this.azHeader(sec.letter, sec.games.length, secIndex === 0 ? 0 : -1)
          }) {
            ForEach(sec.games, (g: GameMeta, gi: number) => {
              ListItem() {
                // ★ item ③：只让**首屏看得见的那十几行**错峰进场。
                //   判断放在调用处（@Builder 的参数是"值快照"，在 build 里算不会建立依赖，
                //   但也因此不会因为内部状态变化而重算 —— 正合我意：进场只做一次）。
                this.azRow(g, (secIndex === 0 && gi < 10) ? gi : -1)
              }
            }, (g: GameMeta) => g.id + this.tick)
          }
        }, (sec: AzSection) => sec.letter)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      // ★★★ 2026-10-14 同类全扫：与网格同步预加载量（6→20 那次）
      //   4 → 20 ⇒ 字母表快速滚动时行已建好，不再边滚边建 ⇒ 连贯 ✓
      .cachedCount(20)
      .sticky(StickyStyle.Header)
      // 滚动时把当前字母同步到右侧索引条
      .onScrollIndex((first: number) => {
        const i: number = first;
        if (i >= 0 && i < this.azSections().length) {
          const L: string = this.azSections()[i].letter;
          const idx: number = this.azLetters().indexOf(L);
          if (idx >= 0 && idx !== this.azCurrent) {
            this.azCurrent = idx;
          }
        }
      })

      // 右侧 A-Z 索引条
      this.azIndexBar()
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top)
  }

  /**
   * 右侧 A-Z 索引条（**自绘**）
   *
   * ## 为什么不用内置 `AlphabetIndexer`
   * 奥森要求「**没有该字母的置灰**」，而内置组件查遍 `alphabet_indexer.d.ts` 只有
   * `color / selectedColor / selectedBackgroundColor / itemSize / font / usingPopup`
   * —— **没有 per-item 禁用或变灰的 API** ⇒ 它只能"点了不跳"，做不到"看着就是灰的"。
   *
   * ## 为什么是 @Builder 而不是自定义组件
   * codelinter 对自定义组件报 `@performance/avoid-overusing-custom-component-check`；
   * 而且这个条**完全依赖本组件状态**（`azCurrent` / `azCounts()`）——
   * @Builder 直接读 `this.xxx`，**不需要传参** ⇒ 天然绕开「@Builder 参数不建立 ArkUI 观察」那个坑。
   */
  @Builder
  azIndexBar() {
    // ★★★ 2026-10-14 第四次修（终于对了）：
    //   前三次失败的根因链：
    //     ① layoutWeight(1) 与 .height() 冲突 ⇒ height 被忽略
    //     ② 去掉 layoutWeight 后，Text 的高度【不能小于行高】⇒ fontSize 9 ⇒ 每项仍 13.35vp
    //     ③ 27 × 13.35 = 360vp > 可用 240vp ⇒ R~Z 仍被裁
    //   ⇒ 终解：**分两列**（27 项 ⇒ 14 行）⇒ 14 × 13.35 = 187vp ✓ 一定装得下
    Row() {
      Column() {
      ForEach(this.azLetters().slice(0, 14), (letter: string, i: number) => {
        Text(letter)
          .fontSize(9)   // ★ 显式小字号（不用档位，避免档位最小值不够小）
          .fontWeight(i === this.azCurrent ? FontWeight.Bold : FontWeight.Normal)
          // 空组 → 最淡（置灰）；当前段 → 主题色；其余 → 次要色
          .fontColor(this.azCounts()[i] === 0
            ? this.theme().lineSoft
            : (i === this.azCurrent ? this.accentColor() : this.theme().inkFaint))
          // ★ 空组 `enabled(false)`：不可点、不参与触摸 —— 与"置灰"视觉配套
          .enabled(this.azCounts()[i] > 0)
          // ★★ 2026-10-13 真机 BUG 修复（奥森报「A-Z 后面的字母根本不显示」）：
          //   原来是**固定 13vp/项** ⇒ 27×13 = 351vp。
          //   但真机（Mate 70）列表区比模拟器矮 ⇒ 仍然装不下 ⇒ S–Z 被裁掉。
          //   ⇒ 改成【按可用高度均分】：layoutWeight(1) + 最小高度
          //     ⇒ 无论什么屏幕、什么字号档位，27 个字母都一定装得下。
          .width(18)
          // ★★★ 2026-10-14 第三次修（关键发现）：
          //   【layoutWeight(1) 与 .height() 冲突】—— layoutWeight 生效时显式 height 被忽略
          //   ⇒ 前两次修（layoutWeight + minHeight / layoutWeight + height）都无效，仍只到 Q。
          //   修法：**去掉 layoutWeight**，改用【固定小高度】⇒ 27 × 11vp = 297vp，
          //        容器够高就自然装下；不够高时由外层 Column 的 scroll 兜底（见下）。
          .height(11)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
          .textAlign(TextAlign.Center)
          .borderRadius(Radius.xs)
          .backgroundColor(i === this.azCurrent ? this.theme().surfaceAlt : Color.Transparent)
          .animation({ duration: Motion.fast, curve: Motion.spring() })
          .onClick(() => {
            Haptics.tap();   // ★ 2026-10-19 按压反馈
            if (this.azCounts()[i] === 0) {
              return;
            }
            this.azScrollTo(letter);
          })
      }, (letter: string) => letter)
      }
      Column() {
      ForEach(this.azLetters().slice(14), (letter: string, i0: number) => {
        Text(letter)
          .fontSize(9)
          .fontWeight((i0 + 14) === this.azCurrent ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.azCounts()[i0 + 14] === 0
            ? this.theme().lineSoft
            : ((i0 + 14) === this.azCurrent ? this.accentColor() : this.theme().inkFaint))
          .enabled(this.azCounts()[i0 + 14] > 0)
          .width(18).height(11).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Clip })
          .textAlign(TextAlign.Center)
          .borderRadius(Radius.xs)
          .backgroundColor((i0 + 14) === this.azCurrent ? this.theme().surfaceAlt : Color.Transparent)
          .animation({ duration: Motion.fast, curve: Motion.spring() })
          .onClick(() => {
            if (this.azCounts()[i0 + 14] === 0) {
              return;
            }
            this.azScrollTo(letter);
          })
      }, (letter: string) => letter)
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    // ★★★ 2026-10-14 真机/模拟器实测修复（奥森第 3 号投诉【复现】：索引条只显示到 Q，R~Z 被裁）：
    //   根因：Column 只有 maxHeight、没有【确定高度】⇒ 内部 Text 的 layoutWeight(1) 不生效
    //        （ArkUI 的 layoutWeight 需要父容器高度确定才能分配）⇒ 27 项按自然高度排 ⇒ 溢出被裁。
    //   修法：给 Column 显式 height('100%') ⇒ layoutWeight 生效 ⇒ 27 项均分可用高度。
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .width(40)                    // ★★ 两列各 18vp ⇒ 容器必须 ≥36vp（原来是 22 ⇒ 右列被水平裁掉！）
    .margin({ right: Space.xs })
  }

  /** 组头：一枚字母 + 该字母下的款数（不是 @Builder 传值 —— 直接读参数对象） */
  @Builder
  azHeader(letter: string, count: number, enterIdx: number) {
    Row({ space: Space.xs }) {
      Text(letter)
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(this.accentColor())
      Text(this.tn('{n} 款', '{n} games', count, '{n} игра', '{n} игры', '{n} игр'))
        .fontSize(FontSize.micro).fontColor(this.theme().inkFaint)
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xs, bottom: 2 })
    .backgroundColor(this.theme().bg)
    .opacity(enterIdx >= 0 ? (this.azShown ? 1 : 0) : 1)   // ★ azShown 是 boolean ⇒ opacity 要 number（编译期就报 No overload）
    .animation({ duration: Motion.base, curve: Motion.enter(),
                 delay: enterIdx >= 0 ? Motion.stagger(enterIdx) : 0 })
  }

  /**
   * 列表行：图标 + 主名 + 副名（点进去能玩）
   * ★ 图标沿用首页那套**预渲染位图**（`iconOf`），不是 emoji —— 尺寸才稳定
   */
  /**
   * @param enterIdx ≥0 ⇒ 这是**首屏**第几行，据此排错峰进场；-1 ⇒ 不做进场动效
   *        （滚动中新建的行若也做，就会"边滚边动"，又乱又掉帧）
   */
  @Builder
  azRow(m: GameMeta, enterIdx: number) {
    Row({ space: Space.sm }) {
      if (iconOf(m.id) !== undefined) {
        Image(iconOf(m.id))
          .width(40).height(40)
          .objectFit(ImageFit.Contain)
          .draggable(false)
      } else {
        Text(m.icon).fontSize(FontSize.lg).width(40).height(40).textAlign(TextAlign.Center)
      }

      Column({ space: 2 }) {
        Text(this.azZhName(m))
          .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.azEnName(m))
          .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (ProgressStore.streakOf(m.id) > 0) {
        Row({ space: 2 }) {
          Text('🔥').fontSize(FontSize.micro)
            .accessibilityLevel('no')
          Text(Digits(String(ProgressStore.streakOf(m.id)), this.langCode)).fontSize(FontSize.micro).fontColor(this.theme().inkSoft)
        }
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xs, bottom: Space.xs })
    // ★ 错峰进场：首屏各行依次淡入 + 轻微上移；其它行 enterIdx = -1 ⇒ 恒定显示
    .opacity(enterIdx >= 0 ? (this.azShown ? 1 : 0) : 1)   // ★ azShown 是 boolean ⇒ opacity 要 number（编译期就报 No overload）
    .translate({ y: enterIdx >= 0 ? (this.azShown ? 0 : 12) : 0 })
    .animation({
      duration: Motion.base,
      curve: Motion.enter(),
      delay: enterIdx >= 0 ? Motion.stagger(enterIdx) : 0
    })
    .onClick(() => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      this.openGame(m.id);
    })
  }

  @Builder
  emptyState() {
    Column({ space: Space.md }) {
      Text(this.seg === Seg.FAV ? '⭐' : (this.seg === Seg.RECENT ? '🕐' : '🔍'))
          .accessibilityLevel('no')   // 装饰性 emoji 不朗读（与 StatsTab 对齐）
        .fontSize(FontSize.hero)
      Text(this.emptyTitle())
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.emptyHint())
        .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(Space.xxl)
        // ★ 2026-10-19 自查 ⑦：空状态原来是"瞬间出现"，没有入场感
        //   ⇒ 淡入 + 轻微上浮（与全应用的进场语言一致）
        .transition(TransitionEffect.OPACITY
          .animation({ duration: Motion.base, curve: Motion.spring() })
          .combine(TransitionEffect.translate({ y: 10 })
            .animation({ duration: Motion.base, curve: Motion.spring() })))
  }
}
