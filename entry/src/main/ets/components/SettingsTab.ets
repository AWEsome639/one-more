/**
 * 设置页 —— 外观 / 游戏偏好 / 数据 / 关于
 *
 * 四组设置：
 *   外观   深色模式（ProgressStore.setThemeDark，会落盘）＋ 主题色 6 色块（AppStorage 'accent'）
 *   偏好   音效 / 振动反馈 / 屏幕常亮（AppStorage，只存偏好）
 *   数据   等级 · 通关 · 玩过几款 · 收藏 ＋ 总局数/总时长 ＋ 重置进度（内联二次确认）
 *   关于   vX.Y.Z · 共 N 款 · 离线可玩/无广告/不采集 ＋ 隐私政策跳转
 *
 * 每行设置 = 一张「卡片行」：左 emoji + 标题 + 副标题，右开关 / 箭头。
 * 颜色·字号·间距·圆角·动效时长一律取自 ../core/Design，组件内不写魔法数值。
 *
 * ★ 2026-10-13 两条真机问题（P4/P5）修在这里：
 *   P5 主题色：选择器原来只有 6 色，且只写 AppStorage 'accent' —— 而真正着色的是
 *      `Palette.primary` 静态常量 ⇒ 选完等于没选。现在改走 `Accent.set(id)`：
 *      写 AppStorage ＋ 改写 `Palette.primary/primaryDeep`（全项目跟着走），
 *      色板扩到 12 档（跟随系统 ＋ 靛蓝 ＋ 彩虹 7 档 ＋ 品红/天蓝/石墨），
 *      并且本页所有着色（小节竖条、开关、芯片、预览）一律读 `this.accentColor()`。
 *      ⚠️ `this.accent` 存的是 **id**（可能是 'system'），**不能直接当颜色用**。
 *   P4 多语言：本页原来有 20 多处裸中文（统计格标签、关于卡三行、重置提示…），
 *      在 10 种非中英语言下仍是中文。现在全部走 `this.t(zh, en)`，字典缺项退英文。
 *      ⚠️ `@Builder` 的参数会被 ArkUI 记忆化 ⇒ **只传字面量 (zh, en)，在 Builder 内部算**；
 *      传算好的字符串时，换语言 Builder 不重建（本页踩过）。
 *
 * 拾海 2026-10-10（2026-10-13 修 P4/P5）
 *
 * ⚠️ 重置进度为何不走 ProgressStore.persist(0,0,0)：
 *    ① persist() 在 ProgressStore 里是 private ⇒ 跨文件调用 TS2341，编译不过；
 *    ② 它只写 xp/totalSolved/superStreak/bestStreak，清不掉 favorites/recent/totalPlays/perGame*。
 *    ⇒ 这里改成：先把 AppStorage 的进度键全写回初始值，再用 preferences 公共 API 把
 *      'onemore_progress' 整库 clear（库名与 ProgressStore / StatsCardAbility 一致，本工程已有先例），
 *      最后把「深色模式」这个外观偏好写回 —— 重置的是进度，不该顺手改外观。
 */

import { LengthMetrics } from '@kit.ArkUI';
import { TG } from '../core/GameI18n';
import { Sound } from '../core/Sound';
import { Bp } from '../core/Bp';
import { router } from '@kit.ArkUI';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Accent, AccentOption } from '../core/Design';
import { BUILD_TAG, GAMES } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
// ★★★ 2026-10-23 路线 E：游玩记录导出
import { GameLog } from '../core/GameLog';
import { Haptics } from '../core/Haptics';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameDiff } from '../core/GameDiff';
import { findGame, displayName } from '../core/GameRegistry';
import { I18n, L, LANGS, LangInfo, TN } from '../core/I18n';
import { IconSize } from './Common';
import { UiModeMgr } from '../core/UiMode';
import { About } from '../core/About';
import { pasteboard } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { Tv } from '../core/Tv';

/** 进度库名 —— 与 ProgressStore 的 STORE_NAME、StatsCardAbility 的 STORE 同一个库 */
const STORE_NAME: string = 'onemore_progress';
/** 版本号 —— 与 AppScope/app.json5 的 versionName 保持一致 */
// ★ 2026-10-13：版本号**单一真相源**在 `core/About.ets` 的 `About.VERSION`
//   原来这里又硬编码了一份 ⇒ 改一处忘另一处就会不同步（我今天正好发现两处都是 1.0.0）
const APP_VERSION: string = About.VERSION;
/** 主题色候选：12 档（跟随系统 ＋ 靛蓝 ＋ 彩虹 7 档 ＋ 品红/天蓝/石墨）—— 真相源在 Design.Accent */
const ACCENTS: AccentOption[] = Accent.options;
/** 毫秒 → 分钟 */
const MS_PER_MIN: number = 60000;
/** 选中色块的放大倍率 */
const PICK_SCALE: number = 1.1;
/** 首屏进场延迟 */
const ENTER_DELAY: number = 30;
/** 难度名（简/繁/其它语言都走字典） */
const DIFF_ZH: string[] = [TG('简单'), TG('普通'), TG('困难')];
const DIFF_EN: string[] = ['Easy', 'Normal', 'Hard'];

/**
 * 开关行
 *
 * ★ 只放**字面量** (zh, en)，文案在 Builder 内部才算 ——
 *   `@Builder` 的参数会被 ArkUI 记忆化，传算好的字符串时换语言不重建（本页踩过）。
 */
interface SwitchCfg {
  icon: string;
  zh: string;
  en: string;
  subZh: string;
  subEn: string;
  on: boolean;
  storeKey: string;
}

/** 统计格（同上：字面量进，内部算；数字也只在 Builder 内部拼） */
interface StatCfg {
  icon: string;
  zh: string;
  en: string;
  /** 数值种类：level / games / kinds —— 文案在 Builder 内部拼，别在调用点算 */
  kind: string;
  num: number;
}

/** 可点行（带 › 箭头）；同上：字面量进，内部算 */
interface NavCfg {
  icon: string;
  zh: string;
  en: string;
  subZh: string;
  subEn: string;
  danger: boolean;
  tap: () => void;
}

/** 三行说明（同上：字面量进，内部算） */
interface InfoCfg {
  icon: string;
  zh: string;
  en: string;
  subZh: string;
  subEn: string;
}

/** 隐私政策页参数 */
interface GuideParams {
  kind: string;
}

@Component
export struct SettingsTab {
  @State renderRev: number = 0;
  // ── 外观 / 偏好（AppStorage 响应式）──
  @StorageProp('themeDark') dark: boolean = false;
  /**
   * ★ 当前主题色 —— 存的是 **id**（'system' 或 '#RRGGBB'），不是颜色！
   *   要画颜色一律用 `this.accentColor()`（'system' 会被解析成系统品牌色）。
   *   这个 @StorageProp 也是本页"选色立刻重绘"的观察源。
   */
  @StorageProp('accent') accent: string = Palette.primary;
  // ★★★ 2026-10-19 自查 A1：这里会被【赋值】（点按切换模式时 this.uiMode = m）
  //   @StorageProp 是【单向】（AppStorage → 组件），本地赋值不回写、下次同步还会被覆盖
  //   ⇒ 改成 @StorageLink（双向）—— 这才是"既读又写"的正确装饰器
  @StorageLink('uiMode') uiMode: string = 'normal';   // 界面模式（大字/紧凑），双向
  /** ★★★ 2026-11-07 交互死角：智慧屏/键盘焦点环（判据：可点组件必须有 focusable） */
  @State private tvFocus: string = '';
  @State private copyHint: string = '';   // 「已复制 ✓」提示
  /** 标星卡片的提示（打开 GitHub 失败时显示可复制的地址） */
  @State private starHint: string = '';
  @StorageProp('themeMode') mode: string = 'system';
  @StorageProp('lang') lang: string = 'zh';

  /**
   * ★ 2026-11-08 RTL 判据 —— `const observed` 是**渲染依赖声明，别删**。
   *   为什么不用裸 `I18n.isRTL()`：`I18n.current()` 返回 `I18n.cached` 静态字段，
   *   ArkUI 看不到依赖 ⇒ 切语言后箭头/方向不会重算。摸一下 @StorageProp 才有依赖。
   *   （同类坑见 Common.ets 的 taglineText()/gameTitle()）
   */
  private rtl(): boolean {
    const observed: string = this.lang;   // ← 依赖声明，别删
    return I18n.isRTL();
  }
  @StorageProp('soundOn') soundOn: boolean = true;
  @StorageProp('hapticsOn') hapticsOn: boolean = true;
  @StorageProp('keepAwake') keepAwake: boolean = true;

  // ── 进度摘要（用 @StorageProp 才跟着数据变）──
  @StorageProp('level') level: number = 1;
  @StorageProp('totalSolved') totalSolved: number = 0;
  @StorageProp('favorites') favRaw: string = '';
  @StorageProp('perGamePlays') perGamePlaysRaw: string = '{}';
  @StorageProp('totalPlays') totalPlays: number = 0;
  @StorageProp('totalMs') totalMs: number = 0;

  // ── 本地 UI 状态 ──
  @State private confirming: boolean = false;
  @State private note: string = '';
  @State private noteOk: boolean = true;
  @State private entered: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
        this.entered = true;
      });
    }, ENTER_DELAY);
  }

  // ★ 性能：theme() 一次渲染被调 35+ 次 ⇒ 按 dark 记忆化
  private themeCache: Theme | null = null;
  private themeCacheDark: boolean = false;

  private t(zh: string, en: string): string {
    const observed: string = this.lang;
    return L(zh, en);   // ★ 走字典，支持 12 语言（含繁体转换）
  }

  /**
   * 当前主题色（可直接当颜色用）
   *
   * ★ 读一次 `this.accent` 就是"依赖声明" —— 选了新色本页立刻重绘；
   *   而 `Accent.color()` 负责把 'system' 解析成系统品牌色。
   */
  private accentColor(): string {
    const observed: string = this.accent;
    return Accent.color(this.accent);
  }

  /** 这个 id 是不是当前选中的主题色 */
  private isAccent(id: string): boolean {
    return this.accent === id;
  }

  private theme(): Theme {
    if (this.themeCache === null || this.themeCacheDark !== this.dark) {
      this.themeCache = this.dark ? Theme.dark() : Theme.light();
      this.themeCacheDark = this.dark;
    }
    return this.themeCache;
  }

  /** 玩过的款数：从 perGamePlays 的 JSON 里数键（读 @StorageProp 才能响应变化） */
  private playedKinds(): number {
    try {
      const m: Record<string, number> = JSON.parse(this.perGamePlaysRaw) as Record<string, number>;
      return Object.keys(m).length;
    } catch (e) {
      return 0;
    }
  }

  /** 收藏数 */
  private favCount(): number {
    return this.favRaw.length === 0 ? 0 : this.favRaw.split(',').length;
  }

  /** 累计游玩分钟 */
  private playedMinutes(): number {
    return Math.round(this.totalMs / MS_PER_MIN);
  }

  /** 存一项开关偏好：深色模式走 ProgressStore（落盘），其余四项只存 AppStorage */
  private setPref(storeKey: string, v: boolean): void {
    if (storeKey === 'themeDark') {
      ProgressStore.setThemeDark(v);
    } else {
      AppStorage.setOrCreate(storeKey, v);
    }
  }

  /**
   * 导出游玩记录（路线 E）
   * 写给谁：路线 B/C 的训练脚本读这个 JSON；他自己也能看
   * 失败怎么办：note 里说清楚，不弹窗、不打断
   */
  private doExport(): void {
    hilog.info(0x0000, 'GameLog', 'doExport ENTER, count=%{public}d', GameLog.count());
    Haptics.tap();
    const n: number = GameLog.count();
    hilog.info(0x0000, 'GameLog', 'doExport count=%{public}d ready-check', n);
    if (n === 0) {
      this.noteOk = false;
      this.note = TG('还没有游玩记录 —— 先玩几局再来导出');
      return;
    }
    hilog.info(0x0000, 'GameLog', 'doExport: calling writeExport');
    const path: string = GameLog.writeExport();
    hilog.info(0x0000, 'GameLog', 'doExport: writeExport returned len=%{public}d', path.length);
    if (path.length === 0) {
      this.noteOk = false;
      this.note = this.t('导出失败 —— 请再试一次', 'Export failed — please try again');
      return;
    }
    this.noteOk = true;
    // ★ 不带数字：i18n 是拿【中文原文当 key】查 EXTRA 的，
    //   一拼接就查不到 ⇒ 10 种语言全退成英文（这是 App 里踩过很多次的坑）
    //   局数放日志里：
    this.note = this.t('游玩记录已导出，文件在手机上',
      'Play log exported and saved on this device');
    hilog.info(0x0000, 'GameLog', 'doExport: note set len=%{public}d text=%{public}s', this.note.length, this.note);
  }

  private askReset(): void {
    this.confirming = true;
    this.note = '';
  }

  /**
   * ★★★ 2026-10-29（项目 F 顺手）：**GitHub 标星方块**
   *
   * 奥森：「在应用里加一个『在 GitHub 上标星』的方块，点击后跳到对应的标星页面」
   *
   * 设计考虑：
   *   · 放在设置页「关于」区的最下面 —— 愿意往下翻到这儿的人，才是真的喜欢
   *   · **不显示 star 数**：那要联网拉 API，与「离线可玩 / 不采集」冲突
   *   · 不用 WebView，走系统浏览器（和隐私政策一致的做法）
   *   · 打开失败时给一句可复制的地址，不让用户卡住
   */
  @Builder
  starCard() {
    Column({ space: Space.xs }) {
      Row({ space: Space.sm }) {
        Text('⭐').fontSize(FontSize.lg).width(IconSize.of(FontSize.lg)).height(IconSize.of(FontSize.lg)).textAlign(TextAlign.Center)
          .accessibilityLevel('no')
        Column({ space: 2 }) {
          Text(this.t('在 GitHub 上标星', 'Star it on GitHub'))
            .fontSize(FontSize.sm).fontColor(this.theme().ink).fontWeight(FontWeight.Medium)
          Text(this.t('喜欢的话给它一颗星 · 开源、无广告、不采集',
                      'Enjoying it? Give it a star · open source, no ads, no tracking'))
            .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('↗').fontSize(FontSize.sm).fontColor(this.theme().inkFaint)
          .accessibilityLevel('no')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.starHint.length > 0) {
        Text(this.starHint)
          .fontSize(FontSize.xxs).fontColor(Palette.rose)
          .width('100%')
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surfaceAlt)
    .borderRadius(Radius.lg)
    .margin({ top: Space.sm })
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'S314'; })
    .onBlur(() => { if (this.tvFocus === 'S314') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'S314'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
      Haptics.tap();
      this.openStar();
     }); })
    .accessibilityGroup(true)
    .accessibilityText(this.t('在 GitHub 上标星', 'Star it on GitHub'))
    .accessibilityLevel('yes')
    .onClick(() => {
      Haptics.tap();
      this.openStar();
    })
    .accessibilityText(this.t('在 GitHub 上标星', 'Star it on GitHub'))
  }

  /** 打开 GitHub 标星页（失败时给一句可复制的地址） */
  private openStar(): void {
    const url: string = About.GITHUB_STAR_URL;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      }).catch(() => {
        this.starHint = this.t('打不开链接，请手动访问：', 'Cannot open link. Please visit: ') + url;
        setTimeout(() => { this.starHint = ''; }, 6000);
      });
    } catch (e) {
      this.starHint = this.t('打不开链接，请手动访问：', 'Cannot open link. Please visit: ') + url;
      setTimeout(() => { this.starHint = ''; }, 6000);
    }
  }


  private openPrivacy(): void {
    const params: GuideParams = { kind: 'privacy' };
    router.pushUrl({ url: 'pages/GuidePage', params: params });
  }

  /**
   * 重置进度（二次确认后才会调到）。
   * ① 内存：进度键全部回初始值；② 磁盘：'onemore_progress' 整库清空；③ 外观偏好写回。
   */
  private doReset(): void {
    try {
      // ★ 统一走 ProgressStore.resetAll()：清 AppStorage + preferences 库 + 内存里的连胜 Map
      //   （逐键清会漏掉 streaks，重置后一玩旧连胜又被写回磁盘 —— feat-settings 抓到的坑）
      ProgressStore.resetAll();
      // 深色模式是"外观"不是"进度" ⇒ 重置后写回，别顺手把人家的主题改了
      ProgressStore.setThemeDark(this.dark);
      this.noteOk = true;
      this.note = this.t('已经清干净了：等级回到 1，通关和收藏都归零 ✅',
                         'All clear: level back to 1, clears and saves at zero ✅');
    } catch (e) {
      this.noteOk = false;
      this.note = this.t('重置没成功 —— 请再试一次，或到系统设置里清除应用数据 ↺',
                         'Reset failed — try again, or clear the app data in system settings ↺');
    }
    this.confirming = false;
  }

    /** 整句模板（读语言字段建立 ArkUI 依赖）—— 例：tn('{n} 局', '{n} games', 3) */
  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.lang;
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

build() {
    Scroll() {
      Column({ space: Space.sm }) {
        this.pageHeader()

        // ───────── 外观 ─────────
        this.sectionTitle('外观', 'Appearance')
        this.themeModePicker()
        this.langPicker()

        // 局域网对战入口
        Row({ space: Space.md }) {
          Text('📶').fontSize(FontSize.md).width(26).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Column({ space: 2 }) {
            Text(this.t('局域网对战', 'LAN Play')).fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
            Text(this.t('同一 Wi-Fi 下两台设备直接对局，没有服务器',
                        'Two devices on the same Wi-Fi. No server.'))
              .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.rtl() ? '‹' : '›').fontSize(FontSize.lg).fontColor(this.theme().inkFaint)
            .accessibilityLevel('no')
        }
        .width('100%').height(64).padding(Space.md)   // ★ 判据 1757 试修：显式高度，防嵌套 Column 塌陷
        .backgroundColor(this.theme().surface).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'S400'; })
        .onBlur(() => { if (this.tvFocus === 'S400') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'S400'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
          Haptics.tap();
          router.pushUrl({ url: 'pages/LanLobby' });
         }); })
        .accessibilityGroup(true)
        .accessibilityText(this.t('局域网对战', 'LAN Play'))
        .accessibilityLevel('yes')
        .onClick(() => {
          Haptics.tap();
          router.pushUrl({ url: 'pages/LanLobby' });
        })
        this.accentPicker()
        this.uiModePicker()
        this.diffSelfCheck()

        // ───────── 游戏偏好 ─────────
        this.sectionTitle('游戏偏好', 'Gameplay')
        this.switchRow({
          icon: '🔊', zh: '音效', en: 'Sound',
          subZh: '通关、失败、点按都有声音', subEn: 'Sounds on wins, losses and taps',
          on: this.soundOn, storeKey: 'soundOn'
        })
        this.switchRow({
          icon: '📳', zh: '振动反馈', en: 'Haptics',
          subZh: '答对时轻轻震一下', subEn: 'A tiny buzz when you get it right',
          on: this.hapticsOn, storeKey: 'hapticsOn'
        })
        this.switchRow({
          icon: '💡', zh: '游戏时屏幕常亮', en: 'Keep screen awake',
          subZh: '玩的时候屏幕不会自己黑掉', subEn: 'Screen will not dim while you play',
          on: this.keepAwake, storeKey: 'keepAwake'
        })

        // ───────── 数据 ─────────
        // ★★★ 2026-10-23 真机抓到的显示问题：
        //   提示语原来放在两个 navRow 之后 ⇒ 「重置进度」本身就贴着屏幕底边，
        //   提示语被顶到屏幕外 ⇒ 导出成功了但用户什么都看不到（截图确认过）
        //   ⇒ 移到 statCard 之前：分组顶部，永远在首屏
        if (this.note.length > 0) {
          Text(this.note)
            .fontSize(FontSize.xxs)
            .fontColor(this.noteOk ? Palette.emerald : Palette.warning)
            .width('100%')
            .padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm })
            .margin({ left: Space.lg, right: Space.lg })
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.sm)
        }
        this.sectionTitle(TG('数据'), 'Your data')
        this.statCard()

        if (this.confirming) {
          this.confirmPanel()
        } else {
          // ★★★ 2026-10-23 路线 E：导出游玩记录
          //   为什么放这里：它在「数据」分组，和重置进度是一对（一个拿走、一个清零）
          //   为什么导 JSON：路线 B/C 的训练脚本要读它；他自己也能看
          this.navRow({
            icon: '📤', zh: '导出游玩记录', en: 'Export play log',
            subZh: '把每局的用时与结果导出成 JSON，只存在本机',
            subEn: 'Export each game time and result as JSON, stored on this device only',
            danger: false, tap: () => {
              this.doExport();
            }
          })
          this.navRow({
            icon: '🧹', zh: '重置进度', en: 'Reset progress',
            subZh: '等级、通关记录、收藏和统计全部归零', subEn: 'Level, clears, saves and stats all go to zero',
            danger: true, tap: () => {
              this.askReset();
            }
          })
        }


        // ───────── 关于 ─────────
        this.sectionTitle('关于', 'About')
        this.aboutCard()
        this.navRow({
          icon: '📄', zh: TG('隐私政策'), en: 'Privacy policy',
          subZh: '这个应用不做什么，都写在这儿', subEn: 'What this app does not do, all written here',
          danger: false, tap: () => {
            this.openPrivacy();
          }
        })
        this.starCard()
        // ★ 2026-11-08：反馈卡（原来被误插在 `themeModePicker()` 里，见 feedbackCard 的注释）
        this.feedbackCard()

        Text('One More · ' + this.tn('{n} 款小游戏，不用联网也能玩', '{n} mini games, playable offline', GAMES.length,
          '{n} мини-игра без интернета', '{n} мини-игры без интернета', '{n} мини-игр без интернета'))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: Space.lg, bottom: Space.xxxl })
      }
      .width('100%')
      // ★★★ 2026-10-30：**写死 84 在矮屏上不够**（实测 960×540 下
      //   「界面模式」三个按钮仍被导航栏遮住下半部分 —— 差约 20vp）。
      //   ⇒ 改成按 **导航栏实际高度** 现算。
      //
      // ★★★ 2026-11-05（第 1324 轮）：**试过改成 `Space.xxl`(32)，已回滚**
      //   实验：108 → 32 vp，195 真机复测：**纯白 85% → 89%（反而升了）**
      //   ⇒ 白色的真因是「内容在最后一段就结束」，**不是 padding 太大**
      //   ⇒ 判据 847；原值保留（判据 792：它承担「不被页签栏贴住」的职责）
      .padding({ bottom: (Bp.isWatch() || Bp.tinyScreen() ? 36 : 60) + 48 })
      .opacity(this.entered ? 1 : 0)
      .translate({ y: this.entered ? 0 : 10 })
      .animation({ duration: Motion.slow, curve: Motion.spring() })
      // ★ 2026-11-08 实验 A（方案①）：把 direction 从 Scroll 挪到**里面的 Column**。
      //   ⚠️ SDK `common.d.ts:20248` 原文：The setting does not take effect in the **Column**
      //   component ⇒ 文档预期这条**无效**，保留它只为验证文档是否说谎。
      .direction(this.rtl() ? Direction.Rtl : Direction.Ltr)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(this.theme().bg)
  }

  /** 页头 */
  @Builder
  pageHeader() {
    Column({ space: Space.xs }) {
      Text(this.t('设置', 'Settings'))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.t('调成你顺手的样子，随时都能改', 'Make it yours — change anytime'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkFaint)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.xl, bottom: Space.xs })
  }

  /** 分组小标题（竖条用当前主题色） */
  @Builder
  /**
   * 小节标题
   *
   * ★ 必须收 (zh, en) 在内部算，**不能收算好的字符串** ——
   *   `@Builder` 的**参数会被 ArkUI 记忆化** ⇒ 传算好的串时，语言变了 Builder 也不重建
   *   （实测：切到日语后「外観/テーマ」变了，但「外观/数据/关于」这些走 Builder 的没变）
   */
  sectionTitle(zh: string, en: string) {
    Row({ space: Space.xs }) {
      Row()
        .width(Space.xs)
        .height(FontSize.md)
        .backgroundColor(this.accentColor())
        .borderRadius(Radius.full)
      Text(this.t(zh, en))
        .fontSize(FontSize.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().inkSoft)
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md })
  }

  /** 卡片行：emoji + 标题 + 副标题 + 开关 */
  @Builder
  switchRow(cfg: SwitchCfg) {
    Row({ space: Space.md }) {
      Text(cfg.icon)
        // ★ 2026-11-03（第 1120 轮）**装饰 emoji 摘出无障碍树**
        //   否则读屏会念「喇叭」「震动」，然后才念标题，白占一拍。
        .accessibilityLevel('no')
        .fontSize(FontSize.xl)
        .width(Space.xxl)
        .textAlign(TextAlign.Center)

      Column({ space: Space.xs }) {
        Text(this.t(cfg.zh, cfg.en))
          .fontSize(FontSize.md)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().ink)
        Text(this.t(cfg.subZh, cfg.subEn))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: cfg.on })
        // ★★★ 2026-11-03（第 1120 轮）**开关必须说清"是哪个设置、现在什么状态"**
        //   原来 Toggle 只有系统默认的「开关」两个字：
        //   读屏念「开关」，用户不知道是"声音"还是"震动"。
        //   ⇒ 标题 + 当前状态一次说完。
        //   ⚠️ 不用 accessibilityChecked：那是**手动覆盖**用的；
        //      这里的状态由 Toggle 自己驱动，写成常量会与真实状态不同步。
        .accessibilityText(this.t(cfg.zh, cfg.en) + this.t('：', ': ') +
          (cfg.on ? this.t('已开启', 'on') : this.t('已关闭', 'off')))
        .accessibilityLevel('yes')
        .selectedColor(this.accentColor())
        .onChange((v: boolean) => {
          // ★ 手感：开关拨动要有"咔哒"的确认感
          Haptics.tap();
          this.setPref(cfg.storeKey, v);
          // ★★★ 2026-10-29（项目 D ④）：**打开音效开关时立刻响一声**
          //   这是最直接的"试听"：用户拧开就能听见，不用等一局游戏
          //   · 只在「打开」时响（关掉还响就矛盾了）
          //   · 只对 soundOn 这一个开关生效（别的开关不乱响）
          if (cfg.storeKey === 'soundOn' && v) {
            Sound.tap();
          }
        })
    }
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /** 主题色：6 个色块，选中的放大并打勾 */
  /** 外观三态：浅色 / 深色 / 跟随系统 */
  /** 语言：中文 / English */
  @Builder
  langPicker() {
    Column({ space: Space.sm }) {
      Row() {
        Text('🌏').fontSize(FontSize.md).width(26).textAlign(TextAlign.Center)
          .accessibilityLevel('no')
        Column({ space: 2 }) {
          Text(this.t('语言', 'Language')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          Text(this.t('切换后界面立刻变，游戏名也会跟着换', 'Switches instantly, game names too'))
            .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(LANGS, (l: LangInfo) => {
          this.langChip(l.code, l.flag + ' ' + l.native)
        }, (l: LangInfo) => l.code)
      }
      .width('100%')
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  langChip(code: string, label: string) {
    Text(label)
      .fontSize(FontSize.xs)
      .fontWeight(this.lang === code ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.lang === code ? Color.White : this.theme().inkSoft)
      .textAlign(TextAlign.Center)
      .padding({ left: Space.md, right: Space.md, top: Space.tiny, bottom: Space.tiny })
      .margin({ start: LengthMetrics.vp(0), end: LengthMetrics.vp(6), bottom: Space.xs })
      .backgroundColor(this.lang === code ? this.accentColor() : this.theme().surfaceAlt)
      .borderRadius(Radius.full)
      .animation({ duration: Motion.fast, curve: Motion.spring() })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'S653-' + code; })
      .onBlur(() => { if (this.tvFocus === 'S653-' + code) { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'S653-' + code))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        // ★ 语言切换不能包在 animateTo 里 —— 它不是动画属性，
        //   而且换语言要重建大量文案，包进动画闭包反而可能不执行
        I18n.set(code);
        ProgressStore.saveLang(code);   // ★ 落盘（preferences 通道，实测跨重启可靠）
        this.renderRev = this.renderRev + 1;
       }); })
      .accessibilityGroup(true)
      .accessibilityText(label)
      .accessibilityLevel('yes')
      .onClick(() => {
        Haptics.tap();   // ★ 2026-10-19 按压反馈
        // ★ 语言切换不能包在 animateTo 里 —— 它不是动画属性，
        //   而且换语言要重建大量文案，包进动画闭包反而可能不执行
        I18n.set(code);
        ProgressStore.saveLang(code);   // ★ 落盘（preferences 通道，实测跨重启可靠）
        this.renderRev = this.renderRev + 1;
      })
  }

  @Builder
  themeModePicker() {
    Column({ space: Space.sm }) {
      Row() {
        Text('🎨').fontSize(FontSize.md).width(26).textAlign(TextAlign.Center)
          .accessibilityLevel('no')
      Column({ space: 2 }) {
          Text(this.t('外观模式', 'Theme')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          Text(this.modeSub())
            .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Row({ space: Space.sm }) {
        this.modeChip('light', '☀️', '浅色', 'Light')
        this.modeChip('dark', '🌙', '深色', 'Dark')
        this.modeChip('system', '🔄', '跟随系统', 'System')
      }
      .width('100%')
      // ★★★ 2026-11-08 实验 B（文档指出的正解）：SDK 原文 direction 是
      //   「how elements are laid out along the **main axis** of the container」
      //   ⇒ 只对**主轴容器（Row）**有意义；官方 FAQ「如何实现镜像语言功能」的示例也挂在 Row 上。
      //   ★ 这里用 **Direction.Auto**（不是写死 Rtl）：配合 I18n.set() 里新加的
      //     `setAppPreferredLanguage`，让平台自己解析方向 —— 这才是 FAQ 的第 3 步。
      //   判据：阿语下三个胶囊若变成「跟随系统 → 深色 → 浅色」，说明 ①+③ 整条链路通了。
      .direction(Direction.Auto)
    }
    .width('100%')
    .padding(Space.md)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /**
   * ★★★ 2026-11-08 **真机抓到**（判据 1786）：整块「反馈与关于 + 隐私政策」原来被**误插在
   *   `themeModePicker()` 的 Column 里** ⇒ 设置页「外观」之后直接接反馈卡，
   *   语言 / 局域网 / 主题色 / 界面模式 全被挤到很下面（真机滚动确认内容都在，只是顺序乱了）。
   *   ⇒ 抽成独立 builder，在 `build()` 里紧接 `themeModePicker()`（保持原分区顺序）。
   */
  @Builder
  feedbackCard() {
      // ★ 2026-10-13 奥森：「游戏里可以放"反馈邮箱"什么的，以及制作者的一些合适的信息」
      //   设计：① 只放必要信息（不放真名/学号）② 邮箱可复制（不裸链）③ 署名用英文名
      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Text('✉️').fontSize(FontSize.lg).width(IconSize.of(FontSize.lg)).height(IconSize.of(FontSize.lg)).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Column({ space: 2 }) {
            Text(this.t('反馈与关于', 'Feedback & about'))
              .fontSize(FontSize.md).fontWeight(FontWeight.Medium).fontColor(this.theme().ink)
            Text(this.t('有问题、想加游戏、发现 bug —— 写信给我', 'Bugs, ideas, new games — write to me'))
              .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
        }
        .width('100%')

        // ★★★ 2026-11-07 奥森：「把你的邮箱也写到反馈那里吧！」
        //   ⇒ 作者邮箱下面多一行「拾海（AI）」的邮箱，给用户第二条直达通道。
        Row({ space: Space.sm }) {
          Text('🤖')
            .fontSize(FontSize.sm).width(IconSize.of(FontSize.sm)).height(IconSize.of(FontSize.sm)).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Text(About.SHAJIA_EMAIL)
            .minFontSize(9)
            .maxFontSize(FontSize.sm)
            .fontSize(FontSize.sm).fontColor(this.theme().inkSoft).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.t('复制', 'Copy'))
            .fontSize(FontSize.xs).fontColor(Color.White)
            .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
            .backgroundColor(this.theme().inkFaint).borderRadius(Radius.full)
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'S720'; })
            .onBlur(() => { if (this.tvFocus === 'S720') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'S720'))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
              Haptics.tap();
              this.copyEmail(About.SHAJIA_EMAIL);
             }); })
            .accessibilityGroup(true)
            .accessibilityText(this.t('复制', 'Copy'))
            .accessibilityLevel('yes')
            .onClick(() => {
              Haptics.tap();
              this.copyEmail(About.SHAJIA_EMAIL);
            })
        }
        .width('100%')

        Row({ space: Space.sm }) {
          Text(About.FEEDBACK_EMAIL)
          // ★ 2026-10-19 真机大字模式实拍后修：原来只有 fontSize(sm) + maxLines(1) + Ellipsis
          //   ⇒ 大字模式邮箱 andrew680701@outlook.com 被截成「andrew680701@outlook....」
          //   ⇒ 加 minFontSize/maxFontSize（与游戏卡副标题同一套机制）：先缩字号，真缩不下才省略
          .minFontSize(9)
          .maxFontSize(FontSize.sm)
            .fontSize(FontSize.sm).fontColor(this.theme().inkSoft).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.t('复制', 'Copy'))
            .fontSize(FontSize.xs).fontColor(Color.White)
            .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
            .backgroundColor(this.accentColor()).borderRadius(Radius.full)
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'S740'; })
            .onBlur(() => { if (this.tvFocus === 'S740') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'S740'))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
              Haptics.tap();
              this.copyEmail(About.FEEDBACK_EMAIL);
             }); })
            .accessibilityGroup(true)
            .accessibilityText(this.t('复制', 'Copy'))
            .accessibilityLevel('yes')
            .onClick(() => {
              Haptics.tap();
              this.copyEmail(About.FEEDBACK_EMAIL);
            })
        }
        .width('100%')

        if (this.copyHint.length > 0) {
          Text(this.copyHint).fontSize(FontSize.xs).fontColor(this.accentColor())
        }

        // ★ 2026-10-13 AGC 上架【硬要求】：应用内必须有隐私政策入口
        Divider().color(this.theme().line).margin({ top: Space.xs, bottom: Space.xs })

        Row({ space: Space.sm }) {
          Text('🔒').fontSize(FontSize.md).width(IconSize.of(FontSize.md)).height(IconSize.of(FontSize.md)).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Text(this.t(About.PRIVACY_TITLE_CN, About.PRIVACY_TITLE_EN))
            .fontSize(FontSize.sm).fontColor(this.theme().ink).layoutWeight(1)
          Text(this.rtl() ? '‹' : '›').fontSize(FontSize.md).fontColor(this.theme().inkFaint)
            .accessibilityLevel('no')
        }
        .width('100%')
        .padding({ top: Space.xs, bottom: Space.xs })
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'S764'; })
        .onBlur(() => { if (this.tvFocus === 'S764') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'S764'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
          Haptics.tap();
          this.openPrivacyUrl();
         }); })
        .accessibilityGroup(true)
        .accessibilityText(this.t(About.PRIVACY_TITLE_CN, About.PRIVACY_TITLE_EN))
        .accessibilityLevel('yes')
        .onClick(() => {
          Haptics.tap();
          this.openPrivacyUrl();
        })

        Text(this.t('不收集任何信息 · 记录只在你手机里', 'No data collected · Everything stays on your device'))
          .fontSize(FontSize.micro).fontColor(this.theme().inkFaint)

        Text(this.t('作者 ', 'By ') + About.AUTHOR_CN + ' · v' + About.VERSION + ' · ' + About.YEAR)
          .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor(this.theme().surface)
      .borderRadius(Radius.lg)
      .margin({ bottom: Space.md })
  }

  @Builder
  /** ★ 同上：收 (zh, en) 在内部算，别收算好的字符串 */
  modeChip(m: string, icon: string, zh: string, en: string) {
    Row({ space: 4 }) {
      Text(icon).fontSize(FontSize.xs)
      Text(this.t(zh, en)).fontSize(FontSize.xs)
        .fontWeight(this.mode === m ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === m ? Color.White : this.theme().inkSoft)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: Space.tiny, bottom: Space.tiny })
    .backgroundColor(this.mode === m ? this.accentColor() : this.theme().surfaceAlt)
    .borderRadius(Radius.full)
    .animation({ duration: Motion.fast, curve: Motion.spring() })
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'S803'; })
    .onBlur(() => { if (this.tvFocus === 'S803') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'S803'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
        ProgressStore.setThemeMode(m);
      });
     }); })
    .accessibilityGroup(true)
    // ★ 2026-11-08：这里要念**文字**，不能念 icon（它是 emoji 装饰）
    .accessibilityText(this.t(zh, en))
    .accessibilityLevel('yes')
    .onClick(() => {
      Haptics.tap();   // ★ 2026-10-19 按压反馈
      animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
        ProgressStore.setThemeMode(m);
      });
    })
  }


  /**
   * ★★★ 2026-11-07 交互死角修复：复制邮箱（原来两处各抄一遍 pasteboard 流程，
   *   补 TV 焦点后会变成 4 份副本 ⇒ 收成一个方法，点击/遥控器 OK 共用）。
   */
  private copyEmail(addr: string): void {
    const data: pasteboard.PasteData =
      pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, addr);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.copyHint = this.t('已复制 ✓', 'Copied ✓');
        setTimeout(() => { this.copyHint = ''; }, 1600);
      })
      .catch(() => {
        this.copyHint = this.t('复制失败，请手动输入', 'Copy failed — type it manually');
        setTimeout(() => { this.copyHint = ''; }, 2200);
      });
  }

  /** ★ 2026-11-07：隐私政策外链（与 openStar 同一套兜底；点击/遥控器 OK 共用） */
  private openPrivacyUrl(): void {
    const url: string = this.lang === 'en' ? About.PRIVACY_URL_EN : About.PRIVACY_URL;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      ctx.startAbility({ action: 'ohos.want.action.viewData', uri: url }).catch(() => {
        this.copyHint = this.t('打不开链接，请手动访问：', 'Cannot open link. Please visit: ') + url;
        setTimeout(() => { this.copyHint = ''; }, 6000);
      });
    } catch (e) {
      this.copyHint = this.t('打不开链接，请手动访问：', 'Cannot open link. Please visit: ') + url;
      setTimeout(() => { this.copyHint = ''; }, 6000);
    }
  }

  private modeSub(): string {
    if (this.mode === 'light') {
      return this.t('一直用浅色', 'Always light');
    }
    if (this.mode === 'dark') {
      return this.t('一直用深色，纯黑省电', 'Always dark — true black saves battery');
    }
    return this.t('跟着手机设置走，白天黑夜自动换', 'Follow your phone — switches day and night');
  }

  /**
   * 难度自证 —— 列出"进过的游戏"里难度的实际取值
   *
   * 为什么放在设置页：全部游戏里靠 UI 导航逐个点进去验**极不可靠**
   * （面板展开会推挤卡片、Grid 虚拟化让远端项查不到）。
   * 改成运行时自证：进过哪款，这里就有哪款的记录，一屏看完。
   */
  @Builder
  diffSelfCheck() {
    Column({ space: 6 }) {
      Row() {
        Text(this.t('🔍 难度自证', '🔍 Difficulty check'))
          .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
        Blank()
        Text(this.tn('{n} 款已记录', '{n} games logged', GameDiff.readLog().length))
          .fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
      }
      .width('100%')

      Text(this.t('进过的游戏会记在这里 —— 看"实际"一列是否随难度变化',
                  'Games you have opened show up here. Watch the "actual" column change with difficulty.'))
        .fontSize(FontSize.micro).fontColor(this.theme().inkFaint)

      ForEach(GameDiff.readLog().slice(-8), (line: string) => {
        Row({ space: Space.sm }) {
          Text(this.logName(line)).fontSize(FontSize.xxs).fontColor(this.theme().ink)
            .layoutWeight(1).maxLines(1)
            // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.logDetail(line)).fontSize(FontSize.micro)
            .fontColor(this.logOk(line) ? Palette.emerald : Palette.rose)
        }
        .width('100%')
      }, (line: string) => line)
    }
    .width('100%').padding(Space.md)
    .backgroundColor(this.theme().surface).borderRadius(Radius.md).shadow(Shadow.card)
  }

  private logName(line: string): string {
    const p: string[] = line.split('|');
    if (p.length < 1) {
      return line;
    }
    const m = findGame(p[0]);
    if (m === undefined) {
      return p[0];
    }
    const observed: string = this.lang;   // ← 依赖声明
    return displayName(m);   // ★ 繁體走 toTrad（2026-10-13 模拟器同类问题）
  }

  /** 基础 60 → 实际 42（困难） */
  private logDetail(line: string): string {
    const p: string[] = line.split('|');
    if (p.length < 4) {
      return line;
    }
    const d: number = Number.parseInt(p[3], 10);
    const dn: string = this.t(DIFF_ZH[d], DIFF_EN[d]);
    return p[1] + ' → ' + p[2] + '  (' + dn + ')';
  }

  /** 难度生效则"实际"应等于 基础 × 倍率 */
  private logOk(line: string): boolean {
    const p: string[] = line.split('|');
    if (p.length < 4) {
      return false;
    }
    const base: number = Number.parseInt(p[1], 10);
    const got: number = Number.parseInt(p[2], 10);
    const d: number = Number.parseInt(p[3], 10);
    const scale: number = d === 0 ? 1.5 : (d === 2 ? 0.7 : 1.0);
    const want: number = Math.max(10, Math.round(base * scale));
    return got === want;
  }

  /**
   * 主题色选择器 —— 12 档（跟随系统 ＋ 靛蓝 ＋ 彩虹 7 档 ＋ 品红/天蓝/石墨）
   *
   * ★ 为什么以前"选了不变"：只写 AppStorage 'accent'，而全项目着色读的是
   *   `Palette.primary` 静态常量。现在点一下走 `Accent.set(id)`：
   *   写 AppStorage ＋ 改写 Palette.primary/primaryDeep（300+ 处引用一处不改就跟着走）。
   * ★ "跟随系统"存的是 id `'system'`，落色时由 `Accent.color()` 解析成系统品牌色，
   *   **绝不能把 id 直接当颜色用**。
   */
  @Builder
  accentPicker() {
    Column({ space: Space.sm }) {
      Row({ space: Space.md }) {
        Text('🎨')
          .accessibilityLevel('no')
          .fontSize(FontSize.xl)
          .width(Space.xxl)
          .textAlign(TextAlign.Center)
        // ★★★ 2026-11-08（主题色色板修复）**根因找到了**：
        //   2026-11-07 那次（verifier-dev S-01「这一卡只剩一枚 🎨」）只补回了**标题块**，
        //   没动**根因** —— 「界面模式」整块当时是**嵌在 `accentPicker()` 里面的**，
        //   于是顺序成了「🎨+标题 → 界面模式整卡 → 主题色标题(重复) → 色板」。
        //   用户扫一眼只见"标题 → 界面模式"，就报了「没有色板」（色板其实在下面，被整张卡顶开）。
        //   ⇒ 本轮把界面模式拆成独立的 `uiModePicker()`，并删掉重复的标题块；
        //     色板 `ForEach(ACCENTS)` 一直都在（1173 行那次 grep 漏看），不是"丢失"。
        Column({ space: 2 }) {
          Text(this.t('主题色', 'Accent colour'))
            .fontSize(FontSize.md).fontWeight(FontWeight.Medium).fontColor(this.theme().ink)
          Text(this.t('按钮和高亮都跟着换成这个颜色', 'Buttons and highlights follow this colour'))
            .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      .width('100%')


      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(ACCENTS, (o: AccentOption) => {
          this.accentChip(o)
        }, (o: AccentOption) => o.id)
      }
      .width('100%')

      // 实时预览：这一枚就是"按钮长什么样"
      Row({ space: Space.sm }) {
        Text(this.accentName())
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
        Blank()
        Text(this.t('开始 ›', 'Start ›'))
          .fontSize(FontSize.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
          .backgroundColor(this.accentColor())
          .borderRadius(Radius.full)
          .animation({ duration: Motion.fast, curve: Motion.spring() })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /**
   * ★★★ 2026-11-08（主题色色板修复）**「界面模式」独立成卡**
   *
   *   原来这一整块是**嵌在 `accentPicker()` 里的**（缩进了两层，`.padding/.backgroundColor/.borderRadius`
   *   都在 `Column({space: Space.sm})` 内部）⇒ 视觉上变成：
   *     「🎨 主题色」标题 → **界面模式整卡** → 「主题色」标题（重复一次）→ 色板
   *   于是用户看到「主题色描述完直接是界面模式」，**以为色板丢了**（verifier-dev S-01 报的就是这个）。
   *
   *   现在拆成两张并列的卡：`accentPicker()`（主题色）+ `uiModePicker()`（界面模式），
   *   顺序保持用户预期（主题色在前、界面模式在后）。
   */
  @Builder
  uiModePicker() {
        // ★ 2026-10-13 奥森：「可以加"长辈模式""简约模式"什么的」⇒ 定名【大字模式 / 紧凑模式】
      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Text('🔠').fontSize(FontSize.lg).width(IconSize.of(FontSize.lg)).height(IconSize.of(FontSize.lg)).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Column({ space: 2 }) {
            Text(this.t('界面模式', 'Layout scale'))
              .fontSize(FontSize.md).fontWeight(FontWeight.Medium).fontColor(this.theme().ink)
            Text(this.t('字大还是紧凑，一按就变', 'Bigger text or denser — one tap'))
              .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
        }
        .width('100%')
        // ★★★ 2026-10-16 模拟器实拍【二次确认】：奥森报的「最后一个显示不出来」没根治 ——
        //   套横向 Scroll 后，第三个按钮【滑不出来】（默认/大字模式都实测不动），
        //   只露出「Com…」⇒ 玩家【点不到】。
        //   ⇒ 改为 Flex 自动换行：宽度不够就换到第二行，★ 三个按钮永远可见、可点。
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(UiModeMgr.all(), (m: string) => {
            Column({ space: 2 }) {
              // ★★★ 2026-10-19 奥森报的 bug：「切换到别的模式后，默认模式下面的文字还是"当前模式"」
              //   第一刀：把「现在的样子」改成绝对描述「标准字号与间距」（见 UiMode.descOf / I18n）
              //   第二刀：选中的那一格【打一个 ✓】—— "哪个是当前"不再需要从颜色深浅去猜
              Row({ space: 3 }) {
                Text(this.t(UiModeMgr.labelOf(m), UiModeMgr.labelEnOf(m)))
                  .fontSize(FontSize.sm)
                  .fontWeight(this.uiMode === m ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.uiMode === m ? Color.White : this.theme().inkSoft)
                if (this.uiMode === m) {
                  Text('✓')
                    .accessibilityLevel('no')
                    .fontSize(FontSize.sm)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
              }
              Text(this.t(UiModeMgr.descOf(m), UiModeMgr.descEnOf(m)))
                .fontSize(FontSize.micro)
                .fontColor(this.uiMode === m ? Color.White : this.theme().inkFaint)
                .maxLines(1)
                // ★ 2026-10-14 同类全扫：maxLines(1) 必须配 textOverflow，否则溢出会被硬切
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
            .margin({ start: LengthMetrics.vp(0), end: LengthMetrics.vp(Space.sm), bottom: Space.xs })   // ★ Flex wrap 靠 margin 拉开间距
            .backgroundColor(this.uiMode === m ? this.accentColor() : this.theme().surfaceAlt)
            .border({ width: 1, color: this.uiMode === m ? this.accentColor() : this.theme().line })
            .borderRadius(Radius.md)
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'S979'; })
            .onBlur(() => { if (this.tvFocus === 'S979') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'S979'))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
              Haptics.tap();
              UiModeMgr.save(m);
              this.uiMode = m;
             }); })
            .accessibilityGroup(true)
            .accessibilityText(this.t(UiModeMgr.labelOf(m), UiModeMgr.labelEnOf(m)))
            .accessibilityLevel('yes')
            .onClick(() => {
              Haptics.tap();
              UiModeMgr.save(m);
              this.uiMode = m;
            })
          }, (m: string) => m)
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor(this.theme().surface)
      .borderRadius(Radius.lg)
      .margin({ bottom: Space.md })
  }

  /** 当前主题色的名字（'system' 显示"跟随系统"） */
  private accentName(): string {
    const cur: string = this.accent;
    for (let i = 0; i < ACCENTS.length; i++) {
      if (ACCENTS[i].id === cur) {
        return this.t(ACCENTS[i].zh, ACCENTS[i].en);
      }
    }
    return '';
  }

  /** 单个色块：彩色圆 + 名字 + 选中打勾（四列一行） */
  @Builder
  accentChip(o: AccentOption) {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(Space.xxl)
          .height(Space.xxl)
          // ★ 判据 1829：圆的尺寸是**视觉主角**，绝不能被 flex 压扁
          .flexShrink(0)
          .backgroundColor(Accent.color(o.id))
          .borderRadius(Radius.full)
          .borderWidth(this.isAccent(o.id) ? 3 : 0)
          .borderColor(this.theme().ink)
        if (this.isAccent(o.id)) {
          Text('✓')
            .accessibilityLevel('no')
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .scale({
        x: this.isAccent(o.id) ? PICK_SCALE : 1,
        y: this.isAccent(o.id) ? PICK_SCALE : 1
      })
      .animation({ duration: Motion.fast, curve: Motion.spring() })

      Text(this.t(o.zh, o.en))
        .fontSize(FontSize.micro)
        // ★★★ 2026-11-09：**窄屏 + 大字模式 ⇒ 允许两行**。
        //   实测（本机 853vp，切换到 elder 后重新 dump）：
        //     `FontSize.micro` 10→15 ⇒ 色名宽度**正好 ×1.50**
        //     （`Как в системе` 66.0→99.0vp、`Индиго` 35.7→53.3、`Красный` 42.0→63.0、`Оранжевый` 56.3→84.3）
        //   ⇒ 俄语最长名在 elder 下 = 84.7 × 1.5 = **127vp**。
        //   而 360vp 手机上 elder 档的卡片内容宽只有 ≈ **252vp**（Space.lg/md 也跟着变大）
        //   ⇒ 就算降到 **两列 45% = 113vp 也不够**（127 > 113），**一列 100% 才够但太丑**。
        //   ⇒ 所以窄屏 + elder 用「**三列 + 两行**」：30% = 75.6vp/行，两行 ≈ 151vp 容量 > 127vp ✓
        //   ⚠️ 同样**本机验不到**（853vp ⇒ 条件恒 false），是按下表推算的（见报告 §4）。
        .maxLines(Bp.width < 420 && this.uiMode === 'elder' ? 2 : 1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.isAccent(o.id) ? this.theme().ink : this.theme().inkFaint)
    }
    // ★★★ 判据 1829：**色块必须"固定尺寸 + 不参与压缩"**。
    //   23% 是"四列一行"的宽度基准；`flexShrink(0)` 保证 Flex 换行时它不会被压成椭圆/细条
    //   （1875 那次的教训就是 `SymbolGlyph` 在 Row 里被拉伸成一片紫）。
    //
    // ★★★ 2026-11-09（窄屏色块）：**窄屏（< 420vp）改 30% —— 四列变三列**
    //   真机实测（853vp 平板窗口，normal 档）：色名 `Небесно-голубой` = **84.7vp**，格宽 189vp。
    //   换算到 360vp 手机：内容宽 ≈ 288vp ⇒ 23% = **66.2vp** < 84.7vp ⇒ **会被省略号截断**。
    //   30% ⇒ 288 × 30% = **86.4vp**，刚好容下 84.7vp（余 1.7vp）。
    //   ⚠️ 本机是 853vp ⇒ `Bp.width < 420` **恒 false** ⇒ 这半句**在本机上验不到**（见巡检报告）。
    //   ⚠️ `Bp.width` 是静态类 `core/Bp` 的字段，由 `EntryAbility` 在 window 创建/尺寸变化时写入
    //      （`Bp.update(w,h)`）⇒ `@Builder` 里读它是合法的；同文件 `Common.ets:1250` 早已这么用。
    //      但它**不是 ArkUI 的观察状态** ⇒ 只有页面因别的原因重建时才会跟着换列（窗口 resize 本身会触发重建）。
    .width(Bp.width < 420 ? '30%' : '23%')
    .flexShrink(0)
    .padding({ top: Space.xs, bottom: Space.xs })
    // ★★★ 2026-11-08 读屏缺口修复（审计 P0-5 第 1 条）：
    //   色块的**颜色本身就是信息** —— 视力用户扫一眼就知道是哪个色、有没有选中；
    //   而原来这里只有子 Text 的「颜色名」会被零散念出来，
    //   **听不出"这是主题色选择"、更听不出"当前选中了哪个"**。
    //   ⇒ 合并成一个可访问对象，并把手势动作（选择）与状态（当前选中）一起说出来。
    .accessibilityGroup(true)
    .accessibilityText(this.t('主题色：', 'Theme colour: ') + this.t(o.zh, o.en)
      + (this.isAccent(o.id) ? this.t('，当前选中', ', currently selected') : ''))
    .accessibilityLevel('yes')
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'S1084-' + o.id; })
    .onBlur(() => { if (this.tvFocus === 'S1084-' + o.id) { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'S1084-' + o.id))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
      Haptics.tap();
      // ★ 一条路走完：AppStorage ＋ Palette.primary/primaryDeep ＋ 落盘
      Accent.set(o.id);
      ProgressStore.saveAccent(o.id);
     }); })
    .onClick(() => {
      Haptics.tap();
      // ★ 一条路走完：AppStorage ＋ Palette.primary/primaryDeep ＋ 落盘
      Accent.set(o.id);
      ProgressStore.saveAccent(o.id);
    })
  }

  /** 数据卡：2×2 摘要 + 累计一行 */
  @Builder
  statCard() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        this.statBox({ icon: '🎖️', zh: '等级', en: 'Level', kind: 'level', num: this.level })
        this.statBox({ icon: '🏆', zh: TG('通关了'), en: 'Cleared', kind: 'games', num: this.totalSolved })
      }
      .width('100%')

      Row({ space: Space.sm }) {
        this.statBox({ icon: '🎮', zh: TG('玩过几款'), en: 'Tried', kind: 'kinds', num: this.playedKinds() })
        this.statBox({ icon: '⭐', zh: '收藏', en: 'Saved', kind: 'kinds', num: this.favCount() })
      }
      .width('100%')

      Text(this.t('一共玩了', 'Played') + ' ' + this.tn('{n} 局', '{n} games', this.totalPlays, '{n} партия', '{n} партии', '{n} партий')
           + ' · ' + this.tn('{n} 分钟', '{n} min', this.playedMinutes()))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkFaint)
    }
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /** 统计格里的数字文案（在 Builder 内部调，换语言才会跟着重建） */
  private statValue(kind: string, n: number): string {
    if (kind === 'level') {
      return 'Lv.' + n;
    }
    if (kind === 'games') {
      return this.tn('{n} 局', '{n} games', n, '{n} партия', '{n} партии', '{n} партий');
    }
    return this.tn('{n} 款', '{n} games', n, '{n} игра', '{n} игры', '{n} игр');
  }

  /** 统计格（Row 里的格子用 layoutWeight，不写 width 100%） */
  @Builder
  statBox(cfg: StatCfg) {
    Column({ space: Space.xs }) {
      Row({ space: Space.xs }) {
        Text(cfg.icon).fontSize(FontSize.sm)
        Text(this.t(cfg.zh, cfg.en))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
      }
      Text(this.statValue(cfg.kind, cfg.num))
        .fontSize(FontSize.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme().surfaceAlt)
    .borderRadius(Radius.sm)
  }

  /** 可点行：emoji + 标题 + 副标题 + › */
  @Builder
  navRow(cfg: NavCfg) {
    Row({ space: Space.md }) {
      Text(cfg.icon)
        .fontSize(FontSize.xl)
        .width(Space.xxl)
        .textAlign(TextAlign.Center)

      Column({ space: Space.xs }) {
        Text(this.t(cfg.zh, cfg.en))
          .fontSize(FontSize.md)
          .fontWeight(FontWeight.Medium)
          .fontColor(cfg.danger ? Palette.danger : this.theme().ink)
        Text(this.t(cfg.subZh, cfg.subEn))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.rtl() ? '‹' : '›')
        .accessibilityLevel('no')
        .fontSize(FontSize.xl)
        .fontColor(this.theme().inkFaint)
    }
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    // ★★★ 2026-10-19 全面自查 A6：这一处 navRow 被【6 个入口】复用（隐私政策 / 局域网 /
    //   反馈 / 关于 …），原来点了没任何按压反馈、也没触感 ⇒ 改一处顶六处
    .stateStyles({
      pressed: { .scale({ x: 0.975, y: 0.975 }).opacity(0.9) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'S1192-' + cfg.en; })
    .onBlur(() => { if (this.tvFocus === 'S1192-' + cfg.en) { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'S1192-' + cfg.en))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
      Haptics.tap();
      cfg.tap();
     }); })
    .accessibilityGroup(true)
    // ★ 2026-11-08：navRow 念标题，不能念 cfg.icon（emoji）
    .accessibilityText(this.t(cfg.zh, cfg.en))
    .accessibilityLevel('yes')
    .onClick(() => {
      Haptics.tap();
      cfg.tap();
    })
  }

  /** 重置进度的内联二次确认 */
  @Builder
  confirmPanel() {
    Column({ space: Space.sm }) {
      Row({ space: Space.xs }) {
        Text('⚠️').fontSize(FontSize.md).width(IconSize.of(FontSize.md)).height(IconSize.of(FontSize.md)).textAlign(TextAlign.Center)
          .accessibilityLevel('no')
        Text(this.t('真的要清空吗？', 'Really clear everything?'))
          .fontSize(FontSize.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.danger)
      }
      .width('100%')

      Text(this.t('等级、通关记录、玩过的游戏、收藏和统计都会归零，删了就找不回来了。',
                 'Level, clears, played games, saves and stats all go back to zero. This cannot be undone.'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme().inkSoft)

      Row({ space: Space.sm }) {
        Text(this.t('再想想', 'Not now'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme().inkSoft)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: Space.sm, bottom: Space.sm })
          .backgroundColor(this.theme().surface)
          .borderRadius(Radius.sm)
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'S1226'; })
          .onBlur(() => { if (this.tvFocus === 'S1226') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'S1226'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
            Haptics.tap();   // ★ 2026-10-19 按压反馈
            this.confirming = false;
           }); })
          .accessibilityGroup(true)
          .accessibilityText(this.t('再想想', 'Not now'))
          .accessibilityLevel('yes')
          .onClick(() => {
            Haptics.tap();   // ★ 2026-10-19 按压反馈
            this.confirming = false;
          })

        Text(this.t('确定重置', 'Yes, reset'))
          .fontSize(FontSize.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .padding({ top: Space.sm, bottom: Space.sm })
          .backgroundColor(Palette.danger)
          .borderRadius(Radius.sm)
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'S1240'; })
          .onBlur(() => { if (this.tvFocus === 'S1240') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'S1240'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => {
            this.doReset();
           }); })
          .accessibilityGroup(true)
          .accessibilityText(this.t('确定重置', 'Yes, reset'))
          .accessibilityLevel('yes')
          .onClick(() => {
            this.doReset();
          })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surfaceAlt)
    .borderRadius(Radius.md)
  }

  /** 关于卡：版本 + 三行说明 */
  @Builder
  aboutCard() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Text('🎲')
          .accessibilityLevel('no')
          .fontSize(FontSize.xxl)
          .width(Space.xxl)
          .textAlign(TextAlign.Center)
        Column({ space: Space.xs }) {
          // ★ 2026-10-19 自查：应用名已改 One More（品牌名，不翻译）；下面这行是版本 + 款数
          Text('One More')
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          Text('v' + APP_VERSION + ' · ' + this.tn('共 {n} 款游戏', '{n} games in total', GAMES.length) + '  ·  ' + BUILD_TAG)
            .fontSize(FontSize.xxs)
            .fontColor(this.theme().inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      this.infoRow({
        // ★★★ 2026-10-19 收口复查抓到的假陈述（第 13 轮只修了隐私弹窗，这里漏了）：
        //   原来写「无需联网 / 连网络权限都没申请，飞行模式照样玩」—— 假话
        //   实际：manifest 申请了 ohos.permission.INTERNET（局域网对战要开 UDP 端口），
        //         GameKit 也要连华为服务器做账号校验
        //   ⇒ 改成实话：不改"离线能玩"这个真实卖点，只说清"什么时候才用网"
        icon: '📴', zh: '不联网也能玩', en: 'Playable offline',
        subZh: '355 款游戏全都不用联网。只有局域网对战、和华为游戏服务账号校验会用到网络',
        subEn: 'All 355 games run offline. Network is used only for LAN play and Huawei sign-in'
      })
      this.infoRow({
        icon: '🚫', zh: '无广告', en: 'No ads',
        subZh: '没有开屏广告、弹窗广告和看视频解锁',
        subEn: 'No splash ads, no pop-ups, no watch-a-video to unlock'
      })
      this.infoRow({
        // ★★★ 同上：原来写「不用注册账号，不上传数据，没用任何第三方代码」——
        //   「没用任何第三方代码」是假话（GameKit 就是第三方 SDK）
        //   ⇒ 改成实话
        icon: '🔒', zh: '不采集你的数据', en: 'No personal data collected',
        subZh: '不用注册账号，不上传游戏记录。只用华为游戏服务做账号校验',
        subEn: 'No account, no uploads of your records. Huawei Game Service is used only for sign-in'
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(Space.md)
    .margin({ left: Space.lg, right: Space.lg })
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /** 说明行（无箭头） */
  @Builder
  infoRow(cfg: InfoCfg) {
    Row({ space: Space.md }) {
      Text(cfg.icon)
        .fontSize(FontSize.md)
        .width(Space.xxl)
        .textAlign(TextAlign.Center)
      Column({ space: Space.xs }) {
        Text(this.t(cfg.zh, cfg.en))
          .fontSize(FontSize.sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().ink)
        Text(this.t(cfg.subZh, cfg.subEn))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme().inkFaint)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }
}
