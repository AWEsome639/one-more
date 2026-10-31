/**
 * 黑白和（Kakurasu）⚫
 *
 * 规则：每格涂黑或留白。第 r 行左侧的数字 = 该行黑格所在**列号之和**；
 *       第 c 列上方的数字 = 该列黑格所在**行号之和**（列号/行号从 1 数起）。
 * 胜负：行、列全部对上 = 通关；步数用尽 = 失败。
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

const N: number = 5;
const MAX_MOVES: number = 150;
const LBL_W: number = 40;

@Component
export struct GKakurasuSums {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
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

  @State private black: boolean[] = [];
  @State private rowLab: number[] = [];
  @State private colLab: number[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKakurasuSums')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    let b: boolean[] = [];
    let ok: boolean = false;
    let guard: number = 0;
    while (!ok && guard < 40) {
      guard++;
      b = new Array<boolean>(N * N).fill(false);
      let blk: number = 0;
      for (let i = 0; i < N * N; i++) {
        if (Math.random() < 0.45) {
          b[i] = true;
          blk++;
        }
      }
      ok = blk >= 4 && blk <= N * N - 4;
    }
    const rowLab: number[] = new Array<number>(N).fill(0);
    const colLab: number[] = new Array<number>(N).fill(0);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        if (b[r * N + c]) {
          rowLab[r] += c + 1;
          colLab[c] += r + 1;
        }
      }
    }
    this.rowLab = rowLab;
    this.colLab = colLab;
    this.black = new Array<boolean>(N * N).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private rowSum(r: number): number {
    let s: number = 0;
    for (let c = 0; c < N; c++) {
      if (this.black[r * N + c]) {
        s += c + 1;
      }
    }
    return s;
  }

  private colSum(c: number): number {
    let s: number = 0;
    for (let r = 0; r < N; r++) {
      if (this.black[r * N + c]) {
        s += r + 1;
      }
    }
    return s;
  }

  private rowOk(r: number): boolean {
    return this.rowSum(r) === this.rowLab[r];
  }

  private colOk(c: number): boolean {
    return this.colSum(c) === this.colLab[c];
  }

  private okLines(): number {
    let n: number = 0;
    for (let i = 0; i < N; i++) {
      if (this.rowOk(i)) {
        n++;
      }
      if (this.colOk(i)) {
        n++;
      }
    }
    return n;
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < N * N; i++) {
      if (this.black[i]) {
        n++;
      }
    }
    return n;
  }


  /**
   * ★ 2026-10-23 第二期：黑白和提示
   *
   * 规则：行线索 = 这一行**涂黑格的列号+1** 之和；
   *       列线索 = 这一列**涂黑格的行号+1** 之和。
   * ⇒ 逐行/逐列可判，沿用数织那套：
   *    枚举这一行所有涂黑组合（2^5 = 32），只留"和等于线索且与玩家标记不矛盾"的，
   *    再求交集 —— 所有候选里都一样的格，就是确定的。
   * 都给不出 ⇒ Hint.none()。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < N; k++) {
        const marks: number[] = [];
        for (let i = 0; i < N; i++) {
          marks.push(this.black[horiz === 1 ? k * N + i : i * N + k] ? 1 : 0);
        }
        const target: number = horiz === 1 ? this.rowLab[k] : this.colLab[k];
        let acc: number[] = [];
        let cnt: number = 0;
        const total: number = 1 << N;
        for (let mask = 0; mask < total; mask++) {
          let s2: number = 0;
          let ok: boolean = true;
          for (let i = 0; i < N; i++) {
            const isBlack: boolean = ((mask >> i) & 1) === 1;
            if (isBlack) {
              s2 += i + 1;                  // 权重 = 位置 + 1
            }
            if (marks[i] === 1 && !isBlack) {
              ok = false;
              break;
            }
          }
          if (!ok || s2 !== target) {
            continue;
          }
          if (cnt === 0) {
            acc = [];
            for (let i = 0; i < N; i++) {
              acc.push(((mask >> i) & 1) === 1 ? 1 : 0);
            }
          } else {
            for (let i = 0; i < N; i++) {
              const cur: number = ((mask >> i) & 1) === 1 ? 1 : 0;
              if (acc[i] !== cur) {
                acc[i] = -1;
              }
            }
          }
          cnt++;
        }
        if (cnt <= 1) {
          continue;
        }
        for (let i = 0; i < N; i++) {
          if (acc[i] < 0) {
            continue;
          }
          const idx: number = horiz === 1 ? k * N + i : i * N + k;
          const wantBlack: boolean = acc[i] === 1;
          if (this.black[idx] === wantBlack) {
            continue;
          }
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          if (wantBlack) {
            return Hint.make([idx], TG2('第 {0} 行第 {1} 列必须涂黑', String(r), String(c)),
              TG2('Row {0}, column {1} must be filled', String(r), String(c)), t0);
          }
          return Hint.make([idx], TG2('第 {0} 行第 {1} 列必须留白', String(r), String(c)),
            TG2('Row {0}, column {1} must stay empty', String(r), String(c)), t0);
        }
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步从线索推不出来，得先涂一个试试');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  /** 求解：逐行枚举 32 种涂法，用列线索双向剪枝 */
  private kakDfs(r: number, cols: number[], pick: number[], budget: number[]): boolean {
    if (budget[0] <= 0) {
      return false;
    }
    budget[0] = budget[0] - 1;
    if (r >= N) {
      for (let c = 0; c < N; c++) {
        if (cols[c] !== this.colLab[c]) {
          return false;
        }
      }
      return true;
    }
    const remain: number = (N * (N + 1) / 2) - ((r + 1) * (r + 2) / 2);
    const total: number = 1 << N;
    for (let mask = 0; mask < total; mask++) {
      let s: number = 0;
      for (let i = 0; i < N; i++) {
        if (((mask >> i) & 1) === 1) {
          s += i + 1;
        }
      }
      if (s !== this.rowLab[r]) {
        continue;
      }
      let ok: boolean = true;
      for (let c = 0; c < N; c++) {
        const add: number = ((mask >> c) & 1) === 1 ? r + 1 : 0;
        if (cols[c] + add > this.colLab[c]) {
          ok = false;
          break;
        }
        if (cols[c] + add + remain < this.colLab[c]) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        continue;
      }
      for (let c2 = 0; c2 < N; c2++) {
        pick[r * N + c2] = ((mask >> c2) & 1) === 1 ? 1 : 0;
      }
      const cols2: number[] = cols.slice();
      for (let c3 = 0; c3 < N; c3++) {
        if (((mask >> c3) & 1) === 1) {
          cols2[c3] = cols2[c3] + r + 1;
        }
      }
      if (this.kakDfs(r + 1, cols2, pick, budget)) {
        return true;
      }
    }
    return false;
  }

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
    const pick: number[] = new Array<number>(N * N).fill(-1);
    const cols: number[] = new Array<number>(N).fill(0);
    const budget: number[] = [20000];
    if (!this.kakDfs(0, cols, pick, budget)) {
      return false;
    }
    for (let i = 0; i < N * N; i++) {
      if (pick[i] >= 0 && (pick[i] === 1) !== this.black[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
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
    if (this.over) {
      return;
    }
    const b: boolean[] = this.black.slice();
    b[i] = !b[i];
    this.black = b;
    this.moves++;
    if (this.okLines() === 2 * N) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'kakurasu_sums',
      solved: solved,
      score: solved ? Math.max(200, 1400 - this.moves * 8) : this.okLines() * 90,
      durationMs: Date.now() - this.startAt,
      levelReached: this.okLines()
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount())))
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
        Text((TG('达标线'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.okLines()) + '/' + String(2 * N)))
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
      }
      .width('100%')

      Column({ space: 2 }) {
        Row({ space: 2 }) {
          Row() {
          }
          .width(LBL_W)
          ForEach([0, 1, 2, 3, 4], (c: number) => {
            Column({ space: 2 }) {
            Text(String((false) ? this.rowLab[(c)] : this.colLab[(c)]))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor((false) ? (this.rowOk((c)) ? Palette.emerald : this.theme.ink) :
            (this.colOk((c)) ? Palette.emerald : this.theme.ink))
            Text(String((false) ? this.rowSum((c)) : this.colSum((c))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(LBL_W)
            .height(LBL_W)
            .justifyContent(FlexAlign.Center)
          }, (c: number) => 'ksh' + c)
        }
        .width('100%')

        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: 2 }) {
            Column({ space: 2 }) {
            Text(String((true) ? this.rowLab[(r)] : this.colLab[(r)]))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor((true) ? (this.rowOk((r)) ? Palette.emerald : this.theme.ink) :
            (this.colOk((r)) ? Palette.emerald : this.theme.ink))
            Text(String((true) ? this.rowSum((r)) : this.colSum((r))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(LBL_W)
            .height(LBL_W)
            .justifyContent(FlexAlign.Center)
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.black[(r * N + c)] ? (this.theme.isDark ? '#0B0B0B' : '#1F2937') : this.theme.surface)
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'ks' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'ksr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点格子涂黑 / 擦白')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.hintMsg.length > 0 ? this.hintMsg : TG('上方数字 = 该列黑格的行号之和；左侧数字 = 该行黑格的列号之和（行/列号从 1 起）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  /** 行/列提示数：目标 + 当前（对上了变绿） */



}
