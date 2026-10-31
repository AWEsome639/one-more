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
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const BOX_R: number = 3;          // 宫高 3
const BOX_C: number = 2;          // 宫宽 2
const CELLS: number = N * N;

/**
 * ★★★ 2026-10-23 修「尺寸陷阱」：这个文件原本把三样东西写死成 6×6 的值 ——
 *   ① 宫格布局 BOX_R×BOX_C
 *   ② 校验循环上界 N
 *   ③ 题给数个数 GIVENS
 *   而难度会改棋盘边长（简单 ×0.7→4 / 普通 6 / 困难 ×1.3→8）。
 *   ⇒ 简单 4×4 时题给数比总格数还多 ⇒ 一格都不挖 ⇒ 满盘全是题给数、无法游玩。
 *
 *   现在：边长当参数传；宫格按边长选；题给数按比例。
 *   6×6 的行为与修复前完全一致（宫格 3×2、题给 16 个）。
 */
function boxFor(n: number): number[] {
  if (n === 4) {
    const a: number[] = [2, 2];
    return a;
  }
  if (n === 8) {
    const a2: number[] = [4, 2];
    return a2;
  }
  const a3: number[] = [3, 2];
  return a3;
}

/** 题给数比例：50%（6×6 → 16 个，与修复前一致） */
const GIVEN_RATIO: number = 0.5;
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

function fits(grid: number[], idx: number, v: number, n: number): boolean {
  const r: number = Math.floor(idx / n);
  const c: number = idx % n;
  for (let i = 0; i < n; i++) {
    if (grid[r * n + i] === v || grid[i * n + c] === v) {
      return false;
    }
  }
  const bx: number[] = boxFor(n);
  const br: number = bx[0];
  const bc: number = bx[1];
  const r0: number = Math.floor(r / br) * br;
  const c0: number = Math.floor(c / bc) * bc;
  for (let i = 0; i < br; i++) {
    for (let j = 0; j < bc; j++) {
      if (grid[(r0 + i) * n + c0 + j] === v) {
        return false;
      }
    }
  }
  return true;
}

function fill(grid: number[], pos: number, n: number): boolean {
  if (pos === n * n) {
    return true;
  }
  if (grid[pos] !== 0) {
    return fill(grid, pos + 1, n);
  }
  const order: number[] = shuffled(n);
  for (let k = 0; k < order.length; k++) {
    const v: number = order[k] + 1;
    if (fits(grid, pos, v, n)) {
      grid[pos] = v;
      if (fill(grid, pos + 1, n)) {
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
  for (let v = 1; v <= size; v++) {
    if (fits(grid, pos, v, size)) {
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

function makePuzzle(size: number): Puzzle {
  const answer: number[] = new Array<number>(MAX_CELLS).fill(0);
  fill(answer, 0, size);
  const quiz: number[] = answer.slice();
  const total: number = size * size;
  const order: number[] = shuffled(total);
  let removed: number = 0;
  const need: number = total - Math.floor(total * GIVEN_RATIO);
  for (let k = 0; k < order.length; k++) {
    if (removed >= need) {
      break;
    }
    const p: number = order[k];
    const keep: number = quiz[p];
    quiz[p] = 0;
    const probe: number[] = quiz.slice();
    if (count(probe, 2, size) !== 1) {
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

  /** 出题时的完整解 */

  private solCells: number[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State */

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private cells: number[] = [];
  @State private fixed: boolean[] = [];
  @State private sel: number = -1;
  @State private mistakes: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAlphabetSudoku')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
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
    const p: Puzzle = makePuzzle(this.diffTotal);
    // ★ 2026-10-24 第三期：出题时的完整解留着（同数壹的做法）
    this.solCells = p.answer.slice();
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
    return !fits(probe, i, v, this.diffTotal);
  }


  /**
   * ★ 2026-10-23 第二期：字母数独提示
   *
   * 这个文件本来就有完整求解器（fill：回溯填满），
   * 所以提示很直接：把当前盘面复制一份、解开、找一个还空着的格，告诉它该填几。
   *
   * ⚠️ 与数独（GSudoku）的做法一致：
   *    优先找「唯一候选」的格（更"人类"），没有再直接揭答案。
   *    这里因为求解器现成，先做揭答案这一路 —— 简单、永远可用。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    const g: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < n * n; i++) {
      g[i] = this.cells[i];
    }
    if (!fill(g, 0, n)) {
      return Hint.none('none');
    }
    for (let i = 0; i < n * n; i++) {
      if (this.cells[i] === 0 && g[i] > 0) {
        this.hintIdx = i;
        const r: number = Math.floor(i / n) + 1;
        const c: number = (i % n) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列填 {2}', String(r), String(c), String(g[i])),
          TG2('Row {0}, column {1}: fill {2}', String(r), String(c), String(g[i])), t0);
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第三期：AI 代打（字母数独）
   * 用出题时保留的完整解：选格 → 填字母，一次一格。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.done || this.finished) {
      return false;
    }
    const n: number = this.diffTotal;
    if (this.solCells.length < n * n) {
      return false;
    }
    for (let i = 0; i < n * n; i++) {
      if (this.cells[i] !== this.solCells[i] && !this.fixed[i]) {
        this.sel = i;
        this.put(this.solCells[i]);
        return true;
      }
    }
    return false;
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
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.status = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.status = TG('这一步算不出来（盘面可能已经填错了）');
    setTimeout(() => { this.status = ''; }, 4500);
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
      if (!fits(probe, i, v, this.diffTotal)) {
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
    // ★ 2026-10-24 修真 BUG：cells 的长度是 MAX_CELLS（8×8 = 64），
    //   但本局只用到 diffTotal² 个格子。原来的循环写到 cells.length，
    //   于是 36~63 这些**永远为 0 的尾巴**让 isWin 永远返回 false
    //   ⇒ 小于 8×8 的字母数独根本不可能通关。
    //   证据：AI 代打把 6×6 填满成 36/36、零失误，游戏仍显示「填得对，继续」。
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
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

  /**
   * 棋盘边长(vp)：宽度与可用高度取小者 —— 不许 aspectRatio 自行决定高度。
   *
   * ★★★ 2026-10-30 为什么改：原来是 `.width('86%')` + `.aspectRatio(1)`，
   *   **没有任何高度约束**：平板横屏 853×533 上 86% × 813 ≈ 699vp 宽
   *   （813 = 853 − 左右 padding 各 20），aspectRatio 把高也锁成 699vp，
   *   而这块地方真正能用的高只有 ~425vp（533 − 顶栏 88 − 底 padding 20）
   *   ⇒ **溢出 1.64 倍**：
   *   下面的按钮/状态被挤出屏外，点不到。
   *   （第 452 轮只扫了 `width('100%')` 那一族，`width('8x%')` 这一族一直漏着）
   *
   * reserve 怎么算（本文件）：
   *   顶栏 88 + 底 padding 20 + 信息行 56（实测：卡片上下 padding 10 + 两行字）
   *   + 板下 3 行 = 数字键行 46 + 按钮行 46 + 状态文字 20 = 112
   *   + 子元素间隙：5 个子元素 ⇒ 4 × 16vp = 64
   *   ⇒ reserve = 88 + 20 + 56 + 112 + 64 = 340
   *   · 手机竖 420×744 ⇒ min(380, 404) = 380
   *   · 平板横 853×533 ⇒ min(813, 193) = 193
   *   · 平板竖 800×1280 ⇒ min(768, 940) = 768
   */
  private boardPx(reserve: number): number {
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(160, Bp.height - reserve);
    return Math.min(w, h);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text(true ? TG('已填') : (false ? TG('失误') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        Text(true ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
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
        Text(false ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
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
        Text(false ? (this.filled() + '/' + String(this.diffTotal * this.diffTotal))
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
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell((r * this.diffTotal + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tapCell((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      // ★ 2026-10-30：宽高都从「可用高度」反推（见 boardPx 注释），不再让 aspectRatio 决定高度
      .width(this.boardPx(340))
      .height(this.boardPx(340))
      .alignSelf(ItemAlign.Center)
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
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.put(k + 1); }); })
            .onClick(() => {
              Haptics.tap();
              this.put(k + 1);
            })
        }, (ch: string) => 'k' + ch)
      }
      .width('100%')

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('✕ 擦除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.put(0); }); })
          .onClick(() => {
            Haptics.tap();
            this.put(0);
          })
        Button(this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打')))
          .layoutWeight(1)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (!this.finished) { this.done = true; this.status = TG('已放弃这一局'); this.finish(false); } }); })
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
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
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
