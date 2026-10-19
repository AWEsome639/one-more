/** 文氏图 —— 集合运算
 *  玩法：给出集合 A、B 与一个数字，判断它落在哪个区域（只在 A / 只在 B / 都在 / 都不在）
 *  胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 8; const PASS: number = 6; const NEXT_MS: number = 850; const UNIVERSE: number = 12;
const REGION: string[] = ['只在 A', '只在 B', 'A、B 都有', '都不在'];
function sample(k: number, hi: number): number[] {
  const pool: number[] = [];
  for (let i = 1; i <= hi; i++) { pool.push(i); }
  const out: number[] = [];
  for (let i = 0; i < k; i++) {
    const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1);
  }
  for (let i = 1; i < out.length; i++) {
    const cur: number = out[i]; let j: number = i - 1;
    while (j >= 0 && out[j] > cur) { out[j + 1] = out[j]; j--; }
    out[j + 1] = cur;
  }
  return out;
}
function setText(name: string, arr: number[]): string {
  return name + ' = { ' + arr.join(', ') + ' }';
}
@Component
export struct GSetTheoryVenn {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=8
  @State private diffTotal: number = GameDiff.sizeNow(8);
  onFinish: (r: GameResult) => void = () => {};
  @State private setA: number[] = []; @State private setB: number[] = []; @State private probe: number = 1;
  @State private round: number = 1; @State private right: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private pick: number = -1; @State private answered: boolean = false; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.right = 0; this.score = 0; this.over = false;
    this.won = false; this.ask(); this.msg = TG('看这个数字落在哪个区域');
  }
  private ask(): void {
    this.setA = sample(4, UNIVERSE); this.setB = sample(4, UNIVERSE);
    this.probe = 1 + Math.floor(Math.random() * UNIVERSE); this.pick = -1; this.answered = false;
  }
  /** 0 只在 A ／ 1 只在 B ／ 2 都在 ／ 3 都不在 */
  private solution(): number {
    const a: number[] = this.setA; const b: number[] = this.setB; const n: number = this.probe;
    const inA: boolean = a.indexOf(n) >= 0; const inB: boolean = b.indexOf(n) >= 0;
    if (inA && inB) { return 2; }
    if (inA) { return 0; }
    if (inB) { return 1; }
    return 3;
  }
  private submit(k: number): void {
    if (this.answered || this.over) { return; }
    this.answered = true; this.pick = k; const ans: number = this.solution();
    if (k === ans) {
      this.right = this.right + 1; this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ {0} 确实「{1}」', String(this.probe), REGION[ans]);
    } else {
      this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ {0} 应该是「{1}」', String(this.probe), REGION[ans]); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1; this.next();
    }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG('看这个数字落在哪个区域');
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'set_theory_venn', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }



  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(PASS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(TG2('🔵 A ∪ 🔴 B，问 {0} 在哪', String(this.probe))).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
        Row({ space: Space.xs }) {
          Column({ space: 2 }) {
          Text(('🔵 A')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((String(this.setA.length) + TG(' 个'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.sky)).borderRadius(Radius.lg).shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(('🟣 A∩B')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((TG('重叠区'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.violet)).borderRadius(Radius.lg).shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(('🔴 B')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((String(this.setB.length) + TG(' 个'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.rose)).borderRadius(Radius.lg).shadow(Shadow.card)
        }.width('100%')
        Text(setText('A', this.setA)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        Text(setText('B', this.setB)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(REGION[(0)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (0)
        ? ((0) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((0));
        })
        Button(REGION[(1)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (1)
        ? ((1) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((1));
        })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(REGION[(2)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (2)
        ? ((2) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((2));
        })
        Button(REGION[(3)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (3)
        ? ((3) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((3));
        })
      }.width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      Text(TG('提示：先看这个数在不在 A 里，再看在不在 B 里')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
