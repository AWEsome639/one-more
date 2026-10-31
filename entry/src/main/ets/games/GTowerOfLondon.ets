/** 伦敦塔 📐（id: tower_of_london）
 * 每次搬一个球、大球不许压小球，把三球摆成目标；摆成 ⇒ 通关，超出「最少步 + 5」⇒ 失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
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
const PEGS: number = 3;
const BALLS: number = 3;
const STATES: number = 27;
const SLACK: number = 5;
/** 三进制权重：球 b 所在柱 = (state / W[b-1]) % 3，球 1 最小 */
const W: number[] = [9, 3, 1];
const COLORS: string[] = [Palette.emerald, Palette.sky, Palette.violet];
const TOWERS: number[] = [0, 1, 2];
@Component
export struct GTowerOfLondon {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 PEGS=3
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」第 14 个：
   *   状态编码是**手工设计的三进制**：3 根柱子 × 3 个球 = 27 种状态，
   *   权重 W=[9,3,1]（球 1 最轻）。这是固定结构，不能按难度缩放。
   *
   *   但原来 diffTotal = sizeNow(3)（2/3/4），而且 ballAt() 用它当进制：
   *     ballAt(s,b) = floor(s / W[b-1]) % diffTotal
   *     · 简单 diffTotal=2：三进制权重配 %2 ⇒ 状态映射全乱
   *     · 困难 diffTotal=4：%4 会返回 3 ⇒ **第 4 根柱子不存在**，
   *       bfs 里 nx 能超过 26 ⇒ dist[nx] 越界写（数组只有 27 项）
   *
   *   ⇒ 修法：进制固定成 PEGS=3；难度改到**允许多走的步数**上。
   */
  @State private diffTotal: number = PEGS;
  /** 允许比最少步数多走几步：简单 8 / 普通 5 / 困难 3 */
  @State private slacks: number = GTowerOfLondon.slackNow();

  private static slackNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 8;
    }
    if (d === 2) {
      return 3;
    }
    return 5;
  }
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State state: number = 0;
  @State goalState: number = 1;
  @State sel: number = -1;
  @State moves: number = 0;
  @State best: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTowerOfLondon')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.slacks = GTowerOfLondon.slackNow();
     this.reset(); }
  private reset(): void {
    const a: number = Math.floor(Math.random() * STATES);
    let b: number = Math.floor(Math.random() * STATES);
    for (let i = 0; i < 40 && b === a; i++) { b = Math.floor(Math.random() * STATES); }
    this.state = a; this.goalState = b; this.sel = -1; this.moves = 0; this.best = this.bfs(a, b);
    this.over = false; this.won = false; this.done = false;
    this.note = TG('每次搬一个球 · 大球不能压小球 · 摆成目标'); this.startAt = Date.now();
  }
  private ballAt(s: number, b: number): number { return Math.floor(s / W[b - 1]) % this.diffTotal; }
  /** 球 b 能不能落到柱 c：柱 c 上不能有比它更小的球 */
  private canPut(s: number, b: number, c: number): boolean {
    for (let o = 1; o < b; o++) { if (this.ballAt(s, o) === c) { return false; } }
    return true;
  }
  private topBall(s: number, i: number): number {
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === i) { return b; } }
    return -1;
  }
  /** 广度优先求最少步数（合法状态只有 27 种） */
  private bfs(from: number, to: number): number {
    const dist: number[] = new Array<number>(STATES).fill(-1);
    const q: number[] = [from];
    dist[from] = 0;
    for (let h = 0; h < q.length; h++) {
      const s: number = q[h];
      if (s === to) { return dist[s]; }
      for (let b = 1; b <= BALLS; b++) {
        const a: number = this.ballAt(s, b);
        for (let c = 0; c < this.diffTotal; c++) {
          const nx: number = s + (c - a) * W[b - 1];
          if (c !== a && this.canPut(s, b, c) && dist[nx] < 0) { dist[nx] = dist[s] + 1; q.push(nx); }
        }
      }
    }
    return BALLS * 2;
  }
  private rightCount(s: number): number {
    let n: number = 0;
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === this.ballAt(this.goalState, b)) { n++; } }
    return n;
  }
  /** 柱上的球，从上到下（小球在上） */
  private stack(s: number, i: number): number[] {
    const out: number[] = [];
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === i) { out.push(b); } }
    return out;
  }
  private tap(i: number): void {
    if (this.over) { return; }
    if (this.sel < 0) {
      const top: number = this.topBall(this.state, i);
      if (top < 0) { this.note = TG('这根柱是空的'); return; }
      this.sel = i; this.note = TG2('拿起 {0} 号球', String(top));
      return;
    }
    if (this.sel === i) { this.sel = -1; this.note = TG('放回原处，重新选'); return; }
    const ball: number = this.topBall(this.state, this.sel);
    if (!this.canPut(this.state, ball, i)) { this.note = TG('❌ 大球不能压在小球上'); return; }
    const next: number = this.state + (i - this.sel) * W[ball - 1];
    this.state = next; this.moves++; this.sel = -1;
    if (next === this.goalState) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.moves >= this.best + this.slacks) { this.note = TG('步数用光了'); this.finish(false); return; }
    this.note = TG2('✅ 好，继续 · 对位 {0}/{1}', String(this.rightCount(next)), String(BALLS));
  }
  // ═══════════ 提示 + 代打（2026-10-24 第三期）═══════════
  // 这款游戏本来就有 bfs(from, to) 给出最短距离（27 个状态，极快）。
  // ⇒ 每一步枚举所有合法走法，选"走完离目标最近"的那个。

  /** 找一步最优走法，返回 [from, to]；没有返回空 */
  private bestMove(): number[] {
    if (this.bfs(this.state, this.goalState) === 0) {
      return [];
    }
    let bestA: number = -1;
    let bestB: number = -1;
    let bestD: number = 99999;
    for (let a = 0; a < this.diffTotal; a++) {
      const ball: number = this.topBall(this.state, a);
      if (ball < 0) {
        continue;
      }
      for (let b = 0; b < this.diffTotal; b++) {
        if (a === b || !this.canPut(this.state, ball, b)) {
          continue;
        }
        const nx: number = this.state + (b - a) * W[ball - 1];
        const d: number = this.bfs(nx, this.goalState);
        if (d >= 0 && d < bestD) {
          bestD = d;
          bestA = a;
          bestB = b;
        }
      }
    }
    if (bestA < 0) {
      return [];
    }
    return [bestA, bestB];
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const mv: number[] = this.bestMove();
    if (mv.length < 2) {
      return Hint.none('none');
    }
    const ball: number = this.topBall(this.state, mv[0]);
    return Hint.make([],
      TG2('把 {0} 号球从第 {1} 根柱子移到第 {2} 根', String(ball), String(mv[0] + 1), String(mv[1] + 1)),
      TG2('Move ball {0} from peg {1} to peg {2}', String(ball), String(mv[0] + 1), String(mv[1] + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出该动哪颗球'));
  }

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
    const mv: number[] = this.bestMove();
    if (mv.length < 2) {
      return false;
    }
    this.sel = mv[0];
    this.tap(mv[1]);
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

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; const r: GameResult = {
      gameId: 'tower_of_london', solved: solved,
      score: solved ? Math.max(40, 220 - (this.moves - this.best) * 20) : 0,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 1 : 0
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Text(TG2('步数 {0} · 最少 {1} · 上限 {2}',Digits(String(this.moves), this.langCode),Digits(String(this.best), this.langCode), String(this.best + this.slacks)) +
        TG2(' · 对位 {0}/{1}', String(this.rightCount(this.state)), String(BALLS)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Text(TG('目标 · 照着它摆')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
      Row({ space: Space.xs }) {
      ForEach(TOWERS, (i: number) => {
      Column({ space: 2 }) {
      Column({ space: 2 }) {
      ForEach(this.stack(((this.goalState)), (i)), (d: number) => {
      Stack() {
      Text(String(d)).fontSize(FontSize.xxs).fontColor('#FFFFFF')
      }
      .width((((false)) ? Space.xl : Space.md) + d * Space.md).height(((false)) ? Space.lg : Space.sm)
      .backgroundColor(COLORS[d - 1]).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
      }, (d: number) => 'b' + d + '_' + (i) + (((false)) ? 'L' : 'G'))
      }
      .layoutWeight(1).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
      Stack()
      .width('100%').height(Space.xs).borderRadius(Radius.xs)
      .backgroundColor(((false)) && this.sel === (i) ? Palette.amber : this.theme.lineSoft)
      }
      .layoutWeight(1).height('100%').padding(Space.xs).borderRadius(Radius.md)
      .borderWidth(((false)) && this.sel === (i) ? 2 : 0).borderColor(Palette.amber).onClick(() => { Haptics.tick(); if (((false))) { this.tap((i)); } })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (((false))) { this.tap((i)); } }); })
      }, (i: number) => ((false) ? 'lp' : 'gp') + i)
      }
      .width('100%').height((false) ? Space.xxxl * 3 : Space.xxxl * 2).padding(Space.xs)
      .borderRadius(Radius.lg).backgroundColor((false) ? this.theme.surface : this.theme.surfaceAlt).shadow(Shadow.card)
      Row({ space: Space.xs }) {
      ForEach(TOWERS, (i: number) => {
      Column({ space: 2 }) {
      Column({ space: 2 }) {
      ForEach(this.stack(((this.state)), (i)), (d: number) => {
      Stack() {
      Text(String(d)).fontSize(FontSize.xxs).fontColor('#FFFFFF')
      }
      .width((((true)) ? Space.xl : Space.md) + d * Space.md).height(((true)) ? Space.lg : Space.sm)
      .backgroundColor(COLORS[d - 1]).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
      }, (d: number) => 'b' + d + '_' + (i) + (((true)) ? 'L' : 'G'))
      }
      .layoutWeight(1).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
      Stack()
      .width('100%').height(Space.xs).borderRadius(Radius.xs)
      .backgroundColor(((true)) && this.sel === (i) ? Palette.amber : this.theme.lineSoft)
      }
      .layoutWeight(1).height('100%').padding(Space.xs).borderRadius(Radius.md)
      .borderWidth(((true)) && this.sel === (i) ? 2 : 0).borderColor(Palette.amber).onClick(() => { Haptics.tick(); if (((true))) { this.tap((i)); } })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (((true))) { this.tap((i)); } }); })
      }, (i: number) => ((true) ? 'lp' : 'gp') + i)
      }
      .width('100%').height((true) ? Space.xxxl * 3 : Space.xxxl * 2).padding(Space.xs)
      .borderRadius(Radius.lg).backgroundColor((true) ? this.theme.surface : this.theme.surfaceAlt).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
