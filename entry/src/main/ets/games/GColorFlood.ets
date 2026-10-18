/**
 * 色彩洪水（Flood-It）🎨
 *
 * 规则：棋盘左上角是"洪水"起点，每步选一种颜色，把与左上角连通的一整块染成该色。
 * 胜负：步数上限内整盘同色 = 通关；步数用尽仍未统一 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 12;
const MAX_MOVES: number = 25;
const COLORS: string[] = ['#EF4444', '#F59E0B', '#10B981', '#0EA5E9', '#8B5CF6', '#EC4899'];

/** 把与 0 号格连通且同色的一整块染成 to，返回新数组 */
function floodTo(cells: number[], to: number): number[] {
  const out: number[] = cells.slice();
  const src: number = out[0];
  if (src === to) {
    return out;
  }
  const st: number[] = [0];
  out[0] = to;
  while (st.length > 0) {
    const i: number = st[st.length - 1];
    st.splice(st.length - 1, 1);
    const r: number = Math.floor(i / N);
    const c: number = i - r * N;
    if (c > 0 && out[i - 1] === src) {
      out[i - 1] = to;
      st.push(i - 1);
    }
    if (c < N - 1 && out[i + 1] === src) {
      out[i + 1] = to;
      st.push(i + 1);
    }
    if (r > 0 && out[i - N] === src) {
      out[i - N] = to;
      st.push(i - N);
    }
    if (r < N - 1 && out[i + N] === src) {
      out[i + N] = to;
      st.push(i + N);
    }
  }
  return out;
}

@Component
export struct GColorFlood {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
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
    const c: number[] = [];
    for (let i = 0; i < N * N; i++) {
      c.push(Math.floor(Math.random() * COLORS.length));
    }
    this.cells = c;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  /** 与起点同色的格子数 —— 进度条口径 */
  private filled(): number {
    let n: number = 0;
    const head: number = this.cells.length > 0 ? this.cells[0] : 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === head) {
        n++;
      }
    }
    return n;
  }

  private pick(color: number): void {
    if (this.over || this.cells.length === 0) {
      return;
    }
    const head: number = this.cells[0];
    if (head === color) {
      return;   // 同色无效果，不记步
    }
    this.cells = floodTo(this.cells, color);
    this.moves++;
    if (this.filled() === N * N) {
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
      gameId: 'color_flood',
      solved: solved,
      score: solved ? Math.max(200, 1200 - this.moves * 40) : this.filled() * 12,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.diffTotal)))
        .fontSize(FontSize.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('统一度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filled()) + '/' + String(N * N)))
        .fontSize(FontSize.xl)
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
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (c: number) => {
              Stack() {
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(COLORS[this.cells[(r * N + c)]])
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (c: number) => 'cf' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'cfr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
          Stack() {
          Text(this.cells.length > 0 && this.cells[0] === (i) ? '起点' : '')
          .fontSize(FontSize.xxs)
          .fontColor('#FFFFFF')
          }
          .layoutWeight(1)
          .height(Cell.of(48))
          .backgroundColor(COLORS[(i)])
          .borderRadius(Radius.md)
          .scale({
          x: this.pressed === (i) ? Motion.pressScale : 1,
          y: this.pressed === (i) ? Motion.pressScale : 1
          })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
          this.pressed = (i);
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressed = -1;
          }
          })
          .onClick(() => {
          this.pick((i));
          })
        }, (i: number) => 'cfp' + i)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点色块染左上角连通区')
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
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }






}
