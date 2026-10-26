/**
 * 进制转换 —— 限时进制换算
 *
 * 玩法：十进制 ⇄ 2/8/16 进制互转，四选一；答对连击加分，答错扣 3 秒。
 * 胜负：60 秒内答对 10 题 ⇒ 通关；时间归零还没达标 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';

const TIME_LIMIT: number = 60;   // 总秒数
const GOAL: number = 10;         // 通关需答对题数
const PICK: number = 4;          // 选项数
const NEXT_MS: number = 560;     // 答完到下一题
const PENALTY: number = 3;       // 答错扣秒
const TICK_MS: number = 1000;
const BASES: number[] = [2, 8, 16];
const SUBS: string[] = ['₂', '₈', '₁₆'];
const LETTERS: string[] = ['A', 'B', 'C', 'D'];
const DIGITS: string = '0123456789ABCDEF';

/** 自己写进制转换，不依赖 Number.toString(radix) */
function toBase(n: number, b: number): string {
  if (n <= 0) {
    return '0';
  }
  let v: number = n;
  let out: string = '';
  while (v > 0) {
    out = DIGITS.charAt(v % b) + out;
    v = Math.floor(v / b);
  }
  return out;
}

@Component
export struct GBaseConversionRun {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private opts: string[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  /** ★ 提示用：当前题的目标进制 / 数值 / 方向（true = 十进制转过去） */
  @State private curBase: number = 2;
  @State private curN: number = 0;
  @State private curToBase: boolean = true;
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private combo: number = 0;
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
  private optsIdx: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
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
    this.right = 0;
    this.wrong = 0;
    this.combo = 0;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.ask();
    this.msg = TG2("把进制换算对，答错扣 {0} 秒",Digits(String(PENALTY), this.langCode));
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.tick();
    }, TICK_MS);
  }

  private tick(): void {
    if (this.over) {
      return;
    }
    this.left = this.left - 1;
    if (this.left <= 0) {
      this.left = 0;
      this.lose(TG('⏰ 时间到，答对 ') + String(this.right) + ' 题，没到 ' + String(GOAL) + TG(' 题'));
    }
  }

  /** 出题：十进制 → b 进制 或 b 进制 → 十进制 */

  /**
   * ★ 2026-10-23 第二期：进制转换提示
   *
   * 提示**只给方法**，不给答案：
   *   十进制 → b 进制：「不断除以 {b}，把余数从下往上写」
   *   b 进制 → 十进制：「从右往左，每位乘 {b} 的幂再加起来」
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const b: number = this.curBase;
    if (!(b >= 2)) {
      return Hint.none('none');
    }
    if (this.curToBase) {
      return Hint.make([],
        TG2('十进制转 {0} 进制：把 {1} 不断除以 {0}，记下每次的余数，最后从下往上读',
          String(b), String(this.curN)),
        TG2('Decimal to base {0}: divide {1} by {0} repeatedly, keep the remainders, read them bottom-up',
          String(b), String(this.curN)), t0);
    }
    return Hint.make([],
      TG2('{0} 进制转十进制：从右往左，每一位乘 {0} 的幂再相加（最右是 {0}⁰）', String(b)),
      TG2('Base {0} to decimal: from the right, multiply each digit by {0} to the power of its position',
        String(b)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private ask(): void {
    const bi: number = Math.floor(Math.random() * BASES.length);
    const b: number = BASES[bi];
    const hi: number = b === 2 ? 127 : 255;
    const n: number = 5 + Math.floor(Math.random() * (hi - 4));
    const toBaseQ: boolean = Math.random() < 0.5;
    this.curBase = b; this.curN = n; this.curToBase = toBaseQ;
    const pool: string[] = [];
    let correct: string = '';
    if (toBaseQ) {
      correct = toBase(n, b);
      pool.push(toBase(n - 1, b));
      pool.push(toBase(n + 1, b));
      pool.push(toBase(n + 2, b));
      pool.push(toBase(n + b, b));
      this.quiz = String(n) + '₁₀ = ? ' + SUBS[bi];
    } else {
      correct = String(n);
      pool.push(String(n - 1));
      pool.push(String(n + 1));
      pool.push(String(n + 2));
      pool.push(String(n * b));
      this.quiz = toBase(n, b) + SUBS[bi] + ' = ? ₁₀';
    }
    const opts: string[] = [correct];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.opts = opts;
    this.ans = opts.indexOf(correct);
    this.picked = -1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.combo = this.combo + 1;
      this.score += 100 + this.combo * 10;
      this.msg = TG2('✅ 答对！连击 ×{0}', String(this.combo));
    } else {
      this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.combo = 0;
      this.score = Math.max(0, this.score - 20);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒（正确答案已标绿）",Digits(String(PENALTY), this.langCode));
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.advance();
    }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) {
      return;
    }
    if (this.right >= GOAL) {
      this.over = true;
      this.won = true;
      this.msg = TG2("🎉 答对 {0} 题，通关！剩 {1} 秒",Digits(String(GOAL), this.langCode),Digits(String(this.left), this.langCode));
      this.clearAll();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.left <= 0) {
      this.lose(TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题'));
      return;
    }
    this.ask();
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
      gameId: 'base_conversion_run',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private optBg(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.emerald;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private optInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
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
          .backgroundColor(this.left <= 15 ? Palette.rose : Palette.orange)
          .borderRadius(Radius.full)
          .animation({ duration: Motion.base, curve: Motion.snap() })
      }
      .width('100%')
      .height(8)

      // 题目卡
      Column({ space: Space.xs }) {
        Text(this.quiz)
          .fontSize(FontSize.xxxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.orange)
        Text(TG2("第 {0} 题 · 目标答对 {1} 题", String(this.right + this.wrong + 1), String(GOAL)))
          .fontSize(FontSize.xxs)
          // ★ 错误抖动
          .translate({ x: this.shakeX })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .fontColor(this.theme.inkFaint)
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      // 选项
      Column({ space: Space.sm }) {
        ForEach(this.optsIdx, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkFaint)
            Text(this.opts[i])
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.optInk(i))
              .layoutWeight(1)
          }
          .width('100%')
          .height(Cell.of(52))
          .padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i))
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'bq' + i)
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(42))
        .onClick(() => {
          this.askHint();
        })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('提示：₂ 二进制 · ₈ 八进制 · ₁₆ 十六进制（A~F 表示 10~15）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=剩余秒数 1=答对 2=得分 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('剩余') : (kind === 1 ? TG('答对') : TG('得分')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.left + 's'
        : (kind === 1 ? this.right + '/' + GOAL : String(this.score)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 && this.left <= 15 ? Palette.rose : this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }
}
