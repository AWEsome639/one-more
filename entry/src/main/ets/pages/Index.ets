/**
 * 主页壳 —— 底部导航（游戏 / 统计 / 设置）
 *
 * 动效：
 *   ① Tab 切换用 ArkUI Tabs 自带的滑动 + 时长控制
 *   ② 导航栏图标切换时 scale 弹跳 + 颜色渐变
 *   ③ 整页首次进场有轻微上浮淡入
 *   ④ ★ 2026-10-13「动画拉满」：**页面转场**（本页是路由栈底，只能靠
 *      `PageTransitionExit` 在"被 GameHost 盖住 / 从 GameHost 返回"时响应）
 *
 * 拾海 2026-10-10（本页 2026-10-13 加转场）
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Bp } from '../core/Bp';
import { Tv } from '../core/Tv';
import { FontSize, Space, Radius, Palette, Motion, Theme, Accent, Shadow } from '../core/Design';
import { UiModeMgr } from '../core/UiMode';
import { ProgressStore } from '../core/ProgressStore';
import { About } from '../core/About';
import { common, Want } from '@kit.AbilityKit';
import { Haptics } from '../core/Haptics';
import { L } from '../core/I18n';
import { GamesTab } from '../components/GamesTab';
import { StatsTab } from '../components/StatsTab';
import { SettingsTab } from '../components/SettingsTab';

@Entry
@Component
struct Index {
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  @StorageProp('themeDark') dark: boolean = false;
  /**
   * ★ 界面模式观察源（2026-10-13「大字 / 紧凑」）
   *   它本身不改这个组件的样子 —— **它的作用是"切换时让整棵树重建"**，
   *   这样各组件在 build() 里重新读 FontSize/Space/Radius（UiModeMgr 已改写过的值）。
   */
  @StorageProp('uiMode') @Watch('onUiModeChange') uiMode: string = 'normal';
  /**
   * ★ 强制整树重建的开关（2026-10-13 实测发现）：
   *   只改静态常量 + 父组件有观察源 **ArkUI 不会重建子组件** ⇒ 字号不会变。
   *   ⇒ 用一个 if 分支配对（两个分支内容相同）⇒ 切换时整棵子树【销毁+重建】
   *     ⇒ 各组件在 build() 里重新读 FontSize/Space/Radius ⇒ 真正生效。
   *   （同一个办法我在 GameHost 的难度刷新上用过，验证可行）
   */
  @State private uiRev: number = 0;
  /** 隐私弹窗句柄（用于「查看全文」后再弹一次） */
  private privacyDialog: object | null = null;

  /** 界面模式变了 ⇒ 先套用常量，再 flip 开关强制重建 */
  /**
   * ★ 首次启动的隐私同意弹窗（2026-10-13 · AGC 上架硬要求）
   *
   * 审核会查三件事，这里逐条满足：
   *   ① **首次启动要弹**、要用户明确同意 ⇒ `AlertDialog` + 必须点「同意并继续」
   *   ② **同意前不得有任何网络请求** ⇒ 本应用启动时不联网；局域网 socket 另有守卫
   *   ③ **要能看到隐私政策全文** ⇒ 弹窗里给「查看隐私政策」按钮，跳系统浏览器
   *
   * ⚠️ 已同意的用户**不再打扰**（标记落盘，见 ProgressStore.savePrivacyAgreed）
   */
  private maybeShowPrivacy(): void {
    if (ProgressStore.privacyAgreed()) {
      return;
    }
    // ★ 显式声明类型；字段名是 primaryButton / secondaryButton（见 d.ts:965）
    const opt: AlertDialogParamWithButtons = {
      title: this.t('隐私说明', 'Privacy'),
      // ★★★ 2026-10-29（六设备·手表实测）：系统 AlertDialog 的尺寸是系统定的，
      //   手表 233×233 vp 上原文案太长 ⇒ 弹窗撑满全屏、**「同意并继续」按钮够不到**
      //   ⇒ 用户卡在首启页，App 根本用不了。
      //   ⇒ 手表上只用一行极短文案（合规信息不减：「不收集信息 + 本地存储」），
      //     按钮就能完整露出来。
      message: Bp.tinyWatch() ? this.t(
          // ★ 2026-10-29（运动手表 195vp 实测）：18 字的文案仍会撑到 3 行、
          //   把两个按钮顶出屏幕 ⇒ 极小屏压到 8 个字（合规信息靠「查看全文」兜）
          '不收集信息 · 只存本地',
          'No data · Local only') : Bp.isWatch() ? this.t(
          '不收集你的信息，记录只存在手表里。',
          'No data collected. All records stay on this watch.') : this.t(
          // ★ 2026-10-19 真机首启实拍后修正：原来写「不连公网」是假的
          //   （GameKit 的账号校验会连华为服务器，这是应用市场对游戏类目的合规要求）
          '「One More」不收集你的个人信息，也不上传你的游戏记录。\n' +
          '所有记录只存在你自己的手机里。需联网的只有两项：局域网对战、华为游戏服务的账号校验。\n\n' +
          '详情见隐私政策。',
             '"One More" does not collect your personal information and never uploads your game records.\n' +
             'Everything stays on your device. Only two features use the network: LAN play and Huawei Game Service account check.\n\n' +
             'See the Privacy Policy for details.'),
      //   我第一版传了个函数 ⇒ **「查看全文」按钮根本没渲染**（实拍只有"同意并继续"）
      //   ⇒ 审核要求「用户能在同意【之前】读到全文」，这个按钮是硬要求
      secondaryButton: {
        value: this.t('查看全文', 'Read policy'),
        action: () => {
          this.openPrivacy();
        }
      },
      primaryButton: {
        value: this.t('同意并继续', 'Agree and continue'),
        action: () => {
          ProgressStore.savePrivacyAgreed();
        }
      }
    };
    // ★ 2026-10-29：不再用系统 AlertDialog（会静默失败、不可重试）
    //   ⇒ 用应用内自绘弹窗（见 privacyCard()），由 showPrivacy 控制
    this.showPrivacy = true;
  }

  /** 打开隐私政策全文（系统浏览器） */
  private openPrivacy(): void {
    const url: string = this.langCode === 'en' ? About.PRIVACY_URL_EN : About.PRIVACY_URL;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const want: Want = { action: 'ohos.want.action.viewData', uri: url };
      ctx.startAbility(want);
    } catch (e) {
      // 打不开就把地址显示出来，不让人卡住
    }
  }

  onUiModeChange(): void {
    UiModeMgr.apply(this.uiMode);
    this.uiRev = this.uiRev + 1;
  }
  @State current: number = 0;
  @State entered: boolean = false;
  /** 首次进入引导卡（项目 D ⑤）：点「开始玩」后落盘，不再出现 */
  @State private showWelcome: boolean = false;
  /**
   * ★★★ 2026-10-29 真机抓到的合规 BUG：
   *   原来隐私弹窗用系统 `AlertDialog.show()`，只试一次（800ms）。
   *   页面没建好时它**静默失败**（代码注释里自己就写着这个坑）⇒
   *   **全新安装后弹窗永远不出现** ⇒ 用户没同意就用了 App（合规风险），
   *   而且 privacyAgreed 永远 false ⇒ 欢迎卡也被连带卡死。
   *   ⇒ 改成**应用内自绘弹窗**（和 welcomeCard 同一个套路）：
   *     完全可控、可重试、不依赖系统时序。
   */
  @State private showPrivacy: boolean = false;

  aboutToAppear(): void {
    UiModeMgr.apply(UiModeMgr.current());
    // ★ 2026-10-13 实测修正：两件事必须等 ——
    //   ① ProgressStore.init() 是异步的（要等它把 pref 句柄拿到）
    //   ② AlertDialog.show() 不能在 aboutToAppear 里立刻调（页面还没建好 ⇒ 静默失败）
    //   ⇒ 延迟 800ms 再弹
    setTimeout(() => { this.maybeShowPrivacy(); }, 800);
    // ★★★ 2026-10-29 真机抓到的**真因**：showWelcome 从来没有被设成 true
    //   （之前那段触发代码根本没进文件）⇒ 欢迎卡永远不出现。
    //   时序坑：ProgressStore.init() 是异步的，太早判 privacyAgreed() 会返 false
    //   ⇒ 用重试（700ms × 8 次）而不是只判一次。
    let tries: number = 0;
    const kick: () => void = () => {
      tries = tries + 1;
      const agreed: boolean = ProgressStore.privacyAgreed();
      const done: boolean = ProgressStore.onboarded();
      // 只在"决定显示"那一刻留一行日志（便于线上排查"为什么没弹"），
      // 不在每次重试都打 —— 那是噪音

      if (this.showWelcome || done) {
        return;
      }
      if (agreed) {
        this.showWelcome = true;
        hilog.info(0x0001, 'testTag', 'ONBOARD_DBG showWelcome=true');
        return;
      }
      if (tries < 8) {
        setTimeout(kick, 700);
      }
    };
    setTimeout(kick, 1600);
    // 监听后续切换 ⇒ 强制重建（见 uiRev 的注释）   // 启动时把常量设成当前档（落盘恢复由 ProgressStore 负责）
    setTimeout(() => {
      this.entered = true;
    }, 30);
  }

  private theme(): Theme {
    return this.dark ? Theme.dark() : Theme.light();
  }

    /** 取当前语言的文案（必须读 langCode 建立 ArkUI 依赖，否则不重渲染） */
  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    return L(zh, en);
  }

/**
 * ★ 页面转场（2026-10-13「动画拉满」专项 item ②）
 *
 * 本页是**路由栈底**（`@Entry` 首页），进游戏是 `router.pushUrl` 把 GameHost 压上来
 * ⇒ 本页只在"被盖住"和"重新露出来"时动，所以效果全挂在 **Exit** 上：
 *   · 进游戏（type = Push）：整页**轻微上移 + 淡出**，做出"被推下去"的层次；
 *   · 返回（type = Pop）：浮回来 + 淡入。
 *
 * ⚠️ 用 `PageTransitionEnter/Exit`（定义在 `page_transition.d.ts`）而**不是**
 *   `TransitionEffect` —— 后者是**组件级**转场，挂在页面根节点上不响应路由事件。
 */
pageTransition() {
  PageTransitionExit({ type: RouteType.Push, duration: Motion.base })
    .translate({ y: -14 })
    .opacity(0)
  PageTransitionExit({ type: RouteType.Pop, duration: Motion.base })
    .translate({ y: -14 })
    .opacity(0)
  PageTransitionEnter({ type: RouteType.Pop, duration: Motion.base })
    .translate({ y: -14 })
    .opacity(0)
  // ★★★ 2026-10-30（P0-3）：**开屏 → 主页的交接**
  //
  //   先查了 SDK：`RouteType` 只有 None / Push / Pop **三个值**，没有 Replace。
  //   而 `page_transition.d.ts` 对 `None = 0` 的注释写明：
  //     "The page is not redirected. The animation specified by PageTransitionEnter
  //      takes effect for page entrance" —— **这正是 `router.replaceUrl` 的情形**。
  //   ⇒ 所以交接要挂在 `RouteType.None` 上。
  //
  //   原来只写了 Push/Pop，而 Splash 用 `replaceUrl` ⇒ 走 None ⇒ 无转场 ⇒ **硬切**。
  //   现在两页共用 #0D1320 底色，只差一个 scale 方向 + 淡入
  //   ⇒ 读起来是"内容自己浮上来"，不是"换了一页"。
  PageTransitionEnter({ type: RouteType.None, duration: 320 })
    .opacity(0)
    .scale({ x: 1.03, y: 1.03 })
}

  /**
   * 隐私说明卡（2026-10-29 起改为应用内自绘）。
   * 合规三条：
   *   ① 首次启动要弹、要用户明确同意 ⇒ 只有「同意并继续」会落盘
   *   ② 同意前不得有任何网络请求 ⇒ 本应用启动不联网
   *   ③ 要能看到隐私政策全文 ⇒ 「查看全文」跳系统浏览器
   */
  @Builder
  privacyCard() {
    Column({ space: 12 }) {
      Text(this.t('隐私说明', 'Privacy'))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
      Text(this.t('「One More」不收集你的个人信息，也不上传你的游戏记录。所有记录只存在你自己的手机里。需联网的只有两项：局域网对战、华为游戏服务的账号校验。',
                  'One More collects nothing and uploads nothing. All records stay on your phone. Only two things use the network: LAN matches and Huawei Game Service sign-in.'))
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
      Row({ space: 10 }) {
        Button(this.t('查看全文', 'Read policy'))
          .layoutWeight(1).height(42)
          .fontSize(FontSize.sm)
          .fontColor(this.theme().ink)
          .backgroundColor(this.theme().surfaceAlt)
          .borderRadius(Radius.md)
          .accessibilityText(this.t('查看全文', 'Read policy'))
          .onClick(() => { Haptics.tap(); this.openPrivacy(); })
        Button(this.t('同意并继续', 'Agree and continue'))
          .layoutWeight(1).height(42)
          .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.accentColor())
          .borderRadius(Radius.md)
          .accessibilityText(this.t('同意并继续', 'Agree and continue'))
          .onClick(() => {
            Haptics.tap();
            ProgressStore.savePrivacyAgreed();
            this.showPrivacy = false;
            // ★ 2026-10-29：同意的那一刻**直接接上欢迎卡**。
            //   理由：kick 那 8 次重试（1.6s~7.2s）在用户同意之前就耗完了，
            //   同意之后没有任何东西再触发 ⇒ 欢迎卡永远不出现。
            if (!ProgressStore.onboarded()) {
              this.showWelcome = true;
            }
          })
      }
      .width('100%')
    }
    .width('88%')
    .padding(Space.lg)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

  /**
   * ★★★ 2026-10-29（项目 D ⑤）：首次进入引导卡。
   *   一次性：点「开始玩」后 ProgressStore.saveOnboarded()，不再出现。
   *   手表上跳过（233vp 放不下，且手表只有 24 款，不需要解释 355 款）。
   */
  @Builder
  welcomeCard() {
    Column({ space: 12 }) {
      Text('👋').fontSize(38)
      Text(this.t('欢迎来到 One More', 'Welcome to One More'))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
      Text(this.t('355 款小游戏，每一款都能：', '355 mini-games. Every one can:'))
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
      Column({ space: 7 }) {
        Text(this.t('💡 提示 — 卡住时给下一步', '💡 Hint — the next step when stuck'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(this.t('🤖 AI 代打 — 看它一步一步走完', '🤖 Auto-play — watch it finish'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(this.t('▶️ 演示 — 进游戏 3 秒自动演一遍', '▶️ Demo — 3s after you enter'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(this.t('🔍 搜索 / 分类 / 收藏', '🔍 Search, filter, favourites'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
      }
      .alignItems(HorizontalAlign.Start).width('100%')

      Button(this.t('开始玩', 'Start playing'))
        .width('100%').height(46)
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.accentColor())
        .borderRadius(Radius.md)
        .accessibilityText(this.t('开始玩', 'Start playing'))
        .onClick(() => {
          Haptics.tap();
          ProgressStore.saveOnboarded();
          this.showWelcome = false;
        })
    }
    .width('86%')
    .padding(Space.lg)
    .backgroundColor(this.theme().surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

build() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.current }) {
        TabContent() {
          if (this.uiRev % 2 === 0) { GamesTab() } else { GamesTab() }
        }
        .tabBar(this.barItem(0, '🎮', '游戏', 'Games'))

        TabContent() {
          if (this.uiRev % 2 === 0) { StatsTab() } else { StatsTab() }
        }
        .tabBar(this.barItem(1, '📊', '统计', 'Stats'))

        TabContent() {
          if (this.uiRev % 2 === 0) { SettingsTab() } else { SettingsTab() }
        }
        .tabBar(this.barItem(2, '⚙️', '设置', 'Settings'))
      }
      // ★ 2026-10-29（六设备·手表实测）：233×233 vp 上 60vp 的页签占掉 1/4 屏
      //   ⇒ 手表缩到 36，给列表让出空间
      // ★ 2026-10-29（奥森提醒「显示大小可以变得很小」）：
      //   极小屏（高 < 340vp，含手机把显示大小调到最小）页签也要缩，
      //   否则 60vp 页签 + 顶栏会把列表挤没（实测 195vp 下一张卡都放不下）
      .barHeight(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60)
      .barMode(BarMode.Fixed)
      .barBackgroundColor(this.theme().surface)
      .scrollable(true)
      .animationDuration(Motion.base)
      .divider({ strokeWidth: 0 })
      .onChange((i: number) => {
        Haptics.tick();   // ★ 手感：切页给最轻的一下

        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.current = i;
        });
      })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bg)
    .opacity(this.entered ? 1 : 0)
    .translate({ y: this.entered ? 0 : 10 })
    .animation({ duration: Motion.slow, curve: Motion.spring() })

    // ★ 隐私说明卡（2026-10-29：应用内自绘，替代会静默失败的 AlertDialog）
    //   手表/极小屏也显示 —— 合规内容不能因为屏小而省，但文字会自动换行
    if (this.showPrivacy) {
      Stack() {
        Column().width('100%').height('100%').backgroundColor('#99000000')
        this.privacyCard()
      }
      .width('100%').height('100%')
    }

    // ★ 首次进入引导卡（项目 D ⑤）：盖在内容之上，点「开始玩」消失
    //   手表/极小屏跳过（放不下，且那些设备只有 24 款，不需要解释 355 款）
    if (this.showWelcome && !Bp.isWatch() && !Bp.tinyScreen()) {
      Stack() {
        // 半透明遮罩：点它也算"看过了"，但必须点按钮才落盘
        Column().width('100%').height('100%').backgroundColor('#99000000')
        this.welcomeCard()
      }
      .width('100%').height('100%')
    }
    }
  }

  @Builder
  barItem(idx: number, icon: string, zh: string, en: string) {
    // ★ 在 Builder 内部取词。⚠️ ArkTS 的 @Builder 里**不能声明局部变量**
    //   （只允许 UI 组件语法）⇒ 只能把判断写成表达式，直接塞进 Text()
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(this.current === idx ? FontSize.lg : FontSize.md)
        .scale({ x: this.current === idx ? 1.15 : 1, y: this.current === idx ? 1.15 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.spring() })
      // ★ 走 this.t() 而不是裸 L() —— 裸 L() 是模块级函数，ArkUI 看不到依赖，
        //   切语言后底部导航不重渲染（这个坑我踩了四次，这是第五次换马甲）
        Text(this.t(zh, en))
        .fontSize(FontSize.xxs)
        .fontWeight(this.current === idx ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === idx ? this.accentColor() : this.theme().inkFaint)
        .animation({ duration: Motion.fast, curve: Motion.spring() })
    }
    .width('100%')
    .height(Bp.isWatch() || Bp.tinyScreen() ? 36 : 60)
    .justifyContent(FlexAlign.Center)
    // ★★★ 2026-10-29（项目 F 阶段 2）：智慧屏焦点
    //   电视上没有触摸 ⇒ 用遥控器方向键在三个页签间移动，OK 键切换
    //   `this.current = idx` 就是 Tabs 的受控索引，和点击 tabBar 的效果一致
    //   ⚠️ 不在电视上时这几行完全不起作用（Tv.on() 恒 false）
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => {
      Tv.handleKey(e, () => {
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.current = idx;
        });
      });
    })
  }
}
