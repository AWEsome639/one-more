/**
 * 界面模式（**长辈模式 / 简约模式**）—— 奥森 2026-10-13 09:0x 提议
 *
 * > 原话：「**我觉得可以加"长辈模式""简约模式"什么的？你看看，或者其他合适的模式也行**」
 *
 * ────────────────────────────────────────────────────────────
 * ★ 机理（和主题色 P5 同一套路）
 *
 * `FontSize / Space / Radius` 原本是 `static readonly` ⇒ **选完等于没选**（P5 踩过同样的坑）。
 * 现在改成**可写** ⇒ `UiMode.apply(mode)` 一键重写这些常量；
 * 再由 `Index.ets` 的 `@StorageProp('uiMode')` 触发**整树重建**
 * ⇒ 所有组件在 build() 里重新读常量 ⇒ **全局立刻跟着变**。
 *
 * ⚠️ 注意：**改的是模块级静态值** ⇒ 只在"重建"时生效，
 *    所以**必须有 `@StorageProp('uiMode')` 这个观察源**（否则界面不动）。
 */
import { FontSize, Space, Radius, Cell } from './Design';

/** 三种界面档位 */
export enum UiMode {
  /** 默认：现在这样 */
  NORMAL = 'normal',
  /** 长辈：字大、按钮大、间距宽、圆角柔和 */
  ELDER = 'elder',
  /** 简约：紧凑、字略小、圆角小（一屏看更多） */
  SIMPLE = 'simple',
}

/** 各档位的数值表 —— 想调手感只改这里 */
class Spec {
  hero: number = 36; xxxl: number = 28; xxl: number = 24; xl: number = 20;
  lg: number = 18; md: number = 16; sm: number = 14; xs: number = 13;
  xxs: number = 12; micro: number = 10; badge: number = 8;
  sxs: number = 6; ssm: number = 10; smd: number = 16; slg: number = 20;
  sxl: number = 28; sxxl: number = 32; sxxxl: number = 48;
  rxs: number = 8; rsm: number = 12; rmd: number = 16; rlg: number = 24;
  rxl: number = 32; rxxl: number = 40;
}

const NORMAL: Spec = new Spec();

/** 长辈模式：字号 +25%、间距 +40%、圆角更柔 */
function elder(): Spec {
  const s: Spec = new Spec();
  s.hero = 44; s.xxxl = 34; s.xxl = 30; s.xl = 26; s.lg = 24; s.md = 21;
  s.sm = 19; s.xs = 18; s.xxs = 17; s.micro = 15; s.badge = 12;
  s.sxs = 10; s.ssm = 16; s.smd = 24; s.slg = 30; s.sxl = 38; s.sxxl = 44; s.sxxxl = 60;
  s.rxs = 12; s.rsm = 16; s.rmd = 20; s.rlg = 28; s.rxl = 36; s.rxxl = 44;
  return s;
}

/** 简约模式：字号 -1、间距 -25%、圆角更小 */
function simple(): Spec {
  const s: Spec = new Spec();
  s.hero = 32; s.xxxl = 25; s.xxl = 21; s.xl = 18; s.lg = 16; s.md = 15;
  s.sm = 13; s.xs = 12; s.xxs = 11; s.micro = 9; s.badge = 8;
  s.sxs = 4; s.ssm = 7; s.smd = 12; s.slg = 15; s.sxl = 20; s.sxxl = 24; s.sxxxl = 36;
  s.rxs = 6; s.rsm = 8; s.rmd = 10; s.rlg = 14; s.rxl = 18; s.rxxl = 22;
  return s;
}

export class UiModeMgr {
  private static cur: string = UiMode.NORMAL;

  static current(): string {
    return UiModeMgr.cur;
  }

  /** 把某个档位的数值写进 Design 的常量（**调用后需要一次重建才可见**） */
  static apply(mode: string): void {
    let s: Spec = NORMAL;
    if (mode === UiMode.ELDER) {
      s = elder();
    } else if (mode === UiMode.SIMPLE) {
      s = simple();
    }
    UiModeMgr.cur = mode;

    FontSize.hero = s.hero; FontSize.xxxl = s.xxxl; FontSize.xxl = s.xxl;
    FontSize.xl = s.xl; FontSize.lg = s.lg; FontSize.md = s.md;
    FontSize.sm = s.sm; FontSize.xs = s.xs; FontSize.xxs = s.xxs;
    FontSize.micro = s.micro; FontSize.badge = s.badge;

    Space.xs = s.sxs; Space.sm = s.ssm; Space.md = s.smd; Space.lg = s.slg;
    Space.xl = s.sxl; Space.xxl = s.sxxl; Space.xxxl = s.sxxxl;

    Radius.xs = s.rxs; Radius.sm = s.rsm; Radius.md = s.rmd; Radius.lg = s.rlg;
    Radius.xl = s.rxl; Radius.xxl = s.rxxl;

    // ★★★ 2026-10-14：格子尺寸的缩放系数（游戏内 633 处固定高度靠它跟随模式）
    //   elder 字号 +30~42% ⇒ 格子 ×1.33；simple 字略小 ⇒ ×0.9
    if (mode === UiMode.ELDER) {
      Cell.k = 1.33;
    } else if (mode === UiMode.SIMPLE) {
      Cell.k = 0.9;
    } else {
      Cell.k = 1;
    }

    // ★ 写进 AppStorage ⇒ `@StorageProp('uiMode')` 的组件会重建
    AppStorage.setOrCreate('uiMode', mode);
  }

  /** 落盘（走工程既有的 preferences 通道 —— PersistentStorage 在本工程"只写不读"，见 I18n 的结论） */
  static save(mode: string): void {
    UiModeMgr.apply(mode);
    try {
      // 由 ProgressStore 统一写盘（它已持有 preferences 通道）
      AppStorage.setOrCreate('uiModePersist', mode);
    } catch (e) {
      // 落盘失败只影响"下次启动的记忆"，不影响本次切换
    }
  }

  /** 三种档位的显示名（十语言走 L()，这里给中文原文） */
  static labelOf(mode: string): string {
    if (mode === UiMode.ELDER) {
      return '大字模式';   // ★ 定名（2026-10-13 奥森：「长辈模式」不好听，换一个）
    }
    if (mode === UiMode.SIMPLE) {
      return '简约模式';
    }
    return '默认';
    // ⚠️ 想改档位名只改这里；三档：默认 / 大字 / 紧凑
  }

  /** ★★★ 2026-10-16 加：界面模式名的英文（供 this.t(zh, en) 用；原来只传中文两份） */
  static labelEnOf(mode: string): string {
    if (mode === UiMode.ELDER) {
      return 'Large text';
    }
    if (mode === UiMode.SIMPLE) {
      return 'Compact';
    }
    return 'Default';
  }

  /** ★★★ 2026-10-16 加：界面模式说明的英文 */
  static descEnOf(mode: string): string {
    if (mode === UiMode.ELDER) {
      return 'Bigger text, buttons and spacing';
    }
    if (mode === UiMode.SIMPLE) {
      return 'Tighter — more per screen';
    }
    // ★ 2026-10-19 修：原来 'As it is now' 是相对说法，切走之后就成了假话
    return 'Standard text & spacing';
  }

  static descOf(mode: string): string {
    if (mode === UiMode.ELDER) {
      return '字更大、按钮更大、间距更宽';
    }
    if (mode === UiMode.SIMPLE) {
      return '更紧凑，一屏看更多';
    // 注意：ZHTW/外语下这两个串会走 I18n 的 L()，见 SettingsTab 调用处
    }
    // ★ 2026-10-19 修：绝对描述（原「现在的样子」= 相对说法，切走即失真）
    return '标准字号与间距';
  }

  /** 给 UI 遍历用 */
  static all(): string[] {
    return [UiMode.NORMAL, UiMode.ELDER, UiMode.SIMPLE];
  }
}
