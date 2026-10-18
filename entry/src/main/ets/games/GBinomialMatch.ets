/**
 * 二项式配对 —— 把展开项和它的系数配起来
 *
 * 玩法：给定 (a+b)ⁿ，左列是 4 个展开项（aᵏb^(n−k)），右列是打乱的 4 个系数；
 *       各点一个配对，配对成功就锁定，配错记一次失误。
 * 胜负：4 组全配对 ⇒ 通关；错满 3 次 ⇒ 失败。
 * 判据：aᵏb^(n−k) 的系数 = C(n, k)；四个 k 的系数互不相同，保证配对唯一。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const PAIRS: number = 4;        // 每局配对数
const MISS: number = 3;         // 失误上限
const COEF_BASE: number = 200;  // 每配对得分
const SUP: string[] = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸'];

/** 一个展开项 */
interface Term {
  k: number;      // b 的次数（a 的次数 = n − k）
  coef: number;   // 系数 C(n, k)
  text: string;   // a²b¹ 这样的文本
}

function binom(n: number, k: number): number {
  let r: number = 1;
  for (let i = 0; i < k; i++) {
    r = r * (n - i) / (i + 1);
  }
  return Math.round(r);
}

function termText(n: number, k: number): string {
  const a: number = n - k;
  if (a === 0) {
    return 'b' + SUP[k];
  }
  if (k === 0) {
    return 'a' + SUP[a];
  }
  return 'a' + SUP[a] + 'b' + SUP[k];
}

@Component
export struct GBinomialMatch {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PAIRS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(PAIRS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private n: number = 0;
  @State private left: Term[] = [];         // 左列（4 项）
  @State private right: number[] = [];      // 右列（4 个系数，打乱）
  @State private doneL: boolean[] = [];
  @State private doneR: boolean[] = [];
  @State private selL: number = -1;
  @State private selR: number = -1;
  @State private matched: number = 0;
  @State private bad: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private nextTo: number = -1;
  // ★★★★ 2026-10-14 崩溃修复：必须是 @State —— 否则 reset() 改了长度 ForEach 不重算
  //   （原来写死 [0,1,2,3]，与 left 的真实长度脱钩 ⇒ 越界 ⇒ TypeError 崩溃）
  @State private slots: number[] = [];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PAIRS);
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
    this.n = 3 + Math.floor(Math.random() * 5);      // 3~7 次方
    const ks: number[] = [];
    for (let k = 0; k <= this.n; k++) {
      ks.push(k);
    }
    for (let i = ks.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = ks[i];
      ks[i] = ks[j];
      ks[j] = t;
    }
    const pick: number[] = [];
    const coefs: number[] = [];
    for (let i = 0; i < ks.length && pick.length < this.diffTotal; i++) {
      const c: number = binom(this.n, ks[i]);
      if (coefs.indexOf(c) < 0) {                    // 系数唯一 ⇒ 配对不会歧义
        coefs.push(c);
        pick.push(ks[i]);
      }
    }
    const terms: Term[] = [];
    for (let i = 0; i < pick.length; i++) {
      const t: Term = { k: pick[i], coef: coefs[i], text: termText(this.n, pick[i]) };
      terms.push(t);
    }
    const rt: number[] = coefs.slice();
    for (let i = rt.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = rt[i];
      rt[i] = rt[j];
      rt[j] = t;
    }
    this.left = terms;
    // ★★★ 崩溃修复：槽位必须【跟随真实数据长度】，不能写死 4 个
    //   （ArkTS 严格模式：不许 unknown / 泛型推断 ⇒ 用普通循环）
    const sl: number[] = [];
    for (let k = 0; k < terms.length; k++) {
      sl.push(k);
    }
    this.slots = sl;
    this.right = rt;
    this.doneL = new Array<boolean>(this.diffTotal).fill(false);
    this.doneR = new Array<boolean>(this.diffTotal).fill(false);
    this.selL = -1;
    this.selR = -1;
    this.matched = 0;
    this.bad = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG('左边点项、右边点系数，配成一对');
  }

  private tapL(i: number): void {
    if (this.over || this.doneL[i]) {
      return;
    }
    this.selL = this.selL === i ? -1 : i;
    this.tryMatch();
  }

  private tapR(j: number): void {
    if (this.over || this.doneR[j]) {
      return;
    }
    this.selR = this.selR === j ? -1 : j;
    this.tryMatch();
  }

  private tryMatch(): void {
    if (this.selL < 0 || this.selR < 0) {
      return;
    }
    const li: number = this.selL;
    const rj: number = this.selR;
    this.selL = -1;
    this.selR = -1;
    if (this.left[li].coef === this.right[rj]) {
      const dl: boolean[] = this.doneL.slice();
      const dr: boolean[] = this.doneR.slice();
      dl[li] = true;
      dr[rj] = true;
      this.doneL = dl;
      this.doneR = dr;
      this.matched = this.matched + 1;
      this.score += COEF_BASE;
      this.msg = TG2('✅ {0} 的系数就是 {1}', this.left[li].text, String(this.left[li].coef)) +
        TG2('（还有 {0} 对）', String(this.diffTotal - this.matched));
      if (this.matched >= this.diffTotal) {
        this.over = true;
        this.won = true;
        this.msg = TG('🎉 四对全中，展开式配齐！');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.bad = this.bad + 1;
    this.score = Math.max(0, this.score - 40);
    this.msg = TG2('❌ 不是一对（失误 {0}/{1}）', String(this.bad), String(MISS));
    if (this.bad >= MISS) {
      this.over = true;
      this.won = false;
      this.msg = TG2('💥 错满 {0} 次，配对失败',Digits(String(MISS), this.langCode));
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'binomial_match',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.matched
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private leftBg(i: number): string {
    if (this.doneL[i]) {
      return Palette.emerald;
    }
    return this.selL === i ? Palette.primary : this.theme.surface;
  }

  private rightBg(j: number): string {
    if (this.doneR[j]) {
      return Palette.emerald;
    }
    return this.selR === j ? Palette.primary : this.theme.surface;
  }

  private leftInk(i: number): string {
    return this.doneL[i] || this.selL === i ? '#FFFFFF' : this.theme.ink;
  }

  private rightInk(j: number): string {
    return this.doneR[j] || this.selR === j ? '#FFFFFF' : this.theme.ink;
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
        Text(TG2('(a + b){0} 展开式里，项的系数是多少？', SUP[this.n]))
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
        Text(TG2('系数 = C({0}, k)，即 aᵏb^(n−k) 的系数', String(this.n)))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }
      .width('100%')
      .padding(Space.md)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Row({ space: Space.md }) {
        Column({ space: Space.sm }) {
          Text(TG('展开项')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          ForEach(this.slots, (i: number) => {
            this.termCell(i)
          }, (i: number) => 'bt' + i)
        }
        .layoutWeight(1)

        Column({ space: Space.sm }) {
          Text(TG('系数')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          ForEach(this.slots, (j: number) => {
            this.coefCell(j)
          }, (j: number) => 'bc' + j)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : '换一组')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          this.reset();
        })

      Text(TG('提示：C(n,k) 从杨辉三角读最快 —— 例如 C(4,2) = 6'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=已配对 1=失误 2=得分 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '已配对' : (kind === 1 ? TG('失误') : TG('得分')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.matched + '/' + this.diffTotal
        : (kind === 1 ? this.bad + '/' + MISS : String(this.score)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 1 && this.bad > 0 ? Palette.rose : this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  termCell(i: number) {
    // ★★★★ 2026-10-14 崩溃修复（真机日志 jscrash-com.andrewoscar.onemore-...174315677）：
    //   TypeError: Cannot read property text of undefined  at GBinomialMatch:611
    //   根因：ForEach 遍历的是 this.slots（写死 [0,1,2,3] = 4 个），
    //         而 this.left 的长度 = pick.length（可能不足 4）⇒ this.left[3] 是 undefined
    //         ⇒ 读 .text 直接抛 TypeError ⇒ ★ 整个 app 崩
    //   ⇒ 修法：① 读字段加保护 ② slots 跟随真实长度（见 reset()）
    Text(this.left[i] ? this.left[i].text : '')
      .fontSize(FontSize.xxl)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Center)
      .fontColor(this.leftInk(i))
      .width('100%')
      .height(Cell.of(52))
      .backgroundColor(this.leftBg(i))
      .borderRadius(Radius.md)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
        this.tapL(i);
      })
  }

  @Builder
  coefCell(j: number) {
    // ★ 同上：right 可能不足 slots 长度 ⇒ 加保护
    Text(this.right[j] === undefined ? '' : String(this.right[j]))
      .fontSize(FontSize.xxl)
      .fontWeight(FontWeight.Bold)
      .textAlign(TextAlign.Center)
      .fontColor(this.rightInk(j))
      .width('100%')
      .height(Cell.of(52))
      .backgroundColor(this.rightBg(j))
      .borderRadius(Radius.md)
      .shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
        this.tapR(j);
      })
  }
}
