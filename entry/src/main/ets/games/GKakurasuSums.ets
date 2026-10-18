/**
 * 黑白和（Kakurasu）⚫
 *
 * 规则：每格涂黑或留白。第 r 行左侧的数字 = 该行黑格所在**列号之和**；
 *       第 c 列上方的数字 = 该列黑格所在**行号之和**（列号/行号从 1 数起）。
 * 胜负：行、列全部对上 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const MAX_MOVES: number = 150;
const LBL_W: number = 40;

@Component
export struct GKakurasuSums {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private black: boolean[] = [];
  @State private rowLab: number[] = [];
  @State private colLab: number[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    let b: boolean[] = [];
    let ok: boolean = false;
    let guard: number = 0;
    while (!ok && guard < 40) {
      guard++;
      b = new Array<boolean>(N * N).fill(false);
      let blk: number = 0;
      for (let i = 0; i < N * N; i++) {
        if (Math.random() < 0.45) {
          b[i] = true;
          blk++;
        }
      }
      ok = blk >= 4 && blk <= N * N - 4;
    }
    const rowLab: number[] = new Array<number>(N).fill(0);
    const colLab: number[] = new Array<number>(N).fill(0);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        if (b[r * N + c]) {
          rowLab[r] += c + 1;
          colLab[c] += r + 1;
        }
      }
    }
    this.rowLab = rowLab;
    this.colLab = colLab;
    this.black = new Array<boolean>(N * N).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private rowSum(r: number): number {
    let s: number = 0;
    for (let c = 0; c < N; c++) {
      if (this.black[r * N + c]) {
        s += c + 1;
      }
    }
    return s;
  }

  private colSum(c: number): number {
    let s: number = 0;
    for (let r = 0; r < N; r++) {
      if (this.black[r * N + c]) {
        s += r + 1;
      }
    }
    return s;
  }

  private rowOk(r: number): boolean {
    return this.rowSum(r) === this.rowLab[r];
  }

  private colOk(c: number): boolean {
    return this.colSum(c) === this.colLab[c];
  }

  private okLines(): number {
    let n: number = 0;
    for (let i = 0; i < N; i++) {
      if (this.rowOk(i)) {
        n++;
      }
      if (this.colOk(i)) {
        n++;
      }
    }
    return n;
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < N * N; i++) {
      if (this.black[i]) {
        n++;
      }
    }
    return n;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const b: boolean[] = this.black.slice();
    b[i] = !b[i];
    this.black = b;
    this.moves++;
    if (this.okLines() === 2 * N) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'kakurasu_sums',
      solved: solved,
      score: solved ? Math.max(200, 1400 - this.moves * 8) : this.okLines() * 90,
      durationMs: Date.now() - this.startAt,
      levelReached: this.okLines()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('达标线'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.okLines()) + '/' + String(2 * N)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        Row({ space: 2 }) {
          Row() {
          }
          .width(LBL_W)
          ForEach([0, 1, 2, 3, 4], (c: number) => {
            Column({ space: 2 }) {
            Text(String((false) ? this.rowLab[(c)] : this.colLab[(c)]))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor((false) ? (this.rowOk((c)) ? Palette.emerald : this.theme.ink) :
            (this.colOk((c)) ? Palette.emerald : this.theme.ink))
            Text(String((false) ? this.rowSum((c)) : this.colSum((c))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(LBL_W)
            .height(LBL_W)
            .justifyContent(FlexAlign.Center)
          }, (c: number) => 'ksh' + c)
        }
        .width('100%')

        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: 2 }) {
            Column({ space: 2 }) {
            Text(String((true) ? this.rowLab[(r)] : this.colLab[(r)]))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor((true) ? (this.rowOk((r)) ? Palette.emerald : this.theme.ink) :
            (this.colOk((r)) ? Palette.emerald : this.theme.ink))
            Text(String((true) ? this.rowSum((r)) : this.colSum((r))))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
            }
            .width(LBL_W)
            .height(LBL_W)
            .justifyContent(FlexAlign.Center)
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.black[(r * N + c)] ? (this.theme.isDark ? '#0B0B0B' : '#1F2937') : this.theme.surface)
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .onClick(() => {
              this.tap((r * N + c));
              })
            }, (c: number) => 'ks' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'ksr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点格子涂黑 / 擦白')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')

      Text(TG('上方数字 = 该列黑格的行号之和；左侧数字 = 该行黑格的列号之和（行/列号从 1 起）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  /** 行/列提示数：目标 + 当前（对上了变绿） */



}
