/** 文氏图 —— 集合运算
 *  玩法：给出集合 A、B 与一个数字，判断它落在哪个区域（只在 A / 只在 B / 都在 / 都不在）
 *  胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */

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
const ROUNDS: number = 8; const PASS: number = 6; const NEXT_MS: number = 850; const UNIVERSE: number = 12;
const REGION: string[] = ['只在 A', '只在 B', 'A、B 都有', '都不在'];
function sample(k: number, hi: number): number[] {
  const pool: number[] = [];
  for (let i = 1; i <= hi; i++) { pool.push(i); }
  const out: number[] = [];
  for (let i = 0; i < k; i++) {
    const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1);
  }
  for (let i = 1; i < out.length; i++) {
    const cur: number = out[i]; let j: number = i - 1;
    while (j >= 0 && out[j] > cur) { out[j + 1] = out[j]; j--; }
    out[j + 1] = cur;
  }
  return out;
}
function setText(name: string, arr: number[]): string {
  return name + ' = { ' + arr.join(', ') + ' }';
}
@Component
export struct GSetTheoryVenn {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=8
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(8);
  onFinish: (r: GameResult) => void = () => {};
  @State private setA: number[] = []; @State private setB: number[] = []; @State private probe: number = 1;
  @State private round: number = 1; @State private right: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private pick: number = -1; @State private answered: boolean = false; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSetTheoryVenn')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.right = 0; this.score = 0; this.over = false;
    this.won = false; this.ask(); this.msg = TG('看这个数字落在哪个区域');
  }
  private ask(): void {
    this.setA = sample(4, UNIVERSE); this.setB = sample(4, UNIVERSE);
    this.probe = 1 + Math.floor(Math.random() * UNIVERSE); this.pick = -1; this.answered = false;
  }
  /** 0 只在 A ／ 1 只在 B ／ 2 都在 ／ 3 都不在 */
  private solution(): number {
    const a: number[] = this.setA; const b: number[] = this.setB; const n: number = this.probe;
    const inA: boolean = a.indexOf(n) >= 0; const inB: boolean = b.indexOf(n) >= 0;
    if (inA && inB) { return 2; }
    if (inA) { return 0; }
    if (inB) { return 1; }
    return 3;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    this.submit(this.solution());
    return !this.over;
  }

  /** 提示：直接报区域名 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.answered || this.over) {
      return Hint.none('none');
    }
    const ans: number = this.solution();
    return Hint.make([ans], TG2('应该是「{0}」', REGION[ans]),
      TG2('It should be {0}', REGION[ans]), t0);
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
    this.answered = true; this.pick = k; const ans: number = this.solution();
    if (k === ans) {
      this.right = this.right + 1; this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ {0} 确实「{1}」', String(this.probe), REGION[ans]);
    } else {
      this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ {0} 应该是「{1}」', String(this.probe), REGION[ans]); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
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
    this.round = this.round + 1; this.ask(); this.msg = TG('看这个数字落在哪个区域');
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'set_theory_venn', solved: solved, score: this.score,
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
        Text(TG2('🔵 A ∪ 🔴 B，问 {0} 在哪', String(this.probe))).fontSize(FontSize.md).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
        Row({ space: Space.xs }) {
          Column({ space: 2 }) {
          Text(('🔵 A')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((String(this.setA.length) + TG(' 个'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.sky)).borderRadius(Radius.lg).shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(('🟣 A∩B')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((TG('重叠区'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.violet)).borderRadius(Radius.lg).shadow(Shadow.card)
          Column({ space: 2 }) {
          Text(('🔴 B')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text((String(this.setB.length) + TG(' 个'))).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }.layoutWeight(1).padding(Space.sm).backgroundColor((Palette.rose)).borderRadius(Radius.lg).shadow(Shadow.card)
        }.width('100%')
        Text(setText('A', this.setA)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        Text(setText('B', this.setB)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(REGION[(0)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (0)
        ? ((0) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((0));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit((0)); }); })
        Button(REGION[(1)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (1)
        ? ((1) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((1));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit((1)); }); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(REGION[(2)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (2)
        ? ((2) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((2));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit((2)); }); })
        Button(REGION[(3)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.pick === (3)
        ? ((3) === this.solution() ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((3));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit((3)); }); })
      }.width('100%')
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
      Text(TG('提示：先看这个数在不在 A 里，再看在不在 B 里')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
