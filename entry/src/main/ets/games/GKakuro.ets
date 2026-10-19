/**
 * 数谜（Kakuro）—— 4×4 十字盘 ❓
 *
 * 盘面（B = 黑格提示位，W = 白格）：
 *      B   B↓  B↓  B
 *      B→  W   W   W
 *      B   W   ※   W
 *      B→  W   W   W
 * 规则：白格填 1~9；每条「横串 / 竖串」内数字互不相同，且和等于串首提示数。
 * 胜负：四条串全部满足 ⇒ 通关（solved=true）；步数用尽 ⇒ 失败（solved=false）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4;
const CELLS: number = N * N;
/** 白格下标（r*4+c）—— 中间十字形 */
const WHITE: number[] = [5, 6, 7, 9, 11, 13, 14, 15];
/** 四条串：两条横、两条竖，每条 3 格 */
const H_RUNS: number[][] = [[5, 6, 7], [13, 14, 15]];
const V_RUNS: number[][] = [[5, 9, 13], [7, 11, 15]];
/** 提示格：横串提示写在串首左边，竖串提示写在串首上面 */
const H_CLUE_AT: number[] = [4, 12];
const V_CLUE_AT: number[] = [1, 3];
const RUNS: number = 4;
const MAX_MOVES: number = 30;
const K1: number[] = [1, 2, 3, 4, 5];
const K2: number[] = [6, 7, 8, 9];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GKakuro {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = new Array<number>(CELLS).fill(0);
  @State private rowClue: number[] = new Array<number>(CELLS).fill(0);
  @State private colClue: number[] = new Array<number>(CELLS).fill(0);
  @State private sel: number = 5;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点一个白格，再点下面数字填入');

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);
  private k1: number[] = K1;
  private k2: number[] = K2;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  // ── 串的判定 ──

  private isWhite(i: number): boolean {
    return WHITE.indexOf(i) >= 0;
  }

  private runSum(v: number[], run: number[]): number {
    let s: number = 0;
    for (let i = 0; i < run.length; i++) {
      s += v[run[i]];
    }
    return s;
  }

  private runDistinct(v: number[], run: number[]): boolean {
    const seen: number[] = [];
    for (let i = 0; i < run.length; i++) {
      const d: number = v[run[i]];
      if (seen.indexOf(d) >= 0) {
        return false;
      }
      seen.push(d);
    }
    return true;
  }

  private runOk(v: number[], run: number[], clue: number): boolean {
    const seen: number[] = [];
    for (let i = 0; i < run.length; i++) {
      const d: number = v[run[i]];
      if (d === 0 || seen.indexOf(d) >= 0) {
        return false;
      }
      seen.push(d);
    }
    return this.runSum(v, run) === clue;
  }

  private doneRuns(): number {
    let n: number = 0;
    for (let i = 0; i < H_RUNS.length; i++) {
      if (this.runOk(this.vals, H_RUNS[i], this.rowClue[H_CLUE_AT[i]])) {
        n++;
      }
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      if (this.runOk(this.vals, V_RUNS[i], this.colClue[V_CLUE_AT[i]])) {
        n++;
      }
    }
    return n;
  }

  private filled(): number {
    let n: number = 0;
    for (let i = 0; i < WHITE.length; i++) {
      if (this.vals[WHITE[i]] !== 0) {
        n++;
      }
    }
    return n;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'kakuro',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.moves * 20) : this.doneRuns() * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneRuns()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ── 出题：先造一组合法解，再取行/列和当提示 ──

  private reset(): void {
    const sol: number[] = new Array<number>(CELLS).fill(0);
    let tries: number = 0;
    let good: boolean = false;
    while (tries < 500 && !good) {
      tries++;
      for (let i = 0; i < WHITE.length; i++) {
        sol[WHITE[i]] = 1 + Math.floor(Math.random() * 9);
      }
      good = true;
      for (let i = 0; i < H_RUNS.length; i++) {
        if (!this.runDistinct(sol, H_RUNS[i])) {
          good = false;
        }
      }
      for (let i = 0; i < V_RUNS.length; i++) {
        if (!this.runDistinct(sol, V_RUNS[i])) {
          good = false;
        }
      }
    }

    const rc: number[] = new Array<number>(CELLS).fill(0);
    const cc: number[] = new Array<number>(CELLS).fill(0);
    for (let i = 0; i < H_RUNS.length; i++) {
      rc[H_CLUE_AT[i]] = this.runSum(sol, H_RUNS[i]);
    }
    for (let i = 0; i < V_RUNS.length; i++) {
      cc[V_CLUE_AT[i]] = this.runSum(sol, V_RUNS[i]);
    }

    this.rowClue = rc;
    this.colClue = cc;
    this.vals = new Array<number>(CELLS).fill(0);
    this.sel = WHITE[0];
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点一个白格，再点下面数字填入');
    this.startAt = Date.now();
  }

  // ── 输入 ──

  private setVal(i: number, v: number): void {
    const n: number[] = this.vals.slice();
    n[i] = v;
    this.vals = n;
  }

  private advance(): void {
    const pos: number = WHITE.indexOf(this.sel);
    for (let k = 1; k <= WHITE.length; k++) {
      const i: number = WHITE[(pos + k) % WHITE.length];
      if (this.vals[i] === 0) {
        this.sel = i;
        return;
      }
    }
    this.sel = WHITE[(pos + 1) % WHITE.length];
  }

  private put(d: number): void {
    if (this.over || !this.isWhite(this.sel)) {
      return;
    }
    this.setVal(this.sel, d);
    this.moves++;
    this.advance();
    this.check();
  }

  private clearSel(): void {
    if (this.over || !this.isWhite(this.sel)) {
      return;
    }
    this.setVal(this.sel, 0);
    this.moves++;
    this.check();
  }

  private tapCell(i: number): void {
    if (this.over || !this.isWhite(i)) {
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

  private check(): void {
    if (this.finished) {
      return;
    }
    const done: number = this.doneRuns();
    if (done === RUNS) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 四条串全对，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    this.tip = TG2('已完成 {0} / {1} 条串', String(done),Digits(String(RUNS), this.langCode));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('完成串'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneRuns()) + '/' + String(RUNS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filled()) + '/' + String(WHITE.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rows, (c: number) => {
              if (this.isWhite((r * N + c))) {
              Stack() {
              Text(this.vals[((r * N + c))] === 0 ? '' : String(this.vals[((r * N + c))]))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.sel === ((r * N + c)) ? '#226366F1' : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({ width: this.sel === ((r * N + c)) ? 2 : 1, color: this.sel === ((r * N + c)) ? Palette.primary : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tapCell(((r * N + c)));
              })
              } else {
              Column({ space: 1 }) {
              Text(this.colClue[((r * N + c))] > 0 ? '↓' + String(this.colClue[((r * N + c))]) : '')
              .fontSize(FontSize.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.teal)
              Text(this.rowClue[((r * N + c))] > 0 ? String(this.rowClue[((r * N + c))]) + '→' : '')
              .fontSize(FontSize.xs)
              .fontWeight(FontWeight.Bold)
              .fontColor(Palette.teal)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.theme.line)
              .borderRadius(Radius.xs)
              }
            }, (c: number) => 'kc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'kr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.xs }) {
        ForEach(this.k1, (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'ka' + d)
      }
      .width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.k2, (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'kb' + d)
        this.delBtn()
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.berry)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }











  @Builder
  delBtn() {
    Text('⌫')
      .accessibilityText(TG('删除'))
      .fontSize(FontSize.lg)
      .fontColor(Palette.rose)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(Cell.of(40))
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
      .onClick(() => {
        Haptics.tick();
        this.clearSel();
      })
  }
}
