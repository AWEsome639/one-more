/**
 * 难度对游戏玩法的作用 —— 354 款游戏共用的换算入口
 *
 * 为什么单独抽一层：
 *   游戏里的时限/棋盘/生命数是**模块级常量**（如 `const TIME_LIMIT = 60`），
 *   模块加载时就算死了 ⇒ 玩家中途改难度**不会重算**。
 *   ⇒ 游戏要取"本局实际用多少"，必须**在组件构造时调一次**这里的方法。
 *
 * 用法（游戏里）：
 *   @State private left: number = GameDiff.time(this.gameId, TIME_LIMIT);
 *   private total: number = GameDiff.time(this.gameId, TIME_LIMIT);   // 进度条分母用这个
 *   ⚠️ 别再用 TIME_LIMIT 当分母 —— 简单档时间更长，会算出 >100%
 *
 * 三档的语义（奥森 2026-10-11 要求）：
 *   简单 —— 时间更宽（×1.5）、数量更少（×0.7）、XP ×0.8
 *   普通 —— 一切照旧（×1.0）
 *   困难 —— 时间更紧（×0.7）、数量更多（×1.3）、XP ×1.4
 */

import { ProgressStore } from './ProgressStore';

export class GameDiff {
  /**
   * 当前正在玩的游戏 id —— 由 GameHost 在加载时写入。
   *
   * 为什么不给每个游戏传 gameId 属性：
   *   354 个游戏组件的入参是统一的 `{ theme, restartToken, onFinish }`，
   *   加一个参数要改 354 个文件的签名 + 生成器的 354 处调用。
   *   而"同一时刻只有一个游戏在玩" ⇒ 一个静态值就够了，**零侵入**。
   */
  private static cur: string = '';

  /** GameHost 加载游戏时调一次 */
  static enter(gameId: string): void {
    GameDiff.cur = gameId;
  }

  /** 当前游戏 id（游戏组件内部不用自己传） */
  static gameId(): string {
    return GameDiff.cur;
  }

  /** 玩家选的档：0 简单 / 1 普通 / 2 困难 */
  static of(gameId: string): number {
    return ProgressStore.diffOf(gameId);
  }

  /** 当前游戏的档 */
  static now(): number {
    return ProgressStore.diffOf(GameDiff.cur);
  }

  /** 时间倍率：简单更长、困难更短 */
  static timeScale(gameId: string): number {
    const d: number = GameDiff.of(gameId.length > 0 ? gameId : GameDiff.cur);
    if (d === 0) {
      return 1.5;
    }
    if (d === 2) {
      return 0.7;
    }
    return 1.0;
  }

  /** 数量倍率：简单更少、困难更多（棋盘、题数、目标分…） */
  static sizeScale(gameId: string): number {
    const d: number = GameDiff.of(gameId.length > 0 ? gameId : GameDiff.cur);
    if (d === 0) {
      return 0.7;
    }
    if (d === 2) {
      return 1.3;
    }
    return 1.0;
  }

  /**
   * 运行时自证日志：`gameId|基础值|实际值|难度`，逗号分隔
   * 设置页读它显示，用来一屏核对"哪些游戏的难度真的生效了"
   */
  private static log(gameId: string, base: number, got: number, diff: number): void {
    if (gameId.length === 0) {
      return;
    }
    const line: string = gameId + '|' + base + '|' + got + '|' + diff;
    const raw: string = AppStorage.get<string>('diffLog') ?? '';
    const lines: string[] = raw.length === 0 ? [] : raw.split(';');
    // 同一款只留最新一条
    const out: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].length > 0 && lines[i].split('|')[0] !== gameId) {
        out.push(lines[i]);
      }
    }
    out.push(line);
    // 最多留 400 条
    while (out.length > 400) {
      out.shift();
    }
    AppStorage.setOrCreate('diffLog', out.join(';'));
  }

  /** 读自证日志（设置页用） */
  static readLog(): string[] {
    const raw: string = AppStorage.get<string>('diffLog') ?? '';
    return raw.length === 0 ? [] : raw.split(';');
  }

  /** 把基础秒数换算成本局秒数（至少 10 秒，免得困难档短到没法玩） */
  static time(gameId: string, base: number): number {
    const v: number = Math.round(base * GameDiff.timeScale(gameId));
    return v < 10 ? 10 : v;
  }

  /** 把基础数量换算成本局数量（至少 1） */
  static size(gameId: string, base: number): number {
    const v: number = Math.round(base * GameDiff.sizeScale(gameId));
    return v < 1 ? 1 : v;
  }

  /**
   * 便捷：不用传 id（用当前游戏）
   *
   * ★ 每次调用都**记一笔**（gameId / 基础值 / 实际算出的值 / 当时的难度）。
   *   为什么：354 款游戏里"难度到底有没有生效"，靠 UI 导航逐个点进去验**极不可靠**
   *   （面板展开会推挤卡片、Grid 虚拟化让远端的项查不到）。
   *   改成运行时自证：只要进过这款游戏，这里就有记录，在设置页一屏看完。
   */
  static timeNow(base: number): number {
    const d: number = ProgressStore.diffOf(GameDiff.cur);
    const v: number = GameDiff.time(GameDiff.cur, base);
    GameDiff.log(GameDiff.cur, base, v, d);
    return v;
  }

  static sizeNow(base: number): number {
    // ★ 也记一笔 —— 自证页要能看到"棋盘/数量"这一维度的难度是否生效
    const d: number = ProgressStore.diffOf(GameDiff.cur);
    const v: number = GameDiff.size(GameDiff.cur, base);
    GameDiff.log(GameDiff.cur, base, v, d);
    return v;
  }

  static livesNow(base: number): number {
    // ★ 也记一笔 —— 自证页要能看到"次数/容错"这一维度的难度是否生效
    const d: number = ProgressStore.diffOf(GameDiff.cur);
    const v: number = GameDiff.lives(GameDiff.cur, base);
    GameDiff.log(GameDiff.cur, base, v, d);
    return v;
  }

  /**
   * 三档各给一个**明确的值**（手工设计难度时用）
   *
   * ★ 为什么不能都用倍率：有些量**必须是特定值**，倍率算出来的数没有意义。
   *   例：2048 的胜利条件是「棋盘上出现 2048 这个方块」，用 ×0.7 算出 1434
   *   —— 那不是一个合法方块，**简单档就永远赢不了**。
   *   ⇒ 这种情况用 pick(1024, 2048, 4096)。
   */
  static pick(easy: number, normal: number, hard: number): number {
    const d: number = ProgressStore.diffOf(GameDiff.cur);
    if (d === 0) {
      return easy;
    }
    if (d === 2) {
      return hard;
    }
    return normal;
  }

  /** 生命 / 步数这类"容错次数"：简单更多、困难更少 */
  static lives(gameId: string, base: number): number {
    const d: number = GameDiff.of(gameId.length > 0 ? gameId : GameDiff.cur);
    let v: number = base;
    if (d === 0) {
      v = Math.ceil(base * 1.5);
    } else if (d === 2) {
      v = Math.max(1, Math.floor(base * 0.6));
    }
    return v < 1 ? 1 : v;
  }
}
