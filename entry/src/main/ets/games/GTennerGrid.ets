/**
 * 十格 tenner_grid（10×10）—— 每行每列都要恰好含 0~9 各一次（拉丁方）
 *
 * 操作：点空格选中 → 点数字键盘填入（再点同一个数字 = 擦掉）
 * 胜负：填满 100 格且无冲突 ⇒ 通关；冲突 3 次 ⇒ 失败（冲突的数不会落盘）
 * 进度：已填 x/100 ／ 冲突 x/3 ／ 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 10;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 13×13 = 169 格，原来只开 100）
const MAX_N: number = 13;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;
const GIVEN_RATE: number = 0.7;

function shuffled(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GTennerGrid {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=10；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(10);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State grid: number[] = [];
  @State fixed: number[] = [];
  @State sel: number = -1;
  @State errors: number = 0;
  @State placed: number = 0;
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
    this.diffTotal = GameDiff.sizeNow(10);
    this.reset();
  }

  private reset(): void {
    const rp: number[] = shuffled(this.diffTotal);
    const cp: number[] = shuffled(this.diffTotal);
    const vp: number[] = shuffled(this.diffTotal);
    const sol: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal; i++) {
      for (let j = 0; j < this.diffTotal; j++) {
        sol[rp[i] * this.diffTotal + cp[j]] = vp[(i + j) % this.diffTotal];
      }
    }
    const grid: number[] = new Array<number>(MAX_CELLS).fill(-1);
    const fixed: number[] = new Array<number>(MAX_CELLS).fill(0);
    let givens: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (Math.random() < GIVEN_RATE) {
        grid[i] = sol[i];
        fixed[i] = 1;
        givens++;
      }
    }
    let guard: number = 0;
    while (givens < 55 && guard < 400) {
      guard++;
      const i: number = Math.floor(Math.random() * CELLS);
      if (fixed[i] === 0) {
        grid[i] = sol[i];
        fixed[i] = 1;
        givens++;
      }
    }
    this.grid = grid;
    this.fixed = fixed;
    this.sel = -1;
    this.errors = 0;
    this.placed = givens;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 行/列里是否已经有这个数字 */
  private conflict(idx: number, d: number): boolean {
    const r: number = Math.floor(idx / this.diffTotal);
    const c: number = idx % this.diffTotal;
    for (let k = 0; k < this.diffTotal; k++) {
      if (k !== c && this.grid[r * this.diffTotal + k] === d) {
        return true;
      }
      if (k !== r && this.grid[k * this.diffTotal + c] === d) {
        return true;
      }
    }
    return false;
  }

  private place(d: number): void {
    if (this.over || this.sel < 0) {
      return;
    }
    const idx: number = this.sel;
    if (this.fixed[idx] === 1) {
      return;
    }
    const next: number[] = this.grid.slice();
    if (next[idx] === d) {
      next[idx] = -1;                 // 再点一次同一个数字 = 擦掉
      this.grid = next;
      this.placed--;
      return;
    }
    if (this.conflict(idx, d)) {
      this.errors++;
      if (this.errors >= ERR_MAX) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    const was: number = next[idx];
    next[idx] = d;
    this.grid = next;
    this.placed += was < 0 ? 1 : 0;
    if (this.placed === CELLS) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(80, 620 - this.errors * 90 - sec);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'tenner_grid',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.placed
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * ★ 2026-10-23 第二期：十格提示（唯一候选法）
   *
   * 规则：每行放 0..9 各一次；相邻两行同列不能相同（见 conflict）。
   * ⇒ 对每个空格，把 0..9 都试一遍 **用游戏自己的 conflict 判定**
   *   ⇒ 只剩一个合法数字时，它就确定了。
   *
   * 复用 conflict 的好处：提示与游戏本体永远同一把尺子。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      if (this.grid[i] > 0 || this.fixed[i] === 1) {
        continue;                      // 已填 / 题目给的，跳过
      }
      let only: number = -1;
      let cnt: number = 0;
      for (let d = 0; d < n; d++) {
        if (!this.conflict(i, d)) {
          cnt++;
          only = d;
          if (cnt > 1) {
            break;
          }
        }
      }
      if (cnt !== 1 || only < 0) {
        continue;
      }
      const r: number = Math.floor(i / n) + 1;
      const c: number = (i % n) + 1;
      return Hint.make([i],
        TG2('第 {0} 行第 {1} 列只能填 {2} —— 其它数字都会撞',
          String(r), String(c), String(only)),
        TG2('Row {0}, column {1} can only be {2} — every other digit clashes',
          String(r), String(c), String(only)), t0);
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第二期：AI 代打（十格，一次填一格）
   * 与提示同一套判据：唯一候选法。
   */
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const n: number = this.diffTotal;
    for (let i = 0; i < n * n; i++) {
      if (this.grid[i] > 0 || this.fixed[i] === 1) {
        continue;
      }
      let only: number = -1;
      let cnt: number = 0;
      for (let d = 0; d < n; d++) {
        if (!this.conflict(i, d)) {
          cnt++;
          only = d;
          if (cnt > 1) {
            break;
          }
        }
      }
      if (cnt === 1 && only >= 0) {
        this.sel = i;
        this.place(only);
        return !this.over;
      }
    }
    return false;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格是唯一的'));
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("整盘排好 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '冲突太多，本局失败';
    }
    return this.sel < 0 ? '先点一个空格，再点下面数字' : TG2("已选中第 {0} 行", String(Math.floor(this.sel / this.diffTotal) + 1));
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.placed) + '/' + String(CELLS)))
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
        Text((TG('冲突'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
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
              Text(this.grid[(r * this.diffTotal + c)] < 0 ? '' : String(this.grid[(r * this.diffTotal + c)]))
              .fontSize(FontSize.xxs)
              .fontWeight(this.fixed[(r * this.diffTotal + c)] === 1 ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.grid[(r * this.diffTotal + c)] < 0 ? this.theme.inkFaint : this.theme.ink).animation({ duration: Motion.fast, curve: Motion.snap() })
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.fixed[(r * this.diffTotal + c)] === 1 ? this.theme.surfaceAlt : this.theme.surface)
              .borderRadius(Radius.xs)
              .border({
              width: this.sel === (r * this.diffTotal + c) ? 2 : 1,
              color: this.sel === (r * this.diffTotal + c) ? Palette.violet : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              if (this.over) {
              return;
              }
              this.sel = (r * this.diffTotal + c);
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(38))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
            Haptics.tick();
            this.place((d));
            })
          }, (d: number) => 'd' + d)
        }
        .width('100%')
        Row({ space: Space.xs }) {
          ForEach([5, 6, 7, 8, 9], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(38))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
            Haptics.tick();
            this.place((d));
            })
          }, (d: number) => 'e' + d)
        }
        .width('100%')
      }
      .width('100%')

      Text(this.tip())
        .fontSize(FontSize.xs)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%')

      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.berry)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('每行每列都要有 0~9 各一次；灰底是题目给的数'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }






}
