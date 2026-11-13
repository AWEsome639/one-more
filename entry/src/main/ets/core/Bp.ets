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
  /**
   * 是不是「矮屏」（纵向空间不够）—— 智慧屏/横放的平板/PC 窗口。
   *
   * ★★★ 2026-10-29（六设备实测抓到）：智慧屏 1920×1080 @320dpi ⇒ **只 540vp 高**。
   *   首页的「今天这一局」+「随机来一局」+ 分类芯片 吃掉了整整 800px，
   *   **游戏列表一张卡都露不出来，而且整页不滚动** ⇒ 电视上根本开不了游戏。
   *   ⇒ 矮屏时把这两块收起，把纵向空间让给列表。
   *
   * 判据用 620vp：手机竖屏 744~812vp 不受影响；
   *   电视 540 / 横放平板 800 中的矮一档 / 小窗 PC 会命中。
   */
  /**
   * 是不是「极小的手表」（运动手表 195vp 这类）。
   * ★ 2026-10-29（六设备实测）：195×195 vp 上手卡的 48vp 图标 + 标题放不下，
   *   标题被截成「宝...」⇒ 极小屏藏图标、标题降字号且允许两行。
   */
  static tinyWatch(): boolean {
    // ★ 2026-10-29：**只按尺寸判断，不依赖 deviceType。**
    //   理由：195vp 的屏不管是什么设备，48vp 图标 + 标题就是放不下；
    //   而 deviceType 在模拟器上永远报 "phone"，靠它会导致这条分支测不到。
    //   ⇒ 「屏幕小到用不了常规卡片」= 紧凑布局，与设备类型无关。
    return Bp.height > 0 && Bp.height < 210;
  }

  /**
   * 极小屏（高 < 340vp）。
   * ★★★ 2026-10-29（奥森提醒）：「显示大小可以变得很小啊」
   *   ⇒ 不只是手表 —— **手机把「显示大小」调到最小，vp 也会变得很小**，
   *     那时顶栏 + LV 条 + 分类芯片 + 页签 会把列表整片挤没。
   *   ⇒ 极小屏只留「标题 + 列表」，其余全部收起。
   *   ★ 与设备类型无关（只看尺寸）：小就是小。
   */
  static tinyScreen(): boolean {
    return Bp.height > 0 && Bp.height < 340;
  }

  /**
   * ★★★ 2026-11-02（第 853-854 轮）：**窄屏**（高 < 420 或 宽 < 420）。
   *
   * 为什么单独抽出来：
   *   `DemoBar` 与 `GameHost` 两个文件**各自**写了一遍
   *   `Bp.height < 420 || Bp.width < 420`（方法名还不一样：`tiny()` / `tinyScreen()`），
   *   而 `Bp.tinyScreen()` 的阈值是 **340** ⇒ 两套阈值并存，
   *   在 **360~420** 之间会给出相反结论。
   *
   * ⇒ 统一到这里：需要"低于 420 就收紧"的地方一律调 `Bp.narrowScreen()`。
   *   ⚠️ 它与 `tinyScreen()` **不是同一个概念**：
   *      · `tinyScreen()`  < 340 ⇒ 只留「标题 + 列表」（更激进的降级）
   *      · `narrowScreen()` ⇒ 收紧字号/间距（温和降级）
   *
   * ★ 2026-11-08（第 X 轮）：**宽度阈值 420 → 460**（高度阈值**保持 420 不动**）。
   *   来历：440×956 竖屏手机落在「两头不靠」区间 ——
   *     `tinyWatch`(h<210) ✗ ｜ `tinyScreen`(h<340) ✗ ｜ 原来 `narrowScreen`(w<420) ✗
   *   ⇒ 它既不窄屏也不算小屏，走「正常大屏」路径，但只有 440 宽：
   *     顶栏 5 个按钮（‹ ☆ ? 普通 ↻）挤、结算弹窗字号大、演示条文案要 2 行。
   *   竖屏垂直余量实测只有 ~35vp（chrome≈240 + 盘≤596 + 底 85 ≈ 921/956）
   *   ⇒ 把「收紧间距/字号/文案」提前到 460，能实打实多出 30~60vp，且**只动 chrome、不碰棋盘**。
   *
   *   ⚠️ **为什么只改宽度、不改高度**（lead 2026-11-08 指正）：
   *     高度维度已经有 `tinyWatch`(<210) / `tinyScreen`(<340) / `narrowHeight`(<420) 三级判据，
   *     手表与矮屏**本来就该走那几条**；把 height 也抬到 460 会让「420~460 高」的设备
   *     误走窄屏而不是手表/矮屏分支 ⇒ **只把宽度 420 → 460**。
   */
  static narrowScreen(): boolean {
    return Bp.height < 420 || Bp.width < 460;
  }

  /**
   * ★ 2026-11-08：**是否隐藏「☆ 收藏」**（顶栏那个星标）。
   *
   * 为什么与 `narrowScreen()` 分开（判据：**收紧间距 = 视觉变化，隐藏控件 = 不可逆体验损失**）：
   *   · 440 宽的竖屏手机上，顶栏 5 个按钮（‹ ☆ ? 普通 ↻ ≈ 200vp）**放得下** ⇒ 不该隐藏收藏；
   *   · 真正放不下的是 195 手表（5 个按钮 200vp > 195）⇒ 才隐藏 ☆。
   *   （`?` 帮助**任何尺寸都不隐藏** —— 2026-11-02 手表真机教训：腕上最需要「怎么看」）
   */
  static hideFav(): boolean {
    return Bp.width > 0 && Bp.width < 300;
  }

  /**
   * ★ 2026-11-08：**是否隐藏游戏页顶栏的「标题 + 副标题」**。
   *
   * 与 `hideFav()` 同一条来历：原来这两处都挂在 `tinyScreen()` 上，
   * 而 `tinyScreen()` 的判定是「高 < 340」（手表 195×195 才该命中）——
   * 但 `tinyScreen()` 里用的是 `Bp.narrowScreen()`（现在是宽 < 460）
   * ⇒ 440 宽竖屏手机**会跟着把标题藏掉**，而 440×956 的顶栏完全放得下标题。
   *
   * 判据同 `hideFav()`：**收紧间距 = 视觉变化；隐藏内容 = 不可逆损失**。
   * 只有 195 手表那种「顶栏 44 + 演示条 38 吃掉 109vp，内容区只剩 86vp」才该藏。
   */
  static hideGameTitle(): boolean {
    return Bp.width > 0 && Bp.width < 300;
  }

  /**
   * ★ 2026-11-02（第 854 轮）：**只看高度**的窄判据（高 < 420）。
   *
   * 为什么单独一个：`DemoBar` 的演示条高度、`GameHost` 的图标尺寸
   * 都写成了裸的 `Bp.height < 420 ? A : B` —— 只看高度是有道理的
   * （这两个量只跟垂直空间有关），但**裸写会让人以为它等于 narrowScreen()**。
   * ⇒ 抽出来，让"我只关心高度"这件事显式。
   */
  static narrowHeight(): boolean {
    return Bp.height < 420;
  }

  static isShort(): boolean {
    // ★★★ 2026-11-03（第 935 轮）**620 → 690**：620 太宽容，
    //   620 高的屏上"展开态"需要 482vp（顶栏+LV+筛选+今日+随机+页签+分类+计数）
    //   + 标签栏 60 + 至少 1 行卡 142 = **684vp** ⇒ 620 上**一张卡都放不下**（既有 bug）。
    //   ⇒ 690 以下一律进"收起态"，把空间让给列表。
    //   ⚠️ 744（真实手机竖屏）仍 ≥ 690 ⇒ 保持展开态不变。
    // ★★★ 2026-11-13（队友静态分析）：**电视不该进「矮屏」分支** ——
    //   1080p 电视 @dens2.0 ⇒ px2vp(1080)=540vp ⇒ 原来会判成矮屏，
    //   于是隐藏说明行、棋盘封顶、`Cell.of ×0.85` 全套「矮屏减法」都在电视上生效
    //   ⇒ 越修越小，而 10-foot UI 恰恰相反（3 米视距需要更大）
    return Bp.height < 690 && !Bp.isTv();
  }

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
