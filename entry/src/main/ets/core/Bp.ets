/**
 * Bp（Breakpoint）—— 设备断点与自适应布局的单一口径
 *
 * ★★★ 为什么要有这个文件（2026-10-28，项目 F：六设备支持）
 *   以前全项目的尺寸只有 `Cell.k` 一个系数（普通/大字号/简洁三档），
 *   它解决的是"同一台手机上字大字小"，**完全没有设备概念**：
 *     · 平板上 355 个游戏还是按手机宽度排 ⇒ 两边大片空白，字小得可怜
 *     · PC/2in1 上窗口能拖到 1600vp，格子还是 44vp ⇒ 像在看邮票
 *   ⇒ 这里补上「当前窗口多宽 ⇒ 该用多大的格子、排几列」
 *
 * ★ 设计原则
 *   1. **只做加法**：手机上的值必须和改造前**一模一样**（scale = 1.0）
 *      ⇒ 老设备零回归，这是硬门槛
 *   2. **单一来源**：宽度只从 WindowStage 读一次 + 监听变化，别到处 getWindowProperties
 *   3. **优雅降级**：任何一步失败都退回"手机 + 360vp"，绝不让界面打不开
 *
 * 设备类型（与 AGC「支持设备」六个勾选框对齐）
 *   phone / tablet / 2in1 / tv / wearable —— 后两个另有专门的布局分支
 */

/** 设备类型（与 module.json5 的 deviceTypes、AGC 的勾选框同名） */
export class BpDev {
  static readonly PHONE: string = 'phone';
  static readonly TABLET: string = 'tablet';
  static readonly PC: string = '2in1';
  static readonly TV: string = 'tv';
  static readonly WATCH: string = 'wearable';
  /** 折叠屏的 deviceType 仍是 phone，靠宽度区分（展开后通常 ≥ 600vp） */
}

export class Bp {
  /** 当前窗口宽度（vp）。默认按手机最小宽度算，宁可小不要溢出 */
  static width: number = 360;
  /** 当前窗口高度（vp） */
  static height: number = 780;
  /** 设备类型 */
  static dev: string = BpDev.PHONE;
  /** 是否已初始化过（避免重复注册监听） */
  static ready: boolean = false;

  // ─────────── 断点阈值（vp）───────────
  /** 小于它 = 手机竖屏 */
  static readonly SM: number = 600;
  /** 小于它 = 平板竖屏 / 折叠屏展开 */
  static readonly MD: number = 840;

  /** ★ 由 EntryAbility 在窗口创建时调用一次，窗口变化时再调 */
  static update(w: number, h: number, dev?: string): void {
    if (w > 0) {
      Bp.width = w;
    }
    if (h > 0) {
      Bp.height = h;
    }
    if (dev !== undefined && dev.length > 0) {
      Bp.dev = dev;
    } else if (Bp.width >= 1080) {
      // 没有设备信息时的保守推断：超宽窗口按 PC 处理
      Bp.dev = BpDev.PC;
    }
    Bp.ready = true;
  }

  // ─────────── 断点判断 ───────────
  static isSm(): boolean {
    return Bp.width < Bp.SM;
  }

  static isMd(): boolean {
    return Bp.width >= Bp.SM && Bp.width < Bp.MD;
  }

  static isLg(): boolean {
    return Bp.width >= Bp.MD;
  }

  /** 断点名，便于日志与调试 */
  static tag(): string {
    if (Bp.isLg()) {
      return 'lg';
    }
    if (Bp.isMd()) {
      return 'md';
    }
    return 'sm';
  }

  // ─────────── 尺寸缩放 ───────────
  /**
   * ★★★ 设备缩放系数 —— 与 Cell.k（字号档位）**相乘**，两者互不替代
   *   · 手机  1.00  ⇒ 与改造前完全一致（零回归的保证）
   *   · 折叠屏展开 / 平板竖 1.06
   *   · 平板横 / PC        1.12
   *   ⚠️ 不要给太大：格子太大反而显得空、也不好看（试过 1.3，棋盘像被放大镜照）
   */
  static scale(): number {
    if (Bp.dev === BpDev.TV) {
      return 1.45;        // 3 米视距，必须大
    }
    if (Bp.dev === BpDev.WATCH) {
      return 0.92;        // 466px 圆屏，略微收一点
    }
    if (Bp.isLg()) {
      return 1.12;
    }
    if (Bp.isMd()) {
      return 1.06;
    }
    return 1.0;
  }

  // ─────────── 布局列数 ───────────
  /**
   * 列表/网格该排几列。
   * @param base 手机上的列数（各页面自己定）
   * @returns 当前设备上的列数（只增不减，保证平板上不浪费空间）
   */
  static cols(base: number): number {
    if (Bp.dev === BpDev.TV) {
      return base + 2;
    }
    if (Bp.dev === BpDev.WATCH) {
      return 1;
    }
    if (Bp.isLg()) {
      return base + 2;
    }
    if (Bp.isMd()) {
      return base + 1;
    }
    return base;
  }

  /**
   * 内容最大宽度上限（vp）。
   * ★ 超宽屏上别让一行字横跨 1600vp —— 人眼读不了那么长的行。
   * 用法：容器 `.constraintSize({ maxWidth: Bp.maxContent() }).alignSelf(ItemAlign.Center)`
   */
  static maxContent(): number {
    if (Bp.dev === BpDev.TV) {
      return 1100;
    }
    return 760;
  }

  /** 横向边距（vp）：屏幕越大留白越多 */
  static padH(): number {
    if (Bp.isLg()) {
      return 32;
    }
    if (Bp.isMd()) {
      return 24;
    }
    return 16;
  }

  // ─────────── 圆屏安全区（手表专用）───────────
  /**
   * ★★★ 2026-10-29（项目 F 阶段 3）：圆屏安全区内边距
   *
   * 手表是**圆形**屏幕：四角会被切掉。内容要留在**内切正方形**里才不会被切。
   *   466px 圆屏 ⇒ 内切正方形边长 ≈ 466/√2 ≈ 330px
   *   ⇒ 每边要让出 (466-330)/2 ≈ 68px
   *
   * 用法（在页面根容器上）：
   *   .padding(Bp.isWatch() ? Bp.safePad() : 0)
   *
   * ⚠️ 非手表恒为 0 ⇒ 手机/平板/PC 零影响
   */
  static safePad(): number {
    if (!Bp.isWatch()) {
      return 0;
    }
    // 用实际宽度算，别写死 466（不同手表尺寸不同）
    // 内切正方形边长 = 宽 / √2 ⇒ 每边余量 = (宽 - 宽/√2) / 2
    const w: number = Bp.width > 0 ? Bp.width : 466;
    return Math.round((w - w / 1.4142) / 2);
  }

  /**
   * 手表上的「可用内容宽度」（内切正方形边长）。
   * 表格/棋盘类要用它限制最大宽度。
   */
  static safeWidth(): number {
    if (!Bp.isWatch()) {
      return Bp.width;
    }
    return Math.round(Bp.width / 1.4142);
  }

  // ─────────── 设备能力判断（给焦点导航、旋钮等分支用）───────────
  /** 有没有触摸 —— 智慧屏/手表通常没有 */
  static hasTouch(): boolean {
    return Bp.dev !== BpDev.TV;
  }

  /** 是不是手表（圆屏、极简布局） */
  static isWatch(): boolean {
    return Bp.dev === BpDev.WATCH;
  }

  /** 是不是电视（遥控器焦点导航） */
  static isTv(): boolean {
    return Bp.dev === BpDev.TV;
  }

  /** 是不是桌面类（鼠标 hover、窗口可缩放） */
  static isDesktop(): boolean {
    return Bp.dev === BpDev.PC;
  }
}
