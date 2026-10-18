/**
 * 局域网**竞速模式**引擎 —— 让「一局」的 355 款游戏全都能联机对战
 *
 * 奥森 2026-10-13 08:0x 亲述：
 *   「**所有游戏其实都可以设置成可以在局域网内对战的，那样就是比速度（谁先完成）**」
 *   「**然后对战可以不只两人，可以多人**」
 *
 * ────────────────────────────────────────────────────────────
 * ★ 设计：UDP 广播 + 各端本地算排名（**不用服务器、不用星型转发**）
 *
 *   房主广播 `race_go`（带起始时间戳）
 *        ⇒ 所有设备听到 ⇒ 同一时刻开始
 *   每人完成时广播 `race_done`（昵称 + 用时 ms）
 *        ⇒ 所有设备听到所有人的成绩
 *        ⇒ **每台设备本地算出同样的排名**
 *
 *   好处：天然支持 N 人 · 无单点 · 房主中途退出也不影响已开赛的局
 *
 * ────────────────────────────────────────────────────────────
 * ★ 游戏侧只需 **2 个钩子**（游戏逻辑一行不用改）：
 *
 *   // ① 开局那一刻
 *   LanRace.noteStart();
 *
 *   // ② 完成 / 失败那一刻（传本次用时，或让引擎自己算）
 *   LanRace.noteDone();          // 引擎按 noteStart 到现在自动算用时
 *   // 或显式给：LanRace.noteDone(ms)
 *
 * ★ 判据：`LanRace.isRacing()` 为真时才需要上报（单人玩时它恒假，零开销）
 */

import { Lan, LanMsg } from './Lan';

/** 一条成绩 */
export interface RaceScore {
  nick: string;      // 玩家昵称
  ms: number;        // 用时（毫秒）
  me: boolean;       // 是不是我自己
}

/** 广播消息类型 */
const T_GO: string = 'race_go';
const T_DONE: string = 'race_done';
const T_ASK: string = 'race_ask';     // 新人加入 ⇒ 请求重发开始信号
const T_BYE: string = 'race_bye';

export class LanRace {
  /** 是否在竞速局里 */
  private static racing: boolean = false;
  /** 我是不是房主 */
  private static host: boolean = false;
  /** 起始时刻（本机单调用 now() —— 各端各自记，避免时钟不同步） */
  private static startAt: number = 0;   // 0 = 还没开始计时（收到 race_go 后才有值）
  /** 已收到的成绩（含我自己） */
  private static scores: RaceScore[] = [];
  /** 局号：换一局就 +1，用来忽略上一局的迟到消息 */
  private static round: number = 0;
  /** 状态变化回调（UI 订阅） */
  private static onChange: () => void = () => {};

  // ─── 查询 ───
  static isRacing(): boolean { return LanRace.racing; }
  static amHost(): boolean { return LanRace.host; }
  static scoresOf(): RaceScore[] { return LanRace.scores; }
  static roundNo(): number { return LanRace.round; }

  /** 实时排名：已完成的按用时升序，未完成的排在后面 */
  static ranked(): RaceScore[] {
    const arr: RaceScore[] = LanRace.scores.slice();
    arr.sort((a: RaceScore, b: RaceScore): number => a.ms - b.ms);
    return arr;
  }

  /** 我的名次（1 起）；没完成返回 0 */
  static myRank(): number {
    const r: RaceScore[] = LanRace.ranked();
    for (let i = 0; i < r.length; i++) {
      if (r[i].me) { return i + 1; }
    }
    return 0;
  }

  static setOnChange(cb: () => void): void { LanRace.onChange = cb; }

  // ─── 开一局（房主调） ───
  /**
   * 房主开一局：清空成绩、记下起始时刻、广播 go
   * @param gameId 玩哪一款（对方会跟着进同一款游戏）
   */
  static async hostStart(gameId: string): Promise<void> {
    LanRace.racing = true;
    LanRace.host = true;
    LanRace.round = LanRace.round + 1;
    LanRace.scores = [];
    LanRace.startAt = Date.now();
    LanRace.onChange();
    await Lan.send({ t: T_GO, d: JSON.stringify({ g: gameId, r: LanRace.round }) });
  }

  /** 非房主：加入后请求一次 go（防止错过广播） */
  static async ask(): Promise<void> {
    await Lan.send({ t: T_ASK, d: '' });
  }

  // ─── 游戏侧的两个钩子 ───
  /**
   * ① 我这一局开始了（各端在收到 go、真正进游戏后调）
   *
   * ★★ 起跑公平性（2026-10-13 · games-input 提出，我修的）：
   *   计时**不应该**在「进游戏那一刻」重新开始 —— 否则网络快慢 + 加载快慢
   *   会带来几十~几百 ms 的系统性差异（谁的机器快谁占便宜）。
   *   ⇒ **计时从「收到 race_go」那一刻就开始了**（那时各端几乎同时收到，只差单向网络延迟）。
   *   ⇒ 本函数**只在没计过时的情况下兜底**（比如单人先练一把再有人开赛）。
   */
  static noteStart(): void {
    if (!LanRace.racing) { return; }
    if (LanRace.startAt <= 0) {
      LanRace.startAt = Date.now();
    }
  }

  /** ② 我完成了（或失败了）—— 用时自动算；也可显式传 */
  static async noteDone(ms: number = -1): Promise<void> {
    if (!LanRace.racing) { return; }
    const used: number = ms >= 0 ? ms : (Date.now() - LanRace.startAt);
    LanRace.addScore(Lan.nick(), used, true);
    await Lan.send({ t: T_DONE, d: JSON.stringify({ n: Lan.nick(), ms: used, r: LanRace.round }) });
  }

  // ─── 收消息（由 Lan 的 onMsg 转进来） ───
  static async receive(m: LanMsg): Promise<void> {
    if (m.t === T_GO) {
      try {
        const o = JSON.parse(m.d) as Record<string, string>;
        const r: number = Number.parseInt(o.r, 10);
        if (r < LanRace.round) { return; }          // 旧局的迟到消息，丢
        LanRace.racing = true;
        LanRace.host = false;
        LanRace.round = r;
        LanRace.scores = [];
        LanRace.startAt = Date.now();               // ★ 各端各自记起始时刻
        LanRace.onChange();
      } catch (e) { /* 忽略坏包 */ }
      return;
    }
    if (m.t === T_ASK) {
      // 新人问「现在在比什么」⇒ 房主把当前状态回一遍
      if (LanRace.host && LanRace.racing) {
        await Lan.send({ t: T_GO, d: JSON.stringify({ g: '', r: LanRace.round }) });
      }
      return;
    }
    if (m.t === T_DONE) {
      try {
        const o = JSON.parse(m.d) as Record<string, string>;
        const r: number = Number.parseInt(o.r, 10);
        if (r !== LanRace.round) { return; }        // 不是这一局，丢
        const n: string = o.n;
        const ms: number = Number.parseInt(o.ms, 10);
        if (!isNaN(ms)) { LanRace.addScore(n, ms, n === Lan.nick()); }
      } catch (e) { /* 忽略坏包 */ }
      return;
    }
    if (m.t === T_BYE) {
      // 有人退出 ⇒ 不删成绩（他可能已完成），只刷新一下
      LanRace.onChange();
    }
  }

  /** 记一条成绩（同一个人只记最快的一次） */
  private static addScore(nick: string, ms: number, me: boolean): void {
    for (let i = 0; i < LanRace.scores.length; i++) {
      const s: RaceScore = LanRace.scores[i];
      if (s.nick === nick) {
        if (ms < s.ms) { LanRace.scores[i] = { nick: nick, ms: ms, me: s.me || me }; }
        LanRace.onChange();
        return;
      }
    }
    LanRace.scores.push({ nick: nick, ms: ms, me: me });
    LanRace.onChange();
  }

  /** 退出竞速（回大厅/换游戏时调） */
  static async leave(): Promise<void> {
    if (LanRace.racing) {
      await Lan.send({ t: T_BYE, d: Lan.nick() });
    }
    LanRace.racing = false;
    LanRace.host = false;
    LanRace.scores = [];
    LanRace.round = 0;
    LanRace.onChange();
  }
}
