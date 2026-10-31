/** 矢印（Yajilin）—— 箭头提示黑格，其余白格须连成单回路（每格 2 个白邻格且整体连通）
 *  玩法：点白格涂黑；带箭头的线索格不可取消。过关判据：4 题全部成环
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const CELLS: number = N * N;
const ROUNDS: number = 4;

interface QClue { r: number; c: number; dr: number; dc: number; n: number }
interface QPuz { black: number[]; clues: QClue[] }

/** 已用穷举验证过「补全后白格恰好成单回路」的题库 */
const PUZZLES: QPuz[] = [
  { black: [0, 6, 9, 10], clues: [{ r: 1, c: 2, dr: 1, dc: 0, n: 1 }, { r: 2, c: 1, dr: 0, dc: 1, n: 1 }] },
  { black: [0, 6, 9, 15], clues: [{ r: 0, c: 0, dr: 0, dc: 1, n: 0 }, { r: 1, c: 2, dr: 0, dc: 1, n: 0 }] },
  { black: [3, 5, 9, 10], clues: [{ r: 1, c: 1, dr: 1, dc: 0, n: 1 }, { r: 2, c: 1, dr: 0, dc: 1, n: 1 }] },
  { black: [5, 6, 9, 10], clues: [{ r: 1, c: 1, dr: 0, dc: 1, n: 1 }, { r: 1, c: 2, dr: 0, dc: -1, n: 1 }] },
  { black: [0, 1, 2, 3, 9, 10], clues: [{ r: 0, c: 0, dr: 0, dc: 1, n: 3 }, { r: 0, c: 3, dr: 0, dc: -1, n: 3 }] },
  { black: [3, 5, 7, 9, 11, 15], clues: [{ r: 0, c: 3, dr: 1, dc: 0, n: 3 }, { r: 3, c: 3, dr: -1, dc: 0, n: 3 }] }
];

@Component
export struct GYajilin {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private fixed: boolean[] = [];
  @State private mine: boolean[] = [];
  @State private level: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private tip: string = TG('点白格涂黑，凑出单回路');

  private startAt: number = 0;
  private cur: QPuz = PUZZLES[0];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GYajilin')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.score = 0;
    this.level = 0;
    this.over = false;
    this.tip = TG('点白格涂黑，凑出单回路');
    this.load(0);
  }

  private load(lv: number): void {
    this.cur = PUZZLES[lv % PUZZLES.length];
    const lock: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let k = 0; k < this.cur.clues.length; k++) {
      const q: QClue = this.cur.clues[k];
      lock[q.r * N + q.c] = true;
    }
    this.fixed = lock;
    this.mine = new Array<boolean>(CELLS).fill(false);
  }

  private blackAt(i: number): boolean {
    return this.fixed[i] || this.mine[i];
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.blackAt(i)) { n++; }
    }
    return n;
  }

  private deg(i: number): number {
    const r: number = Math.floor(i / N);
    const c: number = i % N;
    let d: number = 0;
    if (r > 0 && !this.blackAt(i - N)) { d++; }
    if (r < N - 1 && !this.blackAt(i + N)) { d++; }
    if (c > 0 && !this.blackAt(i - 1)) { d++; }
    if (c < N - 1 && !this.blackAt(i + 1)) { d++; }
    return d;
  }

  private clueText(i: number): string {
    if (!this.fixed[i]) { return ''; }
    for (let k = 0; k < this.cur.clues.length; k++) {
      const q: QClue = this.cur.clues[k];
      if (q.r * N + q.c !== i) { continue; }
      let mark: string = '←';
      if (q.dr === 1) { mark = '↓'; } else if (q.dr === -1) { mark = '↑'; } else if (q.dc === 1) { mark = '→'; }
      return mark + String(q.n);
    }
    return '';
  }

  private cluesOk(): boolean {
    for (let k = 0; k < this.cur.clues.length; k++) {
      const q: QClue = this.cur.clues[k];
      let r: number = q.r + q.dr;
      let c: number = q.c + q.dc;
      let hit: number = 0;
      while (r >= 0 && r < N && c >= 0 && c < N) {
        if (this.blackAt(r * N + c)) { hit++; }
        r += q.dr;
        c += q.dc;
      }
      if (hit !== q.n) { return false; }
    }
    return true;
  }

  /** 白格每格度数 2 且全部连通 ⇒ 单回路 */
  private loopOk(): boolean {
    const kept: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (!this.blackAt(i)) { kept.push(i); }
    }
    if (kept.length < 4) { return false; }
    for (let k = 0; k < kept.length; k++) {
      if (this.deg(kept[k]) !== 2) { return false; }
    }
    const seen: boolean[] = new Array<boolean>(CELLS).fill(false);
    const stack: number[] = [kept[0]];
    seen[kept[0]] = true;
    let count: number = 1;
    while (stack.length > 0) {
      const i: number = stack.pop() as number;
      const r: number = Math.floor(i / N);
      const c: number = i % N;
      const cand: number[] = [];
      if (r > 0) { cand.push(i - N); }
      if (r < N - 1) { cand.push(i + N); }
      if (c > 0) { cand.push(i - 1); }
      if (c < N - 1) { cand.push(i + 1); }
      for (let j = 0; j < cand.length; j++) {
        const q: number = cand[j];
        if (!this.blackAt(q) && !seen[q]) { seen[q] = true; count++; stack.push(q); }
      }
    }
    return count === kept.length;
  }

  /** 代打/提示共用：本题答案里还没涂黑的格子（没有一个就 -1） */
  private autoCell(): number {
    for (let k = 0; k < this.cur.black.length; k++) {
      const i: number = this.cur.black[k];
      if (!this.blackAt(i)) {
        return i;
      }
    }
    return -1;
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
    if (this.over || this.autoCell() < 0) {
      return true;
    }
    this.tap(this.autoCell());
    return !this.over;
  }

  // 真值就在 this.cur.black（题库里每题的黑格答案；settle 判单回路）
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.autoCell();
    if (i < 0) {
      return Hint.none('none');
    }
    let left: number = 0;
    for (let k = 0; k < this.cur.black.length; k++) {
      if (!this.blackAt(this.cur.black[k])) {
        left++;
      }
    }
    return Hint.make([i],
      '第' + String(Math.floor(i / N) + 1) + '行第' + String(i % N + 1) + '列涂黑（本题还差 ' + String(left) + ' 格）',
      'Blacken row ' + String(Math.floor(i / N) + 1) + ', column ' + String(i % N + 1), t0);
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
    if (this.over || this.fixed[i]) { return; }
    const next: boolean[] = this.mine.slice();
    next[i] = !next[i];
    this.mine = next;
    this.settle();
  }

  private settle(): void {
    if (!this.loopOk() || !this.cluesOk()) {
      this.tip = this.cluesOk() ? '白格还不是单回路（每格要 2 个白邻格）' : '箭头计数还没满足';
      return;
    }
    this.score += 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = TG('全部通关 🎉');
      this.finish(true);
      return;
    }
    this.load(this.level);
    this.tip = TG2('✓ 第 {0} 题完成，继续', String(this.level));
  }

  private hint(): void {
    if (this.over) { return; }
    let target: number = -1;
    for (let k = 0; k < this.cur.black.length; k++) {
      const i: number = this.cur.black[k];
      if (target < 0 && !this.blackAt(i)) { target = i; }
    }
    if (target < 0) {
      this.tip = TG('没有可提示的格子了');
      return;
    }
    const next: boolean[] = this.mine.slice();
    next[target] = true;
    this.mine = next;
    this.score = Math.max(0, this.score - 5); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.settle();
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'yajilin', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
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
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.level) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text(this.blackAt((r * N + c)) ? (this.fixed[(r * N + c)] ? this.clueText((r * N + c)) : '■') : String(this.deg((r * N + c))))
              .fontSize(this.fixed[(r * N + c)] ? FontSize.xs : FontSize.lg).fontWeight(FontWeight.Bold)
              .fontColor(this.blackAt((r * N + c)) ? '#FFFFFF' : (this.deg((r * N + c)) === 2 ? Palette.emerald : this.theme.inkSoft))
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.blackAt((r * N + c)) ? (this.theme.isDark ? '#1E1E1E' : '#0F172A') : this.theme.surface)
              .borderRadius(Radius.sm).borderWidth(this.blackAt((r * N + c)) ? 0 : 2).borderColor(this.deg((r * N + c)) === 2 ? Palette.emerald : this.theme.line)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * N + c)); })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'y' + c)
          }.width('100%')
        }, (r: number) => 'x' + r)
      }.width('100%').aspectRatio(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.tip).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)

      Row({ space: Space.sm }) {
        Button(TG('提示 (-5)'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over).onClick(() => { Haptics.tap(); this.hint(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.hint(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.teal).borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
