/**
 * 3D 迷宫 —— 立体迷宫导航
 *
 * 玩法：一个 5×5×3 的立体迷宫，用方向键在水平面移动、用 ↑↓ 按钮换层。
 * 从起点走到终点即通关；步数越少得分越高。
 *
 * 原创实现（拾海 2026-10-10）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const W = 5;          // 宽
const H = 5;          // 深
const L = 3;          // 层
const CELLS = W * H * L;

@Component
export struct GMazeNav3d {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：迷宫层数（简单 2 / 普通 3 / 困难 4）
  @State private diffTotal: number = GameDiff.pick(2, 3, 4);
  onFinish: (r: GameResult) => void = () => {};

  @State private walls: number[] = [];     // 1 = 墙
  @State private px: number = 0;
  @State private py: number = 0;
  @State private pz: number = 0;
  @State private steps: number = 0;
  @State private done: boolean = false;
  @State private best: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.pick(2, 3, 4);
    this.reset();
  }

  private idx(x: number, y: number, z: number): number {
    return z * W * H + y * W + x;
  }

  /** 用「随机挖通道」生成一个保证连通的迷宫 */
  private reset(): void {
    this.walls = new Array<number>(CELLS).fill(1);
    this.px = 0;
    this.py = 0;
    this.pz = 0;
    this.steps = 0;
    this.done = false;
    this.startAt = Date.now();

    // 每层挖一条随机游走的通路
    const w = this.walls.slice();
    for (let z = 0; z < this.diffTotal; z++) {
      let cx = 0;
      let cy = 0;
      w[this.idx(cx, cy, z)] = 0;
      for (let n = 0; n < 22; n++) {
        const d: number = Math.floor(Math.random() * 4);
        if (d === 0 && cx + 1 < W) {
          cx++;
        } else if (d === 1 && cx > 0) {
          cx--;
        } else if (d === 2 && cy + 1 < H) {
          cy++;
        } else if (d === 3 && cy > 0) {
          cy--;
        }
        w[this.idx(cx, cy, z)] = 0;
      }
      // 保证终点通
      w[this.idx(W - 1, H - 1, z)] = 0;
      w[this.idx(W - 2, H - 1, z)] = 0;
      w[this.idx(W - 1, H - 2, z)] = 0;
      // 层间通道
      if (z + 1 < this.diffTotal) {
        w[this.idx(cx, cy, z)] = 0;
        w[this.idx(cx, cy, z + 1)] = 0;
      }
    }
    this.walls = w;
  }

  private at(x: number, y: number, z: number): number {
    if (x < 0 || x >= W || y < 0 || y >= H || z < 0 || z >= this.diffTotal) {
      return 1;
    }
    return this.walls[this.idx(x, y, z)];
  }

  private tryMove(dx: number, dy: number, dz: number): void {
    if (this.done) {
      return;
    }
    const nx: number = this.px + dx;
    const ny: number = this.py + dy;
    const nz: number = this.pz + dz;
    if (this.at(nx, ny, nz) === 1) {
      return;
    }
    this.px = nx;
    this.py = ny;
    this.pz = nz;
    this.steps = this.steps + 1;
    if (nx === W - 1 && ny === H - 1 && nz === this.diffTotal - 1) {
      this.done = true;
      if (this.best === 0 || this.steps < this.best) {
        this.best = this.steps;
      }
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'maze_nav_3d', solved: true,
        score: Math.max(10, 400 - this.steps * 8),
        durationMs: Date.now() - this.startAt
      });
    }
  }

  build() {
    Column({ space: Space.md }) {
      // 状态
      Row({ space: Space.lg }) {
        Column({ space: 2 }) {
        Text(Digits(String(this.steps), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text(((this.pz + 1) + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        Text(('层')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text((this.best === 0 ? '—' : String(this.best))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        Text((TG('最好'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
      }
      .width('100%')

      Text(this.done ? '🎉 走通了！' : '走到右下角的 🏁 就算通关')
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)

      // 当前层的平面图
      Column({ space: 6 }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: 6 }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(this.px === (c) && this.py === (r)
              ? '🧍'
              : ((c) === W - 1 && (r) === H - 1
              ? '🏁'
              : (this.at((c), (r), this.pz) === 1 ? '🧱' : '')))
              .fontSize(FontSize.lg)   // ★ 2026-10-14 改用常量（原来硬编码 ⇒ 大字模式下不变）
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.at((c), (r), this.pz) === 1 ? this.theme.surface : this.theme.surfaceAlt)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      // 层切换
      Row({ space: Space.md }) {
        Button(TG('▼ 下层'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).layoutWeight(1).height(Cell.of(42))
          .backgroundColor(this.theme.surfaceAlt).fontColor(this.theme.ink)
          .borderRadius(Radius.sm)
          .enabled(this.pz > 0)
          .onClick(() => {
            this.tryMove(0, 0, -1);
          })
        Button(TG('▲ 上层'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).layoutWeight(1).height(Cell.of(42))
          .backgroundColor(this.theme.surfaceAlt).fontColor(this.theme.ink)
          .borderRadius(Radius.sm)
          .enabled(this.pz < this.diffTotal - 1)
          .onClick(() => {
            this.tryMove(0, 0, 1);
          })
      }
      .width('100%')

      // 方向键
      Column({ space: Space.xs }) {
        Text(('↑'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .width(64).height(Cell.of(40))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => {
        this.tryMove((0), (-1), 0);
        })
        Row({ space: Space.xs }) {
          Text(('←'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          this.tryMove((-1), (0), 0);
          })
          Text(('↓'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          this.tryMove((0), (1), 0);
          })
          Text(('→'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          this.tryMove((1), (0), 0);
          })
        }
      }
      .width('100%')

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .onClick(() => {
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .padding(Space.md)
  }






}
