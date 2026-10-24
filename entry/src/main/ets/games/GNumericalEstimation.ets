/**
 * 数值估算 —— 估算结果
 *
 * 玩法：给出乘 / 除 / 百分数算式，四选一挑出最接近的估算值。共 8 题。
 * 胜负：答对 ≥ 6 题 ⇒ 通关；否则失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 8;
const PASS: number = 6;
const PICK: number = 4;
const NEXT_MS: number = 420;

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

/** 取 1 位有效数字的"好估算值" */
function niceRound(v: number): number {
  let unit: number = 1;
  while (v / unit >= 10) {
    unit = unit * 10;
  }
  return Math.round(v / unit) * unit;
}

/** 千分位 */
function fmt(v: number): string {
  const s: string = String(Math.round(v));
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const k: number = s.length - i;
    out = out + s.charAt(i) + ((k > 1 && k % 3 === 1) ? ',' : '');
  }
  return out;
}

@Component
export struct GNumericalEstimation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private nextTo: number = -1;
  private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
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
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG('不用精算，挑最接近的那个');
    this.ask();
  }

  private ask(): void {
    const kind: number = randInt(0, 2);
    let truth: number = 0;
    let q: string = '';
    if (kind === 0) {
      const a: number = randInt(21, 89);
      const b: number = randInt(21, 79);
      truth = a * b;
      q = a + ' × ' + b + ' ≈ ?';
    } else if (kind === 1) {
      const b: number = randInt(11, 39);
      const q0: number = randInt(11, 49);
      const a: number = b * q0 + randInt(1, b - 1);
      truth = a / b;
      q = a + ' ÷ ' + b + ' ≈ ?';
    } else {
      const p: number = randInt(11, 89);
      const v: number = randInt(120, 880);
      truth = v * p / 100;
      q = TG2("{0} 的 {1}% ≈ ?", v, p);
    }
    const correct: number = niceRound(truth);
    const pool: number[] = [Math.round(correct * 0.5), Math.round(correct * 2),
      Math.round(correct * 0.25), Math.round(correct * 3)];
    const opts: number[] = [correct];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (pool[i] > 0 && opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = opts[i];
      opts[i] = opts[j];
      opts[j] = tmp;
    }
    this.opts = opts;
    this.ans = opts.indexOf(correct);
    this.picked = -1;
    this.quiz = q;
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
      this.score = this.score + 100; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ 就是 {0} 上下', fmt(this.opts[this.ans]));
    } else {
      this.msg = TG2('❌ 更接近的是 {0}', fmt(this.opts[this.ans]));
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
    if (this.round >= this.diffTotal) {
      const ok: boolean = this.right >= PASS;
      this.msg = ok ? TG('🎉 答对 ') + this.right + '/' + this.diffTotal + ' 题，通关！'
        : TG('答对 ') + this.right + '/' + this.diffTotal + ' 题，还差一点';
      this.finish(ok);
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
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'numerical_estimation',
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
      return Palette.sky;
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
        Column({ space: 2 }) {
        Text((TG('第几题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(this.quiz).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.sky).textAlign(TextAlign.Center)
        Text(TG('≈ 是"大约"，选最接近的')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Row({ space: Space.sm }) {
            Text(String(i + 1)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.inkFaint)
            Text(fmt(this.opts[i])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1)
          }.width('100%').height(Cell.of(50)).padding({ left: Space.md, right: Space.md }).backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'ne' + i)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%').animation({ duration: Motion.fast, curve: Motion.snap() })

      HintBar({

        showHint: false,

        onAutoTap: () => { this.askAuto(); },

        autoOn: this.autoId >= 0

      })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.sky).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
