/**
 * 灭灯（Lights Out）—— 5×5 🔌
 *
 * 规则：点一格，它自己与上下左右四格一起「亮 ↔ 灭」翻转。
 * 胜负：全盘熄灭 ⇒ 通关（solved=true）；步数用尽 ⇒ 失败。
 * 出题：从全灭出发随机按几下 ⇒ 保证这盘一定有解（按回去即可）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
const MAX_MOVES: number = 40;
const MIN_TAPS: number = 6;
const MAX_TAPS: number = 10;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

function shuffled(n: number): number[] {
  const a: number[] = range(n);
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GLightsOut {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private on: boolean[] = new Array<boolean>(CELLS).fill(false);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点任意一格：它和上下左右一起翻转');
  /** ★ 第二期：提示指向的格子（-1 = 无） */
  @State private hintIdx: number = -1;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GLightsOut')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private rowOf(i: number): number {
    return Math.floor(i / N);
  }

  private colOf(i: number): number {
    return i % N;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.rowOf(i);
    const c: number = this.colOf(i);
    if (r > 0) {
      out.push(i - N);
    }
    if (r < N - 1) {
      out.push(i + N);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < N - 1) {
      out.push(i + 1);
    }
    return out;
  }

  private flip(b: boolean[], i: number): void {
    b[i] = !b[i];
    const ns: number[] = this.nbrs(i);
    for (let k = 0; k < ns.length; k++) {
      b[ns[k]] = !b[ns[k]];
    }
  }

  private litCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.on[i]) {
        n++;
      }
    }
    return n;
  }

  private reset(): void {
    const b: boolean[] = new Array<boolean>(CELLS).fill(false);
    const order: number[] = shuffled(CELLS);
    const taps: number = MIN_TAPS + Math.floor(Math.random() * (MAX_TAPS - MIN_TAPS + 1));
    for (let i = 0; i < taps; i++) {
      this.flip(b, order[i]);
    }
    this.on = b;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点任意一格：它和上下左右一起翻转');
    this.startAt = Date.now();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'lights_out',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : Math.max(0, 300 - this.litCount() * 20),
      durationMs: Date.now() - this.startAt,
      levelReached: CELLS - this.litCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    if (this.litCount() === 0) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 全盘熄灭，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG2('步数用尽，还剩 {0} 盏亮着', String(this.litCount()));
      this.finish(false);
      return;
    }
    this.tip = TG2('还剩 {0} 盏亮着', String(this.litCount()));
  }


  /**
   * ★★★ 2026-10-23 第二期：灭灯提示（**精确解**，不猜）
   *
   * 灭灯有个很好的性质：**第一行怎么点，后面的行就全被决定了**
   *   —— 因为第 r 行点不点，只取决于第 r-1 行哪盏还亮着。
   * 所以只要枚举第一行的 2^5 = 32 种点法，逐行"追赶"下去，
   * 5 行做完看是否全灭即可。**这是可证的正确解，不是启发式。**
   *
   * 提示 = 最短解法的第一手。
   * ⚠️ 与扫雷不同：灭灯**没有隐藏信息**（棋盘全公开），
   *    所以给出"完整解法里的第一步"不算作弊 —— 只是替你算了一步。
   */
  private solveTaps(): number[] {
    let best: number[] = [];
    // ⚠️ 必须用单独的 found 标记，不能用 best.length === 0 兼作"还没找到"：
    //    "解是空的"（盘已全灭）和"还没找到解"用同一个判据会互相冒充，
    //    实测就把一个全灭的盘解成了 12 手（测试④抓到的就是这个）
    let found: boolean = false;
    for (let mask = 0; mask < (1 << N); mask++) {
      const b: boolean[] = this.on.slice();
      const taps: number[] = [];
      // 第一行按 mask 点
      for (let c = 0; c < N; c++) {
        if ((mask & (1 << c)) !== 0) {
          this.flip(b, c);
          taps.push(c);
        }
      }
      // 之后逐行追赶：上一行哪盏亮着，就在下一行同一列点它
      for (let r = 1; r < N; r++) {
        for (let c = 0; c < N; c++) {
          if (b[(r - 1) * N + c]) {
            this.flip(b, r * N + c);
            taps.push(r * N + c);
          }
        }
      }
      let allOff: boolean = true;
      for (let i = 0; i < CELLS; i++) {
        if (b[i]) {
          allOff = false;
          break;
        }
      }
      if (allOff && (!found || taps.length < best.length)) {
        best = taps;
        found = true;
      }
    }
    return best;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const sol: number[] = this.solveTaps();
    if (sol.length === 0) {
      return Hint.none('none');            // 已经全灭 / 无解（不该发生）
    }
    const first: number = sol[0];
    const r: number = Math.floor(first / N) + 1;
    const c: number = (first % N) + 1;
    return Hint.make([first],
      TG2('试试点第 {0} 行第 {1} 列（这条路共 {2} 手）', String(r), String(c), String(sol.length)),
      TG2('Try row {0}, column {1} ({2} taps in this line)', String(r), String(c), String(sol.length)),
      t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款已有 computeHint()（返回应该点的那一格）⇒ 代打就是"按提示一直点"。
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
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.tip = r.zh;
      setTimeout(() => { this.hintIdx = -1; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.tip = TG('这一步算不出来（盘面可能已经无解），重开一局吧');
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const nb: boolean[] = this.on.slice();
    this.flip(nb, i);
    this.on = nb;
    this.moves++;
    this.check();
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
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('亮灯'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.litCount()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已灭'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(CELLS - this.litCount()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Text(this.on[(r * N + c)] ? '💡' : '')
              .fontSize(FontSize.xl)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.on[(r * N + c)] ? '#33F59E0B' : (this.theme.isDark ? '#111111' : '#DDE3EC'))
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.on[(r * N + c)] ? Palette.amber : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'oc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'or' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .height(Cell.of(40))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        .onClick(() => {
          this.askHint();
        })
      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG('目标：全部熄灭。点一格会连带翻转上下左右四格'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)


      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.sky)
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
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
