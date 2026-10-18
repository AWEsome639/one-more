/**
 * 局域网对局核心 —— 把「一局」的局域网协议接进具体游戏
 *
 * 设计（刻意做到**对游戏本体零侵入**）：
 *   井字棋 / 四子棋 / 黑白棋 / 尼姆 都是**确定性游戏** ——
 *   给定同一串落子序列，两边棋盘必然一致。
 *   ⇒ 不需要同步整个棋盘，**只同步"谁在第几手落在哪"**就够了。
 *
 * 流程：
 *   1. 大厅里连上后，双方约定谁是先手（房主固定先手）
 *   2. 落子时调 `LanMatch.record(...)` —— 记进本局历史并发给对方
 *   3. 收到对方的落子 ⇒ `LanMatch.onRemote` 回调 ⇒ 游戏把它当成"对方点的那一步"应用
 *   4. 轮次由 `LanMatch.myTurn()` 判断；不是自己回合就不接受本地点击
 *
 * 为什么单列一层：
 *   网络层（`Lan.ets`）只管收发字节；**回合制规则**属于游戏，但四款游戏共用同一套，
 *   抽出来避免在 4 个文件里各写一遍。
 *
 * 拾海 2026-10-11
 */

import { Lan, LanMsg } from './Lan';
import { ProgressStore } from './ProgressStore';
import { Haptics } from './Haptics';

/** 一方 */
export enum Side {
  NONE = 0,
  HOST = 1,   // 房主（先手）
  GUEST = 2   // 加入方（后手）
}

export class LanMatch {
  /** 是否在联机对局中 */
  private static active: boolean = false;
  /** 我是哪一方 */
  private static me: Side = Side.NONE;
  /** 当前轮到谁 */
  private static turn: Side = Side.HOST;
  /** 本局落子历史（"谁:数据"），用来重开时对齐 */
  private static history: string[] = [];
  /** 收到对方落子时的回调 —— 由游戏注册 */
  private static onRemote: (d: string) => void = () => {};
  /** 本局玩的是哪一款（同步难度要用） */
  private static gameId: string = '';

  /**
   * 单独注册"收到对方落子"的回调
   * ★ 为什么需要：`begin()` 是在**大厅**调的，而回调属于**游戏组件** ——
   *   游戏在 `aboutToAppear` 里用这个方法把自己接上。
   */
  static setHandler(onRemote: (d: string) => void): void {
    LanMatch.onRemote = onRemote;
  }

  /** 开局：房主调 host=true */
  static begin(isHost: boolean, onRemote: (d: string) => void, gameId: string = ''): void {
    LanMatch.active = true;
    LanMatch.gameId = gameId;
    LanMatch.me = isHost ? Side.HOST : Side.GUEST;
    LanMatch.turn = Side.HOST;          // 房主先手
    LanMatch.history = [];
    LanMatch.onRemote = onRemote;
  }

  /** 结束联机对局 */
  static end(): void {
    LanMatch.active = false;
    LanMatch.me = Side.NONE;
    LanMatch.turn = Side.HOST;
    LanMatch.history = [];
    LanMatch.onRemote = () => {};
  }

  static isActive(): boolean {
    return LanMatch.active;
  }

  static mySide(): Side {
    return LanMatch.me;
  }

  /** 现在是不是我的回合？ */
  static myTurn(): boolean {
    return LanMatch.active && LanMatch.turn === LanMatch.me;
  }

  /**
   * 我落了一子 —— 记下来并发给对方，然后换手
   * @param d 这一步的载荷（各游戏自定义，如 "4" 表示第 4 格）
   */
  static record(d: string): void {
    if (!LanMatch.active) {
      return;
    }
    LanMatch.history.push('m:' + d);
    LanMatch.turn = LanMatch.turn === Side.HOST ? Side.GUEST : Side.HOST;
    Lan.send({ t: 'move', d: d });
    Haptics.tap();
  }

  /** 收到网络消息时由 Lan 的回调转发进来 */
  static receive(m: LanMsg): void {
    if (!LanMatch.active) {
      return;
    }
    if (m.t === 'move') {
      LanMatch.history.push('r:' + m.d);
      LanMatch.turn = LanMatch.turn === Side.HOST ? Side.GUEST : Side.HOST;
      LanMatch.onRemote(m.d);          // 交给游戏去应用这一步
      Haptics.tap();
    } else if (m.t === 'diff') {
      // ★ 房主把难度广播过来 ⇒ 加入方**强制与房主一致**
      //   为什么必须同步：有些游戏的**棋盘大小随难度变**（如四子棋 6/7/9 列），
      //   两边难度不同 ⇒ 落子列号对不上 ⇒ 对局错位（真会发生的 bug）
      const d: number = Number.parseInt(m.d, 10);
      if (!isNaN(d) && LanMatch.gameId.length > 0) {
        ProgressStore.setDiff(LanMatch.gameId, d);
      }
    } else if (m.t === 'restart') {
      // 对方要重开 —— 双方回到房主先手、清空历史
      LanMatch.history = [];
      LanMatch.turn = Side.HOST;
    } else if (m.t === 'bye') {
      LanMatch.end();
    }
  }

  /** 房主连上后调一次：把自己的难度广播给加入方 */
  static broadcastDiff(gameId: string): void {
    if (!LanMatch.active || LanMatch.me !== Side.HOST || gameId.length === 0) {
      return;
    }
    Lan.send({ t: 'diff', d: String(ProgressStore.diffOf(gameId)) });
  }

  /** 我请求重开 —— 同时告诉对方 */
  static requestRestart(): void {
    if (!LanMatch.active) {
      return;
    }
    LanMatch.history = [];
    LanMatch.turn = Side.HOST;
    Lan.send({ t: 'restart', d: '' });
  }

  /** 本局走了多少手（大厅/结算可以显示） */
  static moveCount(): number {
    return LanMatch.history.length;
  }
}
