import { curves } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
/**
 * 设计系统 —— 全app唯一的视觉真相源
 *
 * 对标 sidhant947/Puzzle 的「体验数值」（字号阶梯／间距网格／圆角／色板／缓动时长），
 * 代码与命名 100% 自写，不抄其任何源码。
 *
 * 铁律：
 *  ① 组件里**不许出现魔法数字** —— 字号/间距/圆角一律引用这里
 *  ② 深色走 AMOLED（纯黑省电、对比强）
 *
 * ★ 2026-10-13 主题色（P5 · 奥森真机：「主题色好像也不会变」）：
 *   事故：主题色只写进 AppStorage 'accent'，而全项目真正着色用的是 `Palette.primary`
 *   这个**静态只读常量** ⇒ 选色只让设置页那几个色块变，别的页面一动不动。
 *   现在：`Palette.primary / primaryDeep` 变成**可跟随的变量**，由 `Accent.set()` 统一改写，
 *   全项目 300+ 处 `Palette.primary` 一处不用改就跟着走。
 *   ⚠️ 想让**当前这一帧立刻**变色的组件，自己要有观察源：加一行
 *      `@StorageProp('accent') accent: string = Palette.primary;` 并在 build 里读一次。
 */

/** 字号阶梯 */
export class FontSize {
  static hero: number = 36;
  static xxxl: number = 28;
  static xxl: number = 24;
  static xl: number = 20;
  static lg: number = 18;
  static md: number = 16;   // 正文基准
  static sm: number = 14;
  static xs: number = 13;
  static xxs: number = 12;
  static micro: number = 10;   // 徽标／角标这类极小字
  static badge: number = 8;    // LV 圈里那两行
}

/** 间距网格 —— 严格遵守，这是"优美"的骨架 */
export class Space {
  static xs: number = 6;
  static sm: number = 10;
  static md: number = 16;
  static lg: number = 20;
  static xl: number = 28;
  static xxl: number = 32;
  static xxxl: number = 48;
}

/** 圆角 */
/**
 * ★★★ 2026-10-14 新增：可缩放的【格子尺寸】
 *   起因：奥森要我注意"模式（大字/紧凑）后的界面"。
 *   查出：UiMode 的 elder 档把字号放大 30~42%，而游戏里有 633 处【写死的格子高度】
 *        （如 .height(44) 里放 FontSize.lg，elder 下字号变 24 ⇒ 会裁字）。
 *   ⇒ 用法：把字面量包一层 —— `.height(Cell.of(44))`
 *      normal ×1.0 ｜ elder ×1.33 ｜ simple ×0.9
 *   ⚠️ 只对"装文字的格子"用；纯装饰尺寸不要套（否则会无端变大）
 */
export class Cell {
  /** 缩放系数：由 UiMode.apply() 写入 */
  static k: number = 1;

  /** 把一个原始尺寸按当前模式缩放（取整，避免半像素） */
  static of(base: number): number {
    return Math.round(base * Cell.k);
  }
}

export class Radius {
  static xs: number = 8;
  static sm: number = 12;
  static md: number = 16;
  static lg: number = 24;
  static xl: number = 32;
  static xxl: number = 40;
  static full: number = 999;
}

/** 色板 —— 浅色/深色两套 */
export class Palette {
  // 品牌
  /**
   * ★ 当前主题色 —— 由 `Accent.set()` 改写，全项目 300+ 处直接读它
   *   （以前是 `static readonly`，所以选色改不动界面 —— P5 的根因）
   */
  static primary: string = '#6366F1';
  /** 主题色的深色版（按下态、强调边），随 primary 一起派生 */
  static primaryDeep: string = '#4F46E5';
  static readonly berry: string = '#EC4899';
  static readonly emerald: string = '#10B981';
  static readonly amber: string = '#F59E0B';
  static readonly teal: string = '#0D9488';
  static readonly violet: string = '#8B5CF6';
  static readonly sky: string = '#0EA5E9';
  static readonly rose: string = '#F43F5E';
  static readonly lime: string = '#84CC16';
  static readonly orange: string = '#F97316';
  static readonly cyan: string = '#06B6D4';

  // 语义
  static readonly success: string = '#10B981';
  static readonly danger: string = '#EF4444';
  static readonly warning: string = '#F59E0B';

  // 浅色主题
  static readonly bg: string = '#F8FAFC';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceAlt: string = '#FCFBF4';
  static readonly ink: string = '#0F172A';
  static readonly inkSoft: string = '#334155';
  static readonly inkFaint: string = '#64748B';
  static readonly line: string = '#E2E8F0';
  static readonly lineSoft: string = '#CBD5E1';

  // 深色主题（AMOLED）
  static readonly dBg: string = '#000000';
  static readonly dSurface: string = '#141414';
  static readonly dSurfaceAlt: string = '#1E1E1E';
  static readonly dInk: string = '#F8FAFC';
  static readonly dInkSoft: string = '#94A3B8';
  static readonly dInkFaint: string = '#64748B';
  static readonly dLine: string = '#2D2D2D';
  static readonly dLineSoft: string = '#3A3A3A';

  /** 12 色卡片轮转色（游戏卡用，保证网格有节奏感） */
  static readonly wheel: string[] = [
    '#6366F1', '#EC4899', '#10B981', '#F59E0B',
    '#0D9488', '#8B5CF6', '#0EA5E9', '#F43F5E',
    '#84CC16', '#F97316', '#06B6D4', '#A855F7'
  ];
}

/** 主题色候选（给设置页选择器用） */
export interface AccentOption {
  /** 落盘 id：'system' 或 '#RRGGBB' */
  id: string;
  /** 中文名（走 I18n 字典，别写死） */
  zh: string;
  /** 英文名（字典缺项时兜底） */
  en: string;
  /** 色块的展示色；'system' 用系统品牌色的兜底值，真值由 color() 解析 */
  hex: string;
  /** 是不是"跟随系统" */
  isSystem: boolean;
}

/**
 * 主题色引擎 —— 12 档：跟随系统 ＋ 靛蓝（默认）＋ 彩虹 7 档 ＋ 品红/天蓝/石墨
 *
 * 用法（组件里）：
 *   `Palette.primary`            → 当前主题色（画什么就用它，别写死 #6366F1）
 *   `Accent.set(id)`             → 用户点色块时调它（写 AppStorage + 改写 Palette）
 *   `Accent.options`             → 选择器遍历这个列表
 *   `this.t(o.zh, o.en)`         → 取色名（12 语言）
 */
export class Accent {
  /** "跟随系统"的 id */
  static readonly SYSTEM: string = 'system';
  /** 取不到系统品牌色时的兜底 —— HarmonyOS 默认品牌蓝 */
  static readonly SYSTEM_FALLBACK: string = '#0A59F7';
  /** 默认主题色（靛蓝） */
  static readonly DEFAULT: string = '#6366F1';

  /** 选择器顺序：跟随系统 → 默认靛蓝 → 彩虹 7 档 → 品红/天蓝/石墨 */
  static readonly options: AccentOption[] = [
    { id: Accent.SYSTEM, zh: '跟随系统', en: 'System', hex: Accent.SYSTEM_FALLBACK, isSystem: true },
    { id: '#6366F1', zh: '靛蓝', en: 'Indigo', hex: '#6366F1', isSystem: false },
    { id: '#EF4444', zh: '红', en: 'Red', hex: '#EF4444', isSystem: false },
    { id: '#F97316', zh: '橙', en: 'Orange', hex: '#F97316', isSystem: false },
    { id: '#EAB308', zh: '黄', en: 'Yellow', hex: '#EAB308', isSystem: false },
    { id: '#10B981', zh: '绿', en: 'Green', hex: '#10B981', isSystem: false },
    { id: '#06B6D4', zh: '青', en: 'Cyan', hex: '#06B6D4', isSystem: false },
    { id: '#3B82F6', zh: '蓝', en: 'Blue', hex: '#3B82F6', isSystem: false },
    { id: '#8B5CF6', zh: '紫', en: 'Purple', hex: '#8B5CF6', isSystem: false },
    { id: '#EC4899', zh: '品红', en: 'Magenta', hex: '#EC4899', isSystem: false },
    { id: '#0EA5E9', zh: '天蓝', en: 'Sky', hex: '#0EA5E9', isSystem: false },
    { id: '#64748B', zh: '石墨', en: 'Graphite', hex: '#64748B', isSystem: false },
  ];

  private static sysCache: string = '';
  private static persistTried: boolean = false;

  /** 当前选择（'system' 或 '#RRGGBB'）；读不到就是默认靛蓝 */
  static currentId(): string {
    try {
      const v: string | undefined = AppStorage.get<string>('accent');
      if (v !== undefined && v.length > 0) {
        return v;
      }
    } catch (e) {
      // AppStorage 还没起来 —— 用默认值
    }
    return Accent.DEFAULT;
  }

  /** 某个 id 实际该画的颜色（'system' 会去读系统品牌色） */
  static color(id: string): string {
    if (id === Accent.SYSTEM) {
      return Accent.systemColor();
    }
    return (id.length === 7 && id.charAt(0) === '#') ? id : Accent.DEFAULT;
  }

  /** 把主题色写进 Palette（全项目所有 `Palette.primary` 立刻读到新值） */
  static apply(id: string): void {
    const hex: string = Accent.color(id);
    Palette.primary = hex;
    Palette.primaryDeep = Accent.deep(hex);
  }

  /** 用户点色块：落盘 + 生效（一条路走完，别再各写各的） */
  static set(id: string): void {
    AppStorage.setOrCreate('accent', id);
    Accent.apply(id);
  }

  /**
   * 启动/回到页面时把磁盘上的选择接回来。
   * ⚠️ 只在模块加载时自动调一次；组件里不必重复调（重复调也幂等）。
   */
  static sync(): void {
    // ★ 2026-10-13 模拟器实测：PersistentStorage 在本工程**只写不读**（见 I18n.initPersist 注释），
    //   主题色落盘同样改走 ProgressStore 的 preferences 通道（saveAccent / init 里恢复）。
    if (!Accent.persistTried) {
      Accent.persistTried = true;
    }
    Accent.apply(Accent.currentId());
  }

  /** 系统品牌色（sys.color.brand）→ '#RRGGBB'；读不到退 HarmonyOS 品牌蓝 */
  static systemColor(): string {
    if (Accent.sysCache.length > 0) {
      return Accent.sysCache;
    }
    let c: string = Accent.SYSTEM_FALLBACK;
    try {
      const rm: resourceManager.ResourceManager = resourceManager.getSystemResourceManager();
      const v: number = rm.getColorByNameSync('brand');
      if (v !== 0) {
        c = Accent.argb(v);
      }
    } catch (e) {
      c = Accent.SYSTEM_FALLBACK;   // 系统色拿不到就用品牌蓝，绝不空着
    }
    Accent.sysCache = c;
    return c;
  }

  /** 派生深色（按下态用）：RGB 各乘 0.84 */
  static deep(hex: string): string {
    if (hex.length !== 7 || hex.charAt(0) !== '#') {
      return Palette.primaryDeep;
    }
    const r: number = Math.round(Number.parseInt(hex.substring(1, 3), 16) * 0.84);
    const g: number = Math.round(Number.parseInt(hex.substring(3, 5), 16) * 0.84);
    const b: number = Math.round(Number.parseInt(hex.substring(5, 7), 16) * 0.84);
    return '#' + Accent.pad2(r) + Accent.pad2(g) + Accent.pad2(b);
  }

  private static pad2(n: number): string {
    const s: string = n.toString(16).toUpperCase();
    return s.length >= 2 ? s : '0' + s;
  }

  /** 0xAARRGGBB → '#RRGGBB' */
  private static argb(v: number): string {
    const r: number = (v >> 16) & 0xFF;
    const g: number = (v >> 8) & 0xFF;
    const b: number = v & 0xFF;
    return '#' + Accent.pad2(r) + Accent.pad2(g) + Accent.pad2(b);
  }
}

/** 动效 —— "流畅"从这来：一律 160~260ms，超过 300 就"拖" */
export class Motion {
  // ── 时长 ──
  static readonly fast: number = 180;
  static readonly base: number = 260;
  static readonly slow: number = 320;
  static readonly sheet: number = 380;

  // ── 曲线 ──
  /**
   * ★ 弹簧曲线（物理动效）—— 比 Curve.EaseOut 自然得多：
   *   ① springMotion：通用弹性，收尾有轻微回弹，「活」但不飘
   *   ② responsiveSpringMotion：跟手响应，用于拖拽/按压
   *   ③ interactiveSpringMotion：交互式，用于面板展开收起
   *
   * 用法：.animation({ duration: Motion.base, curve: Motion.spring() })
   * ⚠️ 弹簧曲线对 duration 的敏感度低于缓动曲线 —— 改时长主要是改"感觉上的快慢"
   */
  static spring(response: number = 0.35, damping: number = 0.82): ICurve {
    return curves.springMotion(response, damping);
  }

  /**
   * 小元件专用：**干脆的弹簧**（格子、芯片、小图标的高亮/选中）
   *
   * ★ 为什么不能直接用 spring()：那个 response=0.35 偏"软"，
   *   小元件上会显得**晃**；这里 0.22 + 阻尼 0.9 ⇒ 快、稳、收尾有极小回弹
   *   —— 就是俗称的"Q弹"：**弹一下立刻停住**。
   */
  static snap(): ICurve {
    return curves.springMotion(0.22, 0.9);
  }

  /** 跟手响应（按压、拖拽）—— 系统推荐保留默认值 */
  static responsive(): ICurve {
    return curves.responsiveSpringMotion();
  }

  /** 面板展开/收起、弹窗 —— 响应快一点、回弹少一点，避免"晃" */
  static sheetCurve(): ICurve {
    return curves.springMotion(0.28, 0.9);
  }

  /** 进入：略慢、略有回弹，显得"活" */
  static enter(): ICurve {
    return curves.springMotion(0.42, 0.78);
  }

  /** 退出：快、几乎不回弹 —— 退场拖泥带水最难看 */
  static exit(): ICurve {
    return curves.springMotion(0.24, 0.98);
  }

  /** 列表交错进场：第 n 项延迟 n×40ms，封顶 400 */
  static stagger(index: number): number {
    const d: number = index * 40;
    return d > 400 ? 400 : d;
  }

  /** 按下反馈缩放 */
  static readonly pressScale: number = 0.96;

  /** 断点 */
  static readonly breakpointMobile: number = 600;
  static readonly breakpointTablet: number = 1024;
}

/** 主题包：把"当前该用哪套颜色"收成一个对象，组件只认它 */
/** 彩色底上的白色叠加层 —— 别在组件里硬写 '#CCFFFFFF' 这类值 */
export class Overlay {
  /** 主文字（彩色卡上的白字） */
  static readonly onColor: string = '#FFFFFF';
  /** 次级文字 */
  static readonly onColorSoft: string = '#CCFFFFFF';
  /** 极淡（标签、说明） */
  static readonly onColorFaint: string = '#B3FFFFFF';
  /** 底色块（按钮、圆章） */
  static readonly chip: string = '#33FFFFFF';
  /** 更淡的底 */
  static readonly chipSoft: string = '#1AFFFFFF';
  /** 浮层遮罩（底部提示条） */
  static readonly scrim: string = '#E6000000';
}

/** 无障碍与尺寸下限 */
export class Layout {
  /** 可点区域最小边长（vp）—— 小于这个值手指点不准 */
  static readonly touchMin: number = 44;
  /** 进度条这类细线的高度 */
  static readonly hairline: number = 3;
}

export class Theme {
  readonly isDark: boolean;
  readonly bg: string;
  readonly surface: string;
  readonly surfaceAlt: string;
  readonly ink: string;
  readonly inkSoft: string;
  readonly inkFaint: string;
  readonly line: string;
  readonly lineSoft: string;

  constructor(isDark: boolean) {
    this.isDark = isDark;
    this.bg = isDark ? Palette.dBg : Palette.bg;
    this.surface = isDark ? Palette.dSurface : Palette.surface;
    this.surfaceAlt = isDark ? Palette.dSurfaceAlt : Palette.surfaceAlt;
    this.ink = isDark ? Palette.dInk : Palette.ink;
    this.inkSoft = isDark ? Palette.dInkSoft : Palette.inkSoft;
    this.inkFaint = isDark ? Palette.dInkFaint : Palette.inkFaint;
    this.line = isDark ? Palette.dLine : Palette.line;
    this.lineSoft = isDark ? Palette.dLineSoft : Palette.lineSoft;
  }

  static light(): Theme {
    return new Theme(false);
  }

  static dark(): Theme {
    return new Theme(true);
  }
}

/** 常用组合样式（省得每个组件重复写） */
export class Shadow {
  static readonly card: ShadowOptions = {
    radius: 16,
    color: '#14000000',
    offsetX: 0,
    offsetY: 4
  };
  static readonly lifted: ShadowOptions = {
    radius: 24,
    color: '#1F000000',
    offsetX: 0,
    offsetY: 8
  };
}

/**
 * 模块加载即把磁盘上的主题色接回来 —— 必须在任何组件读 `Palette.primary` 之前跑完。
 * 拿不到持久化能力时自动退回默认靛蓝（`Accent.sync()` 内部已经兜住）。
 */
function initAccent(): void {
  Accent.sync();
}

initAccent();
