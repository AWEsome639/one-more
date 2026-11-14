/**
 * 迷你数谜（Kakuro mini）—— 小盘数谜 ❓
 *
 * 规则：3×3 每格填 1~9；每行、每列的数字各不相同，且和等于旁边的提示数。
 * 胜负：六条线全部满足 = 通关；超过 40 步还没解出 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 3;
const MAX_MOVES: number = 40;

@Component
export struct GKakuroMini {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
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
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State private rowT: number[] = [0, 0, 0];
  @State private colT: number[] = [0, 0, 0];
  @State private sel: number = -1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  /** ★ 2026-11-08 重入闩锁（结算函数可能被多路径调用；over 由调用方先置，不能当守卫） */
  private settled: boolean = false;
  @State private won: boolean = false;
  /** ★ P18：给"和都对上了但没通关"一个明确原因（否则玩家只会觉得"完成了没算通关"） */
  @State private hint: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKakuroMini')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  // ── 出题：随机生成一张合法解，再取其行/列和作为提示 ──

  private canPut(g: number[], idx: number, v: number): boolean {
    const r: number = Math.floor(idx / N);
    const c: number = idx % N;
    for (let i = 0; i < N; i++) {
      if (g[r * N + i] === v || g[i * N + c] === v) {
        return false;
      }
    }
    return true;
  }

  private fill(g: number[], idx: number): boolean {
    if (idx === N * N) {
      return true;
    }
    const pool: number[] = [];
    for (let v = 1; v <= 9; v++) {
      if (this.canPut(g, idx, v)) {
        pool.push(v);
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    for (let i = 0; i < pool.length; i++) {
      g[idx] = pool[i];
      if (this.fill(g, idx + 1)) {
        return true;
      }
      g[idx] = 0;
    }
    return false;
  }

  private reset(): void {
    const g: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    this.fill(g, 0);
    const rt: number[] = [0, 0, 0];
    const ct: number[] = [0, 0, 0];
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        rt[r] += g[r * N + c];
        ct[c] += g[r * N + c];
      }
    }
    this.rowT = rt;
    this.colT = ct;
    this.vals = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    this.sel = 0;
    this.moves = 0;
    this.over = false;
    this.settled = false;
    this.won = false;
    this.hint = '';
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private distinct3(a: number, b: number, c: number): boolean {
    return a !== 0 && b !== 0 && c !== 0 && a !== b && a !== c && b !== c;
  }

  private rowOk(r: number): boolean {
    const a: number = this.vals[r * N];
    const b: number = this.vals[r * N + 1];
    const c: number = this.vals[r * N + 2];
    return this.distinct3(a, b, c) && a + b + c === this.rowT[r];
  }

  private colOk(c: number): boolean {
    const a: number = this.vals[c];
    const b: number = this.vals[N + c];
    const d: number = this.vals[2 * N + c];
    return this.distinct3(a, b, d) && a + b + d === this.colT[c];
  }

  private rowCur(r: number): number {
    return this.vals[r * N] + this.vals[r * N + 1] + this.vals[r * N + 2];
  }

  private colCur(c: number): number {
    return this.vals[c] + this.vals[N + c] + this.vals[2 * N + c];
  }

  private linesDone(): number {
    let n: number = 0;
    for (let i = 0; i < N; i++) {
      if (this.rowOk(i)) {
        n++;
      }
      if (this.colOk(i)) {
        n++;
      }
    }
    return n;
  }

  /**
   * 有没有「和已经对上、但同一行/列出现重复数字」的线。
   *
   * ★ P18「完成了没算通关」：判胜条件本身是对的（六条线都要"数字各不相同 + 和等于提示"），
   *   但界面上只看得到"和"（rowCur/colCur 变绿），**"各不相同"这条规则完全没提示** ——
   *   玩家用 3+3+9=15 这种凑出正确的和，就会以为通关了，实际判胜不给过。
   *   ⇒ 不改判胜（规则没写错），而是把原因说出来。
   */
  private dupLine(): boolean {
    for (let i = 0; i < N; i++) {
      const a: number = this.vals[i * N];
      const b: number = this.vals[i * N + 1];
      const c: number = this.vals[i * N + 2];
      if (a !== 0 && b !== 0 && c !== 0 && a + b + c === this.rowT[i] && !this.distinct3(a, b, c)) {
        return true;
      }
      const d: number = this.vals[i];
      const e: number = this.vals[N + i];
      const g: number = this.vals[2 * N + i];
      if (d !== 0 && e !== 0 && g !== 0 && d + e + g === this.colT[i] && !this.distinct3(d, e, g)) {
        return true;
      }
    }
    return false;
  }

  private finish(solved: boolean): void {
    if (this.settled) {
      return;
    }
    const r: GameResult = {
      gameId: 'kakuro_mini',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 15) : this.linesDone() * 80,
      durationMs: Date.now() - this.startAt,
      levelReached: this.linesDone()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.settled = true;
    this.onFinish(r);
  }

  private check(): void {
    let all: boolean = true;
    for (let i = 0; i < N; i++) {
      if (!this.rowOk(i) || !this.colOk(i)) {
        all = false;
      }
    }
    if (all) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    this.hint = this.dupLine()
      ? TG('和是对上了，但同一行/列里有重复数字 —— 每条线必须各不相同')
      : '';
    if (this.moves >= this.diffTotal) {
      this.over = true; this.won = false;
      this.finish(false);
    }
  }

  // ── 输入 ──

  private setVal(i: number, v: number): void {
    const n: number[] = this.vals.slice();
    n[i] = v;
    this.vals = n;
  }

  private tapCell(i: number): void {
    if (this.over) {
      return;
    }
    if (this.sel === i) {
      this.setVal(i, 0);
      this.moves++;
      this.check();
      return;
    }
    this.sel = i;
  }

  /** 和为 s 的三个互不相同数字（1..9）的全部排列，按 3 个一组摊平 */
  private triples(s: number): number[] {
    const out: number[] = [];
    for (let a = 1; a <= 9; a++) {
      for (let b = 1; b <= 9; b++) {
        if (b === a) {
          continue;
        }
        const c: number = s - a - b;
        if (c < 1 || c > 9 || c === a || c === b) {
          continue;
        }
        out.push(a);
        out.push(b);
        out.push(c);
      }
    }
    return out;
  }

  /** 解这一题（三行/三列各自互不相同且和等于提示数）⇒ 9 个数；解不出返回空数组 */
  private solveNow(): number[] {
    const r0: number[] = this.triples(this.rowT[0]);
    const r1: number[] = this.triples(this.rowT[1]);
    const r2: number[] = this.triples(this.rowT[2]);
    for (let i = 0; i < r0.length; i += 3) {
      const a: number = r0[i];
      const b: number = r0[i + 1];
      const c: number = r0[i + 2];
      for (let j = 0; j < r1.length; j += 3) {
        const d: number = r1[j];
        const e: number = r1[j + 1];
        const f: number = r1[j + 2];
        if (a === d || b === e || c === f) {
          continue;
        }
        for (let k = 0; k < r2.length; k += 3) {
          const g: number = r2[k];
          const h: number = r2[k + 1];
          const p: number = r2[k + 2];
          if (g === a || g === d || h === b || h === e || p === c || p === f) {
            continue;
          }
          if (a + d + g !== this.colT[0] || b + e + h !== this.colT[1] || c + f + p !== this.colT[2]) {
            continue;
          }
          return [a, b, c, d, e, f, g, h, p];
        }
      }
    }
    return [];
  }

  /** 代打：把选中格挪到第一个跟解不一样的格子，返回该填的数（0 = 不用填了） */
  private autoVal(): number {
    const sol: number[] = this.solveNow();
    if (sol.length < 9) {
      return 0;
    }
    let t: number = -1;
    for (let i = 0; i < 9; i++) {
      if (this.vals[i] !== sol[i]) {
        t = i;
        break;
      }
    }
    if (t < 0) {
      return 0;
    }
    this.sel = t;
    return sol[t];
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
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
    if (this.over || this.autoVal() < 1) {
      return true;
    }
    this.put(this.autoVal());
    return !this.over;
  }

  // 出题时就是先随机填一张合法盘，再把行/列和当提示 ⇒ 反解出来就是答案
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.sel < 0) {
      return Hint.none('none');
    }
    const sol: number[] = this.solveNow();
    if (sol.length < 9) {
      return Hint.none('none');
    }
    const v: number = sol[this.sel];
    // ★★★ 2026-11-01 全项目扫「提示说"这一格"但没给坐标」时抓到**唯一真的一处**：
    //   原来只说「这一格填 X」—— 而棋盘上没有高亮（这款不在 13 款描边名单里），
    //   玩家看到「这一格」却不知道是哪一格 ⇒ **提示等于没给**。
    //   同批另外两款（GGomoku / GLetterGridSwapper）主文案本来就带行列，是假警报。
    //   ⚠️ 踩到一个差点用错的变量：
    //     `this.diffTotal = GameDiff.livesNow(MAX_MOVES)` 是**步数上限**，不是列数！
    //     网格边长是模块级 `N`（=3）。用 diffTotal 算行列会算错。
    const hr: number = Math.floor(this.sel / N) + 1;
    const hc: number = (this.sel % N) + 1;
    const pos: string = TG2('第 {0} 行第 {1} 列填 {2}', String(hr), String(hc), String(v));
    return Hint.make([this.sel],
      TG2('{0} —— 整盘解是 {1}', pos, sol.slice(0, 3).join(' ') + ' / ' + sol.slice(3, 6).join(' ')),
      'Fill ' + String(v) + ' here; the full solution is ' + sol.join(' '), t0);
  }
  private askAuto(): void {
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
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private put(d: number): void {
    if (this.over || this.sel < 0) {
      return;
    }
    this.setVal(this.sel, d);
    this.moves++;
    let next: number = -1;
    for (let k = this.sel + 1; k < N * N; k++) {
      if (this.vals[k] === 0) {
        next = k;
        break;
      }
    }
    this.sel = next;
    this.check();
  }

  private backspace(): void {
    if (this.over || this.sel < 0) {
      return;
    }
    this.setVal(this.sel, 0);
    this.moves++;
    this.check();
  }

  build() {
    Scroll() {
      Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
        // ★ 演示条（共用组件；未演示时高度为 0，不占位）
        DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
          onAutoTap: () => { this.askAuto(); },
          demoOn: false,
          disabled: this.demoId >= 0,
          autoOn: this.autoId >= 0
        })
        Row({ space: Space.md }) {
          // ⚠️ 只传「种类」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这两格永不刷新
          this.head(0)
          this.head(1)
        }
        .width('100%')

        // 4×4：左上角留空，第一行是列和，第一列是行和
        Column({ space: Space.xs }) {
          Row({ space: Space.xs }) {
            this.corner()
            ForEach([0, 1, 2], (c: number) => {
              this.colSum(c)
            }, (c: number) => 'cs' + c)
          }
          .width('100%')

          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.xs }) {
              this.rowSum(r)
              ForEach([0, 1, 2], (c: number) => {
                this.cellBox(r * N + c)
              }, (c: number) => 'cb' + r + '-' + c)
            }
            .width('100%')
          }, (r: number) => 'gr' + r)
        }
        .width('100%')
        // ★★★ 2026-11-08 **横屏棋盘下沿被底部 tab 栏裁掉**（verifier-dev 真机实测）：
        //   本款根容器是 `Column`（无 Scroll），棋盘 `width('100%')` + 内部格子 `aspectRatio(1)`
        //   ⇒ 853 宽时棋盘高 ≈813vp，远超声高 ⇒ 底边压到 y≈1600，被 tab 栏盖住。
        //   ⇒ 判据 1802：**约束加在「棋盘容器」上**（不是格子），横屏按可用高反推；
        //   ★ 模板取自同族的 `GKakuro`（那边用 -310，因为它按钮行**紧贴棋盘正下方**；
        //     本款按钮在上方 ⇒ 先用 -260，真机量了不够再压）。
        //   ★ 手机零回归：`Bp.height >= 600` 走 9999（等于不约束）。
        // ★ 2026-11-08 **第二次校准**（verifier-dev 真机量）：`-260` 时格子底 1536px，
        //   而安全区是 1516px ⇒ **还差 ~20px**（仍压在手势区边缘）。
        //   对照 `GShikaku`（同批同一修法）：它格底 1385px、收进来 215px ⇒ **已安全**。
        //   ⇒ 再收 20px。
              // ★ 2026-11-12（判据 1928+1939）：`aspectRatio(1)` 板子 **`maxHeight` 只裁不缩** ⇒ 改 `maxWidth`；
              //   按 3×3 反推：可用高 ~343vp − 键盘两行(~90) − 提示(17) ≈ 236vp ⇒ 留余量取 `Bp.height - 320`。
              // 2026-11-14 真机截图（blk=24px）：**盘面末行 + 数字键 `1~5` 都被切**
              //   11-12 那条 `Bp.height - 320` 还不够（两行键盘 `~90vp` + 提示 + 头 `480px` 已把预算吃满）
              //   ⇒ 再收 40vp：`Bp.height - 360`（3×3 ⇒ 每格 ~58vp，仍在 44 触控下限之上）
              .constraintSize({ maxWidth: Bp.height < 600 ? Math.min(Bp.width - 2 * Space.lg, Math.max(120, Bp.height - 360)) : 9999 })
        .padding(Space.sm)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)

        Text(this.over ? (this.won ? TG('🎉 六条线全对，通关！') : TG('步数用尽，重开一题吧')) :
          (this.hint.length > 0 ? '⚠️ ' + this.hint :
            (this.sel < 0 ? TG('点一个格子开始填数') : TG('点下面数字填入选中格；再点格子可清空'))))
          .fontSize(FontSize.sm)
          // ★ 2026-11-12（判据 1939）：矮屏只隐藏「空闲那句长说明」（两行、占 ~40px），
          //   **保留 `over`（胜负）与 `hint`（报错）** —— 反馈不能丢。
          .visibility(Bp.isShort() && !this.over && this.hint.length === 0 ? Visibility.None : Visibility.Visible)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

        // 数字键盘
        Row({ space: Space.xs }) {
          ForEach([1, 2, 3, 4, 5], (d: number) => {
            this.keyBtn(d)
          }, (d: number) => 'k' + d)
        }
        .width('100%')
        Row({ space: Space.xs }) {
          ForEach([6, 7, 8, 9], (d: number) => {
            this.keyBtn(d)
          }, (d: number) => 'k' + d)
          this.delKey()
        }
        .width('100%')

        Row({ space: Space.md }) {
          Button(TG('换一题'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md).fontColor(Color.White)
            .backgroundColor(Palette.teal).borderRadius(Radius.md)
            .layoutWeight(1).height(Cell.tap(44))
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'L567'; })
            .onBlur(() => { if (this.tvFocus === 'L567') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'L567'))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
            .onClick(() => {
              Haptics.tap();
              this.reset();
            })
          Button(TG('重开'))
        // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md).fontColor(this.theme.ink)
            .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
            .layoutWeight(1).height(Cell.tap(44))
            .focusable(Tv.on())
            .onFocus(() => { this.tvFocus = 'L579'; })
            .onBlur(() => { if (this.tvFocus === 'L579') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'L579'))
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
            .onClick(() => {
              Haptics.tap();
              this.reset();
            })
        }
        .width('100%')
      }
      .onTouch((e: TouchEvent) => {
        // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
        if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
      })
      .width('100%')
      // .height('100%')  ← 2026-11-14：套 Scroll 后不能用 100%（内容高=视口高⇒滚不动），判据见 _巡检记录
    }
  }

  /** 顶部小格：kind 0=步数 1=完成线 */
  @Builder
  head(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : TG('完成线'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves) + '/' + String(this.diffTotal)
        : String(this.linesDone()) + '/6')
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1).padding(Space.sm)
    .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
  }

  @Builder
  corner() {
    Row()
      .layoutWeight(1)
      .aspectRatio(1)
      .backgroundColor('#00000000')
  }

  @Builder
  colSum(c: number) {
    Column({ space: 2 }) {
      Text('↓' + String(this.colT[c]))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(Palette.teal)
      Text(String(this.colCur(c)))
        .fontSize(FontSize.xxs)
        .fontColor(this.colOk(c) ? Palette.emerald : this.theme.inkFaint)
    }
    .layoutWeight(1).aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colOk(c) ? '#1910B981' : '#00000000').animation({ duration: Motion.fast, curve: Motion.snap() })
    .borderRadius(Radius.xs)
  }

  @Builder
  rowSum(r: number) {
    Column({ space: 2 }) {
      Text(String(this.rowT[r]) + '→')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(Palette.teal)
      Text(String(this.rowCur(r)))
        .fontSize(FontSize.xxs)
        .fontColor(this.rowOk(r) ? Palette.emerald : this.theme.inkFaint)
    }
    .layoutWeight(1).aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.rowOk(r) ? '#1910B981' : '#00000000')
    .borderRadius(Radius.xs)
  }

  @Builder
  cellBox(i: number) {
    Stack() {
      Text(this.vals[i] === 0 ? '' : String(this.vals[i]))
        .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.sel === i ? Palette.tint('22') : this.theme.surface)
    .borderRadius(Radius.sm)
    .border({ width: this.sel === i ? 2 : 1, color: this.sel === i ? Palette.primary : this.theme.line })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'L664'; })
    .onBlur(() => { if (this.tvFocus === 'L664') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'L664', Radius.sm))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell(i); }); })
    .onClick(() => {
      Haptics.tick();
      this.tapCell(i);
    })
  }

  @Builder
  keyBtn(d: number) {
    Text(String(d))
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.tap(44))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L683'; })
      .onBlur(() => { if (this.tvFocus === 'L683') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L683', Radius.sm))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put(d); }); })
      .onClick(() => {
        Haptics.tick();
        this.put(d);
      })
  }

  @Builder
  delKey() {
    Text('⌫')
      .accessibilityText(TG('删除'))
      .fontSize(FontSize.xl)
      .fontColor(Palette.rose)
      .textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.tap(44))
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L702'; })
      .onBlur(() => { if (this.tvFocus === 'L702') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L702', Radius.sm))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.backspace(); }); })
      .onClick(() => {
        Haptics.tick();
        this.backspace();
      })
  }
}
