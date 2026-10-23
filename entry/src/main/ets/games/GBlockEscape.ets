/**
 * 华容道逃脱 —— 6×6 停车场，把 🚗 挪到右边出口
 *
 * 玩法：点一个方块选中 → 用 ← ↑ ↓ → 沿它自己的方向推一格（车只能顺着车身走）
 * 判据：🚗 挪到最右侧出口 ⇒ 通关；步数太多可以重来；「认输」结束本局
 * 出题：基准局（出口被挡）做随机游走打乱 —— 每一步都可逆 ⇒ 必定有解
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const GRID: number = 6;
const CELLS: number = GRID * GRID;
const TARGET: number = 0;          // 🚗 就是 0 号方块，第 3 行（y=2）
const SCRAMBLE: number = 45;       // 打乱步数
const TICK_MS: number = 1000;
const GAP: number = 3;
const KEY_H: number = 46;

/** 基准局：🚗 在 (0,2)，出口那条路被 1、2 号挡住 */
const BASE_X: number[] = [0, 3, 4, 5, 0, 1, 3, 0];
const BASE_Y: number[] = [2, 0, 1, 3, 4, 0, 4, 0];
const BASE_LEN: number[] = [2, 3, 2, 3, 3, 2, 2, 2];
const BASE_HOR: boolean[] = [true, false, false, false, true, false, true, false];

const CAR_COLORS: string[] = [
  Palette.rose, Palette.sky, Palette.amber, Palette.violet,
  Palette.emerald, Palette.cyan, Palette.orange, Palette.primary
];

function occupancy(x: number[], y: number[], len: number[], hor: boolean[]): number[] {
  const occ: number[] = new Array<number>(CELLS).fill(-1);
  for (let b = 0; b < x.length; b++) {
    for (let k = 0; k < len[b]; k++) {
      const cx: number = hor[b] ? x[b] + k : x[b];
      const cy: number = hor[b] ? y[b] : y[b] + k;
      if (cx >= 0 && cx < GRID && cy >= 0 && cy < GRID) {
        occ[cy * GRID + cx] = b;
      }
    }
  }
  return occ;
}

/** dir: 0 左 1 右 2 上 3 下 */
function canMove(x: number[], y: number[], len: number[], hor: boolean[], b: number, dir: number): boolean {
  let dx: number = 0;
  let dy: number = 0;
  if (dir === 0) {
    dx = -1;
  } else if (dir === 1) {
    dx = 1;
  } else if (dir === 2) {
    dy = -1;
  } else {
    dy = 1;
  }
  if (hor[b] && dy !== 0) {
    return false;
  }
  if (!hor[b] && dx !== 0) {
    return false;
  }
  const occ: number[] = occupancy(x, y, len, hor);
  for (let k = 0; k < len[b]; k++) {
    const cx: number = (hor[b] ? x[b] + k : x[b]) + dx;
    const cy: number = (hor[b] ? y[b] : y[b] + k) + dy;
    if (cx < 0 || cx >= GRID || cy < 0 || cy >= GRID) {
      return false;
    }
    const v: number = occ[cy * GRID + cx];
    if (v >= 0 && v !== b) {
      return false;
    }
  }
  return true;
}

/** 直接改数组的推一步（只在打乱时用） */
function push(x: number[], y: number[], len: number[], hor: boolean[], b: number, dir: number): boolean {
  if (!canMove(x, y, len, hor, b, dir)) {
    return false;
  }
  if (dir === 0) {
    x[b] = x[b] - 1;
  } else if (dir === 1) {
    x[b] = x[b] + 1;
  } else if (dir === 2) {
    y[b] = y[b] - 1;
  } else {
    y[b] = y[b] + 1;
  }
  return true;
}

@Component
export struct GBlockEscape {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：SCRAMBLE 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(SCRAMBLE);
  onFinish: (r: GameResult) => void = () => {};

  @State private occ: number[] = [];
  @State private sel: number = TARGET;
  @State private moves: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;

  private bx: number[] = [];
  private by: number[] = [];
  private blen: number[] = [];
  private bhor: boolean[] = [];
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(SCRAMBLE);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    const x: number[] = BASE_X.slice();
    const y: number[] = BASE_Y.slice();
    const len: number[] = BASE_LEN.slice();
    const hor: boolean[] = BASE_HOR.slice();

    // 随机游走打乱：可逆 ⇒ 一定有解；顺便保证 🚗 一开始逃不出去
    let guard: number = 0;
    while (guard < 60) {
      guard++;
      let steps: number = 0;
      let inner: number = 0;
      while (steps < this.diffTotal && inner < 500) {
        inner++;
        const b: number = Math.floor(Math.random() * x.length);
        const dir: number = Math.floor(Math.random() * 4);
        if (push(x, y, len, hor, b, dir)) {
          steps++;
        }
      }
      if (x[TARGET] + len[TARGET] < GRID) {
        break;
      }
    }

    this.bx = x;
    this.by = y;
    this.blen = len;
    this.bhor = hor;
    this.occ = occupancy(x, y, len, hor);
    this.sel = TARGET;
    this.moves = 0;
    this.seconds = 0;
    this.status = TG('点方块选中，再用方向键推它');
    this.done = false;
    this.finished = false;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.done && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private blockAt(cell: number): number {
    return cell >= 0 && cell < this.occ.length ? this.occ[cell] : -1;
  }

  private tap(cell: number): void {
    if (this.done || this.finished) {
      return;
    }
    const b: number = this.blockAt(cell);
    if (b < 0) {
      this.status = TG('这里是空位，点一个方块');
      return;
    }
    this.sel = b;
    this.status = b === TARGET ? '选中了 🚗，把它挪到右边出口' : '选中了这辆车，顺着车身推';
  }

  private go(dir: number): void {
    if (this.done || this.finished) {
      return;
    }
    const b: number = this.sel;
    if (b < 0) {
      return;
    }
    if (!canMove(this.bx, this.by, this.blen, this.bhor, b, dir)) {
      this.status = this.bhor[b] ? '这辆车只能左右走，或者前面被挡住了' : '这辆车只能上下走，或者前面被挡住了';
      return;
    }
    push(this.bx, this.by, this.blen, this.bhor, b, dir);
    this.moves = this.moves + 1;
    this.occ = occupancy(this.bx, this.by, this.blen, this.bhor);

    if (this.bx[TARGET] + this.blen[TARGET] >= GRID) {
      this.done = true;
      this.status = TG2("🎉 开出去了！用了 {0} 步",Digits(String(this.moves), this.langCode));
      this.finish(true);
      return;
    }
    this.status = TG2("已走 {0} 步",Digits(String(this.moves), this.langCode));
  }

  /**
   * ★ 2026-10-23 第二期：华容道逃脱提示
   *
   * 完整 BFS 成本偏高（状态在 occ 里，重建形状麻烦），
   * 先做一条最有用的局部提示：
   *   看 0 号车右边到出口这一段，第一个挡住它的是谁。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const row: number = this.by[TARGET];
    const startCol: number = this.bx[TARGET] + this.blen[TARGET];
    let blocker: number = -1;
    let blockerCol: number = -1;
    for (let c = startCol; c < GRID; c++) {
      const b: number = this.blockAt(row * GRID + c);
      if (b >= 0 && b !== TARGET) {
        blocker = b;
        blockerCol = c;
        break;
      }
    }
    if (blocker < 0) {
      return Hint.make([],
        TG('右边已经空了 —— 把车一路推到出口就行'),
        TG('The path is clear — push the car all the way right'), t0);
    }
    return Hint.make([],
      TG2('右边第 {0} 格被 {1} 号挡住，先把它挪开',
        String(blockerCol - startCol + 1), String(blocker + 1)),
      TG2('Block {1} blocks the car at cell {0} — move it first',
        String(blockerCol - startCol + 1), String(blocker + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private gapToExit(): number {
    return GRID - (this.bx[TARGET] + this.blen[TARGET]);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const r: GameResult = {
      gameId: 'block_escape',
      solved: solved,
      score: solved ? Math.max(120, 900 - this.moves * 12) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
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
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: GAP }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              this.cellView(r * GRID + c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('88%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor('#1A6366F1')
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        this.dirBtn('←', 0)
        this.dirBtn('↑', 2)
        this.dirBtn('↓', 3)
        this.dirBtn('→', 1)
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
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width('100%')
          .height(KEY_H + 8)
          .onClick(() => {
            this.askHint();
          })
        Button(TG('认输'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            if (!this.finished) {
              this.done = true;
              this.status = TG('已认输');
              this.finish(false);
            }
          })
      }
      .width('100%')

      Text(this.status)
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=步数 1=距出口 2=用时 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : (kind === 1 ? '距出口' : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves)
        : (kind === 1 ? (this.gapToExit() + TG(' 格')) : (this.seconds + 's')))
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
  cellView(cell: number) {
    Stack() {
      Text(this.markOf(cell))
        .fontSize(FontSize.lg)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.cellBg(cell))
    .borderRadius(Radius.sm)
    .borderWidth(this.selCell(cell) ? 2 : 0)
    .borderColor('#FFFFFF')
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.tap(cell);
    })
  }

  private selCell(cell: number): boolean {
    const b: number = this.blockAt(cell);
    return b >= 0 && b === this.sel;
  }

  @Builder
  dirBtn(label: string, dir: number) {
    Text(label)
      .fontSize(FontSize.lg)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(KEY_H)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .onClick(() => {
        Haptics.tick();
        this.go(dir);
      })
  }

  private markOf(cell: number): string {
    const b: number = this.blockAt(cell);
    if (b < 0) {
      return '';
    }
    const head: boolean = this.bx[b] === cell % GRID && this.by[b] === Math.floor(cell / GRID);
    if (!head) {
      return '';
    }
    return b === TARGET ? '🚗' : '🚙';
  }

  private cellBg(cell: number): string {
    const b: number = this.blockAt(cell);
    if (b < 0) {
      return this.theme.isDark ? '#15151F' : '#F1F5F9';
    }
    return b < CAR_COLORS.length ? CAR_COLORS[b] : Palette.primary;
  }
}
