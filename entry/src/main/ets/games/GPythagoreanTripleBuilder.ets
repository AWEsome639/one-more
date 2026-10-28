/** 勾股数 —— 构造勾股三元组｜关数（简单 4/普通 6/困难 8）里解出 ≥ 通关线（3/5/7）关过关 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const LEVELS: number = 6;
const PASS: number = 5;

interface Tri { a: number; b: number; c: number }

const TRIPLES: Tri[] = [
  { a: 3, b: 4, c: 5 }, { a: 5, b: 12, c: 13 }, { a: 6, b: 8, c: 10 },
  { a: 7, b: 24, c: 25 }, { a: 8, b: 15, c: 17 }, { a: 9, b: 12, c: 15 },
  { a: 9, b: 40, c: 41 }, { a: 12, b: 16, c: 20 }, { a: 15, b: 20, c: 25 },
  { a: 20, b: 21, c: 29 }, { a: 10, b: 24, c: 26 }, { a: 18, b: 24, c: 30 }
];

@Component
export struct GPythagoreanTripleBuilder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State private ask: string = '';
  @State private ans: number = 5;
  @State private typed: string = '';
  @State private level: number = 0;
  @State private clears: number = 0;
  @State private miss: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = '';
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.level = 0;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.load();
  }

  private load(): void {
    const t: Tri = TRIPLES[Math.floor(Math.random() * TRIPLES.length)];
    const flip: boolean = Math.random() < 0.5;
    const ax: number = flip ? t.b : t.a;
    const bx: number = flip ? t.a : t.b;
    if (Math.random() < 0.5) {
      this.ask = TG2("两条直角边 {0} 与 {1}，斜边 = ?", String(ax), String(bx));
      this.ans = t.c;
    } else {
      this.ask = TG2("斜边 {0}，一条直角边 {1}，另一边 = ?", String(t.c), String(ax));
      this.ans = bx;
    }
    this.typed = '';
    this.miss = 0;
    this.tip = TG('a² + b² = c²，输入整数后点确认');
  }

  private typedValue(): number {
    let v: number = 0;
    for (let i = 0; i < this.typed.length; i++) { v = v * 10 + (this.typed.charCodeAt(i) - 48); }
    return v;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const want: string = String(this.ans);
    if (this.typed.length < want.length) {
      this.pickKey(want.charAt(this.typed.length));   // 一位一位敲进去
      return true;
    }
    if (this.typed === want) {
      this.submit();
      return !this.over;
    }
    this.typed = '';                // 玩家留下的残数，先清掉
    return true;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('填 {0}（a² + b² = c²，取整数）', String(this.ans)),
      TG2('The answer is {0}', String(this.ans)), t0);
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

  private pickKey(s: string): void {
    if (this.over) { return; }
    if (s === '⌫') {
      this.typed = this.typed.length > 0 ? this.typed.substring(0, this.typed.length - 1) : '';
      return;
    }
    if (s === TG('确认')) { this.submit(); return; }
    if (this.typed.length < 3) { this.typed = this.typed + s; }
  }

  private submit(): void {
    if (this.typed.length === 0) { this.tip = TG('先输入一个数'); return; }
    const v: number = this.typedValue();
    if (v === this.ans) {
      this.clears++;
      this.score += 14;
      this.next(TG2('✓ 正是 {0}', String(this.ans)));
      return;
    }
    this.miss++;
    this.score -= 3;
    if (this.miss >= 2) { this.next(TG2('✗ 正确答案是 {0}', String(this.ans))); return; }
    this.tip = TG2("{0} 不对，再算一次（a² + b² = c²）", String(v));
    this.typed = '';
  }

  /**
   * ★ 2026-10-28 修正：通关线不能是常量 —— 关数按难度变（简单 4 / 普通 6 / 困难 8），
   *   原来固定 PASS=5，简单档只有 4 关 ⇒ 最多解出 4 关，数学上不可能赢。
   *   公式 = min(关数, PASS + (关数 - LEVELS))：简单 4→3、普通 6→5、困难 8→7。
   *   每题答案都能输入（最多两位数），所以「实际能拿到的最大值 = 关数」。
   */
  private passNeed(): number {
    const v: number = PASS + (this.diffTotal - LEVELS);
    return Math.max(1, Math.min(this.diffTotal, v));
  }

  private next(msg: string): void {
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("{0}｜共解出 {1}/{2} 关", msg,Digits(String(this.clears), this.langCode),Digits(String(this.diffTotal), this.langCode));
      const res: GameResult = {
        gameId: 'pythagorean_triple_builder', solved: this.clears >= this.passNeed(),
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.clears
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.load();
    this.tip = TG2("{0}，第 {1} 关", msg, String(this.level + 1));
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.level + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已解出'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.clears), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.miss), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(this.ask).fontSize(FontSize.lg).fontColor(this.theme.ink).textAlign(TextAlign.Center).width('100%')
        Text(this.typed.length > 0 ? this.typed : '?')
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.berry)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
        Button((('1')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('1')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('1')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('1')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('1'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('1'))); }); })
        Button((('2')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('2')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('2')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('2')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('2'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('2'))); }); })
        Button((('3')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('3')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('3')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('3')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('3'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('3'))); }); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('4')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('4')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('4')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('4')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('4'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('4'))); }); })
        Button((('5')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('5')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('5')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('5')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('5'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('5'))); }); })
        Button((('6')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('6')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('6')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('6')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('6'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('6'))); }); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('7')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('7')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('7')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('7')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('7'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('7'))); }); })
        Button((('8')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('8')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('8')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('8')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('8'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('8'))); }); })
        Button((('9')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('9')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('9')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('9')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('9'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('9'))); }); })
        }.width('100%')
        Row({ space: Space.xs }) {
        Button((('⌫')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('⌫')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('⌫')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('⌫')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('⌫'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('⌫'))); }); })
        Button((('0')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize((('0')) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor((('0')) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor((('0')) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey((('0'))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey((('0'))); }); })
        Button(((TG('确认'))))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(((TG('确认'))) === TG('确认') ? FontSize.md : FontSize.xl)
        .fontColor(((TG('确认'))) === TG('确认') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(((TG('确认'))) === TG('确认') ? Palette.berry : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over)
        .onClick(() => { Haptics.tap(); this.pickKey(((TG('确认')))); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickKey(((TG('确认')))); }); })
        }.width('100%')
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.berry)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Text(TG('背熟的勾股数：3-4-5、5-12-13、8-15-17')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
