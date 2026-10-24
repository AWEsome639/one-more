/** 数字金字塔 —— 下层相邻两数之和等于上层
 *  玩法：底层 4 个数已知，自下而上把金字塔填满（每格 4 选 1）
 *  胜负：6 格全填对 ⇒ 通关；错 3 次 ⇒ 失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const LIVES: number = 3; const CELLS: number = 10; const ORDER: number[] = [4, 5, 6, 7, 8, 9];
function shuffle(a: number[]): number[] {
  const out: number[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
function buildOpts(ans: number, mates: number[]): number[] {
  const cands: number[] = [ans + 1, ans - 1, ans + 2, ans - 2, ans + 10];
  for (let i = 0; i < mates.length; i++) { cands.push(mates[i]); }
  const out: number[] = [ans];
  for (let i = 0; i < cands.length && out.length < 4; i++) {
    const v: number = cands[i];
    if (v > 0 && v !== ans && out.indexOf(v) < 0) { out.push(v); }
  }
  let extra: number = 3;
  while (out.length < 4) {
    const v: number = ans + extra * 7;
    if (out.indexOf(v) < 0) { out.push(v); }
    extra++;
  }
  return out;
}
@Component
export struct GSumPyramid {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 LIVES=3
  @State private diffTotal: number = GameDiff.livesNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State private vals: number[] = []; @State private opts: number[] = []; @State private answer: number = 0;
  @State private cursor: number = 0; @State private wrong: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private pick: number = -1; @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false;
  private sol: number[] = []; private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(3);
     this.reset(); }
  private reset(): void {
    this.startAt = Date.now(); this.done = false; this.cursor = 0; this.wrong = 0; this.score = 0; this.over = false;
    this.won = false; const pyramid: number[] = [];
    for (let i = 0; i < 4; i++) { pyramid.push(2 + Math.floor(Math.random() * 8)); }
    pyramid[4] = pyramid[0] + pyramid[1]; pyramid[5] = pyramid[1] + pyramid[2]; pyramid[6] = pyramid[2] + pyramid[3];
    pyramid[7] = pyramid[4] + pyramid[5]; pyramid[8] = pyramid[5] + pyramid[6]; pyramid[9] = pyramid[7] + pyramid[8]; this.sol = pyramid;
    const shown: number[] = [];
    for (let i = 0; i < CELLS; i++) { shown.push(i < 4 ? pyramid[i] : -1); }
    this.vals = shown; this.msg = TG('从下往上填：每格 = 下面相邻两格之和'); this.ask();
  }
  private current(): number { return this.cursor < ORDER.length ? ORDER[this.cursor] : -1; }
  private ask(): void {
    const idx: number = this.current();
    if (idx < 0) { return; }
    const mates: number[] = [this.sol[idx] + 3, this.sol[idx] - 3]; this.answer = this.sol[idx];
    this.opts = shuffle(buildOpts(this.answer, mates)); this.pick = -1;
  }
  private choose(v: number): void {
    if (this.over || v === this.pick) { return; }
    this.pick = v; const idx: number = this.current();
    if (idx < 0) { return; }
    if (v === this.answer) {
      const next: number[] = this.vals.slice(); next[idx] = v; this.vals = next; this.cursor = this.cursor + 1;
      this.score = this.score + 20; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.cursor >= ORDER.length) {
        this.over = true; this.won = true; this.msg = TG2('🎉 金字塔封顶，顶峰 {0}！', String(this.sol[9])); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.msg = TG2("✅ 已填 {0}/{1} 格", String(this.cursor), String(ORDER.length)); this.ask();
    } else {
      this.wrong = this.wrong + 1; this.score = Math.max(0, this.score - 10); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.wrong >= this.diffTotal) {
        this.over = true; this.won = false; this.msg = TG2('😵 错 {0} 次，金字塔没搭起来',Digits(String(this.diffTotal), this.langCode)); this.finish(false);
        return;
      }
      this.msg = TG2('❌ {0} 不对，看看它下面那两格', String(v));
    }
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'sum_pyramid', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cursor };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  private rowBase(lvl: number): number {
    if (lvl === 0) { return 9; }
    if (lvl === 1) { return 7; }
    return lvl === 2 ? 4 : 0;
  }
  private rowCells(lvl: number): number[] {
    const base: number = this.rowBase(lvl); const out: number[] = [];
    for (let i = 0; i <= lvl; i++) { out.push(base + i); }
    return out;
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.cursor) + '/' + String(ORDER.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.wrong) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('🔺 数字金字塔')).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        ForEach([0, 1, 2, 3], (lvl: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowCells(lvl), (idx: number) => {
              Stack() {
              Text(this.vals[(idx)] < 0 ? '?' : String(this.vals[(idx)])).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
              .fontColor(this.vals[(idx)] < 0
              ? ((idx) === this.current() ? Palette.lime : this.theme.inkFaint)
              : this.theme.ink)
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.vals[(idx)] < 0 ? this.theme.surfaceAlt : this.theme.surface)
              .borderRadius(Radius.sm).border({ width: (idx) === this.current() ? 2 : 0, color: Palette.lime })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (idx: number) => 'c' + idx + '_' + this.vals[idx] + (idx === this.current() ? 'a' : ''))
          }.width(String((lvl + 1) * 25) + '%')
        }, (lvl: number) => 'r' + lvl)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Button(this.opts.length > (i) ? String(this.opts[(i)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg)
          .fontColor(this.opts.length > (i) && this.opts[(i)] === this.pick ? '#FFFFFF' : this.theme.ink)
          .backgroundColor(this.opts.length > (i) && this.opts[(i)] === this.pick
          ? (this.opts[(i)] === this.answer ? Palette.emerald : Palette.rose)
          : this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tap();
          if (this.opts.length > (i)) { this.choose(this.opts[(i)]); }
          })
        }, (i: number) => 'o' + i)
      }.width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      Text(TG('提示：相邻两格之和往上搬，一层层来')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
