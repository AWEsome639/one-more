/** 解不等式（Algebraic Inequality Solver）—— 求一元一次不等式的解集
 *  玩法：从 4 个解集里点出正确的一个。过关判据：10 题答对 ≥ 7 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 10;
const PASS: number = 7;

interface QIneq { text: string; answer: string; choices: string[] }

function flip(sign: string): string {
  if (sign === '>') { return '<'; }
  if (sign === '<') { return '>'; }
  if (sign === '≥') { return '≤'; }
  return '≥';
}

function makeIneq(): QIneq {
  const a: number = 2 + Math.floor(Math.random() * 4);
  const x0: number = -5 + Math.floor(Math.random() * 12);
  const b: number = 1 + Math.floor(Math.random() * 9);
  const kinds: string[] = ['>', '<', '≥', '≤'];
  const sign: string = kinds[Math.floor(Math.random() * kinds.length)];
  const form: number = Math.floor(Math.random() * 2);
  let text: string = '';
  if (form === 0) {
    text = String(a) + 'x + ' + String(b) + ' ' + sign + ' ' + String(a * x0 + b);
  } else {
    text = String(a) + 'x - ' + String(b) + ' ' + sign + ' ' + String(a * x0 - b);
  }
  const want: string = 'x ' + sign + ' ' + String(x0);
  const raw: string[] = [want, 'x ' + flip(sign) + ' ' + String(x0),
    'x ' + sign + ' ' + String(x0 + 1), 'x ' + sign + ' ' + String(x0 - 1)];
  const bag: string[] = [];
  for (let k = 0; k < raw.length; k++) {
    let dup: boolean = false;
    for (let j = 0; j < bag.length; j++) {
      if (bag[j] === raw[k]) { dup = true; }
    }
    if (!dup) { bag.push(raw[k]); }
  }
  while (bag.length < 4) { bag.push('x = ' + String(x0)); }
  for (let i = bag.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = bag[i];
    bag[i] = bag[j];
    bag[j] = t;
  }
  return { text: text, answer: want, choices: bag };
}

@Component
export struct GAlgebraicInequalitySolver {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private quiz: QIneq = { text: '', answer: '', choices: [] };
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private tip: string = TG('点出正确的解集');
  @State private lockTap: boolean = false;

  private startAt: number = 0;
  private wait: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAlgebraicInequalitySolver')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  aboutToDisappear(): void {
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
  }

  private reset(): void {
    this.startAt = Date.now();
    this.idx = 0;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.lockTap = false;
    this.tip = TG('点出正确的解集');
    this.quiz = makeIneq();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：s === this.quiz.answer（字符串答案）
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.over || this.lockTap) {
      return true;
    }
    if (this.quiz.answer.length === 0) {
      return true;
    }
    this.answer(this.quiz.answer);
    return !this.over;
  }

  /** 提示：直接报解集 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.quiz.answer.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('解集是 {0}', this.quiz.answer),
      TG2('The solution set is {0}', this.quiz.answer), t0);
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

  private answer(s: string): void {
    if (this.over || this.lockTap) { return; }
    if (s === this.quiz.answer) {
      this.right++;
      this.score += 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.tip = TG2('✓ 解集就是 {0}', this.quiz.answer);
    } else {
      this.tip = TG2('✗ 正解：{0}', this.quiz.answer);
    }
    this.lockTap = true;
    this.wait = setTimeout(() => {
      this.wait = -1;
      this.idx++;
      if (this.idx >= this.diffTotal) {
        this.over = true;
        this.tip = TG2("共答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
        this.finish(this.right >= PASS);
        return;
      }
      this.quiz = makeIneq();
      this.lockTap = false;
      this.tip = TG('点出正确的解集');
    }, 650);
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'algebraic_inequality_solver', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
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
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
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

      Column({ space: Space.sm }) {
        Text('🔢').fontSize(FontSize.hero)
          .accessibilityLevel('no')
        Text(this.quiz.text).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('求 x 的解集')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.base, curve: Motion.snap() })

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.tip.startsWith('✓') ? Palette.emerald : this.theme.inkSoft)

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Button(this.quiz.choices[(0)] ?? '?')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
          .enabled(!this.lockTap && !this.over).onClick(() => { Haptics.tap(); this.answer(this.quiz.choices[(0)] ?? '?'); })
          Button(this.quiz.choices[(1)] ?? '?')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
          .enabled(!this.lockTap && !this.over).onClick(() => { Haptics.tap(); this.answer(this.quiz.choices[(1)] ?? '?'); })
        }.width('100%')
        Row({ space: Space.sm }) {
          Button(this.quiz.choices[(2)] ?? '?')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
          .enabled(!this.lockTap && !this.over).onClick(() => { Haptics.tap(); this.answer(this.quiz.choices[(2)] ?? '?'); })
          Button(this.quiz.choices[(3)] ?? '?')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
          .enabled(!this.lockTap && !this.over).onClick(() => { Haptics.tap(); this.answer(this.quiz.choices[(3)] ?? '?'); })
        }.width('100%')
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.sky).borderRadius(Radius.md)
          .width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('严格/非严格要看清楚')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
