/**
 * 不等式（Futoshiki）🧩
 *
 * 规则：5×5 每行每列都填 1~5 且不重复，同时满足格与格之间的不等号。
 * 胜负：填满且行列不重复、所有不等号成立 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const MAX_MOVES: number = 120;
const SIGN_W: number = 18;

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 循环拉丁方 + 行/列/符号三重打乱 ⇒ 必然是合法拉丁方 */
function latinSquare(): number[] {
  const rows: number[] = [0, 1, 2, 3, 4];
  const cols: number[] = [0, 1, 2, 3, 4];
  const syms: number[] = [1, 2, 3, 4, 5];
  shuffleArr(rows);
  shuffleArr(cols);
  shuffleArr(syms);
  const out: number[] = new Array<number>(N * N).fill(0);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      const base: number = (rows[r] + cols[c]) % N;
      out[r * N + c] = syms[base];
    }
  }
  return out;
}

@Component
export struct GFutoshiki {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = [];
  @State private given: boolean[] = [];
  @State private hSign: number[] = [];   // 水平：(r,c)-(r,c+1)，1 = <，2 = >
  @State private vSign: number[] = [];   // 垂直：(r,c)-(r+1,c)，1 = <，2 = >
  @State private sel: number = -1;
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
    const sol: number[] = latinSquare();
    const given: boolean[] = new Array<boolean>(N * N).fill(false);
    const order: number[] = [];
    for (let i = 0; i < N * N; i++) {
      order.push(i);
    }
    shuffleArr(order);
    for (let k = 0; k < 8; k++) {
      given[order[k]] = true;
    }
    const h: number[] = new Array<number>(N * (N - 1)).fill(0);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N - 1; c++) {
        if (Math.random() < 0.45) {
          h[r * (N - 1) + c] = sol[r * N + c] < sol[r * N + c + 1] ? 1 : 2;
        }
      }
    }
    const v: number[] = new Array<number>((N - 1) * N).fill(0);
    for (let r = 0; r < N - 1; r++) {
      for (let c = 0; c < N; c++) {
        if (Math.random() < 0.45) {
          v[r * N + c] = sol[r * N + c] < sol[(r + 1) * N + c] ? 1 : 2;
        }
      }
    }
    const vv: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < N * N; i++) {
      vv[i] = given[i] ? sol[i] : 0;
    }
    this.vals = vv;
    this.given = given;
    this.hSign = h;
    this.vSign = v;
    this.sel = -1;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.vals.length; i++) {
      if (this.vals[i] > 0) {
        n++;
      }
    }
    return n;
  }

  private signTotal(): number {
    let n: number = 0;
    for (let i = 0; i < this.hSign.length; i++) {
      if (this.hSign[i] > 0) {
        n++;
      }
    }
    for (let i = 0; i < this.vSign.length; i++) {
      if (this.vSign[i] > 0) {
        n++;
      }
    }
    return n;
  }

  private signOk(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N - 1; c++) {
        const s: number = this.hSign[r * (N - 1) + c];
        const a: number = this.vals[r * N + c];
        const b: number = this.vals[r * N + c + 1];
        if (s > 0 && a > 0 && b > 0 && ((s === 1 && a < b) || (s === 2 && a > b))) {
          n++;
        }
      }
    }
    for (let r = 0; r < N - 1; r++) {
      for (let c = 0; c < N; c++) {
        const s: number = this.vSign[r * N + c];
        const a: number = this.vals[r * N + c];
        const b: number = this.vals[(r + 1) * N + c];
        if (s > 0 && a > 0 && b > 0 && ((s === 1 && a < b) || (s === 2 && a > b))) {
          n++;
        }
      }
    }
    return n;
  }

  private latinOk(): boolean {
    for (let r = 0; r < N; r++) {
      const seen: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let c = 0; c < N; c++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen[v]) {
          return false;
        }
        seen[v] = true;
      }
    }
    for (let c = 0; c < N; c++) {
      const seen: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let r = 0; r < N; r++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen[v]) {
          return false;
        }
        seen[v] = true;
      }
    }
    return true;
  }

  private put(d: number): void {
    if (this.over || this.sel < 0 || this.given[this.sel]) {
      return;
    }
    const n: number[] = this.vals.slice();
    n[this.sel] = d;
    this.vals = n;
    this.moves++;
    if (this.latinOk() && this.signOk() === this.signTotal()) {
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
      gameId: 'futoshiki',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : this.filledCount() * 20,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filledCount()) + '/25'))
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
        Text((TG('不等式'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.signOk()) + '/' + String(this.signTotal())))
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
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((0) * N + 0)] > 0 ? String(this.vals[((0) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 0)]) {
        this.sel = ((0) * N + 0);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 1)] > 0 ? String(this.vals[((0) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 1)]) {
        this.sel = ((0) * N + 1);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 2)] > 0 ? String(this.vals[((0) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 2)]) {
        this.sel = ((0) * N + 2);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 3)] > 0 ? String(this.vals[((0) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 3)]) {
        this.sel = ((0) * N + 3);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 4)] > 0 ? String(this.vals[((0) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 4)]) {
        this.sel = ((0) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((0)) * N + (0)] === 1 ? 'v' : (this.vSign[((0)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (1)] === 1 ? 'v' : (this.vSign[((0)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (2)] === 1 ? 'v' : (this.vSign[((0)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (3)] === 1 ? 'v' : (this.vSign[((0)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (4)] === 1 ? 'v' : (this.vSign[((0)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((1) * N + 0)] > 0 ? String(this.vals[((1) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 0)]) {
        this.sel = ((1) * N + 0);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 1)] > 0 ? String(this.vals[((1) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 1)]) {
        this.sel = ((1) * N + 1);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 2)] > 0 ? String(this.vals[((1) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 2)]) {
        this.sel = ((1) * N + 2);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 3)] > 0 ? String(this.vals[((1) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 3)]) {
        this.sel = ((1) * N + 3);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 4)] > 0 ? String(this.vals[((1) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 4)]) {
        this.sel = ((1) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((1)) * N + (0)] === 1 ? 'v' : (this.vSign[((1)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (1)] === 1 ? 'v' : (this.vSign[((1)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (2)] === 1 ? 'v' : (this.vSign[((1)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (3)] === 1 ? 'v' : (this.vSign[((1)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (4)] === 1 ? 'v' : (this.vSign[((1)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((2) * N + 0)] > 0 ? String(this.vals[((2) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 0)]) {
        this.sel = ((2) * N + 0);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 1)] > 0 ? String(this.vals[((2) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 1)]) {
        this.sel = ((2) * N + 1);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 2)] > 0 ? String(this.vals[((2) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 2)]) {
        this.sel = ((2) * N + 2);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 3)] > 0 ? String(this.vals[((2) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 3)]) {
        this.sel = ((2) * N + 3);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 4)] > 0 ? String(this.vals[((2) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 4)]) {
        this.sel = ((2) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((2)) * N + (0)] === 1 ? 'v' : (this.vSign[((2)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (1)] === 1 ? 'v' : (this.vSign[((2)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (2)] === 1 ? 'v' : (this.vSign[((2)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (3)] === 1 ? 'v' : (this.vSign[((2)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (4)] === 1 ? 'v' : (this.vSign[((2)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((3) * N + 0)] > 0 ? String(this.vals[((3) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 0)]) {
        this.sel = ((3) * N + 0);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 1)] > 0 ? String(this.vals[((3) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 1)]) {
        this.sel = ((3) * N + 1);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 2)] > 0 ? String(this.vals[((3) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 2)]) {
        this.sel = ((3) * N + 2);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 3)] > 0 ? String(this.vals[((3) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 3)]) {
        this.sel = ((3) * N + 3);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 4)] > 0 ? String(this.vals[((3) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 4)]) {
        this.sel = ((3) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((3)) * N + (0)] === 1 ? 'v' : (this.vSign[((3)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (1)] === 1 ? 'v' : (this.vSign[((3)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (2)] === 1 ? 'v' : (this.vSign[((3)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (3)] === 1 ? 'v' : (this.vSign[((3)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (4)] === 1 ? 'v' : (this.vSign[((3)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((4) * N + 0)] > 0 ? String(this.vals[((4) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 0)]) {
        this.sel = ((4) * N + 0);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 1)] > 0 ? String(this.vals[((4) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 1)]) {
        this.sel = ((4) * N + 1);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 2)] > 0 ? String(this.vals[((4) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 2)]) {
        this.sel = ((4) * N + 2);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 3)] > 0 ? String(this.vals[((4) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 3)]) {
        this.sel = ((4) * N + 3);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 4)] > 0 ? String(this.vals[((4) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 4)]) {
        this.sel = ((4) * N + 4);
        }
        })
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4, 5], (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'fk' + d)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.over ? (this.won ? '🎉 行列不重复且不等号全满足，通关！' : TG('步数用尽，重开一题吧')) :
        '点格子选中，再点下面数字填入；粗黑数字是题目提示')
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }





  @Builder
  gapBox() {
    Row() {
    }
    .width(SIGN_W)
  }










}
