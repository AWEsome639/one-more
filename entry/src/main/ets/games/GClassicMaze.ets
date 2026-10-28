/**
 * 经典迷宫 🌀
 * 规则：9×9 完美迷宫（深度优先凿墙生成，唯一通路）；滑动或方向键走球，撞墙不动。
 * 胜负：走到右下角出口 = 通关；步数超过上限 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 9; const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 12×12 = 144 格，原来只开 81）
const MAX_N: number = 12;
const MAX_CELLS: number = MAX_N * MAX_N; const DMAX: number = 4 * N;
/** 方向 0上 1右 2下 3左；墙位 1/2/4/8 */
const DR: number[] = [-1, 0, 1, 0]; const DC: number[] = [0, 1, 0, -1];
const WALL: number[] = [1, 2, 4, 8];
function genWalls(n: number): number[] {
 // ★★★ 2026-10-18 00:0x 真 BUG 修复（第八轮「穷尽式找不完美」）：
 //   原来用【常量 N=9】生成墙壁，但 step() 用 this.diffTotal（6/9/12）算行列
 //   ⇒ 简单档/困难档下墙壁错位、终点判定错（CELLS-1 永远是 80）
 //   ⇒ 修法：按【实际边长 n】生成，DFS 保证全连通（一定走得通）
 const nn: number = n > 1 ? n : 2;
 const w: number[] = new Array<number>(MAX_CELLS).fill(15);
 const seen: boolean[] = new Array<boolean>(MAX_CELLS).fill(false); const st: number[] = [0];
 seen[0] = true;
 while (st.length > 0) {
 const cur: number = st[st.length - 1]; const r: number = Math.floor(cur / nn);
 const c: number = cur - r * nn; const opts: number[] = [];
 for (let d = 0; d < 4; d++) {
 const nr: number = r + DR[d]; const nc: number = c + DC[d];
 if (nr >= 0 && nr < nn && nc >= 0 && nc < nn && !seen[nr * nn + nc]) { opts.push(d); }
 }
 if (opts.length === 0) { st.pop(); continue; }
 const d: number = opts[Math.floor(Math.random() * opts.length)];
 const nb: number = (r + DR[d]) * nn + (c + DC[d]);
 // ★ 位清零代替减法（幂等，重复拆也不会把掩码减成负数）
 w[cur] = w[cur] & (~WALL[d]);
 w[nb] = w[nb] & (~WALL[(d + 2) % 4]); seen[nb] = true; st.push(nb);
 }
 return w;
}
  @Component
export struct GClassicMaze {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=9；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5, 6, 7, 8]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(9);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private walls: number[] = []; @State private pos: number = 0;
  @State private steps: number = 0; @State private over: boolean = false;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   if (Hint.demoOnce('GClassicMaze')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
 }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(9);
     this.reset(); }
 /** ★ 本局步数上限（随棋盘边长走：4 倍格子边） */
 private dmax(): number { return this.diffTotal * 4; }
 /** ★ 出口格子下标（随棋盘边长走） */
 private goalIdx(): number { return this.diffTotal * this.diffTotal - 1; }
 private reset(): void {
 this.walls = genWalls(this.diffTotal); this.pos = 0; this.steps = 0; this.over = false;
 this.won = false; this.note = TG('滑动或按方向键，找出口 🌀'); this.startAt = Date.now();
 }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 迷宫没有"答案字段"—— 现算：在 this.walls 上做 BFS，每次只走一格
  /** BFS 结果：方向 × 10000 + 还要走几步；负数 = 走不到出口 */
  private nextMove(): number {
    const n: number = this.diffTotal;
    const goal: number = this.goalIdx();
    const from: number[] = new Array<number>(n * n).fill(-1);
    const q: number[] = [this.pos];
    from[this.pos] = this.pos;
    let head: number = 0;
    while (head < q.length && from[goal] < 0) {
      const cur: number = q[head];
      for (let d = 0; d < 4; d++) {
        if ((this.walls[cur] & WALL[d]) !== 0) {
          continue;
        }
        const r: number = Math.floor(cur / n) + DR[d];
        const c: number = cur % n + DC[d];
        if (r < 0 || r >= n || c < 0 || c >= n) {
          continue;
        }
        const nx: number = r * n + c;
        if (from[nx] >= 0) {
          continue;
        }
        from[nx] = cur;
        q.push(nx);
      }
      head = head + 1;
    }
    if (from[goal] < 0) {
      return -10000;
    }
    let hop: number = 0;
    let at: number = goal;
    while (hop < n * n && from[at] >= 0 && from[at] !== this.pos) {
      at = from[at];
      hop = hop + 1;
    }
    if (at === this.pos) {
      return -10000;
    }
    const dr: number = Math.floor(at / n) - Math.floor(this.pos / n);
    const dc: number = at % n - this.pos % n;
    for (let d2 = 0; d2 < 4; d2++) {
      if (DR[d2] === dr && DC[d2] === dc) {
        return d2 * 10000 + (hop + 1);
      }
    }
    return -10000;
  }

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
    const m: number = this.nextMove();
    if (m < 0) {
      return false;
    }
    this.step(Math.floor(m / 10000));
    return !this.over;
  }

  /** 提示：下一步往哪走 + 还要几步（迷宫只有"方向"是有意义的信息） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const m: number = this.nextMove();
    if (m < 0) {
      return Hint.none('none');
    }
    const names: string[] = [TG('上'), TG('右'), TG('下'), TG('左')];
    const ens: string[] = ['up', 'right', 'down', 'left'];
    const dir: number = Math.floor(m / 10000);
    const left: number = m % 10000;
    return Hint.make([], TG2('往{0}走 🌀 还要 {1} 步', names[dir], left),
      TG2('Go {0} — {1} steps left', ens[dir], left), t0);
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

 private step(d: number): void {
 if (this.over) { return; }
 const cur: number = this.pos;
 if ((this.walls[cur] & WALL[d]) !== 0) {
 this.note = TG('撞墙了，换个方向 🧱'); return;
 }
 const r: number = Math.floor(cur / this.diffTotal) + DR[d]; const c: number = cur % this.diffTotal + DC[d];
 if (r < 0 || r >= this.diffTotal || c < 0 || c >= this.diffTotal) {
 this.note = TG('这边是外墙 🧱'); return;
 }
 this.pos = r * this.diffTotal + c; this.steps++;
 if (this.pos === this.goalIdx()) {
 this.note = TG('出来了，出口到 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.steps >= this.dmax()) {
 this.note = TG('步数用尽，困在迷宫里 😵'); this.finish(false); return;
 }
 this.note = TG2("已走 {0} 步，还剩 {1} 步",Digits(String(this.steps), this.langCode), this.dmax() - this.steps);
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'classic_maze', solved: solved,
 score: solved ? 70 + Math.max(0, this.dmax() - this.steps * 3) : this.steps * 3,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.xs }) {
   HintBar({
     showHint: true,
     onHintTap: () => { this.askHint(); },
     onAutoTap: () => { this.askAuto(); },
     autoOn: this.autoId >= 0,
     demoOn: this.demoId >= 0
   })
 Text(TG2("步数 {0}/{1}　位置 {2}排",Digits(String(this.steps), this.langCode), this.dmax(), (Math.floor(this.pos / this.diffTotal) + 1))
 + (this.pos % this.diffTotal + 1) + TG2('列　出口 {0}排{1}列', this.diffTotal, this.diffTotal)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: 0 }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: 0 }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.pos === r * this.diffTotal + c ? '🔵' : (r * this.diffTotal + c === this.goalIdx() ? '🏁' : '')).fontSize(FontSize.sm)
 }.layoutWeight(1).height(Cell.of(40)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).borderWidth({
 top: (this.walls[r * this.diffTotal + c] & 1) !== 0 ? 2 : 0, right: (this.walls[r * this.diffTotal + c] & 2) !== 0 ? 2 : 0,
 bottom: (this.walls[r * this.diffTotal + c] & 4) !== 0 ? 2 : 0,
 left: (this.walls[r * this.diffTotal + c] & 8) !== 0 ? 2 : 0
 }).borderColor(Palette.wall).animation({ duration: Motion.fast, curve: Motion.snap() })
 // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
 .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
   .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r)
 }.width('100%').gesture(
 SwipeGesture({ fingers: 1, direction: SwipeDirection.All, speed: 20 }).onAction((e: GestureEvent) => {
 const a: number = e.angle;
 if (a >= -45 && a < 45) { this.step(1); }
 else if (a >= 45 && a < 135) { this.step(2); }
 else if (a >= -135 && a < -45) { this.step(0); }
 else { this.step(3); }
 })
)
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.xs }) {
 Button('↑')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step(0); }); }).onClick(() => { Haptics.tap(); this.step(0); })
 Button('↓')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step(2); }); }).onClick(() => { Haptics.tap(); this.step(2); })
 Button('←')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step(3); }); }).onClick(() => { Haptics.tap(); this.step(3); })
 Button('→')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step(1); }); }).onClick(() => { Haptics.tap(); this.step(1); })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}