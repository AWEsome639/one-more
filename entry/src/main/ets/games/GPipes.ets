/**
 * 管道 pipes（5×5）—— 点格子把管道转 90°，让所有接口对接、水不漏
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：所有开口两两对接 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已对接接口 ／ 已用步数 ／ 剩余步数
 *
 * 位掩码：1 上 ／ 2 右 ／ 4 下 ／ 8 左
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const STEP_BUDGET: number = 70;

/** 3 关初始状态（每格都是某个合法管件的一个旋转，必定可复原） */
const PIPE_LIB: number[][] = [
  // 第 1 关
  [
    1,2,10,7,2,
    10,8,12,15,12,
    11,7,7,2,4,
    2,2,15,10,4,
    8,10,14,10,8
  ],
  // 第 2 关
  [
    2,12,2,8,4,
    6,7,7,12,5,
    14,14,4,12,9,
    10,3,7,15,12,
    2,1,3,8,1
  ],
  // 第 3 关
  [
    1,8,3,6,2,
    12,11,15,11,8,
    9,9,10,3,14,
    10,3,15,1,10,
    4,2,1,2,3
  ]
];

/** 掩码(0~15) → 制表符画出的管件：下标即位掩码 1上 2右 4下 8左 */
const GLYPHS: string[] = [
  '·', '╵', '╶', '╰', '╷', '│', '╭', '├',
  '╴', '╯', '─', '┴', '╮', '┤', '┬', '┼'
];

@Component
export struct GPipes {
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

  @State pipeMask: number[] = [];
  @State steps: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

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
    const k: number = Math.floor(Math.random() * PIPE_LIB.length);
    this.pipeMask = PIPE_LIB[k].slice();
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private ports(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      const m: number = this.pipeMask[i];
      if ((m & 1) !== 0) {
        n++;
      }
      if ((m & 2) !== 0) {
        n++;
      }
      if ((m & 4) !== 0) {
        n++;
      }
      if ((m & 8) !== 0) {
        n++;
      }
    }
    return n;
  }

  /** 某一侧的开口是否与邻居对接 */
  private sideOk(i: number, bit: number): boolean {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    if (bit === 1) {
      return r > 0 && (this.pipeMask[i - this.diffTotal] & 4) !== 0;
    }
    if (bit === 2) {
      return c < this.diffTotal - 1 && (this.pipeMask[i + 1] & 8) !== 0;
    }
    if (bit === 4) {
      return r < this.diffTotal - 1 && (this.pipeMask[i + this.diffTotal] & 1) !== 0;
    }
    return c > 0 && (this.pipeMask[i - 1] & 2) !== 0;
  }

  private matched(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      const m: number = this.pipeMask[i];
      if ((m & 1) !== 0 && this.sideOk(i, 1)) {
        n++;
      }
      if ((m & 2) !== 0 && this.sideOk(i, 2)) {
        n++;
      }
      if ((m & 4) !== 0 && this.sideOk(i, 4)) {
        n++;
      }
      if ((m & 8) !== 0 && this.sideOk(i, 8)) {
        n++;
      }
    }
    return n;
  }

  private cellOk(i: number): boolean {
    const m: number = this.pipeMask[i];
    if ((m & 1) !== 0 && !this.sideOk(i, 1)) {
      return false;
    }
    if ((m & 2) !== 0 && !this.sideOk(i, 2)) {
      return false;
    }
    if ((m & 4) !== 0 && !this.sideOk(i, 4)) {
      return false;
    }
    if ((m & 8) !== 0 && !this.sideOk(i, 8)) {
      return false;
    }
    return true;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const next: number[] = this.pipeMask.slice();
    next[i] = ((next[i] << 1) | (next[i] >> 3)) & 15;   // 顺时针 90°
    this.pipeMask = next;
    this.steps++;
    if (this.matched() === this.ports()) {
      this.over = true;
      this.won = true;
      this.score = Math.max(80, 520 - this.steps * 4);
      this.finish(true);
      return;
    }
    if (this.steps >= STEP_BUDGET) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'pipes',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.matched()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已对接'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.matched()) + '/' + String(this.ports())))
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
        Text((TG('已用步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(STEP_BUDGET)))
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
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, STEP_BUDGET - this.steps))))
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
              Text(GLYPHS[this.pipeMask[(r * this.diffTotal + c)]])
              .fontSize(FontSize.xxl)
              .fontColor(this.cellOk((r * this.diffTotal + c)) ? Palette.emerald : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellOk((r * this.diffTotal + c)) ? (this.theme.isDark ? '#0E2A22' : '#ECFDF5') : this.theme.surface)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
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
          ? (this.won ? '水路全通 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点格子旋转管道，绿色表示这一格接口都接上了')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.teal)
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
