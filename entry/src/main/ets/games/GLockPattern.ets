/**
 * 图案锁 —— 一笔连出图案 🎮
 *
 * 规则：3×3 九个点，系统先闪一遍图案，再按同样顺序点出来。
 * 胜负：连对 5 关（图案从 3 个点加到 7 个点）= 通关；点错一个 = 失败
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const DOTS: number = 9;
const MAXLVL: number = 5;
const PREVIEW_MS: number = 450;

@Component
export struct GLockPattern {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：DOTS 按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(DOTS);
  onFinish: (r: GameResult) => void = () => {};

  @State private target: number[] = [];
  @State private input: number[] = [];
  @State private lit: number = -1;      // 预览时点亮的点
  @State private phase: number = 0;     // 0=预览 1=作答 2=结束
  @State private lvl: number = 1;
  @State private peeks: number = 0;
  @State private won: boolean = false;

  private timer: number = -1;
  private delay: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.newGame();
  }

  aboutToDisappear(): void {
    this.stopAll();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(DOTS);
    this.newGame();
  }

  private stopAll(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.delay !== -1) {
      clearTimeout(this.delay);
      this.delay = -1;
    }
  }

  private newGame(): void {
    this.stopAll();
    this.lvl = 1;
    this.peeks = 0;
    this.won = false;
    this.startAt = Date.now();
    this.startLevel();
  }

  private startLevel(): void {
    this.stopAll();
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      pool.push(i);
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    this.target = pool.slice(0, 2 + this.lvl);
    this.input = [];
    this.preview();
  }

  /** 依次闪一遍图案，然后进入作答 */
  private preview(): void {
    this.stopAll();
    this.phase = 0;
    this.lit = -1;
    let k: number = 0;
    this.timer = setInterval(() => {
      if (k < this.target.length) {
        this.lit = this.target[k];
        k++;
      } else {
        this.stopAll();
        this.lit = -1;
        this.input = [];
        this.phase = 1;
      }
    }, PREVIEW_MS);
  }

  private peek(): void {
    if (this.phase !== 1) {
      return;
    }
    this.peeks++;
    this.preview();
  }

  private tapDot(i: number): void {
    if (this.phase !== 1) {
      return;
    }
    const k: number = this.input.length;
    if (this.target[k] !== i) {
      this.phase = 2;
      this.stopAll();
      this.finish(false);
      return;
    }
    const ni: number[] = this.input.slice();
    ni.push(i);
    this.input = ni;
    if (ni.length === this.target.length) {
      if (this.lvl >= MAXLVL) {
        this.phase = 2;
        this.won = true;
        this.finish(true);
      } else {
        this.phase = 0;
        this.delay = setTimeout(() => {
          this.delay = -1;
          this.lvl = this.lvl + 1;
          this.startLevel();
        }, 600);
      }
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'lock_pattern',
      solved: solved,
      score: solved ? Math.max(200, 1000 - this.peeks * 50) : (this.lvl - 1) * 150,
      durationMs: Date.now() - this.startAt,
      levelReached: this.lvl
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private dotColor(i: number): string {
    if (this.lit === i) {
      return Palette.sky;
    }
    if (this.input.indexOf(i) >= 0) {
      return Palette.emerald;
    }
    return this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.lg }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.lvl) + '/' + String(MAXLVL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('图案'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.target.length) + TG(' 点'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已连'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.input.length) + '/' + String(this.target.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.md }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.md }) {
            ForEach([0, 1, 2], (c: number) => {
              Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.dotColor((r * 3 + c)))
              .borderRadius(Radius.full)
              .border({
              width: 2,
              color: this.lit === (r * 3 + c) ? Palette.sky : (this.input.indexOf((r * 3 + c)) >= 0 ? Palette.emerald : this.theme.line)
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              this.tapDot((r * 3 + c));
              })
            }, (c: number) => 'd' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'pr' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.phase === 0 ? '👀 记住顺序…' :
        (this.phase === 1 ? '按顺序点出来（已连 ' + String(this.input.length) + TG(' 个）')
          : (this.won ? '🎉 五关全过！' : '❌ 点错了，重开一局')))
        .fontSize(FontSize.md)
        .fontColor(this.phase === 2 ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('再看一次'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(this.phase === 1)
          .onClick(() => {
            this.peek();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.sky).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .onClick(() => {
            this.newGame();
          })
      }
      .width('100%')

      Text(TG2('偷看 {0} 次（每次扣 50 分）',Digits(String(this.peeks), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }




}
