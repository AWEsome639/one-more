/**
 * 华容道 —— 「横刀立马」4×5 🧊
 *
 * 布局：曹操 2×2 在上中，四员大将竖着分列两侧，关羽横在中间，四卒守底，底部中央两格空。
 * 玩法：点一个方块选中它，再点方向键把它推进相邻空格（一次一格）。
 * 胜负：曹操左上角走到 (1,3)（即底部出口那一块）⇒ 通关；步数超过上限 ⇒ 失败。
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

const COLS: number = 4;
const ROWS: number = 5;
/** 「横刀立马」一格一格走的最短解是 116 步（BFS 实测）⇒ 上限必须留够余量，否则永远赢不了 */
const MAX_MOVES: number = 160;
const CAO: number = 1;          // 曹操在方块数组里的下标（layout() 里第二个 push）
const CAO_TX: number = 1;       // 出口：曹操左上角目标列
const CAO_TY: number = 3;       // 出口：曹操左上角目标行
const GAP: number = Space.xs / 2;
/** 拖动判定阈值（vp）：一次拖动至少这么多才认一个方向 */
const DRAG_MIN: number = 18;

// ═══════════ AI 代打 / 提示用的「最优解常量」（2026-10-28 第六批）═══════════
// ★ 为什么写死而不在运行时求解：华容道只有「横刀立马」这一种开局（layout() 是固定局），
//   最优解唯一；而现算一次 BFS 要遍历 ~46 万个局面（实测 Python 37 秒），
//   搬到手机上就是好几秒的卡死 —— 违反"宁可说想不出来，也不许冻界面"。
//   ⇒ 路线离线算好存成常量：0 毫秒、必然最优；换局面的代价见 aiAt() 的注释。
/** 最短解 116 步（单格推法）。每步编码 = (y * 4 + x) * 4 + 方向：
 *  x,y 是「被推的那个方块推之前的左上角」，方向 0 上 1 右 2 下 3 左（与 tryMove 的 dx,dy 对齐） */
const KLO_STEPS: number = 116;
const KLO_MOVES: number[] = [
  65, 34, 39, 56, 79, 46, 41, 33, 48, 71, 75, 63,
  46, 37, 52, 62, 68, 65, 34, 39, 43, 14, 30, 5,
  1, 32, 48, 16, 32, 71, 55, 59, 79, 46, 37, 52,
  72, 65, 69, 38, 6, 1, 16, 48, 55, 22, 38, 33,
  36, 43, 60, 39, 73, 58, 47, 76, 73, 42, 33, 2,
  37, 52, 7, 20, 36, 59, 79, 62, 42, 10, 5, 1,
  16, 48, 9, 5, 20, 52, 75, 71, 79, 75, 58, 26,
  10, 25, 5, 36, 20, 43, 30, 46, 14, 30, 9, 5,
  1, 32, 16, 39, 63, 56, 72, 69, 65, 73, 69, 34,
  43, 39, 47, 43, 56, 72, 57, 49
];
/** 每一步之后的局面指纹（20 字符：前 6 块各两位 xy + 四卒排序后各两位 xy），
 *  用来把"当前局面"定位到路线上的第几步 —— 玩家中途自己推过也能对上 */
const KLO_TRACE: string =
  '001030021232041323340010300212321314233400103003123213142334001030030232131423340010300302321314223400103003023213142224' +
  '001030030233131422240010300302331314243200103003123313142432001030021233131424320010300212330413243200103002123304131432' +
  '001030021223041314320010300212230413143300103002222304131433001030022223041214330010300222230412143400103002222304121334' +
  '001030022223121314340010300322231213143400103003222302131434001030031223021314340010310312230213143400103203122302131434' +
  '002032031223021314341020320312230213143410203203122301131434102032021223011314341020320212230013143410203201122300131434' +
  '102032011223000413341020320112230003043410203201121300030434102032011213000304241020330112130003042410203301221300030424' +
  '102033012212000304241020330122120003042310203301221200031423102033012212000323241020330122130003232411203301221300032324' +
  '112033012213031023241120330022130310232411203300221302102324112033002203021023241220330022030210232413203300220302102324' +
  '132033002203101223241320330022031011232413203300120310112324132032001203101123241320320002031011232413203200020310112334' +
  '132032000203101124341320220002031011243413202200020310112433132022000203101133341320230002031011333413202300120310113334' +
  '132023011203101133341320230122031011333412202301220310113334122023012203001133341220230122030010333411202301220300103334' +
  '112013012203001033341120130122030010243311201301220300102434112013012303001024341121130123030010243411211301230300202434' +
  '112113012303102024341121130023031020243411211300230210202434112113002302102430341121130023022024303410211300230220243034' +
  '102112002302202430341021120023021420303410211200230204203034102112002302042024301021120023020414203010211200240204142030' +
  '102212002402041420301022120024020414213010221200240204143031202212002402041430312022110024020414303120221000240204143031' +
  '201210002402041430312012100024020414303220121000240204143033201210002402041431332012100024020414323330121000240204143233' +
  '301220002402041432333012201024020414323330122010240104143233301220102400041432333002201024000414323330022010240004142332' +
  '300220102400041422323002201023000414223230022010230004222432300220102300142224323002201023001422323430022010230022243234' +
  '300320102300222432343003201023001224323430032010230002243234300320102300022224343003201023000212243430032010220002122434' +
  '300320102200021223343003201022000212333430132010220002123334';
/** 方向表：与 tryMove(dx, dy) 一致 */
const AI_DXS: number[] = [0, 1, 0, -1];
/** 方向名（d=0 上 / 1 右 / 2 下 / 3 左，与 AI_DXS/AI_DYS 同序） */
const DIR_NAME: string[] = ['上', '右', '下', '左'];
const AI_DYS: number[] = [-1, 0, 1, 0];

interface Blk {
  x: number;      // 列
  y: number;      // 行
  w: number;      // 占几列
  h: number;      // 占几行
  label: string;
  color: string;
}

@Component
export struct GKlotski {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private blocks: Blk[] = [];
  @State private sel: number = CAO;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  /** 代打计时器（-1 = 未运行）。必须 @State，否则按钮文字不刷新 */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-10-31 演示动画三拍（与宝石迷阵同一套节拍器 core/Demo.ets）
  //   华容道是「移动」类：第 1 拍先把要推的那块**圈出来并说往哪推**，
  //   第 2 拍才真的推，第 3 拍亮一下剩余步数。
  @State private demoGuideBlk: number = -1;   // 第 1 拍高亮哪块
  // ★ 演示专用文案（不复用 tip —— tip 会被 tryMove/check 反复覆盖）
  @State private demoMsg: string = '';
  private demoBlk: number = -1;   // 本拍要推的方块下标
  private demoDir: number = 0;     // 本拍方向（0上 1右 2下 3左）
  @State private demoRound: number = 0;       // 演到第几轮
  @State private demoPhase: number = 0;       // 0=引导 1=执行 2=结果
  private demoSnapSel: number = -1;
  private demoSnapBlk: string = '';
  @State private tip: string = TG('点方块选中，再点方向键移动');

  private startAt: number = 0;
  private finished: boolean = false;
  /** ★ 拖动起点（vp）：一次拖动可以连着推好几格，每认一格就把起点重置 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKlotski')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  /** 「横刀立马」开局 */
  private layout(): Blk[] {
    const bs: Blk[] = [];
    const zhang: Blk = { x: 0, y: 0, w: 1, h: 2, label: '张飞', color: Palette.sky };
    const cao: Blk = { x: 1, y: 0, w: 2, h: 2, label: '曹操', color: Palette.rose };
    const zhao: Blk = { x: 3, y: 0, w: 1, h: 2, label: '赵云', color: Palette.teal };
    const ma: Blk = { x: 0, y: 2, w: 1, h: 2, label: '马超', color: Palette.violet };
    const guan: Blk = { x: 1, y: 2, w: 2, h: 1, label: '关羽', color: Palette.amber };
    const huang: Blk = { x: 3, y: 2, w: 1, h: 2, label: '黄忠', color: Palette.orange };
    const z1: Blk = { x: 1, y: 3, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z2: Blk = { x: 2, y: 3, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z3: Blk = { x: 0, y: 4, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z4: Blk = { x: 3, y: 4, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    // push 顺序即下标：0 张飞 · 1 曹操（= CAO）· 2 赵云 · 3 马超 · 4 关羽 · 5 黄忠 · 6~9 四卒
    bs.push(zhang);
    bs.push(cao);
    bs.push(zhao);
    bs.push(ma);
    bs.push(guan);
    bs.push(huang);
    bs.push(z1);
    bs.push(z2);
    bs.push(z3);
    bs.push(z4);
    return bs;
  }

  private reset(): void {
    this.blocks = this.layout();
    this.sel = CAO;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点方块选中，再点方向键移动');
    this.startAt = Date.now();
  }

  private hit(a: Blk, b: Blk): boolean {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
  }

  // ═══════════ AI 代打 / 提示（2026-10-28 第六批）═══════════
  /** 当前局面的指纹：前 6 块按固定顺序，四卒排序后拼（卒长得一样，换身份仍是同一局面） */
  private aiKey(): string {
    let s: string = '';
    for (let i = 0; i < 6; i++) {
      s = s + String(this.blocks[i].x) + String(this.blocks[i].y);
    }
    const zs: string[] = [];
    for (let i = 6; i < 10; i++) {
      zs.push(String(this.blocks[i].x) + String(this.blocks[i].y));
    }
    zs.sort();
    for (let i = 0; i < zs.length; i++) {
      s = s + zs[i];
    }
    return s;
  }

  /**
   * 当前局面在最优路线上的第几步。
   * -1 = 不在路线上（玩家自己走过别的走法）⇒ 这时给不出提示，老实说"想不出来"，
   * 绝不给一个错的走法（推错一步整盘就废了）。
   */
  private aiAt(): number {
    if (this.blocks.length < 10) {
      return -1;
    }
    const k: string = this.aiKey();
    for (let i = 0; i < KLO_STEPS; i++) {
      if (KLO_TRACE.substring(i * 20, i * 20 + 20) === k) {
        return i;
      }
    }
    return -1;
  }

  /** 执行路线上的第 i 步：按「推之前的位置」找方块，不存下标 —— 四卒换了身份也推不错 */
  /** 演示专用：找**任意一步合法走法**（不依赖预置解法）
   *  ★ 2026-10-31 真机定位：原演示用 `aiAt()`，而它只在「局面恰好在预置解法的
   *    某一步上」时才返回下标，否则 -1 ⇒ 演示第 1 拍就 `demoFinish()`，
   *    **0 帧结束**（探针实测 demoId 当时已是 -1）。
   *  ⇒ 演示不该问"解法走到哪了"，该问"现在能怎么走"。
   *  @returns [方块下标, 方向] 或 null
   */
  private demoFindMove(): number[] | null {
    for (let j = 0; j < this.blocks.length; j++) {
      const b: Blk = this.blocks[j];
      for (let d = 0; d < 4; d++) {
        const nx: number = b.x + AI_DXS[d];
        const ny: number = b.y + AI_DYS[d];
        if (nx < 0 || ny < 0 || nx + b.w > COLS || ny + b.h > ROWS) { continue; }
        const probe: Blk = { x: nx, y: ny, w: b.w, h: b.h, label: b.label, color: b.color };
        let blocked: boolean = false;
        for (let k = 0; k < this.blocks.length; k++) {
          if (k === j) { continue; }
          if (this.hit(probe, this.blocks[k])) { blocked = true; break; }
        }
        if (!blocked) { return [j, d]; }
      }
    }
    return null;
  }

  private aiApply(i: number): void {
    const e: number = KLO_MOVES[i];
    const d: number = e % 4;
    const p: number = Math.floor(e / 4);
    const px: number = p % COLS;
    const py: number = Math.floor(p / COLS);
    for (let j = 0; j < this.blocks.length; j++) {
      if (this.blocks[j].x === px && this.blocks[j].y === py) {
        this.sel = j;
        this.tryMove(AI_DXS[d], AI_DYS[d]);
        return;
      }
    }
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  /** 华容道的三拍演示：**引导（圈出方块 + 说往哪推）→ 执行 → 结果**
   *  为什么不用旧版：旧版一个 tick 内 `aiApply()` 直接推完，
   *  玩家只看到"方块瞬移"，不知道该看哪、也不知道刚才是往哪推的。
   */
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    // ── 第 1 拍：引导（找**任意**一步合法走法，不依赖预置解法）──
    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      const mv: number[] | null = this.demoFindMove();
      if (mv === null) { this.demoFinish(); return -1; }
      this.demoBlk = mv[0];
      this.demoDir = mv[1];
      this.demoGuideBlk = mv[0];
      this.demoMsg = TG2('看这块「{0}」：往{1}推一格', this.blocks[mv[0]].label, DIR_NAME[mv[1]]);
      this.tip = this.demoMsg;
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    // ── 第 2 拍：执行 ──
    if (this.demoPhase === 1) {
      if (this.demoBlk >= 0 && this.demoBlk < this.blocks.length) {
        this.sel = this.demoBlk;
        this.tryMove(AI_DXS[this.demoDir], AI_DYS[this.demoDir]);
      }
      this.demoGuideBlk = -1;
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    // ── 第 3 拍：结果 ──
    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样挪。碰一下屏幕，换你来')
      : TG2('推过去了。已走 {0} 步，最多 {1} 步', String(this.moves), String(this.diffTotal));
    this.tip = this.demoMsg;
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoGuideBlk = -1;
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    // ★ 2026-10-31：演示**自然结束**时也必须归 -1，
    //   否则 HintBar 永远停在「演示中…」，玩家以为还在演（真机抓到了）。
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
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
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来会告诉你要推哪一块');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const i: number = this.aiAt();
    if (i < 0 || i >= KLO_STEPS) {
      return false;               // 已经不在解法上了：停手，不要乱推
    }
    this.aiApply(i);
    return !this.over;
  }

  /** 提示：报「推哪块 + 往哪边 + 还要几步」（报方块名字与方向，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.aiAt();
    if (i < 0) {
      return Hint.none('offroute');
    }
    if (i >= KLO_STEPS) {
      return Hint.none('none');
    }
    const e: number = KLO_MOVES[i];
    const d: number = e % 4;
    const p: number = Math.floor(e / 4);
    const px: number = p % COLS;
    const py: number = Math.floor(p / COLS);
    let lab: string = '';
    for (let j = 0; j < this.blocks.length; j++) {
      if (this.blocks[j].x === px && this.blocks[j].y === py) {
        lab = this.blocks[j].label;
      }
    }
    const names: string[] = [TG('上'), TG('右'), TG('下'), TG('左')];
    const ens: string[] = ['up', 'right', 'down', 'left'];
    const left: number = KLO_STEPS - i;
    return Hint.make([], TG2('把「{0}」往{1}推一格 · 还要 {2} 步', lab, names[d], left),
      TG2('Push {0} {1} · {2} moves left', lab, ens[d], left), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, this.aiAt() < 0 ? TG('这局面已经不在最优解上了 —— 点「重开」我从开局带你走') : TG('这一步看不出答案'));
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    if (this.aiAt() < 0) {
      Hint.toast(TG('这局面已经不在最优解上了 —— 点「重开」我一路替你走完'));
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

  private tryMove(dx: number, dy: number): void {
    if (this.over) {
      return;
    }
    const i: number = this.sel;
    const b: Blk = this.blocks[i];
    const nx: number = b.x + dx;
    const ny: number = b.y + dy;
    if (nx < 0 || ny < 0 || nx + b.w > COLS || ny + b.h > ROWS) {
      return;   // 撞墙
    }
    const probe: Blk = { x: nx, y: ny, w: b.w, h: b.h, label: b.label, color: b.color };
    for (let k = 0; k < this.blocks.length; k++) {
      if (k === i) {
        continue;
      }
      if (this.hit(probe, this.blocks[k])) {
        return;   // 被别的方块挡住
      }
    }
    const nb: Blk[] = [];
    for (let k = 0; k < this.blocks.length; k++) {
      const o: Blk = this.blocks[k];
      if (k === i) {
        const moved: Blk = { x: nx, y: ny, w: o.w, h: o.h, label: o.label, color: o.color };
        nb.push(moved);
      } else {
        nb.push(o);
      }
    }
    this.blocks = nb;
    this.moves++;
    this.check();
  }

  private away(): number {
    const b: Blk = this.blocks.length > CAO ? this.blocks[CAO] : this.blocks[0];
    return Math.abs(b.x - CAO_TX) + Math.abs(b.y - CAO_TY);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'klotski',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : Math.max(0, 300 - this.away() * 40),
      durationMs: Date.now() - this.startAt,
      levelReached: Math.max(0, ROWS - 1 - this.blocks[CAO].y)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const b: Blk = this.blocks[CAO];
    if (b.x === CAO_TX && b.y === CAO_TY) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 曹操出关，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，曹操没能出关');
      this.finish(false);
      return;
    }
    // ★ 2026-10-31：演示期间**不许写这句** —— 它会把第 1 拍的
    //   「看这块「卒」：往右推一格」顶掉（真机 dump 抓到过）。
    //   演示要能独占文案通道。
    if (this.demoId < 0) {
      this.tip = TG2("曹操距出口还差 {0} 格", String(this.away()));
    }
  }

  build() {
    Column({ space: Space.md }) {
      // ★★★ 2026-10-31 真机定位（第 3 次 @Prop 出问题）：
      //   HintBar 的 `@Prop demoOn` **只进不出** —— 演示结束后它仍停在 true，
      //   导致界面永远显示「演示中…」、且演示文案永远传不进去。
      //   ⇒ 演示态**不再交给 HintBar**，由游戏页自己渲染（本页 @State 直接生效）。
      // ★ 演示条（共用组件）：`on` 由本页 @State 直传，不走 HintBar 的 @Prop
      //   （那个 @Prop 在演示结束后不复位，本项目已踩三次）
       // ★ 演示条与 HintBar 恒显示：DemoBar 在未演示时高度为 0，不占位
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
        this.head(0)
        this.head(1)
        this.head(2)
      }
      .width('100%')

      Stack() {
        // 出口高亮：底部中央 2×2
        Row()
          .width((2 * 100 / COLS) + '%')
          .height((2 * 100 / ROWS) + '%')
          .position({ x: (CAO_TX * 100 / COLS) + '%', y: (CAO_TY * 100 / ROWS) + '%' })
          .border({ width: 2, color: Palette.emerald, style: BorderStyle.Dashed })
          .borderRadius(Radius.md)
          .opacity(0.6)

        ForEach(this.blocks, (b: Blk, i: number) => {
          this.block(i)
        }, (b: Blk, i: number) => 'kb' + i)
      }
      .width('100%')
      .aspectRatio(COLS / ROWS)
      // ★ 2026-10-31 真机：宽驱动 + 无高度上限 ⇒ 横屏 853×533 上棋盘撑到 813vp 高，
      //   把「重开」等按钮挤出屏幕。限高让它按 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      // ★ 2026-10-31：演示文案改由 HintBar 那一行承载（demoMsg），
      //   不再另开一行 Text —— 单独那行在横屏布局里**不渲染**（真机 dump 抓不到）。
      if (this.demoId < 0 && Bp.width <= Bp.height) {
      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      }

      // ★ 2026-10-31 真机（横屏 853×533）：原来是「↑ 一行 + ←↓→ 一行」两行，
      //   加上方的四行 UI ⇒ 下面的「←↓→」和「重开」被挤出屏幕，用户点不到。
      //   ⇒ 横屏时把四个方向键并成**一行**，省下一行高度（竖屏空间够，保持原布局）。
      if (Bp.width > Bp.height) {
        Row({ space: Space.xs }) {
          this.moveBtn('←', -1, 0)
          this.moveBtn('↑', 0, -1)
          this.moveBtn('↓', 0, 1)
          this.moveBtn('→', 1, 0)
          Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开'))
            .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.sm)
            .fontColor(Color.White)
            .backgroundColor(Palette.amber)
            .borderRadius(Radius.md)
            .height(Cell.of(44))
            .layoutWeight(1)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            // ★ 2026-10-31：横屏这个「重开」漏了 onKeyEvent ⇒ 遥控器 OK 键点不动（审计抓到）
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
            .onClick(() => { Haptics.tap(); this.reset(); })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: Space.xs }) {
          this.moveBtn('↑', 0, -1)
          Row({ space: Space.xs }) {
            this.moveBtn('←', -1, 0)
            this.moveBtn('↓', 0, 1)
            this.moveBtn('→', 1, 0)
          }
        }
        .width('100%')
      }

      if (Bp.width <= Bp.height) {
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
      }
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /**
   * 顶部小格：kind 0=步数 1=距出口 2=已选
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三个数整局不刷新。
   */
  @Builder
  head(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : (kind === 1 ? '距出口' : TG('已选')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves) + '/' + String(this.diffTotal)
        : (kind === 1 ? String(this.away()) + TG(' 格')
          : (this.blocks.length > 0 ? this.blocks[this.sel].label : '-')))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  block(i: number) {
    Row() {
      Column() {
        Text(this.blocks[i].label)
          .fontSize(this.blocks[i].w > 1 ? FontSize.lg : FontSize.md)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.blocks[i].color)
      .borderRadius(Radius.sm)
      // ★ 演示引导：被圈中的那块加**金色描边 + 浮起阴影**，一眼知道"看这里"
      .border({
        width: (this.demoGuideBlk === i || this.sel === i) ? 3 : 0,
        color: this.demoGuideBlk === i ? Palette.amber : '#FFFFFF'
      })
      .shadow(this.sel === i ? Shadow.lifted : Shadow.card)
    }
    .width((this.blocks[i].w * 100 / COLS) + '%')
    .height((this.blocks[i].h * 100 / ROWS) + '%')
    .padding(GAP)
    .position({
      x: (this.blocks[i].x * 100 / COLS) + '%',
      y: (this.blocks[i].y * 100 / ROWS) + '%'
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onClick(() => {
      Haptics.tick();
      this.sel = i;
      if (this.demoId < 0) { this.tip = TG2("{0} 已选中，点方向键移动", this.blocks[i].label); }
    })
    // ★ P9：手指直接在方块上朝想去的方向一拖 = 推它一格（不用先选中、再点下面的方向键）
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 6 })
        .onActionStart(() => {
          this.sel = i;
          this.dragX = 0;
          this.dragY = 0;
        })
        .onActionUpdate((e: GestureEvent) => {
          const dx: number = e.offsetX - this.dragX;
          const dy: number = e.offsetY - this.dragY;
          if (Math.abs(dx) < DRAG_MIN && Math.abs(dy) < DRAG_MIN) {
            return;
          }
          this.dragX = e.offsetX;
          this.dragY = e.offsetY;
          if (Math.abs(dx) >= Math.abs(dy)) {
            this.tryMove(dx > 0 ? 1 : -1, 0);
          } else {
            this.tryMove(0, dy > 0 ? 1 : -1);
          }
        })
        .onActionEnd(() => {
          this.dragX = 0;
          this.dragY = 0;
        })
    )
  }

  @Builder
  moveBtn(label: string, dx: number, dy: number) {
    Text(label)
      .fontSize(FontSize.lg)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .width(64)
      .height(Cell.of(40))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tryMove(dx, dy); }); })
      .onClick(() => {
        Haptics.tick();
        this.tryMove(dx, dy);
      })
  }
}
