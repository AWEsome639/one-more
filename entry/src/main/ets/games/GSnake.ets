/**
 * 贪吃蛇 —— 20×20 网格实时循环
 *
 * 玩法：每 200ms 走一格；滑动棋盘或点方向键转向；吃到食物变长
 * 结束：撞墙 / 咬到自己 ⇒ solved=false；吃满 GOAL 个食物 ⇒ solved=true
 *
 * ⚠️ 实时循环三条硬规矩（本文件都做到了）：
 *   ① setInterval 只在 startLoop() 里建，建之前先 clearInterval
 *   ② aboutToDisappear() 必须 clearInterval（退出页面不许还在跑）
 *   ③ onRestart()（宿主点「换一局」）先停旧循环再重开
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 20;               // 网格边长
const CELLS: number = N * N;
const TICK_MS: number = 200;        // 一拍走一格（按要求不再加快，省电）
const GOAL: number = 12;            // 吃满 12 个食物算通关
const SCORE_PER_FOOD: number = 10;
const BTN_H: number = 46;           // 操作按钮高
const PAD_H: number = 44;           // 方向键高
/** 滑动判定阈值（vp）：一次滑动至少这么多才认一个方向 */
const DRAG_MIN: number = 18;

const EMPTY: number = 0;
const BODY: number = 1;
const HEAD: number = 2;
const FOOD: number = 3;

/** 方向：0 上 / 1 右 / 2 下 / 3 左 */
const DX: number[] = [0, 1, 0, -1];
const DY: number[] = [-1, 0, 1, 0];

/** 0..n-1 下标数组（给 ForEach 用，只建一次） */
function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GSnake {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：蛇的速度按难度（简单 300ms 一拍更从容 / 普通 200 / 困难 140 更快）
  //   TICK_MS 是模块常量，加载时算死 ⇒ 必须用运行时的 this.tickMs
  //   ⚠️ 也顺带省电：简单档间隔更大 ⇒ 每秒更新次数更少
  private tickMs: number = GameDiff.timeNow(TICK_MS);
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State cells: number[] = [];
  @State score: number = 0;
  @State eaten: number = 0;
  @State len: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State paused: boolean = false;
  @State pressKey: string = '';
  /** ★ 待操作（起始缓冲）：true = 蛇静止，等玩家第一次滑动才开始 */
  @State private ready: boolean = false;
  /** ★ 2026-10-14 无尽模式：吃满 GOAL 后继续，看能吃多少 */
  @State private endless: boolean = false;

  /** 蛇身格子下标，头在 [0]；渲染只认 cells，所以它不用 @State */
  private snake: number[] = [];
  private food: number = -1;
  private dir: number = 1;          // 当前方向
  private nextDir: number = 1;      // 下一拍生效的方向（防止一拍内连转掉头）
  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);
  private cols: number[] = range(N);
  /** ★ 滑动起点（vp）：每认一次方向就重置，一次滑动可以连着转两次 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSnake')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.tickMs = GameDiff.timeNow(TICK_MS);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  // ── 循环管理 ──────────────────────────────────────────────
  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private startLoop(): void {
    this.stopLoop();
    this.timer = setInterval(() => {
      this.tick();
    }, this.tickMs);
  }

  // ── 局面 ─────────────────────────────────────────────────
  private reset(): void {
    this.stopLoop();
    const mid: number = Math.floor(N / 2);
    const body: number[] = [];
    body.push(mid * N + mid);         // 头
    body.push(mid * N + mid - 1);
    body.push(mid * N + mid - 2);
    this.snake = body;
    this.dir = 1;
    this.nextDir = 1;
    this.food = -1;
    this.score = 0;
    this.eaten = 0;
    this.len = body.length;
    this.over = false;
    this.won = false;
    this.paused = false;
    this.pressKey = '';
    this.finished = false;
    this.spawnFood();
    this.cells = this.paint();
    // ★★ 2026-10-13 真机体验修复（奥森：「一点击开始游戏就开始了，玩家根本反应不过来」）：
    //   原来 reset() 里【立刻】startLoop() ⇒ 蛇马上开始走，玩家还没看清棋盘就撞墙。
    //   ⇒ 改成「待操作」：蛇**静止不动**，等玩家第一次滑动/点击才真正开始。
    this.ready = true;
    this.startAt = Date.now();
    // 不启动循环；等 turn() 里首次操作时再 startLoop()
  }

  /** 把蛇身与食物画成一张"格子状态表" */
  private paint(): number[] {
    const c: number[] = new Array<number>(CELLS).fill(EMPTY);
    for (let i = 0; i < this.snake.length; i++) {
      c[this.snake[i]] = i === 0 ? HEAD : BODY;
    }
    if (this.food >= 0) {
      c[this.food] = FOOD;
    }
    return c;
  }

  /** 在空格里随机落一个食物；没空位说明蛇把棋盘填满了（food 留 -1） */
  private spawnFood(): void {
    const empty: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (this.snake.indexOf(i) < 0) {
        empty.push(i);
      }
    }
    if (empty.length === 0) {
      this.food = -1;
      return;
    }
    this.food = empty[Math.floor(Math.random() * empty.length)];
  }

  /** 一拍 */
  private tick(): void {
    if (this.over || this.won || this.paused) {
      return;
    }
    this.dir = this.nextDir;
    const head: number = this.snake[0];
    const hx: number = head % N;
    const hy: number = Math.floor(head / N);
    const nx: number = hx + DX[this.dir];
    const ny: number = hy + DY[this.dir];

    // 撞墙
    if (nx < 0 || nx >= N || ny < 0 || ny >= N) {
      this.die();
      return;
    }

    const nIdx: number = ny * N + nx;
    // 咬到自己：尾巴这一拍正好移开，所以最后那一格不算
    for (let i = 0; i < this.snake.length - 1; i++) {
      if (this.snake[i] === nIdx) {
        this.die();
        return;
      }
    }

    this.snake.unshift(nIdx);
    if (nIdx === this.food) {
      this.eaten++;
      this.score += SCORE_PER_FOOD;
      this.food = -1;
      this.spawnFood();
    } else {
      this.snake.pop();
    }
    this.len = this.snake.length;
    this.cells = this.paint();

    // ★★ 2026-10-14 无尽模式：吃满 GOAL 不再结束，改为【进入无尽】
    if (this.eaten >= GOAL && !this.endless) {
      this.endless = true;
    }
    if (this.food < 0) {
      this.win(true);             // 棋盘被蛇填满 ⇒ 也算通关
    }
  }

  private die(): void {
    this.over = true;
    this.cells = this.paint();
    this.stopLoop();
    this.finish(false);
  }

  /** 吃满目标（boardFull=false）/ 蛇填满整个棋盘（boardFull=true） */
  private win(boardFull: boolean): void {
    this.won = true;
    if (boardFull) {
      this.score += GOAL * SCORE_PER_FOOD;
    }
    this.stopLoop();
    this.finish(true);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'snake',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.snake.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private togglePause(): void {
    if (this.over || this.won) {
      return;
    }
    this.paused = !this.paused;
    if (this.paused) {
      this.stopLoop();
    } else {
      this.startLoop();
    }
  }

  /** 转向：禁 180° 掉头 */
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
    if (this.over || this.won) {
      return false;
    }
    if (this.paused) {
      return true;
    }
    const d: number = this.snDir();
    if (d < 0) {
      return false;
    }
    this.turn(d);
    return true;
  }

  /** 代打/提示共用：从 start 出发能走到的空格数（避开蛇身） */
  private snRoom(start: number): number {
    const seen: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let i = 0; i < this.snake.length; i++) {
      if (this.snake[i] !== start) {
        seen[this.snake[i]] = true;
      }
    }
    const q: number[] = [];
    q.push(start);
    seen[start] = true;
    let n: number = 0;
    let qi: number = 0;
    while (qi < q.length) {
      const cur: number = q[qi];
      qi = qi + 1;
      n = n + 1;
      const r: number = Math.floor(cur / N);
      const c: number = cur - r * N;
      for (let d = 0; d < 4; d++) {
        const rr: number = r + DY[d];
        const cc: number = c + DX[d];
        if (rr < 0 || rr >= N || cc < 0 || cc >= N) {
          continue;
        }
        const ni: number = rr * N + cc;
        if (seen[ni]) {
          continue;
        }
        seen[ni] = true;
        q.push(ni);
      }
    }
    return n;
  }

  /** 代打/提示共用：朝食物走，但只在「走完还有空间」的方向里挑（-1 = 全堵死） */
  private snDir(): number {
    const head: number = this.snake[0];
    const hx: number = head % N;
    const hy: number = Math.floor(head / N);
    const fx: number = this.food >= 0 ? this.food % N : hx;
    const fy: number = this.food >= 0 ? Math.floor(this.food / N) : hy;
    let best: number = -1;
    let bestS: number = -1e9;
    for (let d = 0; d < 4; d++) {
      if ((d + 2) % 4 === this.dir) {
        continue;
      }
      const nx: number = hx + DX[d];
      const ny: number = hy + DY[d];
      if (nx < 0 || nx >= N || ny < 0 || ny >= N) {
        continue;
      }
      if (this.snake.indexOf(ny * N + nx) >= 0) {
        continue;
      }
      const room: number = this.snRoom(ny * N + nx);
      const s: number = room * 100 - (Math.abs(nx - fx) + Math.abs(ny - fy));
      if (s > bestS) {
        bestS = s;
        best = d;
      }
    }
    return best;
  }

  /** 提示：报「下一步往哪走」+ 食物在哪个方向 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.won) {
      return Hint.none('none');
    }
    const d: number = this.snDir();
    if (d < 0) {
      return Hint.none(TG('四面都堵住了，只能等'));
    }
    const names: string[] = ['上', '右', '下', '左'];
    const head: number = this.snake[0];
    const hx: number = head % N;
    const hy: number = Math.floor(head / N);
    const fx: number = this.food >= 0 ? this.food % N : hx;
    const fy: number = this.food >= 0 ? Math.floor(this.food / N) : hy;
    let where: string = '';
    where = where + (fy < hy ? '上' : (fy > hy ? '下' : ''));
    where = where + (fx > hx ? '右' : (fx < hx ? '左' : ''));
    if (where.length === 0) { where = '就在头上'; }
    return Hint.make([],
      TG2('下一步往{0}走；食物在{1}边', names[d], where),
      TG2('Turn {0} next; the food is {1}', names[d], where), t0);
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

  private turn(d: number): void {
    if (this.over || this.won || this.paused) {
      return;
    }
    // ★ 首次操作 ⇒ 真正开始（起始缓冲结束）
    if (this.ready) {
      this.ready = false;
      this.startAt = Date.now();
      this.startLoop();
    }
    if ((d + 2) % 4 === this.dir) {
      return;
    }
    this.nextDir = d;
  }

  private statusText(): string {
    if (this.won) {
      return TG('🎉 达标通关！点「重开」再冲一次');
    }
    if (this.over) {
      return TG2('💥 撞了，得分 {0}，点「重开」再来',Digits(String(this.score), this.langCode));
    }
    if (this.paused) {
      return TG('⏸ 已暂停，点「继续」接着走');
    }
    // ★ 2026-10-14 无尽模式提示
    if (this.endless) {
      return TG2('♾️ 无尽模式　已吃 {0} 个　得分 {1}',Digits(String(this.eaten), this.langCode),Digits(String(this.score), this.langCode));
    }
    return TG2('滑动棋盘或点方向键转向；吃满 {0} 个食物算通关',Digits(String(GOAL), this.langCode));
  }

  private cellColor(v: number): string {
    if (v === HEAD) {
      return Palette.emerald;
    }
    if (v === BODY) {
      return Palette.teal;
    }
    if (v === FOOD) {
      return Palette.rose;
    }
    return this.theme.surfaceAlt;
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
      // 得分条 —— ⚠️ 只传「种类」：@Builder 按值传参不建立观察（见 stat() 注释）
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 棋盘
      // ★ P7 同类：原来这里是 Column 自己 `.layoutWeight(1).aspectRatio(1)` ——
      //   同一个节点上 layoutWeight 会先把**高度**定成"游戏区剩余高度"（≈790vp），
      //   aspectRatio 再据此反推宽度 ⇒ 棋盘是个比屏幕还宽一倍多的巨块
      //   （左右各出屏 ~210vp）：格子和边界都跑到屏幕外，这正是 P2/P7 那一类。
      //   ⇒ 改成显式 width('100%') 宽度驱动（和 G2048 棋盘同款），外层只负责占位与居中。
      Column() {
        Column() {
          ForEach(this.rows, (r: number) => {
            Row() {
              ForEach(this.cols, (c: number) => {
                this.cellView(r * N + c)
              }, (c: number) => 'c' + c)
            }
            .width('100%')
            .layoutWeight(1)
          }, (r: number) => 'r' + r)
        }
        .width('100%')
        .aspectRatio(1)
        // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
        //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
        .constraintSize({ maxHeight: '70%' })
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        .gesture(
          // ★ P9：滑动改口径 —— 用 PanGesture 的 offsetX/offsetY（vp）判方向，
          //   不再用 SwipeGesture 的 e.angle：① 慢拖也能认；② 方向不依赖 angle 的正负约定，
          //   不会出现"往上滑结果往下走"。
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 6 })
            .onActionStart(() => {
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
                this.turn(dx > 0 ? 1 : 3);
              } else {
                this.turn(dy > 0 ? 2 : 0);
              }
            })
            .onActionEnd(() => {
              this.dragX = 0;
              this.dragY = 0;
            })
        )
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 方向键
      Row({ space: Space.sm }) {
        this.dirBtn('←', 3, 'l')
        this.dirBtn('↑', 0, 'u')
        this.dirBtn('↓', 2, 'd')
        this.dirBtn('→', 1, 'r')
      }
      .width('100%')

      // 暂停 / 重开
      Row({ space: Space.md }) {
        Button(this.paused ? '继续' : TG('暂停'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.paused ? Palette.emerald : Palette.sky)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over && !this.won)
          .onClick(() => {
            Haptics.tap();
            this.togglePause();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.togglePause(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(this.statusText())
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? Palette.rose : this.theme.inkFaint)
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
   * 顶部小格：kind 0=得分 1=长度 2=进度
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值的话这三个数
   *    一局都不会动（P6/P8/P17 同族）。读取必须落在闭包内。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('得分') : (kind === 1 ? TG('长度') : TG('进度')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.score)
        : (kind === 1 ? String(this.len) : this.eaten + '/' + GOAL))
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
  cellView(i: number) {
    Row()
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.cellColor(this.cells.length > i ? this.cells[i] : EMPTY))
      .borderRadius(Radius.xs)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  dirBtn(label: string, d: number, key: string) {
    Row() {
      Text(label)
        .fontSize(FontSize.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(PAD_H)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scale({
      x: this.pressKey === key ? Motion.pressScale : 1,
      y: this.pressKey === key ? Motion.pressScale : 1
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressKey = key;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressKey = '';
      }
    })
    .onClick(() => {
      Haptics.tick();
      this.turn(d);
    })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.turn(d); }); })
  }
}
