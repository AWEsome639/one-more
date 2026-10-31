/**
 * 路径回忆 📐
 * 规则：格子依次亮起，连成一条路径；看完后按同样顺序点出来。
 * 胜负：连过 6 轮（路径 3→8 格）⇒ 通关；点错一格 ⇒ 失败。　进度：轮次 / 路径长度 / 已点
 */
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
import { Tv } from '../core/Tv';

const N: number = 5; const ROUNDS: number = 6; const START: number = 3; const FLASH: number = 520;
const IDXN: number[] = [0, 1, 2, 3, 4];

@Component
export struct GPathRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(5);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private seq: number[] = []; @State private playIdx: number = -1; @State private step: number = 0;
  @State private round: number = 1; @State private phase: string = '看';
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPathRecall')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.halt(); }
  private halt(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.halt(); this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound(1);
  }
  /** 自避路径：每步只走向没走过的邻居；实在走不动就整条重来 */
  private makeSeq(len: number): number[] {
    for (let attempt = 0; attempt < 60; attempt++) {
      const path: number[] = [];
      let cur: number = Math.floor(Math.random() * this.diffTotal * this.diffTotal);
      path.push(cur);
      let bad: boolean = false;
      while (path.length < len && !bad) {
        const r: number = Math.floor(cur / this.diffTotal); const c: number = cur % this.diffTotal;
        const nb: number[] = [];
        if (r > 0) { nb.push(cur - this.diffTotal); }
        if (r < this.diffTotal - 1) { nb.push(cur + this.diffTotal); }
        if (c > 0) { nb.push(cur - 1); }
        if (c < this.diffTotal - 1) { nb.push(cur + 1); }
        const cand: number[] = [];
        for (let i = 0; i < nb.length; i++) { if (path.indexOf(nb[i]) < 0) { cand.push(nb[i]); } }
        if (cand.length === 0) { bad = true; } else {
          cur = cand[Math.floor(Math.random() * cand.length)];
          path.push(cur);
        }
      }
      if (!bad && path.length === len) { return path; }
    }
    const fallback: number[] = [];
    for (let i = 0; i < len; i++) { fallback.push(Math.floor(Math.random() * this.diffTotal * this.diffTotal)); }
    return fallback;
  }
  private newRound(round: number): void {
    this.round = round; this.step = 0; this.seq = this.makeSeq(START + round - 1);
    this.halt(); this.phase = TG('看'); this.playIdx = -1; this.msg = TG('看清亮起的顺序…');
    let i: number = -1;
    this.timer = setInterval(() => {
      i = i + 1;
      if (i >= this.seq.length) {
        this.halt(); this.playIdx = -1; this.phase = TG('点');
        this.msg = TG2("按顺序点出这 {0} 格", String(this.seq.length));
        return;
      }
      this.playIdx = i;
    }, FLASH);
  }
  private inTrail(i: number): boolean {
    for (let k = 0; k < this.step; k++) { if (this.seq[k] === i) { return true; } }
    return false;
  }
  private lit(i: number): boolean {
    const p: number = this.playIdx;
    if (p >= 0 && p < this.seq.length) { return this.seq[p] === i; }
    return this.phase === TG('点') && this.inTrail(i);
  }
  /** 提示：按顺序点，现在该点第 idx+1 个（seq[idx]） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.step;
    if (k < 0 || k >= this.seq.length) {
      return Hint.none('none');
    }
    return Hint.make([this.seq[k]],
      TG2('该点第 {0} 个', String(this.seq[k] + 1)),
      TG2('Tap number {0}', String(this.seq[k] + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 路径回忆：按顺序点 seq
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
    if (this.over || this.phase !== TG('点')) {
      return true;              // 还在播放/过渡，等
    }
    if (this.step >= this.seq.length) {
      return true;              // 这一轮答完了，等它开下一轮
    }
    this.tap(this.seq[this.step]);
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

  private tap(i: number): void {
    if (this.over || this.phase !== TG('点')) { return; }
    if (i !== this.seq[this.step]) { this.finish(false); return; }
    this.step = this.step + 1;
    if (this.step < this.seq.length) { this.msg = '✅ ' + String(this.step) + '/' + String(this.seq.length); return; }
    if (this.round >= ROUNDS) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    this.newRound(this.round + 1);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.halt();
    this.over = true; this.won = solved; this.phase = TG('结束'); this.playIdx = -1;
    this.msg = solved ? '🎉 六轮全过，路都记住了！' : '❌ 顺序错了，本局结束';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'path_recall', solved: solved,
      score: solved ? 200 + ROUNDS * 30 : (this.round - 1) * 30 + this.step * 5,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    });
  }
  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('路径'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(START + this.round - 1) + TG(' 格'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.step) + '/' + String(this.seq.length))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (c: number) => { Stack() {
            Text(this.lit((r * this.diffTotal + c)) ? '●' : '').fontSize(FontSize.md).fontColor('#FFFFFF')
            }.layoutWeight(1).aspectRatio(1)
            .backgroundColor(this.lit((r * this.diffTotal + c)) ? Palette.sky : this.theme.surfaceAlt)
            .borderRadius(Radius.md)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { Haptics.tick(); this.tap((r * this.diffTotal + c)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('86%').aspectRatio(1)
      Text(this.phase === '看' ? '👀 看清顺序' : (this.phase === TG('点') ? '👆 轮到你了' : '🏁 本局结束'))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.phase === TG('点') ? Palette.emerald : this.theme.inkSoft)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
