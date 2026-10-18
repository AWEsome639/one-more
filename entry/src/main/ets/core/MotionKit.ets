/**
 * 动效工具箱（拾海 2026-10-13）—— 「动画配置拉满」专项
 *
 * ## 为什么单独一个文件
 * 曲线/时长常量都在 `core/Design.ets` 的 `Motion` 里（**那一份是 lead 的地盘，我不动**）。
 * 这里只放**用这些常量拼出来的、可复用的动效零件**：
 *   · `RollingNumber` —— 数字滚动（结算面板那种"滚上去"）
 *   · `@Extend(Text) pressBounce` —— 图标/文字按下弹一下
 *   · `@Extend(Button)` / `@Styles` 类的小反馈
 *
 * ## 三条纪律（都是本项目踩过的）
 * ① **别每帧 `setState`** —— 数字滚动必须"自己推帧 + 到点就停"，不能挂着不停；
 * ② **`animateTo` 里改 `@State` 才会动** —— 只改局部变量UI不会重绘；
 * ③ **@Extend/@Styles 里不能读 `this`** —— 需要主题色时由调用方用 `.fontColor()` 补。
 */

import { Motion } from '../core/Design';

/**
 * 数字滚动器
 *
 * 用法（组件里）：
 * ```ts
 * @State shown: number = 0;
 * private roll: RollingNumber = new RollingNumber();
 * private onScore(v: number) { this.roll.to(v, (x: number) => { this.shown = x; }); }
 * aboutToDisappear() { this.roll.stop(); }     // ★ 必须停，否则离开页面还在推帧
 * ```
 *
 * 为什么不用 `animateTo`：它只能插值**属性**，插不了"显示用的数字" ⇒ 只能自己推帧。
 * 缓动 `easeOutCubic`（先冲后稳）—— 比线性有手感。
 */
export class RollingNumber {
  private timer: number = -1;
  /** 每帧间隔（ms）。34ms ≈ 30fps，够顺且省电 */
  private readonly stepMs: number = 34;
  /** 分几帧走完 */
  private readonly steps: number = 18;

  /** 滚到 target；apply 每帧回调一次（把值写进 @State） */
  to(target: number, apply: (v: number) => void, steps?: number): void {
    this.stop();
    if (target <= 0) {
      apply(0);
      return;
    }
    const n: number = steps === undefined ? this.steps : steps;
    let i: number = 0;
    this.timer = setInterval(() => {
      i = i + 1;
      const p: number = i / n;
      const e: number = 1 - Math.pow(1 - p, 3);   // easeOutCubic
      apply(Math.round(target * e));
      if (i >= n) {
        this.stop();
        apply(target);            // ★ 收尾必须写"准确值"，别让四舍五入留下 1 的误差
      }
    }, this.stepMs);
  }

  /** 停掉当前滚动（重开一局 / 离开页面时必须调，否则数字会抖） */
  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
}

/**
 * 图标/文字「按下弹一下」的工具函数
 *
 * ## 为什么不做成 `@Extend` / `@Styles`
 * 试过，都不行：
 *   · `@Extend(Text)` 里**不能读 `this`** ⇒ 弹跳要看 `@State pressed`，读不到就动不了；
 *   · `@Styles` 只能放通用属性，放不了 `onTouch` 闭包里的状态判断。
 * ⇒ 只能"组件自己持有 `pressed` 状态、自己写 onTouch"。这里给的是**统一的数值**，
 *   免得每处各写一个（1.08 是实测手感最舒服的档：够明显又不晃眼）。
 *
 * 用法（三行，跟 GameCard 的按下反馈同一套写法）：
 * ```ts
 * @State private pressed: boolean = false;
 * // ...
 * Text('🎮').scale({ x: this.pressed ? IconPress.scale : 1, y: this.pressed ? IconPress.scale : 1 })
 *   .animation({ duration: Motion.fast, curve: Motion.snap() })
 *   .onTouch((e: TouchEvent) => { this.pressed = IconPress.onTouch(this.pressed, e); })
 * ```
 */
export class IconPress {
  /** 按下时放大到的倍率（>1 = "弹起来"；图标类用放大，卡片类用缩小更自然） */
  static readonly scale: number = 1.08;

  /**
   * 统一的按下/抬起判定
   * - Returns: 处理后的 pressed 值
   */
  static onTouch(pressed: boolean, e: TouchEvent): boolean {
    if (e.type === TouchType.Down) {
      return true;
    }
    if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      return false;
    }
    return pressed;
  }
}
