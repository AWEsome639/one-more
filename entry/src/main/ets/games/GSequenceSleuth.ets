/** 数列侦探 —— 看前五项推第六项｜8 题答对 6 题过关 */
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

const TOTAL: number = 8;
const PASS: number = 6;

interface SeqQ { terms: number[]; ans: number; opts: number[]; why: string }

function makeQ(): SeqQ {
  const kind: number = Math.floor(Math.random() * 4);
  const terms: number[] = [];
  let ans: number = 0;
  let diff: number = 0;
  let why: string = '';
  if (kind === 0) {
    const a: number = 1 + Math.floor(Math.random() * 20);
    diff = 2 + Math.floor(Math.random() * 8);
    for (let i = 0; i < 5; i++) { terms.push(a + i * diff); }
    ans = a + 5 * diff;
    why = TG2('等差数列，公差 {0}', String(diff));
  } else if (kind === 1) {
    const a: number = 1 + Math.floor(Math.random() * 4);
    const r: number = 2 + Math.floor(Math.random() * 2);
    let v: number = a;
    for (let i = 0; i < 5; i++) {
      terms.push(v);
      v = v * r;
    }
    ans = v;
    why = TG2('等比数列，公比 {0}', String(r));
  } else if (kind === 2) {
    let x: number = 1 + Math.floor(Math.random() * 5);
    let y: number = 1 + Math.floor(Math.random() * 5);
    terms.push(x);
    terms.push(y);
    for (let i = 2; i < 5; i++) {
      const t: number = x + y;
      terms.push(t);
      x = y;
      y = t;
    }
    ans = x + y;
    why = TG('每项 = 前两项之和');
  } else {
    const s: number = 2 + Math.floor(Math.random() * 6);
    for (let i = 0; i < 5; i++) { terms.push((s + i) * (s + i)); }
    ans = (s + 5) * (s + 5);
    why = TG('连续平方数');
  }
  const cands: number[] = [ans + 1, ans - 1, ans + 2, ans - 2, ans + 3, ans - 3];
  if (diff > 0) { cands.push(ans + diff); cands.push(ans - diff); }
  const opts: number[] = [ans];
  for (let i = 0; i < cands.length && opts.length < 4; i++) {
    const v: number = cands[i];
    if (v > 0 && opts.indexOf(v) < 0) { opts.push(v); }
  }
  for (let i = opts.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = opts[i];
    opts[i] = opts[j];
    opts[j] = t;
  }
  return { terms: terms, ans: ans, opts: opts, why: why };
}

@Component
export struct GSequenceSleuth {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private terms: number[] = [];
  @State private ans: number = 0;
  @State private opts: number[] = [];
  @State private why: string = '';
  @State private picked: number = -1;
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('找出规律，填第六项');
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


  /**
   * ★ 2026-10-23 第二期：数列侦探提示
   *
   * 这款每一项的 `why` 字段本身就是「规律说明」：
   *   等差数列，公差 N ｜ 等比数列，公比 N ｜ 每项 = 前两项之和 ｜ 连续平方数
   * ⇒ 直接把它当提示 —— **说明规律，但不给答案**。
   *   玩家知道规律之后自己就能算出第六项。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.why.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('规律是：{0}（照着它算第六项）', this.why),
      TG2('The rule is: {0} (work out the sixth term from it)', this.why), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

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
    const item: SeqQ = makeQ();
    this.terms = item.terms;
    this.ans = item.ans;
    this.opts = item.opts;
    this.why = item.why;
    this.picked = -1;
    this.tip = TG('看前五项，规律是什么？');
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

  private choose(v: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = v;
    if (v === this.ans) {
      this.right++;
      this.score += 12;
      this.tip = TG2('✓ {0}，第六项 {1}', this.why, String(this.ans));
    } else {
      this.wrong++;
      this.score -= 2;
      this.tip = TG2('✗ {0}，第六项 {1}', this.why, String(this.ans));
    }
    this.wait = setTimeout(() => { this.next(); }, 900);
  }

  private next(): void {
    this.wait = -1;
    this.idx++;
    if (this.idx >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'sequence_sleuth', solved: this.right >= PASS,
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
        Text(this.terms.join(' , ') + ' , ?').fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink).textAlign(TextAlign.Center).width('100%')
        Text(TG('第六项是哪一个？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        ForEach([0, 1], (i: number) => { Button(String(this.opts[(i)]))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked < 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([2, 3], (i: number) => { Button(String(this.opts[(i)]))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked < 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); }); }, (i: number) => 'b' + i)
      }.width('100%')
      Row({ space: Space.md }) {
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
        HintBar({
          showHint: false,
          onAutoTap: () => { this.askAuto(); },
          autoOn: this.autoId >= 0
        })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('先看差，再看比，其次看前两项')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }





  private optTone(i: number): string {
    const v: number = this.opts[i];
    if (this.picked < 0) { return Palette.violet; }
    if (v === this.ans) { return Palette.emerald; }
    if (v === this.picked) { return Palette.danger; }
    return this.theme.surfaceAlt;
  }

  private optInk(i: number): string {
    const v: number = this.opts[i];
    if (this.picked < 0 || v === this.ans || v === this.picked) { return '#FFFFFF'; }
    return this.theme.ink;
  }
}
