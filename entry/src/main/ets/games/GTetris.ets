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
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

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
  }

  onRestart(): void {
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
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

  build() {
    Column({ space: Space.md }) {
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
            this.reset();
          })
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
  }

  private cellColor(i: number): string {
    const v: number = i < this.view.length ? this.view[i] : 0;
    if (v === 0) {
      return this.theme.isDark ? '#15151F' : '#F8FAFC';
    }
    return COLORS[v];
  }
}
