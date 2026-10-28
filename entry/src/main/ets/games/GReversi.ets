/**
 * 黑白棋（Reversi / Othello）—— 夹住翻面
 *
 * 规则：你执黑先行，落子后把同一直线上被夹住的白子全部翻黑；无处可下就跳过。
 * 结算：双方都无处可下（或棋盘下满）时数子；黑多 ⇒ 通关，白多 ⇒ 失败。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 8;
const EMPTY: number = 0;
const BLACK: number = 1;      // 玩家
const WHITE: number = 2;      // 电脑
const R8: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
const DIRS: number[][] = [
  [-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]
];
const AI_DELAY: number = 420;
const BTN_H: number = 46;


/**
 * ★★ 2026-10-13 AI 拔高（奥森：「电脑的水平实在是太低了」）
 *
 * 黑白棋 AI 的标准起手式（依据 knowledge/cards/棋类AI-算法与难度分级.md）：
 *   ① ★ 位置价值表 —— 黑白棋**最关键**的一条，比"翻多少子"重要得多
 *      角 = 最稳（占住就翻不掉）⇒ +100
 *      角邻 = 最危险（送给对手占角）⇒ −25
 *      边 = 较稳 ⇒ +8
 *      次外圈 = 较危险 ⇒ −3
 *      其余 ⇒ +1
 *      ⚠️ 按棋盘尺寸【程序化生成】⇒ 9×9/11×11 都适用
 *   ② ★ 行动力（mobility）—— 让【对手的可选步数】越少越好
 *      这是黑白棋"闷死对手"的核心：不是翻得多，而是让对手没得下
 *
 * 原来只算 `翻子数 + 角×8` ⇒ 会为了多翻两子把角送给对手 ⇒ 显得很弱
 */
function posWeight(size: number, r: number, c: number): number {
  const isCorner: boolean = (r === 0 || r === size - 1) && (c === 0 || c === size - 1);
  if (isCorner) {
    return 100;
  }
  const nearCorner: boolean = (r <= 1 && c <= 1) || (r <= 1 && c >= size - 2)
    || (r >= size - 2 && c <= 1) || (r >= size - 2 && c >= size - 2);
  if (nearCorner) {
    return -25;
  }
  const onEdge: boolean = r === 0 || c === 0 || r === size - 1 || c === size - 1;
  if (onEdge) {
    return 8;
  }
  const nearEdge: boolean = r === 1 || c === 1 || r === size - 2 || c === size - 2;
  if (nearEdge) {
    return -3;
  }
  return 1;
}

@Component
export struct GReversi {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=8）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(8);

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private turn: number = BLACK;
  @State private legalNow: number[] = [];
  @State private bCount: number = 2;
  @State private wCount: number = 2;
  @State private hands: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private to: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机对局：对方走白方 —— 收到就当成「电脑的那一步」应用
    LanMatch.setHandler((d: string) => {
      const i: number = Number.parseInt(d, 10);
      if (isNaN(i) || this.over || this.turn !== WHITE) {
        return;
      }
      this.cells = this.place(this.cells, i, WHITE);
      this.hands++;
      this.turn = BLACK;
      this.refresh();
      // 双方都无处可下 ⇒ 结束；只有我无处可下 ⇒ 跳过
      const mine: number[] = this.legal(this.cells, BLACK);
      const theirs: number[] = this.legal(this.cells, WHITE);
      if (mine.length === 0 && theirs.length === 0) {
        this.end();
      } else if (mine.length === 0) {
        this.turn = WHITE;
        this.msg = TG('你无处可下，跳过这一手');
        this.refresh();
      } else {
        this.msg = TG('轮到你落子');
      }
    });
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GReversi')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearTo();
  }

  private clearTo(): void {
    if (this.to >= 0) {
      clearTimeout(this.to);
      this.to = -1;
    }
  }

  private reset(): void {
    this.clearTo();
    const a: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      a.push(EMPTY);
    }
    a[3 * this.diffTotal + 3] = WHITE;
    a[4 * this.diffTotal + 4] = WHITE;
    a[3 * this.diffTotal + 4] = BLACK;
    a[4 * this.diffTotal + 3] = BLACK;
    this.cells = a;
    this.turn = BLACK;
    this.hands = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('你执黑先行');
    this.refresh();
    this.startAt = Date.now();
    this.beginTurn();
  }

  /** 落子 i 能翻掉哪些子（空数组 = 不合法） */
  private flips(cells: number[], i: number, who: number): number[] {
    const out: number[] = [];
    if (cells[i] !== EMPTY) {
      return out;
    }
    const foe: number = who === BLACK ? WHITE : BLACK;
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    for (let d = 0; d < DIRS.length; d++) {
      const dr: number = DIRS[d][0];
      const dc: number = DIRS[d][1];
      const line: number[] = [];
      let rr: number = r + dr;
      let cc: number = c + dc;
      while (rr >= 0 && rr < this.diffTotal && cc >= 0 && cc < this.diffTotal && cells[rr * this.diffTotal + cc] === foe) {
        line.push(rr * this.diffTotal + cc);
        rr += dr;
        cc += dc;
      }
      if (line.length > 0 && rr >= 0 && rr < this.diffTotal && cc >= 0 && cc < this.diffTotal && cells[rr * this.diffTotal + cc] === who) {
        for (let k = 0; k < line.length; k++) {
          out.push(line[k]);
        }
      }
    }
    return out;
  }

  private legal(cells: number[], who: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < cells.length; i++) {
      if (this.flips(cells, i, who).length > 0) {
        out.push(i);
      }
    }
    return out;
  }

  private place(cells: number[], i: number, who: number): number[] {
    const next: number[] = cells.slice();
    next[i] = who;
    const f: number[] = this.flips(cells, i, who);
    for (let k = 0; k < f.length; k++) {
      next[f[k]] = who;
    }
    return next;
  }

  private refresh(): void {
    let b: number = 0;
    let w: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === BLACK) {
        b++;
      } else if (this.cells[i] === WHITE) {
        w++;
      }
    }
    this.bCount = b;
    this.wCount = w;
    this.legalNow = this.turn === BLACK ? this.legal(this.cells, BLACK) : [];
  }

  /** 谁该走、能不能走 */
  private beginTurn(): void {
    if (this.over) {
      return;
    }
    const mine: number[] = this.legal(this.cells, BLACK);
    const theirs: number[] = this.legal(this.cells, WHITE);
    if (mine.length === 0 && theirs.length === 0) {
      this.end();
      return;
    }
    if (this.turn === BLACK && mine.length === 0) {
      this.turn = WHITE;
      this.msg = TG('你无处可下，跳过这一手');
      this.refresh();
    } else if (this.turn === WHITE && theirs.length === 0) {
      this.turn = BLACK;
      this.msg = TG('电脑无处可下，跳过');
      this.refresh();
    }
    if (this.turn === WHITE) {
      this.clearTo();
      this.to = setTimeout(() => {
        this.to = -1;
        this.aiMove();
      }, AI_DELAY);
    } else {
      this.refresh();
      if (this.msg === '') {
        this.msg = TG('轮到你了');
      }
    }
  }

  /** 电脑：翻得多的优先，角额外加分 */
  private aiMove(): void {
    if (this.over) {
      return;
    }
    const moves: number[] = this.legal(this.cells, WHITE);
    if (moves.length === 0) {
      this.turn = BLACK;
      this.beginTurn();
      return;
    }
    let best: number = moves[0];
    let bestScore: number = -9999;
    for (let k = 0; k < moves.length; k++) {
      const i: number = moves[k];
      const r: number = Math.floor(i / this.diffTotal);
      const c: number = i % this.diffTotal;
      // ★★ 2026-10-13 AI 拔高：评分从"翻子数 + 角"改成标准的三项
      //   ① 位置权重（角 ≫ 边 ≫ 中心 ≫ 角邻）—— 黑白棋最关键
      //   ② 行动力：我下完之后【对手的可选步数】，越少越好（闷死对手）
      //   ③ 翻子数给小权重（黑白棋里翻得多≠优势，甚至常常是劣势）
      const w: number = posWeight(this.diffTotal, r, c);
      const flips: number = this.flips(this.cells, i, WHITE).length;
      const after: number[] = this.place(this.cells, i, WHITE);
      const oppMoves: number = this.legal(after, BLACK).length;
      const sc: number = w * 10 + flips * 1.5 - oppMoves * 12;
      if (sc > bestScore) {
        bestScore = sc;
        best = i;
      }
    }
    this.cells = this.place(this.cells, best, WHITE);
    this.hands++;
    this.turn = BLACK;
    this.msg = TG2('电脑落子（{0}）', (best + 1));
    this.refresh();
    this.beginTurn();
  }

  /** 代打：黑方该下哪一格（位置权重 + 行动力，跟内置白方同一套评法） */
  private autoPick(): number {
    if (this.over || this.turn !== BLACK) {
      return -1;
    }
    const moves: number[] = this.legal(this.cells, BLACK);
    if (moves.length === 0) {
      return -1;
    }
    let best: number = moves[0];
    let bestSc: number = -99999;
    for (let k = 0; k < moves.length; k++) {
      const i: number = moves[k];
      const r: number = Math.floor(i / this.diffTotal);
      const c: number = i % this.diffTotal;
      const w: number = posWeight(this.diffTotal, r, c);
      const flips: number = this.flips(this.cells, i, BLACK).length;
      const after: number[] = this.place(this.cells, i, BLACK);
      const oppMoves: number = this.legal(after, WHITE).length;
      const sc: number = w * 10 + flips * 1.5 - oppMoves * 12;
      if (sc > bestSc) {
        bestSc = sc;
        best = i;
      }
    }
    return best;
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
    if (this.over || this.turn !== BLACK || this.autoPick() < 0) {
      return true;
    }
    this.tap(this.autoPick());
    return !this.over;
  }

  // legalNow 就是这一手的全部合法落点 ⇒ 按位置权重挑最好的一个报出来
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.turn !== BLACK) {
      return Hint.none('none');
    }
    const i: number = this.autoPick();
    if (i < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    const flips: number = this.flips(this.cells, i, BLACK).length;
    return Hint.make([i], '下在第 ' + String(r + 1) + ' 行第 ' + String(c + 1) + ' 列，翻 ' + String(flips) + ' 子',
      'Play row ' + String(r + 1) + ', column ' + String(c + 1) + ' (flips ' + String(flips) + ')', t0);
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
    if (this.over || this.turn !== BLACK) {
      return;
    }
    if (this.legalNow.indexOf(i) < 0) {
      return;
    }
    // ★ 联机时：不是我的回合就不接受点击
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      this.msg = TG('等对手落子…');
      return;
    }
    this.cells = this.place(this.cells, i, BLACK);
    this.hands++;
    this.turn = WHITE;
    // ★ 联机时：把这一步发给对方，然后**不跑 AI**（白方就是那个人）
    if (LanMatch.isActive()) {
      LanMatch.record(String(i));
      this.msg = TG('等对手落子…');
      this.refresh();
      return;
    }
    this.msg = TG('电脑思考中…');
    this.refresh();
    this.beginTurn();
  }

  private end(): void {
    if (this.over) {
      return;
    }
    this.over = true;
    this.won = this.bCount > this.wCount;
    this.turn = EMPTY;
    this.clearTo();
    this.msg = this.won
      ? '🎉 你赢了 ' + this.bCount + ':' + this.wCount
      : (this.bCount === this.wCount
        ? '🤝 平局 ' + this.bCount + ':' + this.wCount
        : TG2('😵 你输了 {0}:{1}', this.bCount, this.wCount));
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'reversi',
      solved: solved,
      score: this.bCount * 20 + (solved ? 150 : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.bCount
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('你（黑）'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.bCount), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('电脑（白）'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wCount), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('手数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hands), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              if (this.cells[(r) * this.diffTotal + (c)] !== EMPTY) {
              Row()
              .width('76%')
              .aspectRatio(1)
              .backgroundColor(this.cells[(r) * this.diffTotal + (c)] === BLACK ? '#111827' : '#FFFFFF').animation({ duration: Motion.fast, curve: Motion.snap() })
              .borderRadius(Radius.full)
              .shadow(Shadow.card)
              } else if (this.legalNow.indexOf((r) * this.diffTotal + (c)) >= 0) {
              Row()
              .width('24%')
              .aspectRatio(1)
              .backgroundColor('#88FFFFFF')
              .borderRadius(Radius.full)
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r) * this.diffTotal + (c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r) * this.diffTotal + (c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#0B3B2E' : Palette.emerald)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.sky)
        .borderRadius(Radius.md)
        .width('100%')
        .height(BTN_H)
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('点浅色提示点落子；棋盘下满或双方都无处可下时结算'))
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




}
