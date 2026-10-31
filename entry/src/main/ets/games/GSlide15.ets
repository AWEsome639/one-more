/**
 * 数字华容道 4×4 —— 把 1~15 按顺序归位，右下角留空
 *
 * ★可解性（关键）：初始局面**不是随机排列**，而是从"已解状态"出发做 260 步随机合法移动打乱。
 *   15-puzzle 的合法移动只产生偶置换，随机排列有一半是无解的 —— 用"逆向打乱"从根上杜绝无解局面。
 *
 * 交互：点空格旁的方块 ⇒ 它滑进空位；也支持朝空位方向滑整块棋盘（滑动是点击的别名）
 * 通关：第 0~14 格依次为 1~15，第 15 格为空
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 6×6 = 36 格，原来只开 16）
const MAX_N: number = 6;
const MAX_CELLS: number = MAX_N * MAX_N;
const SHUFFLE_STEPS: number = 260;

@Component
export struct GSlide15 {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State tiles: number[] = [];        // 0 = 空位
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State moves: number = 0;
  @State seconds: number = 0;
  @State won: boolean = false;
  @State pressed: number = -1;
  @State bestMoves: number = 0;       // 本局内的最好成绩
  /** ★★ 2026-10-14 滑行（奥森：部分游戏应该有动态的运动过程，以 2048 为首）：
   *  只让【刚移过来的那一块】从「来处」方向滑进来 */
  @State private slideTo: number = -1;
  @State private slideDX: number = 0;
  @State private slideDY: number = 0;

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  /** ★ 代打用：打乱时记下的空位轨迹，倒着走一遍就必然归位（每一步都可逆） */
  private solPlan: number[] = [];
  private planAt: number = 0;
  /** 倒放计划还成不成立（玩家自己滑过就不成立了） */
  private planOk: boolean = true;
  /** 贪心兜底用：上一步空位在哪（避免原地来回） */
  private lastCell: number = -1;
  private blank: number = CELLS - 1;
  private initial: number[] = [];
  private initialBlank: number = CELLS - 1;
  private startAt: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSlide15')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private reset(): void {
    // ① 从已解状态出发
    let t: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < CELLS - 1; i++) {
      t[i] = i + 1;
    }
    // ② 只做合法移动 ⇒ 局面必定可解（等价于"倒着解回去"）
    let b: number = CELLS - 1;
    let prev: number = -1;
    // ★ 代打用：把空位走过的每一格记下来 —— 倒着走一遍就是一条「必定归位」的路
    const walk: number[] = [CELLS - 1];
    for (let s = 0; s < SHUFFLE_STEPS; s++) {
      const cand: number[] = this.neighbors(b).filter((x: number) => x !== prev);
      const pick: number = cand[Math.floor(Math.random() * cand.length)];
      t[b] = t[pick];
      t[pick] = 0;
      prev = b;
      b = pick;
      walk.push(pick);
    }
    if (this.isDone(t)) {          // 极小概率又转回原状 ⇒ 再挪一步
      const nb: number[] = this.neighbors(b);
      const pick: number = nb[Math.floor(Math.random() * nb.length)];
      t[b] = t[pick];
      t[pick] = 0;
      b = pick;
      walk.push(pick);
    }
    const rev: number[] = walk.slice();
    rev.reverse();
    this.solPlan = rev.slice(1);
    this.planAt = 0;
    this.planOk = true;
    this.lastCell = -1;

    this.initial = t.slice();
    this.initialBlank = b;
    this.tiles = t;
    this.blank = b;
    this.moves = 0;
    this.won = false;
    this.seconds = 0;
    this.pressed = -1;
    this.startAt = Date.now();

    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.timer = setInterval(() => {
      if (!this.won) {
        this.seconds = Math.floor((Date.now() - this.startAt) / 1000);
      }
    }, 1000);
  }

  /** 某格的上下左右合法邻格 */
  private neighbors(i: number): number[] {
    const x: number = i % this.diffTotal;
    const y: number = Math.floor(i / this.diffTotal);
    const out: number[] = [];
    if (x > 0) {
      out.push(i - 1);
    }
    if (x < this.diffTotal - 1) {
      out.push(i + 1);
    }
    if (y > 0) {
      out.push(i - this.diffTotal);
    }
    if (y < this.diffTotal - 1) {
      out.push(i + this.diffTotal);
    }
    return out;
  }

  private isDone(t: number[]): boolean {
    for (let i = 0; i < CELLS - 1; i++) {
      if (t[i] !== i + 1) {
        return false;
      }
    }
    return t[CELLS - 1] === 0;
  }

  /** 点方块：只有挨着空位的才能滑 */

  /** 总曼哈顿距离（空位不算）；格数与边长全部从 diffTotal 派生 */
  private manhattan15(arr: number[]): number {
    const n2: number = this.diffTotal;
    let sum: number = 0;
    for (let i = 0; i < n2 * n2; i++) {
      const v: number = arr[i];
      if (v <= 0) {
        continue;
      }
      const tr: number = Math.floor((v - 1) / n2);
      const tc: number = (v - 1) % n2;
      sum += Math.abs(Math.floor(i / n2) - tr) + Math.abs(i % n2 - tc);
    }
    return sum;
  }

  /**
   * ★ 2026-10-23 第二期：数字华容道（4×4 版）提示
   *
   * 与 3×3 版同一套：曼哈顿距离贪心爬山 —— 枚举空位能换的相邻块，
   * 挑换完之后总距离最小的那一步。
   *
   * ⚠️ 不是最优解，只是朝答案走的一步（最优要 A 星，4×4 解长五六十步，
   *    单次 500 ms 内跑不完）。文案也明说「总距离 x → y」。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n2: number = this.diffTotal;
    const b: number = this.blank;
    const br: number = Math.floor(b / n2);
    const bc: number = b % n2;
    const cand: number[] = [];
    if (br > 0) {
      cand.push(b - n2);
    }
    if (br < n2 - 1) {
      cand.push(b + n2);
    }
    if (bc > 0) {
      cand.push(b - 1);
    }
    if (bc < n2 - 1) {
      cand.push(b + 1);
    }
    if (cand.length === 0) {
      return Hint.none('none');
    }
    const cur: number = this.manhattan15(this.tiles);
    let bestIdx: number = -1;
    let bestDist: number = 1e9;
    for (let k = 0; k < cand.length; k++) {
      const i: number = cand[k];
      const arr: number[] = this.tiles.slice();
      arr[b] = arr[i];
      arr[i] = 0;
      const d: number = this.manhattan15(arr);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(bestIdx / n2) + 1;
    const c: number = (bestIdx % n2) + 1;
    const better: boolean = bestDist < cur;
    return Hint.make([bestIdx],
      TG4(better ? '把第 {0} 行第 {1} 列的块推进空格（总距离 {2} → {3}）'
                 : '没有能立刻缩短距离的一步；先推第 {0} 行第 {1} 列（距离 {2} → {3}）',
        String(r), String(c), String(cur), String(bestDist)),
      TG4(better ? 'Slide the tile at row {0}, column {1} (distance {2} → {3})'
                 : 'No immediate gain; slide row {0}, column {1} first (distance {2} → {3})',
        String(r), String(c), String(cur), String(bestDist)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintMsg = ''; }, 5000);
      return;
    }
    this.hintMsg = TG('这一局算不出来，重开一局试试');
    setTimeout(() => { this.hintMsg = ''; }, 5000);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ① 局面还是开局 ⇒ 把打乱的那串滑动倒着走一遍，必然归位（每一步都可逆）
  // ② 玩家已经自己滑过了 ⇒ 退化成曼哈顿下降的一步（缩不短就绕一步，绝不原地打转）
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
    if (this.won) {
      return false;
    }
    if (this.planOk && this.planAt < this.solPlan.length) {
      let k: number = 0;
      while (k < 20 && this.planAt < this.solPlan.length && !this.won) {
        if (this.planAt === 0 && !this.sameAsInitial()) {
          this.planOk = false;
          break;
        }
        const cell: number = this.solPlan[this.planAt];
        if (!this.nearBlank(cell)) {
          this.planOk = false;
          break;
        }
        this.planAt = this.planAt + 1;
        this.tap(cell);
        k = k + 1;
      }
      if (this.planOk) {
        return !this.won;
      }
    }
    return this.greedyStep();
  }

  /** 局面是否还是本局开局 —— 倒放计划只对这个局面成立 */
  private sameAsInitial(): boolean {
    if (this.blank !== this.initialBlank || this.tiles.length !== this.initial.length) {
      return false;
    }
    for (let i = 0; i < this.initial.length; i++) {
      if (this.tiles[i] !== this.initial[i]) {
        return false;
      }
    }
    return true;
  }

  /** 这一格是不是挨着空位（能滑） */
  private nearBlank(cell: number): boolean {
    const bx: number = this.blank % this.diffTotal;
    const by: number = Math.floor(this.blank / this.diffTotal);
    const x: number = cell % this.diffTotal;
    const y: number = Math.floor(cell / this.diffTotal);
    return Math.abs(x - bx) + Math.abs(y - by) === 1;
  }

  /** 贪心一步：优先缩短总曼哈顿距离；一步也缩不短就挑最小的一步绕（不立刻走回头路） */
  private greedyStep(): boolean {
    const b: number = this.blank;
    const cand: number[] = this.neighbors(b);
    if (cand.length === 0) {
      return false;
    }
    let pickAt: number = -1;
    let pickD: number = -1;
    let safeAt: number = -1;
    let safeD: number = -1;
    for (let k = 0; k < cand.length; k++) {
      const i: number = cand[k];
      const arr: number[] = this.tiles.slice();
      arr[b] = arr[i];
      arr[i] = 0;
      const d: number = this.manhattan15(arr);
      if (pickAt < 0 || d < pickD) {
        pickAt = i;
        pickD = d;
      }
      if (i !== this.lastCell && (safeAt < 0 || d < safeD)) {
        safeAt = i;
        safeD = d;
      }
    }
    const useAt: number = safeAt >= 0 ? safeAt : pickAt;
    if (useAt < 0) {
      return false;
    }
    this.lastCell = b;
    this.tap(useAt);
    return !this.won;
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
    if (this.won || i === this.blank) {
      return;
    }
    const bx: number = this.blank % this.diffTotal;
    const by: number = Math.floor(this.blank / this.diffTotal);
    const x: number = i % this.diffTotal;
    const y: number = Math.floor(i / this.diffTotal);
    if (Math.abs(x - bx) + Math.abs(y - by) !== 1) {
      return;
    }
    const t: number[] = this.tiles.slice();
    t[this.blank] = t[i];
    t[i] = 0;
    this.blank = i;
    this.tiles = t;
    // ★ 滑行：记录「移到哪」与「从哪来」的方向
    const OFF: number = 12;
    this.slideTo = i;
    this.slideDX = ((i % this.diffTotal) - bx) * OFF;
    this.slideDY = (Math.floor(i / this.diffTotal) - by) * OFF;
    setTimeout(() => { this.slideDX = 0; this.slideDY = 0; }, 16);
    this.moves++;

    if (this.isDone(t)) {
      this.won = true;
      if (this.bestMoves === 0 || this.moves < this.bestMoves) {
        this.bestMoves = this.moves;
      }
      this.finish(true);
    }
  }

  /** 滑动是"点空格另一侧那块"的别名：上滑 ⇒ 空位下方的块往上走 */
  private swipe(dir: number): void {
    const bx: number = this.blank % this.diffTotal;
    const by: number = Math.floor(this.blank / this.diffTotal);
    if (dir === 0 && by < this.diffTotal - 1) {
      this.tap(this.blank + this.diffTotal);
    } else if (dir === 1 && bx > 0) {
      this.tap(this.blank - 1);
    } else if (dir === 2 && by > 0) {
      this.tap(this.blank - this.diffTotal);
    } else if (dir === 3 && bx < this.diffTotal - 1) {
      this.tap(this.blank + 1);
    }
  }

  private finish(solved: boolean): void {
    const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
    const r: GameResult = {
      gameId: 'slide15',
      solved: solved,
      score: solved ? Math.max(100, 1600 - this.moves * 8 - sec * 3) : 0,
      durationMs: Date.now() - this.startAt
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private clock(): string {
    const m: number = Math.floor(this.seconds / 60);
    const s: number = this.seconds % 60;
    return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
  }

  private tileBg(v: number, i: number): string {
    if (v === 0) {
      return this.theme.isDark ? '#14FFFFFF' : '#0F0F172A';
    }
    return v === i + 1 ? Palette.emerald : this.theme.surface;
  }

  private tileInk(v: number, i: number): ResourceColor {
    return v === i + 1 ? Color.White : this.theme.ink;
  }

  /** 回到本局的初始局面（局面不变，从头再来） */
  private retrySame(): void {
    const t: number[] = this.initial.slice();
    this.tiles = t;
    this.blank = this.initialBlank;
    this.planAt = 0;
    this.moves = 0;
    this.won = false;
    this.seconds = 0;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  build() {
    Column({ space: Space.lg }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      // ── 顶部三个数字 ──
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode))
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
        Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.clock()))
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
        Text((TG('最好'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.bestMoves > 0 ? this.bestMoves + TG(' 步') : '—'))
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

      // ── 棋盘 ──
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              if ((this.tiles[r * this.diffTotal + c]) > 0) {
              Text(String((this.tiles[r * this.diffTotal + c])))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.tileInk((this.tiles[r * this.diffTotal + c]), (r * this.diffTotal + c)))
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              // ★ 滑行：只有刚移过来的那块有位移（其它块不动）
              .translate({
                x: (r * this.diffTotal + c) === this.slideTo ? this.slideDX : 0,
                y: (r * this.diffTotal + c) === this.slideTo ? this.slideDY : 0
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .backgroundColor(this.tileBg((this.tiles[r * this.diffTotal + c]), (r * this.diffTotal + c)))
              .borderRadius(Radius.md)
              .scale({
              x: this.pressed === (r * this.diffTotal + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * this.diffTotal + c) ? Motion.pressScale : 1
              })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * this.diffTotal + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (c: number) => 's15c' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 's15r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)
      .gesture(
        SwipeGesture({ fingers: 1, direction: SwipeDirection.All, speed: 20 })
          .onAction((e: GestureEvent) => {
            const a: number = e.angle;
            if (a >= -45 && a < 45) {
              this.swipe(1);
            } else if (a >= 45 && a < 135) {
              this.swipe(2);
            } else if (a >= -135 && a < -45) {
              this.swipe(0);
            } else {
              this.swipe(3);
            }
          })
      )

      // ── 状态 ──
      Text(this.hintMsg.length > 0 ? this.hintMsg : (this.won ? '🎉 归位完成！' : '点空白格旁边的方块，让它滑过去'))
        .fontSize(FontSize.sm)
        .fontColor(this.won ? Palette.emerald : this.theme.inkSoft)

      // ── 操作 ──
      Row({ space: Space.md }) {
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
        Button(TG('打乱重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Button(TG('重玩本局'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.retrySame();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.retrySame(); }); })
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
