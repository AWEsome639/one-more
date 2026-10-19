/**
 * 磁铁（Magnets）—— 4×4 / 8 组磁铁 🧲
 *
 * 棋盘被切成 8 组「横着相邻的两格」= 一块磁铁的两端。
 * 规则：每块磁铁一端是正极 ＋、另一端是负极 －（不能两端同极）；
 *       最右一列数字 = 该行正极的个数，最下一行数字 = 该列正极的个数。
 * 玩法：点格子循环切换 空 → ＋ → － → 空。
 * 胜负：8 块磁铁都成一正一负 且 行列正极数全部对上 ⇒ 通关；步数用尽 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const CELLS: number = N * N;
/** 8 块磁铁最省也要 8×3=24 下（＋ 一下、－ 两下）⇒ 上限给足，别让手滑的人赢不了 */
const MAX_MOVES: number = 60;
const PLUS: number = 1;
const MINUS: number = 2;
const CLUE_W: number = 44;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GMagnets {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private marks: number[] = new Array<number>(CELLS).fill(0);
  @State private rowClue: number[] = new Array<number>(N).fill(0);
  @State private colClue: number[] = new Array<number>(N).fill(0);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点格子切换 空 → ＋ → －');

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  /** 每块磁铁的两端下标 */
  private dominoA(r: number, d: number): number {
    return r * N + d * 2;
  }

  private reset(): void {
    const sol: number[] = new Array<number>(CELLS).fill(0);
    const rc: number[] = new Array<number>(N).fill(0);
    const cc: number[] = new Array<number>(N).fill(0);
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const b: number = a + 1;
        if (Math.random() < 0.5) {
          sol[a] = PLUS;
          sol[b] = MINUS;
        } else {
          sol[a] = MINUS;
          sol[b] = PLUS;
        }
      }
    }
    for (let i = 0; i < CELLS; i++) {
      if (sol[i] === PLUS) {
        rc[Math.floor(i / N)]++;
        cc[i % N]++;
      }
    }
    this.rowClue = rc;
    this.colClue = cc;
    this.marks = new Array<number>(CELLS).fill(0);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点格子切换 空 → ＋ → －');
    this.startAt = Date.now();
  }

  // ── 判定 ──

  private plusInRow(r: number): number {
    let n: number = 0;
    for (let c = 0; c < N; c++) {
      if (this.marks[r * N + c] === PLUS) {
        n++;
      }
    }
    return n;
  }

  private plusInCol(c: number): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      if (this.marks[r * N + c] === PLUS) {
        n++;
      }
    }
    return n;
  }

  private dominoesOk(): boolean {
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const b: number = a + 1;
        const x: number = this.marks[a];
        const y: number = this.marks[b];
        if (x === 0 || y === 0 || x === y) {
          return false;
        }
      }
    }
    return true;
  }

  private linesOk(): boolean {
    for (let r = 0; r < N; r++) {
      if (this.plusInRow(r) !== this.rowClue[r]) {
        return false;
      }
    }
    for (let c = 0; c < N; c++) {
      if (this.plusInCol(c) !== this.colClue[c]) {
        return false;
      }
    }
    return true;
  }

  private placed(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.marks[i] !== 0) {
        n++;
      }
    }
    return n;
  }

  private goodDominoes(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      for (let d = 0; d < 2; d++) {
        const a: number = this.dominoA(r, d);
        const x: number = this.marks[a];
        const y: number = this.marks[a + 1];
        if (x !== 0 && y !== 0 && x !== y) {
          n++;
        }
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
      gameId: 'magnets',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : this.goodDominoes() * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.goodDominoes()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    if (this.dominoesOk() && this.linesOk()) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 磁铁成对、行列正极数全对，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    this.tip = TG2('磁铁成对 {0}/8', String(this.goodDominoes()));
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const nm: number[] = this.marks.slice();
    nm[i] = (nm[i] + 1) % 3;
    this.marks = nm;
    this.moves++;
    this.check();
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
        Text((TG('成对磁铁'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.goodDominoes()) + '/8')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已定格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Stack() {
              Text(this.marks[(r * N + c)] === PLUS ? '＋' : (this.marks[(r * N + c)] === MINUS ? '－' : ''))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.marks[(r * N + c)] === PLUS ? Palette.rose : Palette.sky)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.marks[(r * N + c)] === PLUS ? '#33F43F5E' : (this.marks[(r * N + c)] === MINUS ? '#330EA5E9' : this.theme.surface))
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'mc' + r + '-' + c)
            Column({ space: 1 }) {
            Text(String(this.rowClue[(r)]) + '＋')
            .fontSize(FontSize.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.plusInRow((r)) === this.rowClue[(r)] ? Palette.emerald : this.theme.inkSoft)
            Text(TG2('现 {0}', String(this.plusInRow((r)))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(CLUE_W)
            .height(CLUE_W)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.xs)
          }
          .width('100%')
        }, (r: number) => 'mr' + r)

        Row({ space: Space.xs }) {
          ForEach(this.rows, (c: number) => {
            Column({ space: 1 }) {
            Text(String(this.colClue[(c)]) + '＋')
            .fontSize(FontSize.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.plusInCol((c)) === this.colClue[(c)] ? Palette.emerald : this.theme.inkSoft)
            Text(TG2('现 {0}', String(this.plusInCol((c)))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .layoutWeight(1)
            .aspectRatio(1)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.xs)
          }, (c: number) => 'mq' + c)
          Row().width(CLUE_W).height(CLUE_W)
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG('每块磁铁（横向两格）必须一正一负；右侧/下方数字是该行该列 ＋ 的个数'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.rose)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }








}
