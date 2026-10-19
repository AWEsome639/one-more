/**
 * 进制移位 —— 不同进制切换
 *
 * 玩法：b 进制下把一个数「左移 k 位」（末尾添 k 个 0），选出它的十进制值；四选一。
 * 胜负：10 题里答对 ≥7 ⇒ 通关；答错 3 次 ⇒ 失败。
 * 算理：末尾添一个 0 = 乘一次 b；添 k 个 = 乘 b^k。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 10;      // 每局题数
const PASS: number = 7;        // 通关需答对
const LIVES: number = 3;       // 答错上限
const PICK: number = 4;
const NEXT_MS: number = 700;
const BASES: number[] = [2, 8, 16];
const SUBS: string[] = ['₂', '₈', '₁₆'];
const LETTERS: string[] = ['A', 'B', 'C', 'D'];
const DIGITS: string = '0123456789ABCDEF';

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

function pown(b: number, e: number): number {
  let r: number = 1;
  for (let i = 0; i < e; i++) {
    r = r * b;
  }
  return r;
}

@Component
export struct GBaseShift {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  @State private detail: string = '';
  @State private round: number = 1;
  @State private right: number = 0;
  @State private bad: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
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
    this.diffTotal = GameDiff.sizeNow(TOTAL);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
    this.round = 1;
    this.right = 0;
    this.bad = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.ask();
    this.msg = TG('选出移位后的十进制值');
  }

  private ask(): void {
    const bi: number = Math.floor(Math.random() * BASES.length);
    const b: number = BASES[bi];
    const vMax: number = b === 2 ? 63 : 255;
    const v: number = 1 + Math.floor(Math.random() * vMax);
    const k: number = 1 + Math.floor(Math.random() * 3);        // 移 1~3 位
    const correct: number = v * pown(b, k);
    const pool: number[] = [];
    pool.push(v * pown(b, k - 1));
    pool.push(v * pown(b, k + 1));
    pool.push(correct + v);
    pool.push(correct - v);
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
    this.quiz = TG2("{0} 里 {1} 末尾添 {2} 个 0 = ?", SUBS[bi], toBase(v, b), String(k));
    this.detail = '（' + String(b) + ' 进制下每添 1 个 0 就是 ×' + String(b) + '，添 ' + String(k) + ' 个 = ×' + String(pown(b, k)) + '）';
  }

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.score += 120;
      this.msg = TG2('✅ 对！{0}', this.detail);
    } else {
      this.bad = this.bad + 1;
      this.score = Math.max(0, this.score - 20);
      this.msg = TG('❌ 错，正确答案已标绿');
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.next();
    }, NEXT_MS);
  }

  private next(): void {
    if (this.over) {
      return;
    }
    if (this.bad >= LIVES) {
      this.over = true;
      this.won = false;
      this.msg = TG2("💔 错满 {0} 次，答对 {1} 题",Digits(String(LIVES), this.langCode),Digits(String(this.right), this.langCode));
      this.finish(false);
      return;
    }
    if (this.round >= this.diffTotal) {
      this.over = true;
      this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS) + TG(' 题');
      this.finish(this.won);
      return;
    }
    this.round = this.round + 1;
    this.ask();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'base_shift',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private hearts(): string {
    let s: string = '';
    for (let i = 0; i < LIVES; i++) {
      s = s + (i < LIVES - this.bad ? '❤' : '🤍');
    }
    return s;
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

      Column({ space: Space.xs }) {
        Text(this.quiz)
          .fontSize(FontSize.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.cyan)
          .textAlign(TextAlign.Center)
        Text(TG2("第 {0}/{1} 题 · 生命 {2}",Digits(String(this.round), this.langCode),Digits(String(this.diffTotal), this.langCode), this.hearts()))
          .fontSize(FontSize.xxs)
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
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'bs' + i)
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.cyan).animation({ duration: Motion.fast, curve: Motion.snap() })
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('规则：末尾添 0 就是左移一位；添 {0} 个 0 就是 ×{1}（以二进制为例）', String(2), String(4)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=题号 1=答对 2=得分 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('题号') : (kind === 1 ? TG('答对') : TG('得分')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.round + '/' + this.diffTotal
        : (kind === 1 ? this.right + '/' + PASS : String(this.score)))
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
}
