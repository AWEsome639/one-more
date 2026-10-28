/**
 * 颜色匹配 🎨
 * 规则：5×5 彩盘，点中的格子若与四邻有同色，就连同整片同色一起消掉；消完塌落、空列左移、顶部补新色。
 * 胜负：目标分达标 = 通关；步数用尽没达标 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

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
  @State private colors: number[] = []; @State private score: number = 0;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private moves: number = 0; @State private over: boolean = false;
  /** ★ 2026-10-15 得分跳动：分数变化时脉冲一下（创作型动画） */
  @State private scorePulse: number = 1;
  @State private won: boolean = false; @State private note: string = '';

 private startAt: number = 0;

 aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
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
   HintBar({
     showHint: true,
     onHintTap: () => { this.askHint(); },
     onAutoTap: () => { this.askAuto(); },
     autoOn: this.autoId >= 0
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
 Text(this.colors[r * N + c] >= 0 ? '●' : '').fontSize(FontSize.md).fontColor('#FFFFFF')
 }.layoutWeight(1).height(Cell.of(58)).backgroundColor(this.colors[r * N + c] >= 0
 ? HUE[this.colors[r * N + c]] : this.theme.surfaceAlt).borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick(r * N + c); })
 }, (c: number) => 'c' + c) }.width('100%')
 }, (r: number) => 'r' + r) }.width('100%')
 Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
 Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).width('100%').height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
 }.width('100%').height('100%').justifyContent(FlexAlign.Start)
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