/**
 * 数织 nonogram（5×5）—— 按行/列数字涂格，涂出图案即通关
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：行列线索全部满足 ⇒ solved:true；错涂 3 次 ⇒ solved:false
 * 进度：错涂次数 ／ 已完成行 ／ 已完成列
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const ERR_MAX: number = 3;
const CLUE_W: number = 42;

/** 4 张 5×5 图案（1 = 涂黑）：心 / 菱形 / 箭 / 星 */
const NONO_ART: number[][] = [
  // 第 1 关
  [
    0,1,0,1,0,
    1,1,1,1,1,
    1,1,1,1,1,
    0,1,1,1,0,
    0,0,1,0,0
  ],
  // 第 2 关
  [
    0,0,1,0,0,
    0,1,1,1,0,
    1,1,1,1,1,
    0,1,1,1,0,
    0,0,1,0,0
  ],
  // 第 3 关
  [
    0,0,1,0,0,
    0,1,1,1,0,
    1,1,1,1,1,
    0,0,1,0,0,
    0,0,1,0,0
  ],
  // 第 4 关
  [
    0,0,1,0,0,
    0,1,0,1,0,
    1,1,1,1,1,
    1,1,1,1,1,
    0,1,0,1,0
  ]
];

/** 一行/一列的线索串（如 "1 2"）；整行全空记 "0" */
function clueOf(line: number[]): string {
  const parts: number[] = [];
  let run: number = 0;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === 1) {
      run++;
    } else if (run > 0) {
      parts.push(run);
      run = 0;
    }
  }
  if (run > 0) {
    parts.push(run);
  }
  return parts.length === 0 ? '0' : parts.join(' ');
}

@Component
export struct GNonogram {
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

  @State art: number[] = [];
  @State cells: number[] = [];   // 0 空 1 涂黑 2 打叉
  @State errors: number = 0;
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
    const k: number = Math.floor(Math.random() * NONO_ART.length);
    this.art = NONO_ART[k].slice();
    this.cells = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 取第 k 行/列的当前涂黑情况（horiz=true 为行） */
  private line(horiz: boolean, k: number): number[] {
    const out: number[] = [];
    for (let j = 0; j < this.diffTotal; j++) {
      const i: number = horiz ? k * this.diffTotal + j : j * this.diffTotal + k;
      out.push(this.cells[i] === 1 ? 1 : 0);
    }
    return out;
  }

  private artLine(horiz: boolean, k: number): number[] {
    const out: number[] = [];
    for (let j = 0; j < this.diffTotal; j++) {
      const i: number = horiz ? k * this.diffTotal + j : j * this.diffTotal + k;
      out.push(this.art[i]);
    }
    return out;
  }

  private lineOk(horiz: boolean, k: number): boolean {
    return clueOf(this.line(horiz, k)) === clueOf(this.artLine(horiz, k));
  }

  private doneCount(horiz: boolean): number {
    let n: number = 0;
    for (let k = 0; k < this.diffTotal; k++) {
      if (this.lineOk(horiz, k)) {
        n++;
      }
    }
    return n;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const next: number[] = this.cells.slice();
    next[i] = (next[i] + 1) % 3;      // 空 → 涂黑 → 打叉 → 空
    this.cells = next;
    const v: number = next[i];
    if (v === 1 && this.art[i] === 0) {
      this.errors++;
      const undo: number[] = this.cells.slice();
      undo[i] = 0;
      this.cells = undo;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    if (this.doneCount(true) === this.diffTotal && this.doneCount(false) === this.diffTotal) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(50, 320 - this.errors * 60 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'nonogram',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneCount(true) + this.doneCount(false)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('错涂'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
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
        Text((TG('已完成行'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneCount(true)) + '/' + String(this.diffTotal)))
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
        Text((TG('已完成列'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneCount(false)) + '/' + String(this.diffTotal)))
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
        // 列线索
        Row({ space: Space.xs }) {
          Text('').width(CLUE_W)
          ForEach(this.rowIdx(), (c: number) => {
            Text(clueOf(this.artLine(false, c)))
              .fontSize(FontSize.xxs)
              .fontColor(this.lineOk(false, c) ? Palette.emerald : this.theme.inkSoft)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }, (c: number) => 'tc' + c)
        }
        .width('100%')

        // 行线索 + 格子
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            Text(clueOf(this.artLine(true, r)))
              .fontSize(FontSize.xxs)
              .fontColor(this.lineOk(true, r) ? Palette.emerald : this.theme.inkSoft)
              .width(CLUE_W)
              .textAlign(TextAlign.Center)
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.cells[(r * this.diffTotal + c)] === 2 ? '×' : '')
              .fontSize(FontSize.md)
              .fontColor(this.theme.inkFaint)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells[(r * this.diffTotal + c)] === 1 ? Palette.primaryDeep : this.theme.surface)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
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
          ? (this.won ? '图案复原 🎉 得分 ' + String(this.score) : '错涂太多，本局失败')
          : '点格子：涂黑 → 打叉 → 清空')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.primaryDeep)
          .borderRadius(Radius.md)
          .width(96)
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




}
