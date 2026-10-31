/**
 * 镜像迷宫（id: mirror_maze）—— 屏幕是镜中的世界：按「左」其实往右走 🌀
 * 胜负：走到 🏁 通关；步数耗尽 ⇒ 失败。进度：步数 / 剩余 / 最短路径
 * 出题：随机摆墙 + BFS 保证一定连通（最短路径同时作为步数上限）
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 8×8 = 64 格，
//   而数组原来按 CELLS = 36 开 ⇒【困难档必越界】✗）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N;
const WALL_P: number = 0.26;
const PERFECT: number = 11;

interface Board {
  wall: boolean[];
  goal: number;
  start: number;
}

/** 最短路径：起点到终点；到不了返回 -1 */
// ★★ 2026-10-13 修复（困难档 ×1.3 ⇒ 棋盘更大，原来只处理前 36 格）
function bfs(wall: boolean[], goalIdx: number, startIdx: number, n: number): number {
  const dist: number[] = new Array<number>(MAX_CELLS).fill(-1);
  dist[goalIdx] = 0;
  const q: number[] = [goalIdx];
  let head: number = 0;
  const dx: number[] = [0, 1, 0, -1];
  const dy: number[] = [-1, 0, 1, 0];
  while (head < q.length) {
    const cur: number = q[head];
    head++;
    const cx: number = cur % n;
    const cy: number = Math.floor(cur / n);
    for (let d = 0; d < 4; d++) {
      const nx: number = cx + dx[d];
      const ny: number = cy + dy[d];
      if (nx < 0 || nx >= n || ny < 0 || ny >= n) {
        continue;
      }
      const ni: number = ny * n + nx;
      if (wall[ni] || dist[ni] >= 0) {
        continue;
      }
      dist[ni] = dist[cur] + 1;
      q.push(ni);
    }
  }
  return dist[startIdx];
}

function makeBoard(n: number): Board {
  let best: Board | null = null;
  for (let attempt = 0; attempt < 60; attempt++) {
    const wall: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
    for (let i = 0; i < n * n; i++) {
      wall[i] = Math.random() < WALL_P;
    }
    const start: number = 0;
    const goal: number = n * n - 1;
    wall[start] = false;
    wall[goal] = false;
    const d: number = bfs(wall, goal, start, n);
    if (d >= 6 && d <= 14) {
      const ok: Board = { wall: wall, goal: goal, start: start };
      return ok;
    }
    if (d > 0 && best === null) {
      best = { wall: wall, goal: goal, start: start };
    }
  }
  if (best !== null) {
    return best;
  }
  const empty: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
  empty[7] = true;
  empty[8] = true;
  const out: Board = { wall: empty, goal: n * n - 1, start: 0 };
  return out;
}

@Component
export struct GMirrorMaze {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);
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
  @State private wall: boolean[] = []; @State private goal: number = CELLS - 1; @State private pos: number = 0;
  @State private steps: number = 0; @State private limit: number = 18; @State private short: number = 0;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMirrorMaze')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  private reset(): void {
    const b: Board = makeBoard(this.diffTotal);
    this.wall = b.wall;
    this.goal = b.goal;
    this.pos = b.start;
    this.short = bfs(b.wall, b.goal, b.start, this.diffTotal);
    if (this.short < 6) {
      this.short = 8;
    }
    this.limit = this.short + 7;
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.done = false;
    this.msg = TG('🌀 镜中世界：按「左」会往右走，按「右」往左走');
    this.startAt = Date.now();
  }
  /** 方向名（提示用） */
  private dirName(d: number): string {
    if (d === 0) {
      return '上';
    }
    if (d === 1) {
      return '右';
    }
    if (d === 2) {
      return '下';
    }
    return '左';
  }

  /** 代打：BFS 到终点，返回下一步该按的方向（-1 = 走不到） */
  private autoDir(): number {
    const n: number = this.diffTotal;
    const total: number = n * n;
    const dx: number[] = [0, 1, 0, -1];
    const dy: number[] = [-1, 0, 1, 0];
    const dist: number[] = new Array<number>(total).fill(-1);
    dist[this.goal] = 0;
    const q: number[] = [this.goal];
    let head: number = 0;
    while (head < q.length) {
      const cur: number = q[head];
      head++;
      const cx: number = cur % n;
      const cy: number = Math.floor(cur / n);
      for (let d = 0; d < 4; d++) {
        const nx: number = cx + dx[d];
        const ny: number = cy + dy[d];
        if (nx < 0 || nx >= n || ny < 0 || ny >= n) {
          continue;
        }
        const ni: number = ny * n + nx;
        if (this.wall[ni] || dist[ni] >= 0) {
          continue;
        }
        dist[ni] = dist[cur] + 1;
        q.push(ni);
      }
    }
    const px: number = this.pos % n;
    const py: number = Math.floor(this.pos / n);
    for (let d = 0; d < 4; d++) {
      const nx: number = px + dx[d];
      const ny: number = py + dy[d];
      if (nx < 0 || nx >= n || ny < 0 || ny >= n) {
        continue;
      }
      const ni: number = ny * n + nx;
      if (this.wall[ni]) {
        continue;
      }
      if (dist[ni] >= 0 && dist[ni] === dist[this.pos] - 1) {
        return d;
      }
    }
    return -1;
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
    if (this.over || this.done || this.autoDir() < 0) {
      return true;
    }
    this.tap(this.autoDir());
    return !this.over;
  }

  // 出口是 this.goal、墙是 this.wall ⇒ 用 BFS 报下一步该按哪个方向
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.done) {
      return Hint.none('none');
    }
    const d: number = this.autoDir();
    if (d < 0) {
      return Hint.none('none');
    }
    return Hint.make([], '按「' + this.dirName(d) + '」，能走到 🏁（还剩 ' + String(this.limit - this.steps) + ' 步）',
      'Press "' + this.dirName(d) + '" to reach the flag', t0);
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

  private tap(dir: number): void {
    if (this.over || this.done) { return; }
    const dx: number[] = [0, 1, 0, -1];
    const dy: number[] = [-1, 0, 1, 0];
    const cx: number = this.pos % this.diffTotal;
    const cy: number = Math.floor(this.pos / this.diffTotal);
    const nx: number = cx + dx[dir];
    const ny: number = cy + dy[dir];
    if (nx < 0 || nx >= this.diffTotal || ny < 0 || ny >= this.diffTotal) {
      this.msg = TG('🧱 撞到镜框了');
      return;
    }
    const ni: number = ny * this.diffTotal + nx;
    if (this.wall[ni]) {
      this.msg = TG('🧱 前面是墙');
      return;
    }
    this.pos = ni;
    this.steps = this.steps + 1;
    if (ni === this.goal) {
      this.done = true;
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 抵达 🏁 · 走了 {0} 步（最短 {1}）',Digits(String(this.steps), this.langCode),Digits(String(this.short), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.steps >= this.limit) {
      this.done = true;
      this.over = true;
      this.won = false;
      this.msg = TG('💤 步数用完了，没能走出镜子');
      this.finish(false);
      return;
    }
    this.msg = TG2("已走 {0} 步 · 还能走 {1} 步",Digits(String(this.steps), this.langCode), String(this.limit - this.steps));
  }
  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mirror_maze', solved: solved,
      score: solved ? Math.max(120, 700 - (this.steps - this.short) * 60) : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.steps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(this.limit))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, this.limit - this.steps)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('最短'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.short), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: 2 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.face((r * this.diffTotal + c)))
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '70%' })
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Text(('◀'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((3)); }); })
        Text(('▲'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((0)); }); })
        Text(('▼'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((2)); }); })
        Text(('▶'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((1)); }); })
      }
      .width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：走到 🏁 通关 · 步数上限 = 最短路径 + 7'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }


  private face(i: number): string {
    if (this.wall[i]) {
      return '';
    }
    if (i === this.pos) {
      return '🌀';
    }
    if (i === this.goal) {
      return '🏁';
    }
    return '';
  }
  private cellBg(i: number): string {
    if (this.wall[i]) {
      return this.theme.isDark ? '#2B2B33' : '#3F3F46';
    }
    if (i === this.pos) {
      return Palette.teal;
    }
    if (i === this.goal) {
      return Palette.emerald;
    }
    return this.theme.surface;
  }

}
