/**
 * 模路径 —— 按模数走格
 *
 * 玩法：5×5 格子里有一条隐形的路，起点已给出；每次只能走到上下左右相邻、
 *       且数值恰好 +1（满 8 归 0）的格子，把整条路走出来。
 * 胜负：走满 6 格 ⇒ 通关；踩错 3 次 ⇒ 失败。
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

const GRID: number = 5;
const PATH_LEN: number = 6;
const MOD: number = 8;
const LIVES: number = 3;

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GModuloPath {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = [];
  @State private trail: number[] = [];
  @State private pos: number = -1;
  @State private startVal: number = 0;
  @State private step: number = 0;
  @State private err: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private cellsIdx: number[] = [];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    const a: number[] = [];
    for (let i = 0; i < GRID * GRID; i++) {
      a.push(i);
    }
    this.cellsIdx = a;
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GModuloPath')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
    this.reset();
  }

  private reset(): void {
    const board: number[] = new Array<number>(GRID * GRID).fill(0);
    let path: number[] = [];
    for (let tries = 0; tries < 80 && path.length < PATH_LEN; tries++) {
      const seen: boolean[] = new Array<boolean>(GRID * GRID).fill(false);
      const walk: number[] = [randInt(0, GRID * GRID - 1)];
      seen[walk[0]] = true;
      while (walk.length < PATH_LEN) {
        const cur: number = walk[walk.length - 1];
        const r: number = Math.floor(cur / GRID);
        const c: number = cur % GRID;
        const nb: number[] = [];
        if (r > 0 && !seen[cur - GRID]) {
          nb.push(cur - GRID);
        }
        if (r < GRID - 1 && !seen[cur + GRID]) {
          nb.push(cur + GRID);
        }
        if (c > 0 && !seen[cur - 1]) {
          nb.push(cur - 1);
        }
        if (c < GRID - 1 && !seen[cur + 1]) {
          nb.push(cur + 1);
        }
        if (nb.length === 0) {
          break;
        }
        const nxt: number = nb[Math.floor(Math.random() * nb.length)];
        seen[nxt] = true;
        walk.push(nxt);
      }
      if (walk.length >= PATH_LEN) {
        path = walk.slice(0, PATH_LEN);
      }
    }
    if (path.length < PATH_LEN) {
      path = [0, 1, 2, 3, 4, 5];   // 兜底：第一行直线
    }
    const base: number = randInt(0, MOD - 1);
    for (let i = 0; i < path.length; i++) {
      board[path[i]] = (base + i) % MOD;
    }
    // 干扰格只用「路外余数」，保证每个数值唯一对应一格
    const spare: number[] = [];
    for (let r = 0; r < MOD; r++) {
      let used: boolean = false;
      for (let i = 0; i < path.length; i++) {
        if ((base + i) % MOD === r) {
          used = true;
        }
      }
      if (!used) {
        spare.push(r);
      }
    }
    for (let i = 0; i < board.length; i++) {
      if (path.indexOf(i) < 0) {
        const rr: number = spare.length > 0 ? spare[i % spare.length] : (base + 3) % MOD;
        board[i] = rr + MOD * randInt(0, 2);
      }
    }
    this.vals = board;
    this.startVal = base;
    this.trail = path.length > 0 ? [path[0]] : [];
    this.pos = path.length > 0 ? path[0] : -1;
    this.step = 0;
    this.err = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG2('从 {0} 出发，每次走到相邻且 +1（满 {1} 归 0）的格子', base,Digits(String(MOD), this.langCode));
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
    if (this.over || this.nextCell() < 0) {
      return true;
    }
    this.tap(this.nextCell());
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 下一格的「值」是确定的 ⇒ 在相邻格里找那个值（全盘唯一）
  /** 下一步该点的格子（找不到返回 -1） */
  private nextCell(): number {
    if (this.pos < 0) {
      return -1;
    }
    const want: number = (this.startVal + this.step + 1) % MOD;
    const r1: number = Math.floor(this.pos / GRID);
    const c1: number = this.pos % GRID;
    for (let i = 0; i < this.vals.length; i++) {
      if (this.vals[i] !== want) {
        continue;
      }
      const r2: number = Math.floor(i / GRID);
      const c2: number = i % GRID;
      if (Math.abs(r1 - r2) + Math.abs(c1 - c2) === 1) {
        return i;
      }
    }
    return -1;
  }

  /** 提示：报下一格在第几行第几列、值是几 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.nextCell();
    if (i < 0) {
      return Hint.none('none');
    }
    const want: number = (this.startVal + this.step + 1) % MOD;
    const r: number = Math.floor(i / GRID) + 1;
    const c: number = (i % GRID) + 1;
    return Hint.make([i],
      TG2('走第 {0} 行第 {1} 列 —— 值是 {2}', String(r), String(c), String(want)),
      TG2('Go to row {0}, column {1} — value {2}', String(r), String(c), String(want)), t0);
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

  private tap(i: number): void {
    if (this.over || this.pos < 0 || i === this.pos) {
      return;
    }
    const r1: number = Math.floor(this.pos / GRID);
    const c1: number = this.pos % GRID;
    const r2: number = Math.floor(i / GRID);
    const c2: number = i % GRID;
    const near: boolean = Math.abs(r1 - r2) + Math.abs(c1 - c2) === 1;
    const want: number = (this.startVal + this.step + 1) % MOD;
    const val: number = this.vals[i];
    if (near && val === want) {
      this.step = this.step + 1;
      this.pos = i;
      const t: number[] = this.trail.slice();
      t.push(i);
      this.trail = t;
      this.msg = TG2('✅ 走到 {0}', val);
      if (this.step >= PATH_LEN - 1) {
        this.msg = TG('🎉 整条模路径走通！');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.err = this.err + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.err >= this.diffTotal) {
      this.msg = TG2('❌ 踩错 {0} 次，路断了',Digits(String(this.diffTotal), this.langCode));
      this.finish(false);
      return;
    }
    this.msg = near ? TG2("❌ 这一格是 {0}，要的是 {1}", val, want) : '❌ 只能走上下左右相邻的格子';
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'modulo_path',
      solved: solved,
      score: solved ? Math.max(100, 800 - this.err * 200) : this.step * 100,
      durationMs: Date.now() - this.startAt,
      levelReached: this.step
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private trailRank(i: number): number {
    return this.trail.indexOf(i);
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
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.step) + '/' + (PATH_LEN - 1))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.err + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('下一格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String((this.startVal + this.step + 1) % MOD))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(String(this.vals[(r * GRID + c)])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.trailRank((r * GRID + c)) >= 0 ? '#FFFFFF' : this.theme.ink)
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.trailRank((r * GRID + c)) >= 0 ? Palette.amber
              : ((r * GRID + c) === this.pos ? '#33F59E0B' : this.theme.surface)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              Haptics.tick();
              this.tap((r * GRID + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * GRID + c)); }); })
            }, (c: number) => 'mc' + c)
          }.width('100%')
        }, (r: number) => 'mr' + r)
      }.width('100%').layoutWeight(1)

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%').animation({ duration: Motion.fast, curve: Motion.snap() })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.amber).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
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
