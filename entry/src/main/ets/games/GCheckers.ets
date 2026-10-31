/**
 * 跳棋（英式跳棋 / 吃子跳）—— 6×6 棋盘，只走深色格
 *
 * 玩法：点自己的棋子 ⇒ 高亮可走点 ⇒ 点目标格。斜走一格；跳过对方棋子到空格可吃子。
 *       有吃子可走时**必须**吃（连跳可以一直跳，跳到不能再跳才换手）。
 *       走到对方底线升王，王可以往回走。
 * 胜负：对方无子或无子可动 ⇒ 你赢（solved=true）；你无子或无子可动 ⇒ 你输（solved=false）
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch, Side } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

/**
 * ★★ 局域网对战（2026-10-13，P12）
 *
 * 走子编码：`"from,to"`（两个格子下标）。**收到后必须做 180° 旋转**：
 *   跳棋棋盘是**有方向**的（自己的兵永远"往上"走），两台设备各自把自己摆在下方
 *   ⇒ 对方的下标 `i` 在我这边是 `n²-1-i`（同时翻行翻列，偶数列宽下深浅格奇偶不变）。
 *   不旋转的话：对方"往前走"到我这边会变成"往回走" ⇒ 直接下不了。
 * 哨兵：'P' 空过（连吃时用，见下）、'R' 重开。
 *
 * ⚠️ **连吃会破坏严格轮流**：`apply()` 里"吃完还能再吃就不换手"，
 *   而 `LanMatch.record()` 无条件翻手 ⇒ 和播棋的连走一模一样，
 *   走完那一步后要补发一个 'P' 把回合翻回来。
 */
const LAN_PASS: string = 'P';
const LAN_RESTART: string = 'R';

const N: number = 6;
const EMPTY: number = 0;
const P_MAN: number = 1;
const P_KING: number = 2;
const A_MAN: number = 3;
const A_KING: number = 4;
const PER_CAPTURE: number = 50;
const WIN_BONUS: number = 200;
const AI_DELAY: number = 480;

interface Move {
  from: number;
  to: number;
  cap: number;      // 被吃子的下标；-1 = 只是走一步
}

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}


/**
 * ★★★ 2026-10-23 第二期：给跳棋装一个会思考的对手
 *
 * 原来 scheduleAi() 里是：
 *   const pick = ms[Math.floor(Math.random() * ms.length)];
 * ⇒ 「电脑」是**随机走子**。7 款棋类里它是唯一一个不会思考的。
 *
 * 现在换成极小化极大 + α-β 剪枝：
 *   评估 = 子力（兵 1 / 王 2.5）+ 推进度（兵往前走一点点加分）+ 中心偏好
 *   深度：0 档 1 层（几乎乱走，新手能赢）/ 1 档 4 层 / 2 档 6 层
 *
 * ★ 为什么评估里"王"值 2.5 而不是 3：跳棋里一个王很强但不等于三个兵，
 *   2.5 是经验值（我按常见跳棋引擎的取值取的）。
 * ★ 纯函数：只吃 board/size/side，不碰组件状态 —— 这样将来能挪到工作线程。
 */

/** 某方所有可走法（纯函数版，与组件里的 movesFrom 规则一致） */
function genMoves(b: number[], size: number, side: number, onlyFrom: number): Move[] {
  const out: Move[] = [];
  const idx = (r: number, c: number): number => r * size + c;
  for (let i = 0; i < b.length; i++) {
    const v: number = b[i];
    const mine: boolean = side === 1 ? (v === P_MAN || v === P_KING) : (v === A_MAN || v === A_KING);
    if (!mine || (onlyFrom >= 0 && i !== onlyFrom)) {
      continue;
    }
    const r: number = Math.floor(i / size);
    const c: number = i % size;
    const king: boolean = (side === 1 && v === P_KING) || (side === 3 && v === A_KING);
    const dirs: number[] = king ? [-1, 1] : (side === 1 ? [-1] : [1]);
    for (let d = 0; d < dirs.length; d++) {
      const dr: number = dirs[d];
      for (let dc = -1; dc <= 1; dc += 2) {
        const tr: number = r + dr;
        const tc: number = c + dc;
        if (tr < 0 || tr >= size || tc < 0 || tc >= size) {
          continue;
        }
        if (b[idx(tr, tc)] === EMPTY) {
          out.push({ from: i, to: idx(tr, tc), cap: -1 });
        }
        const lr: number = r + dr * 2;
        const lc: number = c + dc * 2;
        if (lr < 0 || lr >= size || lc < 0 || lc >= size) {
          continue;
        }
        const mid: number = b[idx(tr, tc)];
        const midIsOpp: boolean = side === 1 ? (mid === A_MAN || mid === A_KING) : (mid === P_MAN || mid === P_KING);
        if (midIsOpp && b[idx(lr, lc)] === EMPTY) {
          out.push({ from: i, to: idx(lr, lc), cap: idx(tr, tc) });
        }
      }
    }
  }
  return out;
}

/** 落一子后的新盘（不改原盘） */
function afterMove(b: number[], size: number, m: Move, side: number): number[] {
  const n: number[] = b.slice();
  let v: number = n[m.from];
  n[m.from] = EMPTY;
  if (m.cap >= 0) {
    n[m.cap] = EMPTY;
  }
  const r: number = Math.floor(m.to / size);
  if (v === P_MAN && r === 0) {
    v = P_KING;
  } else if (v === A_MAN && r === size - 1) {
    v = A_KING;
  }
  n[m.to] = v;
  return n;
}

/** 评估（站在 side=3 电脑的视角，越大越好） */
function evalBoard(b: number[], size: number): number {
  let score: number = 0;
  for (let i = 0; i < b.length; i++) {
    const v: number = b[i];
    if (v === EMPTY) {
      continue;
    }
    const r: number = Math.floor(i / size);
    const c: number = i % size;
    // 中心偏好：越靠中间越值钱
    const cx: number = Math.abs(c - (size - 1) / 2) / size;
    const centerBonus: number = (0.5 - cx) * 0.4;
    if (v === A_MAN) {
      // 电脑的兵往上走（r 越小越接近升王）
      score += 1.0 + (size - 1 - r) / size * 0.35 + centerBonus;
    } else if (v === A_KING) {
      score += 2.5 + centerBonus;
    } else if (v === P_MAN) {
      score -= 1.0 + r / size * 0.35 + centerBonus;
    } else if (v === P_KING) {
      score -= 2.5 + centerBonus;
    }
  }
  return score;
}

const WIN_SCORE: number = 100000;

/** 极小化极大 + α-β。side 是"该谁走"。 */
function search(b: number[], size: number, side: number, depth: number,
                alpha0: number, beta0: number, budget: number[]): number {
  budget[0]--;
  if (budget[0] <= 0) {
    return evalBoard(b, size);          // 超预算就交静态评估（保证有返回值）
  }
  const ms: Move[] = genMoves(b, size, side, -1);
  if (ms.length === 0) {
    // 无路可走 = 该方输
    return side === 3 ? -WIN_SCORE : WIN_SCORE;
  }
  if (depth <= 0) {
    return evalBoard(b, size);
  }
  let alpha: number = alpha0;
  let beta: number = beta0;
  if (side === 3) {
    let best: number = -WIN_SCORE * 2;
    for (let k = 0; k < ms.length; k++) {
      const nb: number[] = afterMove(b, size, ms[k], side);
      const sc: number = search(nb, size, 1, depth - 1, alpha, beta, budget);
      if (sc > best) {
        best = sc;
      }
      if (best > alpha) {
        alpha = best;
      }
      if (alpha >= beta) {
        break;
      }
    }
    return best;
  }
  let best2: number = WIN_SCORE * 2;
  for (let k = 0; k < ms.length; k++) {
    const nb: number[] = afterMove(b, size, ms[k], side);
    const sc: number = search(nb, size, 3, depth - 1, alpha, beta, budget);
    if (sc < best2) {
      best2 = sc;
    }
    if (best2 < beta) {
      beta = best2;
    }
    if (alpha >= beta) {
      break;
    }
  }
  return best2;
}

/**
 * 电脑选一手。
 * level: 0 简单（深 1，几乎乱走）/ 1 普通（深 4）/ 2 困难（深 6）
 * 任何异常 ⇒ 返回 null，调用方回落随机（绝不让游戏卡死）
 */
function aiBest(board: number[], size: number, level: number, onlyFrom: number): Move | null {
  try {
    const ms: Move[] = genMoves(board, size, 3, onlyFrom);
    if (ms.length === 0) {
      return null;
    }
    if (ms.length === 1) {
      return ms[0];                     // 只有一步，不用想
    }
    // ★★★ 2026-10-23：困难档由深 6 提到深 8 —— **不是拍脑袋，是打出来的**
    //   量过：深 6 的搜索只要 8.4 ms（Node），12 万节点预算只用了 5 千
    //   于是让深 6 与深 8 自对弈 24 局（两侧轮换抵消先手）：
    //     深 8 胜 12 ｜ 深 6 胜 0 ｜ 平 12
    //   ⇒ 深 8 从不输给深 6，加深是稳赚的
    //   ⚠️ 24 局里 12 平说明双方都能避免被吃 —— 评测函数缺"推进"以外的长期目标，
    //      这是已知弱点，不在这轮解决（记在台账里）
    const depth: number = level <= 0 ? 1 : (level >= 2 ? 8 : 4);
    const budget: number[] = [level >= 2 ? 120000 : 30000];
    let best: Move = ms[0];
    let bestSc: number = -WIN_SCORE * 2;
    for (let k = 0; k < ms.length; k++) {
      const nb: number[] = afterMove(board, size, ms[k], 3);
      const sc: number = search(nb, size, 1, depth - 1, -WIN_SCORE * 2, WIN_SCORE * 2, budget);
      if (sc > bestSc) {
        bestSc = sc;
        best = ms[k];
      }
      if (budget[0] <= 0) {
        break;                          // 超预算 ⇒ 用当前最好的
      }
    }
    return best;
  } catch (e) {
    return null;
  }
}

@Component
export struct GCheckers {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6）
  //   ⚠️ 渲染原本用 ForEach(this.rows)，已改成 ForEach(this.rowIdx())
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private board: number[] = [];
  @State private sel: number = -1;
  @State private targets: number[] = [];
  @State private cap: number = 0;
  @State private msg: string = TG('点自己的棋子，再点高亮格');
  @State private turn: number = 1;          // 1 = 你，3 = 电脑
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private aiTimer: number = -1;
  private rows: number[] = range(this.diffTotal);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机：对方的走子 = 本局「AI 的那一步」
    LanMatch.setHandler((d: string) => {
      this.onRemote(d);
    });
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCheckers')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」：联机时要通知对方，否则两边棋盘不一样 */
  onRestart(): void {
    this.restartTap();
  }

  /** 本局棋盘边长。★ 联机钉死标准 6×6（难度会改 4/6/8，两边不同就对不了局） */
  private pickSize(): number {
    return LanMatch.isActive() ? N : GameDiff.sizeNow(6);
  }

  /** 本局格子数 */
  private cellCount(): number {
    return this.diffTotal * this.diffTotal;
  }

  /** 对方下标 → 我这边：180° 旋转（翻行+翻列） */
  private rot(i: number): number {
    return this.cellCount() - 1 - i;
  }

  /** 重开（按钮与宿主「换一局」都走这里）：联机要通知对方 + 把回合翻回房主先手 */
  private restartTap(): void {
    if (!LanMatch.isActive()) {
      this.reset();
      return;
    }
    const iAmHost: boolean = LanMatch.mySide() === Side.HOST;
    const turnWasHost: boolean = iAmHost ? LanMatch.myTurn() : !LanMatch.myTurn();
    this.reset();
    LanMatch.record(LAN_RESTART);
    if (turnWasHost) {
      LanMatch.record(LAN_PASS);
    }
    this.turn = LanMatch.myTurn() ? 1 : 3;
  }

  /** 收到对方的走子（"from,to"）：旋转成我的编号后按合法走法应用 */
  private onRemote(d: string): void {
    if (d === LAN_RESTART) {
      this.reset();
      return;
    }
    if (d === LAN_PASS) {
      this.turn = LanMatch.myTurn() ? 1 : 3;
      return;
    }
    const parts: string[] = d.split(',');
    if (parts.length !== 2) {
      return;
    }
    const from: number = this.rot(Number.parseInt(parts[0], 10));
    const to: number = this.rot(Number.parseInt(parts[1], 10));
    if (isNaN(from) || isNaN(to) || this.over || from < 0 || to < 0
      || from >= this.cellCount() || to >= this.cellCount()) {
      return;
    }
    // 用真实的走法表校验（旋转后必须真的合法）——比自己重算规则安全
    const ms: Move[] = this.movesFrom(this.board, 3, from);
    let hit: Move | undefined = undefined;
    for (let k = 0; k < ms.length; k++) {
      if (ms[k].to === to) {
        hit = ms[k];
        break;
      }
    }
    if (hit === undefined) {
      return;
    }
    this.apply(hit);      // 连吃/升王/结算都由 apply 自己算 ⇒ 两边必然一致
    if (!this.over) {
      this.turn = LanMatch.myTurn() ? 1 : 3;
    }
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.aiTimer >= 0) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  private idx(r: number, c: number): number {
    return r * this.diffTotal + c;
  }

  private dark(r: number, c: number): boolean {
    return (r + c) % 2 === 1;
  }

  private reset(): void {
    this.clearTimer();
    this.diffTotal = this.pickSize();
    const b: number[] = new Array<number>(this.cellCount()).fill(EMPTY);
    for (let r = 0; r < this.diffTotal; r++) {
      for (let c = 0; c < this.diffTotal; c++) {
        if (!this.dark(r, c)) {
          continue;
        }
        if (r <= 1) {
          b[this.idx(r, c)] = A_MAN;
        } else if (r >= this.diffTotal - 2) {
          b[this.idx(r, c)] = P_MAN;
        }
      }
    }
    this.board = b;
    this.sel = -1;
    this.targets = [];
    this.cap = 0;
    this.turn = 1;
    this.over = false;
    this.won = false;
    this.finished = false;
    // ★ 联机：本地 turn 要跟"轮到谁"对齐（房主先手；否则加入方开局会显示"轮到你了"却点不动）
    if (LanMatch.isActive()) {
      this.turn = LanMatch.myTurn() ? 1 : 3;
    }
    this.msg = LanMatch.isActive()
      ? (this.turn === 1 ? '联机：点自己的棋子，再点高亮格' : '联机：等对手走子…')
      : TG('点自己的棋子，再点高亮格');
    this.startAt = Date.now();
  }

  private isPlayer(v: number): boolean {
    return v === P_MAN || v === P_KING;
  }

  private isAi(v: number): boolean {
    return v === A_MAN || v === A_KING;
  }

  /** 某一方某个子的可走法；onlyFrom >= 0 时只看这一个子 */
  private movesFrom(b: number[], side: number, onlyFrom: number): Move[] {
    const out: Move[] = [];
    for (let i = 0; i < b.length; i++) {
      const v: number = b[i];
      const ok: boolean = side === 1 ? this.isPlayer(v) : this.isAi(v);
      if (!ok || (onlyFrom >= 0 && i !== onlyFrom)) {
        continue;
      }
      const r: number = Math.floor(i / this.diffTotal);
      const c: number = i % this.diffTotal;
      const king: boolean = (side === 1 && v === P_KING) || (side === 3 && v === A_KING);
      const dirs: number[] = king ? [-1, 1] : (side === 1 ? [-1] : [1]);
      for (let d = 0; d < dirs.length; d++) {
        const dr: number = dirs[d];
        for (let dc = -1; dc <= 1; dc += 2) {
          const tr: number = r + dr;
          const tc: number = c + dc;
          if (tr < 0 || tr >= this.diffTotal || tc < 0 || tc >= this.diffTotal) {
            continue;
          }
          if (b[this.idx(tr, tc)] === EMPTY) {
            const m: Move = { from: i, to: this.idx(tr, tc), cap: -1 };
            out.push(m);
          }
          const lr: number = r + dr * 2;
          const lc: number = c + dc * 2;
          if (lr < 0 || lr >= this.diffTotal || lc < 0 || lc >= this.diffTotal) {
            continue;
          }
          const mid: number = b[this.idx(tr, tc)];
          const isEnemy: boolean = side === 1 ? this.isAi(mid) : this.isPlayer(mid);
          if (isEnemy && b[this.idx(lr, lc)] === EMPTY) {
            const m2: Move = { from: i, to: this.idx(lr, lc), cap: this.idx(tr, tc) };
            out.push(m2);
          }
        }
      }
    }
    const caps: Move[] = out.filter((m: Move) => m.cap >= 0);
    return caps.length > 0 ? caps : out;
  }

  private apply(m: Move): void {
    const b: number[] = this.board.slice();
    let v: number = b[m.from];
    b[m.from] = EMPTY;
    if (m.cap >= 0) {
      b[m.cap] = EMPTY;
      if (this.turn === 1) {
        this.cap++;
      } else {
        this.cap--;
      }
    }
    // 升王
    const r: number = Math.floor(m.to / this.diffTotal);
    if (v === P_MAN && r === 0) {
      v = P_KING;
    } else if (v === A_MAN && r === this.diffTotal - 1) {
      v = A_KING;
    }
    b[m.to] = v;
    this.board = b;

    // 连跳：吃完还能再吃就继续，不换手
    if (m.cap >= 0) {
      const again: Move[] = this.movesFrom(b, this.turn, m.to);
      const canJump: boolean = again.length > 0 && again[0].cap >= 0;
      if (canJump) {
        if (this.turn === 1) {
          this.sel = m.to;
          this.targets = again.map((x: Move) => x.to);
        } else {
          this.scheduleAi(m.to);
        }
        return;
      }
    }
    this.endTurn();
  }

  private endTurn(): void {
    const b: number[] = this.board;
    if (this.countOf(b, 3) === 0) {
      this.finishGame(true);
      return;
    }
    if (this.countOf(b, 1) === 0) {
      this.finishGame(false);
      return;
    }
    this.turn = this.turn === 1 ? 3 : 1;
    this.sel = -1;
    this.targets = [];
    const mine: Move[] = this.movesFrom(b, this.turn, -1);
    if (mine.length === 0) {
      this.finishGame(this.turn === 3);
      return;
    }
    if (this.turn === 3) {
      this.msg = LanMatch.isActive() ? '联机：等对手走子…' : TG('电脑思考中…');
      this.scheduleAi(-1);
    } else {
      this.msg = LanMatch.isActive() ? '联机：轮到你了' : TG('轮到你了');
    }
  }

  private countOf(b: number[], side: number): number {
    let n: number = 0;
    for (let i = 0; i < b.length; i++) {
      const v: number = b[i];
      if (side === 1 ? this.isPlayer(v) : this.isAi(v)) {
        n++;
      }
    }
    return n;
  }

  private scheduleAi(from: number): void {
    if (LanMatch.isActive()) {
      return;                    // ★ 联机时没有 AI
    }
    this.clearTimer();
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      const ms: Move[] = this.movesFrom(this.board, 3, from);
      if (ms.length === 0) {
        this.endTurn();
        return;
      }
      // ★★★ 2026-10-23：随机走子 → 极小化极大 + α-β
      //   原来「电脑」是 Math.random 挑一个合法步 ⇒ 玩家几乎不可能输，
      //   7 款棋类里它是唯一一个不会思考的。
      //   level 用 GameDiff.now()（0/1/2）；算不出来（异常/超预算）⇒ 回落随机，绝不卡死
      const lv: number = GameDiff.now();
      const best: Move | null = aiBest(this.board, this.diffTotal, lv, from);
      const pick: Move = best !== null ? best : ms[Math.floor(Math.random() * ms.length)];
      this.apply(pick);
    }, AI_DELAY);
  }

  private finishGame(playerWon: boolean): void {
    this.over = true;
    this.won = playerWon;
    this.turn = 0;
    this.sel = -1;
    this.targets = [];
    this.msg = playerWon
      ? '🎉 吃掉对手 / 对手无路可走，你赢了'
      : (LanMatch.isActive() ? '对手赢了，再来一局' : '电脑赢了，再来一局');
    this.clearTimer();
    this.finish(playerWon);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'checkers',
      solved: solved,
      score: this.cap * PER_CAPTURE + (solved ? WIN_BONUS : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.cap
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款本来就有搜索器（aiBest/search），但它只会替电脑（side 3）想。
  // 代打要替玩家（side 1）想 ⇒ 反过来：search 的分数是电脑视角 ⇒ 挑最小的。
  private aiBestForPlayer(onlyFrom: number): Move | null {
    const ms: Move[] = this.movesFrom(this.board, 1, onlyFrom);
    if (ms.length === 0) {
      return null;
    }
    if (ms.length === 1) {
      return ms[0];
    }
    let best: Move = ms[0];
    let bestSc: number = WIN_SCORE * 2;
    for (let k = 0; k < ms.length; k++) {
      // ★ 每个候选各给一份预算（共用一份的话第一个候选就把它吃光 ⇒ 等于永远走第一手）
      const budget: number[] = [4000];
      const nb: number[] = afterMove(this.board, this.diffTotal, ms[k], 1);
      const sc: number = search(nb, this.diffTotal, 3, 4, -WIN_SCORE * 2, WIN_SCORE * 2, budget);
      if (sc < bestSc) {
        bestSc = sc;
        best = ms[k];
      }
    }
    return best;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.turn !== 1) {
      return true;               // 轮到电脑/对手，等它走完
    }
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      return true;
    }
    if (this.sel >= 0) {
      const mv: Move | null = this.aiBestForPlayer(this.sel);
      if (mv === null) {
        this.sel = -1;
        this.targets = [];
        return true;
      }
      this.tap(mv.to);           // 已选中 ⇒ 走到最优目标格
      return !this.over;
    }
    const mv2: Move | null = this.aiBestForPlayer(-1);
    if (mv2 === null) {
      return false;
    }
    this.tap(mv2.from);          // 先点棋子
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.turn !== 1) {
      return Hint.none('none');
    }
    const mv: Move | null = this.aiBestForPlayer(this.sel >= 0 ? this.sel : -1);
    if (mv === null) {
      return Hint.none('none');
    }
    const r1: number = Math.floor(mv.from / this.diffTotal) + 1;
    const c1: number = (mv.from % this.diffTotal) + 1;
    const r2: number = Math.floor(mv.to / this.diffTotal) + 1;
    const c2: number = (mv.to % this.diffTotal) + 1;
    const tail: string = mv.cap >= 0 ? TG('（能吃掉对方一颗子）') : '';
    return Hint.make([mv.from, mv.to],
      TG2('把第 {0} 行第 {1} 列的子走到', String(r1), String(c1))
        + TG2('第 {0} 行第 {1} 列', String(r2), String(c2)) + tail,
      TG2('Move the piece at row {0}, column {1}', String(r1), String(c1))
        + TG2(' to row {0}, column {1}', String(r2), String(c2)), t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private tap(i: number): void {
    if (this.over || this.turn !== 1) {
      return;
    }
    // ★ 联机：不是我的回合就不接受点击
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      return;
    }
    for (let k = 0; k < this.targets.length; k++) {
      if (this.targets[k] === i && this.sel >= 0) {
        const ms: Move[] = this.movesFrom(this.board, 1, this.sel);
        for (let j = 0; j < ms.length; j++) {
          if (ms[j].to === i) {
            const mv: Move = ms[j];
            this.apply(mv);
            if (LanMatch.isActive()) {
              // ★ 先广播这一步（对方要靠它算出同样的局面）
              // ⚠️ 发送的是**我自己编号系**的 from/to，对方收到会做 180° 旋转
              LanMatch.record(String(mv.from) + ',' + String(mv.to));
              if (!this.over && this.turn === 1) {
                // 连吃：还要继续吃 ⇒ 补个空过包把回合翻回来
                LanMatch.record(LAN_PASS);
              }
            }
            return;
          }
        }
      }
    }
    const v: number = this.board[i];
    if (this.isPlayer(v)) {
      const ms: Move[] = this.movesFrom(this.board, 1, i);
      if (ms.length === 0) {
        this.msg = TG('这颗子走不动');
        return;
      }
      this.sel = i;
      this.targets = ms.map((m: Move) => m.to);
      this.msg = TG2("可走 {0} 步", ms.length);
      return;
    }
    this.sel = -1;
    this.targets = [];
  }

  /** 棋盘边长（vp）：按「可用宽 / 可用高」取小值
   *  ★★★ 2026-10-30：百分比（70% / 45%）在横竖屏下不可能同时最优
   *    ⇒ 按真实可用空间算。模式已在 GBejeweled / GReversi 真机验过：
   *      横屏 293vp（装得下、按钮可见）/ 竖屏 704vp（尽量大、无空白）。
   */
    private boardPx(): number {
    // ★★★ 2026-10-31 · 第四版（前三版都错，完整记录）：
    //   ① `Bp.height * 0.55`          ⇒ 横屏 293vp，把「重开」挤出屏幕
    //   ② `(Bp.height - 260) * 0.85`  ⇒ 横屏 232vp，**仍然超 27vp**
    //      （实测：棋盘 232vp 时「重开」y=1562px，安全上限 1480px）
    //   ③ 错误原因：**固定部分是绝对值**（顶栏/HintBar/三信息卡/状态/按钮），
    //      不是比例；且我两次都把固定部分估小了。
    //   ④ 用实测数据反推：需要棋盘 ≤ 205vp ⇒ 比例取 **0.70**。
    //      横屏 (533-260)*0.70 = 191vp ⇒ 「重开」约 480vp（安全）
    //      竖屏 (1280-260)*0.70 = 714vp（受宽度限，仍比旧 704 大）
    const FIXED: number = 300;   // ★ 第五版：实测黑白棋固定部分更大，取 300 覆盖所有款
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(120, (Bp.height - FIXED) * 0.70);
    return Math.min(w, h);
  }

  build() {
    // ★★★ 2026-10-30：横屏 853×533 下，maxHeight 45%（240vp）+ 固定部分 350vp
    //   仍可能超过 533vp（大字模式/极小屏）⇒ **套 Scroll 兜底**，
    //   让玩家总能滚到「重开」。与 GBejeweled / GColorFlood / GFillomino 同一模板。
    Scroll() {
      Column({ space: Space.sm }) {
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
          onAutoTap: () => { this.askAuto(); },
          demoOn: this.demoId >= 0,
          autoOn: this.autoId >= 0
        })
        Row({ space: Space.sm }) {
          // ⚠️ 只传「种类」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三格整局不刷新
          Column({ space: 2 }) {
          Text(true ? (LanMatch.isActive() ? '我的吃子' : '你的吃子')
          : (false ? (LanMatch.isActive() ? '我的子' : '你的子')
          : (LanMatch.isActive() ? '对手的子' : '电脑的子')))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(true ? String(this.cap)
          : (false ? String(this.countOf(this.board, 1)) : String(this.countOf(this.board, 3))))
          .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(true ? Palette.emerald : (false ? Palette.primary : Palette.rose))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(false ? (LanMatch.isActive() ? '我的吃子' : '你的吃子')
          : (true ? (LanMatch.isActive() ? '我的子' : '你的子')
          : (LanMatch.isActive() ? '对手的子' : '电脑的子')))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(false ? String(this.cap)
          : (true ? String(this.countOf(this.board, 1)) : String(this.countOf(this.board, 3))))
          .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(false ? Palette.emerald : (true ? Palette.primary : Palette.rose))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(false ? (LanMatch.isActive() ? '我的吃子' : '你的吃子')
          : (false ? (LanMatch.isActive() ? '我的子' : '你的子')
          : (LanMatch.isActive() ? '对手的子' : '电脑的子')))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(false ? String(this.cap)
          : (false ? String(this.countOf(this.board, 1)) : String(this.countOf(this.board, 3))))
          .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
          .fontColor(false ? Palette.emerald : (false ? Palette.primary : Palette.rose))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .width('100%')

        Column() {
          ForEach(this.rowIdx(), (r: number) => {
            Row() {
              ForEach(this.rowIdx(), (c: number) => {
                Stack() {
                if (this.board.length > (this.idx(r, c)) && this.board[(this.idx(r, c))] !== EMPTY) {
                Row()
                .width('74%')
                .aspectRatio(1)
                .backgroundColor(this.isPlayer(this.board[(this.idx(r, c))]) ? Palette.rose : '#1F2937').animation({ duration: Motion.fast, curve: Motion.snap() })
                .borderRadius(Radius.full)
                .border({
                width: this.sel === (this.idx(r, c)) ? 3 : 1,
                color: this.sel === (this.idx(r, c)) ? Palette.amber : '#33FFFFFF'
                })
                .shadow(Shadow.card)
                if (this.board[(this.idx(r, c))] === P_KING || this.board[(this.idx(r, c))] === A_KING) {
                Text('♛').accessibilityLevel('no').fontSize(FontSize.sm).fontColor(Palette.amber)
                }
                } else if (this.targets.indexOf((this.idx(r, c))) >= 0) {
                Row()
                .width('34%')
                .aspectRatio(1)
                .backgroundColor(Palette.amber)
                .borderRadius(Radius.full)
                .opacity(0.75)
                }
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .backgroundColor(this.dark((r), (c)) ? this.theme.surfaceAlt : this.theme.surface)
                .borderRadius(Radius.xs)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((this.idx(r, c))); }); })
                .onClick(() => {
                Haptics.tick();
                this.tap((this.idx(r, c)));
                })
              }, (c: number) => 'c' + c)
            }
            .width('100%')
            .layoutWeight(1)
          }, (r: number) => 'r' + r)
        }
        // ★★★ 2026-10-30 · 用「算出来的边长」，不用百分比（见 boardPx 注释）
        .width(this.boardPx())
        .height(this.boardPx())
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg)
        .shadow(Shadow.card)

        Text(this.msg)
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

        Button(TG('重开'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width('100%')
          .height(Cell.of(46))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.restartTap(); }); })
          .onClick(() => {
            Haptics.tap();
            this.restartTap();
          })

        Text(LanMatch.isActive()
          ? '联机：你执下方（房主先手）；斜走一格，跳过对方子到空格即吃子，能跳必须跳、可连跳；到底线升王（♛）'
          : '斜走一格；跳过对方子到空格即吃子。能跳必须跳，可连跳；到底线升王（♛）')
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }
      .onTouch((e: TouchEvent) => {
        // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
        if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
      })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  /** 顶部小格：kind 0=吃子 1=我的子 2=对方的子（联机时叫"对手"） */



}
