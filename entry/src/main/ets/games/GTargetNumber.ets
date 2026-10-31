/** 目标数字 —— 四则运算凑目标
 *  玩法：给出三个数和一个目标值，从 4 个式子里选出结果正好等于目标的那个
 *  胜负：6 题答对 ≥5 ⇒ 通关；否则失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const ROUNDS: number = 6; const PASS: number = 5; const NEXT_MS: number = 900;
interface Expr { text: string; value: number }
function makeExprs(a: number, b: number, c: number): Expr[] {
  const list: Expr[] = [];
  list.push({ text: '(' + String(a) + ' + ' + String(b) + ') × ' + String(c), value: (a + b) * c });
  list.push({ text: String(a) + ' × ' + String(b) + ' + ' + String(c), value: a * b + c });
  list.push({ text: String(a) + ' × ' + String(b) + ' − ' + String(c), value: a * b - c });
  list.push({ text: String(a) + ' × (' + String(b) + ' + ' + String(c) + ')', value: a * (b + c) });
  list.push({ text: String(a) + ' + ' + String(b) + ' × ' + String(c), value: a + b * c });
  if (a > b) {
    list.push({ text: '(' + String(a) + ' − ' + String(b) + ') × ' + String(c), value: (a - b) * c });
  }
  if (b > c) {
    list.push({ text: String(a) + ' × (' + String(b) + ' − ' + String(c) + ')', value: a * (b - c) });
  }
  return list;
}
function uniqueByValue(list: Expr[]): Expr[] {
  const out: Expr[] = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].value < 1 || list[i].value > 200) { continue; }
    let dup: boolean = false;
    for (let j = 0; j < out.length; j++) {
      if (out[j].value === list[i].value) { dup = true; }
    }
    if (!dup) { out.push(list[i]); }
  }
  return out;
}
function perm(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GTargetNumber {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=6
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);
  onFinish: (r: GameResult) => void = () => {};
  @State private nums: number[] = []; @State private opts: string[] = []; @State private target: number = 0;
  @State private ansIdx: number = 0; @State private round: number = 1; @State private right: number = 0;
  @State private score: number = 0; @State private pick: number = -1; @State private answered: boolean = false;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTargetNumber')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.right = 0; this.score = 0; this.over = false;
    this.won = false; this.ask(); this.msg = TG('哪个式子的结果等于目标？');
  }
  private ask(): void {
    let pool: Expr[] = []; let trio: number[] = [2, 3, 4];
    for (let k = 0; k < 40 && pool.length < 4; k++) {
      const a: number = 2 + Math.floor(Math.random() * 8); const b: number = 2 + Math.floor(Math.random() * 8);
      const c: number = 2 + Math.floor(Math.random() * 8); const cand: Expr[] = uniqueByValue(makeExprs(a, b, c));
      if (cand.length >= 4) { pool = cand; trio = [a, b, c]; }
    }
    if (pool.length < 4) {
      // 兜底：2、3、4 必定凑出 4 个不同结果（20 / 10 / 2 / 14）
      trio = [2, 3, 4]; pool = uniqueByValue(makeExprs(2, 3, 4));
    }
    this.nums = trio; const pickIdx: number = Math.floor(Math.random() * pool.length);
    this.target = pool[pickIdx].value; const chosen: Expr[] = [pool[pickIdx]];
    const rest: number[] = perm(pool.length);
    for (let i = 0; i < rest.length && chosen.length < 4; i++) {
      if (rest[i] !== pickIdx) { chosen.push(pool[rest[i]]); }
    }
    const order: number[] = perm(chosen.length); const texts: string[] = []; const tgt: number = this.target;
    let ansPos: number = 0;
    for (let i = 0; i < order.length; i++) {
      const e: Expr = chosen[order[i]];
      if (e.value === tgt) { ansPos = i; }
      texts.push(e.text);
    }
    this.opts = texts; this.ansIdx = ansPos; this.pick = -1; this.answered = false;
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
    if (this.answered) {
      return true;
    }
    this.submit(this.ansIdx);
    return !this.over;
  }

  // 答案就在 this.ansIdx（submit 比的就是 k === ansIdx）
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.answered) {
      return Hint.none('none');
    }
    const i: number = this.ansIdx;
    return Hint.make([i],
      '答案是「' + this.opts[i] + '」= ' + String(this.target),
      'The answer is "' + this.opts[i] + '" = ' + String(this.target), t0);
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

  private submit(k: number): void {
    if (this.answered || this.over) { return; }
    this.answered = true; this.pick = k; const ok: boolean = k === this.ansIdx;
    if (ok) {
      this.right = this.right + 1; this.score = this.score + 150; this.msg = TG2('✅ 正是 {0}', String(this.target)); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    } else {
      this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('❌ 目标是 {0}，正确式子是 {1}', String(this.target), this.opts[this.ansIdx]);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1; this.next();
    }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG('哪个式子的结果等于目标？');
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'target_number', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(PASS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(TG2('🎯 目标 = {0}', String(this.target))).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold)
          .fontColor(Palette.cyan)
        Row({ space: Space.sm }) {
          ForEach(this.nums, (v: number, i: number) => {
            Text(String((v))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(46)).backgroundColor(this.theme.surfaceAlt)
            .borderRadius(Radius.md)
          }, (v: number, i: number) => 'n' + i + '_' + v)
        }.width('100%')
        Text(TG('用这三个数，选出结果等于目标的式子')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      ForEach([0, 1, 2, 3], (i: number) => {
        Button(this.opts.length > (i) ? this.opts[(i)] : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor(this.pick === (i) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (i)
        ? ((i) === this.ansIdx ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).animation({ duration: Motion.fast, curve: Motion.snap() })
        // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        .onClick(() => {
        Haptics.tap();
        this.submit((i));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit((i)); }); })
      }, (i: number) => 'o' + i)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：先算乘除，再算加减；括号先算')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
