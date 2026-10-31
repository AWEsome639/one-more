/**
 * 像素临摹 👾
 * 规则：照着左边的目标像素图，在右边点出一样的图案（再点一次可擦掉）。
 * 胜负：64 格全部一致 ⇒ 通关；步数用尽还没画对 ⇒ 失败。　进度：对上几格 / 步数
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

const N: number = 8; const LIMIT: number = 70;
const IDXN: number[] = [0, 1, 2, 3, 4, 5, 6, 7];

function sameMap(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
  return true;
}
function matchedOf(a: boolean[], b: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i] === b[i]) { n = n + 1; } }
  return n;
}
function countOf(a: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i]) { n = n + 1; } }
  return n;
}

@Component
export struct GPixelMimic {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=8）
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
  @State private diffTotal: number = GameDiff.sizeNow(8);
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
  @State private goal: boolean[] = []; @State private mine: boolean[] = [];
  @State private steps: number = 0; @State private over: boolean = false; @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPixelMimic')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  private reset(): void {
    this.goal = this.makeGoal();
    this.mine = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    this.steps = 0; this.over = false; this.won = false;
    this.msg = TG('照左边画，多点的格子再点一次就擦掉');
    this.startAt = Date.now();
  }
  /** 四向对称 ⇒ 生成的图案像个小怪物的脸 */
  private makeGoal(): boolean[] {
    for (let attempt = 0; attempt < 40; attempt++) {
      const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
      for (let r = 0; r < this.diffTotal / 2; r++) {
        for (let c = 0; c < this.diffTotal / 2; c++) {
          if (Math.random() < 0.5) {
            g[r * this.diffTotal + c] = true; g[r * this.diffTotal + (this.diffTotal - 1 - c)] = true;
            g[(this.diffTotal - 1 - r) * this.diffTotal + c] = true; g[(this.diffTotal - 1 - r) * this.diffTotal + (this.diffTotal - 1 - c)] = true;
          }
        }
      }
      const n: number = countOf(g);
      if (n >= 12 && n <= 30) { return g; }
    }
    const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    for (let r = 0; r < this.diffTotal; r++) {
      for (let c = 0; c < this.diffTotal; c++) {
        if (Math.abs(r - 3.5) + Math.abs(c - 3.5) <= 2) { g[r * this.diffTotal + c] = true; }
      }
    }
    return g;
  }
  /** 提示：和代打同一个循环（含局部常量），只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.goal.length; i++) {
      if (this.goal[i] !== this.mine[i]) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 变体⑦：照真值数组走
  // goal vs mine：哪个格子不一致就点哪个（点一下翻转）
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
    for (let i = 0; i < this.goal.length; i++) {
      if (this.goal[i] !== this.mine[i]) {
        this.paint(i);
        return !this.over;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private paint(i: number): void {
    if (this.over) { return; }
    const m: boolean[] = this.mine.slice();
    m[i] = !m[i];
    this.mine = m; this.steps = this.steps + 1;
    if (sameMap(m, this.goal)) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.steps >= LIMIT) { this.finish(false); return; }
    this.msg = TG2("对上 {0}/{1} 格", String(matchedOf(m, this.goal)), String(this.diffTotal * this.diffTotal));
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 一模一样！' : '😵 步数用尽，还差几格';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'pixel_mimic', solved: solved,
      score: solved ? 120 + (LIMIT - this.steps) * 8 : matchedOf(this.mine, this.goal) * 2,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 2 : 1
    });
  }
  /** mode 1 = 目标图，0 = 我的画布 */
  private pixOf(mode: number, i: number): boolean { return mode === 1 ? this.goal[i] : this.mine[i]; }
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
        Text((TG('目标格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(countOf(this.goal)))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('对上'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(matchedOf(this.mine, this.goal)) + '/' + String(this.diffTotal * this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(LIMIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
          Text(TG('目标')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 1 }) {
          ForEach(this.rowIdx(), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.pixOf((1), r * this.diffTotal + c) ? Palette.amber : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          if (false) { this.paint(r * this.diffTotal + c); }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (false) { this.paint(r * this.diffTotal + c); } }); })
          }, (c: number) => (true ? 'gc' : 'pc') + c)
          }.width('100%')
          }, (r: number) => (true ? 'gr' : 'pr') + r)
          }.width('100%').padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('你的画布 · 点格子')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 1 }) {
          ForEach(this.rowIdx(), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.pixOf((0), r * this.diffTotal + c) ? Palette.amber : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          if (true) { this.paint(r * this.diffTotal + c); }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (true) { this.paint(r * this.diffTotal + c); } }); })
          }, (c: number) => (false ? 'gc' : 'pc') + c)
          }.width('100%')
          }, (r: number) => (false ? 'gr' : 'pr') + r)
          }.width('100%').padding(Space.xs)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }.layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
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
