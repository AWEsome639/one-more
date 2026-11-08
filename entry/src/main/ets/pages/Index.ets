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

import { TG } from '../core/GameI18n';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Bp } from '../core/Bp';
import { Tv } from '../core/Tv';
import { FontSize, Space, Radius, Palette, Motion, Theme, Accent, Shadow } from '../core/Design';
import { UiModeMgr } from '../core/UiMode';
import { ProgressStore } from '../core/ProgressStore';
import { About } from '../core/About';
import { common, Want } from '@kit.AbilityKit';
import { Haptics } from '../core/Haptics';
import { L, I18n } from '../core/I18n';
import { GamesTab } from '../components/GamesTab';
import { StatsTab } from '../components/StatsTab';
import { SettingsTab } from '../components/SettingsTab';
import { Diag } from '../core/Diag';
import { LocalLLM } from '../core/LocalLLM';

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
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
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
          TG('不收集信息 · 只存本地'),
          'No data · Local only') : Bp.isWatch() ? TG('不收集你的信息，记录只存在手表里。') : this.t(
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

  /**
   * 打开隐私政策全文（系统浏览器）。
   *
   * ★★★ 2026-11-07 **交互死角**（code-hunter 扫描 P0-2）：
   *   原来只有同步 `try/catch`，而 `startAbility()` 返回 **Promise** ——
   *   同步 try 根本抓不到异步失败，catch 块里也只有一句注释（**什么也没做**）
   *   ⇒ 用户点「查看全文」打不开时**零反馈**，只会觉得按钮坏了。
   *   而**同一个 app 的同一个链接**，设置页那块是对的（挂了 `.catch()` 显示地址）
   *   ⇒ 照抄那 6 行。
   */
  private openPrivacy(): void {
    const url: string = this.langCode === 'en' ? About.PRIVACY_URL_EN : About.PRIVACY_URL;
    const ctx = getContext(this) as common.UIAbilityContext;
    ctx.startAbility({
      action: 'ohos.want.action.viewData',
      uri: url
    }).catch(() => {
      // 打不开就把地址显示出来，不让人卡住
      this.privacyFallback = this.t('打不开链接，请手动访问：', 'Cannot open link. Please visit: ') + url;
      setTimeout(() => { this.privacyFallback = ''; }, 5000);
    });
  }

  onUiModeChange(): void {
    UiModeMgr.apply(this.uiMode);
    this.uiRev = this.uiRev + 1;
  }
  // ★ 第 1277 轮：允许诊断期强制默认页签（-1 = 不强制），用于「输入层坏了但布局要验」
  @State current: number = Diag.forceTab >= 0 ? Diag.forceTab : 0;
  /** ★ 2026-11-03（第 916 轮）**PC hover 状态**：哪个页签在鼠标下（-1 = 无） */
  @State private barHover: number = -1;
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
  /** ★ 2026-11-07 判据 1781：隐私链接打不开时的兜底提示（按钮点了必须有反馈） */
  @State private privacyFallback: string = '';

  aboutToAppear(): void {
    UiModeMgr.apply(UiModeMgr.current());
    // ★ 2026-11-08：端侧 LLM 启动探针（`Diag.llmProbe`，验完置 false）
    //   为什么要在这里：对话入口的「找」按钮在 853×533 上被挤出屏幕、Enter 也不触发
    //   `onSubmit` ⇒ 没法从 UI 触发 `LocalLLM.init()`。这里探一次只多一行 hilog，
    //   失败也只是 `reason='init-false'/'init-failed'`，**不影响任何用户可见行为**。
    if (Diag.llmProbe) {
      LocalLLM.init().then((ok: boolean) => {
        hilog.info(0x0000, 'LocalLLM', 'probe ready=%{public}s initMs=%{public}d reason=%{public}s',
          String(ok), LocalLLM.stat.initMs, LocalLLM.stat.reason);
      }).catch(() => {
        // 静默：探针失败绝不影响启动
      });
    }
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
  // ★★★ 2026-11-03（第 1103 轮）**真 bug：开屏 → 首页的交接处 scale 跳变 8.3%**
  //
  //   开屏退场（Splash.ets）：pOut = sm(1950, 320)，
  //     `scale = 1 - pOut * 0.06`、`opacity = 1 - pOut`
  //   而 HOLD = 2230 硬跳 ⇒ 那一刻 pOut = (2230−1950)/320 = **0.875**
  //     ⇒ 开屏最后停在 **scale 0.9475 / opacity 0.125**
  //
  //   原来这里写 `scale({x: 1.03, y: 1.03})` ⇒ 首页从 **103%** 开始
  //     ⇒ 交接处 scale 从 0.9475 **突跳到 1.03**（差 8.3% 画面尺寸）
  //     ⇒ 读起来是"啪一下弹开"，不是"内容自己浮上来"
  //   注释里原本写的是「读起来是内容自己浮上来，不是换了一页」——
  //   那句话是**意图**，而 1.03 是**反着做的**。
  //
  //   ⇒ 修：让入场**从开屏的终点接住**（0.9475），而不是从 1.03 收回来。
  //     scale：0.9475 → 1.0（继续放大，与开屏缩小的方向相反但幅度连续）
  //     opacity：0.125 → 1.0（开屏 0.125 淡出，这里 0 起 ⇒ 差 0.125，视觉上"暗一下"）
  //   ⚠️ 0.9475 是「HOLD 时刻」的值 —— 若改 HOLD / pOut 区间，这里要同步重算
  //      （判据 326：一条等式里变量变了，等式必须重算）
  PageTransitionEnter({ type: RouteType.None, duration: 320 })
    .opacity(0)
    .scale({ x: 0.9475, y: 0.9475 })
}

  /**
   * 隐私说明卡（2026-10-29 起改为应用内自绘）。
   * 合规三条：
   *   ① 首次启动要弹、要用户明确同意 ⇒ 只有「同意并继续」会落盘
   *   ② 同意前不得有任何网络请求 ⇒ 本应用启动不联网
   *   ③ 要能看到隐私政策全文 ⇒ 「查看全文」跳系统浏览器
   */
  /**
   * ★ 2026-11-04（第 1171 轮）：隐私卡是否走"极小屏紧凑版"。
   *   ⚠️ `@Builder` 内部**不能写 `const` 声明**（编译报
   *      "Only UI component syntax can be written here"）⇒ 必须用方法。
   */
  private privacyCompact(): boolean {
    return Bp.isWatch() || Bp.tinyScreen();
  }

  @Builder
  privacyCard() {
    // ★★★ 2026-11-04（第 1171 轮）**195×195 真机抓到：隐私卡按钮溢出卡片**
    //   实测（585×585 px）：卡片白底到 y≈485，按钮到 y≈560 ⇒ 溢出约 75 px
    //   ⇒ 已做三项收紧（行数 5→4、间距 12→6、padding lg→md、按钮 42→36vp）
    //   ⚠️ **仍未彻底解决**：按钮仍超出卡片下边界。正确方案是把按钮移出滚动区、
    //      固定在卡片底部（`Column { Scroll(标题+正文) ; Row(按钮) }`），
    //      本轮试过 `Scroll` 包整卡 ⇒ 按钮被滚到可视区外，更糟，已回退。
    // ★★★ 2026-11-04（第 1172 轮）**彻底修法：按钮移出滚动区，固定在卡片底部**
    //
    //   上一轮（1171）只做了"收紧三项"，按钮高度恢复正常（36vp），但**仍伸出卡片 75 px**。
    //   上一轮还试过"整卡包 Scroll" ⇒ 按钮被压到 41px 且滚出可视区 ⇒ 更糟，已回退。
    //
    //   本轮正解（判据 519）：
    //     卡片 = Column {
    //              Scroll(标题 + 正文)   ← layoutWeight(1)，内容超高时只滚文字
    //              Row(两个按钮)         ← **在 Scroll 之外，永远可见**
    //            }
    //     .constraintSize({ maxHeight: '100%' })   ← 卡片本身不超出屏幕
    //
    //   ⇒ 效果：内容再多，按钮也永远在卡片底部、永远可点。
    Column({ space: this.privacyCompact() ? 6 : 12 }) {
      Scroll() {
        Column({ space: this.privacyCompact() ? 4 : 8 }) {
          Text(this.t('隐私说明', 'Privacy'))
            .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
            .width('100%')
          Text(TG('「One More」不收集你的个人信息，也不上传你的游戏记录。所有记录只存在你自己的手机里。需联网的只有两项：局域网对战、华为游戏服务的账号校验。'))
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
        // ★★★ 2026-11-02（第 844 轮）**手表 233×233 真机截图抓到**：
        //   这段摘要没有行数上限，在 233vp 上排了 12 行、把卡片撑破，
        //   **两个按钮被挤出卡片边界**（截图里按钮贴在屏幕最底、卡片外）。
        //   ⇒ 加行数上限 + 省略号；**完整内容仍可点「查看全文」看到** ——
        //     注释说"合规内容不能因为屏小而省"，全文入口还在，没有省。
        .maxLines(this.privacyCompact() ? 3 : 20)   // ★ 第 1176 轮：4→3（195 上省 49 px，让按钮回到卡片内）
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        }
        .width('100%')
      }
      // ★★★ 2026-11-04（第 1175 轮）**去掉 `layoutWeight(1)`**（奥森：「好像不太协调？」）
      //
      //   第 1172 轮我用 `.layoutWeight(1)` 让 Scroll 吃掉剩余高度 ——
      //   目的达到了（按钮被推到卡片底部、不会溢出），
      //   但**副作用**是：正文只有 2 行时，Scroll 仍然把剩余空间全部占住
      //     ⇒ 正文与按钮之间空出 **246 vp** 的大白块（440×744 实测 739 px）。
      //
      //   ⇒ 改成给 Scroll 一个**明确的高度上限**：
      //     内容少 ⇒ Scroll 按内容收缩（空白消失）
      //     内容多 ⇒ Scroll 到上限后内部滚动（按钮仍在卡片内）
      .constraintSize({ maxHeight: this.privacyCompact() ? 120 : 300 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')

      // ★ 按钮在 Scroll **之外** ⇒ 永远可见（判据 519）
      // ★★★ 2026-11-07 溢出审计：**非极小屏改竖排、每个按钮整行**。
      //   并排时每个按钮只有 ~132vp，而俄语「Согласиться и продолжить」24 字符 ≈208vp
      //   ⇒ 只能在「同意并继续」上显示成「Согласиться и пр…」。
      //   ⚠️ `textOverflow` 修不了：`Button` 的 `LabelStyle.overflow` 默认就是 Ellipsis。
      //   极小屏这一支**保持不变**（那里已用短标签，且高度极紧，判据 519）。
      if (Bp.isWatch() || Bp.tinyScreen()) {
      Row({ space: 10 }) {
        // ★ 2026-11-02（第 845 轮）**手表 233×233**：两个按钮并排时宽度不够，
        //   文字被省略成「查看…」「同意…」⇒ 极小屏改用短标签（语义不变）。
        Button(Bp.isWatch() || Bp.tinyScreen()
          ? TG('全文')
          : this.t('查看全文', 'Read policy'))
          .layoutWeight(1).height(this.privacyCompact() ? 36 : 42)
          .fontSize(FontSize.sm)
          .fontColor(this.theme().ink)
          .backgroundColor(this.theme().surfaceAlt)
          .borderRadius(Radius.md)
          .accessibilityText(this.t('查看全文', 'Read policy'))
          .onClick(() => { Haptics.tap(); this.openPrivacy(); })
        Button(Bp.isWatch() || Bp.tinyScreen()
          ? TG('同意')
          : this.t('同意并继续', 'Agree and continue'))
          .layoutWeight(1).height(this.privacyCompact() ? 36 : 42)
          .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.accentColor())
          .borderRadius(Radius.md)
          .accessibilityText(this.t('同意并继续', 'Agree and continue'))
          .onClick(() => { this.agreePrivacy(); })
      }
      .width('100%')
      } else {
        this.privacyFootStack()
      }
    }
    .width('88%')
    // ★★★ 2026-11-04（第 1173 轮）**上限给"够用"而不是"满屏"**
    //   第 1172 轮用了 `maxHeight: '100%'`（判据 522 的方案）——
    //   在 195（内容刚好占满）上效果完美，但在 960×540 上**卡片被撑到屏高 87%**，
    //   而实际内容只有 3 行字 + 两个按钮 ⇒ 大片空白，观感差。
    //   ⇒ 极小屏仍用 100%（内容真的需要那么多），其余给 **80%**（上下各留 10% 呼吸）
    // ★ 第 1173 轮二调：大屏 80% 仍然偏高（卡片占屏 71%、正文与按钮之间空白大）
    //   ⇒ 收到 **60%**：实测内容只需约 420 px，60% of 1620 = 972 px ⇒ 绰绰有余
    .constraintSize({
      // ★★★ 2026-11-04（第 1176 轮）**compact 必须 '100%'，不能 '95%'**
      //   第 1175 轮我把它改成 95%，结果 195 上卡片被压到 323 px
      //   （内容需要 ~497 px）⇒ **按钮又伸出卡片底边**
      //   ⇒ 极小屏本来就只有 195 vp 高，任何"留边"都会挤掉内容
      maxHeight: this.privacyCompact() ? '100%' : '85%'
    })
    .padding(this.privacyCompact() ? Space.md : Space.lg)
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
      Text(TG('欢迎来到 One More'))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme().ink)
      Text(TG('355 款小游戏，每一款都能：'))
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
      Column({ space: 7 }) {
        Text(TG('💡 提示 — 卡住时给下一步'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(TG('🤖 AI 代打 — 看它一步一步走完'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(TG('▶️ 演示 — 进游戏 3 秒自动演一遍'))
          .fontSize(FontSize.sm).fontColor(this.theme().ink)
        Text(TG('🔍 搜索 / 分类 / 收藏'))
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


  /** ★ 2026-11-07 溢出审计：同意隐私协议的**统一入口**（并排 / 竖排两支都调它，别写两遍） */
  private agreePrivacy(): void {
    Haptics.tap();
    ProgressStore.savePrivacyAgreed();
    this.showPrivacy = false;
    // ★ 2026-10-29：同意的那一刻**直接接上欢迎卡**。
    //   理由：kick 那 8 次重试（1.6s~7.2s）在用户同意之前就耗完了，
    //   同意之后没有任何东西再触发 ⇒ 欢迎卡永远不出现。
    if (!ProgressStore.onboarded()) {
      this.showWelcome = true;
    }
  }

  /**
   * ★★★ 2026-11-07 溢出审计：隐私页两按钮的**竖排整行**版本（非极小屏用）。
   *
   * 为什么必须竖排：并排时每个按钮只有 ~132vp（卡片内宽 288 − 间距 10，再减按钮 padding），
   *   而最长语言放不下 —— 俄 `Согласиться и продолжить` 24 字符 ≈208vp、
   *   德 `Zustimmen und weiter` 20 字符 ≈180vp ⇒ 只能显示成「Согласиться и пр…」。
   *   竖排后每个按钮拿到卡片整宽 288vp ⇒ 12 种语言全部完整显示。
   *
   * ⚠️ 为什么不能用 `textOverflow` 修（很容易踩的坑）：
   *   `Button(label)` 的 `LabelStyle.maxLines` **默认就是 1**、`overflow` **默认就是
   *   TextOverflow.Ellipsis** ⇒ 它本来就在省略号截断，再写一遍是空操作，用户看到的还是半句。
   *   要真放得下只能给宽度（本函数）或缩字号（缩到 9vp 才够，不可接受）。
   *
   * ⚠️ 为什么抽成 @Builder 而不是直接改原来那个 `Row`：
   *   极小屏（233/195）必须继续**并排** —— 那里已经用短标签「全文」「同意」，
   *   且高度极紧（判据 519 那笔账：多 46vp 按钮就会被顶出卡片）。所以按设备分两支，
   *   高度不变、只是换了方向。
   */
  @Builder
  privacyFootStack() {
    Column({ space: 10 }) {
      Button(this.t('查看全文', 'Read policy'))
        .width('100%').height(this.privacyCompact() ? 36 : 42)
        .fontSize(FontSize.sm)
        .fontColor(this.theme().ink)
        .backgroundColor(this.theme().surfaceAlt)
        .borderRadius(Radius.md)
        .accessibilityText(this.t('查看全文', 'Read policy'))
        .onClick(() => { Haptics.tap(); this.openPrivacy(); })
      Button(this.t('同意并继续', 'Agree and continue'))
        .width('100%').height(this.privacyCompact() ? 36 : 42)
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(this.accentColor())
        .borderRadius(Radius.md)
        .accessibilityText(this.t('同意并继续', 'Agree and continue'))
        .onClick(() => { this.agreePrivacy(); })
      }
      .width('100%')
      // ★★★ 2026-11-07 判据 1781：**「查看全文」点了必须有反馈** ——
      //   打不开系统浏览器时把地址显示出来（设置页那块早有这个处理，首启弹窗漏了）。
      if (this.privacyFallback.length > 0) {
        Text(this.privacyFallback)
          .fontSize(FontSize.xxs).fontColor(Palette.warning)
          .width('100%').textAlign(TextAlign.Center)
          .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ top: Space.sm })
      }
  }

build() {
    Stack({ alignContent: Alignment.Center }) {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.current }) {
        TabContent() {
          if (this.uiRev % 2 === 0) { GamesTab() } else { GamesTab() }
        }
        .tabBar(this.barItem(0, '🎮', '游戏', 'Games'))   // ★ 2026-11-08：**不能再套 TG()** ——
        //   barItem 内部会用 this.t(zh, en) 取词；外面套 TG() 会先把 '游戏' 翻成当前语言，
        //   再当 zh 传进去 ⇒ 拿阿语/俄语去查字典 ⇒ 查不到 ⇒ **退英文**。
        //   真机证据：阿语下底部三标签显示 Games / Stats / Settings。（判据 1801：三层取词）

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
    // ★★★ 2026-11-08 RTL：挂在**根 Stack** 上，覆盖整页（含隐私/引导遮罩）。
    //   ⚠️ 真机实测：这一层**不会**穿透进 `Tabs/TabContent` 里的自定义组件 ——
    //      阿语下箭头镜像了（说明 rtl() 正常），但标题仍在左、模式胶囊仍是 LTR 顺序。
    //   ⇒ 三个 Tab 各自在自己的根上又声明了一份（GamesTab/StatsTab/SettingsTab）。
    //   ⚠️ 用 this.rtl() 而不是裸 I18n.isRTL()：后者读静态缓存，ArkUI 看不到依赖。
    }
    .direction(this.rtl() ? Direction.Rtl : Direction.Ltr)
  }

  /**
   * ★ 2026-11-08 RTL 判据（**别改成直接写 I18n.isRTL()**）
   *   `I18n.current()` 返回的是 `I18n.cached` 静态字段，ArkUI 不会为它建立渲染依赖
   *   ⇒ 切语言后 direction 不会重算。摸一下 `this.langCode`（@StorageProp）才有依赖。
   *   这个写法照抄 Common.ets 的 `taglineText()/gameTitle()`（同类坑踩过）。
   */
  private rtl(): boolean {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return I18n.isRTL();
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
    // ★★★ 2026-11-03（第 916 轮）**PC hover：底部标签栏是桌面上最常被点的元素**。
    //   原来这里只有电视焦点（focusBox），鼠标划过**没有任何反馈** ——
    //   而同一份代码里的 GameCard 是有 hover 的（Common.ets:922）
    //   ⇒ 同一个 App 里两种手感，玩家会觉得"下半截没做完"。
    //   ⚠️ `Bp.isDesktop() || Bp.isLg()` 门控：触屏设备不该有 hover 态。
    //   ⚠️ 高亮只改**背景色**，不碰内部 Text(icon) 已有的 1.15 scale
    //      （两层 scale 会相乘，1.06×1.15=1.22 太大）。
    .onHover((isHover: boolean) => {
      if (!(Bp.isDesktop() || Bp.isLg())) {
        return;
      }
      animateTo({ duration: Motion.fast, curve: Motion.snap() }, () => {
        this.barHover = isHover ? idx : -1;
      });
    })
    .backgroundColor(this.barHover === idx && this.current !== idx
      ? this.theme().surfaceAlt : Color.Transparent)
    .borderRadius(Radius.sm)
    // ★★★ 2026-10-29（项目 F 阶段 2）：智慧屏焦点
    //   电视上没有触摸 ⇒ 用遥控器方向键在三个页签间移动，OK 键切换
    //   `this.current = idx` 就是 Tabs 的受控索引，和点击 tabBar 的效果一致
    //   ⚠️ 不在电视上时这几行完全不起作用（Tv.on() 恒 false）
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'L475-' + idx; })
    .onBlur(() => { if (this.tvFocus === 'L475-' + idx) { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'L475-' + idx, Radius.sm))
    .onKeyEvent((e: KeyEvent) => {
      Tv.handleKey(e, () => {
        animateTo({ duration: Motion.base, curve: Motion.spring() }, () => {
          this.current = idx;
        });
      });
    })
  }
}
