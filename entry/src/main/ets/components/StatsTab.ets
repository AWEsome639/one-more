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

import { router } from '@kit.ArkUI';
import { Digits } from '../core/I18n';   // ★ 2026-10-16 数字本地化
import { Bp } from '../core/Bp';
// ★ 2026-10-13「动画拉满」：数字滚动（从 GameHost 提取成公共件，见 core/MotionKit.ets）
import { RollingNumber } from '../core/MotionKit';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Overlay, Layout, Accent, Cell } from '../core/Design';
import { GAMES, GameMeta, GameCategory, CatCount, categoryList, findGame, colorOf, displayName, displayTagline, gamesByCategory } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
import { LevelHeader, iconOf } from './Common';
import { Haptics } from '../core/Haptics';
import { L, TN } from '../core/I18n';

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

@Component
export struct StatsTab {
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  @State achvExpanded: boolean = false;
  @State renderRev: number = 0;
  @StorageProp('totalPlays') plays: number = 0;      // 累计开局（必须用 StorageProp，函数调用不会触发重渲染）
  @StorageProp('totalMs') totalMs: number = 0;       // 累计时长
  @StorageProp('clearedGames') clearedRaw: string = '';
  @StorageProp('themeDark') dark: boolean = false;
  @StorageProp('xp') xp: number = 0;
  @StorageProp('level') level: number = 1;
  @StorageProp('totalSolved') totalSolved: number = 0;
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

  private levelPct(): number {
    return Math.round(ProgressStore.levelProgress(this.xp) * PCT);
  }

  private xpLeftText(): string {
    if (this.level >= MAX_LEVEL) {
      return this.t('已达最高等级', 'Max level reached');
    }
    return this.tn('再攒 {n} 点经验就升级', '{n} XP to next level', ProgressStore.xpToNext(this.xp));
  }

  private nextLevelText(): string {
    if (this.level >= MAX_LEVEL) {
      return 'LV ' + MAX_LEVEL + ' · ' + this.t('满级', 'Max');
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

  private titleForLevel(): string {
    const l: number = this.level;
    if (l >= 60) {
      return this.t('游戏宗师', 'Grandmaster');
    }
    if (l >= 40) {
      return this.t('解谜高手', 'Puzzle Master');
    }
    if (l >= 25) {
      return this.t('益智达人', 'Puzzle Pro');
    }
    if (l >= 15) {
      return this.t('小有所成', 'Getting Somewhere');
    }
    if (l >= 8) {
      return this.t('渐入佳境', 'In the Groove');
    }
    if (l >= 3) {
      return this.t('初窥门径', 'First Steps');
    }
    return this.t('新手上路', 'Newcomer');
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

  /** 玩过的 gameId（从 perGamePlays 的键取，省得遍历 354 款） */
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

  build() {
    Scroll() {
      Column({ space: Space.lg }) {
        // ★ 2026-10-13 巡检发现：统计页缺等级展示（首页有 LV/经验/火焰，这里直接跳到成就）
        //   ⇒ 复用 Common 里现成的 LevelHeader（和首页同一套数据源，不重复实现）
        LevelHeader()
        this.achvWall()
        this.badgeWall()
        this.heroCard()
        this.statGrid()
        if (ProgressStore.totalPlays() === 0) {
          this.emptyState()
          this.suggestSection()      // ★ item ③：把底部的空白填上
        } else {
          this.recentSection()
          this.topSection()
        }
        Text(this.t('记录只存在你手机里，不上传、不联网也能看', 'Everything stays on your phone — no uploads, works offline'))
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

  /** ── ① 等级头卡：徽章 + 称号 + XP 进度条 + 连胜/收藏 ── */
  @Builder
  heroCard() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Stack() {
          Circle({ width: BADGE_SIZE, height: BADGE_SIZE })
            .fill(this.accentColor())
            .shadow(Shadow.card)
          Column() {
            Text('LV')
              .fontSize(FontSize.xxs)
              .fontColor(ON_PRIMARY_SOFT)
            Text(Digits(String(this.level), this.langCode))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width(BADGE_SIZE)
        .height(BADGE_SIZE)

        Column({ space: Space.xs }) {
          Text(this.titleForLevel())
            .fontSize(FontSize.xl)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          Text(this.solvedToday ? this.t('✅ 今日已打卡', '✅ Checked in today') : this.t('⭕ 还没玩 · 来一局就打卡', '⭕ Nothing yet — play one to check in'))
            .fontSize(FontSize.xxs)
            .fontColor(this.solvedToday ? Palette.emerald : this.theme().inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        Row() {
          Text(this.nextLevelText())
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkSoft)
          Blank()
          Text(Digits(String(this.levelPct()), this.langCode) + '%')
            .fontSize(FontSize.xxs)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(BAR_H)
            .backgroundColor(this.theme().line)
            .borderRadius(Radius.full)
          Row()
            .width(this.levelPct() + '%')
            .height(BAR_H)
            .backgroundColor(this.accentColor())
            .borderRadius(Radius.full)
            .animation({ duration: Motion.slow, curve: Motion.spring() })
        }
        .width('100%')
        .height(BAR_H)

        Row() {
          Text(this.tn('一共攒了 {n} 点经验', '{n} XP earned', this.xp))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
          Blank()
          Text(this.xpLeftText())
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
        }
        .width('100%')
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        this.chip('🔥', '连胜 {n} 天', 'Streak {n} days', this.superStreak, Palette.orange)
        this.chip('🏅', '最长连了 {n} 天', 'Longest {n} days', this.bestStreak, Palette.amber)
        this.chip('📅', '今天玩了 {n} 局', 'Today {n} rounds', this.dailyCount, Palette.sky)
        this.chip('⭐', '收藏 {n} 款', 'Saved {n}', ProgressStore.favorites().length, Palette.berry)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.lg)
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
        this.statCell('🏆', String(this.solvedShown), '局', 'rounds', '通关了', 'Cleared', Palette.amber)
        this.statCell('🎯', String(this.playsShown), '局', 'rounds', '一共玩了', 'Played', this.accentColor())
      }
      .width('100%')

      Row({ space: Space.md }) {
        this.statCell('⏱️', this.durationText(), '', '', '玩了多久', 'Time played', Palette.emerald)
        this.statCell('🧩', ProgressStore.playedKinds() + '/' + GAMES.length, '款', 'games', '玩过几款', 'Tried', Palette.violet)
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

  /** ── ③ 最近玩过：横向滑动小卡 ── */
  @Builder
  recentSection() {
    Column({ space: Space.sm }) {
      this.sectionHeader('🕐', '最近玩过的', 'Recently played', '点一下直接续上', 'Tap to pick up where you left off')

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
    .onClick(() => {
      Haptics.tap();
      this.openGame(g.id);
    })
  }

  /** ── ④ 最常玩的 5 款 ── */
  @Builder
  topSection() {
    Column({ space: Space.sm }) {
      this.sectionHeader('📈', '玩得最多的', 'Most played', '按玩的次数排', 'sorted by plays')

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
          Text(this.tn('玩过 {n} 次', 'Played {n} times', it.plays))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
          if (it.best > 0) {
            Text(this.tn('最高 {n}', 'Best {n}', it.best))
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
        Text(this.t('🏅 成就', '🏅 Achievements')).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
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
        Text(this.achvExpanded ? this.t('收起', 'Less')
            : this.tn('看全部 {n} 个', 'See all {n}', ProgressStore.achievementList().length))
          .fontSize(FontSize.xxs).fontColor(this.accentColor()).fontWeight(FontWeight.Bold)
        Text(this.achvExpanded ? '▲' : '▼').fontSize(FontSize.micro).fontColor(this.accentColor())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 6, bottom: 2 })
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
        Text(this.t('🎖️ 游戏徽章', '🎖️ Game Badges')).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.theme().ink)
        Blank()
        Text(Digits(String(ProgressStore.tierTotal()), this.langCode) + ' / ' +
              Digits(String(GAMES.length * 4), this.langCode))
          .fontSize(FontSize.xs).fontColor(Palette.emerald).fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Text(this.t('每款游戏 4 档：首通 · 熟练 10 次 · 精通 50 次 · 大师 100 次', 'Each game has 4 tiers: first clear, 10, 50, 100'))
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
        Text(this.t('还没有徽章——通关任意一局就点亮', 'No badges yet — clear any game to start'))
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
      this.sectionHeader('🎲', '先从这几款开始', 'Start with these', '挑不出就先玩这几个', 'picks to get going')

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
      Text(this.t('这里还空着', 'Nothing here yet'))
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
