/**
 * 色彩迷宫 🌀
 * 规则：6×6 彩砖盘，只能走进「与脚下同色」的四邻砖（每走一步就换一次颜色基准），起点随机。
 * 胜负：踩到终点 🏁 = 通关；步数超过上限 = 失败。
 */
import { A11y } from '../core/A11y';
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

const N: number = 6; const CELLS: number = N * N;
// ★★ 2026-10-13 修复（奥森："电脑水平太低" 挖出的尺寸越界）：
//   GameDiff.sizeScale 困难档 = ×1.3 ⇒ 棋盘会变成 8×8
//   而数组原来按 CELLS = 36 开 ⇒ 【困难档必越界】✗
//   ⇒ 按【困难档最大尺寸】开数组（多占几百个 int，可忽略）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N; const CMAX: number = 4; const DMAX: number = 26;
const HUE: string[] = ['#EF4444', '#10B981', '#0EA5E9', '#8B5CF6'];
interface ColorMap {
 color: number[]; start: number; goal: number;
}
/** 先随机走一条整条同色的通路，再给其余砖上色并封住终点 ⇒ 必定可解、且不能一步到 */
// ★★ 2026-10-13 修复（困难档 ×1.3 ⇒ 棋盘 8×8，原来只生成前 36 格 ⇒ 后 28 格是死格子）
function genMap(n: number): ColorMap {
 const color: number[] = new Array<number>(MAX_CELLS).fill(-1);
 let cur: number = Math.floor(Math.random() * n * n); const start: number = cur;
 color[cur] = 0; const len: number = 10 + Math.floor(Math.random() * 6);
 for (let s = 0; s < len; s++) {
 const r: number = Math.floor(cur / n); const c: number = cur - r * n; const opts: number[] = [];
 if (r > 0 && color[cur - n] < 0) { opts.push(cur - n); }
 if (r < n - 1 && color[cur + n] < 0) { opts.push(cur + n); }
 if (c > 0 && color[cur - 1] < 0) { opts.push(cur - 1); }
 if (c < n - 1 && color[cur + 1] < 0) { opts.push(cur + 1); }
 if (opts.length === 0) { break; }
 const nx: number = opts[Math.floor(Math.random() * opts.length)]; color[nx] = 0; cur = nx;
 }
 const goal: number = cur;
 for (let i = 0; i < n * n; i++) {
 if (color[i] >= 0) { continue; }
 const r: number = Math.floor(i / n); const c: number = i - r * n; const bad: number[] = [];
 if (r > 0) { bad.push(color[i - n]); }
 if (r < n - 1) { bad.push(color[i + n]); }
 if (c > 0) { bad.push(color[i - 1]); }
 if (c < n - 1) { bad.push(color[i + 1]); }
 let v: number = 1 + Math.floor(Math.random() * (CMAX - 1));
 for (let t = 0; t < 8 && bad.indexOf(v) >= 0; t++) {
 v = 1 + Math.floor(Math.random() * (CMAX - 1));
 }
 color[i] = v;
 }
 // 终点保持与通路同色：通路本身就是"这条路"，改写终点颜色会让它变成走不到的孤岛
 return { color: color, start: start, goal: goal };
}
  @Component
export struct GColorMazeNav {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);
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

  @State private color: number[] = []; @State private pos: number = 0;
  @State private goal: number = 0; @State private steps: number = 0;
  @State private over: boolean = false; @State private won: boolean = false;
  @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   if (Hint.demoOnce('GColorMazeNav')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
 }
 onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
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
    const t: number = this.aiNext();
    if (t < 0) { return Hint.none('none'); }
    const dr: number = Math.floor(t / this.diffTotal) - Math.floor(this.pos / this.diffTotal);
    const dc: number = t % this.diffTotal - this.pos % this.diffTotal;
    const dir: string = dr < 0 ? TG('上') : (dr > 0 ? TG('下') : (dc < 0 ? TG('左') : TG('右')));
    return Hint.make([t], TG2('往「{0}」走一步（只能走同色砖）', dir),
      TG2('Step {0} — only tiles of the same colour', dir), t0);
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
 const m: ColorMap = genMap(this.diffTotal); this.color = m.color; this.pos = m.start; this.goal = m.goal;
 this.steps = 0; this.over = false; this.won = false; this.note = TG('只能走同色砖，踩到 🏁 通关');
 this.startAt = Date.now();
 }
 private go(dr: number, dc: number): void {
 if (this.over) { return; }
 const r: number = Math.floor(this.pos / this.diffTotal) + dr; const c: number = this.pos % this.diffTotal + dc;
 if (r < 0 || r >= this.diffTotal || c < 0 || c >= this.diffTotal) {
 this.note = TG('越界了，回头 🧱'); return;
 }
 const t: number = r * this.diffTotal + c;
 if (this.color[t] !== this.color[this.pos]) {
 this.note = TG('那块颜色不同，走不过去 🚫'); return;
 }
 this.pos = t; this.steps++;
 if (t === this.goal) {
 this.note = TG('踩到终点，通关 🎉'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.steps >= DMAX) {
 this.note = TG('步数用尽，没摸到终点 😵'); this.finish(false); return;
 }
 this.note = TG2("已走 {0} 步，还剩 {1} 步",Digits(String(this.steps), this.langCode), (DMAX - this.steps));
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'color_maze_nav', solved: solved,
 score: solved ? 70 + Math.max(0, (DMAX - this.steps) * 3) : this.steps * 3,
 durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
 });
 }
  /** AI 用：只走同色砖，BFS 找一条到终点的路，返回要走的下一格（-1 = 走不到） */
  private aiNext(): number {
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
      const nb: number[] = [];
      if (r > 0) { nb.push(cur - n); }
      if (r < n - 1) { nb.push(cur + n); }
      if (c > 0) { nb.push(cur - 1); }
      if (c < n - 1) { nb.push(cur + 1); }
      for (let k = 0; k < nb.length; k++) {
        const t: number = nb[k];
        if (prev[t] !== -2 || this.color[t] !== this.color[cur]) { continue; }
        prev[t] = cur;
        q.push(t);
      }
    }
    if (!found) { return -1; }
    let c2: number = this.goal;
    while (prev[c2] >= 0 && prev[c2] !== this.pos) { c2 = prev[c2]; }
    return prev[c2] === this.pos ? c2 : -1;
  }

  /** AI 用：沿同色通路走一步 */
  private aiGo(_d: number): void {
    const t: number = this.aiNext();
    if (t < 0) { return; }
    const dr: number = Math.floor(t / this.diffTotal) - Math.floor(this.pos / this.diffTotal);
    const dc: number = t % this.diffTotal - this.pos % this.diffTotal;
    this.go(dr, dc);
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
 Text(TG2("步数 {0}/{1}　脚下 {2}",Digits(String(this.steps), this.langCode), DMAX, (this.color[this.pos] + 1))
 + TG2(' 号色　终点 {0} 号色', (this.color[this.goal] + 1))).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach(this.rowIdx(), (r: number) => {
 Row({ space: Space.xs }) {
 ForEach(this.rowIdx(), (c: number) => {
 Stack() {
 // ★ 色盲辅助（项目 D ③）：每格叠一个颜色字母 ——「同色才能走」是这个迷宫唯一的判据
 //   · 格子尺寸：困难档 8×8 ⇒ 单格实测约 36×44，字形取 9 号
 //     （不用 A11y.glyphSize(44)：它会给 15 号，在 36px 宽的格子里会和 🔵 / 🏁 打架）
 //   · 不挡内容：字母与 🔵/🏁 并排居中（合计约 27px / 36px），不重叠、不遮挡
 Row({ space: 2 }) {
 Text(A11y.glyph(this.color[r * this.diffTotal + c]))
   .fontSize(9).fontWeight(FontWeight.Bold)
   .fontColor(A11y.glyphInk(this.color[r * this.diffTotal + c]))
   .textShadow(A11y.glyphShadow())
 Text(this.pos === r * this.diffTotal + c ? '🔵' : (r * this.diffTotal + c === this.goal ? '🏁' : '')).fontSize(FontSize.md)
 }
 }.layoutWeight(1).height(Cell.of(44)).backgroundColor(HUE[this.color[r * this.diffTotal + c]]).borderRadius(Radius.sm).borderWidth(this.pos === r * this.diffTotal + c ? 3 : 0).borderColor('#FFFFFF').animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.note = TG('滑动或按方向键走同色砖 🌀'); }); }).onClick(() => { Haptics.tick(); this.note = TG('滑动或按方向键走同色砖 🌀'); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r)
 }.width('100%').gesture(
 SwipeGesture({ fingers: 1, direction: SwipeDirection.All, speed: 20 }).onAction((e: GestureEvent) => {
 const a: number = e.angle;
 if (a >= -45 && a < 45) { this.go(0, 1); }
 else if (a >= 45 && a < 135) { this.go(1, 0); }
 else if (a >= -135 && a < -45) { this.go(-1, 0); }
 else { this.go(0, -1); }
 })
)
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Row({ space: Space.xs }) {
 Button('↑')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.go(-1, 0); }); }).onClick(() => { Haptics.tap(); this.go(-1, 0); })
 Button('↓')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.go(1, 0); }); }).onClick(() => { Haptics.tap(); this.go(1, 0); })
 Button('←')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.go(0, -1); }); }).onClick(() => { Haptics.tap(); this.go(0, -1); })
 Button('→')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.go(0, 1); }); }).onClick(() => { Haptics.tap(); this.go(0, 1); })
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(40)).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%') }.width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
}