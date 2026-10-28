/**
 * 塔帕 tapa（5×5）—— 涂黑格子，让每个数字格的 8 邻域按数字连成若干段黑格
 *
 * 规则：黑格必须连成一片、不许出现 2×2 黑块、数字格本身不能涂黑
 * 胜负：全部满足 ⇒ 通关；180 秒倒计时归零 ⇒ 失败
 * 进度：黑格数 ／ 剩余秒数 ／ 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，原来只开 25）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const LIMIT_SEC: number = 180;

function tint(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

function sorted(a: number[]): number[] {
  const c: number[] = a.slice();
  c.sort((x: number, y: number) => x - y);
  return c;
}

function sameRuns(a: number[], b: number[]): boolean {
  if (a.length !== b.length) {
    return false;
  }
  const x: number[] = sorted(a);
  const y: number[] = sorted(b);
  for (let i = 0; i < x.length; i++) {
    if (x[i] !== y[i]) {
      return false;
    }
  }
  return true;
}

@Component
export struct GTapa {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(5);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State cells: number[] = [];
  @State clueText: string[] = [];
  @State black: number = 0;
  @State left: number = LIMIT_SEC;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private clueRuns: number[][] = [];
  /** 生成时的答案黑格图（reset() 里存下来，代打照它涂） */
  private sol: number[] = [];
  private timer: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
    this.reset();
  }

  private nbrs4(i: number): number[] {
    const out: number[] = [];
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    if (r > 0) {
      out.push(i - this.diffTotal);
    }
    if (r < this.diffTotal - 1) {
      out.push(i + this.diffTotal);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < this.diffTotal - 1) {
      out.push(i + 1);
    }
    return out;
  }

  /** 顺时针一圈的 8 邻居，出界记 -1 */
  private ring8(i: number): number[] {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    const dr: number[] = [-1, -1, 0, 1, 1, 1, 0, -1];
    const dc: number[] = [0, 1, 1, 1, 0, -1, -1, -1];
    const out: number[] = [];
    for (let k = 0; k < 8; k++) {
      const rr: number = r + dr[k];
      const cc: number = c + dc[k];
      out.push((rr < 0 || rr >= this.diffTotal || cc < 0 || cc >= this.diffTotal) ? -1 : rr * this.diffTotal + cc);
    }
    return out;
  }

  private has2x2(board: number[]): boolean {
    for (let r = 0; r + 1 < this.diffTotal; r++) {
      for (let c = 0; c + 1 < this.diffTotal; c++) {
        const a: number = board[r * this.diffTotal + c];
        if (a === 1 && board[r * this.diffTotal + c + 1] === 1
          && board[(r + 1) * this.diffTotal + c] === 1 && board[(r + 1) * this.diffTotal + c + 1] === 1) {
          return true;
        }
      }
    }
    return false;
  }

  private connected(board: number[]): boolean {
    let start: number = -1;
    let total: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] === 1) {
        total++;
        if (start < 0) {
          start = i;
        }
      }
    }
    if (start < 0) {
      return false;
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    const stack: number[] = [start];
    seen[start] = 1;
    let cnt: number = 1;
    while (stack.length > 0) {
      const cur: number = stack.pop() as number;
      const nb: number[] = this.nbrs4(cur);
      for (let j = 0; j < nb.length; j++) {
        const k: number = nb[j];
        if (board[k] === 1 && seen[k] === 0) {
          seen[k] = 1;
          cnt++;
          stack.push(k);
        }
      }
    }
    return cnt === total;
  }

  /** 某格的 8 邻域黑格，按顺时针连成几段 */
  private runsOf(board: number[], i: number): number[] {
    const ring: number[] = this.ring8(i);
    const b: boolean[] = [];
    let allBlack: boolean = true;
    for (let k = 0; k < 8; k++) {
      const idx: number = ring[k];
      const isB: boolean = idx >= 0 && board[idx] === 1;
      b.push(isB);
      if (!isB) {
        allBlack = false;
      }
    }
    const runs: number[] = [];
    if (allBlack) {
      runs.push(8);
      return runs;
    }
    let start: number = 0;
    for (let k = 0; k < 8; k++) {
      if (!b[k]) {
        start = k;
        break;
      }
    }
    let cur: number = 0;
    for (let s = 0; s < 8; s++) {
      const k: number = (start + s) % 8;
      if (b[k]) {
        cur++;
      } else if (cur > 0) {
        runs.push(cur);
        cur = 0;
      }
    }
    if (cur > 0) {
      runs.push(cur);
    }
    return runs;
  }

  /** 随机构造一片合法黑格（连通、无 2×2），再反推数字提示 ⇒ 一定有解 */
  private genBoard(): number[] {
    let best: number[] = [];
    let bestSize: number = -1;
    for (let attempt = 0; attempt < 24; attempt++) {
      const black: number[] = new Array<number>(MAX_CELLS).fill(0);
      black[Math.floor(Math.random() * CELLS)] = 1;
      let size: number = 1;
      const want: number = 8 + Math.floor(Math.random() * 4);
      let guard: number = 0;
      while (size < want && guard < 400) {
        guard++;
        const cand: number[] = [];
        for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
          if (black[i] === 1) {
            continue;
          }
          let touch: boolean = false;
          const nb: number[] = this.nbrs4(i);
          for (let j = 0; j < nb.length; j++) {
            if (black[nb[j]] === 1) {
              touch = true;
            }
          }
          if (!touch) {
            continue;
          }
          black[i] = 1;
          const bad: boolean = this.has2x2(black);
          black[i] = 0;
          if (!bad) {
            cand.push(i);
          }
        }
        if (cand.length === 0) {
          break;
        }
        black[cand[Math.floor(Math.random() * cand.length)]] = 1;
        size++;
      }
      if (size > bestSize) {
        bestSize = size;
        best = black.slice();
      }
      if (size >= want) {
        break;
      }
    }
    return best;
  }

  private reset(): void {
    const black: number[] = this.genBoard();
    this.sol = black.slice();
    const runs: number[][] = [];
    const text: string[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      let hasBlack: boolean = false;
      const ring: number[] = this.ring8(i);
      for (let k = 0; k < 8; k++) {
        if (ring[k] >= 0 && black[ring[k]] === 1) {
          hasBlack = true;
        }
      }
      if (black[i] === 0 && hasBlack) {
        const rs: number[] = this.runsOf(black, i);
        runs.push(rs);
        text.push(rs.join(','));
      } else {
        runs.push([]);
        text.push('');
      }
    }
    this.clueRuns = runs;
    this.clueText = text;
    this.cells = new Array<number>(MAX_CELLS).fill(0);
    this.black = 0;
    this.left = LIMIT_SEC;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.timer = setInterval(() => {
      if (this.over) {
        return;
      }
      const next: number = this.left - 1;
      this.left = next > 0 ? next : 0;
      if (this.left <= 0) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
    }, 1000);
  }

  private solvedNow(): boolean {
    const board: number[] = this.cells;
    let cnt: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] === 1) {
        cnt++;
      }
    }
    if (cnt === 0) {
      return false;
    }
    if (this.has2x2(board)) {
      return false;
    }
    if (!this.connected(board)) {
      return false;
    }
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] === 1) {
        if (this.clueRuns[i].length > 0) {
          return false;
        }
        continue;
      }
      if (!sameRuns(this.runsOf(board, i), this.clueRuns[i])) {
        return false;
      }
    }
    return true;
  }


  /**
   * ★ 2026-10-23 第二期：塔帕提示
   *
   * 规则：带数字的格子，其 8 邻域里黑格连成的段长要正好等于那些数字。
   * 局部规则（与明灯同型）：
   *   「已黑邻居数 + 还能涂黑的未定邻居数」正好等于线索之和
   *   ⇒ 那些未定邻居**必须全部涂黑**。
   *
   * ⚠️ 这款的 cells 只有 0（未定/白）和 1（黑），没有单独的白标记，
   *    所以只能推「必须黑」，不能推「必须白」。宁可少给。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      const runs: number[] = this.clueRuns[i];
      if (runs.length === 0) {
        continue;
      }
      let need: number = 0;
      for (let k = 0; k < runs.length; k++) {
        need += runs[k];
      }
      const r: number = Math.floor(i / n);
      const c: number = i % n;
      let have: number = 0;
      let free: number = 0;
      let freeIdx: number = -1;
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          if (dr === 0 && dc === 0) {
            continue;
          }
          const rr: number = r + dr;
          const cc: number = c + dc;
          if (rr < 0 || rr >= n || cc < 0 || cc >= n) {
            continue;
          }
          const j: number = rr * n + cc;
          if (this.clueRuns[j].length > 0) {
            continue;                      // 数字格不计入
          }
          if (this.cells[j] === 1) {
            have++;
          } else {
            free++;
            freeIdx = j;
          }
        }
      }
      if (have + free !== need || free === 0 || freeIdx < 0) {
        continue;
      }
      const rr2: number = Math.floor(freeIdx / n) + 1;
      const cc2: number = (freeIdx % n) + 1;
      return Hint.make([freeIdx],
        TG2('第 {0} 行第 {1} 列必须涂黑（旁边那个数字还差 {2} 格）',
          String(rr2), String(cc2), String(need - have)),
        TG2('Row {0}, column {1} must be black (that clue still needs {2})',
          String(rr2), String(cc2), String(need - have)), t0);
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须涂黑'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：reset() 生成题目时就把答案黑格图存进了 this.sol
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
    const n: number = this.diffTotal * this.diffTotal;
    if (this.sol.length < n) {
      return false;
    }
    for (let i = 0; i < n; i++) {
      if (this.cells[i] === 1 && this.sol[i] !== 1) {
        this.tap(i);                   // 先擦掉涂错的格子
        return !this.over;
      }
    }
    for (let i = 0; i < n; i++) {
      if (this.sol[i] === 1 && this.cells[i] !== 1) {
        this.tap(i);                   // 再补上答案要的黑格
        return !this.over;
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

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.clueRuns[i].length > 0) {
      return;                     // 数字格不能涂黑
    }
    const next: number[] = this.cells.slice();
    next[i] = next[i] === 1 ? 0 : 1;
    this.cells = next;
    let cnt: number = 0;
    for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
      if (next[k] === 1) {
        cnt++;
      }
    }
    this.black = cnt;
    if (this.solvedNow()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(80, 520 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'tapa',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.black
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("全部满足 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '时间到，还差一点';
    }
    return TG('点格子涂黑/擦白；数字 = 8 邻域里连续黑格的段长');
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
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.black), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余秒'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.left), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.clueText[(r * this.diffTotal + c)])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.cells[(r * this.diffTotal + c)] === 1 ? '#FFFFFF' : Palette.primaryDeep)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells[(r * this.diffTotal + c)] === 1
              ? (this.theme.isDark ? '#E8E8E8' : '#1F2937')
              : tint(Palette.primary, this.theme.isDark))
              .borderRadius(Radius.xs)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Text(this.tip())
        .fontSize(FontSize.sm)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%')

      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .width(64)
        .height(44)
        .onClick(() => {
          this.askHint();
        })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('黑格要连成一片、不能出现 2×2；白格也必须连通'))
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
