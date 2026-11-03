/**
 * 宝石迷阵 —— 交换相邻宝石，凑出三个以上同色即消除
 *
 * 玩法：点一颗宝石 → 点它上下左右相邻的一颗 ⇒ 交换；换出三连就消，消完上面的会掉下来接着连消
 * 胜负：MOVE_LIMIT 步内达到 TARGET 分 ⇒ solved=true；步数用完没到 ⇒ solved=false
 * 坐标口径：整盘在 7×7 网格里，格子用 layoutWeight(1) 均分，视觉与机型无关
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 7;               // 盘面边长
const KINDS: number = 5;           // 宝石种类
const MOVE_LIMIT: number = 20;     // 步数上限
const TARGET: number = 600;        // 通关分数线
const PER_GEM: number = 10;        // 每消一颗的分

const GEMS: string[] = ['💎', '🔥', '🍀', '🔮', '💧'];

// ★★★ 2026-11-03（第 1014 轮）**逐字形垂直微调**（奥森报「水滴没在圆盘里居中」）
//   实测：49 颗宝石的**几何重心**偏差全部 < 0.25px（数学上完美居中），
//        但 emoji 是彩色字形，**视觉重心**与几何重心不同：
//          💎 上宽下尖（倒三角）⇒ 视觉重心**偏上** ⇒ 需**下移**
//          🔥 火苗上窜、底部宽   ⇒ 视觉重心**偏下** ⇒ 需**上移**
//          🍀 近似圆形           ⇒ 对称 ⇒ **不动**
//          🔮 球体 + 底座         ⇒ 视觉重心**偏下** ⇒ 需**上移**
//          💧 上尖下圆           ⇒ 视觉重心**偏下** ⇒ 需**上移**
//   ⇒ 用 `.offset({ y })` 补偿（**只做视觉平移，不影响布局**，判据 305）。
//   ⚠️ 数值是按"目测视觉重心 × 格子占比"定的；换字号时需要等比缩放。
const GEM_DY: number[] = [1.0, -1.0, 0, -1.0, -1.5];
const GEM_COLORS: string[] = [
  Palette.sky, Palette.orange, Palette.emerald, Palette.violet, Palette.primary
];

/** 0..n-1 下标数组（给 ForEach 用，只建一次） */
function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GBejeweled {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-10-31 演示动画改造：三拍节拍 + 强视觉引导
  //   奥森原话：「我认为的'演示'不是这样的呀！应该就是一段演示动画」
  //   旧实现一个 tick 内 tap(a);tap(b) 全做完 ⇒ 玩家只看到格子瞬间变了。
  @State private demoGuideA: number = -1;   // 第 1 拍要高亮的格（交换源）
  @State private demoGuideB: number = -1;   // 第 1 拍要高亮的格（交换目标）
  @State private demoRound: number = 0;     // 演到第几轮
  @State private demoPhase: number = 0;     // 0=引导 1=执行 2=结果
  // ★★ 2026-10-31 奥森要求：**演示不该让玩家得分** —— 它是一段动画，不是一局游戏。
  //   ⇒ 演示前把（棋盘/得分/剩余步数）快照下来，演示结束后**原样恢复**。
  //     演示期间屏上看到的是"预演"，玩家的真实对局状态从头到尾没被动过。
  private demoSnapBoard: number[] = [];
  private demoSnapScore: number = 0;
  private demoSnapLeft: number = 0;
  @State private demoScored: number = 0;    // 演示期间"假的"得分（只显示，不进记录）
  @State private board: number[] = [];
  @State private sel: number = -1;
  /**
   * ★★★ 2026-11-01 真机（智慧屏 960×540）：**游戏内焦点框不可见**。
   *   根因：`.focusBox()` 按 SDK 文档「只改样式，不管框出不出现」（common.d.ts:18880）。
   *   ⇒ 用 `onFocus/onBlur` 记下当前聚焦的格子索引，再用 `.border()` 自绘。
   *   这是「工具先于批量」的第一款试点（Tv.focusBorder 已就绪）。
   */
  @State private tvFocus: number = -1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(MOVE_LIMIT);
  @State private left: number = 0;
  @State private msg: string = TG('点一颗宝石，再点它相邻的一颗');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBejeweled')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.timeNow(MOVE_LIMIT);
    this.reset();
  }

  private idx(r: number, c: number): number {
    return r * N + c;
  }

  /**
   * ★★★ 2026-11-01 **棋盘焦点导航的试点（第 1/355 款）**：
   *   背景（台账第 665 轮 TAB 对照实验）：ArkUI 的 **2D 方向键遍历在游戏页不工作**，
   *   但线性 TAB 遍历正常 ⇒ 焦点系统本身是好的。
   *   ⇒ 唯一出路是**自己实现方向键导航**：每格一个有意义的稳定 id + 显式 requestFocus。
   *
   *   id 用 `cell_行_列`（不是下标）—— 下标在换列数时会错位，
   *   而行列是**几何位置**，换布局也不会指错（判据：锚点要选结构决定的位置）。
   */
  private cellId(r: number, c: number): string {
    return 'cell_' + r + '_' + c;
  }

  private reset(): void {
    this.board = this.fill();
    this.sel = -1;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点一颗宝石，再点它相邻的一颗');
    this.startAt = Date.now();
  }

  /** 开局盘面：随机填，且保证开局没有现成三连 */
  private fill(): number[] {
    let b: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < b.length; i++) {
      b[i] = Math.floor(Math.random() * KINDS);
    }
    for (let t = 0; t < 80; t++) {
      const m: number[] = this.mark(b);
      let again: boolean = false;
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = Math.floor(Math.random() * KINDS);
          again = true;
        }
      }
      if (!again) {
        break;
      }
    }
    return b;
  }

  /** 标记所有已成三连及以上的格子（1 = 要消） */
  private mark(b: number[]): number[] {
    const m: number[] = new Array<number>(N * N).fill(0);
    for (let r = 0; r < N; r++) {
      let run: number = 1;
      for (let c = 1; c <= N; c++) {
        const same: boolean = c < N && b[this.idx(r, c)] === b[this.idx(r, c - 1)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = c - run; k < c; k++) {
              m[this.idx(r, k)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    for (let c = 0; c < N; c++) {
      let run: number = 1;
      for (let r = 1; r <= N; r++) {
        const same: boolean = r < N && b[this.idx(r, c)] === b[this.idx(r - 1, c)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = r - run; k < r; k++) {
              m[this.idx(k, c)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    return m;
  }

  private hasMark(b: number[]): boolean {
    const m: number[] = this.mark(b);
    for (let i = 0; i < m.length; i++) {
      if (m[i] === 1) {
        return true;
      }
    }
    return false;
  }

  /** 消掉空格后向下压实，顶上补新宝石（原地改 b） */
  private settle(b: number[]): void {
    for (let c = 0; c < N; c++) {
      let write: number = N - 1;
      for (let r = N - 1; r >= 0; r--) {
        const v: number = b[this.idx(r, c)];
        if (v >= 0) {
          b[this.idx(write, c)] = v;
          if (write !== r) {
            b[this.idx(r, c)] = -1;
          }
          write--;
        }
      }
      for (let r = write; r >= 0; r--) {
        b[this.idx(r, c)] = Math.floor(Math.random() * KINDS);
      }
    }
  }

  /** 反复消除直到没有三连；返回本次连消总分（含 combo 加成） */
  private resolve(): number {
    let gained: number = 0;
    let combo: number = 1;
    while (combo <= 30) {          // 上限兜底：连消不会无限，但绝不让自己卡死
      const b: number[] = this.board.slice();
      const m: number[] = this.mark(b);
      let cnt: number = 0;
      for (let i = 0; i < m.length; i++) {
        if (m[i] === 1) {
          cnt++;
        }
      }
      if (cnt === 0) {
        break;
      }
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = -1;
        }
      }
      this.settle(b);
      this.board = b;
      gained += cnt * PER_GEM * combo;
      combo++;
    }
    return gained;
  }

  private adjacent(a: number, b: number): boolean {
    const ar: number = Math.floor(a / N);
    const ac: number = a % N;
    const br: number = Math.floor(b / N);
    const bc: number = b % N;
    return Math.abs(ar - br) + Math.abs(ac - bc) === 1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这盘没有"答案字段"—— 现搜一对能换出三连的相邻格（判据就是游戏自己的 hasMark）
  private aiSwapOk(a: number, b: number): boolean {
    const t: number[] = this.board.slice();
    const tmp: number = t[a];
    t[a] = t[b];
    t[b] = tmp;
    return this.hasMark(t);
  }

  /** 返回 a * 100 + b（一对可换的相邻格），-1 = 没有可换的 */
  private aiFindPair(): number {
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const a: number = r * N + c;
        if (c + 1 < N && this.aiSwapOk(a, a + 1)) {
          return a * 100 + (a + 1);
        }
        if (r + 1 < N && this.aiSwapOk(a, a + N)) {
          return a * 100 + (a + N);
        }
      }
    }
    return -1;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  /** 演示：**三拍**（引导 → 执行 → 结果），演 2 轮 ≈ 4.6 秒
   *  ★ 为什么改：旧版一个 tick 内做完交换，玩家看不到"在指哪、做了什么"。
   *    新版第 1 拍先把两颗要交换的宝石**圈出来并放大**，配一句"看这两颗"；
   *    第 2 拍才真正交换（280ms 短促）；第 3 拍留 1.15 秒让你看清"消掉了"。
   */
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    // ── 第 1 拍：引导 ──
    if (this.demoPhase === 0) {
      this.sel = -1;
      const m: number = this.aiFindPair();
      if (m < 0 || this.demoRound >= 2) { this.demoFinish(); return -1; }
      this.demoGuideA = Math.floor(m / 100);
      this.demoGuideB = m % 100;
      this.msg = TG('看这两颗：交换它们，三个同色就消掉');
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    // ── 第 2 拍：执行 ──
    if (this.demoPhase === 1) {
      const a: number = this.demoGuideA;
      const b: number = this.demoGuideB;
      this.demoGuideA = -1;
      this.demoGuideB = -1;
      if (a >= 0 && b >= 0) {
        this.tap(a);
        this.tap(b);
      }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    // ── 第 3 拍：结果 ──
    this.demoRound = this.demoRound + 1;
    this.demoScored = this.score - this.demoSnapScore;
    this.msg = this.demoRound >= 2
      ? TG('就这样连。这就是全部玩法 —— 碰一下屏幕，换你来')
      : TG2('消掉了！这一下能拿 +{0} 分（演示不计分）', String(this.demoScored));
    this.demoPhase = 0;
    if (this.demoRound >= 2) {
      this.demoFinish();
      return Demo.RESULT_MS;
    }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    // ★★★ 2026-11-01 真机（智慧屏 960×540）抓到：**演示 21 秒还没结束**。
    //   根因：这一款是手工写的 demoFinish，**漏了停计时器**。
    //     · demoBeat 在 `demoRound >= 2` 时调 `demoFinish()` 并 `return -1`
    //     · 但 `demoFinish()` 只复位数据，没有 `Demo.stop(demoId)`、没有 `demoId = -1`
    //     ⇒ `demoId` 仍然是正数 ⇒ 界面 `this.demoId >= 0` 恒真
    //     ⇒ 演示条永远显示「演示中…」，而真正能停下它的 demoStop() 只挂在 onTouch 上
    //     ⇒ **遥控器/键盘用户永远停不下来。**
    //   ★ 全项目查过：355 款里只有这一款漏（其余 354 款由批量脚本生成，都带 Demo.stop）。
    //     这就是"手工版与批量版分叉"的代价 —— 手工写的那一份没有跟上后续修复。
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoGuideA = -1;
    this.demoGuideB = -1;
    this.demoPhase = 0;
    this.demoRound = 0;
    // 原样恢复 —— 演示期间的一切改动都被抹掉
    if (this.demoSnapBoard.length === this.board.length) {
      this.board = this.demoSnapBoard;
    }
    this.score = this.demoSnapScore;
    this.left = this.demoSnapLeft;
    this.demoScored = 0;
    this.demoSnapBoard = [];
    this.over = false;
    this.won = false;
    this.sel = -1;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    // 演示前快照：演完原样恢复 ⇒ **玩家不可能因为看演示而得分/失分**
    this.demoSnapBoard = this.board.slice();
    this.demoSnapScore = this.score;
    this.demoSnapLeft = this.left;
    this.demoScored = 0;
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.sel = -1;
    const m: number = this.aiFindPair();
    if (m < 0) {
      return false;
    }
    this.tap(Math.floor(m / 100));
    this.tap(m % 100);
    return !this.over;
  }

  /** 提示：报这一对可换的宝石（报行列，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const m: number = this.aiFindPair();
    if (m < 0) {
      return Hint.none('none');
    }
    const a: number = Math.floor(m / 100);
    const b: number = m % 100;
    // ★★★ 2026-11-01 真机（英文模式）抓到 i18n 断点：
    //   这里原来把「排/列」**硬拼进数字**（`1 + '排' + 2 + '列'`），
    //   然后整串塞进 `TG2('换 {0} 与 {1} 这两颗能消')` 的 {0}/{1}。
    //   ⇒ 中文对了，但**英文模式下坐标仍是中文**：「Swap 1排2列 with 2排2列」。
    //   ★ 而 i18n 脚本查不出来 —— 它只核对**字典条目**（2888×10），
    //     查不到**运行时拼接**出来的字符串。这是 i18n 的盲区。
    //   ⇒ 改用字典里**已有的**模板 `'第 {0} 排第 {1} 列'`
    //     （10 语言齐全，en = "Row {0}, column {1}"）⇒ 一处复用，不用新增翻译。
    const pa: string = TG2('第 {0} 排第 {1} 列', Math.floor(a / N) + 1, (a % N) + 1);
    const pb: string = TG2('第 {0} 排第 {1} 列', Math.floor(b / N) + 1, (b % N) + 1);
    return Hint.make([a, b], TG2('换 {0} 与 {1} 这两颗能消', pa, pb),
      TG2('Swap {0} with {1} to clear', pa, pb), t0);
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
    if (this.over) {
      return;
    }
    if (this.sel < 0) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    if (!this.adjacent(this.sel, i)) {
      this.sel = i;
      return;
    }

    const a: number = this.sel;
    const nb: number[] = this.board.slice();
    const t: number = nb[a];
    nb[a] = nb[i];
    nb[i] = t;

    if (!this.hasMark(nb)) {
      this.sel = i;
      this.msg = TG('这样换不出三连，换一颗试试');
      return;
    }

    this.board = nb;
    this.sel = -1;
    this.left--;
    const gained: number = this.resolve();
    this.score += gained; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.msg = TG2("消除 +{0} 分", gained);
    if (this.left <= 0) {
      this.end();
    }
  }

  private end(): void {
    this.over = true;
    this.won = this.score >= TARGET;
    this.msg = this.won ? '🎉 达标！' : '步数用完，差一点';
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'bejeweled',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: MOVE_LIMIT - this.left
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 棋盘边长（vp）：按「可用宽 / 可用高」取小值
   *  ★★★ 2026-10-30：百分比（70% / 45%）在横竖屏下不可能同时最优
   *    ⇒ 按真实可用空间算。
   */
    private boardPx(): number {
    // ★★★ 2026-10-31 · 第四版（前三版都错，完整记录）：
    //   ① `Bp.height * 0.55`          ⇒ 横屏 293vp，把「重开」挤出屏幕
    //   ② `(Bp.height - 260) * 0.85`  ⇒ 横屏 232vp，**仍然超 27vp**
    //      （实测：棋盘 232vp 时「重开」y=1562px，安全上限 1480px）
    //   ③ 错误原因：**固定部分是绝对值**（顶栏/HintBar/三信息卡/状态/按钮），
    //      不是比例；且我两次都把固定部分估小了。
    //   ④ 用实测数据反推：需要棋盘 ≤ 205vp ⇒ 比例取 **0.70**。
    //      横屏 (533-260)*0.70 = 191vp ⇒ 「重开」约 480vp（安全）
    //      竖屏 (1280-260)*0.70 = 714vp（受宽度限，仍比旧 704 大）
    // ★★★ 2026-11-03（第 1012 轮）**300 → 200**：
    //   奥森截图报「宝石错位」⇒ 实测是 **7 列而不是 8 列**（宝石 49 个，应 64）。
    //   算账：格子 51px、间距 18px ⇒ 8×51 + 7×18 = **534px**，
    //         而 `boardPx` 给的容器只有 **504px** ⇒ 溢出 30px ⇒ 第 8 列被挤掉。
    //   而 dump 实测：游戏区可用高 **1155px = 385vp**，
    //         540 − 385 = **155vp** 才是真正的固定部分 ⇒ **300 高估了 145vp**。
    //   ⇒ 先降到 200 试（给棋盘 238vp = 714px，够 8×8 且留余量）。
    const FIXED: number = 200;
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(120, (Bp.height - FIXED) * 0.70);
    return Math.min(w, h);
  }

  build() {
    // ★★★ 2026-10-30：横屏 853×533 下「其余部分就有 368vp」，
    //   棋盘 maxHeight 即便降到 45%（240vp），总计仍有 608vp > 533vp。
    //   ⇒ **必须套 Scroll 兜底**，让玩家能滚到「重开 / 提示 / AI 代打」。
    //   这是本项目第 4 款用同一个 Scroll 模板修好的游戏（前 3 款：
    //   GColorFlood / GFillomino / GBlockEscape 系列）。
    Scroll() {
      Column({ space: Space.sm }) {
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
          onAutoTap: () => { this.askAuto(); },
          demoOn: this.demoId >= 0,
          autoOn: this.autoId >= 0,
          // ★★★ 2026-11-01：全项目 339 处 HintBar 里有 338 处带这个保护，
          //   **唯一漏的就是这一款**（手工版没跟上批量改造）。
          //   不加的后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint；
          //   按「AI 代打」会再起一个计时器，与演示计时器同时改棋盘。
          disabled: this.demoId >= 0
        })
        Row({ space: Space.sm }) {
          Column({ space: 2 }) {
          Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((this.demoId >= 0 ? '—' : Digits(String(this.score), this.langCode))).fontSize(FontSize.lg)
          // ★ 得分跳动
          .scale({ x: this.scorePulse, y: this.scorePulse })
          .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(Digits(String(TARGET), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((this.demoId >= 0 ? '—' : Digits(String(this.left), this.langCode))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .width('100%')

        Column({ space: Space.xs }) {
          ForEach(this.rows, (r: number) => {
            Row({ space: Space.xs }) {
              ForEach(this.rows, (c: number) => {
                Stack() {
                Text(GEMS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
                .fontSize(FontSize.lg)   // xl → lg：留边距，压掉字形偏差
                // ★★★ 2026-11-03（第 1012 轮）**emoji 在圆盘里不居中**（奥森截图报的）
                //   现象：🔥 / 💧 偏下，💎 / 🍀 偏上 —— 同一行里"重心"各不相同，像错位。
                //   根因：`Stack` 的 alignContent 只让**文本框**居中，
                //     而 emoji 的**图形**在字体的 em box 里本身偏上/偏下（各字形不同）。
                //   ⇒ 让文本盒子填满格子，再用 textAlign + align 双轴居中；
                //     同时把 fontSize 从 xl 降到 lg —— 留出边距，让 1~2px 的字形偏差不显眼。
                .textAlign(TextAlign.Center)
                .width('100%').height('100%')
                .align(Alignment.Center)
                // ★ 逐字形微调（见 GEM_DY 的注释）
                .offset({ y: GEM_DY[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0] })
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .backgroundColor(GEM_COLORS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
                .borderRadius(Radius.sm)
                .scale({
                x: (this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? 1.24 : (this.sel === (this.idx(r, c)) ? 1.14 : 1),
                y: (this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? 1.24 : (this.sel === (this.idx(r, c)) ? 1.14 : 1)
                })
                // ★ 演示引导：被指到的两颗加描边 + 光晕，玩家一眼知道"看这里"
                // ★ 焦点框（4vp 主色）优先于演示引导（3vp 琥珀）：
                //   两者都是"看这里"，但焦点是"你现在能操作这里"，优先级更高。
                .border((this.tvFocus === this.idx(r, c))
                  ? Tv.focusBorder(true)
                  : {
                    width: (this.demoGuideA === this.idx(r, c) || this.demoGuideB === this.idx(r, c)) ? 3 : 0,
                    color: Palette.amber
                  })
                .shadow((this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? { radius: 18, color: '#99FFFFFF', offsetX: 0, offsetY: 0 }
                  : Shadow.card)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
                // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
                .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                  .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
                .id(this.cellId(r, c))
                // ★★★★ 2026-11-01 **棋盘焦点的最终结论（8 条假设，全排除）**：
                //
                //   ✅ 已经查清的事实（全部真机证据）：
                //     · id 建成了（uitest dumpLayout 能看到 cell_0_0 … cell_6_6）
                //     · requestFocus 返回 false（hilog 实测）
                //     · TAB 遍历从不经过它们（逐次 dump `focused=true`，9 次 TAB 全在
                //       hdr-0..4 和 Scroll/Button 之间循环）
                //     ⇒ **那 49 个格子完全不在焦点树里。**
                //
                //   ❌ 8 条假设全排除：
                //     ① 去掉根容器 defaultFocus　② 根容器 focusable(false)
                //     ③ 上下键不吃掉　④ 显式 requestFocus
                //     ⑤ GameHost 外包层 focusScopeId　⑥ 游戏组件根 focusScopeId
                //     ⑦ 游戏组件根 focusable
                //     ⑧ **nextFocus**（SDK 里唯一"专为方向键导航"的 API，
                //        见 common.d.ts:18796「tabIndex only customizes Tab key navigation.
                //        For arrow key navigation customization, use nextFocus」）
                //        —— 能编译（只警告），但**运行时无效**，TAB 路径一字未变。
                //
                //   🔑 **真正的解法是版本问题，不是写法问题**：
                //     · `tabStop` since API 14　· `nextFocus` since API 18
                //     · 项目 `compatibleSdkVersion = 5.0.0(12)`
                //     ⇒ **升到 API 18+ 后，`nextFocus` 一行就能给出方向键导航**，
                //        不需要给 1166 处加 id、也不需要显式 requestFocus。
                //     ⇒ 但升 compatibleSdkVersion 会缩小支持的设备范围 ——
                //        **这是产品决策，需要奥森点头**，不该我替他定。
                //
                //   当前状态：格子保持 focusable + id + onKeyEvent 导航代码
                //   （失败路径已做安全处理：requestFocus 失败就不 stopPropagation），
                //   升 API 后这段代码会**直接生效**，无需再改。
                // ★★★★ 2026-11-01 **最终结论（9 条假设全排除，含升 API 实验）**：
                //
                //   ✅ 已查清的事实（全部真机证据）：
                //     · id 建成了（dump 能看到 cell_0_0 … cell_6_6）
                //     · requestFocus 返回 false（hilog 实测）
                //     · TAB 遍历从不经过它们（9 次 TAB 逐次 dump，全在 hdr-0..4 和
                //       Scroll/Button 之间循环）⇒ **格子完全不在焦点树里**
                //
                //   ❌ 9 条假设全排除：
                //     ① 去根 defaultFocus ② 根 focusable(false) ③ 上下键不吃掉
                //     ④ 显式 requestFocus ⑤ GameHost 外包层 focusScopeId
                //     ⑥ 游戏组件根 focusScopeId ⑦ 游戏组件根 focusable
                //     ⑧ nextFocus（API 12 下编译过但运行时无效）
                //     ⑨ **升 compatibleSdkVersion 到 5.1.0(18) 后再试 nextFocus**
                //        —— 能编译、能装、能跑，但 **TAB 路径一字未变**
                //        ⇒ 已回退（升 API 不影响设备范围之外的东西，没必要）
                //
                //   ★ 关键认识（省掉了一次不该做的产品决策）：
                //     `nextFocus` 管的是「**已经聚焦时**按方向键跳到哪个 id」，
                //     不是「把这个组件注册进焦点树」。
                //     ⇒ 格子不在焦点树里，nextFocus 就无事可做。
                //     ⇒ **升 API 不解决这个问题** —— 不用为此缩小设备支持范围。
                //
                //   ⇒ 剩下的方向只有架构级：让棋盘元素成为**页面级**的焦点参与者
                //     （把格子渲染上移到 GameHost 层，或用 Builder 展开到同一层）。
                //     那是 355 款的改造，需独立排期。
                .focusable(Tv.on())
                .focusBox(Tv.box())
                // ★ 自绘焦点框的真实驱动（focusBox 只改样式，不负责出现）
                .onFocus(() => { this.tvFocus = this.idx(r, c); })
                .onBlur(() => { if (this.tvFocus === this.idx(r, c)) { this.tvFocus = -1; } })
                .onKeyEvent((e: KeyEvent) => {
                  if (!Tv.on()) { return; }
                  // ★ 2026-11-01 试点：方向键在棋盘内**自己移动焦点**（ArkUI 默认遍历不工作）
                  if (Tv.isArrow(e.keyCode)) {
                    let nr: number = r;
                    let nc: number = c;
                    if (e.keyCode === Tv.KEY_UP) { nr = r - 1; }
                    else if (e.keyCode === Tv.KEY_DOWN) { nr = r + 1; }
                    else if (e.keyCode === Tv.KEY_LEFT) { nc = c - 1; }
                    else { nc = c + 1; }
                    // 边界内才移动（到边就不动，而不是跳到对面 —— 棋盘上"绕回去"会让人误操作）
                    if (nr >= 0 && nr < N && nc >= 0 && nc < N) {
                      let ok: boolean = false;
                      try {
                        ok = focusControl.requestFocus(this.cellId(nr, nc));
                      } catch (err) {
                        ok = false;
                      }
                      // ★★★ 2026-11-01 实测（hilog 插桩）：**requestFocus 返回 false**
                      //   —— id 确实存在（uitest dumpLayout 里能看到 cell_3_3，类型 Stack，
                      //   16×16 vp，clickable/enabled/visible 全 true），
                      //   但焦点系统不接受它。原因未查明（6 次 build 后按判据停手）。
                      //   ⇒ **只在成功时才吃掉按键**：失败就放行，否则方向键比改之前更没用
                      //     （吃掉 + 没移动 = 彻底无效）。
                      if (ok) {
                        e.stopPropagation();
                      }
                    }
                    return;
                  }
                  Tv.handleKey(e, () => { Haptics.tick(); this.tap((this.idx(r, c))); });
                })
                .onClick(() => {
                Haptics.tick();
                this.tap((this.idx(r, c)));
                })
              }, (c: number) => 'c' + c)
            }
            .width('100%')
            .layoutWeight(1)
          }, (r: number) => 'r' + r)
        }
      // ★★★ 2026-10-30 · 用「算出来的边长」，不用百分比
      //   百分比是相对父容器，而父容器横竖屏差一倍多 ⇒ 一个数不可能两头都好：
      //     70%  ⇒ 横屏 373vp 溢出（底部按钮被切）
      //     45%  ⇒ 横屏好了，但**竖屏 1280vp 下只剩 576vp，下方大片空白**（回归）
      //   ⇒ 改成 min(可用宽, 可用高)，两种比例都尽量大、又一定装得下。
      .width(this.boardPx())
      .height(this.boardPx())
        .padding(Space.xs)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.lg)
        .shadow(Shadow.card)

        // ★★★ 2026-11-01（第 814 轮）：**这一款是 355 款里唯一不用 DemoBar 的**。
        //   扫描结果：`DemoBar` 354/355（缺 GBejeweled），而它有完整演示逻辑
        //   （demoOnce / demoId / demoStop / 三拍文案都在）。
        //   后果有两处，都是别的款有、它没有：
        //     ① 演示时**没有「演示中」标识**（玩家不知道"现在不是我操作"）
        //     ② **没有极小屏降级**（DemoBar 在 <420vp 时只留「演示中」三个字，
        //        否则完整文案在 195vp 宽上要占 3 行、24vp 高的条里被切）
        //   ⇒ 接上 DemoBar；未演示时它高度为 0，不占位（与另外 354 款一致）。
        DemoBar({ on: this.demoId >= 0, msg: this.msg })

        // 演示进行中时，下面这行普通提示让位（避免两行字同时出现、上下重复）
        if (this.demoId < 0) {
          Text(this.msg)
            .fontSize(FontSize.sm)
            .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        }

        Row({ space: Space.md }) {
          Button(TG('重开'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md)
            .fontColor(Color.White)
            .backgroundColor(Palette.primary)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(46))
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
            .onClick(() => {
              Haptics.tap();
              this.reset();
            })
          Button(TG('取消选择'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md)
            .fontColor(this.theme.inkSoft)
            .backgroundColor(this.theme.surfaceAlt)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(46))
            // ★ 2026-11-01（第 812 轮）：原来的 `enabled(!this.over)` **只判"游戏结束"**，
            //   没判"有没有选中任何宝石" ⇒ 什么都没选时这个按钮仍可点、点完毫无反应。
            //   按"空操作不该看起来能点"的原则，加上 `this.sel >= 0`。
            .enabled(!this.over && this.sel >= 0)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.sel = -1; }); })
            .onClick(() => {
              Haptics.tap();
              this.sel = -1;
            })
        }
        .width('100%')

        // ★★★ 2026-11-01 真机（切难度后）抓到：难度显示「困难」、剩余步数 **14**，
        //   但底部还写「**20** 步内拿到 600 分算通关」—— 文案和实际不一致。
        //   根因：这里用的是常量 `MOVE_LIMIT`（=20），
        //        而实际步数走的是 `this.total = GameDiff.timeNow(MOVE_LIMIT)`
        //        （难度会**缩减**步数，困难档 14 步）。
        //   ⇒ 文案必须用运行时值 `this.total`，不能用常量。
        //   ★ 判据：**凡是"规则说明里出现的数字"，都必须是运行时读的，不能是常量。**
        //     常量写的文案在难度/关卡变化后一定和实际不符，而它**编译通过、断言全绿**。
        Text(TG2('每消一颗 +{0}，连消翻倍；{1} 步内拿到 {2} 分算通关',Digits(String(PER_GEM), this.langCode),Digits(String(this.total), this.langCode),Digits(String(TARGET), this.langCode)))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }
      .onTouch((e: TouchEvent) => {
        // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
        if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
      })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    // ★★★ 2026-11-01 **试过并回退（第 7 次失败，记在这里别再试）**：
    //   现象（真机 TAB 连按 9 次，逐次 dump `focused=true` 的节点）：
    //     焦点只在 `hdr-0..4` 和 `Scroll/Button` 之间循环，
    //     **从来没到达任何 `cell_*`** ⇒ 那 49 个格子**完全不在焦点树里**。
    //   试过的两个假设（都无效，TAB 路径一字未变）：
    //     · 根容器 `.focusScopeId('board', true)` —— 想把它声明成焦点组
    //     · 根容器 `.focusable(true)` —— 想让子树被注册进焦点树
    //   ⇒ 结论：**棋盘格子进不了焦点树，与容器的 focusScope/focusable 无关。**
    //     顶栏按钮能进，是因为它们是 GameHost（页面级）的直接子元素；
    //     棋盘在**另一个组件的子树**里 —— 而 ArkUI 在本页不把该子树纳入焦点遍历。
    //   已排除的完整清单（7 条）：
    //     ① 去掉根 defaultFocus ② 根 focusable(false) ③ 上下键不吃掉
    //     ④ 显式 requestFocus（id 存在，返回 false） ⑤ GameHost 外包层 focusScopeId
    //     ⑥ 游戏组件根 focusScopeId ⑦ 游戏组件根 focusable
  }




}
