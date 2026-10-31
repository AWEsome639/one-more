/**
 * 数字华容道 slide_puzzle（3×3 八数码）—— 把 1~8 推回位，右下留空
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：1~8 依次归位 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已归位块数 ／ 已用步数 ／ 剩余步数
 *
 * ★★★ 2026-10-13 P8「数字显示错误 / 一堆 undefined」的根因
 *   棋盘尺寸是难度驱动的（`diffTotal = GameDiff.sizeNow(3)` ⇒ 简单 2 / 普通 3 / 困难 4），
 *   但 `N=3 / CELLS=9` 是**模块级常量**：状态数组、判胜、已归位数只认 9 格。
 *   于是在困难档（4×4）渲染循环走 16 格，`tiles[9..15]` 越界 ⇒ 格子上显示 `undefined`，
 *   而进度还是按 9 格算 ⇒「已归位 6/8」这种对不上的数字（真机截图就是这样）。
 *   ⇒ 一切尺寸都必须从 diffTotal 派生（见 boardN()/cellCount()），不许再用 CELLS。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const SHUFFLE: number = 24;   // 打乱基准步数（实际 = SHUFFLE × 棋盘边长）

@Component
export struct GSlidePuzzle {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★★ 2026-10-14 滑行（奥森：部分游戏应该有动态的运动过程，以 2048 为首）：
   *  只让【刚移过来的那一块】从「来处」方向滑进来 */
  @State private slideTo: number = -1;
  @State private slideDX: number = 0;
  @State private slideDY: number = 0;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.boardN();
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State tiles: number[] = [];      // 0 = 空格
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;
  @State blank: number = 0;      // 空格位置（reset() 里按本局格数设）
  @State steps: number = 0;
  @State budget: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSlidePuzzle')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
    this.reset();
  }

  /** 本局棋盘边长（≥2）：难度就是靠它生效的；⛔ 别叫 size()：和 ArkUI 属性方法同名，风险不明 */
  private boardN(): number {
    return this.diffTotal >= 2 ? this.diffTotal : 2;
  }

  /** 本局格子数 = size² —— ⛔ 不要再用模块常量 CELLS（那会让 2×2/4×4 档错位） */
  private cellCount(): number {
    return this.boardN() * this.boardN();
  }

  private nbrsOf(b: number): number[] {
    const out: number[] = [];
    const n2: number = this.boardN();
    const r: number = Math.floor(b / n2);
    const c: number = b % n2;
    if (r > 0) {
      out.push(b - n2);
    }
    if (r < n2 - 1) {
      out.push(b + n2);
    }
    if (c > 0) {
      out.push(b - 1);
    }
    if (c < n2 - 1) {
      out.push(b + 1);
    }
    return out;
  }

  private solvedArr(arr: number[]): boolean {
    const cells: number = this.cellCount();
    for (let i = 0; i < cells - 1; i++) {
      if (arr[i] !== i + 1) {
        return false;
      }
    }
    return arr[cells - 1] === 0;
  }

  private reset(): void {
    const n2: number = this.boardN();
    const cells: number = this.cellCount();
    let tiles: number[] = [];
    let blank: number = cells - 1;
    let guard: number = 0;
    while (guard < 8) {
      tiles = new Array<number>(cells).fill(0);
      for (let i = 0; i < cells - 1; i++) {
        tiles[i] = i + 1;
      }
      blank = cells - 1;
      // 打乱步数也随棋盘走（2×2=48 步 / 3×3=72 / 4×4=96）：格子多了要洗得更匀
      for (let m = 0; m < SHUFFLE * n2; m++) {
        const opts: number[] = this.nbrsOf(blank);
        const t: number = opts[Math.floor(Math.random() * opts.length)];
        tiles[blank] = tiles[t];
        tiles[t] = 0;
        blank = t;
      }
      guard++;
      if (!this.solvedArr(tiles)) {
        break;
      }
    }
    this.tiles = tiles;
    this.blank = blank;
    this.steps = 0;
    // 步数预算同样按棋盘：普通档仍是 72（=SHUFFLE×3），和真机截图口径一致
    this.budget = Math.max(60, SHUFFLE * n2);
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private homeCount(): number {
    let n: number = 0;
    const cells: number = this.cellCount();
    for (let i = 0; i < cells - 1; i++) {
      if (this.tiles[i] === i + 1) {
        n++;
      }
    }
    return n;
  }


  /** 一个盘面的总曼哈顿距离（空格不算） */
  private manhattan(arr: number[]): number {
    const n2: number = this.boardN();
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
   * ★ 2026-10-23 第二期：数字华容道提示
   *
   * 做法是**曼哈顿距离的贪心爬山**：
   *   枚举空格能换的相邻块 → 各算换完之后的曼哈顿距离
   *   → 挑距离最小的那一步；若没有一步能下降，则挑最不坏的。
   *
   * ⚠️ 这**不是最优解**，只是"朝着答案走的一步"。
   *    最优解要 A 星 / IDA 星；4×4 打乱后解长五六十步，500 ms 内跑不完。
   *    与其给个算不准的"最优"，不如诚实给个"能往前走的一步"，
   *    提示文案也是这么写的（「总距离 x → y」，不写"最优"）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n2: number = this.boardN();
    const b: number = this.blank;
    const cand: number[] = this.nbrsOf(b);
    if (cand.length === 0) {
      return Hint.none('none');
    }
    const cur: number = this.manhattan(this.tiles);
    let bestIdx: number = -1;
    let bestDist: number = 1e9;
    for (let k = 0; k < cand.length; k++) {
      const i: number = cand[k];
      const arr: number[] = this.tiles.slice();
      arr[b] = arr[i];
      arr[i] = 0;
      const d: number = this.manhattan(arr);
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

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 复用 computeHint()：它返回"该推哪一块"，代打就把它按下去。
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length === 0) {
      return false;
    }
    this.tap(r.cells[0]);
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

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const b: number = this.blank;
    const n2: number = this.boardN();
    const dr: number = Math.abs(Math.floor(i / n2) - Math.floor(b / n2));
    const dc: number = Math.abs(i % n2 - b % n2);
    if (dr + dc !== 1) {
      return;                       // 只能推空格旁边的块
    }
    const tiles: number[] = this.tiles.slice();
    tiles[b] = tiles[i];
    tiles[i] = 0;
    this.tiles = tiles;
    this.blank = i;
    this.steps++;
    // ★ 滑行：记录「移到哪」与「从哪来」（维度用 n2）
    const OFF: number = 12;
    this.slideTo = i;
    this.slideDX = ((i % n2) - (b % n2)) * OFF;
    this.slideDY = (Math.floor(i / n2) - Math.floor(b / n2)) * OFF;
    setTimeout(() => { this.slideDX = 0; this.slideDY = 0; }, 16);
    if (this.solvedArr(this.tiles)) {
      this.over = true;
      this.won = true;
      this.score = Math.max(80, 360 - this.steps * 5);
      this.finish(true);
      return;
    }
    if (this.steps >= this.budget) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'slide_puzzle',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.homeCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        // ⚠️ 只传「种类」：@Builder 按值传参不建立 ArkUI 观察（P6/P8 同族），传值这三个数不刷新
        this.statBox(0)
        this.statBox(1)
        this.statBox(2)
      }
      .width('100%')

      Column({ space: Space.sm }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (c: number) => {
              this.tile(r, c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      // ★★★ 2026-10-30 · 用「算出来的边长」，不用百分比（见 boardPx 注释）
      .width(this.boardPx())
      .height(this.boardPx())
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.hintMsg.length > 0 ? this.hintMsg : (this.over
          ? (this.won ? '全部归位 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点空格旁边的块把它推进去'))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.rose)
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

  /** 顶部小格：kind 0=已归位 1=已用步数 2=剩余 */
  @Builder
  statBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '已归位' : (kind === 1 ? TG('已用步数') : TG('剩余')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.homeCount()) + '/' + String(this.cellCount() - 1)
        : (kind === 1 ? String(this.steps) + '/' + String(this.budget)
          : String(Math.max(0, this.budget - this.steps))))
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

  /** 一个格子：收 (r,c) 位置，下标在内部按本局边长算（见左上注释：尺寸是难度驱动的） */
  @Builder
  tile(r: number, c: number) {
    Stack() {
      Text(this.tiles[r * this.boardN() + c] === 0 ? '' : String(this.tiles[r * this.boardN() + c]))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .layoutWeight(1)
    .aspectRatio(1)
    // ★ 滑行：只有刚移过来的那块有位移
    .translate({
      x: (r * this.boardN() + c) === this.slideTo ? this.slideDX : 0,
      y: (r * this.boardN() + c) === this.slideTo ? this.slideDY : 0
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .backgroundColor(this.tiles[r * this.boardN() + c] === 0
      ? (this.theme.isDark ? '#101010' : '#E2E8F0')
      : (this.tiles[r * this.boardN() + c] === r * this.boardN() + c + 1 ? Palette.emerald : Palette.primary))
    .borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.tap(r * this.boardN() + c);
    })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(r * this.boardN() + c); }); })
  }
}
