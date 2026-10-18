/**
 * 跳棋（英式跳棋 / 吃子跳）—— 6×6 棋盘，只走深色格
 *
 * 玩法：点自己的棋子 ⇒ 高亮可走点 ⇒ 点目标格。斜走一格；跳过对方棋子到空格可吃子。
 *       有吃子可走时**必须**吃（连跳可以一直跳，跳到不能再跳才换手）。
 *       走到对方底线升王，王可以往回走。
 * 胜负：对方无子或无子可动 ⇒ 你赢（solved=true）；你无子或无子可动 ⇒ 你输（solved=false）
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { LanMatch, Side } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

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

@Component
export struct GCheckers {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6）
  //   ⚠️ 渲染原本用 ForEach(this.rows)，已改成 ForEach(this.rowIdx())
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
      const pick: Move = ms[Math.floor(Math.random() * ms.length)];
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

  build() {
    Column({ space: Space.sm }) {
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
              .onClick(() => {
              this.tap((this.idx(r, c)));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
          .layoutWeight(1)
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
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
        .onClick(() => {
          this.restartTap();
        })

      Text(LanMatch.isActive()
        ? '联机：你执下方（房主先手）；斜走一格，跳过对方子到空格即吃子，能跳必须跳、可连跳；到底线升王（♛）'
        : '斜走一格；跳过对方子到空格即吃子。能跳必须跳，可连跳；到底线升王（♛）')
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** 顶部小格：kind 0=吃子 1=我的子 2=对方的子（联机时叫"对手"） */



}
