/**
 * 迷你数谜（Kakuro mini）—— 小盘数谜 ❓
 *
 * 规则：3×3 每格填 1~9；每行、每列的数字各不相同，且和等于旁边的提示数。
 * 胜负：六条线全部满足 = 通关；超过 40 步还没解出 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 3;
const MAX_MOVES: number = 40;

@Component
export struct GKakuroMini {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State private rowT: number[] = [0, 0, 0];
  @State private colT: number[] = [0, 0, 0];
  @State private sel: number = -1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  /** ★ P18：给"和都对上了但没通关"一个明确原因（否则玩家只会觉得"完成了没算通关"） */
  @State private hint: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GKakuroMini')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  // ── 出题：随机生成一张合法解，再取其行/列和作为提示 ──

  private canPut(g: number[], idx: number, v: number): boolean {
    const r: number = Math.floor(idx / N);
    const c: number = idx % N;
    for (let i = 0; i < N; i++) {
      if (g[r * N + i] === v || g[i * N + c] === v) {
        return false;
      }
    }
    return true;
  }

  private fill(g: number[], idx: number): boolean {
    if (idx === N * N) {
      return true;
    }
    const pool: number[] = [];
    for (let v = 1; v <= 9; v++) {
      if (this.canPut(g, idx, v)) {
        pool.push(v);
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    for (let i = 0; i < pool.length; i++) {
      g[idx] = pool[i];
      if (this.fill(g, idx + 1)) {
        return true;
      }
      g[idx] = 0;
    }
    return false;
  }

  private reset(): void {
    const g: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    this.fill(g, 0);
    const rt: number[] = [0, 0, 0];
    const ct: number[] = [0, 0, 0];
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        rt[r] += g[r * N + c];
        ct[c] += g[r * N + c];
      }
    }
    this.rowT = rt;
    this.colT = ct;
    this.vals = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    this.sel = 0;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.hint = '';
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private distinct3(a: number, b: number, c: number): boolean {
    return a !== 0 && b !== 0 && c !== 0 && a !== b && a !== c && b !== c;
  }

  private rowOk(r: number): boolean {
    const a: number = this.vals[r * N];
    const b: number = this.vals[r * N + 1];
    const c: number = this.vals[r * N + 2];
    return this.distinct3(a, b, c) && a + b + c === this.rowT[r];
  }

  private colOk(c: number): boolean {
    const a: number = this.vals[c];
    const b: number = this.vals[N + c];
    const d: number = this.vals[2 * N + c];
    return this.distinct3(a, b, d) && a + b + d === this.colT[c];
  }

  private rowCur(r: number): number {
    return this.vals[r * N] + this.vals[r * N + 1] + this.vals[r * N + 2];
  }

  private colCur(c: number): number {
    return this.vals[c] + this.vals[N + c] + this.vals[2 * N + c];
  }

  private linesDone(): number {
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

  /**
   * 有没有「和已经对上、但同一行/列出现重复数字」的线。
   *
   * ★ P18「完成了没算通关」：判胜条件本身是对的（六条线都要"数字各不相同 + 和等于提示"），
   *   但界面上只看得到"和"（rowCur/colCur 变绿），**"各不相同"这条规则完全没提示** ——
   *   玩家用 3+3+9=15 这种凑出正确的和，就会以为通关了，实际判胜不给过。
   *   ⇒ 不改判胜（规则没写错），而是把原因说出来。
   */
  private dupLine(): boolean {
    for (let i = 0; i < N; i++) {
      const a: number = this.vals[i * N];
      const b: number = this.vals[i * N + 1];
      const c: number = this.vals[i * N + 2];
      if (a !== 0 && b !== 0 && c !== 0 && a + b + c === this.rowT[i] && !this.distinct3(a, b, c)) {
        return true;
      }
      const d: number = this.vals[i];
      const e: number = this.vals[N + i];
      const g: number = this.vals[2 * N + i];
      if (d !== 0 && e !== 0 && g !== 0 && d + e + g === this.colT[i] && !this.distinct3(d, e, g)) {
        return true;
      }
    }
    return false;
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'kakuro_mini',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 15) : this.linesDone() * 80,
      durationMs: Date.now() - this.startAt,
      levelReached: this.linesDone()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    let all: boolean = true;
    for (let i = 0; i < N; i++) {
      if (!this.rowOk(i) || !this.colOk(i)) {
        all = false;
      }
    }
    if (all) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    this.hint = this.dupLine()
      ? '和是对上了，但同一行/列里有重复数字 —— 每条线必须各不相同'
      : '';
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  // ── 输入 ──

  private setVal(i: number, v: number): void {
    const n: number[] = this.vals.slice();
    n[i] = v;
    this.vals = n;
  }

  private tapCell(i: number): void {
    if (this.over) {
      return;
    }
    if (this.sel === i) {
      this.setVal(i, 0);
      this.moves++;
      this.check();
      return;
    }
    this.sel = i;
  }

  /** 和为 s 的三个互不相同数字（1..9）的全部排列，按 3 个一组摊平 */
  private triples(s: number): number[] {
    const out: number[] = [];
    for (let a = 1; a <= 9; a++) {
      for (let b = 1; b <= 9; b++) {
        if (b === a) {
          continue;
        }
        const c: number = s - a - b;
        if (c < 1 || c > 9 || c === a || c === b) {
          continue;
        }
        out.push(a);
        out.push(b);
        out.push(c);
      }
    }
    return out;
  }

  /** 解这一题（三行/三列各自互不相同且和等于提示数）⇒ 9 个数；解不出返回空数组 */
  private solveNow(): number[] {
    const r0: number[] = this.triples(this.rowT[0]);
    const r1: number[] = this.triples(this.rowT[1]);
    const r2: number[] = this.triples(this.rowT[2]);
    for (let i = 0; i < r0.length; i += 3) {
      const a: number = r0[i];
      const b: number = r0[i + 1];
      const c: number = r0[i + 2];
      for (let j = 0; j < r1.length; j += 3) {
        const d: number = r1[j];
        const e: number = r1[j + 1];
        const f: number = r1[j + 2];
        if (a === d || b === e || c === f) {
          continue;
        }
        for (let k = 0; k < r2.length; k += 3) {
          const g: number = r2[k];
          const h: number = r2[k + 1];
          const p: number = r2[k + 2];
          if (g === a || g === d || h === b || h === e || p === c || p === f) {
            continue;
          }
          if (a + d + g !== this.colT[0] || b + e + h !== this.colT[1] || c + f + p !== this.colT[2]) {
            continue;
          }
          return [a, b, c, d, e, f, g, h, p];
        }
      }
    }
    return [];
  }

  /** 代打：把选中格挪到第一个跟解不一样的格子，返回该填的数（0 = 不用填了） */
  private autoVal(): number {
    const sol: number[] = this.solveNow();
    if (sol.length < 9) {
      return 0;
    }
    let t: number = -1;
    for (let i = 0; i < 9; i++) {
      if (this.vals[i] !== sol[i]) {
        t = i;
        break;
      }
    }
    if (t < 0) {
      return 0;
    }
    this.sel = t;
    return sol[t];
  }
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
    if (this.over || this.autoVal() < 1) {
      return true;
    }
    this.put(this.autoVal());
    return !this.over;
  }

  // 出题时就是先随机填一张合法盘，再把行/列和当提示 ⇒ 反解出来就是答案
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.sel < 0) {
      return Hint.none('none');
    }
    const sol: number[] = this.solveNow();
    if (sol.length < 9) {
      return Hint.none('none');
    }
    const v: number = sol[this.sel];
    return Hint.make([this.sel],
      '这一格填 ' + String(v) + ' —— 整盘解是 ' + sol.slice(0, 3).join(' ') + ' / ' + sol.slice(3, 6).join(' ') + ' / ' + sol.slice(6, 9).join(' '),
      'Fill ' + String(v) + ' here; the full solution is ' + sol.join(' '), t0);
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

  private put(d: number): void {
    if (this.over || this.sel < 0) {
      return;
    }
    this.setVal(this.sel, d);
    this.moves++;
    let next: number = -1;
    for (let k = this.sel + 1; k < N * N; k++) {
      if (this.vals[k] === 0) {
        next = k;
        break;
      }
    }
    this.sel = next;
    this.check();
  }

  private backspace(): void {
    if (this.over || this.sel < 0) {
      return;
    }
    this.setVal(this.sel, 0);
    this.moves++;
    this.check();
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        // ⚠️ 只传「种类」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这两格永不刷新
        this.head(0)
        this.head(1)
      }
      .width('100%')

      // 4×4：左上角留空，第一行是列和，第一列是行和
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          this.corner()
          ForEach([0, 1, 2], (c: number) => {
            this.colSum(c)
          }, (c: number) => 'cs' + c)
        }
        .width('100%')

        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            this.rowSum(r)
            ForEach([0, 1, 2], (c: number) => {
              this.cellBox(r * N + c)
            }, (c: number) => 'cb' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'gr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.over ? (this.won ? '🎉 六条线全对，通关！' : TG('步数用尽，重开一题吧')) :
        (this.hint.length > 0 ? '⚠️ ' + this.hint :
          (this.sel < 0 ? '点一个格子开始填数' : '点下面数字填入选中格；再点格子可清空')))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      // 数字键盘
      Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4, 5], (d: number) => {
          this.keyBtn(d)
        }, (d: number) => 'k' + d)
      }
      .width('100%')
      Row({ space: Space.xs }) {
        ForEach([6, 7, 8, 9], (d: number) => {
          this.keyBtn(d)
        }, (d: number) => 'k' + d)
        this.delKey()
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.teal).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }

  /** 顶部小格：kind 0=步数 1=完成线 */
  @Builder
  head(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : '完成线')
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves) + '/' + String(this.diffTotal)
        : String(this.linesDone()) + '/6')
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1).padding(Space.sm)
    .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
  }

  @Builder
  corner() {
    Row()
      .layoutWeight(1)
      .aspectRatio(1)
      .backgroundColor('#00000000')
  }

  @Builder
  colSum(c: number) {
    Column({ space: 2 }) {
      Text('↓' + String(this.colT[c]))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(Palette.teal)
      Text(String(this.colCur(c)))
        .fontSize(FontSize.xxs)
        .fontColor(this.colOk(c) ? Palette.emerald : this.theme.inkFaint)
    }
    .layoutWeight(1).aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.colOk(c) ? '#1910B981' : '#00000000').animation({ duration: Motion.fast, curve: Motion.snap() })
    .borderRadius(Radius.xs)
  }

  @Builder
  rowSum(r: number) {
    Column({ space: 2 }) {
      Text(String(this.rowT[r]) + '→')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor(Palette.teal)
      Text(String(this.rowCur(r)))
        .fontSize(FontSize.xxs)
        .fontColor(this.rowOk(r) ? Palette.emerald : this.theme.inkFaint)
    }
    .layoutWeight(1).aspectRatio(1)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.rowOk(r) ? '#1910B981' : '#00000000')
    .borderRadius(Radius.xs)
  }

  @Builder
  cellBox(i: number) {
    Stack() {
      Text(this.vals[i] === 0 ? '' : String(this.vals[i]))
        .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.sel === i ? '#226366F1' : this.theme.surface)
    .borderRadius(Radius.sm)
    .border({ width: this.sel === i ? 2 : 1, color: this.sel === i ? Palette.primary : this.theme.line })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell(i); }); })
    .onClick(() => {
      Haptics.tick();
      this.tapCell(i);
    })
  }

  @Builder
  keyBtn(d: number) {
    Text(String(d))
      .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(44))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put(d); }); })
      .onClick(() => {
        Haptics.tick();
        this.put(d);
      })
  }

  @Builder
  delKey() {
    Text('⌫')
      .accessibilityText(TG('删除'))
      .fontSize(FontSize.xl)
      .fontColor(Palette.rose)
      .textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(44))
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.backspace(); }); })
      .onClick(() => {
        Haptics.tick();
        this.backspace();
      })
  }
}
