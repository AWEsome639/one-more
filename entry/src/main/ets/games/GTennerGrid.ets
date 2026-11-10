/**
 * 十格 tenner_grid（10×10）—— 每行每列都要恰好含 0~9 各一次（拉丁方）
 *
 * 操作：点空格选中 → 点数字键盘填入（再点同一个数字 = 擦掉）
 * 胜负：填满 100 格且无冲突 ⇒ 通关；冲突 3 次 ⇒ 失败（冲突的数不会落盘）
 * 进度：已填 x/100 ／ 冲突 x/3 ／ 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { DemoBar } from '../components/DemoBar';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 10;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 13×13 = 169 格，原来只开 100）
const MAX_N: number = 13;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;
const GIVEN_RATE: number = 0.7;

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

@Component
export struct GTennerGrid {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=10；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = GameDiff.sizeNow(10);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State grid: number[] = [];
  /** ★ 判据 1704：生成时的解（AI 代打直接照它填） */
  private sol: number[] = [];
  /** ★ 2026-11-08 代打现场解出来的盘面（不读 sol）；空 = 未算 */
  private autoSol: number[] = [];
  /** ★ 回溯节点预算：防止十格图太松时把 UI 卡死 */
  private autoBudget: number = 0;
  @State fixed: number[] = [];
  @State sel: number = -1;
  @State errors: number = 0;
  @State placed: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTennerGrid')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
    this.reset();
  }

  private reset(): void {
    const rp: number[] = shuffled(this.diffTotal);
    const cp: number[] = shuffled(this.diffTotal);
    const vp: number[] = shuffled(this.diffTotal);
    const sol: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal; i++) {
      for (let j = 0; j < this.diffTotal; j++) {
        sol[rp[i] * this.diffTotal + cp[j]] = vp[(i + j) % this.diffTotal];
      }
    }
    const grid: number[] = new Array<number>(MAX_CELLS).fill(-1);
    const fixed: number[] = new Array<number>(MAX_CELLS).fill(0);
    let givens: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (Math.random() < GIVEN_RATE) {
        grid[i] = sol[i];
        fixed[i] = 1;
        givens++;
      }
    }
    let guard: number = 0;
    while (givens < 55 && guard < 400) {
      guard++;
      const i: number = Math.floor(Math.random() * CELLS);
      if (fixed[i] === 0) {
        grid[i] = sol[i];
        fixed[i] = 1;
        givens++;
      }
    }
    this.sol = sol;
    this.grid = grid;
    this.fixed = fixed;
    this.sel = -1;
    this.errors = 0;
    this.placed = givens;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 行/列里是否已经有这个数字 */
  private conflict(idx: number, d: number): boolean {
    const r: number = Math.floor(idx / this.diffTotal);
    const c: number = idx % this.diffTotal;
    for (let k = 0; k < this.diffTotal; k++) {
      if (k !== c && this.grid[r * this.diffTotal + k] === d) {
        return true;
      }
      if (k !== r && this.grid[k * this.diffTotal + c] === d) {
        return true;
      }
    }
    return false;
  }

  /** ★ 2026-11-08 代打求解：题面固定格 + 行/列不重复（不碰 sol） */
  private solveByRules(n: number): number[] {
    const board: number[] = new Array<number>(n * n).fill(-1);
    const fx: boolean[] = new Array<boolean>(n * n).fill(false);
    for (let i = 0; i < n * n; i++) {
      if (this.fixed[i] === 1) {
        board[i] = this.grid[i];
        fx[i] = true;
      }
    }
    this.autoBudget = 400000;
    return this.tgFill(board, fx, n) ? board : [];
  }

  /** ★ MRV（最少候选优先）：行主序会爆（实测 10×10 + 40% 题面 40 万节点不够），
   *  换成「每次挑候选最少的空格」——实测 <800 节点、0.01 秒。 */
  private tgFill(board: number[], fx: boolean[], n: number): boolean {
    this.autoBudget = this.autoBudget - 1;
    if (this.autoBudget < 0) {
      return false;
    }
    let best: number = -1;
    let bestCnt: number = 99;
    for (let i = 0; i < n * n; i++) {
      if (fx[i] || board[i] >= 0) {
        continue;
      }
      let cnt: number = 0;
      for (let v = 0; v < n; v++) {
        if (this.tgOkAt(board, i, v, n)) {
          cnt = cnt + 1;
        }
      }
      if (cnt === 0) {
        return false;
      }
      if (cnt < bestCnt) {
        bestCnt = cnt;
        best = i;
        if (cnt === 1) {
          break;
        }
      }
    }
    if (best < 0) {
      return true;
    }
    for (let v = 0; v < n; v++) {
      if (!this.tgOkAt(board, best, v, n)) {
        continue;
      }
      board[best] = v;
      if (this.tgFill(board, fx, n)) {
        return true;
      }
      board[best] = -1;
    }
    return false;
  }

  /** 行/列不重复（题面固定格已在 board 里） */
  private tgOkAt(board: number[], idx: number, v: number, n: number): boolean {
    const r: number = Math.floor(idx / n);
    const c: number = idx % n;
    for (let k = 0; k < n; k++) {
      if (k !== c && board[r * n + k] === v) {
        return false;
      }
      if (k !== r && board[k * n + c] === v) {
        return false;
      }
    }
    return true;
  }

  private place(d: number): void {
    if (this.over || this.sel < 0) {
      return;
    }
    const idx: number = this.sel;
    if (this.fixed[idx] === 1) {
      return;
    }
    const next: number[] = this.grid.slice();
    if (next[idx] === d) {
      next[idx] = -1;                 // 再点一次同一个数字 = 擦掉
      this.grid = next;
      this.placed--;
      return;
    }
    if (this.conflict(idx, d)) {
      this.errors++;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    const was: number = next[idx];
    next[idx] = d;
    this.grid = next;
    this.placed += was < 0 ? 1 : 0;
    if (this.placed === CELLS) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(80, 620 - this.errors * 90 - sec);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'tenner_grid',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.placed
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * ★ 2026-10-23 第二期：十格提示（唯一候选法）
   *
   * 规则：每行放 0..9 各一次；相邻两行同列不能相同（见 conflict）。
   * ⇒ 对每个空格，把 0..9 都试一遍 **用游戏自己的 conflict 判定**
   *   ⇒ 只剩一个合法数字时，它就确定了。
   *
   * 复用 conflict 的好处：提示与游戏本体永远同一把尺子。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      if (this.grid[i] >= 0 || this.fixed[i] === 1) {
        continue;                      // 已填 / 题目给的，跳过
      }
      let only: number = -1;
      let cnt: number = 0;
      for (let d = 0; d < n; d++) {
        if (!this.conflict(i, d)) {
          cnt++;
          only = d;
          if (cnt > 1) {
            break;
          }
        }
      }
      if (cnt !== 1 || only < 0) {
        continue;
      }
      const r: number = Math.floor(i / n) + 1;
      const c: number = (i % n) + 1;
      return Hint.make([i],
        TG2('第 {0} 行第 {1} 列只能填 {2} —— 其它数字都会撞',
          String(r), String(c), String(only)),
        TG2('Row {0}, column {1} can only be {2} — every other digit clashes',
          String(r), String(c), String(only)), t0);
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第二期：AI 代打（十格，一次填一格）
   * 与提示同一套判据：唯一候选法。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01）
  // ★ 旧版 `demoStep()` 一个 tick 直接 `autoStep()`，匀速连发 ⇒ 玩家看不出在演什么。
  // ★ 新版三拍：引导(720) → 执行(280) → 结果(1150)，3 轮 ≈ 6.5 秒。
  // ★ 引导拍的文案用**本游戏自己的 computeHint()** —— 它本来就知道该指哪里。
  // ★ 演示期间按钮置灰（本页 demoId 直传），结束后 reset 回干净开局。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.reset();
  }

  private demoStop(): void {
    this.demoFinish();
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const n: number = this.diffTotal;
    // ⚠️ 判据 1705：十格的值是 0~9，**0 是合法值** —— `grid[i] > 0` 会把「已填 0」当成空格，
    //   AI 反复对同一格填 0 / 擦掉 ⇒ 永远填不满（本轮实测「已填」卡在 77~83/100）
    // ⓪ ★ 判据 1704：`sol` 就在 reset 里生成（之前只是局部变量、没存字段）——
    //   AI 代打直接照答案填，保证 100% 能赢；下面的推理只作兜底
    // ★ 2026-11-08（ai-fixer-a）**不再抄出题解 sol**：用回溯骨架（行/列不重复 + 题面固定格）
    //   现场求解，再一格一格填。带节点预算，超了就让代打停下（不会把 UI 卡住）。
    if (this.autoSol.length !== n * n) {
      this.autoSol = this.solveByRules(n);
    }
    if (this.autoSol.length !== n * n) {
      return false;
    }
    for (let i = 0; i < n * n; i++) {
      if (this.grid[i] >= 0 || this.fixed[i] === 1) {
        continue;
      }
      this.sel = i;
      this.place(this.autoSol[i]);
      return !this.over;
    }
    // ① naked single：某格只剩一个数字可放（原有逻辑）
    for (let i = 0; i < n * n; i++) {
      if (this.grid[i] >= 0 || this.fixed[i] === 1) {
        continue;
      }
      let only: number = -1;
      let cnt: number = 0;
      for (let d = 0; d < n; d++) {
        if (!this.conflict(i, d)) {
          cnt++;
          only = d;
          if (cnt > 1) {
            break;
          }
        }
      }
      if (cnt === 1 && only >= 0) {
        this.sel = i;
        this.place(only);
        return !this.over;
      }
    }
    // ② 隐性唯一（行）：某数字在这一行只有一个合法位置（判据 1703）
    for (let r = 0; r < n; r++) {
      for (let d = 0; d < n; d++) {
        let pos: number = -1;
        let cnt: number = 0;
        for (let c = 0; c < n; c++) {
          const i: number = r * n + c;
          if (this.grid[i] === d) {
            cnt = -1;
            break;
          }
          if (this.grid[i] >= 0 || this.fixed[i] === 1) {
            continue;
          }
          if (!this.conflict(i, d)) {
            cnt++;
            pos = i;
          }
        }
        if (cnt === 1 && pos >= 0) {
          this.sel = pos;
          this.place(d);
          return !this.over;
        }
      }
    }
    // ③ 隐性唯一（列）
    for (let c = 0; c < n; c++) {
      for (let d = 0; d < n; d++) {
        let pos: number = -1;
        let cnt: number = 0;
        for (let r = 0; r < n; r++) {
          const i: number = r * n + c;
          if (this.grid[i] === d) {
            cnt = -1;
            break;
          }
          if (this.grid[i] >= 0 || this.fixed[i] === 1) {
            continue;
          }
          if (!this.conflict(i, d)) {
            cnt++;
            pos = i;
          }
        }
        if (cnt === 1 && pos >= 0) {
          this.sel = pos;
          this.place(d);
          return !this.over;
        }
      }
    }
    return false;
  }

  private askAuto(): void {
    if (LanRace.isRacing()) { return; }   // 联机禁用（奥森硬约束）
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格是唯一的'));
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("整盘排好 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : TG('冲突太多，本局失败');
    }
    return this.sel < 0 ? TG('先点一个空格，再点下面数字') : TG2("已选中第 {0} 行", String(Math.floor(this.sel / this.diffTotal) + 1));
  }

  build() {
    Column({ space: Space.xxs }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed) + '/' + String(CELLS)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('冲突'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(ERR_MAX)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.md)
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
              Text(this.grid[(r * this.diffTotal + c)] < 0 ? '' : String(this.grid[(r * this.diffTotal + c)]))
              .fontSize(FontSize.xxs)
              .fontWeight(this.fixed[(r * this.diffTotal + c)] === 1 ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.grid[(r * this.diffTotal + c)] < 0 ? this.theme.inkFaint : this.theme.ink).animation({ duration: Motion.fast, curve: Motion.snap() })
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.fixed[(r * this.diffTotal + c)] === 1 ? this.theme.surfaceAlt : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({
              width: this.sel === (r * this.diffTotal + c) ? 2 : 1,
              color: this.sel === (r * this.diffTotal + c) ? Palette.violet : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              if (this.over) {
              return;
              }
              this.sel = (r * this.diffTotal + c);
              })
              .focusable(Tv.on())
              .onFocus(() => { this.tvFocus = 'L468'; })
              .onBlur(() => { if (this.tvFocus === 'L468') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L468', Radius.xs))
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (this.over) { return; } this.sel = (r * this.diffTotal + c); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      // ★★ 2026-11-01 真机（横屏 853×533）：棋盘无宽度上限，
      //   而格子在 Row 里 `layoutWeight(1) + aspectRatio(1)` ⇒ 高度 = 宽度
      //   ⇒ 10×10 撑破屏幕，数字键与按钮全不可见（截图拍到）。
      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(200, Bp.height - 360)))

      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(38))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
            Haptics.tick();
            this.place((d));
            })
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'L498'; })
            .onBlur(() => { if (this.tvFocus === 'L498') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'L498', Radius.sm))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((d)); }); })
          }, (d: number) => 'd' + d)
        }
        .width('100%')
        Row({ space: Space.xs }) {
          ForEach([5, 6, 7, 8, 9], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(38))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
            Haptics.tick();
            this.place((d));
            })
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'L520'; })
            .onBlur(() => { if (this.tvFocus === 'L520') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'L520', Radius.sm))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((d)); }); })
          }, (d: number) => 'e' + d)
        }
        .width('100%')
      }
      .width('100%')

      Text(this.tip())
        .fontSize(FontSize.xs)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L547'; })
          .onBlur(() => { if (this.tvFocus === 'L547') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L547'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        Button(LanRace.isRacing() ? TG('联机禁用')
          : (this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.tap(38))
          .onClick(() => {
            this.askAuto();
          })
                    // ★★★ 2026-11-01 奥森硬约束：**AI 代打在联机对战中不能启用**
          //   这 16 款是自绘按钮行，HintBar 那套保护没走到它们身上
          .enabled(!LanRace.isRacing())
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L565'; })
          .onBlur(() => { if (this.tvFocus === 'L565') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L565'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
        Button(TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.berry)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.tap(38))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L580'; })
          .onBlur(() => { if (this.tvFocus === 'L580') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L580'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(TG('每行每列都要有 0~9 各一次；灰底是题目给的数'))
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
