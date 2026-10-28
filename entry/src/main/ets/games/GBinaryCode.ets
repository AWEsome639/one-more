/**
 * 二进制码 —— 8 个位开关拼出目标数
 *
 * 玩法：给出目标数（十进制 1~255），点亮 8 个位开关凑出它；凑对自动进下一关。
 * 胜负：60 秒内拼对 6 关 ⇒ 通关；时间归零还没拼够 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const BITS: number = 8;
const COLS: number = 4;
const GOAL: number = 6;          // 通关关数
const TIME_LIMIT: number = 60;   // 总秒数
const NEXT_MS: number = 620;
const TICK_MS: number = 1000;
const WEIGHTS: number[] = [128, 64, 32, 16, 8, 4, 2, 1];

@Component
export struct GBinaryCode {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private flag: boolean[] = new Array<boolean>(BITS).fill(false);
  @State private target: number = 0;
  @State private level: number = 1;
  @State private score: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(TIME_LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private timer: number = -1;
  private nextTo: number = -1;
  private finished: boolean = false;
  private rows: number[] = [0, 1];
  private cols: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBinaryCode')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.timeNow(TIME_LIMIT);   // 难度可能刚变过，必须重算
        this.reset();
  }

  aboutToDisappear(): void {
    this.clearAll();
  }

  private clearAll(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    this.clearAll();
    this.level = 1;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.newLevel(true);
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (!this.over) {
        this.left = this.left - 1;
        if (this.left <= 0) {
          this.left = 0;
          this.lose('⏰ 时间到，拼对 ' + String(this.level - 1) + TG(' 关'));
        }
      }
    }, TICK_MS);
  }

  private newLevel(first: boolean): void {
    this.target = 1 + Math.floor(Math.random() * 255);
    this.flag = new Array<boolean>(BITS).fill(false);
    this.msg = first
      ? '点亮开关凑出 ' + String(this.target)
      : TG('第 ') + String(this.level) + ' 关：凑出 ' + String(this.target);
  }

  private value(): number {
    let v: number = 0;
    for (let i = 0; i < BITS; i++) {
      if (this.flag[i]) {
        v += WEIGHTS[i];
      }
    }
    return v;
  }


  /**
   * ★ 2026-10-23 第二期：二进制码提示
   *
   * 玩法：8 个位（128..1）开关，拼出目标数。
   * 提示 = **找第一个"当前状态与目标二进制不一致"的位**，直接说它该是 0 还是 1。
   *   「第 3 位（值 32）现在应该是 1，你还没点亮」
   * ⇒ 精确、可执行，且每次只泄露一个位（不是整串答案）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const tgt: number = this.target;
    if (!(tgt > 0)) {
      return Hint.none('none');
    }
    for (let k = 0; k < BITS; k++) {
      const should: boolean = ((tgt >> (BITS - 1 - k)) & 1) === 1;
      if (this.flag[k] !== should) {
        const w: number = WEIGHTS[k];
        const pos: string = String(k + 1);
        const weight: string = String(w);
        if (should) {
          return Hint.make([k],
            TG2('第 {0} 位（值 {1}）应该是 1 —— 还没点亮', pos, weight),
            TG2('Bit {0} (value {1}) should be ON — it is still off', pos, weight), t0);
        }
        return Hint.make([k],
          TG2('第 {0} 位（值 {1}）应该是 0 —— 该关掉', pos, weight),
          TG2('Bit {0} (value {1}) should be OFF — turn it off', pos, weight), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 提示驱动：computeHint 每次给出"下一格" ⇒ 照它点
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.nextTo >= 0) {
      return true;              // ★ 正在换关的间隙，toggle 会被拒绝，等一等
    }
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length === 0) {
      return false;
    }
    this.toggle(r.cells[0]);
    return !this.over;
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
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private bitsText(): string {
    let s: string = '';
    for (let i = 0; i < BITS; i++) {
      s = s + (this.flag[i] ? '1' : '0');
    }
    return s;
  }

  private toggle(i: number): void {
    if (this.over || this.nextTo >= 0) {
      return;
    }
    const n: boolean[] = this.flag.slice();
    n[i] = !n[i];
    this.flag = n;
    const v: number = this.value();
    if (v === this.target) {
      this.clearLevel();
      return;
    }
    this.msg = TG2('当前 {0}（{1}）· ', String(v), this.bitsText()) +
      (v > this.target ? TG2('大了 {0}', String(v - this.target)) : TG2('还差 {0}', String(this.target - v)));
  }

  private clearLevel(): void {
    if (this.nextTo >= 0) {
      return;
    }
    this.score += 100 + Math.max(0, this.left * 2);
    if (this.level >= GOAL) {
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 拼对 {0} 关，通关！',Digits(String(GOAL), this.langCode));
      this.clearAll();
      this.finish(true);
      return;
    }
    this.msg = TG2('✅ {0} = {1}，下一关',Digits(String(this.target), this.langCode), this.bitsText());
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.level = this.level + 1;
      this.newLevel(false);
    }, NEXT_MS);
  }

  private lose(why: string): void {
    if (this.finished) {
      return;
    }
    this.over = true;
    this.won = false;
    this.msg = why;
    this.clearAll();
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'binary_code',
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
      HintBar({
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 时间条
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.full)
        Row()
          .width(this.left * 100 / this.total + '%')
          .height('100%')
          .backgroundColor(this.left <= 15 ? Palette.rose : Palette.primaryDeep)
          .borderRadius(Radius.full)
          .animation({ duration: Motion.base, curve: Motion.snap() })
      }
      .width('100%')
      .height(8)

      // 目标 + 当前二进制
      Column({ space: Space.xs }) {
        Text(Digits(String(this.target), this.langCode))
          .fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.value() === this.target ? Palette.emerald : Palette.primaryDeep)
        Text(this.bitsText() + '₂ = ' + String(this.value()) + '₁₀')
          .fontSize(FontSize.lg)
          .fontColor(this.theme.inkSoft)
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      // 8 个位开关
      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (c: number) => {
              this.bitCell(r * COLS + c)
            }, (c: number) => 'bc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'br' + r)
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(42))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        .onClick(() => {
          this.askHint();
        })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('提示：从左到右每位的权重是 128 64 32 16 8 4 2 1，亮 = 1、灭 = 0'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=关卡 1=剩余 2=得分 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('关卡') : (kind === 1 ? TG('剩余') : TG('得分')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.level + '/' + GOAL
        : (kind === 1 ? this.left + 's' : String(this.score)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 1 && this.left <= 15 ? Palette.rose : this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  bitCell(i: number) {
    Column({ space: 2 }) {
      Text(this.flag[i] ? '💡' : '⚫')
        .fontSize(FontSize.sm)
      Text(this.flag[i] ? '1' : '0')
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.flag[i] ? '#FFFFFF' : this.theme.inkFaint)
      Text(String(WEIGHTS[i]))
        .fontSize(FontSize.xxs)
        .fontColor(this.flag[i] ? '#FFFFFF' : this.theme.inkFaint)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: Space.sm, bottom: Space.sm })
    .backgroundColor(this.flag[i] ? Palette.primaryDeep : this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .scale({ x: this.flag[i] ? 1.03 : 1, y: this.flag[i] ? 1.03 : 1 })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.toggle(i); }); })
    .onClick(() => {
      Haptics.tick();
      this.toggle(i);
    })
  }
}
