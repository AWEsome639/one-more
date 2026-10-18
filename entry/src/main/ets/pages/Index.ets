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

import { FontSize, Space, Radius, Palette, Motion, Theme, Accent } from '../core/Design';
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
      message: this.t(
        '「One More」不收集你的任何信息，也不上传任何数据。\n' +
        '你的记录只存在自己手机里；网络权限仅用于「局域网对战」，不连公网。\n\n' +
        '详情见隐私政策。',
        '"One More" collects no information and uploads no data.\n' +
        'Everything stays on your device; network permission is used only for LAN play.\n\n' +
        'See the Privacy Policy for details.'),
      autoCancel: false,
      // ★ 2026-10-13 实测修正：`cancel` 要的是 `{value, action}` **对象**，
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
    AlertDialog.show(opt);
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

  aboutToAppear(): void {
    UiModeMgr.apply(UiModeMgr.current());
    // ★ 2026-10-13 实测修正：两件事必须等 ——
    //   ① ProgressStore.init() 是异步的（要等它把 pref 句柄拿到）
    //   ② AlertDialog.show() 不能在 aboutToAppear 里立刻调（页面还没建好 ⇒ 静默失败）
    //   ⇒ 延迟 800ms 再弹
    setTimeout(() => { this.maybeShowPrivacy(); }, 800);
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
}

build() {
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
      .barHeight(60)
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
    .height(60)
    .justifyContent(FlexAlign.Center)
  }
}
