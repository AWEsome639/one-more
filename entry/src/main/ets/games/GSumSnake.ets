/**
 * 数蛇 sum_snake（4×4）—— 从蛇头出发沿相邻格延伸，路径上数字之和正好等于目标
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：和 = 目标 ⇒ 通关；和 > 目标 ⇒ 撑爆失败（数字全为正，只能回退）
 * 进度：当前和 ／ 目标 ／ 步数
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4;
const CELLS: number = N * N;

function tint(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#33') + hex.substring(1);
}

@Component
export struct GSumSnake {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State nums: number[] = [];
  @State path: number[] = [];
  @State target: number = 0;
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
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    if (r > 0) {
      out.push(i - this.diffTotal);
    }
    if (r < this.diffTotal - 1) {
      out.push(i + this.diffTotal);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < this.diffTotal - 1) {
      out.push(i + 1);
    }
    return out;
  }

  private adjacent(a: number, b: number): boolean {
    return this.nbrs(a).indexOf(b) >= 0;
  }

  private sumOf(p: number[]): number {
    let s: number = 0;
    for (let i = 0; i < p.length; i++) {
      s += this.nums[p[i]];
    }
    return s;
  }

  private reset(): void {
    const nums: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      nums.push(1 + Math.floor(Math.random() * 9));
    }
    // 随机自避路径：它的和就是目标 ⇒ 保证有解
    const head: number = Math.floor(Math.random() * CELLS);
    const p: number[] = [head];
    const want: number = 4 + Math.floor(Math.random() * 4);
    let guard: number = 0;
    while (p.length < want && guard < 200) {
      guard++;
      const cur: number = p[p.length - 1];
      const free: number[] = this.nbrs(cur).filter((k: number) => p.indexOf(k) < 0);
      if (free.length === 0) {
        break;
      }
      p.push(free[Math.floor(Math.random() * free.length)]);
    }
    let sum: number = 0;
    for (let i = 0; i < p.length; i++) {
      sum += nums[p[i]];
    }
    this.nums = nums;
    this.path = [head];
    this.target = sum;
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const p: number[] = this.path.slice();
    if (p.length > 1 && p[p.length - 1] === i) {
      p.pop();                       // 点蛇尾 = 回退一格
      this.path = p;
      return;
    }
    if (p.indexOf(i) >= 0) {
      return;
    }
    const last: number = p[p.length - 1];
    if (!this.adjacent(last, i)) {
      return;
    }
    p.push(i);
    this.path = p;
    this.steps++;
    const s: number = this.sumOf(p);
    if (s === this.target) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      const extra: number = p.length > 3 ? p.length - 3 : 0;
      this.score = Math.max(60, 320 - sec * 2 - extra * 15);
      this.finish(true);
      return;
    }
    if (s > this.target) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'sum_snake',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.path.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("正好等于目标 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '超过目标，蛇撑爆了';
    }
    return TG('点相邻格延伸；点蛇尾回退一格');
  }

  private cellBg(i: number): string {
    if (this.path.indexOf(i) >= 0) {
      return tint(Palette.cyan, this.theme.isDark);
    }
    return this.theme.surface;
  }

  private cellLine(i: number): string {
    const idx: number = this.path.indexOf(i);
    if (idx === 0) {
      return Palette.cyan;
    }
    const last: number = this.path[this.path.length - 1];
    if (i === last && this.path.length > 1) {
      return Palette.berry;
    }
    return this.theme.line;
  }

  private cellLineW(i: number): number {
    const idx: number = this.path.indexOf(i);
    if (idx === 0) {
      return 2;
    }
    const last: number = this.path[this.path.length - 1];
    return (i === last && this.path.length > 1) ? 2 : 1;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('当前和'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.sumOf(this.path))))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.target), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.steps), this.langCode))
        .fontSize(FontSize.lg)
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
              Text(String(this.nums[(r * this.diffTotal + c)]))
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.path.indexOf((r * this.diffTotal + c)) >= 0 ? Palette.primaryDeep : this.theme.inkSoft)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({ width: this.cellLineW((r * this.diffTotal + c)), color: this.cellLine((r * this.diffTotal + c)) })
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
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.tip())
          .fontSize(FontSize.sm)
          .fontColor(this.over
            ? (this.won ? Palette.emerald : Palette.rose)
            : this.theme.inkSoft)
          .layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('🐍 蛇头在外框高亮；紫色外框是蛇尾（点它回退）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
