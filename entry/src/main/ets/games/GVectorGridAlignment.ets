/** 向量对齐 —— 对齐向量网格
 *  玩法：网格上给出起点与目标格，按方向键走「向量 (dx, dy)」那么多步，把点走进目标格
 *  胜负：5 个向量全对齐 ⇒ 通关；某回合步数用尽还没对齐 ⇒ 失败 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const N: number = 5; const ROUNDS: number = 5; const NEXT_MS: number = 700;
function sign(n: number): string { return n >= 0 ? '+' + String(n) : String(n); }
@Component
export struct GVectorGridAlignment {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
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
  @State private pos: number = 0; @State private goal: number = 0; @State private vecX: number = 1;
  @State private vecY: number = 1; @State private round: number = 1; @State private cleared: number = 0;
  @State private movesLeft: number = 0; @State private score: number = 0; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVectorGridAlignment')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.cleared = 0; this.score = 0; this.over = false;
    this.won = false; this.genRound(); this.msg = TG('按方向键，把 🧭 走到 🎯');
  }
  private genRound(): void {
    let ok: boolean = false; let px: number = 1; let py: number = 1; let p0: number = 0; let g0: number = 6;
    let mv: number = 4;
    for (let k = 0; k < 60 && !ok; k++) {
      const tr: number = Math.floor(Math.random() * this.diffTotal); const tc: number = Math.floor(Math.random() * this.diffTotal);
      const dx: number = (Math.random() < 0.5 ? -1 : 1) * (1 + Math.floor(Math.random() * 3));
      const dy: number = (Math.random() < 0.5 ? -1 : 1) * (1 + Math.floor(Math.random() * 3));
      const sr: number = tr - dy; const sc: number = tc - dx;
      if (sr >= 0 && sr < this.diffTotal && sc >= 0 && sc < this.diffTotal) {
        px = dx; py = dy; p0 = sr * this.diffTotal + sc; g0 = tr * this.diffTotal + tc; mv = Math.abs(dx) + Math.abs(dy) + 2; ok = true;
      }
    }
    this.vecX = px; this.vecY = py; this.pos = p0; this.goal = g0; this.movesLeft = mv;
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
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
    if (this.over || this.nextTo >= 0 || this.pos === this.goal) {
      return true;
    }
    this.move(this.stepDx(), this.stepDy());
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 目标格就在 this.goal 里；按行列差走一步（步数上限 = |dx|+|dy|+2，够用）
  private gapCol(): number {
    return (this.goal % this.diffTotal) - (this.pos % this.diffTotal);
  }

  private gapRow(): number {
    return Math.floor(this.goal / this.diffTotal) - Math.floor(this.pos / this.diffTotal);
  }

  private stepDx(): number {
    const g: number = this.gapCol();
    return g > 0 ? 1 : (g < 0 ? -1 : 0);
  }

  private stepDy(): number {
    const g: number = this.gapRow();
    return g > 0 ? 1 : (g < 0 ? -1 : 0);
  }

  /** 提示：报目标格在第几行第几列 + 下一步往哪走 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.nextTo >= 0) {
      return Hint.none('none');
    }
    const gc: number = this.gapCol();
    const gr: number = this.gapRow();
    const dir: string = gc !== 0 ? (gc > 0 ? '往右走一格' : '往左走一格') : (gr > 0 ? '往下走一格' : '往上走一格');
    const gr0: number = Math.floor(this.goal / this.diffTotal) + 1;
    const gc0: number = (this.goal % this.diffTotal) + 1;
    return Hint.make([this.goal],
      TG2('{0} —— 目标在第 {1} 行第 {2} 列', dir, String(gr0), String(gc0)),
      TG2('{0} — target is row {1}, column {2}', dir, String(gr0), String(gc0)), t0);
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

  private move(dx: number, dy: number): void {
    if (this.over || this.nextTo >= 0) { return; }
    const r: number = Math.floor(this.pos / this.diffTotal) + dy; const c: number = (this.pos % this.diffTotal) + dx;
    if (r < 0 || r >= this.diffTotal || c < 0 || c >= this.diffTotal) { this.msg = TG('🧱 出界了，换个方向'); return; }
    this.pos = r * this.diffTotal + c; this.movesLeft = this.movesLeft - 1;
    if (this.pos === this.goal) {
      this.cleared = this.cleared + 1; this.score = this.score + 20 + this.movesLeft * 5; this.msg = TG('✅ 对齐成功！');
      if (this.cleared >= ROUNDS) {
        this.over = true; this.won = true; this.msg = TG2('🎉 {0} 个向量全部对齐！', String(ROUNDS)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.nextTo = setTimeout(() => {
        this.nextTo = -1; this.round = this.round + 1; this.genRound(); this.msg = TG('新向量来了，继续对齐');
      }, NEXT_MS);
      return;
    }
    if (this.movesLeft <= 0) {
      this.over = true; this.won = false; this.msg = TG('😵 步数用尽，还没走进 🎯'); this.finish(false); return;
    }
    const gapC: number = (this.goal % this.diffTotal) - (this.pos % this.diffTotal);
    const gapR: number = Math.floor(this.goal / this.diffTotal) - Math.floor(this.pos / this.diffTotal);
    this.msg = TG2("还差 {0} 列、{1} 行", String(gapC), String(gapR));
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'vector_grid_alignment', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cleared };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  private cellKey(i: number): string { return 'g' + i + (this.pos === i ? 'p' : '') + (this.goal === i ? 't' : ''); }
  private cellInk(i: number): string {
    if (this.pos === i) { return '#FFFFFF'; }
    return this.theme.ink;
  }
  private cellBg(i: number): string {
    if (this.pos === i) { return Palette.berry; }
    return this.goal === i ? this.theme.surfaceAlt : this.theme.bg;
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
        Text((TG('回合'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.movesLeft), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG2('➡️ 向量 v = ({0}, {1})', sign(this.vecX), sign(this.vecY))).fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold).fontColor(Palette.berry)
        Column({ space: Space.xs }) {
          ForEach(this.rowIdx(), (r: number) => {
            Row({ space: Space.xs }) {
              ForEach(this.rowIdx(), (c: number) => {
                Stack() {
                Text(this.pos === (r * this.diffTotal + c) ? '🧭' : (this.goal === (r * this.diffTotal + c) ? '🎯' : '')).fontSize(FontSize.lg).fontColor(this.cellInk((r * this.diffTotal + c)))
                }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cellBg((r * this.diffTotal + c))).borderRadius(Radius.sm)
                .border({ width: this.goal === (r * this.diffTotal + c) ? 2 : 1, color: this.goal === (r * this.diffTotal + c) ? Palette.emerald : this.theme.line })
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => this.cellKey(r * this.diffTotal + c))
            }.width('100%')
          }, (r: number) => 'r' + r)
        }.width('100%').aspectRatio(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt)
        // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
        //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
        .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
        .borderRadius(Radius.lg)
        Text(TG('(dx, dy)：+ 列向右、+ 行向下')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(('←'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.move((-1), (0));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move((-1), (0)); }); })
        Button(('↑'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.move((0), (-1));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move((0), (-1)); }); })
        Button(('↓'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.move((0), (1));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move((0), (1)); }); })
        Button(('→'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.move((1), (0));
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move((1), (0)); }); })
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
      Text(TG('提示：走错一步要花两步补回来，步数很紧')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
