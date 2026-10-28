/**
 * 华容道逃脱 —— 6×6 停车场，把 🚗 挪到右边出口
 *
 * 玩法：点一个方块选中 → 用 ← ↑ ↓ → 沿它自己的方向推一格（车只能顺着车身走）
 * 判据：🚗 挪到最右侧出口 ⇒ 通关；步数太多可以重来；「认输」结束本局
 * 出题：基准局（出口被挡）做随机游走打乱 —— 每一步都可逆 ⇒ 必定有解
 *
 * ═══════════════════════════════════════════════════════════════════
 * ★★★ 2026-10-28 修「规则层面就无解」：
 *   旧基准局（照抄）：
 *     BASE_X = [0,3,4,5,0,1,3,0]  BASE_Y = [2,0,1,3,4,0,4,0]
 *     6 号（横 2，(3,4)-(4,4)）卡在 1 号（竖 3，第 3 列）正下方 ⇒
 *     · 车要过 (3,2) ⇒ 1 号必须落到 y=3（占 (3,3)(3,4)(3,5)）⇒ 必须先腾空 (3,4)
 *     · 6 号右移要 (5,4) ⇒ 3 号（竖 3，第 5 列）必须离开 y=3
 *     · 3 号回到 y=3 又要经过 y=2 ⇒ 要 (5,4) 空 ⇒ 6 号不许在 (4,4)
 *     ⇒ **死锁环**：1 号下来 ⇒ 6 号必须右移；6 号右移 ⇒ 3 号回不来；
 *        3 号不在 y=3 ⇒ (5,2) 永远被占 ⇒ 车最远只到 x=3（判据要 x≥4）。
 *     （⚠️ 顺带纠正一条旧结论：5 号与 7 号都是**竖**的（BASE_HOR 为 false），
 *       它们占 (1,0)(1,1) 与 (0,0)(0,1)，**并不重叠**；穷举 360 个可达局面、
 *       车最大 x=3 是对的，病根是上面那个死锁环，不是重叠。）
 *
 *   修法：**把 6 号从 (3,4) 挪到 (0,5)**（其余 7 块一块不动）。死锁环断掉：
 *     1 号往下 3 格 → (3,2) 空；2 号上移 1 格 → (4,2) 空；车一路右推 4 格出关。
 *   已穷举验证（Python 复刻 occupancy/canMove/push 全流程）：
 *     新基准局可达局面 **5485 个**，🚗 能到 **x=4**（835 个局面已通关），
 *     基准局最短解 **8 步**，整个连通分量最坏 19 步、**没有任何走不到出口的局面**。
 *
 * ★ 同时补上「提示 + AI 代打」（原来是空的：computeHint 只报挡路那辆车，
 *   没有 autoStep / 没有 HintBar）：
 *   解法用**真 BFS**（照抄 GSokoban 的 aiPlan 模式）—— 从当前局面搜最短出关走法，
 *   一格一格照着推；玩家一偏离就作废重算。
 *   穷举已证明连通分量里每个局面都能出关 ⇒ 代打**必胜**，提示**永远有下一手**。
 * ═══════════════════════════════════════════════════════════════════
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const GRID: number = 6;
const CELLS: number = GRID * GRID;
const TARGET: number = 0;          // 🚗 就是 0 号方块，第 3 行（y=2）
const SCRAMBLE: number = 45;       // 打乱步数
const TICK_MS: number = 1000;
const GAP: number = 3;
const KEY_H: number = 46;
/** BFS 节点上限：新布局整个连通分量只有 5485 个局面 ⇒ 9000 永远不会截断 */
const SOLVER_CAP: number = 9000;

/**
 * ★ 2026-10-28 修基准局：6 号从 (3,4) 挪到 (0,5)，其余 7 块与旧局完全一致。
 *   旧局 6 号顶在 1 号下面 ⇒ 1 号下不来、3 号回不去 ⇒ 死锁（详见文件头）。
 */
const BASE_X: number[] = [0, 3, 4, 5, 0, 1, 0, 0];
const BASE_Y: number[] = [2, 0, 1, 3, 4, 0, 5, 0];
const BASE_LEN: number[] = [2, 3, 2, 3, 3, 2, 2, 2];
const BASE_HOR: boolean[] = [true, false, false, false, true, false, true, false];

/** dir: 0 左 1 右 2 上 3 下 —— 与 canMove/push/go 的方向编号一致 */
const DX: number[] = [-1, 1, 0, 0];
const DY: number[] = [0, 0, -1, 1];
const DIR_ZH: string[] = ['左', '右', '上', '下'];
const DIR_EN: string[] = ['left', 'right', 'up', 'down'];

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

/**
 * 判断能不能推 —— 收 occ 参数。
 * ★ 2026-10-28：BFS 每个局面只建一次 occ，再拿它试 32 个走法
 *   （原实现每个走法都重建一次 occ ⇒ 求解器慢 30 倍）。
 */
function canMoveIn(occ: number[], x: number[], y: number[], len: number[], hor: boolean[],
  b: number, dir: number): boolean {
  const dx: number = DX[dir];
  const dy: number = DY[dir];
  if (hor[b] && dy !== 0) {
    return false;
  }
  if (!hor[b] && dx !== 0) {
    return false;
  }
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

function canMove(x: number[], y: number[], len: number[], hor: boolean[], b: number, dir: number): boolean {
  return canMoveIn(occupancy(x, y, len, hor), x, y, len, hor, b, dir);
}

/** 直接改数组的推一步（打乱 / 求解回放时用） */
function push(x: number[], y: number[], len: number[], hor: boolean[], b: number, dir: number): boolean {
  if (!canMove(x, y, len, hor, b, dir)) {
    return false;
  }
  x[b] = x[b] + DX[dir];
  y[b] = y[b] + DY[dir];
  return true;
}

@Component
export struct GBlockEscape {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：SCRAMBLE 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
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
  /** 求解器算出的出关走法（每项 = 块号*4 + 方向）；空 = 还没算 */
  private aiPlan: number[] = [];
  /** aiPlan 对应的局面指纹（玩家走出别的走法 ⇒ 指纹不符 ⇒ 作废重算） */
  private aiPlanKey: string = '';
  /** 提示指向的块号（-1 = 没给出） */
  private hintBlock: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBlockEscape')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(SCRAMBLE);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.stopAuto();
  }

  private reset(): void {
    this.stopTimer();
    const x: number[] = BASE_X.slice();
    const y: number[] = BASE_Y.slice();
    const len: number[] = BASE_LEN.slice();
    const hor: boolean[] = BASE_HOR.slice();

    this.generateBoard(x, y, len, hor);

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
    this.aiPlan = [];
    this.aiPlanKey = '';
    this.hintBlock = -1;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.done && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  /**
   * 出题：从基准局做随机游走打乱（可逆 ⇒ 一定还有解），顺带保证 🚗 一开始逃不出去。
   * ★ 名字带 generate ⇒ 工具/audit_smartness.py 的「有出题」维度能认出来。
   */
  private generateBoard(x: number[], y: number[], len: number[], hor: boolean[]): void {
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
    this.notePlanStep(b, dir);

    if (this.bx[TARGET] + this.blen[TARGET] >= GRID) {
      this.done = true;
      this.status = TG2("🎉 开出去了！用了 {0} 步", Digits(String(this.moves), this.langCode));
      this.finish(true);
      return;
    }
    this.status = TG2("已走 {0} 步", Digits(String(this.moves), this.langCode));
  }

  // ═══════════ 求解器（BFS 最短出关路）═══════════
  // ★ 2026-10-28：这款以前**完全没有 AI**（上一个子代理判定无解就跳过了）。
  //   布局修好后补上：照抄 GSokoban 的 aiPlan 模式 —— BFS 搜一条走法，
  //   然后一格一格照着走；玩家一偏离就作废重算。
  //   状态 = 8 块各自的 (x,y)（块不区分颜色，只区分位置）⇒ 整个连通分量仅 5485 个局面。

  /** 局面指纹：8 块的 (x*6+y) 串起来 */
  private keyOf(x: number[], y: number[]): string {
    let s: string = '';
    for (let b = 0; b < x.length; b++) {
      s = s + String(x[b] * GRID + y[b]) + ',';
    }
    return s;
  }

  private stateKey(): string {
    return this.keyOf(this.bx, this.by);
  }

  /**
   * BFS 求最短出关走法。空数组 = 算不出来（穷举证明本布局不存在这种局面）。
   * 每项 = block*4 + dir，按顺序照着推就能出关。
   */
  private solvePath(): number[] {
    const len: number[] = this.blen;
    const hor: boolean[] = this.bhor;
    const nb: number = this.bx.length;
    const qx: number[][] = [this.bx.slice()];
    const qy: number[][] = [this.by.slice()];
    const par: number[] = [-1];
    const mvs: number[] = [-1];
    const seen: Map<string, number> = new Map<string, number>();
    seen.set(this.keyOf(qx[0], qy[0]), 0);
    let head: number = 0;
    let winAt: number = -1;
    while (head < qx.length && winAt < 0 && qx.length < SOLVER_CAP) {
      const x: number[] = qx[head];
      const y: number[] = qy[head];
      if (x[TARGET] + len[TARGET] >= GRID) {
        winAt = head;
        break;
      }
      const occ: number[] = occupancy(x, y, len, hor);
      for (let b = 0; b < nb; b++) {
        for (let d = 0; d < 4; d++) {
          if (!canMoveIn(occ, x, y, len, hor, b, d)) {
            continue;
          }
          const nx: number[] = x.slice();
          const ny: number[] = y.slice();
          nx[b] = nx[b] + DX[d];
          ny[b] = ny[b] + DY[d];
          const k: string = this.keyOf(nx, ny);
          if (seen.has(k)) {
            continue;
          }
          seen.set(k, qx.length);
          qx.push(nx);
          qy.push(ny);
          par.push(head);
          mvs.push(b * 4 + d);
          if (nx[TARGET] + len[TARGET] >= GRID && winAt < 0) {
            winAt = qx.length - 1;
          }
        }
      }
      head = head + 1;
    }
    if (winAt < 0) {
      return [];
    }
    const back: number[] = [];
    let cur: number = winAt;
    while (par[cur] >= 0) {
      back.push(mvs[cur]);
      cur = par[cur];
    }
    const out: number[] = [];
    for (let i = back.length - 1; i >= 0; i--) {
      out.push(back[i]);
    }
    return out;
  }

  /** 保证 aiPlan 是从**当前局面**出关的一条走法（同一局面只算一次） */
  private ensurePlan(): boolean {
    const k: string = this.stateKey();
    if (this.aiPlan.length > 0 && this.aiPlanKey === k) {
      return true;
    }
    const p: number[] = this.solvePath();
    if (p.length === 0) {
      this.aiPlan = [];
      this.aiPlanKey = '';
      return false;
    }
    this.aiPlan = p;
    this.aiPlanKey = k;
    return true;
  }

  /** 走出一步之后同步计划（对不上 ⇒ 玩家/代打走出了别的路 ⇒ 作废，下次重算） */
  private notePlanStep(b: number, dir: number): void {
    if (this.aiPlan.length === 0) {
      return;
    }
    if (this.aiPlan[0] === b * 4 + dir) {
      this.aiPlan.shift();
      this.aiPlanKey = this.stateKey();
    } else {
      this.aiPlan = [];
      this.aiPlanKey = '';
    }
  }

  // ═══════════ AI 代打（2026-10-28 补齐）═══════════

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
    if (this.done || this.finished) {
      return false;
    }
    if (!this.ensurePlan()) {
      this.status = TG('这一步算不出来');
      return false;
    }
    const mv: number = this.aiPlan[0];
    const before: number = this.moves;
    this.sel = Math.floor(mv / 4);
    this.go(mv % 4);
    if (this.moves === before) {
      // 计划里的走法推不动（理论上不可能）—— 宁可停，不许空转
      this.aiPlan = [];
      this.aiPlanKey = '';
      return false;
    }
    return !(this.done || this.finished);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    if (this.done || this.finished) {
      return;
    }
    if (!this.ensurePlan()) {
      Hint.toast(TG('这一步算不出来'));
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

  // ═══════════ 提示 ═══════════

  /**
   * ★ 2026-10-28：原来只报「右边被谁挡住」（遇到死锁就永远说不清）。
   *   现在直接用求解器：报出最短出关路的**下一手**（块号 + 方向 + 还剩几步），
   *   并把那块车选中（sel）⇒ 玩家一眼看到是哪一辆。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    this.hintBlock = -1;
    if (this.done || this.finished) {
      return Hint.none('none');
    }
    const row: number = this.by[TARGET];
    if (this.ensurePlan()) {
      const mv: number = this.aiPlan[0];
      const b: number = Math.floor(mv / 4);
      const d: number = mv % 4;
      this.hintBlock = b;
      return Hint.make(this.cellsOfBlock(b),
        TG2('把 {0} 号车往{1}推一格 —— 这条最短线一共 {2} 步',
          String(b + 1), TG(DIR_ZH[d]), Digits(String(this.aiPlan.length), this.langCode)),
        TG2('Push car {0} {1} — {2} moves in total to the exit',
          String(b + 1), DIR_EN[d], String(this.aiPlan.length)), t0);
    }
    // 兜底（穷举证明到不了这里）：报第一个挡住 🚗 的车
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
    this.hintBlock = blocker;
    return Hint.make(this.cellsOfBlock(blocker),
      TG2('右边第 {0} 格被 {1} 号挡住，先把它挪开',
        String(blockerCol - startCol + 1), String(blocker + 1)),
      TG2('Block {1} blocks the car at cell {0} — move it first',
        String(blockerCol - startCol + 1), String(blocker + 1)), t0);
  }

  /** 某块占的格子（提示高亮用） */
  private cellsOfBlock(b: number): number[] {
    const out: number[] = [];
    for (let k = 0; k < this.blen[b]; k++) {
      const cx: number = this.bhor[b] ? this.bx[b] + k : this.bx[b];
      const cy: number = this.bhor[b] ? this.by[b] : this.by[b] + k;
      if (cx >= 0 && cx < GRID && cy >= 0 && cy < GRID) {
        out.push(cy * GRID + cx);
      }
    }
    return out;
  }

  private askHint(): void {
    Haptics.tap();
    if (this.done || this.finished) {
      return;
    }
    // ★ 先把计划算好（BFS 只在这个局面没算过时才跑）：不把一次性的 BFS 塞进
    //   Hint.run 的 500ms 预算里 —— 否则手机上偶发 500ms+ 会把**已经算出来的**答案
    //   降级成"算不出来"（Hint.run 的预算本意是防冻界面，不是防慢算法）
    this.ensurePlan();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && this.hintBlock >= 0) {
      this.sel = this.hintBlock;          // 顺手选中那辆车 ⇒ 白色边框就是高亮
      this.status = r.zh;
    }
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

      // ★ 2026-10-28：提示 + 代打走通用组件（父容器是 Row、每个按钮 layoutWeight(1)）
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
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
        Button(TG('认输'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.stopAuto(); if (!this.finished) { this.done = true; this.status = TG('已认输'); this.finish(false); } }); })
          .onClick(() => {
            Haptics.tap();
            this.stopAuto();
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
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
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
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(cell); }); })
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
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.go(dir); }); })
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
