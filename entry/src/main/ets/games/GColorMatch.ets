/**
 * 颜色匹配 🎨
 * 规则：5×5 彩盘，点中的格子若与四邻有同色，就连同整片同色一起消掉；消完塌落、空列左移、顶部补新色。
 * 胜负：目标分达标 = 通关；步数用尽没达标 = 失败。
 */
import { A11y } from '../core/A11y';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5; const CELLS: number = N * N; const MAX: number = 22; const GOAL: number = 150;
const HUE: string[] = ['#EF4444', '#F59E0B', '#10B981', '#0EA5E9', '#8B5CF6', '#EC4899'];
  @Component
export struct GColorMatch {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：通关目标分（简单 100 / 普通 150 / 困难 220）
  private goalScore: number = GameDiff.pick(100, 150, 220);
 onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private colors: number[] = []; @State private score: number = 0;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private moves: number = 0; @State private over: boolean = false;
  /** ★ 2026-10-15 得分跳动：分数变化时脉冲一下（创作型动画） */
  @State private scorePulse: number = 1;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void {
   LanRace.noteStart(); this.reset();
   // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
   if (Hint.demoOnce('GColorMatch')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
 }
 onRestart(): void {
    this.goalScore = GameDiff.pick(100, 150, 220);
     this.reset(); }
 private reset(): void {
 const a: number[] = [];
 for (let i = 0; i < CELLS; i++) { a.push(Math.floor(Math.random() * HUE.length)); }
 this.colors = a; this.score = 0; this.moves = 0; this.over = false;
 this.won = false; this.note = TG('同色两格以上就能消 🎨'); this.startAt = Date.now();
 }
 /** 同色连通块（含起点） */
 private blob(i: number): number[] {
 const val: number = this.colors[i]; const out: number[] = [i]; const st: number[] = [i];
 while (st.length > 0) {
 const j: number = st.pop() as number; const r: number = Math.floor(j / N);
 const c: number = j - r * N; const nb: number[] = [];
 if (r > 0) { nb.push(j - N); }
 if (r < N - 1) { nb.push(j + N); }
 if (c > 0) { nb.push(j - 1); }
 if (c < N - 1) { nb.push(j + 1); }
 for (let t = 0; t < nb.length; t++) {
 if (this.colors[nb[t]] === val && out.indexOf(nb[t]) < 0) {
 out.push(nb[t]); st.push(nb[t]);
 }
 }
 }
 return out;
 }
 /** 掉落 + 空列左移 + 顶部补新色 */
 private settle(dead: number[]): number[] {
 const src: number[] = this.colors.slice();
 for (let t = 0; t < dead.length; t++) { src[dead[t]] = -1; }
 const out: number[] = new Array<number>(CELLS).fill(-1);
 for (let c = 0; c < N; c++) {
 let w: number = N - 1;
 for (let r = N - 1; r >= 0; r--) {
 if (src[r * N + c] >= 0) {
 out[w * N + c] = src[r * N + c]; w--;
 }
 }
 }
 let wc: number = 0;
 for (let c = 0; c < N; c++) {
 let empty: boolean = true;
 for (let r = 0; r < N; r++) { if (out[r * N + c] >= 0) { empty = false; } }
 if (empty) { continue; }
 if (wc !== c) {
 for (let r = 0; r < N; r++) {
 out[r * N + wc] = out[r * N + c]; out[r * N + c] = -1;
 }
 }
 wc++;
 }
 for (let i = 0; i < CELLS; i++) {
 if (out[i] < 0) { out[i] = Math.floor(Math.random() * HUE.length); }
 }
 return out;
 }
 private pick(i: number): void {
 if (this.over) { return; }
 const b: number[] = this.blob(i);
 if (b.length < 2) {
 this.note = TG('单块消不掉，找连着的同色 👀'); return;
 }
 this.score += b.length * 2; this.moves++; this.colors = this.settle(b);
    this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
 if (this.score >= this.goalScore) {
 this.note = TG2('达标 {0} 分 🎉',Digits(String(this.score), this.langCode)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
 }
 if (this.moves >= MAX) {
 this.note = TG2('步数用尽，{0} 分未达标 😵',Digits(String(this.score), this.langCode)); this.finish(false); return;
 }
 this.note = TG2("消了 {0} 格，+{1} 分", b.length, (b.length * 2));
 }
 private finish(solved: boolean): void {
 this.over = true; this.won = solved;
 LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
 this.onFinish({
 gameId: 'color_match', solved: solved, score: this.score,
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
 Text(TG('得分 ') + this.score + '/' + this.goalScore + '　步数 ' + this.moves + '/' + MAX
 + TG2('　进度 {0}%', Math.min(100, Math.floor(this.score * 100 / this.goalScore))))
        .fontSize(FontSize.sm)
        // ★ 得分跳动：分数一变就弹一下
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() })
        .fontColor(this.theme.inkSoft).width('100%')
 Column({ space: Space.xs }) {
 ForEach([0, 1, 2, 3, 4], (r: number) => {
 Row({ space: Space.xs }) {
 ForEach([0, 1, 2, 3, 4], (c: number) => {
 Stack() {
 // ★ 色盲辅助（项目 D ③）：颜色 + 字母双编码，看不见颜色也能玩
Text(this.colors[r * N + c] >= 0 ? A11y.glyph(this.colors[r * N + c]) : '')
            .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .textShadow({ radius: 2, color: '#000000B3', offsetX: 0, offsetY: 1 })
 }.layoutWeight(1).height(Cell.of(58)).backgroundColor(this.colors[r * N + c] >= 0
 ? HUE[this.colors[r * N + c]] : this.theme.surfaceAlt).borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(r * N + c); }); }).onClick(() => { Haptics.tick(); this.pick(r * N + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).width('100%').height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
 }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
 }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 找同色簇：blob(i).length >= 2 就点
  private findBlob(): number {
    for (let i = 0; i < this.colors.length; i++) {
      if (this.colors[i] >= 0 && this.blob(i).length >= 2) {
        return i;
      }
    }
    return -1;
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
    const i: number = this.findBlob();
    if (i < 0) {
      return false;
    }
    this.pick(i);
    return !this.over;
  }

  /** 提示：点哪一格能消一簇 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.findBlob();
    if (i < 0) {
      return Hint.none('none');
    }
    return Hint.make([i], TG2('点第 {0} 个', String(i + 1)),
      TG2('Tap cell {0}', String(i + 1)), t0);
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

}