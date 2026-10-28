/**
 * 帐篷与树 tents_and_trees（6×6）—— 每棵树旁恰好一顶帐篷，帐篷互不相邻（含斜角）
 *
 * 操作：点空格放帐篷，再点收起；行列边的数字是该行/该列的帐篷总数
 * 胜负：全部规则满足 ⇒ 通关；违规摆放 3 次 ⇒ 失败
 * 进度：已放 x/总 ／ 违规 x/3 ／ 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 8×8 = 64 格，原来只开 36）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N;
const TARGET_TREES: number = 8;
const ERR_MAX: number = 3;

function tint(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GTentsAndTrees {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State board: number[] = [];        // 0 空 ／ 1 树（固定）／ 2 帐篷
  @State rowClue: number[] = [];
  @State colClue: number[] = [];
  @State errors: number = 0;
  @State placed: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private treeCount: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTentsAndTrees')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
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

  private nearTent(board: number[], i: number): boolean {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) {
          continue;
        }
        const rr: number = r + dr;
        const cc: number = c + dc;
        if (rr < 0 || rr >= this.diffTotal || cc < 0 || cc >= this.diffTotal) {
          continue;
        }
        if (board[rr * this.diffTotal + cc] === 2) {
          return true;
        }
      }
    }
    return false;
  }

  /** 构造一对（帐篷 p + 相邻的树 q），并保证全局规则成立 */
  private tryPlace(): number[] {
    const board: number[] = new Array<number>(MAX_CELLS).fill(0);
    let made: number = 0;
    let guard: number = 0;
    while (made < TARGET_TREES && guard < 500) {
      guard++;
      const p: number = Math.floor(Math.random() * CELLS);
      if (board[p] !== 0 || this.nearTent(board, p)) {
        continue;
      }
      const nb: number[] = this.nbrs4(p);
      let treeNext: boolean = false;
      for (let j = 0; j < nb.length; j++) {
        if (board[nb[j]] === 1) {
          treeNext = true;
        }
      }
      if (treeNext) {
        continue;                     // p 旁边已有树 ⇒ 那棵树会有两顶帐篷
      }
      const cand: number[] = [];
      for (let j = 0; j < nb.length; j++) {
        const q: number = nb[j];
        if (board[q] !== 0) {
          continue;
        }
        let bad: boolean = false;
        const nb2: number[] = this.nbrs4(q);
        for (let k = 0; k < nb2.length; k++) {
          const z: number = nb2[k];
          if (z !== p && board[z] === 2) {
            bad = true;
          }
        }
        if (!bad) {
          cand.push(q);
        }
      }
      if (cand.length === 0) {
        continue;
      }
      const q: number = cand[Math.floor(Math.random() * cand.length)];
      board[p] = 2;
      board[q] = 1;
      made++;
    }
    return made >= 5 ? board : [];
  }

  /** 结算判据：树各一帐、帐篷不挨着、行列数量对得上 */
  private rulesOk(board: number[], rowC: number[], colC: number[]): boolean {
    let trees: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] === 1) {
        trees++;
      }
    }
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] !== 1) {
        continue;
      }
      let cnt: number = 0;
      const nb: number[] = this.nbrs4(i);
      for (let j = 0; j < nb.length; j++) {
        if (board[nb[j]] === 2) {
          cnt++;
        }
      }
      if (cnt !== 1) {
        return false;
      }
    }
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (board[i] === 2 && this.nearTent(board, i)) {
        return false;
      }
    }
    for (let r = 0; r < this.diffTotal; r++) {
      let cnt: number = 0;
      for (let c = 0; c < this.diffTotal; c++) {
        if (board[r * this.diffTotal + c] === 2) {
          cnt++;
        }
      }
      if (rowC[r] !== cnt) {
        return false;
      }
    }
    for (let c = 0; c < this.diffTotal; c++) {
      let cnt: number = 0;
      for (let r = 0; r < this.diffTotal; r++) {
        if (board[r * this.diffTotal + c] === 2) {
          cnt++;
        }
      }
      if (colC[c] !== cnt) {
        return false;
      }
    }
    return trees > 0;
  }

  /** 手写的保底牌面（6 对树/帐篷），只在随机 200 次都失败时使用 */
  private fallback(): number[] {
    const b: number[] = new Array<number>(MAX_CELLS).fill(0);
    const tents: number[] = [1, 4, 13, 16, 25, 28];
    const trees: number[] = [0, 5, 12, 17, 24, 29];
    for (let i = 0; i < tents.length; i++) {
      b[tents[i]] = 2;
      b[trees[i]] = 1;
    }
    return b;
  }

  private reset(): void {
    let bestTrees: number = -1;
    let bestPlay: number[] = [];
    let bestRow: number[] = [];
    let bestCol: number[] = [];
    for (let attempt = 0; attempt < 200; attempt++) {
      let full: number[] = this.tryPlace();
      if (full.length === 0) {
        continue;
      }
      const rowC: number[] = new Array<number>(this.diffTotal).fill(0);
      const colC: number[] = new Array<number>(this.diffTotal).fill(0);
      let trees: number = 0;
      for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
        if (full[i] === 2) {
          rowC[Math.floor(i / this.diffTotal)]++;
          colC[i % this.diffTotal]++;
        } else if (full[i] === 1) {
          trees++;
        }
      }
      if (this.rulesOk(full, rowC, colC) && trees > bestTrees) {
        bestTrees = trees;
        bestRow = rowC.slice();
        bestCol = colC.slice();
        const play: number[] = full.slice();
        for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
          if (play[i] === 2) {
            play[i] = 0;
          }
        }
        bestPlay = play;
      }
      if (bestTrees >= TARGET_TREES) {
        break;
      }
    }
    if (bestTrees <= 0) {
      const full: number[] = this.fallback();   // 原代码这里复用了 for 里 let 的 full，已出作用域
      bestRow = new Array<number>(this.diffTotal).fill(0);
      bestCol = new Array<number>(this.diffTotal).fill(0);
      bestTrees = 0;
      for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
        if (full[i] === 2) {
          bestRow[Math.floor(i / this.diffTotal)]++;
          bestCol[i % this.diffTotal]++;
        } else if (full[i] === 1) {
          bestTrees++;
        }
      }
      const play: number[] = full.slice();
      for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
        if (play[i] === 2) {
          play[i] = 0;
        }
      }
      bestPlay = play;
    }
    this.treeCount = bestTrees > 0 ? bestTrees : 0;
    this.rowClue = bestRow;
    this.colClue = bestCol;
    this.board = bestPlay;
    this.errors = 0;
    this.placed = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  // ═══════════ 求解器 + 提示 + 代打（2026-10-24 第三期）═══════════
  // 规则（见 rulesOk）：每棵树恰好 1 顶相邻帐篷；帐篷之间不相邻；
  //                     每行/每列的帐篷数 == 线索。
  // 做法：DFS 遍历"树"，给每棵树挑一个空格放帐篷，用行列余量 + 相邻判定剪枝。
  private tentsDfs(k: number, trees: number[], board: number[], rowHave: number[],
                   colHave: number[], n: number, out: number[], budget: number[]): boolean {
    if (k >= trees.length) {
      for (let r = 0; r < n; r++) {
        if (rowHave[r] !== this.rowClue[r]) { return false; }
      }
      for (let c = 0; c < n; c++) {
        if (colHave[c] !== this.colClue[c]) { return false; }
      }
      return true;
    }
    budget[0] = budget[0] - 1;
    if (budget[0] <= 0) { return false; }
    const nb: number[] = this.nbrs4(trees[k]);
    for (let t = 0; t < nb.length; t++) {
      const j: number = nb[t];
      if (board[j] !== 0) { continue; }
      const r: number = Math.floor(j / n);
      const c: number = j % n;
      if (rowHave[r] >= this.rowClue[r] || colHave[c] >= this.colClue[c]) { continue; }
      board[j] = 2;
      if (this.nearTent(board, j)) { board[j] = 0; continue; }
      rowHave[r]++;
      colHave[c]++;
      out.push(j);
      if (this.tentsDfs(k + 1, trees, board, rowHave, colHave, n, out, budget)) { return true; }
      out.pop();
      rowHave[r]--;
      colHave[c]--;
      board[j] = 0;
    }
    return false;
  }

  private tentsSolve(): number[] {
    const n: number = this.diffTotal;
    const board: number[] = this.board.slice();
    for (let i = 0; i < n * n; i++) {
      if (board[i] === 2) { board[i] = 0; }
    }
    const trees: number[] = [];
    for (let i = 0; i < n * n; i++) {
      if (board[i] === 1) { trees.push(i); }
    }
    if (trees.length === 0) { return []; }
    const rowHave: number[] = new Array<number>(n).fill(0);
    const colHave: number[] = new Array<number>(n).fill(0);
    const out: number[] = [];
    const budget: number[] = [200000];
    if (!this.tentsDfs(0, trees, board, rowHave, colHave, n, out, budget)) { return []; }
    return out;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const sol: number[] = this.tentsSolve();
    if (sol.length === 0) { return Hint.none('none'); }
    for (let k = 0; k < sol.length; k++) {
      const i: number = sol[k];
      if (this.board[i] !== 2) {
        const r: number = Math.floor(i / this.diffTotal) + 1;
        const c: number = (i % this.diffTotal) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列放一顶帐篷', String(r), String(c)),
          TG2('Put a tent at row {0}, column {1}', String(r), String(c)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格该放帐篷'));
  }

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
    if (this.over) { return false; }
    const sol: number[] = this.tentsSolve();
    if (sol.length === 0) { return false; }
    for (let k = 0; k < sol.length; k++) {
      const i: number = sol[k];
      if (this.board[i] !== 2) {
        this.tap(i);
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
    const cur: number = this.board[i];
    if (cur === 1) {
      return;                       // 树不能动
    }
    const next: number[] = this.board.slice();
    if (cur === 2) {
      next[i] = 0;
      this.board = next;
      this.placed--;
      return;
    }
    if (this.nearTent(next, i)) {
      this.errors++;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    next[i] = 2;
    this.board = next;
    this.placed++;
    if (this.placed === this.treeCount && this.rulesOk(next, this.rowClue, this.colClue)) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(80, 520 - this.errors * 100 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'tents_and_trees',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.placed
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("全部配对 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '违规太多，本局失败';
    }
    return TG('点格子放帐篷（再点收起）；帐篷之间不能相邻（斜着也不行）');
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({

        onHintTap: () => { this.askHint(); },

        onAutoTap: () => { this.askAuto(); },

        demoOn: this.demoId >= 0,

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已放'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed) + '/' + String(this.treeCount)))
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
        Text((TG('违规'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(ERR_MAX)))
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
        Row({ space: Space.xs }) {
          Text('').layoutWeight(1)
          ForEach(this.rowIdx(), (c: number) => {
            Text(String((this.colClue[c])))
            .fontSize(FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.inkFaint)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .aspectRatio(1)
          }, (c: number) => 'tc' + c)
        }
        .width('100%')

        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            Text(String((this.rowClue[r])))
            .fontSize(FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.inkFaint)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .aspectRatio(1)
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.board[(r * this.diffTotal + c)] === 1 ? '🌳' : (this.board[(r * this.diffTotal + c)] === 2 ? '⛺' : ''))
              .fontSize(FontSize.lg)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.board[(r * this.diffTotal + c)] === 2
              ? tint(Palette.amber, this.theme.isDark)
              : (this.board[(r * this.diffTotal + c)] === 1 ? tint(Palette.emerald, this.theme.isDark) : this.theme.surface))
              .borderRadius(Radius.xs)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
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
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Text(this.tip())
        .fontSize(FontSize.sm)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%')


      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(Palette.emerald)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('🌳 树固定不动；每棵树上下左右恰好一顶 ⛺；行列数字 = 该行/列的帐篷数'))
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
