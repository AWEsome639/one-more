/**
 * 数方 shikaku（5×5）—— 把整盘切成若干矩形，每块矩形里恰有一个数字，且格数等于该数字
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：25 格全部被合法矩形覆盖 ⇒ solved:true；非法尝试 3 次 ⇒ solved:false
 * 进度：已覆盖格数 ／ 错手 ／ 得分
 *
 * 操作：点第一格 → 点对角格圈出矩形；点已圈好的格子即撤销该矩形
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，原来只开 25）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;

/** 3 关提示（数字 = 所属矩形面积，0 = 无提示） */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    1,0,0,0,0,
    1,0,0,8,0,
    0,0,0,0,0,
    2,0,9,0,3,
    1,0,0,0,0
  ],
  // 第 2 关
  [
    0,0,0,0,0,
    10,0,0,0,0,
    0,5,0,0,0,
    0,5,0,0,0,
    1,1,0,2,1
  ],
  // 第 3 关
  [
    1,5,1,10,0,
    0,0,3,0,0,
    4,0,0,0,0,
    0,0,0,0,0,
    0,0,1,0,0
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GShikaku {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(5);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State owner: number[] = [];     // 0 未圈，否则矩形编号
  @State first: number = -1;
  @State covered: number = 0;
  @State errors: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private seq: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.owner = new Array<number>(MAX_CELLS).fill(0);
    this.first = -1;
    this.covered = 0;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.seq = 0;
    this.startAt = Date.now();
  }

  private removeRect(id: number): void {
    const own: number[] = this.owner.slice();
    let removed: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (own[i] === id) {
        own[i] = 0;
        removed++;
      }
    }
    this.owner = own;
    this.covered -= removed;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const ownHere: number = this.owner[i];
    if (ownHere > 0) {
      this.removeRect(ownHere);
      this.first = -1;
      return;
    }
    if (this.first < 0) {
      this.first = i;
      return;
    }
    const a: number = this.first;
    this.first = -1;
    if (a === i) {
      return;
    }
    const r0: number = Math.min(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const r1: number = Math.max(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const c0: number = Math.min(a % this.diffTotal, i % this.diffTotal);
    const c1: number = Math.max(a % this.diffTotal, i % this.diffTotal);
    let area: number = 0;
    let clueCnt: number = 0;
    let clueVal: number = 0;
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const k: number = r * this.diffTotal + c;
        if (this.owner[k] !== 0) {
          return;                       // 压到别的矩形上，直接放弃
        }
        area++;
        if (this.clues[k] > 0) {
          clueCnt++;
          clueVal = this.clues[k];
        }
      }
    }
    if (clueCnt !== 1 || clueVal !== area) {
      this.errors++;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.seq++;
    const own: number[] = this.owner.slice();
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        own[r * this.diffTotal + c] = this.seq;
      }
    }
    this.owner = own;
    this.covered += area;
    if (this.covered === CELLS) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(100, 520 - this.errors * 100 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'shikaku',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.covered
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    const id: number = this.owner[i];
    if (id > 0) {
      return tintOf(Palette.wheel[(id - 1) % Palette.wheel.length], this.theme.isDark);
    }
    return this.theme.surface;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已覆盖'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.covered) + '/' + String(CELLS)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错手'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(ERR_MAX)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.clues[(r * this.diffTotal + c)] > 0 ? String(this.clues[(r * this.diffTotal + c)]) : '')
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.owner[(r * this.diffTotal + c)] > 0 ? Palette.primaryDeep : this.theme.inkSoft)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({
              width: this.first === (r * this.diffTotal + c) ? 2 : 1,
              color: this.first === (r * this.diffTotal + c) ? Palette.violet : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '整盘切好 🎉 得分 ' + String(this.score) : '错手太多，本局失败')
          : '点两格圈矩形：面积要等于里面的数字')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint).animation({ duration: Motion.fast, curve: Motion.snap() })
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
