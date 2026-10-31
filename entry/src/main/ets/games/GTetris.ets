/**
 * 俄罗斯方块 —— 经典落块消行
 *
 * 玩法：← → 移动、↻ 旋转、⤓ 速降；每消 1 行加分，等级越高落得越快
 * 判据：消满 10 行 ⇒ 通关；方块堆到顶 ⇒ 失败
 * 实现：4×4 方阵表示 7 种方块，顺时针旋转用 n[r][c] = m[3-c][r]
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const COLS: number = 10;
const ROWS: number = 16;
const CELLS: number = COLS * ROWS;
const GOAL_LINES: number = 10;   // 难度会覆盖它      // 消满 10 行通关
const TICK_MS: number = 120;   // 难度会覆盖它        // 心跳
const DROP_TICKS: number = 5;       // 每 5 个心跳落一格（等级越高越少）
const MIN_TICKS: number = 1;
const GAP: number = 1;
const KEY_H: number = 46;

/** 7 种方块（4×4 方阵，1 表示占据；统一放在第 1~2 行） */
const PIECES: number[][] = [
  [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0],   // I
  [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0],   // O
  [0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0],   // T
  [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0],   // S
  [0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0],   // Z
  [0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0],   // J
  [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0]    // L
];

const COLORS: string[] = [
  '#00000000', Palette.sky, Palette.amber, Palette.violet,
  Palette.emerald, Palette.rose, Palette.orange, Palette.cyan
];

const SCORES: number[] = [0, 100, 300, 500, 800];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

const ROWS_IDX: number[] = range(ROWS);
const COLS_IDX: number[] = range(COLS);

/** 顺时针旋转 4×4 方阵 */
function spin(m: number[]): number[] {
  const out: number[] = new Array<number>(16).fill(0);
  for (let r = 0; r < 4; r++) {
    for (let c = 0; c < 4; c++) {
      out[r * 4 + c] = m[(3 - c) * 4 + r];
    }
  }
  return out;
}

@Component
export struct GTetris {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：通关行数 + 下落速度
  //   （简单 6 行/160ms 从容 · 普通 10 行/120ms · 困难 14 行/90ms 更快）
  private goalLines: number = GameDiff.pick(6, 10, 14);
  private tickMs: number = GameDiff.pick(160, 120, 90);
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private view: number[] = [];
  @State private cur: number[] = [];              // 当前方块 4×4
  @State private curColor: number = 1;
  @State private nextType: number = 0;
  @State private score: number = 0;
  @State private lines: number = 0;
  @State private status: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private board: number[] = [];
  private px: number = 3;
  private py: number = 0;
  private tickCount: number = 0;
  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTetris')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
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
    if (this.over) {
      return true;
    }
    this.aiPlay(0);
    return !this.over;
  }

  /** 提示：这块砖该怎么摆 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.cur.length !== 16) { return Hint.none('none'); }
    let bestRot: number = 0;
    let bestScore: number = -1000000;
    let bestX: number = this.px;
    for (let k = 0; k < 4; k++) {
      let shape: number[] = this.cur.slice();
      for (let t = 0; t < k; t++) { shape = spin(shape); }
      const x: number = this.aiBestXOf(shape);
      const sc: number = this.aiEval(shape, x);
      if (sc > bestScore) { bestScore = sc; bestRot = k; bestX = x; }
    }
    return Hint.make([], TG2('这块砖转 {0} 次，落到从数第 {1} 列最划算', String(bestRot), String(bestX + 1)),
      TG2('Rotate {0} time(s), drop at column {1}', String(bestRot), String(bestX + 1)), t0);
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

  private reset(): void {
    this.stopTimer();
    this.board = new Array<number>(CELLS).fill(0);
    this.score = 0;
    this.lines = 0;
    this.over = false;
    this.won = false;
    this.tickCount = 0;
    this.finished = false;
    this.status = TG('← → 移动，↻ 旋转，⤓ 速降');
    this.nextType = Math.floor(Math.random() * PIECES.length);
    this.spawn();
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      this.tick();
    }, this.tickMs);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private level(): number {
    return 1 + Math.floor(this.lines / 5);
  }

  private dropTicks(): number {
    const t: number = DROP_TICKS - (this.level() - 1);
    return t < MIN_TICKS ? MIN_TICKS : t;
  }

  private tick(): void {
    if (this.over || this.finished) {
      return;
    }
    this.tickCount = this.tickCount + 1;
    if (this.tickCount < this.dropTicks()) {
      return;
    }
    this.tickCount = 0;
    if (this.canPlace(this.cur, this.px, this.py + 1)) {
      this.py = this.py + 1;
      this.sync();
    } else {
      this.lock();
    }
  }

  private canPlace(shape: number[], px: number, py: number): boolean {
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        if (shape[r * 4 + c] === 0) {
          continue;
        }
        const x: number = px + c;
        const y: number = py + r;
        if (x < 0 || x >= COLS || y >= ROWS) {
          return false;
        }
        if (y >= 0 && this.board[y * COLS + x] !== 0) {
          return false;
        }
      }
    }
    return true;
  }

  /** 把棋盘 + 当前方块合成一张显示数组 */
  private sync(): void {
    const view: number[] = this.board.slice();
    if (!this.over && this.cur.length === 16) {
      for (let r = 0; r < 4; r++) {
        for (let c = 0; c < 4; c++) {
          if (this.cur[r * 4 + c] === 0) {
            continue;
          }
          const x: number = this.px + c;
          const y: number = this.py + r;
          if (x >= 0 && x < COLS && y >= 0 && y < ROWS) {
            view[y * COLS + x] = this.curColor;
          }
        }
      }
    }
    this.view = view;
  }

  private spawn(): void {
    const type: number = this.nextType;
    this.nextType = Math.floor(Math.random() * PIECES.length);
    this.cur = PIECES[type].slice();
    this.curColor = type + 1;
    this.px = 3;
    this.py = 0;
    if (!this.canPlace(this.cur, this.px, this.py)) {
      this.over = true;
      this.status = TG('方块堆到顶了');
      this.sync();
      this.finish(false);
      return;
    }
    this.sync();
  }

  private move(dx: number): void {
    if (this.over || this.finished) {
      return;
    }
    if (this.canPlace(this.cur, this.px + dx, this.py)) {
      this.px = this.px + dx;
      this.sync();
    }
  }

  private turn(): void {
    if (this.over || this.finished) {
      return;
    }
    const spun: number[] = spin(this.cur);
    const kicks: number[] = [0, -1, 1, -2, 2];
    for (let i = 0; i < kicks.length; i++) {
      const nx: number = this.px + kicks[i];
      if (this.canPlace(spun, nx, this.py)) {
        this.cur = spun;
        this.px = nx;
        this.sync();
        return;
      }
    }
  }

  private drop(): void {
    if (this.over || this.finished) {
      return;
    }
    if (this.canPlace(this.cur, this.px, this.py + 1)) {
      this.py = this.py + 1;
      this.score = this.score + 1;
      this.sync();
    } else {
      this.lock();
    }
  }

  private lock(): void {
    const board: number[] = this.board.slice();
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        if (this.cur[r * 4 + c] === 0) {
          continue;
        }
        const x: number = this.px + c;
        const y: number = this.py + r;
        if (x >= 0 && x < COLS && y >= 0 && y < ROWS) {
          board[y * COLS + x] = this.curColor;
        }
      }
    }
    this.board = board;
    const cleared: number = this.clearLines();
    this.lines = this.lines + cleared;
    this.score = this.score + SCORES[cleared] * this.level() + 10;
    this.tickCount = 0;

    if (this.lines >= this.goalLines) {
      this.won = true;
      this.over = true;
      this.status = TG2('🎉 消满 {0} 行，通关！', this.goalLines);
      this.sync();
      this.finish(true);
      return;
    }
    this.status = cleared > 0 ? TG2("消掉 {0} 行！", cleared) : '继续加油';
    this.spawn();
  }

  /** 消掉满行，返回消掉的行数 */
  private clearLines(): number {
    const board: number[] = this.board;
    const kept: number[] = [];
    let cleared: number = 0;
    for (let r = 0; r < ROWS; r++) {
      let full: boolean = true;
      for (let c = 0; c < COLS; c++) {
        if (board[r * COLS + c] === 0) {
          full = false;
          break;
        }
      }
      if (full) {
        cleared++;
      } else {
        for (let c = 0; c < COLS; c++) {
          kept.push(board[r * COLS + c]);
        }
      }
    }
    const next: number[] = new Array<number>(CELLS).fill(0);
    const offset: number = CELLS - kept.length;
    for (let i = 0; i < kept.length; i++) {
      next[offset + i] = kept[i];
    }
    this.board = next;
    return cleared;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const r: GameResult = {
      gameId: 'tetris',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.level()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** AI 用：模拟「这个朝向落在第 x 列」，给一个局面分（消行多、堆得平、孔少） */
  private aiEval(shape: number[], x: number): number {
    if (!this.canPlace(shape, x, 0)) { return -1000000; }
    let y: number = 0;
    while (y + 1 < ROWS && this.canPlace(shape, x, y + 1)) { y = y + 1; }
    const b: number[] = this.board.slice();
    for (let r = 0; r < 4; r++) {
      for (let c = 0; c < 4; c++) {
        if (shape[r * 4 + c] === 0) { continue; }
        const bx: number = x + c;
        const by: number = y + r;
        if (bx >= 0 && bx < COLS && by >= 0 && by < ROWS) { b[by * COLS + bx] = 1; }
      }
    }
    let lines: number = 0;
    const kept: number[] = [];
    for (let r = 0; r < ROWS; r++) {
      let full: boolean = true;
      for (let c = 0; c < COLS; c++) {
        if (b[r * COLS + c] === 0) { full = false; break; }
      }
      if (full) {
        lines = lines + 1;
      } else {
        for (let c = 0; c < COLS; c++) { kept.push(b[r * COLS + c]); }
      }
    }
    const nb: number[] = new Array<number>(CELLS).fill(0);
    const off: number = CELLS - kept.length;
    for (let i = 0; i < kept.length; i++) { nb[off + i] = kept[i]; }
    let agg: number = 0;
    let holes: number = 0;
    const h: number[] = new Array<number>(COLS).fill(0);
    for (let c = 0; c < COLS; c++) {
      let seen: boolean = false;
      for (let r = 0; r < ROWS; r++) {
        if (nb[r * COLS + c] !== 0) {
          if (!seen) { h[c] = ROWS - r; seen = true; }
        } else if (seen) {
          holes = holes + 1;
        }
      }
      agg = agg + h[c];
    }
    let bump: number = 0;
    for (let c = 0; c + 1 < COLS; c++) { bump = bump + Math.abs(h[c] - h[c + 1]); }
    return lines * 120 - agg * 2 - holes * 40 - bump * 2;
  }

  /** AI 用：这个朝向落到哪一列分最高 */
  private aiBestXOf(shape: number[]): number {
    let bx: number = this.px;
    let best: number = -1000000;
    for (let x = 0; x < COLS; x++) {
      const sc: number = this.aiEval(shape, x);
      if (sc > best) { best = sc; bx = x; }
    }
    return bx;
  }

  /** AI 用：挑朝向 → 转 → 横移到最好的列 → 速降到底（一块砖一次做完） */
  private aiPlay(_d: number): void {
    if (this.cur.length !== 16) { return; }
    let bestRot: number = 0;
    let bestScore: number = -1000000;
    for (let k = 0; k < 4; k++) {
      let shape: number[] = this.cur.slice();
      for (let t = 0; t < k; t++) { shape = spin(shape); }
      const sc: number = this.aiEval(shape, this.aiBestXOf(shape));
      if (sc > bestScore) { bestScore = sc; bestRot = k; }
    }
    for (let i = 0; i < bestRot; i++) { this.turn(); }
    const tx: number = this.aiBestXOf(this.cur);
    let guard: number = 0;
    while (this.px !== tx && guard < COLS + 4) {
      const before: number = this.px;
      this.move(this.px < tx ? 1 : -1);
      guard = guard + 1;
      if (this.px === before) { break; }
    }
    guard = 0;
    while (guard < ROWS + 4 && this.canPlace(this.cur, this.px, this.py + 1)) {
      this.drop();
      guard = guard + 1;
    }
    if (!this.over && !this.finished) { this.drop(); }
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
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      Column({ space: GAP }) {
        ForEach(ROWS_IDX, (r: number) => {
          Row({ space: GAP }) {
            ForEach(COLS_IDX, (c: number) => {
              this.cellView(r * COLS + c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(COLS / ROWS)
      // ★ 2026-10-31 真机：宽驱动 + 无高度上限 ⇒ 横屏 853×533 上棋盘撑到 813vp 高，
      //   把「重开」等按钮挤出屏幕。限高让它按 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Bp.height - 300 })
      .padding(GAP)
      .backgroundColor(this.theme.isDark ? '#0B0B12' : '#E2E8F0')
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        this.ctl('←', 0)
        this.ctl('↻', 1)
        this.ctl('→', 2)
        this.ctl(TG('⤓ 落'), 3)
      }
      .width('100%')

      Row({ space: Space.sm }) {
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
        Text(this.status)
          .fontSize(FontSize.sm)
          .fontColor(this.over ? Palette.danger : this.theme.inkSoft)
          .layoutWeight(2)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Text(TG2('目标：消满 {0} 行通关；堆到顶就输了', this.goalLines))
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

  /** kind: 0=得分 1=消行 2=等级 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('得分') : (kind === 1 ? '消行' : '等级'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.score)
        : (kind === 1 ? (this.lines + '/' + this.goalLines) : String(this.level())))
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

  @Builder
  cellView(i: number) {
    Stack()
      .layoutWeight(1)
      .aspectRatio(1)
      .backgroundColor(this.cellColor(i))
      .borderRadius(Radius.xs)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  ctl(label: string, kind: number) {
    Text(label)
      .fontSize(FontSize.lg)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(kind === 3 ? 2 : 1)
      .height(KEY_H)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .onClick(() => {
        Haptics.tick();
        if (kind === 0) {
          this.move(-1);
        } else if (kind === 1) {
          this.turn();
        } else if (kind === 2) {
          this.move(1);
        } else {
          this.drop();
        }
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (kind === 0) { this.move(-1); } else if (kind === 1) { this.turn(); } else if (kind === 2) { this.move(1); } else { this.drop(); } }); })
  }

  private cellColor(i: number): string {
    const v: number = i < this.view.length ? this.view[i] : 0;
    if (v === 0) {
      return this.theme.isDark ? '#15151F' : '#F8FAFC';
    }
    return COLORS[v];
  }
}
