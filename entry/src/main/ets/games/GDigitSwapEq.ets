/** 数字换位（Digit Swap Equation）—— 交换两个数字使等式成立
 *  玩法：点两个数字块交换它们。过关判据：60 秒内改对 ≥ 5 个等式
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const LIMIT: number = 60;
const NEED: number = 5;

interface Tok { ch: string; pos: number }
interface Puzzle { digits: number[]; g1: number; g2: number; g3: number; sign: string; tokens: Tok[]; ord: number[] }

function digitsOf(v: number): number[] {
  const s: string = String(v);
  const out: number[] = [];
  for (let i = 0; i < s.length; i++) { out.push(Number(s.charAt(i))); }
  return out;
}

function buildTokens(digits: number[], g1: number, g2: number, g3: number, sign: string): Tok[] {
  const out: Tok[] = [];
  const mark: string = sign === 'x' ? '×' : sign;
  for (let i = 0; i < digits.length; i++) {
    if (i === g1) { out.push({ ch: mark, pos: -1 }); }
    if (i === g1 + g2) { out.push({ ch: '=', pos: -1 }); }
    out.push({ ch: String(digits[i]), pos: i });
  }
  return out;
}

/** 打包成谜题（tokens 与 ord 一起生成） */
function pack(digits: number[], g1: number, g2: number, g3: number, sign: string): Puzzle {
  const tokens: Tok[] = buildTokens(digits, g1, g2, g3, sign);
  const ord: number[] = [];
  for (let i = 0; i < tokens.length; i++) { ord.push(i); }
  return { digits: digits, g1: g1, g2: g2, g3: g3, sign: sign, tokens: tokens, ord: ord };
}

function value(digits: number[], from: number, len: number): number {
  let v: number = 0;
  for (let i = from; i < from + len; i++) { v = v * 10 + digits[i]; }
  return v;
}

function isTrue(digits: number[], g1: number, g2: number, g3: number, sign: string): boolean {
  const a: number = value(digits, 0, g1);
  const b: number = value(digits, g1, g2);
  const c: number = value(digits, g1 + g2, g3);
  if (sign === '+') { return a + b === c; }
  if (sign === '-') { return a - b === c; }
  return a * b === c;
}

function makePuzzle(): Puzzle {
  const signs: string[] = ['+', '-', 'x'];
  for (let attempt = 0; attempt < 60; attempt++) {
    const sign: string = signs[Math.floor(Math.random() * 3)];
    let g1: number = 2;
    let g2: number = 2;
    let a: number = 10 + Math.floor(Math.random() * 40);
    let b: number = 10 + Math.floor(Math.random() * 40);
    let c: number = 0;
    if (sign === '+') {
      c = a + b;
    } else if (sign === '-') {
      if (b > a - 10) { b = a - 10; }
      if (b < 10) { continue; }
      c = a - b;
    } else {
      g1 = 1;
      g2 = 1;
      a = 2 + Math.floor(Math.random() * 8);
      b = 2 + Math.floor(Math.random() * 8);
      c = a * b;
    }
    const g3: number = String(c).length;
    const base: number[] = digitsOf(a);
    const mid: number[] = digitsOf(b);
    const tail: number[] = digitsOf(c);
    const digits: number[] = [];
    for (let i = 0; i < base.length; i++) { digits.push(base[i]); }
    for (let i = 0; i < mid.length; i++) { digits.push(mid[i]); }
    for (let i = 0; i < tail.length; i++) { digits.push(tail[i]); }
    // 打乱两个不同的数字位，且打乱后必须不成立
    for (let t = 0; t < 24; t++) {
      const p: number = Math.floor(Math.random() * digits.length);
      const q: number = Math.floor(Math.random() * digits.length);
      if (p === q || digits[p] === digits[q]) { continue; }
      const mixed: number[] = digits.slice();
      const tmp: number = mixed[p];
      mixed[p] = mixed[q];
      mixed[q] = tmp;
      if (!isTrue(mixed, g1, g2, g3, sign)) {
        return pack(mixed, g1, g2, g3, sign);
      }
    }
  }
  // 兜底：12 + 41 = 33（错），把第 3 位与第 5 位换回来即 12 + 31 = 43
  return pack([1, 2, 4, 1, 3, 3], 2, 2, 2, '+');
}

@Component
export struct GDigitSwapEq {
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
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private puz: Puzzle = makePuzzle();
  @State private pickA: number = -1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private clears: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private tip: string = TG('点两个数字块，交换它们');

  private startAt: number = 0;
  private tick: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => {
      if (this.over) { return; }
      this.left--;
      if (this.left <= 0) {
        this.left = 0;
        this.over = true;
        this.tip = TG2('时间到｜共改对 {0} 个等式', String(this.clears));
        this.finish(this.clears >= NEED);
      }
    }, 1000);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDigitSwapEq')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }

  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
  }


  /**
   * ★ 2026-10-23 第二期：数字换位提示（真求解器）
   *
   * 玩法：交换两个数字块，让等式成立。
   * 解法：把**所有两两交换**都试一遍，用 isTrue 判定。
   *   位数最多 9 个 ⇒ 最多 36 次交换，成本可忽略。
   * ⇒ 提示直接报出该换哪两个：「把第 2 个和第 5 个数字换个位」
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const d: number[] = this.puz.digits;
    const n: number = d.length;
    const g1: number = this.puz.g1;
    const g2: number = this.puz.g2;
    const g3: number = this.puz.g3;
    const sg: string = this.puz.sign;
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        const nd: number[] = d.slice();
        const t: number = nd[i];
        nd[i] = nd[j];
        nd[j] = t;
        if (isTrue(nd, g1, g2, g3, sg)) {
          // ⚠️ 模板最多 4 个占位符（TG4 上限）
          //    第一版写了 5 个 ⇒ Expected 1-5 arguments, but got 7
          //    ⇒ 只报位置；玩家自己看得见换完之后等式成不成立
          return Hint.make([i, j],
            TG2('把第 {0} 个和第 {1} 个换个位', String(i + 1), String(j + 1)),
            TG2('Swap tile {0} and tile {1}', String(i + 1), String(j + 1)), t0);
        }
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.aiSwap(0);
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

  private reset(): void {
    this.startAt = Date.now();
    this.left = this.total;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.pickA = -1;
    this.tip = TG('点两个数字块，交换它们');
    this.puz = makePuzzle();
  }

  private tapDigit(pos: number): void {
    if (this.over) { return; }
    if (this.pickA < 0) {
      this.pickA = pos;
      this.tip = TG('再点另一个数字块交换');
      return;
    }
    if (this.pickA === pos) {
      this.pickA = -1;
      this.tip = TG('已取消选择');
      return;
    }
    const mixed: number[] = this.puz.digits.slice();
    const tmp: number = mixed[this.pickA];
    mixed[this.pickA] = mixed[pos];
    mixed[pos] = tmp;
    const next: Puzzle = pack(mixed, this.puz.g1, this.puz.g2, this.puz.g3, this.puz.sign);
    this.puz = next;
    this.pickA = -1;
    if (isTrue(mixed, next.g1, next.g2, next.g3, next.sign)) {
      this.clears++;
      this.score += 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.puz = makePuzzle();
      this.tip = TG('✓ 成立！下一题');
    } else {
      this.tip = TG('还不成立，再换一次');
    }
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'digit_swap_eq', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.clears
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  /** AI 用：找出该换的两个数字块并点掉 */
  private aiSwap(_d: number): void {
    if (this.pickA >= 0) { this.tapDigit(this.pickA); }
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length < 2) { return; }
    this.tapDigit(r.cells[0]);
    this.tapDigit(r.cells[1]);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('改对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.clears) + '/' + String(NEED))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(TG('交换两个数字，让等式成立')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.puz.ord, (i: number) => {
            if ((this.puz.tokens[i]).pos < 0) {
            Text((this.puz.tokens[i]).ch).fontSize(FontSize.xxl).fontColor(this.theme.inkSoft).width(Space.xxl).textAlign(TextAlign.Center)
            } else {
            Text((this.puz.tokens[i]).ch).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
            .fontColor(this.pickA === (this.puz.tokens[i]).pos ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
            .width(Space.xxxl).height(Space.xxxl)
            .backgroundColor(this.pickA === (this.puz.tokens[i]).pos ? Palette.lime : this.theme.surfaceAlt).borderRadius(Radius.xs)
            .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapDigit((this.puz.tokens[i]).pos); }); }).onClick(() => { Haptics.tick(); this.tapDigit((this.puz.tokens[i]).pos); })
            }
          }, (i: number) => 't' + i)
        }.width('100%')
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).height(20)

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(42))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.lime).borderRadius(Radius.md).width(120).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('运算符位置不会变')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
