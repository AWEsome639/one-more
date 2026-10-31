/**
 * 找路径（7×7 迷宫）—— 从左上角走到右下角，步数用完即失败
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：走到终点 ⇒ solved:true；步数超过上限 ⇒ solved:false
 * 进度：已用步数 ／ 步数上限 ／ 理论最短路
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const MR: number = 7;
const MC: number = 7;
const CELLS: number = MR * MC;
const GOAL: number = CELLS - 1;

/** 3 张迷宫（1 = 墙，0 = 通路） */
const MAZE_LIB: number[][] = [
  // 第 1 关
  [
    0,1,0,0,0,0,0,
    0,1,1,1,0,1,1,
    0,0,0,1,0,0,0,
    1,1,0,1,0,1,0,
    0,1,0,1,0,1,0,
    0,1,0,1,1,1,0,
    0,0,0,0,0,0,0
  ],
  // 第 2 关
  [
    0,0,0,1,0,0,0,
    1,1,0,1,0,1,0,
    0,0,0,1,0,1,0,
    0,1,1,1,0,1,0,
    0,0,0,1,0,1,0,
    1,1,0,1,0,1,0,
    0,0,0,0,0,1,0
  ],
  // 第 3 关
  [
    0,1,0,0,0,1,0,
    0,1,0,1,0,1,0,
    0,0,0,1,0,1,0,
    1,1,1,1,0,1,0,
    0,0,0,1,0,1,0,
    0,1,1,1,0,1,0,
    0,0,0,0,0,0,0
  ]
];

/** 每张迷宫的最短路步数 */
const MAZE_PAR: number[] = [12,28,16];

@Component
export struct GPathFinder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 MR=7）
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」第 12 个：
   *   迷宫来自 MAZE_LIB，是**手工画的 7×7 = 49 格**，
   *   但原来 diffTotal = sizeNow(7)（5/7/9）：
   *     · 简单 5×5：终点 index 48 在行 6，而 move() 里 r >= diffTotal 直接 return
   *       ⇒ **走不到终点，这一档无解**
   *     · 困难 9×9：r 允许到 8，但 maze 只有 49 项 ⇒ 后两行读到 undefined
   *     · move() 里行用 diffTotal、列用 MC=7 ⇒ 行列口径不一致
   *   ⇒ 修法：**棋盘固定 7×7**，难度改到**步数预算**上
   *     （budget 本来就是 par * 2，现在按难度给不同倍率）
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
  @State private diffTotal: number = 7;
  /** 本局的步数预算倍率：简单 2.6 / 普通 2.0 / 困难 1.5 */
  @State private budgetMul: number = GPathFinder.mulNow();

  private static mulNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 2.6;
    }
    if (d === 2) {
      return 1.5;
    }
    return 2.0;
  }

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State maze: number[] = [];
  @State par: number = 0;
  @State budget: number = 0;
  @State pos: number = 0;
  @State steps: number = 0;
  @State trail: number[] = [];
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPathFinder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.budgetMul = GPathFinder.mulNow();
    this.diffTotal = GameDiff.sizeNow(7);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * MAZE_LIB.length);
    this.maze = MAZE_LIB[k].slice();
    this.par = MAZE_PAR[k];
    this.budget = Math.round(this.par * this.budgetMul);
    this.pos = 0;
    this.steps = 0;
    this.trail = new Array<number>(CELLS).fill(0);
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private move(dr: number, dc: number): void {
    if (this.over) {
      return;
    }
    const r: number = Math.floor(this.pos / MC) + dr;
    const c: number = this.pos % MC + dc;
    if (r < 0 || r >= this.diffTotal || c < 0 || c >= MC) {
      return;
    }
    const t: number = r * MC + c;
    if (this.maze[t] === 1) {
      return;
    }
    this.pos = t;
    this.steps++;
    const tr: number[] = this.trail.slice();
    tr[t] = 1;
    this.trail = tr;
    if (t === GOAL) {
      this.over = true;
      this.won = true;
      const extra: number = this.steps - this.par;
      this.score = extra >= 0 ? Math.max(60, 420 - extra * 10) : 420;
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

  /** 点相邻格子也能走 */

  /**
   * ★ 2026-10-23 第二期：找路径提示
   *
   * 直接 BFS 从当前位置到终点，取第一步。
   * 迷宫只有 49 格 ⇒ 毫秒级，也永远不会"算不出来"（迷宫本身保证连通）。
   *
   * ⚠️ 这只是"一条最短路的下一步"，不是唯一解 —— 提示文案说的是
   *    「这一步能让你离终点更近」，不声称"唯一走法"。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    const start: number = this.pos;
    if (start === GOAL) {
      return Hint.none('none');
    }
    const prev: number[] = new Array<number>(n * n).fill(-1);
    const seen: boolean[] = new Array<boolean>(n * n).fill(false);
    const q: number[] = [start];
    seen[start] = true;
    let head: number = 0;
    while (head < q.length) {
      const cur: number = q[head];
      head++;
      if (cur === GOAL) {
        break;
      }
      const r: number = Math.floor(cur / MC);
      const c: number = cur % MC;
      const dr: number[] = [-1, 1, 0, 0];
      const dc: number[] = [0, 0, -1, 1];
      for (let d = 0; d < 4; d++) {
        const nr: number = r + dr[d];
        const nc: number = c + dc[d];
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) {
          continue;
        }
        const ni: number = nr * MC + nc;
        if (seen[ni] || this.maze[ni] === 1) {
          continue;
        }
        seen[ni] = true;
        prev[ni] = cur;
        q.push(ni);
      }
    }
    if (prev[GOAL] < 0) {
      return Hint.none('none');
    }
    // 回溯到第一步
    let step: number = GOAL;
    while (prev[step] !== start && prev[step] >= 0) {
      step = prev[step];
    }
    const r: number = Math.floor(step / MC) + 1;
    const c: number = (step % MC) + 1;
    return Hint.make([step],
      TG2('往第 {0} 行第 {1} 列走（最短路上的一步）', String(r), String(c)),
      TG2('Move to row {0}, column {1} (one step on a shortest path)', String(r), String(c)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 提示驱动：computeHint 返回"下一步走哪格" ⇒ tap 它
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

  private tap(i: number): void {
    const dr: number = Math.floor(i / MC) - Math.floor(this.pos / MC);
    const dc: number = i % MC - this.pos % MC;
    if (Math.abs(dr) + Math.abs(dc) === 1) {
      this.move(dr, dc);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'path_finder',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.steps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    if (this.maze[i] === 1) {
      return this.theme.isDark ? '#334155' : '#1E293B';
    }
    if (this.pos === i) {
      return Palette.primary;
    }
    if (this.trail[i] === 1) {
      return this.theme.isDark ? '#1E3A5F' : '#DBEAFE';
    }
    return this.theme.surface;
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已用步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(this.budget)))
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
        Text((TG('最短路'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.par), this.langCode))
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
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, this.budget - this.steps))))
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
              Text(this.pos === (r * MC + c) ? '🧍' : ((r * MC + c) === GOAL ? '🏁' : ''))
              .fontSize(FontSize.sm)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * MC + c)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * MC + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * MC + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.xs }) {
        Text(('←'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(42))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.move((0), (-1));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move((0), (-1)); }); })
        Text(('↑'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(42))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.move((-1), (0));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move((-1), (0)); }); })
        Text(('↓'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(42))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.move((1), (0));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move((1), (0)); }); })
        Text(('→'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(42))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.move((0), (1));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move((0), (1)); }); })
      }
      .width('100%')

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '抵达终点 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '🧍 是你，🏁 是终点：按方向键或点相邻格')
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
          .backgroundColor(Palette.emerald)
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
