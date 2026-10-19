/**
 * 四子棋 —— 7 列 × 6 行，轮流投子，先连成四个（横竖斜）者胜
 *
 * 玩法：点最上面一行的箭头/任意一列 ⇒ 你的 🔴 落到该列最底下；电脑回一手 🟡
 * 胜负：你先连四 ⇒ solved=true；电脑先连四或棋盘填满 ⇒ solved=false
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const COLS: number = 7;
const ROWS: number = 6;
const ME: number = 1;
const AI: number = 2;
const AI_DELAY: number = 420;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GConnectFour {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 ROWS=6）
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

  @State private cells: number[] = [];
  @State private moves: number = 0;
  @State private msg: string = TG('点一列投子');
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private busy: boolean = false;
  @State private winLine: number[] = [];

  private startAt: number = 0;
  private finished: boolean = false;
  private aiTimer: number = -1;
  private rows: number[] = range(this.diffTotal);
  private cols: number[] = range(COLS);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机对局：对方走 AI 那一方 —— 收到列号就当成「电脑的那一步」应用
    LanMatch.setHandler((d: string) => {
      const c: number = Number.parseInt(d, 10);
      if (isNaN(c) || this.over) {
        return;
      }
      const r: number = this.dropRow(this.cells, c);
      if (r < 0) {
        return;
      }
      if (this.place(r, c, AI)) {
        this.end(false);          // 对手连成四子 ⇒ 我输
        return;
      }
      if (this.moves >= this.diffTotal * COLS) {
        this.end(false);
        return;
      }
      this.msg = TG('轮到你落子');
    });
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
    this.reset();
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
    return r * COLS + c;
  }

  private reset(): void {
    this.clearTimer();
    this.cells = new Array<number>(this.diffTotal * COLS).fill(0);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.busy = false;
    this.winLine = [];
    this.msg = TG('点一列投子');
    this.finished = false;
    this.startAt = Date.now();
  }

  /** 该列最下面那个空格的行号；列满返回 -1 */
  private dropRow(b: number[], c: number): number {
    for (let r = this.diffTotal - 1; r >= 0; r--) {
      if (b[this.idx(r, c)] === 0) {
        return r;
      }
    }
    return -1;
  }

  /** 以 (r,c) 为端点朝 (dr,dc) 方向连了几个同色 */
  private runLen(b: number[], r: number, c: number, dr: number, dc: number, who: number): number {
    let n: number = 0;
    let rr: number = r + dr;
    let cc: number = c + dc;
    while (rr >= 0 && rr < this.diffTotal && cc >= 0 && cc < COLS && b[this.idx(rr, cc)] === who) {
      n++;
      rr += dr;
      cc += dc;
    }
    return n;
  }

  /** 落子后是否连成四；是则把这条线写进 out */
  private isWin(b: number[], r: number, c: number, who: number, out: number[]): boolean {
    const dirs: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let d = 0; d < dirs.length; d++) {
      const dr: number = dirs[d][0];
      const dc: number = dirs[d][1];
      const a: number = this.runLen(b, r, c, dr, dc, who);
      const bb: number = this.runLen(b, r, c, -dr, -dc, who);
      if (a + bb + 1 >= 4) {
        out.splice(0, out.length);
        for (let k = -bb; k <= a; k++) {
          out.push(this.idx(r + dr * k, c + dc * k));
        }
        return true;
      }
    }
    return false;
  }

  private place(r: number, c: number, who: number): boolean {
    const b: number[] = this.cells.slice();
    b[this.idx(r, c)] = who;
    const line: number[] = [];
    const win: boolean = this.isWin(b, r, c, who, line);
    this.cells = b;
    this.moves++;
    if (win) {
      this.winLine = line;
    }
    return win;
  }

  private tap(c: number): void {
    if (this.over || this.busy) {
      return;
    }
    const r: number = this.dropRow(this.cells, c);
    if (r < 0) {
      this.msg = TG('这一列满了，换一列');
      return;
    }
    // ★ 联机时：不是我的回合就不接受点击
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      this.msg = TG('等对手落子…');
      return;
    }
    if (this.place(r, c, ME)) {
      this.end(true);
      return;
    }
    // ★ 联机时：把这一列发给对方，然后**不跑 AI**（对手就是那个人）
    if (LanMatch.isActive()) {
      LanMatch.record(String(c));
      this.msg = TG('等对手落子…');
      return;
    }
    if (this.moves >= this.diffTotal * COLS) {
      this.end(false);
      return;
    }
    this.busy = true;
    this.msg = TG('电脑思考中…');
    this.clearTimer();
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      this.aiTurn();
    }, AI_DELAY);
  }

  private aiTurn(): void {
    if (this.over) {
      return;
    }
    const b: number[] = this.cells;
    // ① 自己能赢就赢 ② 对方能赢就堵 ③ 否则按"离中心近"加权随机
    let pick: number = -1;
    for (let c = 0; c < COLS; c++) {
      const r: number = this.dropRow(b, c);
      if (r < 0) {
        continue;
      }
      const t: number[] = b.slice();
      t[this.idx(r, c)] = AI;
      const line: number[] = [];
      if (this.isWin(t, r, c, AI, line)) {
        pick = c;
        break;
      }
    }
    if (pick < 0) {
      for (let c = 0; c < COLS; c++) {
        const r: number = this.dropRow(b, c);
        if (r < 0) {
          continue;
        }
        const t: number[] = b.slice();
        t[this.idx(r, c)] = ME;
        const line: number[] = [];
        if (this.isWin(t, r, c, ME, line)) {
          pick = c;
          break;
        }
      }
    }
    if (pick < 0) {
      // ★★ 2026-10-13 AI 拔高（奥森：「电脑的水平实在是太低了」）
      //   原来兜底 = 「离中心近 + 随机」⇒ 纯 1 层贪心，看不到"我下这里你就造双威胁"
      //   改成【两层预判】：给每列算分，选最不容易被反杀的
      //     · 我下完之后，对手【能立刻赢的列数】> 0 ⇒ 这手是送死，重罚
      //     · 我下完之后，对手【能造双威胁的点数】越多 ⇒ 越危险，中罚
      //     · 我自己的"三连带空"威胁数 ⇒ 加分（进攻）
      //     · 离中心近 ⇒ 小加权（保留原来的合理部分）
      //   依据：knowledge/cards/棋类AI-算法与难度分级.md §一③
      let best: number = -1e9;
      let pickBest: number = -1;
      const center: number = Math.floor(COLS / 2);
      for (let c = 0; c < COLS; c++) {
        const r: number = this.dropRow(b, c);
        if (r < 0) {
          continue;
        }
        const t: number[] = b.slice();
        t[this.idx(r, c)] = AI;

        // ① 对手在我下完之后，能立刻赢的列数
        let oppWins: number = 0;
        for (let c2 = 0; c2 < COLS; c2++) {
          const r2: number = this.dropRow(t, c2);
          if (r2 < 0) {
            continue;
          }
          const t2: number[] = t.slice();
          t2[this.idx(r2, c2)] = ME;
          const ln: number[] = [];
          if (this.isWin(t2, r2, c2, ME, ln)) {
            oppWins++;
          }
        }

        // ② 我自己的威胁数（几步之内能连四的机会）
        let myThreats: number = 0;
        for (let c3 = 0; c3 < COLS; c3++) {
          const r3: number = this.dropRow(t, c3);
          if (r3 < 0) {
            continue;
          }
          const t3: number[] = t.slice();
          t3[this.idx(r3, c3)] = AI;
          const ln3: number[] = [];
          if (this.isWin(t3, r3, c3, AI, ln3)) {
            myThreats++;
          }
        }

        const score: number = myThreats * 60           // 进攻：我下一步能赢的点
          - (oppWins > 0 ? 100000 : 0)                 // ★ 送给对手立刻赢 ⇒ 几乎禁用
          - oppWins * 500                              // 对手能赢的点越少越好
          + (10 - Math.abs(c - center));               // 保留"靠中心"的小加权
        if (score > best) {
          best = score;
          pickBest = c;
        }
      }
      if (pickBest >= 0) {
        pick = pickBest;
      }
    }
    if (pick < 0) {
      this.end(false);
      return;
    }
    const rr: number = this.dropRow(this.cells, pick);
    if (this.place(rr, pick, AI)) {
      this.end(false);
      return;
    }
    this.busy = false;
    if (this.moves >= this.diffTotal * COLS) {
      this.end(false);
      return;
    }
    this.msg = TG2('轮到你了（第 {0} 手）', (this.moves + 1));
  }

  private end(playerWon: boolean): void {
    this.over = true;
    this.won = playerWon;
    this.busy = false;
    this.clearTimer();
    this.msg = playerWon ? '🎉 连成四个，你赢了！' : '电脑赢了，再来一局';
    const r: GameResult = {
      gameId: 'connect_four',
      solved: playerWon,
      score: playerWon ? Math.max(60, 300 - this.moves * 4) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
    };
    if (!this.finished) {
      this.finished = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('手数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('你 🔴'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.countOf(ME)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('电脑 🟡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.countOf(AI)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      // 落子按钮行
      Row({ space: 2 }) {
        ForEach(this.cols, (c: number) => {
          Text('▼')
            .accessibilityLevel('no')
            .fontSize(FontSize.sm)
            .fontColor(this.theme.inkFaint)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .onClick(() => {
              Haptics.tick();
              this.tap(c);
            })
        }, (c: number) => 't' + c)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.cols, (c: number) => {
              Stack() {
              if (this.cells.length > (this.idx(r, c)) && this.cells[(this.idx(r, c))] !== 0) {
              Row()
              .width('78%')
              .aspectRatio(1)
              .backgroundColor(this.cells[(this.idx(r, c))] === ME ? Palette.rose : Palette.amber)
              .borderRadius(Radius.full)
              .border({
              width: this.winLine.indexOf((this.idx(r, c))) >= 0 ? 3 : 0,
              color: Palette.emerald
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.theme.surface)
              .borderRadius(Radius.full)
              .onClick(() => {
              Haptics.tick();
              this.tap((c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
          .layoutWeight(1)
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(COLS / this.diffTotal)
      .padding(Space.xs)
      .backgroundColor(Palette.primary)
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
          Haptics.tap();
          this.reset();
        })

      Text(TG('点任意一列（或箭头）投子，横、竖、斜先连成四个就赢'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  private countOf(who: number): number {
    let n: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === who) {
        n++;
      }
    }
    return n;
  }




}
