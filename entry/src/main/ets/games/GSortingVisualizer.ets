/**
 * 排序可视化 —— 看排序算法跳舞
 *
 * 玩法：12 根柱子随机高低，选一个算法（冒泡/插入/选择/快速），
 *       自动或单步播放每一次「比较」与「交换」，橙色 = 正在比，绿色 = 已排好。
 * 结算：整列排好 ⇒ 通关，比较/交换越少分越高。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface Op {
  a: number;
  b: number;
  swap: boolean;
}

const COUNT: number = 12;
const TICK_MS: number = 150;
const MIN_V: number = 8;
const MAX_V: number = 76;
const ALGOS: string[] = [TG('冒泡'), TG('插入'), TG('选择'), TG('快速')];
const ALGO_IDX: number[] = [0, 1, 2, 3];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const BTN_H: number = 42;

@Component
export struct GSortingVisualizer {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：COUNT 按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(COUNT);
  onFinish: (r: GameResult) => void = () => {};

  @State private arr: number[] = [];
  @State private algo: number = 0;
  @State private pc: number = 0;
  @State private total: number = 0;
  @State private comps: number = 0;
  @State private swaps: number = 0;
  @State private markA: number = -1;
  @State private markB: number = -1;
  @State private sorted: boolean = false;
  @State private running: boolean = false;
  @State private msg: string = '';

  private ops: Op[] = [];
  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(COUNT);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.running = false;
  }

  private reset(): void {
    this.stopLoop();
    const a: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      a.push(MIN_V + Math.floor(Math.random() * (MAX_V - MIN_V + 1)));
    }
    this.arr = a;
    this.ops = [];
    this.total = 0;
    this.pc = 0;
    this.comps = 0;
    this.swaps = 0;
    this.markA = -1;
    this.markB = -1;
    this.sorted = false;
    this.finished = false;
    this.msg = TG2('选算法，点「开始」看{0}排序', ALGOS[this.algo]);
    this.buildOps();
    this.startAt = Date.now();
  }

  private push(a: number, b: number, isSwap: boolean): void {
    const op: Op = { a: a, b: b, swap: isSwap };
    this.ops.push(op);
  }

  /** 先在副本上跑一遍，把「比较/交换」录成操作表，再照着动画播放 */
  private buildOps(): void {
    const v: number[] = this.arr.slice();
    this.ops = [];
    if (this.algo === 0) {
      for (let i = 0; i < this.diffTotal - 1; i++) {
        for (let j = 0; j < this.diffTotal - 1 - i; j++) {
          this.push(j, j + 1, false);
          if (v[j] > v[j + 1]) {
            const t: number = v[j];
            v[j] = v[j + 1];
            v[j + 1] = t;
            this.push(j, j + 1, true);
          }
        }
      }
    } else if (this.algo === 1) {
      for (let i = 1; i < this.diffTotal; i++) {
        let j: number = i;
        while (j > 0) {
          this.push(j - 1, j, false);
          if (v[j - 1] > v[j]) {
            const t: number = v[j - 1];
            v[j - 1] = v[j];
            v[j] = t;
            this.push(j - 1, j, true);
            j--;
          } else {
            break;
          }
        }
      }
    } else if (this.algo === 2) {
      for (let i = 0; i < this.diffTotal - 1; i++) {
        let m: number = i;
        for (let j = i + 1; j < this.diffTotal; j++) {
          this.push(m, j, false);
          if (v[j] < v[m]) {
            m = j;
          }
        }
        if (m !== i) {
          const t: number = v[i];
          v[i] = v[m];
          v[m] = t;
          this.push(i, m, true);
        }
      }
    } else {
      this.quickOps(v, 0, this.diffTotal - 1);
    }
    this.total = this.ops.length;
  }

  private quickOps(v: number[], lo: number, hi: number): void {
    if (lo >= hi) {
      return;
    }
    const pivot: number = v[hi];
    let i: number = lo;
    for (let j = lo; j < hi; j++) {
      this.push(j, hi, false);
      if (v[j] < pivot) {
        if (i !== j) {
          const t: number = v[i];
          v[i] = v[j];
          v[j] = t;
          this.push(i, j, true);
        }
        i++;
      }
    }
    if (i !== hi) {
      const t2: number = v[i];
      v[i] = v[hi];
      v[hi] = t2;
      this.push(i, hi, true);
    }
    this.quickOps(v, lo, i - 1);
    this.quickOps(v, i + 1, hi);
  }

  private play(): void {
    if (this.sorted) {
      return;
    }
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.running = true;
    this.timer = setInterval(() => {
      this.step();
    }, TICK_MS);
  }

  private pause(): void {
    this.stopLoop();
  }

  private step(): void {
    if (this.sorted) {
      return;
    }
    if (this.pc >= this.ops.length) {
      this.done();
      return;
    }
    const op: Op = this.ops[this.pc];
    this.markA = op.a;
    this.markB = op.b;
    if (op.swap) {
      const next: number[] = this.arr.slice();
      const t: number = next[op.a];
      next[op.a] = next[op.b];
      next[op.b] = t;
      this.arr = next;
      this.swaps++;
    } else {
      this.comps++;
    }
    this.pc++;
    if (this.pc >= this.ops.length) {
      this.done();
    }
  }

  private done(): void {
    this.stopLoop();
    this.sorted = true;
    this.markA = -1;
    this.markB = -1;
    this.msg = TG2('🎉 {0}排好了', ALGOS[this.algo]);
    this.finish();
  }

  private finish(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const score: number = Math.max(100, 1200 - this.comps * 4 - this.swaps * 3);
    const r: GameResult = {
      gameId: 'sorting_visualizer',
      solved: true,
      score: score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.pc
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private pickAlgo(k: number): void {
    if (this.algo === k && !this.sorted && this.pc === 0) {
      return;
    }
    this.algo = k;
    this.reset();
  }

  private barColor(i: number): string {
    if (this.sorted) {
      return Palette.emerald;
    }
    if (i === this.markA) {
      return Palette.amber;
    }
    if (i === this.markB) {
      return Palette.rose;
    }
    return Palette.primary;
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('比较'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.comps), this.langCode))
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
        Text((TG('交换'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.swaps), this.langCode))
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
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.pc + '/' + this.total))
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

      Row({ space: Space.xs }) {
        ForEach(ALGO_IDX, (k: number) => {
          Text(ALGOS[k])
            .fontSize(FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.algo === k ? '#FFFFFF' : this.theme.inkSoft)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(34))
            .backgroundColor(this.algo === k ? Palette.amber : this.theme.surface)
            .borderRadius(Radius.sm)
            .onClick(() => {
              Haptics.tick();
              this.pickAlgo(k);
            })
        }, (k: number) => 'a' + k)
      }
      .width('100%')

      Row({ space: 2 }) {
        ForEach(SLOTS, (i: number) => {
          Column() {
          Row()
          .width('100%')
          .height(this.arr[(i)] + '%')
          .backgroundColor(this.barColor((i)))
          .borderRadius({ topLeft: Radius.xs, topRight: Radius.xs })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          Text(String(this.arr[(i)]))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
          .margin({ top: 2 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.End)
        }, (i: number) => 'b' + i)
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Bottom)

      Text(this.sorted
        ? this.msg + ' · 比较 ' + this.comps + ' 次，交换 ' + this.swaps + TG(' 次')
        : (this.running ? '播放中…' : '点「开始」播放；也可单步看每一次比较与交换'))
        .fontSize(FontSize.sm)
        .fontColor(this.sorted ? Palette.emerald : this.theme.inkSoft)

      Row({ space: Space.sm }) {
        Button(this.running ? TG('暂停') : TG('开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.running ? Palette.amber : Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.sorted)
          .onClick(() => {
            Haptics.tap();
            if (this.running) {
              this.pause();
            } else {
              this.play();
            }
          })
        Button(TG('单步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.sorted)
          .onClick(() => {
            Haptics.tap();
            this.pause();
            this.step();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
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
