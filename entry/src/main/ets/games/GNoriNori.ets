/**
 * 两格方块 norinori（5×5）—— 每块区域里恰好放 2 个黑格，且黑格两两拼成多米诺
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：4 块区域各 2 个黑格、黑格全部成对 ⇒ solved:true；非法落子 5 次 ⇒ solved:false
 * 进度：已满足区域 ／ 落子数 ／ 错手数
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，
//   而数组原来按 CELLS = 25 开 ⇒【困难档必越界】✗）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const REG_CNT: number = 4;
const ERR_MAX: number = 5;

/** 3 关区域划分（每格数字 = 区域号 1..4），每关都存在"每区两个黑格"的解 */
const REGION_LIB: number[][] = [
  // 第 1 关
  [
    1,1,1,4,4,
    1,4,4,4,4,
    1,3,3,3,3,
    3,3,3,3,2,
    3,3,3,2,2
  ],
  // 第 2 关
  [
    4,4,3,3,3,
    4,4,3,1,3,
    2,2,1,1,1,
    2,2,2,1,1,
    2,2,2,1,1
  ],
  // 第 3 关
  [
    2,2,2,3,3,
    1,2,2,3,3,
    1,1,1,1,3,
    4,1,1,1,1,
    4,4,4,4,1
  ]
];

/** 区域底色（半透明叠加，深浅主题各一套） */
function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GNoriNori {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」：
   *   原来 diffTotal = sizeNow(5)（4/5/7），棋盘按它开，
   *   但**分区来自 REGION_LIB，是手工画的 5×5 = 25 格**：
   *     · 困难 7×7 = 49 格：regions 只有 25 项，后 24 格全是 undefined
   *     · 简单 4×4 = 16 格：只取前 16 项 ⇒ 区域形状不连续，题是错的
   *   ⇒ 简单档与困难档都坏。
   *
   *   修法：**分区表是 5×5 手绘的，棋盘就固定 5×5**；
   *   难度改到**容错次数**上（本来就是它的压力来源）。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = 5;
  /** 本局允许的错误次数：简单 8 / 普通 5 / 困难 3 */
  @State private errMax: number = GNoriNori.errNow();

  private static errNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 8;
    }
    if (d === 2) {
      return 3;
    }
    return 5;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State regions: number[] = [];
  @State blacks: number[] = [];   // 1 = 涂黑
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
    if (Hint.demoOnce('GNoriNori')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.errMax = GNoriNori.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * REGION_LIB.length);
    this.regions = REGION_LIB[k].slice();
    this.blacks = new Array<number>(MAX_CELLS).fill(0);
    this.errors = 0;
    this.placed = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private blackNbrs(arr: number[], i: number): number {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    let n: number = 0;
    if (r > 0 && arr[i - this.diffTotal] === 1) {
      n++;
    }
    if (r < this.diffTotal - 1 && arr[i + this.diffTotal] === 1) {
      n++;
    }
    if (c > 0 && arr[i - 1] === 1) {
      n++;
    }
    if (c < this.diffTotal - 1 && arr[i + 1] === 1) {
      n++;
    }
    return n;
  }

  /** 落子合法性：本区不超 2 个黑格；任何黑格的邻居都不超过 1 个（防三连与 2×2） */
  private legal(arr: number[], i: number): boolean {
    const rid: number = this.regions[i];
    let cnt: number = 0;
    for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
      if (arr[k] !== 1) {
        continue;
      }
      if (this.regions[k] === rid) {
        cnt++;
      }
      if (this.blackNbrs(arr, k) > 1) {
        return false;
      }
    }
    return cnt <= 2;
  }

  /** 已完成区域数：该区恰好 2 个黑格 */
  private regionDone(rid: number): boolean {
    let n: number = 0;
    for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
      if (this.blacks[k] === 1 && this.regions[k] === rid) {
        n++;
      }
    }
    return n === 2;
  }

  private doneRegions(): number {
    let n: number = 0;
    for (let rid = 1; rid <= REG_CNT; rid++) {
      if (this.regionDone(rid)) {
        n++;
      }
    }
    return n;
  }

  /**
   * ★ 2026-10-23 第二期：两格方块提示
   *
   * 规则：每个区域恰好 2 个黑格，且两个黑格必须**相邻**（成对），
   *       任何黑格的邻居不超过 1 个（防三连与 2×2）。
   *
   * 这里用一条严格成立的推理：
   *   某区**已经有 1 个黑格** ⇒ 第二个必须与它相邻
   *   ⇒ 若该区里"与这个黑格相邻的未涂格"只剩一个 ⇒ 那一格必须涂黑
   *
   * ⚠️ 只推「必须黑」，不推「必须白」（这款只有 0/1 两态，没有白标记）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    const total: number = n * n;
    for (let rid = 1; rid <= REG_CNT; rid++) {
      // 该区已有的黑格
      let blackCell: number = -1;
      let blackN: number = 0;
      for (let k = 0; k < total; k++) {
        if (this.blacks[k] === 1 && this.regions[k] === rid) {
          blackN++;
          blackCell = k;
        }
      }
      if (blackN === 0) {
        // ★ 2026-10-24 补：某区**一个黑格都还没有**，且只剩 2 个空格
        //   ⇒ 那 2 格必须都涂黑（每区恰好 2 个）。
        //   这一条能让提示在开局就有用，不必等到"已有 1 黑"那种局面。
        let freeN: number = 0;
        let f1: number = -1;
        let f2: number = -1;
        for (let k = 0; k < total; k++) {
          if (this.regions[k] === rid) {
            if (this.blacks[k] === 1) {
              freeN = 99;              // 已经有黑格，交给下面那条规则
              break;
            }
            if (f1 < 0) {
              f1 = k;
            } else if (f2 < 0) {
              f2 = k;
            }
            freeN++;
          }
        }
        // ★ 2026-10-24 再补：这一格自己不能已经贴着 2 个黑格
        //   （否则涂上后它的邻居数会 >1，违反规则；单测 6 例）
        if (freeN === 2 && f1 >= 0 && f2 >= 0
            && this.blackNbrs(this.blacks, f1) <= 1) {
          const rr0: number = Math.floor(f1 / n) + 1;
          const cc0: number = (f1 % n) + 1;
          return Hint.make([f1],
            TG2('第 {0} 行第 {1} 列必须涂黑 —— 这个区只剩两格了，两格都要黑',
              String(rr0), String(cc0)),
            TG2('Row {0}, column {1} must be black — this region has only two cells left',
              String(rr0), String(cc0)), t0);
        }
        continue;
      }
      if (blackN !== 1 || blackCell < 0) {
        continue;                      // 已满 2 个不推
      }
      // ★ 2026-10-24 补：这个黑格自己必须**还没有黑邻居**。
      //   若它已有一个（可能是跨区的）黑邻居，再给它加一个相邻黑格
      //   ⇒ 邻居数变 2 ⇒ 违反"黑格邻居不超过 1"的规则。
      //   （单测 1221 组里抓到 142 例，是真 bug）
      if (this.blackNbrs(this.blacks, blackCell) > 0) {
        continue;
      }
      // 与它相邻、同区、且还没涂黑的格子
      const r: number = Math.floor(blackCell / n);
      const c: number = blackCell % n;
      const cand: number[] = [];
      const tryCell = (j: number): void => {
        if (j >= 0 && j < total && this.blacks[j] === 0 && this.regions[j] === rid) {
          cand.push(j);
        }
      };
      if (r > 0) {
        tryCell(blackCell - n);
      }
      if (r < n - 1) {
        tryCell(blackCell + n);
      }
      if (c > 0) {
        tryCell(blackCell - 1);
      }
      if (c < n - 1) {
        tryCell(blackCell + 1);
      }
      if (cand.length !== 1) {
        continue;                      // 只剩一个候选才推
      }
      const j2: number = cand[0];
      // ★ 2026-10-24 再补（第三次修正）：候选格的**黑邻居必须恰好是那一个**。
      //   它本来就与 blackCell 相邻 ⇒ 至少有 1 个黑邻居。
      //   ⇒ 条件是「恰好 1 个」，不是「0 个」。
      //   若为 0 ⇒ 说明它其实不与 blackCell 相邻（不该走到这里）；
      //   若 ≥ 2 ⇒ 另有别的黑格贴着它，涂黑后邻居数会变 2 ⇒ 非法。
      if (this.blackNbrs(this.blacks, j2) !== 1) {
        continue;
      }
      const rr: number = Math.floor(j2 / n) + 1;
      const cc: number = (j2 % n) + 1;
      return Hint.make([j2],
        TG2('第 {0} 行第 {1} 列必须涂黑 —— 这一区的第二个黑格只能贴着已有的那个放',
          String(rr), String(cc)),
        TG2('Row {0}, column {1} must be black — it is the only cell adjacent to the region\'s single black',
          String(rr), String(cc)), t0);
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须涂黑'));
  }

  private isWin(): boolean {
    if (this.placed !== REG_CNT * 2) {
      return false;
    }
    for (let rid = 1; rid <= REG_CNT; rid++) {
      if (!this.regionDone(rid)) {
        return false;
      }
    }
    for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
      if (this.blacks[k] === 1 && this.blackNbrs(this.blacks, k) !== 1) {
        return false;
      }
    }
    return true;
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
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
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
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.autoCell() < 0) {
      return true;
    }
    this.tap(this.autoCell());
    return !this.over;
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

    /** 深搜：每区放一对相邻黑格（rid = 1..REG_CNT）；放满后校验「每个黑格恰好 1 个黑邻居」 */
    private dfsPick(rid: number, chosen: number[]): boolean {
      if (rid > REG_CNT) {
        const arr: number[] = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
        for (let k = 0; k < chosen.length; k++) {
          arr[chosen[k]] = 1;
        }
        for (let k = 0; k < chosen.length; k++) {
          if (this.blackNbrs(arr, chosen[k]) !== 1) {
            return false;
          }
        }
        return true;
      }
      const n: number = this.diffTotal;
      const total: number = n * n;
      for (let i = 0; i < total; i++) {
        if (this.regions[i] !== rid) {
          continue;
        }
        const r: number = Math.floor(i / n);
        const c: number = i % n;
        if (c < n - 1 && this.regions[i + 1] === rid) {
          chosen.push(i);
          chosen.push(i + 1);
          if (this.dfsPick(rid + 1, chosen)) {
            return true;
          }
          chosen.pop();
          chosen.pop();
        }
        if (r < n - 1 && this.regions[i + n] === rid) {
          chosen.push(i);
          chosen.push(i + n);
          if (this.dfsPick(rid + 1, chosen)) {
            return true;
          }
          chosen.pop();
          chosen.pop();
        }
      }
      return false;
    }

    /** 代打：这一步该涂黑哪一格（整盘解由 dfsPick 现算；-1 = 没有待涂的） */
    private autoCell(): number {
      const chosen: number[] = [];
      if (!this.dfsPick(1, chosen) || chosen.length === 0) {
        return -1;
      }
      for (let k = 0; k < chosen.length; k++) {
        if (this.blacks[chosen[k]] !== 1) {
          return chosen[k];
        }
      }
      return -1;
    }
  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.blacks[i] === 1) {
      const cleared: number[] = this.blacks.slice();
      cleared[i] = 0;
      this.blacks = cleared;
      this.placed--;
      return;
    }
    const next: number[] = this.blacks.slice();
    next[i] = 1;
    if (!this.legal(next, i)) {
      this.errors++;
      if (this.errors >= this.errMax) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.blacks = next;
    this.placed++;
    if (this.isWin()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(60, 360 - this.errors * 40 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'norinori',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneRegions()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    if (this.blacks[i] === 1) {
      return this.theme.isDark ? '#E2E8F0' : '#1E293B';
    }
    return tintOf(Palette.wheel[(this.regions[i] - 1) % Palette.wheel.length], this.theme.isDark);
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已满足区域'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneRegions()) + '/' + String(REG_CNT)))
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
        Text((TG('已放黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed) + '/' + String(REG_CNT * 2)))
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
        Text((TG('错手'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(this.errMax)))
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
              Text(this.blacks[(r * this.diffTotal + c)] === 1 ? '' : String(this.regions[(r * this.diffTotal + c)]))
              .fontSize(FontSize.xxs)
              .fontColor(this.theme.inkFaint)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
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
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '全部成对 🎉 得分 ' + String(this.score) : '非法落子太多，本局失败')
          : TG2('点亮格子：{0} 块区域各 2 格，且两两成多米诺', String(REG_CNT)))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.primary)
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
