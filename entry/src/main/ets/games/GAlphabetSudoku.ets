/**
 * 字母数独 —— 6×6 数独，用 A~F 代替数字（3 行 × 2 列为一宫）
 *
 * 玩法：点空格选中 → 点下方 A~F 填入；点「✕」擦除
 * 判据：36 格填满且行/列/宫都不重复 ⇒ 通关；失误满 5 次 ⇒ 失败
 * 出题：随机满盘后逐格挖空，每挖一格验证「解唯一」
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const BOX_R: number = 3;          // 宫高 3
const BOX_C: number = 2;          // 宫宽 2
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 8×8 = 64 格，
//   而数组原来按 CELLS = 36 开 ⇒【困难档必越界】✗）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N;
const GIVENS: number = 16;
const MAX_MISTAKE: number = 5;
const TICK_MS: number = 1000;
const GAP: number = 2;
const KEY_H: number = 46;
const LET: string[] = ['A', 'B', 'C', 'D', 'E', 'F'];

interface Puzzle {
  quiz: number[];
  answer: number[];
}

function shuffled(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

function fits(grid: number[], idx: number, v: number): boolean {
  const r: number = Math.floor(idx / N);
  const c: number = idx % N;
  for (let i = 0; i < N; i++) {
    if (grid[r * N + i] === v || grid[i * N + c] === v) {
      return false;
    }
  }
  const r0: number = Math.floor(r / BOX_R) * BOX_R;
  const c0: number = Math.floor(c / BOX_C) * BOX_C;
  for (let i = 0; i < BOX_R; i++) {
    for (let j = 0; j < BOX_C; j++) {
      if (grid[(r0 + i) * N + c0 + j] === v) {
        return false;
      }
    }
  }
  return true;
}

function fill(grid: number[], pos: number): boolean {
  if (pos === CELLS) {
    return true;
  }
  if (grid[pos] !== 0) {
    return fill(grid, pos + 1);
  }
  const order: number[] = shuffled(N);
  for (let k = 0; k < order.length; k++) {
    const v: number = order[k] + 1;
    if (fits(grid, pos, v)) {
      grid[pos] = v;
      if (fill(grid, pos + 1)) {
        return true;
      }
      grid[pos] = 0;
    }
  }
  return false;
}

// ★★ 2026-10-13 修复循环上界（困难档 ×1.3 ⇒ 棋盘更大，原来只查前 CELLS 格）
function count(grid: number[], limit: number, size: number): number {
  let pos: number = -1;
  for (let i = 0; i < size * size; i++) {
    if (grid[i] === 0) {
      pos = i;
      break;
    }
  }
  if (pos < 0) {
    return 1;
  }
  let total: number = 0;
  for (let v = 1; v <= N; v++) {
    if (fits(grid, pos, v)) {
      grid[pos] = v;
      total = total + count(grid, limit - total, size);
      grid[pos] = 0;
      if (total >= limit) {
        return total;
      }
    }
  }
  return total;
}

function makePuzzle(): Puzzle {
  const answer: number[] = new Array<number>(MAX_CELLS).fill(0);
  fill(answer, 0);
  const quiz: number[] = answer.slice();
  const order: number[] = shuffled(CELLS);
  let removed: number = 0;
  const need: number = CELLS - GIVENS;
  for (let k = 0; k < order.length; k++) {
    if (removed >= need) {
      break;
    }
    const p: number = order[k];
    const keep: number = quiz[p];
    quiz[p] = 0;
    const probe: number[] = quiz.slice();
    if (count(probe, 2, N) !== 1) {
      quiz[p] = keep;
    } else {
      removed++;
    }
  }
  const out: Puzzle = { quiz: quiz, answer: answer };
  return out;
}

@Component
export struct GAlphabetSudoku {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private fixed: boolean[] = [];
  @State private sel: number = -1;
  @State private mistakes: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    const p: Puzzle = makePuzzle();
    const cells: number[] = p.quiz.slice();
    const fixed: boolean[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      fixed.push(cells[i] !== 0);
    }
    this.cells = cells;
    this.fixed = fixed;
    this.sel = -1;
    this.mistakes = 0;
    this.seconds = 0;
    this.status = TG('点空格 → 点字母填入');
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

  private valAt(i: number): number {
    return i >= 0 && i < this.cells.length ? this.cells[i] : 0;
  }

  private isFixed(i: number): boolean {
    return i >= 0 && i < this.fixed.length ? this.fixed[i] : false;
  }

  private bad(i: number): boolean {
    const v: number = this.valAt(i);
    if (v === 0) {
      return false;
    }
    const probe: number[] = this.cells.slice();
    probe[i] = 0;
    return !fits(probe, i, v);
  }

  private filled(): number {
    let n: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] !== 0) {
        n++;
      }
    }
    return n;
  }

  private tapCell(i: number): void {
    if (this.done || this.finished || this.isFixed(i)) {
      return;
    }
    this.sel = this.sel === i ? -1 : i;
    this.status = this.sel < 0 ? TG('已取消选择') : '点一个字母填进去';
  }

  private put(v: number): void {
    if (this.done || this.finished) {
      return;
    }
    const i: number = this.sel;
    if (i < 0) {
      this.status = TG('先点一个空格');
      return;
    }
    if (this.isFixed(i)) {
      this.status = TG('题目自带的字母不能改');
      return;
    }
    const next: number[] = this.cells.slice();
    next[i] = v;
    this.cells = next;

    if (v !== 0) {
      const probe: number[] = next.slice();
      probe[i] = 0;
      if (!fits(probe, i, v)) {
        this.mistakes = this.mistakes + 1;
        this.status = TG('这个字母在行/列/宫里重复了');
        if (this.mistakes >= MAX_MISTAKE) {
          this.done = true;
          this.status = TG2("失误满 {0} 次，这一局没通关",Digits(String(MAX_MISTAKE), this.langCode));
          this.finish(false);
        }
        return;
      }
      this.status = TG('填得对，继续');
    } else {
      this.status = TG('已擦除');
    }

    if (this.isWin()) {
      this.done = true;
      this.status = TG('🎉 字母全部归位！');
      this.finish(true);
    }
  }

  private isWin(): boolean {
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === 0 || this.bad(i)) {
        return false;
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const r: GameResult = {
      gameId: 'alphabet_sudoku',
      solved: solved,
      score: solved ? Math.max(150, 1200 - this.seconds * 3 - this.mistakes * 120) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filled()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text(true ? TG('已填') : (false ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(true ? (this.filled() + '/' + CELLS)
        : (false ? (this.mistakes + '/' + MAX_MISTAKE) : (this.seconds + 's')))
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
        Text(false ? TG('已填') : (true ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? (this.filled() + '/' + CELLS)
        : (true ? (this.mistakes + '/' + MAX_MISTAKE) : (this.seconds + 's')))
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
        Text(false ? TG('已填') : (false ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(false ? (this.filled() + '/' + CELLS)
        : (false ? (this.mistakes + '/' + MAX_MISTAKE) : (this.seconds + 's')))
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
              Text(this.valAt((r * this.diffTotal + c)) === 0 ? '' : LET[this.valAt((r * this.diffTotal + c)) - 1])
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.cellInk((r * this.diffTotal + c)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .scale({ x: this.sel === (r * this.diffTotal + c) ? 1.06 : 1, y: this.sel === (r * this.diffTotal + c) ? 1.06 : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tapCell((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('86%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor('#1A06B6D4')
      .borderRadius(Radius.lg)

      Row({ space: Space.xs }) {
        ForEach(LET, (ch: string, k: number) => {
          Button(ch)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.lg)
            .fontColor(Color.White)
            .backgroundColor(Palette.cyan)
            .borderRadius(Radius.sm)
            .layoutWeight(1)
            .height(KEY_H)
            .onClick(() => {
              Haptics.tap();
              this.put(k + 1);
            })
        }, (ch: string) => 'k' + ch)
      }
      .width('100%')

      Row({ space: Space.sm }) {
        Button(TG('✕ 擦除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.put(0);
          })
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('放弃'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            if (!this.finished) {
              this.done = true;
              this.status = TG('已放弃这一局');
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





  private cellInk(i: number): string {
    if (this.sel === i) {
      return '#FFFFFF';
    }
    if (this.bad(i)) {
      return Palette.danger;
    }
    return this.isFixed(i) ? this.theme.ink : Palette.teal;
  }

  private cellBg(i: number): string {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    const dark: boolean = ((Math.floor(r / BOX_R) + Math.floor(c / BOX_C)) % 2) === 0;
    if (this.bad(i)) {
      return '#FECDD3';
    }
    if (this.sel === i) {
      return Palette.primary;
    }
    if (this.isFixed(i)) {
      return this.theme.isDark ? '#123033' : '#DCFAF7';
    }
    return dark ? this.theme.surface : this.theme.surfaceAlt;
  }
}
