/**
 * 旋转迷宫 🌀（id: rotating_maze）
 * 7×7 迷宫，每走 2 步整体顺时针转 90°；走到出口 🏁 ⇒ 通关，步数用尽 ⇒ 失败。
 * 进度：步数 / 转体次数 / 与出口的曼哈顿距离。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 7; const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 10×10 = 100 格，
//   而数组原来按 CELLS = 49 开 ⇒【困难档必越界】✗）
const MAX_N: number = 10;
const MAX_CELLS: number = MAX_N * MAX_N; const DMAX: number = 64; const TURN_EVERY: number = 2;
const DR: number[] = [-1, 0, 1, 0]; const DC: number[] = [0, 1, 0, -1];
const ROWS: number[] = [0, 1, 2, 3, 4, 5, 6];

/**
 * 顺时针 90°：格 (r,c) → (c, n-1-r)
 *
 * ★ 2026-10-23：加 n 参数。
 *   迷宫按 diffTotal 生成（5/7/9），但这里用模块常量 N=7 换算坐标
 *   ⇒ 5×5 与 9×9 时旋转会算到盘外或错位。
 */
function rotIdx(i: number, n: number): number {
  const r: number = Math.floor(i / n); const c: number = i % n;
  return c * n + (n - 1 - r);
}
/** 左上角能否走到右下角（旋转不改变连通性，判一次就够） */
function reachable(w: number[], n: number): boolean {
  const seen: boolean[] = new Array<boolean>(MAX_CELLS).fill(false); const q: number[] = [0];
  seen[0] = true; let head: number = 0;
  while (head < q.length) {
    const cur: number = q[head]; head++;
    if (cur === n * n - 1) { return true; }
    const r: number = Math.floor(cur / n); const c: number = cur % n;
    for (let d = 0; d < 4; d++) {
      const nr: number = r + DR[d]; const nc: number = c + DC[d];
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
      const nb: number = nr * n + nc;
      if (w[nb] === 1 || seen[nb]) { continue; }
      seen[nb] = true; q.push(nb);
    }
  }
  return false;
}
// ★★ 2026-10-13 修复循环上界（困难档 ×1.3 ⇒ 棋盘更大）
function genWalls(n: number): number[] {
  for (let t = 0; t < 50; t++) {
    const w: number[] = [];
    for (let i = 0; i < n * n; i++) { w.push(Math.random() < 0.3 ? 1 : 0); }
    w[0] = 0; w[n * n - 1] = 0;
    if (reachable(w, n)) { return w; }
  }
  return new Array<number>(MAX_CELLS).fill(0);
}

@Component
export struct GRotatingMaze {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=7）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(7);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State walls: number[] = []; @State pos: number = 0; @State goal: number = 0;
  @State steps: number = 0; @State turns: number = 0; @State turnIn: number = TURN_EVERY;
  @State over: boolean = false; @State won: boolean = false; @State note: string = '';
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(7);
     this.reset(); }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.over) {
      return false;
    }
    if (this.over) {
      return true;
    }
    this.aiGo(0);
    return !this.over;
  }

  /** 提示：下一步往哪走 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const d: number = this.aiDir();
    if (d < 0) { return Hint.none('none'); }
    const dir: string = d === 0 ? TG('上') : (d === 1 ? TG('右') : (d === 2 ? TG('下') : TG('左')));
    return Hint.make([], TG2('往「{0}」走一步（每 2 步整盘转 90°，这条线照样通）', dir),
      TG2('Step {0} (the board turns every 2 steps; the route stays valid)', dir), t0);
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

  private reset(): void {
    this.walls = genWalls(this.diffTotal); this.pos = 0;
    this.goal = this.diffTotal * this.diffTotal - 1; this.steps = 0; this.turns = 0;
    this.turnIn = TURN_EVERY; this.over = false; this.won = false; this.done = false;
    this.note = TG('走到 🏁 出口；每走 2 步迷宫会转 90°'); this.startAt = Date.now();
  }
  /** 墙、人、出口一起顺时针转 90° */
  private spin(): void {
    const next: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { next[rotIdx(i, this.diffTotal)] = this.walls[i]; }
    this.walls = next; this.pos = rotIdx(this.pos, this.diffTotal);
    this.goal = rotIdx(this.goal, this.diffTotal); this.turns++;
  }
  /** d: 0 上 1 右 2 下 3 左（屏幕方向） */
  private step(d: number): void {
    if (this.over) { return; }
    const nr: number = Math.floor(this.pos / this.diffTotal) + DR[d]; const nc: number = this.pos % this.diffTotal + DC[d];
    if (nr < 0 || nr >= this.diffTotal || nc < 0 || nc >= this.diffTotal) { this.note = TG('撞到外框，换个方向 🧱'); return; }
    const nb: number = nr * this.diffTotal + nc;
    if (this.walls[nb] === 1) { this.note = TG('前面是墙 🧱'); return; }
    this.pos = nb; this.steps++;
    if (this.pos === this.goal) { this.note = TG('摸到出口 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    this.turnIn = this.turnIn - 1;
    if (this.turnIn <= 0) {
      this.turnIn = TURN_EVERY; this.spin(); this.note = TG2("🌀 迷宫转了！已走 {0} 步",Digits(String(this.steps), this.langCode));
    } else { this.note = TG2('再走 {0} 步就要转',Digits(String(this.turnIn), this.langCode)); }
    if (this.steps >= DMAX) { this.note = TG('步数用尽，困在里面 😵'); this.finish(false); }
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved;
    const raw: number = solved ? 80 + (DMAX - this.steps) * 2 : this.steps * 2 + this.turns * 3;
    const res: GameResult = { gameId: 'rotating_maze', solved: solved, score: raw, durationMs: Date.now() - this.startAt, levelReached: this.turns };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  private gap(): number {
    return Math.abs(Math.floor(this.goal / this.diffTotal) - Math.floor(this.pos / this.diffTotal)) + Math.abs(this.goal % this.diffTotal - this.pos % this.diffTotal);
  }

  /** AI 用：BFS 从脚下到出口，返回下一步方向（0 上 1 右 2 下 3 左；-1 = 无路） */
  private aiDir(): number {
    const n: number = this.diffTotal;
    const total: number = n * n;
    if (this.pos === this.goal) { return -1; }
    const prev: number[] = new Array<number>(total).fill(-2);
    const q: number[] = [this.pos];
    prev[this.pos] = -1;
    let head: number = 0;
    let found: boolean = false;
    while (head < q.length) {
      const cur: number = q[head];
      head = head + 1;
      if (cur === this.goal) { found = true; break; }
      const r: number = Math.floor(cur / n);
      const c: number = cur % n;
      for (let d = 0; d < 4; d++) {
        const nr: number = r + DR[d];
        const nc: number = c + DC[d];
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) { continue; }
        const nb: number = nr * n + nc;
        if (this.walls[nb] === 1 || prev[nb] !== -2) { continue; }
        prev[nb] = cur;
        q.push(nb);
      }
    }
    if (!found) { return -1; }
    let c2: number = this.goal;
    while (prev[c2] >= 0 && prev[c2] !== this.pos) { c2 = prev[c2]; }
    if (prev[c2] !== this.pos) { return -1; }
    const r0: number = Math.floor(this.pos / n);
    const k0: number = this.pos % n;
    const r1: number = Math.floor(c2 / n);
    const k1: number = c2 % n;
    for (let d = 0; d < 4; d++) {
      if (r0 + DR[d] === r1 && k0 + DC[d] === k1) { return d; }
    }
    return -1;
  }

  /** AI 用：朝出口走一步（整盘旋转是刚体变换，路线一直有效） */
  private aiGo(_d: number): void {
    const d: number = this.aiDir();
    if (d >= 0) { this.step(d); }
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.steps + '/' + DMAX)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('转体'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.turns), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('距离'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.gap()))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.xs }) {
        Text('🌀').accessibilityLevel('no').fontSize(FontSize.lg).rotate({ angle: this.turns * 90 })
          .animation({ duration: Motion.base, curve: Motion.snap() })
        Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')
      Column({ space: 2 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rowIdx(), (c: number) => { Stack() {
            Text(this.pos === (r * this.diffTotal + c) ? '🙂' : (this.goal === (r * this.diffTotal + c) ? '🏁' : '')).fontSize(FontSize.md)
            }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
            .backgroundColor(this.walls[(r * this.diffTotal + c)] === 1 ? (this.theme.isDark ? '#2A2A2A' : '#B9C2D0') : this.theme.surfaceAlt)
            .animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        Button(('←'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surface).borderRadius(Radius.sm).onClick(() => { Haptics.tap(); this.step((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step((3)); }); })
        Button(('↑'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surface).borderRadius(Radius.sm).onClick(() => { Haptics.tap(); this.step((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step((0)); }); })
        Button(('↓'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surface).borderRadius(Radius.sm).onClick(() => { Haptics.tap(); this.step((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step((2)); }); })
        Button(('→'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(42)).fontSize(FontSize.lg).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surface).borderRadius(Radius.sm).onClick(() => { Haptics.tap(); this.step((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step((1)); }); })
      }.width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
