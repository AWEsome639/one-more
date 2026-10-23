/**
 * 多米诺拼盘（Dominosa）🧩
 *
 * 规则：点两个相邻格子把它们配成一块骨牌；每种点数组合（0-0 … 3-3，共 10 种）只能用一次。
 * 胜负：铺满棋盘且 10 种骨牌各不相同 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const H: number = 4;
const W: number = 5;
const NV: number = 4;
const TOTAL: number = 10;
const MAX_MOVES: number = 80;

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 用「最靠前的空格」配对的回溯铺砖，必然能铺满 4×5 */
function domFill(used: boolean[], partner: number[]): boolean {
  let f: number = -1;
  for (let i = 0; i < H * W; i++) {
    if (!used[i]) {
      f = i;
      break;
    }
  }
  if (f < 0) {
    return true;
  }
  used[f] = true;
  const r: number = Math.floor(f / W);
  const c: number = f - r * W;
  const opts: number[] = [];
  if (c + 1 < W && !used[f + 1]) {
    opts.push(f + 1);
  }
  if (r + 1 < H && !used[f + W]) {
    opts.push(f + W);
  }
  shuffleArr(opts);
  for (let k = 0; k < opts.length; k++) {
    const j: number = opts[k];
    used[j] = true;
    partner[f] = j;
    partner[j] = f;
    if (domFill(used, partner)) {
      return true;
    }
    partner[f] = -1;
    partner[j] = -1;
    used[j] = false;
  }
  used[f] = false;
  return false;
}

@Component
export struct GDominosa {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」第 20 个（这一类的第一次"两种难度都不可通关"）：
   *   棋盘固定 4×5 = 20 格 ⇒ 永远只能配成 10 对骨牌。
   *   但 diffTotal = sizeNow(TOTAL) = 7/10/13，
   *   而胜利条件是 `paired() === diffTotal`：
   *     · 简单 7：盘上 20 格，配到 10 也 != 7 ⇒ **永远赢不了**
   *     · 困难 13：最多 10 对，凑不到 13 ⇒ **永远赢不了**
   *   ⇒ 只有普通档（正好 10）能通关。
   *
   *   修法：**对数固定为 TOTAL=10**（棋盘决定的），
   *   难度改到**步数上限**上（MAX_MOVES 本来就是为此准备的）。
   */
  @State private diffTotal: number = TOTAL;
  /** 本局可用步数：简单 120 / 普通 80 / 困难 56 */
  @State private moveCap: number = GDominosa.capNow();

  private static capNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 120;
    }
    if (d === 2) {
      return 56;
    }
    return 80;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private vals: number[] = [];
  @State private owner: number[] = [];   // 配对伙伴下标，-1 = 未配对
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
    this.moveCap = GDominosa.capNow();
    this.reset();
  }

  private reset(): void {
    let heads: number[] = [];
    let partner: number[] = [];
    let guard: number = 0;
    while (heads.length !== this.diffTotal && guard < 30) {
      guard++;
      const used: boolean[] = new Array<boolean>(H * W).fill(false);
      partner = new Array<number>(H * W).fill(-1);
      domFill(used, partner);
      heads = [];
      for (let i = 0; i < H * W; i++) {
        if (partner[i] > i) {
          heads.push(i);
        }
      }
    }
    const codes: number[] = [];
    for (let a = 0; a < NV; a++) {
      for (let b = a; b < NV; b++) {
        codes.push(a * NV + b);
      }
    }
    shuffleArr(codes);
    const vals: number[] = new Array<number>(H * W).fill(0);
    for (let k = 0; k < heads.length && k < codes.length; k++) {
      const h: number = heads[k];
      const t: number = partner[h];
      const code: number = codes[k];
      const a: number = Math.floor(code / NV);
      const b: number = code - a * NV;
      vals[h] = a;
      vals[t] = b;
    }
    this.vals = vals;
    this.owner = new Array<number>(H * W).fill(-1);
    this.sel = -1;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private paired(): number {
    let n: number = 0;
    for (let i = 0; i < this.owner.length; i++) {
      if (this.owner[i] >= 0) {
        n++;
      }
    }
    return Math.floor(n / 2);
  }

  /** 重复的骨牌种类数 */
  private dups(): number {
    const seen: boolean[] = new Array<boolean>(NV * NV).fill(false);
    let dup: number = 0;
    for (let i = 0; i < this.owner.length; i++) {
      const j: number = this.owner[i];
      if (j < i) {
        continue;
      }
      let a: number = this.vals[i];
      let b: number = this.vals[j];
      if (a > b) {
        const t: number = a;
        a = b;
        b = t;
      }
      const code: number = a * NV + b;
      if (seen[code]) {
        dup++;
      } else {
        seen[code] = true;
      }
    }
    return dup;
  }

  private isSolved(): boolean {
    return this.paired() === this.diffTotal && this.dups() === 0;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const own: number[] = this.owner.slice();
    if (own[i] >= 0) {
      const j: number = own[i];
      own[i] = -1;
      own[j] = -1;
      this.owner = own;
      this.sel = -1;
      this.moves++;
      return;
    }
    if (this.sel < 0) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    const r1: number = Math.floor(this.sel / W);
    const c1: number = this.sel - r1 * W;
    const r2: number = Math.floor(i / W);
    const c2: number = i - r2 * W;
    const near: boolean = (r1 === r2 && Math.abs(c1 - c2) === 1) || (c1 === c2 && Math.abs(r1 - r2) === 1);
    if (!near) {
      this.sel = i;
      return;
    }
    own[this.sel] = i;
    own[i] = this.sel;
    this.owner = own;
    this.sel = -1;
    this.moves++;
    if (this.isSolved()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.moveCap) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'dominosa',
      solved: solved,
      score: solved ? Math.max(200, 1200 - this.moves * 10) : this.paired() * 80,
      durationMs: Date.now() - this.startAt,
      levelReached: this.paired()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellBg(i: number): string {
    if (this.owner[i] >= 0) {
      const m: number = Math.min(i, this.owner[i]);
      return Palette.wheel[m % Palette.wheel.length];
    }
    if (this.sel === i) {
      return this.theme.isDark ? '#2A2A44' : '#E0E7FF';
    }
    return this.theme.surface;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('已配对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.paired()) + '/' + String(this.diffTotal)))
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
        Text((TG('重复'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.dups())))
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

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(String(this.vals[(r * W + c)]))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.owner[(r * W + c)] >= 0 ? '#FFFFFF' : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * W + c)))
              .borderRadius(Radius.sm)
              .scale({
              x: this.pressed === (r * W + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * W + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * W + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * W + c));
              })
            }, (c: number) => 'dm' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'dmr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点相邻两格 = 一块骨牌')
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

      Text(TG('骨牌上两个数字就是点数组合；同色 = 已配对（再点一次可拆开）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
