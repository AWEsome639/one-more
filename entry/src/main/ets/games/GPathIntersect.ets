/**
 * 路径交叉（5×5 连线不交叉）—— 把 4 组同色端点两两连起来，线不许共格
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：4 组全部连通 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已接通组数 ／ 剩余步数 ／ 当前激活组
 *
 * 操作：点端点起线 → 点相邻空格延伸；点已有的线即撤销该组
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
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
const PAIRS: number = 4;
const STEP_BUDGET: number = 60;

/** 3 关端点：(行,列)×2 为一组，共 4 组，每关都保证有解 */
const LINK_LIB: number[][] = [
  // 第 1 关
  [
    2,4,0,0,
    3,0,1,2,
    3,3,4,0,
    4,2,3,4
  ],
  // 第 2 关
  [
    0,4,0,0,
    3,1,1,2,
    4,3,2,4,
    2,1,4,2
  ],
  // 第 3 关
  [
    0,0,4,0,
    1,1,3,2,
    0,3,2,4,
    1,3,0,1
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GPathIntersect {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PAIRS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(PAIRS);
  onFinish: (r: GameResult) => void = () => {};

  @State occ: number[] = [];       // 0 空，否则 = 组号
  @State ends: number[] = [];      // 0 非端点，否则 = 组号
  @State head: number[] = [];      // 每组当前线头（-1 = 未激活）
  @State done: number[] = [];      // 每组是否已连通
  @State active: number = -1;
  @State steps: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPathIntersect')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PAIRS);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * LINK_LIB.length);
    const src: number[] = LINK_LIB[k];
    const ends: number[] = new Array<number>(CELLS).fill(0);
    for (let p = 0; p < this.diffTotal; p++) {
      const a: number = src[p * 4] * N + src[p * 4 + 1];
      const b: number = src[p * 4 + 2] * N + src[p * 4 + 3];
      ends[a] = p + 1;
      ends[b] = p + 1;
    }
    this.ends = ends;
    this.occ = new Array<number>(CELLS).fill(0);
    this.head = [-1, -1, -1, -1];
    this.done = [0, 0, 0, 0];
    this.active = -1;
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private clearPair(p: number): void {
    const occ: number[] = this.occ.slice();
    for (let i = 0; i < CELLS; i++) {
      if (occ[i] === p + 1) {
        occ[i] = 0;
      }
    }
    this.occ = occ;
    const head: number[] = this.head.slice();
    head[p] = -1;
    this.head = head;
    const done: number[] = this.done.slice();
    done[p] = 0;
    this.done = done;
  }

  private adjacent(a: number, b: number): boolean {
    const dr: number = Math.abs(Math.floor(a / N) - Math.floor(b / N));
    const dc: number = Math.abs(a % N - b % N);
    return dr + dc === 1;
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
    if (this.active < 0) {
      let a: number = -1;
      let b: number = -1;
      let pth: number[] = [];
      for (let p = 0; p < this.diffTotal; p++) {
        if (this.done[p] === 1) {
          continue;
        }
        const es: number[] = this.piEnds(p);
        if (es[0] < 0 || es[1] < 0) {
          continue;
        }
        const cand: number[] = this.piPath(es[0], es[1], p);
        if (cand.length > 0) {
          a = es[0];
          b = es[1];
          pth = cand;
          break;
        }
      }
      if (pth.length === 0) {
        return false;
      }
      this.piTo = pth;
      this.piAt = 0;
      this.tap(a);
      return !this.over;
    }
    if (this.piAt >= this.piTo.length) {
      return false;
    }
    this.tap(this.piTo[this.piAt]);
    this.piAt = this.piAt + 1;
    return !this.over;
  }

  /** 计划要依次点的格（一次性算好） */
  private piTo: number[] = [];
  private piAt: number = 0;

  /** 从 from 连到 to 的最短路（避开别组的线与端点），返回要依次点的格（不含 from） */
  private piPath(from: number, to: number, p: number): number[] {
    const prev: number[] = new Array<number>(CELLS).fill(-2);
    const q: number[] = [];
    q.push(from);
    prev[from] = -1;
    let qi: number = 0;
    while (qi < q.length) {
      const cur: number = q[qi];
      qi = qi + 1;
      if (cur === to) {
        break;
      }
      const r: number = Math.floor(cur / N);
      const c: number = cur - r * N;
      for (let d = 0; d < 4; d++) {
        const rr: number = r + (d === 0 ? -1 : (d === 2 ? 1 : 0));
        const cc: number = c + (d === 1 ? 1 : (d === 3 ? -1 : 0));
        if (rr < 0 || rr >= N || cc < 0 || cc >= N) {
          continue;
        }
        const ni: number = rr * N + cc;
        if (prev[ni] !== -2) {
          continue;
        }
        const e: number = this.ends[ni];
        if (e > 0 && e !== p + 1) {
          continue;
        }
        if (ni !== to && this.occ[ni] > 0) {
          continue;
        }
        prev[ni] = cur;
        q.push(ni);
      }
    }
    if (prev[to] === -2) {
      return [];
    }
    const out: number[] = [];
    let cur2: number = to;
    while (cur2 !== from && cur2 >= 0) {
      out.unshift(cur2);
      cur2 = prev[cur2];
      if (cur2 === -2) {
        return [];
      }
    }
    return out;
  }

  /** 某一组的两个端点 */
  private piEnds(p: number): number[] {
    let a: number = -1;
    let b: number = -1;
    for (let i = 0; i < CELLS; i++) {
      if (this.ends[i] === p + 1) {
        if (a < 0) {
          a = i;
        } else if (b < 0) {
          b = i;
        }
      }
    }
    const out: number[] = [];
    out.push(a);
    out.push(b);
    return out;
  }

  /** 提示：已经起线了 ⇒ 报下一格；还没起 ⇒ 报某个能连通的组从哪端起 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.active >= 0) {
      const a: number = this.active;
      const h: number = this.head[a];
      const es: number[] = this.piEnds(a);
      const other: number = (es[0] === h) ? es[1] : es[0];
      if (h < 0 || other < 0) {
        return Hint.none('none');
      }
      const pth: number[] = this.piPath(h, other, a);
      if (pth.length === 0) {
        return Hint.none(TG('这一组被堵住了，先点已画的线撤掉它'));
      }
      const k: number = pth[0];
      const r: number = Math.floor(k / N) + 1;
      const c: number = k - Math.floor(k / N) * N + 1;
      return Hint.make([k],
        TG2('接着点第 {0} 行第 {1} 列', String(r), String(c)),
        TG2('Next tap row {0}, column {1}', String(r), String(c)), t0);
    }
    for (let p = 0; p < this.diffTotal; p++) {
      if (this.done[p] === 1) {
        continue;
      }
      const es2: number[] = this.piEnds(p);
      if (es2[0] < 0 || es2[1] < 0) {
        continue;
      }
      if (this.piPath(es2[0], es2[1], p).length === 0) {
        continue;
      }
      const r2: number = Math.floor(es2[0] / N) + 1;
      const c2: number = es2[0] - Math.floor(es2[0] / N) * N + 1;
      return Hint.make([es2[0]],
        TG2('先点第 {0} 行第 {1} 列的端点起线（第 {2} 组）', String(r2), String(c2), String(p + 1)),
        TG2('Start from the end at row {0}, column {1} (pair {2})', String(r2), String(c2), String(p + 1)), t0);
    }
    return Hint.none('none');
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
    if (this.over) {
      return;
    }
    const p: number = this.ends[i];
    if (p > 0) {
      this.clearPair(p - 1);            // 点端点 = 该组重画
      const occ: number[] = this.occ.slice();
      occ[i] = p;
      this.occ = occ;
      const head: number[] = this.head.slice();
      head[p - 1] = i;
      this.head = head;
      const done: number[] = this.done.slice();
      done[p - 1] = 0;
      this.done = done;
      this.active = p - 1;
      return;
    }
    const a: number = this.active;
    if (a < 0) {
      return;
    }
    const o: number = this.occ[i];
    if (o > 0) {                        // 点到线 ⇒ 撤销该组
      this.clearPair(o - 1);
      this.active = -1;
      return;
    }
    const h: number = this.head[a];
    if (h < 0 || !this.adjacent(h, i)) {
      return;
    }
    const other: number = this.ends[i];
    if (other > 0 && other !== a + 1) {
      return;                            // 别组的端点不能穿过
    }
    const occ: number[] = this.occ.slice();
    occ[i] = a + 1;
    this.occ = occ;
    const head: number[] = this.head.slice();
    head[a] = i;
    this.head = head;
    this.steps++;
    if (other === a + 1) {               // 接通了
      const done: number[] = this.done.slice();
      done[a] = 1;
      this.done = done;
      const h2: number[] = this.head.slice();
      h2[a] = -1;
      this.head = h2;
      this.active = -1;
      if (this.doneCount() === this.diffTotal) {
        this.over = true;
        this.won = true;
        this.score = Math.max(60, 420 - this.steps * 4);
        this.finish(true);
        return;
      }
    }
    if (this.steps >= STEP_BUDGET) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private doneCount(): number {
    let n: number = 0;
    for (let p = 0; p < this.diffTotal; p++) {
      if (this.done[p] === 1) {
        n++;
      }
    }
    return n;
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'path_intersect',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private pairColor(p: number): string {
    return Palette.wheel[(p - 1) % Palette.wheel.length];
  }

  private isHead(i: number): boolean {
    if (this.active < 0) {
      return false;
    }
    return this.head[this.active] === i;
  }

  private cellColor(i: number): string {
    const o: number = this.occ[i];
    if (o > 0) {
      return tintOf(this.pairColor(o), this.theme.isDark);
    }
    const e: number = this.ends[i];
    if (e > 0) {
      return tintOf(this.pairColor(e), this.theme.isDark);
    }
    return this.theme.surfaceAlt;
  }

  private markColor(i: number): string {
    const o: number = this.occ[i];
    if (o > 0) {
      return this.pairColor(o);
    }
    const e: number = this.ends[i];
    if (e > 0) {
      return this.pairColor(e);
    }
    return '#FFFFFF';
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
        Text((TG('已接通'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneCount()) + '/' + String(this.diffTotal)))
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
        Text((TG('已用步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(STEP_BUDGET)))
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
        Text((TG('当前颜色'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.active >= 0 ? String(this.active + 1) : '—'))
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
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(this.ends[(r * N + c)] > 0 ? '⬤' : (this.occ[(r * N + c)] > 0 ? '●' : ''))
              .fontSize(this.ends[(r * N + c)] > 0 ? FontSize.lg : FontSize.xs)
              .fontColor(this.markColor((r * N + c)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * N + c)))
              .borderRadius(Radius.sm)
              .border({
              width: this.isHead((r * N + c)) ? 2 : 1,
              color: this.isHead((r * N + c)) ? Palette.primary : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '四线齐通 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点端点起线，再点相邻格延伸；点线即撤销')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.amber)
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
