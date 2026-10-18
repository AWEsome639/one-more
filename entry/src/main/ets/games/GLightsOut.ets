/**
 * 灭灯（Lights Out）—— 5×5 🔌
 *
 * 规则：点一格，它自己与上下左右四格一起「亮 ↔ 灭」翻转。
 * 胜负：全盘熄灭 ⇒ 通关（solved=true）；步数用尽 ⇒ 失败。
 * 出题：从全灭出发随机按几下 ⇒ 保证这盘一定有解（按回去即可）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const MAX_MOVES: number = 40;
const MIN_TAPS: number = 6;
const MAX_TAPS: number = 10;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

function shuffled(n: number): number[] {
  const a: number[] = range(n);
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GLightsOut {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private on: boolean[] = new Array<boolean>(CELLS).fill(false);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点任意一格：它和上下左右一起翻转');

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

  private rowOf(i: number): number {
    return Math.floor(i / N);
  }

  private colOf(i: number): number {
    return i % N;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.rowOf(i);
    const c: number = this.colOf(i);
    if (r > 0) {
      out.push(i - N);
    }
    if (r < N - 1) {
      out.push(i + N);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < N - 1) {
      out.push(i + 1);
    }
    return out;
  }

  private flip(b: boolean[], i: number): void {
    b[i] = !b[i];
    const ns: number[] = this.nbrs(i);
    for (let k = 0; k < ns.length; k++) {
      b[ns[k]] = !b[ns[k]];
    }
  }

  private litCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.on[i]) {
        n++;
      }
    }
    return n;
  }

  private reset(): void {
    const b: boolean[] = new Array<boolean>(CELLS).fill(false);
    const order: number[] = shuffled(CELLS);
    const taps: number = MIN_TAPS + Math.floor(Math.random() * (MAX_TAPS - MIN_TAPS + 1));
    for (let i = 0; i < taps; i++) {
      this.flip(b, order[i]);
    }
    this.on = b;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点任意一格：它和上下左右一起翻转');
    this.startAt = Date.now();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'lights_out',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : Math.max(0, 300 - this.litCount() * 20),
      durationMs: Date.now() - this.startAt,
      levelReached: CELLS - this.litCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    if (this.litCount() === 0) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 全盘熄灭，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG2('步数用尽，还剩 {0} 盏亮着', String(this.litCount()));
      this.finish(false);
      return;
    }
    this.tip = TG2('还剩 {0} 盏亮着', String(this.litCount()));
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const nb: boolean[] = this.on.slice();
    this.flip(nb, i);
    this.on = nb;
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
        Text((TG('亮灯'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.litCount()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已灭'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(CELLS - this.litCount()) + '/' + String(CELLS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Text(this.on[(r * N + c)] ? '💡' : '')
              .fontSize(FontSize.xl)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.on[(r * N + c)] ? '#33F59E0B' : (this.theme.isDark ? '#111111' : '#DDE3EC'))
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.on[(r * N + c)] ? Palette.amber : this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              this.tap((r * N + c));
              })
            }, (c: number) => 'oc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'or' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG('目标：全部熄灭。点一格会连带翻转上下左右四格'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.sky)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
