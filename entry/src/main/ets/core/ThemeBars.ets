/**
 * ThemeBars —— 让**系统导航条**跟随 App 的主题（2026-11-17，判据 `2851`）
 *
 * 背景：全库从来没调过 `setWindowSystemBarProperties` ⇒ 深色主题只把 App 页面变黑，
 *       **底部导航条那一条还是系统浅色** ⇒ 任何「底部有内容」的款都会露一条白
 *       （证据：`截图-Affix_Factory-095544.jpeg` 裁底部放大，灰字画在白条上）。
 *
 * 为什么**只设置导航条、不动状态栏**：
 *   `EntryAbility.onWindowStageCreate` 里记着 `2026-11-01` 的查证结论 —— 状态栏是系统
 *   （`com.ohos.sceneboard`）画的「白底黑字」，把它改白会让文字看不见。
 *   ⇒ 这里只负责**底部**那一条。
 *
 * ★ 铁律：任何失败都不许影响启动/切主题（全部 try/catch，只记日志）。
 */
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOM = 0x0001;
const TAG = 'THEMEBARS';

/** 深色页面底（与开屏 / Splash 的 OM_INK 同色系）；浅色直接用白 */
const DARK_BAR: string = '#0D1320';
const LIGHT_BAR: string = '#FFFFFF';

export class ThemeBars {
  /** 主窗口引用（由 EntryAbility 在 onWindowStageCreate 里绑一次） */
  private static win: window.Window | null = null;

  /** 绑定主窗口，并立刻按当前主题刷一次 */
  static bind(w: window.Window, dark: boolean): void {
    ThemeBars.win = w;
    ThemeBars.apply(dark);
  }

  /** 按当前深浅刷新导航条配色。**永不抛异常。** */
  static apply(dark: boolean): void {
    const w: window.Window | null = ThemeBars.win;
    if (w === null) {
      hilog.warn(DOM, TAG, '窗口未绑定，跳过');
      return;
    }
    try {
      const props: window.SystemBarProperties = {
        // 底部导航条
        navigationBarColor: dark ? DARK_BAR : LIGHT_BAR,
        isNavigationBarLightIcon: dark,
        // ★★★ 2026-11-18（判据 2895）：**状态栏也要跟着主题**。
        //   文件头原写「不动状态栏、因为它是系统画的白底黑字、改白会看不见文字」——
        //   那个担心针对的是「把状态栏改成白色」；而实测问题是**深色 App + 白状态栏** ⇒
        //   截图里顶部一条 117px 白带（三张跨 8 小时的截图完全一致 ⇒ 一直存在、不是我改坏的）。
        //   ⇒ 正解不是「改白」，而是**深底配亮图标**：
        statusBarColor: dark ? DARK_BAR : LIGHT_BAR,
        statusBarContentColor: dark ? '#FFFFFF' : '#000000'
      };
      w.setWindowSystemBarProperties(props).catch((e: Error) => {
        hilog.warn(DOM, TAG, 'setWindowSystemBarProperties 失败（不影响使用）: %{public}s', e.message);
      });
    } catch (e) {
      hilog.warn(DOM, TAG, 'setWindowSystemBarProperties 异常（不影响使用）: %{public}s',
        (e as Error).message);
    }
  }
}
