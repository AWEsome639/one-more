/**
 * 斜线数回（Gokigen Naname）➰
 *
 * 规则：每个方格里画一条斜线（╲ 或 ╱），使每个圆点上的数字等于"交汇在该点的斜线条数"，
 *       并且所有斜线不能围成任何闭合回路。
 * 胜负：16 格全部画线且数字全对、无回路 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const M: number = 4;          // 4×4 个方格
const D: number = M + 1;      // 5×5 个圆点
const MAX_MOVES: number = 100;

interface GokiGen {
  ori: number[];
  num: number[];
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

function dsuFind(p: number[], x: number): number {
  let r: number = x;
  while (p[r] !== r) {
    r = p[r];
  }
  let k: number = x;
  while (p[k] !== r) {
    const nx: number = p[k];
    p[k] = r;
    k = nx;
  }
  return r;
}

function dsuUnion(p: number[], a: number, b: number): boolean {
  const ra: number = dsuFind(p, a);
  const rb: number = dsuFind(p, b);
  if (ra === rb) {
    return false;
  }
  p[ra] = rb;
  return true;
}

/** 先铺满 ╲（必然无回路），再随机翻成 ╱ —— 只在不成环时接受 */
function gokiGen(): GokiGen {
  const p: number[] = [];
  for (let i = 0; i < D * D; i++) {
    p.push(i);
  }
  const ori: number[] = new Array<number>(M * M).fill(1);
  for (let r = 0; r < M; r++) {
    for (let c = 0; c < M; c++) {
      dsuUnion(p, r * D + c, (r + 1) * D + (c + 1));
    }
  }
  const cells: number[] = [];
  for (let i = 0; i < M * M; i++) {
    cells.push(i);
  }
  shuffleArr(cells);
  for (let k = 0; k < cells.length; k++) {
    if (Math.random() < 0.5) {
      continue;
    }
    const i: number = cells[k];
    const r: number = Math.floor(i / M);
    const c: number = i - r * M;
    const p2: number[] = p.slice();
    if (dsuUnion(p2, r * D + (c + 1), (r + 1) * D + c)) {
      for (let t = 0; t < p2.length; t++) {
        p[t] = p2[t];
      }
      ori[i] = 2;
    }
  }
  const num: number[] = new Array<number>(D * D).fill(0);
  for (let r = 0; r < M; r++) {
    for (let c = 0; c < M; c++) {
      if (ori[r * M + c] === 1) {
        num[r * D + c]++;
        num[(r + 1) * D + (c + 1)]++;
      } else {
        num[r * D + (c + 1)]++;
        num[(r + 1) * D + c]++;
      }
    }
  }
  return { ori: ori, num: num };
}

@Component
export struct GGokigenNaname {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private ori: number[] = [];
  @State private num: number[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -2;

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
    const g: GokiGen = gokiGen();
    this.num = g.num;
    this.ori = new Array<number>(M * M).fill(0);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -2;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.ori.length; i++) {
      if (this.ori[i] > 0) {
        n++;
      }
    }
    return n;
  }

  /** 当前每条线在两点上的计数与题目数字的吻合点数 */
  private numOk(): number {
    const cnt: number[] = new Array<number>(D * D).fill(0);
    for (let i = 0; i < M * M; i++) {
      const o: number = this.ori[i];
      if (o === 0) {
        continue;
      }
      const r: number = Math.floor(i / M);
      const c: number = i - r * M;
      if (o === 1) {
        cnt[r * D + c]++;
        cnt[(r + 1) * D + (c + 1)]++;
      } else {
        cnt[r * D + (c + 1)]++;
        cnt[(r + 1) * D + c]++;
      }
    }
    let n: number = 0;
    for (let i = 0; i < D * D; i++) {
      if (cnt[i] === this.num[i]) {
        n++;
      }
    }
    return n;
  }

  /** 无闭合回路 */
  private loopFree(): boolean {
    const p: number[] = [];
    for (let i = 0; i < D * D; i++) {
      p.push(i);
    }
    for (let i = 0; i < M * M; i++) {
      const o: number = this.ori[i];
      if (o === 0) {
        continue;
      }
      const r: number = Math.floor(i / M);
      const c: number = i - r * M;
      if (o === 1) {
        if (!dsuUnion(p, r * D + c, (r + 1) * D + (c + 1))) {
          return false;
        }
      } else {
        if (!dsuUnion(p, r * D + (c + 1), (r + 1) * D + c)) {
          return false;
        }
      }
    }
    return true;
  }

  private tapCell(r: number, c: number): void {
    if (this.over) {
      return;
    }
    if (r % 2 !== 1 || c % 2 !== 1) {
      return;
    }
    const i: number = Math.floor((r - 1) / 2) * M + Math.floor((c - 1) / 2);
    const o: number[] = this.ori.slice();
    const cur: number = o[i];
    o[i] = cur === 0 ? 1 : (cur === 1 ? 2 : 0);
    this.ori = o;
    this.moves++;
    if (this.filledCount() === M * M && this.numOk() === D * D && this.loopFree()) {
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
      gameId: 'gokigen_naname',
      solved: solved,
      score: solved ? Math.max(200, 1400 - this.moves * 10) : this.numOk() * 40,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellIdx(r: number, c: number): number {
    return Math.floor((r - 1) / 2) * M + Math.floor((c - 1) / 2);
  }

  private dotVal(r: number, c: number): number {
    return this.num[Math.floor(r / 2) * D + Math.floor(c / 2)];
  }

  private cellChar(r: number, c: number): string {
    const o: number = this.ori[this.cellIdx(r, c)];
    return o === 1 ? '╲' : (o === 2 ? '╱' : '');
  }

  private slotBg(r: number, c: number): string {
    if (r % 2 === 0 && c % 2 === 0) {
      return this.theme.surfaceAlt;
    }
    if (r % 2 === 1 && c % 2 === 1) {
      const o: number = this.ori[this.cellIdx(r, c)];
      if (o === 0) {
        return this.theme.surface;
      }
      return this.theme.isDark ? '#123A4D' : '#BAE6FD';
    }
    return '#00000000';
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('已画'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filledCount()) + '/16'))
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
        Text((TG('数字吻合'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.numOk()) + '/25'))
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

      Column({ space: 1 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (r: number) => {
          Row({ space: 1 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (c: number) => {
              Stack() {
              if ((r) % 2 === 0 && (c) % 2 === 0) {
              Text(String(this.dotVal((r), (c))))
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkSoft)
              } else if ((r) % 2 === 1 && (c) % 2 === 1) {
              Text(this.cellChar((r), (c)))
              .fontSize(FontSize.xl)
              .fontColor(Palette.sky)
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.slotBg((r), (c)))
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r) * 9 + (c) ? Motion.pressScale : 1,
              y: this.pressed === (r) * 9 + (c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r) * 9 + (c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -2;
              }
              })
              .onClick(() => {
              Haptics.tick();
              this.tapCell((r), (c));
              })
            }, (c: number) => 'gk' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'gkr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点方块：空 → ╲ → ╱ → 空')
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
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('圆点数字 = 交汇在此的斜线条数；斜线不能连成圈'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
