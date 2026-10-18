/**
 * 计算冲刺 —— 限时连算
 *
 * 玩法：加减乘除心算，四选一；答对连击加分，答错扣 3 秒。
 * 胜负：60 秒内答对 15 题 ⇒ 通关；时间归零还没达标 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';

const TIME_LIMIT: number = 60;
const GOAL: number = 15;         // 通关需答对
const PICK: number = 4;
const NEXT_MS: number = 460;
const PENALTY: number = 3;       // 答错扣秒
const TICK_MS: number = 1000;
const LETTERS: string[] = ['A', 'B', 'C', 'D'];
const OPS: string[] = ['＋', '−', '×', '÷'];

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GCalculationSprint {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: number[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private combo: number = 0;
  @State private best: number = 0;
  @State private score: number = 0;
  // ★ 难度作用到玩法：本局实际时限 = 基础 60s × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  //   必须在这里算 —— TIME_LIMIT 是模块常量，模块加载时就算死了，中途改难度不会重算
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
    // ★ 难度可能刚变过 ⇒ 时限必须**重算**，不能只靠字段初始化（构造时那一次）
    this.total = GameDiff.timeNow(TIME_LIMIT);
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
    this.best = 0;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.ask();
    this.msg = TG2("算得越快，连击越高；答错扣 {0} 秒",Digits(String(PENALTY), this.langCode));
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

  private ask(): void {
    const op: number = Math.floor(Math.random() * 4);
    let a: number = 0;
    let b: number = 0;
    let correct: number = 0;
    if (op === 0) {
      a = randInt(12, 99);
      b = randInt(12, 99);
      correct = a + b;
    } else if (op === 1) {
      a = randInt(30, 99);
      b = randInt(10, a - 1);
      correct = a - b;
    } else if (op === 2) {
      a = randInt(3, 12);
      b = randInt(3, 19);
      correct = a * b;
    } else {
      b = randInt(3, 12);
      correct = randInt(3, 12);
      a = b * correct;
    }
    const pool: number[] = [correct + 1, correct - 1, correct + 2, correct - 2, correct + 10];
    const opts: number[] = [correct];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (pool[i] > 0 && opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.opts = opts;
    this.ans = opts.indexOf(correct);
    this.picked = -1;
    this.quiz = String(a) + ' ' + OPS[op] + ' ' + String(b) + ' = ?';
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.combo = this.combo + 1;
      if (this.combo > this.best) {
        this.best = this.combo;
      }
      this.score += 60 + this.combo * 10;
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
      gameId: 'calculation_sprint',
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
          .backgroundColor(this.left <= 15 ? Palette.rose : Palette.amber)
          .borderRadius(Radius.full)
          .animation({ duration: Motion.base, curve: Motion.snap() })
      }
      .width('100%')
      .height(8)

      Column({ space: Space.xs }) {
        Text(this.quiz)
          .fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.amber)
        Text(TG2('连击 ×{0} · 最高 ×{1} · 第 {2} 题', String(this.combo), String(this.best), String(this.right + this.wrong + 1)))
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

      Column({ space: Space.sm }) {
        ForEach(this.optsIdx, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkFaint)
            Text(String(this.opts[i]))
              .fontSize(FontSize.xl)
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
            this.pick(i);
          })
        }, (i: number) => 'cs' + i)
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
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          this.reset();
        })

      Text(TG2('提示：答对一题 +1，答错扣 {0} 秒 —— 稳一点比快一点划算',Digits(String(PENALTY), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=剩余 1=答对 2=得分 */
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
