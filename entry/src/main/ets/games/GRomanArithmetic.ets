/** 罗马数字算术 —— 罗马数字的加减｜8 题答对 6 题过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 8;
const PASS: number = 6;
const VALS: number[] = [100, 90, 50, 40, 10, 9, 5, 4, 1];
const SYMS: string[] = ['C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];

interface RomQ { q: string; ans: string; opts: string[] }

function toRoman(n: number): string {
  let out: string = '';
  let v: number = n;
  for (let i = 0; i < VALS.length; i++) {
    while (v >= VALS[i]) {
      out = out + SYMS[i];
      v = v - VALS[i];
    }
  }
  return out;
}

function makeQ(): RomQ {
  const a: number = 4 + Math.floor(Math.random() * 44);
  const plus: boolean = Math.random() < 0.6;
  let b: number = 2 + Math.floor(Math.random() * 25);
  if (!plus && b >= a) { b = a - 1; }
  const val: number = plus ? a + b : a - b;
  const q: string = toRoman(a) + (plus ? '  +  ' : '  −  ') + toRoman(b);
  const ans: string = toRoman(val);
  const cands: number[] = [val + 1, val - 1, val + 2, val - 2, val + 10, val - 10, val + 5];
  const opts: string[] = [ans];
  for (let i = 0; i < cands.length && opts.length < 4; i++) {
    const c: number = cands[i];
    if (c >= 1 && c <= 99) {
      const t: string = toRoman(c);
      if (opts.indexOf(t) < 0) { opts.push(t); }
    }
  }
  for (let i = opts.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = opts[i];
    opts[i] = opts[j];
    opts[j] = t;
  }
  return { q: q, ans: ans, opts: opts };
}

@Component
export struct GRomanArithmetic {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private q: string = '';
  @State private ans: string = '';
  @State private opts: string[] = [];
  @State private picked: string = '';
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('算出数值，再翻成罗马数字');
  private startAt: number = 0;
  private wait: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; } }

  private reset(): void {
    this.startAt = Date.now();
    this.idx = 0;
    this.right = 0;
    this.wrong = 0;
    this.score = 0;
    this.over = false;
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
    this.ask();
  }

  private ask(): void {
    const item: RomQ = makeQ();
    this.q = item.q;
    this.ans = item.ans;
    this.opts = item.opts;
    this.picked = '';
    this.tip = 'I=1 V=5 X=10 L=50 C=100';
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案 this.ans 是字符串，作答函数的参数也是字符串
  // ★ 守卫 this.picked 也是字符串 ⇒ 判据是 length > 0，不是 >= 0
  /** 提示：报答案（字段 this.ans） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('答案是 {0}', this.ans),
      TG2('The answer is {0}', this.ans), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked.length > 0) {
      return true;              // 这题答过了，等下一题
    }
    this.choose(this.ans);
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

  private choose(s: string): void {
    if (this.picked.length > 0 || this.over) { return; }
    this.picked = s;
    if (s === this.ans) {
      this.right++;
      this.score += 12;
      this.tip = '✓ ' + this.q + ' = ' + this.ans;
    } else {
      this.wrong++;
      this.score -= 2;
      this.tip = '✗ ' + this.q + ' = ' + this.ans;
    }
    this.wait = setTimeout(() => { this.next(); }, 850);
  }

  private next(): void {
    this.wait = -1;
    this.idx++;
    if (this.idx >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'roman_arithmetic', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.ask();
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text('= ?').fontSize(FontSize.md).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        ForEach([0, 1], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([2, 3], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'b' + i)
      }.width('100%')
      Row({ space: Space.md }) {
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
          autoOn: this.autoId >= 0
        })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('左减右加：IV=4，IX=9，XL=40')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }





  private optTone(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0) { return Palette.teal; }
    if (s === this.ans) { return Palette.emerald; }
    if (s === this.picked) { return Palette.danger; }
    return this.theme.surfaceAlt;
  }

  private optInk(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0 || s === this.ans || s === this.picked) { return '#FFFFFF'; }
    return this.theme.ink;
  }
}
