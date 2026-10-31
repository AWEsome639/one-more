/**
 * 补全盒子 📐
 * 规则：盘上零散格子中恰好有 12 格能拼成一个矩形边框；点亮空格补齐，点多了就算输。
 * 胜负：恰好点亮 12 格、且全部落在同一个矩形边框上 = 通关；超过 12 格 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
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

const SIDE: number = 4; const CELLS: number = SIDE * SIDE;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 6×6 = 36 格，
//   而数组原来按 CELLS = 16 开 ⇒【困难档必越界】✗）
const MAX_N: number = 6;
const MAX_CELLS: number = MAX_N * MAX_N; const PERIM: number = 12;

function rectCells(r1: number, c1: number, r2: number, c2: number): number[] {
 const out: number[] = [];
 for (let r = r1; r <= r2; r++) {
 for (let c = c1; c <= c2; c++) {
 if (r === r1 || r === r2 || c === c1 || c === c2) { out.push(r * SIDE + c); }
 }
 }
 return out;
}
  @Component
export struct GBoxCompletion {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（简单 3 / 普通 4 / 困难 5）
  //   ⚠️ 光改 this.diffTotal 不够 —— 渲染用的是写死的 [0,1,2,3]，必须同时改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(4);   // 4 = 原 SIDE
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a: number[] = [];
    for (let i = 0; i < n; i++) { a.push(i); }
    return a;
  }
 onFinish: (r: GameResult) => void = () => {};

  @State private cells: boolean[] = []; @State private lit: boolean[] = [];
  @State private moves: number = 0; @State private over: boolean = false;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   if (Hint.demoOnce('GBoxCompletion')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
 }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
 private reset(): void {
 let board: boolean[] | null = null;
 for (let round: number = 0; round < 60; round++) {
 const r1: number = Math.floor(Math.random() * 2); const c1: number = Math.floor(Math.random() * 2);
 const r2: number = r1 + 1 + Math.floor(Math.random() * (this.diffTotal - 1 - r1));
 const c2: number = c1 + 1 + Math.floor(Math.random() * (this.diffTotal - 1 - c1));
 const per: number[] = rectCells(r1, c1, r2, c2);
 const grid: boolean[] = new Array<boolean>(MAX_CELLS).fill(false); let holes: number = 0;
 for (let t = 0; t < per.length; t++) {
 if (Math.random() < 0.6) { grid[per[t]] = true; } else { holes++; }
 }
 if (holes < 3 || holes > 6) { continue; }
 board = grid; break;
 }
 if (board === null) { // 兜底：整圈边框挖 4 个洞
 const g: boolean[] = new Array<boolean>(MAX_CELLS).fill(true); g[1] = false;
 g[2] = false; g[7] = false; g[11] = false; board = g;
 }
 this.cells = board; this.lit = new Array<boolean>(MAX_CELLS).fill(false);
 this.moves = 0; this.over = false; this.won = false; this.note = TG('点亮空格，把边框补成 12 格 📐');
 this.startAt = Date.now();
 }
 private litCount(): number {
 let n: number = 0;
 for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { if (this.lit[i]) { n++; } }
 return n;
 }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  /** 代打/提示共用：边框上还空着的格（0 基下标） */
  private boxHoles(): number[] {
    const n: number = this.diffTotal;
    let r1: number = n;
    let c1: number = n;
    let r2: number = -1;
    let c2: number = -1;
    for (let i = 0; i < n * n; i++) {
      if (this.cells[i]) {
        const r: number = Math.floor(i / n);
        const c: number = i - r * n;
        if (r < r1) { r1 = r; }
        if (r > r2) { r2 = r; }
        if (c < c1) { c1 = c; }
        if (c > c2) { c2 = c; }
      }
    }
    const out: number[] = [];
    if (r2 < 0) {
      return out;
    }
    for (let r3 = r1; r3 <= r2; r3++) {
      for (let c3 = c1; c3 <= c2; c3++) {
        if (r3 !== r1 && r3 !== r2 && c3 !== c1 && c3 !== c2) {
          continue;
        }
        const i2: number = r3 * n + c3;
        if (!this.cells[i2] && !this.lit[i2]) {
          out.push(i2);
        }
      }
    }
    return out;
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    const holes: number[] = this.boxHoles();
    if (holes.length === 0) {
      return false;
    }
    this.pick(holes[0]);
    return !this.over;
  }

  /** 提示：报「还差哪一格」（行列是内容，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const holes: number[] = this.boxHoles();
    if (holes.length === 0) {
      return Hint.none('边框已经补齐了，别再点了');
    }
    const k: number = holes[0];
    const n: number = this.diffTotal;
    const r: number = Math.floor(k / n) + 1;
    const c: number = k - Math.floor(k / n) * n + 1;
    return Hint.make([k],
      TG2('点亮第 {0} 行第 {1} 列（边框还差 {2} 格）', String(r), String(c), String(holes.length)),
      TG2('Light row {0}, column {1} ({2} cells left on the border)', String(r), String(c), String(holes.length)), t0);
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
    Hint.toastResult(r, TG('这一步看不出要补哪格'));
  }
 private pick(i: number): void {
 if (this.over || this.cells[i]) { return; }
 const cur: boolean[] = this.lit.slice();
 if (cur[i]) {
 cur[i] = false; this.lit = cur; return;
 }
 cur[i] = true; this.lit = cur; this.moves++; const n: number = this.litCount();
 if (n > PERIM) {
 this.note = TG2('补过头了，多出 {0} 格 ❌', n - PERIM); this.finish(false); return;
 }
 if (n === PERIM) {
 let r1: number = this.diffTotal; let c1: number = this.diffTotal; let r2: number = -1; let c2: number = -1;
 for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
 if (this.cells[k] || this.lit[k]) {
 const r: number = Math.floor(k / this.diffTotal); const c: number = k - r * this.diffTotal;
 if (r < r1) { r1 = r; }
 if (r > r2) { r2 = r; }
 if (c < c1) { c1 = c; }
 if (c > c2) { c2 = c; }
 }
 }
 const per: number[] = rectCells(r1, c1, r2, c2); let bad: number = 0;
 for (let k = 0; k < this.diffTotal * this.diffTotal; k++) {
 if ((this.cells[k] || this.lit[k]) && per.indexOf(k) < 0) { bad++; }
 }
 if (bad === 0 && per.length === PERIM) {
 this.note = TG('边框合拢，完美盒子 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 this.note = TG('12 格了，但凑不成一个完整边框 🤔 撤几格再试'); return;
 }
 this.note = TG2('已补 {0}/{1} 格，还差 {2} 格', n, PERIM, PERIM - n);
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'box_completion', solved: solved,
 score: solved ? 80 + Math.max(0, 40 - this.moves * 4) : this.litCount() * 4,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
 build() {
 Column({ space: Space.sm }) {
   // ★ 演示条（共用组件；未演示时高度为 0，不占位）
   DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
   HintBar({
     showHint: true,
     onHintTap: () => { this.askHint(); },
     onAutoTap: () => { this.askAuto(); },
     autoOn: this.autoId >= 0,
     demoOn: false,
     disabled: this.demoId >= 0,
   })
 Text(TG2('已补 {0}/{1} 格　步数 {2}', this.litCount(), PERIM,Digits(String(this.moves), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 Text(this.cells[r * this.diffTotal + c] && this.lit[r * this.diffTotal + c] ? '✨'
 : (this.cells[r * this.diffTotal + c] ? '⬛'
 : (this.lit[r * this.diffTotal + c] ? '🟨' : ''))).fontSize(FontSize.xxl)
 }.layoutWeight(1).height(Cell.of(62)).backgroundColor(this.lit[r * this.diffTotal + c] ? Palette.amber : this.theme.surface).borderRadius(Radius.md).borderWidth(2).borderColor(this.cells[r * this.diffTotal + c] ? Palette.ink : this.theme.line).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(r * this.diffTotal + c); }); }).onClick(() => { Haptics.tick(); this.pick(r * this.diffTotal + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.sm }) {
 Button(TG('清空点亮'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (!this.over) { this.lit = new Array<boolean>(MAX_CELLS).fill(false); } }); }).onClick(() => {
 Haptics.tap();
 if (!this.over) { this.lit = new Array<boolean>(MAX_CELLS).fill(false); }
 })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}