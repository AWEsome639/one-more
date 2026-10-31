/**
 * 数回环 slitherlink（5×5）—— 画一条闭合回路，使每格数字 = 该格四边中被画上的边数
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：线索全对 + 回路闭合且只有一个环 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已满足线索 ／ 已画边数 ／ 已用步数
 *
 * 棋盘是 (2N+1)×(2N+1) 的网格：偶偶 = 顶点，偶奇 = 横边，奇偶 = 竖边，奇奇 = 格子
 */

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
import { Tv } from '../core/Tv';

const NC: number = 5;                       // 5×5 格
const CELLS: number = NC * NC;
const HE_CNT: number = (NC + 1) * NC;       // 横边 30
const VE_CNT: number = NC * (NC + 1);       // 竖边 30
const VN: number = NC + 1;                  // 每行顶点数 6
const V_CNT: number = VN * VN;
const STEP_BUDGET: number = 120;
const BAR: number = Space.xs;               // 已画边的粗细
const THIN: number = 2;                     // 未画边的淡引导线
const DOT: number = 4;                      // 顶点小点

/** 3 关线索（0~4，格子四边中被画的边数） */
/** 显示网格的 11 个下标 */
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];


/**
 * ★ 3 关的答案（离线解出来的，已用 isWin 逐条复核过：线索全对 + 恰好一个闭合回路）
 *   前 30 个数 = 横边 he[0..29]，后 30 个数 = 竖边 ve[0..29]，1 = 画上
 *   ⇒ 代打 / 提示直接照真值走，不做搜索（手机上秒回）
 */
const SOL_HE: number[][] = [
  [1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0],
  [1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0],
  [1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0]
];
const SOL_VE: number[][] = [
  [1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0],
  [1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0],
  [1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0]
];

const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    3,2,2,2,2,
    2,2,3,1,2,
    3,1,2,0,1,
    2,2,3,2,2,
    1,3,1,1,1
  ],
  // 第 2 关
  [
    2,1,3,2,3,
    2,1,3,2,2,
    3,1,2,1,1,
    3,1,3,2,2,
    2,3,1,1,1
  ],
  // 第 3 关
  [
    2,3,1,0,0,
    2,3,0,0,0,
    2,2,2,1,0,
    2,2,2,2,1,
    0,1,2,3,1
  ]
];

@Component
export struct GSlitherlink {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 STEP_BUDGET=120
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(120);
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State he: number[] = [];        // 横边是否画上
  @State ve: number[] = [];        // 竖边是否画上
  @State steps: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;
  /** 本局用的是 CLUE_LIB 的第几关（reset() 里存下来，代打照 SOL_HE/SOL_VE 走） */
  private lv: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSlitherlink')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(120);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.lv = k;
    this.clues = CLUE_LIB[k].slice();
    this.he = new Array<number>(HE_CNT).fill(0);
    this.ve = new Array<number>(VE_CNT).fill(0);
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 顶点度数（只有 0 或 2 才是合法回路） */
  private deg(v: number): number {
    const r: number = Math.floor(v / VN);
    const c: number = v % VN;
    let d: number = 0;
    if (c > 0 && this.he[r * NC + c - 1] === 1) {
      d++;
    }
    if (c < NC && this.he[r * NC + c] === 1) {
      d++;
    }
    if (r > 0 && this.ve[(r - 1) * (NC + 1) + c] === 1) {
      d++;
    }
    if (r < NC && this.ve[r * (NC + 1) + c] === 1) {
      d++;
    }
    return d;
  }

  /** 从顶点 v 沿 dir（0左 1右 2上 3下）走到另一端，无边返回 -1 */
  private otherEnd(v: number, dir: number): number {
    const r: number = Math.floor(v / VN);
    const c: number = v % VN;
    if (dir === 0) {
      return (c > 0 && this.he[r * NC + c - 1] === 1) ? v - 1 : -1;
    }
    if (dir === 1) {
      return (c < NC && this.he[r * NC + c] === 1) ? v + 1 : -1;
    }
    if (dir === 2) {
      return (r > 0 && this.ve[(r - 1) * (NC + 1) + c] === 1) ? v - VN : -1;
    }
    return (r < NC && this.ve[r * (NC + 1) + c] === 1) ? v + VN : -1;
  }

  private pushNbr(v: number, seen: number[], queue: number[]): void {
    for (let d = 0; d < 4; d++) {
      const w: number = this.otherEnd(v, d);
      if (w >= 0 && seen[w] === 0) {
        seen[w] = 1;
        queue.push(w);
      }
    }
  }

  private edgeCount(): number {
    let n: number = 0;
    for (let k = 0; k < HE_CNT; k++) {
      if (this.he[k] === 1) {
        n++;
      }
    }
    for (let k = 0; k < VE_CNT; k++) {
      if (this.ve[k] === 1) {
        n++;
      }
    }
    return n;
  }

  private clueCount(i: number): number {
    const r: number = Math.floor(i / NC);
    const c: number = i % NC;
    let n: number = 0;
    if (this.he[r * NC + c] === 1) {
      n++;
    }
    if (this.he[(r + 1) * NC + c] === 1) {
      n++;
    }
    if (this.ve[r * (NC + 1) + c] === 1) {
      n++;
    }
    if (this.ve[r * (NC + 1) + c + 1] === 1) {
      n++;
    }
    return n;
  }

  private clueOk(i: number): boolean {
    return this.clueCount(i) === this.clues[i];
  }

  private solvedClues(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.clueOk(i)) {
        n++;
      }
    }
    return n;
  }

  private isWin(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (!this.clueOk(i)) {
        return false;
      }
    }
    let used: number = 0;
    let start: number = -1;
    for (let v = 0; v < V_CNT; v++) {
      const d: number = this.deg(v);
      if (d !== 0 && d !== 2) {
        return false;                // 有分叉或有断头
      }
      if (d === 2) {
        used++;
        if (start < 0) {
          start = v;
        }
      }
    }
    if (used < 4 || this.edgeCount() !== used) {
      return false;
    }
    const seen: number[] = new Array<number>(V_CNT).fill(0);
    const queue: number[] = [start];
    seen[start] = 1;
    let head: number = 0;
    let visited: number = 0;
    while (head < queue.length) {
      const v: number = queue[head];
      head++;
      visited++;
      this.pushNbr(v, seen, queue);
    }
    return visited === used;         // 恰好一个环
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：3 关答案离线解好写成 SOL_HE / SOL_VE，代打逐条把边画/擦到位
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
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
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
    const solHe: number[] = SOL_HE[this.lv];
    const solVe: number[] = SOL_VE[this.lv];
    for (let k = 0; k < HE_CNT; k++) {
      if (this.he[k] !== solHe[k]) {
        this.toggle(0, k);
        return !this.over;
      }
    }
    for (let k = 0; k < VE_CNT; k++) {
      if (this.ve[k] !== solVe[k]) {
        this.toggle(1, k);
        return !this.over;
      }
    }
    return false;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const solHe: number[] = SOL_HE[this.lv];
    const solVe: number[] = SOL_VE[this.lv];
    for (let k = 0; k < HE_CNT; k++) {
      if (this.he[k] !== solHe[k]) {
        const r: number = Math.floor(k / NC);
        const c: number = k % NC;
        const side: string = r < NC ? TG('上边') : TG('下边');
        const row: number = (r < NC ? r : NC - 1) + 1;
        return Hint.make([k],
          TG2('第 {0} 行第 {1} 列格子要画{2}', String(row), String(c + 1), side),
          TG2('Draw the {2} edge of the cell at row {0}, column {1}', String(row), String(c + 1), r < NC ? 'top' : 'bottom'), t0);
      }
    }
    for (let k = 0; k < VE_CNT; k++) {
      if (this.ve[k] !== solVe[k]) {
        const r: number = Math.floor(k / (NC + 1));
        const c: number = k % (NC + 1);
        const side: string = c < NC ? TG('左边') : TG('右边');
        const col: number = (c < NC ? c : NC - 1) + 1;
        return Hint.make([k],
          TG2('第 {0} 行第 {1} 列格子要画{2}', String(r + 1), String(col), side),
          TG2('Draw the {2} edge of the cell at row {0}, column {1}', String(r + 1), String(col), c < NC ? 'left' : 'right'), t0);
      }
    }
    return Hint.none('none');
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

  private toggle(kind: number, idx: number): void {
    if (this.over) {
      return;
    }
    if (kind === 0) {
      const he: number[] = this.he.slice();
      he[idx] = he[idx] === 1 ? 0 : 1;
      this.he = he;
    } else {
      const ve: number[] = this.ve.slice();
      ve[idx] = ve[idx] === 1 ? 0 : 1;
      this.ve = ve;
    }
    this.steps++;
    if (this.isWin()) {
      this.over = true;
      this.won = true;
      this.score = Math.max(120, 700 - this.steps * 3);
      this.finish(true);
      return;
    }
    if (this.steps >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'slitherlink',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.solvedClues()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 显示网格 (gr,gc) 对应的格子/边下标 */
  private cellIdx(gr: number, gc: number): number {
    return Math.floor((gr - 1) / 2) * NC + Math.floor((gc - 1) / 2);
  }

  private clueInk(gr: number, gc: number): string {
    return this.clueOk(this.cellIdx(gr, gc)) ? Palette.emerald : this.theme.ink;
  }

  private isVertex(gr: number, gc: number): boolean {
    return gr % 2 === 0 && gc % 2 === 0;
  }

  private isHEdge(gr: number, gc: number): boolean {
    return gr % 2 === 0 && gc % 2 === 1;
  }

  private isVEdge(gr: number, gc: number): boolean {
    return gr % 2 === 1 && gc % 2 === 0;
  }

  private heOn(gr: number, gc: number): boolean {
    return this.he[Math.floor(gr / 2) * NC + Math.floor((gc - 1) / 2)] === 1;
  }

  private veOn(gr: number, gc: number): boolean {
    return this.ve[Math.floor((gr - 1) / 2) * (NC + 1) + Math.floor(gc / 2)] === 1;
  }

  private gridTap(gr: number, gc: number): void {
    if (this.isHEdge(gr, gc)) {
      this.toggle(0, Math.floor(gr / 2) * NC + Math.floor((gc - 1) / 2));
    } else if (this.isVEdge(gr, gc)) {
      this.toggle(1, Math.floor((gr - 1) / 2) * (NC + 1) + Math.floor(gc / 2));
    }
  }

  /** 棋盘边长（vp）：按「可用宽 / 可用高」取小值
   *  ★★★ 2026-10-30：百分比（70% / 45%）在横竖屏下不可能同时最优
   *    ⇒ 按真实可用空间算。模式已在 GBejeweled / GReversi 真机验过：
   *      横屏 293vp（装得下、按钮可见）/ 竖屏 704vp（尽量大、无空白）。
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
    const FIXED: number = 300;   // ★ 第五版：实测黑白棋固定部分更大，取 300 覆盖所有款
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(120, (Bp.height - FIXED) * 0.70);
    return Math.min(w, h);
  }

  build() {
    Column({ space: Space.md }) {
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已满足线索'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.solvedClues()) + '/' + String(CELLS)))
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
        Text((TG('已画边'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.edgeCount())))
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
        Text((TG('已用步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(this.diffTotal)))
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

      Column() {
        ForEach(IDX, (gr: number) => {
          Row() {
            ForEach(IDX, (gc: number) => {
              Stack() {
              if (this.isVertex((gr), (gc))) {
              Text('')
              .width(DOT)
              .height(DOT)
              .backgroundColor(Palette.wall)
              .borderRadius(Radius.full)
              } else if (this.isHEdge((gr), (gc))) {
              Text('')
              .width('100%')
              .height(this.heOn((gr), (gc)) ? BAR : THIN).animation({ duration: Motion.fast, curve: Motion.snap() })
              .backgroundColor(this.heOn((gr), (gc)) ? Palette.primaryDeep : this.theme.line)
              .borderRadius(Radius.full)
              } else if (this.isVEdge((gr), (gc))) {
              Text('')
              .width(this.veOn((gr), (gc)) ? BAR : THIN)
              .height('100%')
              .backgroundColor(this.veOn((gr), (gc)) ? Palette.primaryDeep : this.theme.line)
              .borderRadius(Radius.full)
              } else {
              Text(String(this.clues[this.cellIdx((gr), (gc))]))
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.clueInk((gr), (gc)))
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.gridTap((gr), (gc));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.gridTap((gr), (gc)); }); })
            }, (gc: number) => 'g' + gc)
          }
          .width('100%')
        }, (gr: number) => 'gr' + gr)
      }
      // ★★★ 2026-10-30 · 用「算出来的边长」，不用百分比（见 boardPx 注释）
      .width(this.boardPx())
      .height(this.boardPx())
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '回路闭合 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点边线切换；数字变绿说明这一格满足了')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.lime)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
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




}
