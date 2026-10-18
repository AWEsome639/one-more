/**
 * 数墙 nurikabe（5×5）—— 按数字造墙：每个数字是一块恰含该格数的"岛"，其余格涂黑成连通墙
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：岛格数全对 + 墙连通无 2×2 ⇒ solved:true；不可逆错手 3 次 ⇒ solved:false
 * 进度：已满足提示 ／ 黑格数 ／ 错手数
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，
//   而数组原来按 CELLS = 25 开 ⇒【困难档必越界】✗）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;

/** 3 关提示（数字 = 该岛格数，0 = 无提示）；每关都有合法解 */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    0,3,0,0,0,
    0,0,0,0,0,
    3,0,0,0,2,
    0,0,0,0,0,
    3,0,0,0,0
  ],
  // 第 2 关
  [
    3,0,1,0,2,
    0,0,0,0,0,
    0,0,2,0,0,
    0,0,0,0,0,
    0,2,0,0,1
  ],
  // 第 3 关
  [
    2,0,0,2,0,
    0,0,0,0,0,
    2,0,0,0,0,
    0,0,0,4,0,
    0,1,0,0,0
  ]
];

@Component
export struct GNurikabe {
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
  @State blacks: number[] = [];   // 1 = 涂黑（墙）
  @State clueTotal: number = 0;
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
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.blacks = new Array<number>(MAX_CELLS).fill(0);
    let t: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.clues[i] > 0) {
        t++;
      }
    }
    this.clueTotal = t;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private pushCell(arr: number[], seen: number[], queue: number[], j: number, val: number): void {
    if (arr[j] === val && seen[j] === 0) {
      seen[j] = 1;
      queue.push(j);
    }
  }

  /** 同色连通块（val=0 白 / val=1 黑） */
  private flood(arr: number[], start: number, seen: number[], val: number): number[] {
    const comp: number[] = [];
    const queue: number[] = [start];
    seen[start] = 1;
    let head: number = 0;
    while (head < queue.length) {
      const cur: number = queue[head];
      head++;
      comp.push(cur);
      const r: number = Math.floor(cur / this.diffTotal);
      const c: number = cur % this.diffTotal;
      if (r > 0) {
        this.pushCell(arr, seen, queue, cur - this.diffTotal, val);
      }
      if (r < this.diffTotal - 1) {
        this.pushCell(arr, seen, queue, cur + this.diffTotal, val);
      }
      if (c > 0) {
        this.pushCell(arr, seen, queue, cur - 1, val);
      }
      if (c < this.diffTotal - 1) {
        this.pushCell(arr, seen, queue, cur + 1, val);
      }
    }
    return comp;
  }

  /** 白区统计：返回 [提示个数, 目标格数] */
  private whiteInfo(arr: number[], comp: number[]): number[] {
    let clues: number = 0;
    let target: number = 0;
    for (let j = 0; j < comp.length; j++) {
      const cl: number = this.clues[comp[j]];
      if (cl > 0) {
        clues++;
        target = cl;
      }
    }
    return [clues, target];
  }

  /** 不可逆违规：2×2 全黑 ／ 已成形的岛超出自己的提示格数 */
  private violations(arr: number[]): boolean {
    for (let r = 0; r < this.diffTotal - 1; r++) {
      for (let c = 0; c < this.diffTotal - 1; c++) {
        const a: number = r * this.diffTotal + c;
        if (arr[a] === 1 && arr[a + 1] === 1 && arr[a + this.diffTotal] === 1 && arr[a + this.diffTotal + 1] === 1) {
          return true;
        }
      }
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (arr[i] === 1 || seen[i] === 1) {
        continue;
      }
      const comp: number[] = this.flood(arr, i, seen, 0);
      const info: number[] = this.whiteInfo(arr, comp);
      if (info[0] === 1 && comp.length > info[1]) {
        return true;
      }
    }
    return false;
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1) {
        n++;
      }
    }
    return n;
  }

  private isWin(): boolean {
    if (this.violations(this.blacks)) {
      return false;
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1 || seen[i] === 1) {
        continue;
      }
      const comp: number[] = this.flood(this.blacks, i, seen, 0);
      const info: number[] = this.whiteInfo(this.blacks, comp);
      if (info[0] !== 1 || comp.length !== info[1]) {
        return false;
      }
    }
    let first: number = -1;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1) {
        first = i;
        break;
      }
    }
    if (first < 0) {
      return false;
    }
    const bseen: number[] = new Array<number>(MAX_CELLS).fill(0);
    const comp: number[] = this.flood(this.blacks, first, bseen, 1);
    return comp.length === this.blackCount();
  }

  private clueOk(i: number): boolean {
    if (this.clues[i] === 0) {
      return false;
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    const comp: number[] = this.flood(this.blacks, i, seen, 0);
    const info: number[] = this.whiteInfo(this.blacks, comp);
    return info[0] === 1 && comp.length === info[1];
  }

  private solvedClues(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.clues[i] > 0 && this.clueOk(i)) {
        n++;
      }
    }
    return n;
  }

  private tap(i: number): void {
    if (this.over || this.clues[i] > 0) {
      return;      // 提示格固定是岛，不可涂黑
    }
    const next: number[] = this.blacks.slice();
    next[i] = next[i] === 1 ? 0 : 1;
    if (this.violations(next)) {
      this.errors++;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.blacks = next;
    if (this.isWin()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(60, 380 - this.errors * 50 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'nurikabe',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.solvedClues()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    if (this.blacks[i] === 1) {
      return this.theme.isDark ? '#E2E8F0' : '#1E293B';
    }
    return this.clues[i] > 0 ? this.theme.surface : this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已满足提示'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.solvedClues()) + '/' + String(this.clueTotal)))
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
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount())))
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
              .fontColor(this.clueOk((r * this.diffTotal + c)) ? Palette.emerald : Palette.primaryDeep)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({ width: 1, color: this.theme.line })
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
          ? (this.won ? '岛与墙都对了 🎉 得分 ' + String(this.score) : '墙破岛溢，本局失败')
          : '点亮格子涂黑：数字格是岛，其余格成一片连通墙')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.berry)
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
