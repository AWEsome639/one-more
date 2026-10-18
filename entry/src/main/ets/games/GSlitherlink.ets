/**
 * 数回环 slitherlink（5×5）—— 画一条闭合回路，使每格数字 = 该格四边中被画上的边数
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：线索全对 + 回路闭合且只有一个环 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已满足线索 ／ 已画边数 ／ 已用步数
 *
 * 棋盘是 (2N+1)×(2N+1) 的网格：偶偶 = 顶点，偶奇 = 横边，奇偶 = 竖边，奇奇 = 格子
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const NC: number = 5;                       // 5×5 格
const CELLS: number = NC * NC;
const HE_CNT: number = (NC + 1) * NC;       // 横边 30
const VE_CNT: number = NC * (NC + 1);       // 竖边 30
const VN: number = NC + 1;                  // 每行顶点数 6
const V_CNT: number = VN * VN;
const STEP_BUDGET: number = 120;
const BAR: number = Space.xs;               // 已画边的粗细
const THIN: number = 2;                     // 未画边的淡引导线
const DOT: number = 4;                      // 顶点小点

/** 3 关线索（0~4，格子四边中被画的边数） */
/** 显示网格的 11 个下标 */
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    3,2,2,2,2,
    2,2,3,1,2,
    3,1,2,0,1,
    2,2,3,2,2,
    1,3,1,1,1
  ],
  // 第 2 关
  [
    2,1,3,2,3,
    2,1,3,2,2,
    3,1,2,1,1,
    3,1,3,2,2,
    2,3,1,1,1
  ],
  // 第 3 关
  [
    2,3,1,0,0,
    2,3,0,0,0,
    2,2,2,1,0,
    2,2,2,2,1,
    0,1,2,3,1
  ]
];

@Component
export struct GSlitherlink {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 STEP_BUDGET=120
  @State private diffTotal: number = GameDiff.livesNow(120);
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State he: number[] = [];        // 横边是否画上
  @State ve: number[] = [];        // 竖边是否画上
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
    this.diffTotal = GameDiff.livesNow(120);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.he = new Array<number>(HE_CNT).fill(0);
    this.ve = new Array<number>(VE_CNT).fill(0);
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 顶点度数（只有 0 或 2 才是合法回路） */
  private deg(v: number): number {
    const r: number = Math.floor(v / VN);
    const c: number = v % VN;
    let d: number = 0;
    if (c > 0 && this.he[r * NC + c - 1] === 1) {
      d++;
    }
    if (c < NC && this.he[r * NC + c] === 1) {
      d++;
    }
    if (r > 0 && this.ve[(r - 1) * (NC + 1) + c] === 1) {
      d++;
    }
    if (r < NC && this.ve[r * (NC + 1) + c] === 1) {
      d++;
    }
    return d;
  }

  /** 从顶点 v 沿 dir（0左 1右 2上 3下）走到另一端，无边返回 -1 */
  private otherEnd(v: number, dir: number): number {
    const r: number = Math.floor(v / VN);
    const c: number = v % VN;
    if (dir === 0) {
      return (c > 0 && this.he[r * NC + c - 1] === 1) ? v - 1 : -1;
    }
    if (dir === 1) {
      return (c < NC && this.he[r * NC + c] === 1) ? v + 1 : -1;
    }
    if (dir === 2) {
      return (r > 0 && this.ve[(r - 1) * (NC + 1) + c] === 1) ? v - VN : -1;
    }
    return (r < NC && this.ve[r * (NC + 1) + c] === 1) ? v + VN : -1;
  }

  private pushNbr(v: number, seen: number[], queue: number[]): void {
    for (let d = 0; d < 4; d++) {
      const w: number = this.otherEnd(v, d);
      if (w >= 0 && seen[w] === 0) {
        seen[w] = 1;
        queue.push(w);
      }
    }
  }

  private edgeCount(): number {
    let n: number = 0;
    for (let k = 0; k < HE_CNT; k++) {
      if (this.he[k] === 1) {
        n++;
      }
    }
    for (let k = 0; k < VE_CNT; k++) {
      if (this.ve[k] === 1) {
        n++;
      }
    }
    return n;
  }

  private clueCount(i: number): number {
    const r: number = Math.floor(i / NC);
    const c: number = i % NC;
    let n: number = 0;
    if (this.he[r * NC + c] === 1) {
      n++;
    }
    if (this.he[(r + 1) * NC + c] === 1) {
      n++;
    }
    if (this.ve[r * (NC + 1) + c] === 1) {
      n++;
    }
    if (this.ve[r * (NC + 1) + c + 1] === 1) {
      n++;
    }
    return n;
  }

  private clueOk(i: number): boolean {
    return this.clueCount(i) === this.clues[i];
  }

  private solvedClues(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.clueOk(i)) {
        n++;
      }
    }
    return n;
  }

  private isWin(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (!this.clueOk(i)) {
        return false;
      }
    }
    let used: number = 0;
    let start: number = -1;
    for (let v = 0; v < V_CNT; v++) {
      const d: number = this.deg(v);
      if (d !== 0 && d !== 2) {
        return false;                // 有分叉或有断头
      }
      if (d === 2) {
        used++;
        if (start < 0) {
          start = v;
        }
      }
    }
    if (used < 4 || this.edgeCount() !== used) {
      return false;
    }
    const seen: number[] = new Array<number>(V_CNT).fill(0);
    const queue: number[] = [start];
    seen[start] = 1;
    let head: number = 0;
    let visited: number = 0;
    while (head < queue.length) {
      const v: number = queue[head];
      head++;
      visited++;
      this.pushNbr(v, seen, queue);
    }
    return visited === used;         // 恰好一个环
  }

  private toggle(kind: number, idx: number): void {
    if (this.over) {
      return;
    }
    if (kind === 0) {
      const he: number[] = this.he.slice();
      he[idx] = he[idx] === 1 ? 0 : 1;
      this.he = he;
    } else {
      const ve: number[] = this.ve.slice();
      ve[idx] = ve[idx] === 1 ? 0 : 1;
      this.ve = ve;
    }
    this.steps++;
    if (this.isWin()) {
      this.over = true;
      this.won = true;
      this.score = Math.max(120, 700 - this.steps * 3);
      this.finish(true);
      return;
    }
    if (this.steps >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'slitherlink',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.solvedClues()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 显示网格 (gr,gc) 对应的格子/边下标 */
  private cellIdx(gr: number, gc: number): number {
    return Math.floor((gr - 1) / 2) * NC + Math.floor((gc - 1) / 2);
  }

  private clueInk(gr: number, gc: number): string {
    return this.clueOk(this.cellIdx(gr, gc)) ? Palette.emerald : this.theme.ink;
  }

  private isVertex(gr: number, gc: number): boolean {
    return gr % 2 === 0 && gc % 2 === 0;
  }

  private isHEdge(gr: number, gc: number): boolean {
    return gr % 2 === 0 && gc % 2 === 1;
  }

  private isVEdge(gr: number, gc: number): boolean {
    return gr % 2 === 1 && gc % 2 === 0;
  }

  private heOn(gr: number, gc: number): boolean {
    return this.he[Math.floor(gr / 2) * NC + Math.floor((gc - 1) / 2)] === 1;
  }

  private veOn(gr: number, gc: number): boolean {
    return this.ve[Math.floor((gr - 1) / 2) * (NC + 1) + Math.floor(gc / 2)] === 1;
  }

  private gridTap(gr: number, gc: number): void {
    if (this.isHEdge(gr, gc)) {
      this.toggle(0, Math.floor(gr / 2) * NC + Math.floor((gc - 1) / 2));
    } else if (this.isVEdge(gr, gc)) {
      this.toggle(1, Math.floor((gr - 1) / 2) * (NC + 1) + Math.floor(gc / 2));
    }
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已满足线索'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.solvedClues()) + '/' + String(CELLS)))
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
        Text((TG('已画边'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.edgeCount())))
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
        Text((String(this.steps) + '/' + String(this.diffTotal)))
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

      Column() {
        ForEach(IDX, (gr: number) => {
          Row() {
            ForEach(IDX, (gc: number) => {
              Stack() {
              if (this.isVertex((gr), (gc))) {
              Text('')
              .width(DOT)
              .height(DOT)
              .backgroundColor(this.theme.lineSoft)
              .borderRadius(Radius.full)
              } else if (this.isHEdge((gr), (gc))) {
              Text('')
              .width('100%')
              .height(this.heOn((gr), (gc)) ? BAR : THIN).animation({ duration: Motion.fast, curve: Motion.snap() })
              .backgroundColor(this.heOn((gr), (gc)) ? Palette.primaryDeep : this.theme.line)
              .borderRadius(Radius.full)
              } else if (this.isVEdge((gr), (gc))) {
              Text('')
              .width(this.veOn((gr), (gc)) ? BAR : THIN)
              .height('100%')
              .backgroundColor(this.veOn((gr), (gc)) ? Palette.primaryDeep : this.theme.line)
              .borderRadius(Radius.full)
              } else {
              Text(String(this.clues[this.cellIdx((gr), (gc))]))
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.clueInk((gr), (gc)))
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              this.gridTap((gr), (gc));
              })
            }, (gc: number) => 'g' + gc)
          }
          .width('100%')
        }, (gr: number) => 'gr' + gr)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '回路闭合 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点边线切换；数字变绿说明这一格满足了')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.lime)
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
