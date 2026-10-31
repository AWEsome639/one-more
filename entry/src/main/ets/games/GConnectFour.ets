/**
 * 四子棋 —— 7 列 × 6 行，轮流投子，先连成四个（横竖斜）者胜
 *
 * 玩法：点最上面一行的箭头/任意一列 ⇒ 你的 🔴 落到该列最底下；电脑回一手 🟡
 * 胜负：你先连四 ⇒ solved=true；电脑先连四或棋盘填满 ⇒ solved=false
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

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
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GConnectFour')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
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

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.busy) {
      return true;
    }
    this.tap(this.bestCol());
    return !this.over;
  }

  /** 代打/提示共用：给「我」选一列（① 我能赢 ② 堵电脑 ③ 两层预判） */
  private bestCol(): number {
    const b: number[] = this.cells;
    let pick: number = -1;
    for (let c = 0; c < COLS; c++) {
      const r: number = this.dropRow(b, c);
      if (r < 0) {
        continue;
      }
      const t: number[] = b.slice();
      t[this.idx(r, c)] = ME;
      const ln: number[] = [];
      if (this.isWin(t, r, c, ME, ln)) {
        return c;
      }
    }
    for (let c2: number = 0; c2 < COLS; c2++) {
      const r2: number = this.dropRow(b, c2);
      if (r2 < 0) {
        continue;
      }
      const t2: number[] = b.slice();
      t2[this.idx(r2, c2)] = AI;
      const ln2: number[] = [];
      if (this.isWin(t2, r2, c2, AI, ln2)) {
        pick = c2;
        break;
      }
    }
    if (pick >= 0) {
      return pick;
    }
    let bestS: number = -1e9;
    const center: number = Math.floor(COLS / 2);
    for (let c3: number = 0; c3 < COLS; c3++) {
      const r3: number = this.dropRow(b, c3);
      if (r3 < 0) {
        continue;
      }
      const t3: number[] = b.slice();
      t3[this.idx(r3, c3)] = ME;
      let oppWins: number = 0;
      for (let c4: number = 0; c4 < COLS; c4++) {
        const r4: number = this.dropRow(t3, c4);
        if (r4 < 0) {
          continue;
        }
        const t4: number[] = t3.slice();
        t4[this.idx(r4, c4)] = AI;
        const ln4: number[] = [];
        if (this.isWin(t4, r4, c4, AI, ln4)) {
          oppWins = oppWins + 1;
        }
      }
      let myWins: number = 0;
      for (let c5: number = 0; c5 < COLS; c5++) {
        const r5: number = this.dropRow(t3, c5);
        if (r5 < 0) {
          continue;
        }
        const t5: number[] = t3.slice();
        t5[this.idx(r5, c5)] = ME;
        const ln5: number[] = [];
        if (this.isWin(t5, r5, c5, ME, ln5)) {
          myWins = myWins + 1;
        }
      }
      const s: number = myWins * 80 - (oppWins > 0 ? 100000 : 0) - oppWins * 500 + (10 - Math.abs(c3 - center));
      if (s > bestS) {
        bestS = s;
        pick = c3;
      }
    }
    return pick;
  }

  /** 提示：报「下第几列」（列号就是玩家要点的东西） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.busy) {
      return Hint.none(TG('等电脑落子'));
    }
    const c: number = this.bestCol();
    if (c < 0) {
      return Hint.none('none');
    }
    return Hint.make([c],
      TG2('下第 {0} 列（从左数）', String(c + 1)),
      TG2('Play column {0} from the left', String(c + 1)), t0);
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
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
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
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(c); }); })
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
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((c)); }); })
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
      // ★ 2026-10-31 真机：宽驱动 + 无高度上限 ⇒ 横屏 853×533 上棋盘撑到 813vp 高，
      //   把「重开」等按钮挤出屏幕。限高让它按 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
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
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('点任意一列（或箭头）投子，横、竖、斜先连成四个就赢'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
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
