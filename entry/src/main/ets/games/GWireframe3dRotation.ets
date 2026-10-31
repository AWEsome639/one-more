/** 线框旋转 🔄（id: wireframe_3d_rotation）
 * 题面是 4 块方块搭成的立体形状，四个点阵里只有一个是它「转了个方向」的正交投影；
 * 4 题答对 ≥3 ⇒ 通关，否则失败。 */
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
const G: number = 7; const ROUNDS: number = 4;
const NEED: number = 3;
const PAUSE: number = 900;
const TWO: number[] = [0, 1];
const EMPTY: boolean[] = [];
const SHAPES: number[][] = [
  [0, 0, 0, 1, 0, 0, 2, 0, 0, 3, 0, 0], [0, 0, 0, 1, 0, 0, 2, 0, 0, 2, 1, 0],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0], [0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 2, 1, 0], [0, 0, 0, 1, 0, 0, 2, 0, 0, 1, 1, 0],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1]
];
function rot90(p: number[], ax: number): number[] {
  if (ax === 0) { return [p[0], -p[2], p[1]]; }
  return ax === 1 ? [p[2], p[1], -p[0]] : [-p[1], p[0], p[2]];
}
/** 绕坐标轴连转 4~7 次 90°，得到一个正着放的随机朝向 */
function orient(shape: number[]): number[] {
  let cur: number[] = shape.slice(); const n: number = 4 + Math.floor(Math.random() * 4);
  for (let i = 0; i < n; i++) {
    const ax: number = Math.floor(Math.random() * 3); const out: number[] = [];
    for (let k = 0; k < cur.length; k += 3) {
      const q: number[] = rot90([cur[k], cur[k + 1], cur[k + 2]], ax);
      out.push(q[0]); out.push(q[1]); out.push(q[2]); }
    cur = out;
  }
  return cur;
}
/** 正交投影到 G×G 点阵（坐标恒在 -3..3，平移 +3 即可） */
function marks(shape: number[]): boolean[] {
  const out: boolean[] = new Array<boolean>(G * G).fill(false);
  for (let i = 0; i < shape.length; i += 3) { out[(3 - shape[i + 1]) * G + shape[i] + 3] = true; }
  return out;
}
function art(m: boolean[]): string {
  let s: string = ''; for (let r = 0; r < G; r++) {
    for (let c = 0; c < G; c++) { s += m[r * G + c] ? '⬛' : '⬜'; }
    s += '\n'; }
  return s;
}
@Component
export struct GWireframe3dRotation {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 NEED=3
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(3);
  onFinish: (r: GameResult) => void = () => {};
  @State targetMarks: boolean[] = [];
  @State optMarks: boolean[][] = [];
  @State ans: number = 0;
  @State asked: number = 0;
  @State hits: number = 0;
  @State picked: number = -1;
  @State over: boolean = false;
  @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private timer: number = -1;
  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWireframe3dRotation')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); } private win(): boolean { return this.hits >= this.diffTotal; }
  private clearTimer(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }
  private reset(): void {
    this.clearTimer(); this.asked = 0; this.hits = 0; this.over = false; this.done = false;
    this.startAt = Date.now(); this.newRound();
  }
  private newRound(): void {
    for (let attempt = 0; attempt < 60; attempt++) {
      const si: number = Math.floor(Math.random() * SHAPES.length);
      const base: number[] = SHAPES[si];
      const mt: string = marks(base).join(''); const right: number[] = orient(base);
      const mr: string = marks(right).join('');
      if (mr === mt) { continue; }
      const cands: boolean[][] = []; const seen: string[] = [mt, mr];
      for (let k = 0; k < SHAPES.length && cands.length < 3; k++) {
        if (k === si) { continue; }
        const one: boolean[] = marks(orient(SHAPES[k])); const finger: string = one.join('');
        if (seen.indexOf(finger) >= 0) { continue; }
        seen.push(finger); cands.push(one);
      }
      if (cands.length < 3) { continue; }
      const at: number = Math.floor(Math.random() * 4);
      const out: boolean[][] = []; let k: number = 0;
      for (let i = 0; i < 4; i++) {
        if (i === at) { out.push(marks(right)); } else { out.push(cands[k]); k++; }
      }
      this.targetMarks = marks(base); this.optMarks = out; this.ans = at; this.picked = -1;
      this.note = TG('哪个只是转了个方向？');
      return;
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是第 {0} 个', String(n + 1)),
      TG2('The answer is option {0}', String(n + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
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

  private pick(i: number): void {
    if (this.over || this.picked >= 0) { return; }
    this.picked = i; this.asked++;
    if (i === this.ans) { this.hits++; this.note = TG('✅ 同一块积木，转过来的'); } else { this.note = TG('❌ 绿框那个才是它'); }
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.asked >= ROUNDS) { this.finish(this.win()); return; }
      this.newRound();
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.clearTimer();
    const r: GameResult = {
      gameId: 'wireframe_3d_rotation', solved: solved, score: this.hits * 25,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG('第 ') + String(Math.min(this.asked + 1, ROUNDS)) + '/' + String(ROUNDS) + ' 题 · 答对 ' +
        String(this.hits) + '/' + String(this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Text(art(this.targetMarks)).fontSize(FontSize.sm).lineHeight(Space.md)
        .textAlign(TextAlign.Center).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      ForEach(TWO, (r: number) => {
        Row({ space: Space.sm }) {
          this.opt(r * 2)
          this.opt(r * 2 + 1)
        }
        .width('100%')
      }, (r: number) => 'orow' + r)
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center).width('100%')
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
      Button(this.over ? (this.win() ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.win() ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  opt(i: number) {
    Column() {
      Text(art(this.optMarks.length > i ? this.optMarks[i] : EMPTY))
        .fontSize(FontSize.sm).lineHeight(Space.md).textAlign(TextAlign.Center)
    }
    .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
    .borderRadius(Radius.md).borderWidth(2)
    .borderColor(this.picked < 0 ? this.theme.line :
      (i === this.ans ? Palette.emerald : (i === this.picked ? Palette.rose : this.theme.line)))
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.pick(i); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); })
  }
}
