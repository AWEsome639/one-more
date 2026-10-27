/**
 * 通分 —— 找最小公分母
 *
 * 玩法：给两个分数，选出它们的最小公分母（四选一）；选完顺带显示通分结果。
 * 判据：最小公分母 = lcm(b, d) = b × d ÷ gcd(b, d)。
 * 胜负：8 题里答对 ≥6 ⇒ 通关；否则失败。
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

const TOTAL: number = 8;
const PASS: number = 6;
const PICK: number = 4;
const NEXT_MS: number = 780;
const LETTERS: string[] = ['A', 'B', 'C', 'D'];

function gcd(a: number, b: number): number {
  let x: number = a;
  let y: number = b;
  while (y !== 0) {
    const t: number = x % y;
    x = y;
    y = t;
  }
  return x;
}

@Component
export struct GCommonDenominator {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private a: number = 1;      // 第一个分数 a/b
  @State private b: number = 2;
  @State private c: number = 1;      // 第二个分数 c/d
  @State private d: number = 3;
  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private round: number = 1;
  @State private right: number = 0;
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


  /**
   * ★ 2026-10-23 第二期：通分提示
   *
   * 判据是「最小公分母 = b × d ÷ gcd(b, d)」。
   * 提示**只给最大公约数**，让玩家自己乘除：
   *   「{b} 和 {d} 的最大公约数是 G ⇒ 用 {b} × {d} ÷ G」
   * ⇒ 给了方法的关键一步，没直接报答案。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const g: number = gcd(this.b, this.d);
    if (g <= 0) {
      return Hint.none('none');
    }
    if (g === 1) {
      return Hint.make([],
        TG2('{0} 和 {1} 没有公约数（最大公约数 1）⇒ 直接乘起来就是最小公分母',
          String(this.b), String(this.d)),
        TG2('{0} and {1} share no factor (gcd 1) — just multiply them',
          String(this.b), String(this.d)), t0);
    }
    return Hint.make([],
      TG2('{0} 和 {1} 的最大公约数是 {2} ⇒ 最小公分母 = {0} × {1} ÷ {2}',
        String(this.b), String(this.d), String(g)),
      TG2('gcd({0}, {1}) = {2} ⇒ the common denominator is {0} × {1} ÷ {2}',
        String(this.b), String(this.d), String(g)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
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
    this.ask();
    this.msg = TG('这两个分数的最小公分母是多少？');
  }

  private ask(): void {
    this.b = 2 + Math.floor(Math.random() * 11);          // 2~12
    this.d = 2 + Math.floor(Math.random() * 11);
    while (this.d === this.b) {
      this.d = 2 + Math.floor(Math.random() * 11);
    }
    this.a = 1 + Math.floor(Math.random() * (this.b - 1));
    this.c = 1 + Math.floor(Math.random() * (this.d - 1));
    const l: number = this.b * this.d / gcd(this.b, this.d);   // 最小公倍数
    const pool: number[] = [this.b * this.d, this.b + this.d, l * 2, l + this.b, l - 1, this.b * this.d + 1];
    const opts: number[] = [l];
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
    this.ans = opts.indexOf(l);
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
    const l: number = this.opts[this.ans];
    if (i === this.ans) {
      this.right = this.right + 1;
      this.score += 130;
      this.msg = TG2('✅ 公分母 {0}：{1} 与 {2}', String(l),
        String(this.a * l / this.b) + '/' + String(l), String(this.c * l / this.d) + '/' + String(l));
    } else {
      this.score = Math.max(0, this.score - 20);
      this.msg = TG2('❌ 错了，最小公分母是 {0}（已标绿）', String(l));
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
      gameId: 'common_denominator',
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
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 两个分数
      Row({ space: Space.lg }) {
        this.frac(0)
        Text(TG('与')).fontSize(FontSize.md).fontColor(this.theme.inkFaint)
        this.frac(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
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
            Text(TG2('公分母 = {0}', String(this.opts[i])))
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.optInk(i))
              .layoutWeight(1)
          }
          .width('100%')
          .height(Cell.of(50))
          .padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i))
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'cd' + i)
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
        .layoutWeight(1)
        .height(44)
        .onClick(() => {
          this.askHint();
        })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet).animation({ duration: Motion.fast, curve: Motion.snap() })
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('提示：最小公分母 = 两分母的最小公倍数 = b×d ÷ gcd(b, d)'))
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

  /** which: 0=第一个分数 1=第二个分数 */
  @Builder
  frac(which: number) {
    Column({ space: 2 }) {
      Text(String(which === 0 ? this.a : this.c))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(Palette.violet)
      Row()
        .width(48)
        .height(2)
        .backgroundColor(this.theme.lineSoft)
      Text(String(which === 0 ? this.b : this.d))
        .fontSize(FontSize.xxl)
        .fontWeight(FontWeight.Bold)
        .fontColor(Palette.violet)
    }
    .alignItems(HorizontalAlign.Center)
  }
}
