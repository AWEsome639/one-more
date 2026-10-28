/**
 * 井字棋 —— 你执 ✕，电脑执 ○，三子连线者胜
 *
 * 玩法：点空格落子，电脑用极小化极大（minimax）应对，赢不了它
 * 判据：你连成三子 ⇒ 通关；电脑连成三子或平局 ⇒ 这一局没赢
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
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
import { Tv } from '../core/Tv';

const N: number = 3;
const CELLS: number = N * N;
const HUMAN: number = 1;
const AI: number = 2;
const TICK_MS: number = 1000;
const AI_DELAY: number = 350;
const GAP: number = 6;
const KEY_H: number = 46;

const LINES: number[][] = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6]
];

/** 谁赢了：0 无人，1 我，2 电脑 */
function winnerOf(cells: number[]): number {
  for (let i = 0; i < LINES.length; i++) {
    const L: number[] = LINES[i];
    const a: number = cells[L[0]];
    if (a !== 0 && a === cells[L[1]] && a === cells[L[2]]) {
      return a;
    }
  }
  return 0;
}

function full(cells: number[], size: number): boolean {
  for (let i = 0; i < size * size; i++) {
    if (cells[i] === 0) {
      return false;
    }
  }
  return true;
}

/** 局面评分：电脑赢为正、我赢为负；depth 让电脑偏爱快赢慢输 */
// ★★ 2026-10-13 修复（奥森：「电脑的水平实在是太低了」）：
//   原来 AI 用【硬编码 CELLS=9】搜，但难度可以把棋盘改成 4×4/5×5
//   ⇒ 棋盘变大后 AI 只搜前 9 格，完全看不到新的行列 ⇒ 下得毫无道理 ✗
//   ⇒ 改成【按实际尺寸搜】（size 参数）
function score(cells: number[], turn: number, depth: number, alpha: number, beta: number, size: number): number {
  const w: number = winnerOf(cells);
  if (w === AI) {
    return 10 - depth;
  }
  if (w === HUMAN) {
    return depth - 10;
  }
  if (full(cells, size)) {
    return 0;
  }
  if (turn === AI) {
    let best: number = -999;
    for (let i = 0; i < size * size; i++) {
      if (cells[i] !== 0) {
        continue;
      }
      const next: number[] = cells.slice();
      next[i] = AI;
      const s: number = score(next, HUMAN, depth + 1, alpha, beta, size);
      if (s > best) {
        best = s;
      }
      if (best > alpha) {
        alpha = best;
      }
      if (alpha >= beta) {
        break;                 // α-β 剪枝
      }
    }
    return best;
  }
  let worst: number = 999;
  for (let i = 0; i < size * size; i++) {
    if (cells[i] !== 0) {
      continue;
    }
    const next: number[] = cells.slice();
    next[i] = HUMAN;
    const s: number = score(next, AI, depth + 1, alpha, beta, size);
    if (s < worst) {
      worst = s;
    }
    if (worst < beta) {
      beta = worst;
    }
    if (alpha >= beta) {
      break;                   // α-β 剪枝
    }
  }
  return worst;
}

function bestMove(cells: number[], size: number): number {
  let bestS: number = -999;
  let bestI: number = -1;
  let alpha: number = -999;
  for (let i = 0; i < size * size; i++) {
    if (cells[i] !== 0) {
      continue;
    }
    const next: number[] = cells.slice();
    next[i] = AI;
    const s: number = score(next, HUMAN, 1, alpha, 999, size);
    if (s > bestS) {
      bestS = s;
      bestI = i;
    }
    if (s > alpha) {
      alpha = s;
    }
  }
  return bestI;
}

@Component
export struct GTicTacToe {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(3);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private winLine: number[] = [];
  @State private status: string = '';
  @State private score0: number = 0;
  @State private steps: number = 0;
  @State private seconds: number = 0;
  @State private thinking: boolean = false;
  @State private over: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private aiTimer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机对局：对方的落子 = 本局「AI 的那一步」
    LanMatch.setHandler((d: string) => {
      const i: number = Number.parseInt(d, 10);
      if (isNaN(i) || this.over || this.finished || this.valAt(i) !== 0) {
        return;
      }
      const nx: number[] = this.cells.slice();
      nx[i] = AI;
      this.cells = nx;
      this.steps = this.steps + 1;
      if (!this.checkEnd()) {
        this.status = TG('轮到你，点一格落 ✕');
      }
    });
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTicTacToe')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
    this.reset();
  }

  aboutToDisappear(): void {
    this.cleanup();
  }

  private cleanup(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.aiTimer >= 0) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  private reset(): void {
    this.cleanup();
    // ★★ 2026-10-13 修复：原来写死 CELLS=9 ⇒ 棋盘 4×4 时数组不够长 ✗
    //   改成按实际边长开（难度可以改棋盘大小）
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    this.cells = new Array<number>(n2 * n2).fill(0);
    this.winLine = [];
    this.score0 = 0;
    this.steps = 0;
    this.seconds = 0;
    this.thinking = false;
    this.over = false;
    this.finished = false;
    this.status = TG('你先手，点一格落 ✕');
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.over && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private valAt(i: number): number {
    return i >= 0 && i < this.cells.length ? this.cells[i] : 0;
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
    if (this.thinking || this.finished || this.humanMove() < 0) {
      return true;                       // 电脑在想 / 已结束 / 没有空格 ⇒ 这一拍不动
    }
    this.tap(this.humanMove());
    return !this.over;
  }

  /** 代打与提示共用：从「我」这边选一格（① 直接赢 ② 堵对手 ③ 启发式） */
  private humanMove(): number {
    const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const size: number = n * n;
    for (let i = 0; i < size; i++) {
      if (this.cells[i] !== 0) {
        continue;
      }
      const t: number[] = this.cells.slice();
      t[i] = HUMAN;
      if (winnerOf(t) === HUMAN) {
        return i;                       // ① 这一手就能连成
      }
    }
    for (let i = 0; i < size; i++) {
      if (this.cells[i] !== 0) {
        continue;
      }
      const t: number[] = this.cells.slice();
      t[i] = AI;
      if (winnerOf(t) === AI) {
        return i;                       // ② 电脑下一手就能连 ⇒ 必须先堵
      }
    }
    let best: number = -1;
    let bestV: number = -1e9;
    for (let i = 0; i < size; i++) {
      if (this.cells[i] !== 0) {
        continue;
      }
      const v: number = this.linePot(i, HUMAN) * 2 + this.linePot(i, AI) * 1.5;
      if (v > bestV) {
        bestV = v;
        best = i;
      }
    }
    return best;
  }

  /** 经过第 i 格、还没被对手占的线，累计「自己已有几子」的平方（越接近成线越贵） */
  private linePot(i: number, who: number): number {
    let sum: number = 0;
    for (let k = 0; k < LINES.length; k++) {
      const L: number[] = LINES[k];
      if (L[0] !== i && L[1] !== i && L[2] !== i) {
        continue;
      }
      let mine: number = 0;
      let blocked: boolean = false;
      for (let j = 0; j < 3; j++) {
        const v: number = L[j] < this.cells.length ? this.cells[L[j]] : 0;
        if (v === who) {
          mine++;
        } else if (v !== 0) {
          blocked = true;
        }
      }
      if (!blocked) {
        sum = sum + (mine + 1) * (mine + 1);
      }
    }
    return sum;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.finished) {
      return Hint.none('none');
    }
    if (this.thinking) {
      return Hint.make([], TG('电脑正在想，等它落子再看'),
        'The computer is thinking', t0);
    }
    const i: number = this.humanMove();
    if (i < 0) {
      return Hint.none('none');
    }
    const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const r: string = String(Math.floor(i / n) + 1);
    const c: string = String(i % n + 1);
    const probe: number[] = this.cells.slice();
    probe[i] = HUMAN;
    const wins: boolean = winnerOf(probe) === HUMAN;
    const t2: number[] = this.cells.slice();
    t2[i] = AI;
    const mustBlock: boolean = winnerOf(t2) === AI;
    if (wins) {
      return Hint.make([i],
        TG2('落第 {0} 行第 {1} 列 —— 这一手直接连成 ✕', r, c),
        'Play row ' + r + ', column ' + c + ' to win', t0);
    }
    if (mustBlock) {
      return Hint.make([i],
        TG2('电脑下一手就能连 —— 必须堵第 {0} 行第 {1} 列', r, c),
        'Block at row ' + r + ', column ' + c, t0);
    }
    return Hint.make([i],
      TG2('落第 {0} 行第 {1} 列：既是最长的自己的线，也最挡电脑', r, c),
      'Play row ' + r + ', column ' + c, t0);
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
    if (this.over || this.finished || this.thinking || this.valAt(i) !== 0) {
      return;
    }
    // ★ 联机时：不是我的回合就不接受点击
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      this.status = TG('等对手落子…');
      return;
    }
    const next: number[] = this.cells.slice();
    next[i] = HUMAN;
    this.cells = next;
    this.steps = this.steps + 1;
    // ★ 联机时：把这一步发给对方，然后**不跑 AI**（对手就是那个人）
    if (LanMatch.isActive()) {
      LanMatch.record(String(i));
      if (this.checkEnd()) {
        return;
      }
      this.status = TG('等对手落子…');
      return;
    }
    if (this.checkEnd()) {
      return;
    }
    this.thinking = true;
    this.status = TG('电脑在想…');
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      this.aiTurn();
    }, AI_DELAY);
  }

  private aiTurn(): void {
    if (this.over || this.finished) {
      return;
    }
    const move: number = bestMove(this.cells, this.diffTotal);
    if (move >= 0) {
      const next: number[] = this.cells.slice();
      next[move] = AI;
      this.cells = next;
      this.steps = this.steps + 1;
    }
    this.thinking = false;
    if (!this.checkEnd()) {
      this.status = TG('轮到你，点一格落 ✕');
    }
  }

  /** 结算检查；返回是否已分出结果 */
  private checkEnd(): boolean {
    const w: number = winnerOf(this.cells);
    if (w !== 0) {
      const line: number[] = [];
      for (let i = 0; i < LINES.length; i++) {
        const L: number[] = LINES[i];
        if (this.cells[L[0]] === w && this.cells[L[1]] === w && this.cells[L[2]] === w) {
          line.push(L[0]);
          line.push(L[1]);
          line.push(L[2]);
        }
      }
      this.winLine = line;
      this.over = true;
      this.thinking = false;
      if (w === HUMAN) {
        this.score0 = 100;
        this.status = TG('🎉 三子连线，你赢了！');
        this.finish(true);
      } else {
        this.score0 = 0;
        this.status = TG('电脑连线了，再来一局？');
        this.finish(false);
      }
      return true;
    }
    if (full(this.cells, this.diffTotal > 1 ? this.diffTotal : 2)) {
      this.over = true;
      this.thinking = false;
      this.score0 = 40;
      this.status = TG('平局，谁也没连成');
      this.finish(false);
      return true;
    }
    return false;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.cleanup();
    const r: GameResult = {
      gameId: 'tic_tac_toe',
      solved: solved,
      score: this.score0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.steps
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
        Text(true ? TG('得分') : (false ? TG('步数') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(true ? String(this.score0)
        : (false ? String(this.steps) : (this.seconds + 's')))
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
        Text(false ? TG('得分') : (true ? TG('步数') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? String(this.score0)
        : (true ? String(this.steps) : (this.seconds + 's')))
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
        Text(false ? TG('得分') : (false ? TG('步数') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? String(this.score0)
        : (false ? String(this.steps) : (this.seconds + 's')))
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

      Column({ space: GAP }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: GAP }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.markOf((r * this.diffTotal + c)))
              .fontSize(FontSize.xxxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.valAt((r * this.diffTotal + c)) === HUMAN ? Palette.rose : Palette.sky)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * this.diffTotal + c)))
              .borderRadius(Radius.md)
              .scale({ x: this.inWin((r * this.diffTotal + c)) ? 1.05 : 1, y: this.inWin((r * this.diffTotal + c)) ? 1.05 : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('82%')
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor('#1AEC4899')
      .borderRadius(Radius.lg)

      Text(this.status)
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.over ? Palette.emerald : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Button(TG('我认输'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .enabled(!this.over && !this.finished)
          .onClick(() => {
            Haptics.tap();
            if (!this.over && !this.finished) {
              this.over = true;
              this.status = TG('已认输');
              this.finish(false);
            }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (!this.over && !this.finished) { this.over = true; this.status = TG('已认输'); this.finish(false); } }); })
      }
      .width('100%')

      Text(TG('电脑走的是最优解，最好的结果是平局'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }





  private markOf(i: number): string {
    const v: number = this.valAt(i);
    return v === 0 ? '' : (v === HUMAN ? '✕' : '○');
  }

  private inWin(i: number): boolean {
    for (let k = 0; k < this.winLine.length; k++) {
      if (this.winLine[k] === i) {
        return true;
      }
    }
    return false;
  }

  private cellBg(i: number): string {
    if (this.inWin(i)) {
      return this.theme.isDark ? '#1E3A2F' : '#D1FAE5';
    }
    return this.theme.surface;
  }
}
