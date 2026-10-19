/**
 * 二进制天平 —— 只用 2 的幂砝码称重
 *
 * 玩法：右盘只有 1/2/4/8/16/32/64 各一枚，每枚「放=1、不放=0」，
 *       把开关拨到加起来刚好等于物体重量。
 * 胜负：连过 6 关 ⇒ 通关；任何一关超重 ⇒ 天平翻，立刻失败。
 * 出题：目标 = 随机几枚砝码之和 ⇒ 一定是二的幂之和，必有解。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const WEIGHTS: number[] = [1, 2, 4, 8, 16, 32, 64];
const COUNT: number = 7;
const LEVELS: number = 6;
const TICK_MS: number = 1000;

@Component
export struct GBinaryScaleBalance {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private on: boolean[] = new Array<boolean>(COUNT).fill(false);
  @State private target: number = 0;
  @State private level: number = 1;
  @State private score: number = 0;
  @State private seconds: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;
  private rowA: number[] = [0, 1, 2, 3];
  private rowB: number[] = [4, 5, 6];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTick();
  }

  private stopTick(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private reset(): void {
    this.stopTick();
    this.level = 1;
    this.score = 0;
    this.seconds = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.newLevel(true);
    this.timer = setInterval(() => {
      if (!this.over) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private newLevel(first: boolean): void {
    let t: number = 0;
    let picked: number = 0;
    while (picked < 2) {                       // 至少两枚，避免一开始就太简单
      t = 0;
      picked = 0;
      for (let i = 0; i < COUNT; i++) {
        if (Math.random() < 0.5) {
          t += WEIGHTS[i];
          picked = picked + 1;
        }
      }
    }
    this.target = t;
    this.on = new Array<boolean>(COUNT).fill(false);
    this.msg = first
      ? '拨开关，把右盘凑到 ' + String(t)
      : TG('第 ') + String(this.level) + ' 关：凑到 ' + String(t);
  }

  private sum(): number {
    let s: number = 0;
    for (let i = 0; i < COUNT; i++) {
      if (this.on[i]) {
        s += WEIGHTS[i];
      }
    }
    return s;
  }

  /** 当前选中的砝码写成二进制串（高位在左），顺带展示「这就是二进制」 */
  private bitsText(): string {
    let s: string = '';
    for (let i = COUNT - 1; i >= 0; i--) {
      s = s + (this.on[i] ? '1' : '0');
    }
    return s;
  }

  private expr(): string {
    let s: string = '';
    for (let i = 0; i < COUNT; i++) {
      if (this.on[i]) {
        s = s === '' ? String(WEIGHTS[i]) : s + ' + ' + WEIGHTS[i];
      }
    }
    return s === '' ? '空盘' : s;
  }

  private toggle(i: number): void {
    if (this.over) {
      return;
    }
    const n: boolean[] = this.on.slice();
    n[i] = !n[i];
    this.on = n;
    const s: number = this.sum();
    if (s === this.target) {
      this.clearLevel();
      return;
    }
    if (s > this.target) {
      this.over = true;
      this.won = false;
      this.msg = TG2('💥 右盘 {0} 比物体 {1} 重，天平翻了', String(s), String(this.target));
      this.stopTick();
      this.finish(false);
      return;
    }
    this.msg = TG2('右盘 {0} · 还差 {1}', String(s), String(this.target - s));
  }

  private clearLevel(): void {
    this.score += 150 + Math.max(0, 120 - this.seconds * 4);
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 连过 {0} 关，全部称准！',Digits(String(this.diffTotal), this.langCode));
      this.stopTick();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.level = this.level + 1;
    this.newLevel(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'binary_scale_balance',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.level
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 天平
      Row({ space: Space.sm }) {
        this.pan(0)
        Text('⚖️').accessibilityLevel('no').fontSize(FontSize.xxl)
        this.pan(1)
      }
      .width('100%')

      // 七个二进制开关
      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          ForEach(this.rowA, (i: number) => {
            this.sw(i)
          }, (i: number) => 'sa' + i)
        }
        .width('100%')
        Row({ space: Space.sm }) {
          ForEach(this.rowB, (i: number) => {
            this.sw(i)
          }, (i: number) => 'sb' + i)
        }
        .width('100%')
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('提示：右盘一旦超过物体重量，天平就翻了 —— 本局结束'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=关卡 1=得分 2=用时 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('关卡') : (kind === 1 ? TG('得分') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.level + '/' + this.diffTotal
        : (kind === 1 ? String(this.score) : this.seconds + 's'))
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

  /** kind: 0=物体 1=右盘 */
  @Builder
  pan(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '📦 物体' : '🧱 右盘')
        .fontSize(FontSize.xs)
        .fontColor(this.theme.inkFaint)
      Text(String(kind === 0 ? this.target : this.sum()))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 ? Palette.teal : Palette.berry)
      Text(kind === 0 ? '重量' : this.bitsText() + '₂')
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .layoutWeight(1)
    .padding(Space.md)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.lg)
    .border({ width: 2, color: kind === 0 ? Palette.teal : this.theme.line })
    .shadow(Shadow.card)
  }

  @Builder
  sw(i: number) {
    Column({ space: 2 }) {
      Text(this.on[i] ? '1' : '0')
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.on[i] ? '#FFFFFF' : this.theme.inkFaint)
      Text(String(WEIGHTS[i]))
        .fontSize(FontSize.sm)
        .fontColor(this.on[i] ? '#FFFFFF' : this.theme.ink)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: Space.sm, bottom: Space.sm })
    .backgroundColor(this.on[i] ? Palette.berry : this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scale({ x: this.on[i] ? 1.04 : 1, y: this.on[i] ? 1.04 : 1 })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.toggle(i);
    })
  }
}
