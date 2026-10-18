/**
 * 对称 —— 看 4×4 图案，判断它关于哪条轴对称（每题正确答案只有一条）
 * 胜负：8 题答对 ≥ 6 ⇒ 通关　｜　进度：题号 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4; const ROUNDS: number = 8; const PASS: number = 6; const FEED_MS: number = 900;
const AXES: string[] = ['左右对称', '上下对称', '主对角', '副对角'];

function at(r: number, c: number): number { return r * N + c; }

/** 按指定轴生成对称图案 */
function buildSym(axis: number): number[] {
  const g: number[] = new Array<number>(N * N).fill(0);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      const v: number = Math.random() < 0.45 ? 1 : 0;
      g[at(r, c)] = v;
      if (axis === 0) { g[at(r, N - 1 - c)] = v; } else if (axis === 1) { g[at(N - 1 - r, c)] = v; } else if (axis === 2) { g[at(c, r)] = v; } else { g[at(N - 1 - c, N - 1 - r)] = v; }
    }
  }
  return g;
}
/** 该图案共有几条对称轴（==1 才算题目清晰） */
function axisCount(g: number[]): number {
  let n: number = 0;
  for (let a = 0; a < 4; a++) {
    let ok: boolean = true;
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        let m: number = at(r, N - 1 - c);
        if (a === 1) { m = at(N - 1 - r, c); } else if (a === 2) { m = at(c, r); } else if (a === 3) { m = at(N - 1 - c, N - 1 - r); }
        if (g[m] !== g[at(r, c)]) { ok = false; }
      }
    }
    if (ok) { n = n + 1; }
  }
  return n;
}
@Component
export struct GSymmetry {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State grid: number[] = []; @State axis: number = 0; @State pick: number = -1; @State revealed: boolean = false;
  @State round: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private reset(): void {
    this.clearAll(); this.round = 1; this.hits = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.makeRound();
  }
  private makeRound(): void {
    let axis: number = Math.floor(Math.random() * 4);
    let g: number[] = buildSym(axis);
    let guard: number = 0;
    while (guard < 60 && axisCount(g) !== 1) {
      axis = Math.floor(Math.random() * 4); g = buildSym(axis); guard = guard + 1;
    }
    this.grid = g; this.axis = axis; this.pick = -1; this.revealed = false;
    this.msg = TG2("第 {0} / {1} 题：它关于哪条轴对称？",Digits(String(this.round), this.langCode), ROUNDS);
  }
  private answer(choice: number): void {
    if (this.over || this.revealed) { return; }
    this.revealed = true; this.pick = choice;
    if (choice === this.axis) {
      this.hits = this.hits + 1; this.score = this.score + 12; this.msg = TG2('✅ 正是{0}', AXES[this.axis]);
    } else {
      this.msg = TG2('❌ 正确答案是 {0}', AXES[this.axis]);
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }
  private next(): void {
    if (this.round >= ROUNDS) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.hits, ROUNDS);
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.makeRound();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'symmetry', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + ROUNDS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.grid[(r * this.diffTotal + c)] === 1 ? '▪' : '').fontSize(FontSize.md).fontColor('#FFFFFF')
              }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
              .backgroundColor(this.grid[(r * this.diffTotal + c)] === 1 ? (this.revealed && this.pick !== this.axis ? Palette.rose : Palette.teal) : this.theme.surfaceAlt)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + r + '_' + c)
          }.width('100%').layoutWeight(1)
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        Button(AXES[(0)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xs).fontColor('#FFFFFF')
        .backgroundColor(this.revealed && (0) === this.axis ? Palette.emerald : (this.revealed && (0) === this.pick ? Palette.rose : Palette.violet))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((0)); })
        Button(AXES[(1)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xs).fontColor('#FFFFFF')
        .backgroundColor(this.revealed && (1) === this.axis ? Palette.emerald : (this.revealed && (1) === this.pick ? Palette.rose : Palette.violet))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((1)); })
        Button(AXES[(2)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xs).fontColor('#FFFFFF')
        .backgroundColor(this.revealed && (2) === this.axis ? Palette.emerald : (this.revealed && (2) === this.pick ? Palette.rose : Palette.violet))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((2)); })
        Button(AXES[(3)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xs).fontColor('#FFFFFF')
        .backgroundColor(this.revealed && (3) === this.axis ? Palette.emerald : (this.revealed && (3) === this.pick ? Palette.rose : Palette.violet))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.revealed && !this.over)
        .onClick(() => { this.answer((3)); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
