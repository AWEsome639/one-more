/** 字母算术（Crypto Arithmetic）—— 字母代表数字
 *  玩法：给五个字母指派互不相同的数字（首位不为 0）让等式成立。过关判据：5 题解出 ≥ 4 题
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const ROUNDS: number = 5;
const PASS: number = 4;

interface Crypto { form: number; sol: number[] }

function distinct(v: number[]): boolean {
  for (let i = 0; i < v.length; i++) {
    for (let j = i + 1; j < v.length; j++) {
      if (v[i] === v[j]) { return false; }
    }
  }
  return true;
}

function makeCrypto(): Crypto {
  const form: number = Math.random() < 0.5 ? 0 : 1;
  for (let attempt = 0; attempt < 500; attempt++) {
    const a: number = 1 + Math.floor(Math.random() * 9);
    const b: number = Math.floor(Math.random() * 10);
    const c: number = form === 0 ? 1 + Math.floor(Math.random() * 9) : 2 + Math.floor(Math.random() * 8);
    const lhs: number = form === 0 ? (10 * a + b) + c : (10 * a + b) * c;
    if (lhs < 10 || lhs > 99) { continue; }
    const d: number = Math.floor(lhs / 10);
    const e: number = lhs % 10;
    const five: number[] = [a, b, c, d, e];
    if (distinct(five)) { return { form: form, sol: five }; }
  }
  return form === 0 ? { form: 0, sol: [1, 4, 6, 2, 0] } : { form: 1, sol: [3, 9, 2, 7, 8] };
}

@Component
export struct GCryptoArithmetic {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private puz: Crypto = { form: 0, sol: [1, 4, 6, 2, 0] };
  @State private slots: number[] = [-1, -1, -1, -1, -1];
  @State private sel: number = 0;
  @State private round: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private tip: string = TG('选一个字母，再点数字');

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCryptoArithmetic')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.round = 0;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.tip = TG('选一个字母，再点数字');
    this.load();
  }

  private load(): void {
    this.puz = makeCrypto();
    this.slots = [-1, -1, -1, -1, -1];
    this.sel = 0;
  }

  private letterAt(k: number): string {
    return ['A', 'B', 'C', 'D', 'E'][k];
  }

  private usedDigit(d: number): boolean {
    for (let k = 0; k < 5; k++) {
      if (this.slots[k] === d) { return true; }
    }
    return false;
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
    const s: number = this.cryptoCursor();
    if (s < 0) {
      return false;
    }
    this.sel = s;
    this.tapDigit(this.puz.sol[s]);
    return !this.over;
  }

  /** 提示：每个字母的数字解就在 this.puz.sol 里 —— 报「这个字母填几」 */
  private cryptoCursor(): number {
    let s: number = this.sel;
    if (s >= 0 && s < 5 && this.slots[s] < 0) {
      return s;
    }
    for (let i = 0; i < 5; i++) {
      if (this.slots[i] < 0) {
        return i;
      }
    }
    return -1;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const s: number = this.cryptoCursor();
    if (s < 0) {
      return Hint.none('none');
    }
    return Hint.make([s],
      TG2('给 {0} 填 {1}（{2}）', this.letterAt(s), String(this.puz.sol[s]), this.eqText()),
      TG2('Set {0} = {1} ({2})', this.letterAt(s), String(this.puz.sol[s]), this.eqText()), t0);
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
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private tapDigit(d: number): void {
    if (this.over) { return; }
    const next: number[] = this.slots.slice();
    next[this.sel] = d;
    this.slots = next;
    this.check();
    if (!this.over && this.sel >= 0) {
      this.sel = (this.sel + 1) % 5;
    }
  }

  private check(): void {
    for (let k = 0; k < 5; k++) {
      if (this.slots[k] < 0) { return; }
    }
    const a: number = this.slots[0];
    const b: number = this.slots[1];
    const c: number = this.slots[2];
    const d: number = this.slots[3];
    const e: number = this.slots[4];
    if (!distinct(this.slots)) {
      this.tip = TG('五个字母必须是不同数字');
      return;
    }
    if (a === 0 || c === 0 || d === 0) {
      this.tip = TG('A / C / D 不能是 0');
      return;
    }
    const lhs: number = this.puz.form === 0 ? (10 * a + b) + c : (10 * a + b) * c;
    const rhs: number = 10 * d + e;
    if (lhs !== rhs) {
      this.tip = TG2('还不成立：{0} ≠ {1}', String(lhs), String(rhs));
      return;
    }
    this.right++;
    this.score += 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.round++;
    if (this.round >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("共解出 {0}/{1} 题", String(this.right), String(this.diffTotal));
      this.finish(this.right >= PASS);
      return;
    }
    this.load();
    this.sel = -1;
    this.tip = TG2('✓ 成立！下一题：{0}', this.eqText());
  }

  private eqText(): string {
    const mark: string = this.puz.form === 0 ? ' + ' : ' × ';
    return 'AB' + mark + 'C = DE';
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'crypto_arithmetic', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
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
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.round + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('解出'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
        Text(this.puz.form === 0 ? '加法式' : '乘法式').fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          Stack() {
          Text(this.slots[(0)] < 0 ? this.letterAt((0)) : String(this.slots[(0)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.slots[(0)] < 0 ? this.theme.inkFaint : (this.sel === (0) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (0) ? Palette.violet : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over) { this.sel = (0); this.tip = TG2('给 {0} 选数字', this.letterAt((0))); } }); })
          .onClick(() => { Haptics.tick(); if (!this.over) { this.sel = (0); this.tip = TG2('给 {0} 选数字', this.letterAt((0))); } })
          Stack() {
          Text(this.slots[(1)] < 0 ? this.letterAt((1)) : String(this.slots[(1)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.slots[(1)] < 0 ? this.theme.inkFaint : (this.sel === (1) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (1) ? Palette.violet : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over) { this.sel = (1); this.tip = TG2('给 {0} 选数字', this.letterAt((1))); } }); })
          .onClick(() => { Haptics.tick(); if (!this.over) { this.sel = (1); this.tip = TG2('给 {0} 选数字', this.letterAt((1))); } })
          Text(this.puz.form === 0 ? '+' : '×')
            .fontSize(FontSize.xxl).fontColor(this.theme.inkSoft).width(Space.xl).textAlign(TextAlign.Center)
          Stack() {
          Text(this.slots[(2)] < 0 ? this.letterAt((2)) : String(this.slots[(2)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.slots[(2)] < 0 ? this.theme.inkFaint : (this.sel === (2) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (2) ? Palette.violet : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over) { this.sel = (2); this.tip = TG2('给 {0} 选数字', this.letterAt((2))); } }); })
          .onClick(() => { Haptics.tick(); if (!this.over) { this.sel = (2); this.tip = TG2('给 {0} 选数字', this.letterAt((2))); } })
          Text('=').accessibilityText(TG('等于')).fontSize(FontSize.xxl).fontColor(this.theme.inkSoft).width(Space.xl).textAlign(TextAlign.Center)
            .accessibilityLevel('no')
          Stack() {
          Text(this.slots[(3)] < 0 ? this.letterAt((3)) : String(this.slots[(3)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.slots[(3)] < 0 ? this.theme.inkFaint : (this.sel === (3) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (3) ? Palette.violet : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over) { this.sel = (3); this.tip = TG2('给 {0} 选数字', this.letterAt((3))); } }); })
          .onClick(() => { Haptics.tick(); if (!this.over) { this.sel = (3); this.tip = TG2('给 {0} 选数字', this.letterAt((3))); } })
          Stack() {
          Text(this.slots[(4)] < 0 ? this.letterAt((4)) : String(this.slots[(4)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.slots[(4)] < 0 ? this.theme.inkFaint : (this.sel === (4) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (4) ? Palette.violet : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over) { this.sel = (4); this.tip = TG2('给 {0} 选数字', this.letterAt((4))); } }); })
          .onClick(() => { Haptics.tick(); if (!this.over) { this.sel = (4); this.tip = TG2('给 {0} 选数字', this.letterAt((4))); } })
        }
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).height(20)

      Column({ space: Space.sm }) {
        Row({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4], (d: number) => { Button(String((d)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.usedDigit((d)) ? this.theme.inkFaint : this.theme.ink)
          .backgroundColor(this.theme.surface).borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(48))
          .enabled(!this.over && !this.usedDigit((d))).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tapDigit((d)); }); }).onClick(() => { Haptics.tap(); this.tapDigit((d)); }) }, (d: number) => 'p' + d)
        }.width('100%')
        Row({ space: Space.xs }) {
          ForEach([5, 6, 7, 8, 9], (d: number) => { Button(String((d)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.usedDigit((d)) ? this.theme.inkFaint : this.theme.ink)
          .backgroundColor(this.theme.surface).borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(48))
          .enabled(!this.over && !this.usedDigit((d))).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tapDigit((d)); }); }).onClick(() => { Haptics.tap(); this.tapDigit((d)); }) }, (d: number) => 'q' + d)
        }.width('100%')
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.rose).borderRadius(Radius.md).width(120).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('五个字母的数字两两不同')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
