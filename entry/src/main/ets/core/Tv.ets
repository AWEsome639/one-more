/**
 * Tv —— 智慧屏焦点导航（项目 F 阶段 2）
 *
 * ★★★ 为什么需要（2026-10-29）
 *   智慧屏**没有触摸屏**，只有遥控器：方向键移动焦点、OK 键确认、返回键退出。
 *   而 One More 原来是纯触摸应用 —— 全项目 `grep focusable` **零命中**。
 *   ⇒ 投到电视上，遥控器按什么都没反应，一个游戏都进不去。
 *
 * ★ 设计原则
 *   1. **只在电视上生效**：`Bp.isTv()` 为假时，所有方法返回原值 ⇒ 手机/平板/PC 零影响
 *   2. **焦点必须看得见**：3 米视距下，焦点框要比平时粗得多（4vp），颜色要用品牌色
 *   3. **用 ArkUI 原生的 focusBox**：不要自己画描边（会和圆角、阴影打架）
 *
 * 用法（三层）：
 *   ① 焦点框样式：`.focusBox(Tv.box())`
 *   ② 可聚焦：  `.focusable(Tv.on())`
 *   ③ 按键：    `.onKeyEvent((e: KeyEvent) => Tv.handleKey(e, () => this.doSomething()))`
 */

import { Bp } from './Bp';
import { Palette } from './Design';
import { ColorMetrics, LengthMetrics } from '@kit.ArkUI';

export class Tv {
  /** 是否开启焦点导航（只有智慧屏才开） */
  static on(): boolean {
    // ★★★ 2026-10-30（项目 F 阶段 2 补齐）：原来只认 `Bp.isTv()`。
    //   后果：**PC / 2in1 / 平板横屏（lg）上，卡片完全没有焦点能力** ——
    //   明明有键盘，方向键却在列表里点不动，只能拿鼠标一张张点。
    //   ⇒ 扩成「电视 + 桌面类 + 大屏」三类：
    //     · 电视      —— 遥控器方向键
    //     · 桌面/2in1 —— 键盘方向键
    //     · lg 大屏    —— 平板接键盘 / 智慧屏
    //   这三类的共同点：**用户手里有"方向键"这种输入方式**。
    //   手机（sm/md 触屏）仍然不启用 —— 避免无谓的焦点框干扰点按。
    return Bp.isTv() || Bp.isDesktop() || Bp.isLg();
  }

  /**
   * 焦点框样式。
   * ★ 3 米视距 ⇒ 4vp 粗、亮色（用品牌主色，和界面其它强调色一致）
   * ⚠️ ArkUI 的 focusBox 参数类型是 FocusBoxStyle，margin 用于让框离开元素边缘一点
   */
  static box(): FocusBoxStyle {
    // ★ 只用 strokeColor + strokeWidth：margin 不在 FocusBoxStyle 里
    //   （试过 `{...} as FocusBoxStyle` 带 margin ⇒ 编译报"类型不重叠"）
    // ★ FocusBoxStyle 要的是 ColorMetrics / LengthMetrics，不是裸 string/number
    let st: FocusBoxStyle = {
      strokeColor: ColorMetrics.resourceColor(Palette.primary),
      strokeWidth: LengthMetrics.vp(4)
    };
    return st;
  }

  /**
   * 处理一次按键。
   * @param e    onKeyEvent 给的事件
   * @param fire 按下 OK/Enter 时要做的事
   * @returns true = 已处理（吃掉这个按键）
   *
   * ★ 只处理「按下」那一半：ArkUI 会为同一个键发 Down 和 Up 两次，
   *   不判 Type 会导致一次按键触发两遍（点进游戏又立刻退出）
   */
  static handleKey(e: KeyEvent, fire: () => void): boolean {
    if (!Tv.on()) {
      return false;
    }
    if (e.type !== KeyType.Down) {
      return false;
    }
    const code: number = e.keyCode;
    // KEYCODE_ENTER = 2054 / KEYCODE_DPAD_CENTER = 2019 / KEYCODE_NUMPAD_ENTER = 2054
    if (code === 2054 || code === 2019) {
      fire();
      return true;
    }
    return false;
  }

  /**
   * 这个 keyCode 是不是方向键。
   * ★ 2026-10-30（PC / 2in1）：键盘方向键与遥控器 D-pad 用**同一套键码**
   *   （2012~2015）⇒ 一套逻辑同时服务电视遥控器与外接键盘。
   */
  static isArrow(code: number): boolean {
    return code === Tv.KEY_UP || code === Tv.KEY_DOWN
      || code === Tv.KEY_LEFT || code === Tv.KEY_RIGHT;
  }

  /**
   * 方向键 → 偏移量。返回 0 表示不是方向键。
   * @param cols 网格列数 —— 左右键移 ±1，上下键移 ±cols
   *
   * ⚠️ 列数必须由调用方给：
   *   · 手机竖屏 2 列 · 平板竖 3 列 · 平板横 4 列 · 手表 1 列
   *   · 但**同一台设备在不同列表里列数可能不同**（如「我收藏的」只剩 3 款）
   *   ⇒ 不能写死，必须现算。
   */
  static arrowDelta(code: number, cols: number): number {
    if (code === Tv.KEY_LEFT) { return -1; }
    if (code === Tv.KEY_RIGHT) { return 1; }
    if (code === Tv.KEY_UP) { return -cols; }
    if (code === Tv.KEY_DOWN) { return cols; }
    return 0;
  }

  /** 方向键码（给「列表里上下左右移动」这类自定义导航用） */
  static readonly KEY_UP: number = 2012;
  static readonly KEY_DOWN: number = 2013;
  static readonly KEY_LEFT: number = 2014;
  static readonly KEY_RIGHT: number = 2015;
  static readonly KEY_BACK: number = 2;
  static readonly KEY_ENTER: number = 2054;
  /**
   * ★ 2026-10-29（PC/2in1）：ESC 键码。
   *   HarmonyOS 上 KEYCODE_ESCAPE = 2070；部分外接键盘发 27（ASCII ESC）。
   *   两个都认。
   */
  static readonly KEY_ESC: number = 2070;
  static readonly KEY_ESC_ASCII: number = 27;
  static readonly KEY_DPAD_CENTER: number = 2019;

  /** 是不是 ESC（两种键码都认） */
  static isEsc(code: number): boolean {
    return code === Tv.KEY_ESC || code === Tv.KEY_ESC_ASCII;
  }

  /**
   * 桌面类设备（PC/2in1）上，键盘快捷键应该**永远生效**（不需要焦点）。
   * ★ 与 Tv.on() 的区别：Tv 只在 isTv 时为真；这里 PC 也算。
   */
  static desktopKeys(): boolean {
    return Bp.isDesktop() || Bp.isLg();
  }

  static isUp(code: number): boolean {
    return code === Tv.KEY_UP;
  }

  static isDown(code: number): boolean {
    return code === Tv.KEY_DOWN;
  }

  static isLeft(code: number): boolean {
    return code === Tv.KEY_LEFT;
  }

  static isRight(code: number): boolean {
    return code === Tv.KEY_RIGHT;
  }

  static isOk(code: number): boolean {
    return code === Tv.KEY_ENTER || code === Tv.KEY_DPAD_CENTER;
  }

  /**
   * 智慧屏上的字号放大系数（3 米视距）。
   * ★ 与 Bp.scale() 分开：那个是"格子大小"，这个是"字"
   *   电视上字要更大，但格子不能无限大（否则一屏放不下几个）
   */
  static fontScale(): number {
    return Bp.isTv() ? 1.25 : 1.0;
  }
}
