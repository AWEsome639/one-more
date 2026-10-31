/**
 * 折纸 📄
 * 规则：纸对折两次（你看到的是左上角那四分之一）；在折好的纸上打孔，孔会镜像成四份。
 * 胜负：展开后与目标完全一致 ⇒ 通关；步数用尽还没对上 ⇒ 失败。　进度：已打孔 / 步数
 */
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
import { Tv } from '../core/Tv';

const Q: number = 4; const F: number = Q * 2; const HOLES: number = 3; const LIMIT: number = 14;
// ★ 2026-10-23：原来这里是固定的 [0,1,2,3] / [0..7]，
//   与 diffTotal（3/4/5）不一致 ⇒ 渲染的行列数永远等于 4×4 与 8×8。
//   改成按 diffTotal 现算。
function idxOf(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) {
    out.push(i);
  }
  return out;
}

/** 折叠态 → 展开态：一个孔镜像成四份 */
/**
 * ★★★ 2026-10-23 修「尺寸陷阱」第 13 个：
 *   原来 unfold 固定用 Q=4 / F=8，但 fold 区按 diffTotal² 建（3/4/5）：
 *     · 简单 3×3：q 只有 9 项，索引 9..15 是 undefined（被当 false 跳过）
 *     · 困难 5×5：q 有 25 项，**16..24 号孔完全丢失**，goal 永远是错的；
 *       而且玩家在 5×5 上操作，这里按 4 的步长读 ⇒ 位置全错
 *   ⇒ 只有 4×4（普通档）是对的。
 *   修法：**边长跟着走**（qn = diffTotal，展开后 2*qn）。
 */
function unfold(q: boolean[], qn: number): boolean[] {
  const f: number = qn * 2;
  const out: boolean[] = new Array<boolean>(f * f).fill(false);
  for (let r = 0; r < qn; r++) {
    for (let c = 0; c < qn; c++) {
      if (!q[r * qn + c]) { continue; }
      out[r * f + c] = true; out[r * f + (f - 1 - c)] = true;
      out[(f - 1 - r) * f + c] = true; out[(f - 1 - r) * f + (f - 1 - c)] = true;
    }
  }
  return out;
}
function sameMap(a: boolean[], b: boolean[]): boolean {
  for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
  return true;
}
function countOf(a: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < a.length; i++) { if (a[i]) { n = n + 1; } }
  return n;
}

@Component
export struct GPaperFolding {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 Q=4，按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(4);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State private mine: boolean[] = []; @State private goal: boolean[] = []; @State private shown: boolean[] = [];
  @State private steps: number = 0; @State private over: boolean = false; @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPaperFolding')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  private reset(): void {
    const g: boolean[] = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { pool.push(i); }
    for (let k = 0; k < HOLES; k++) {
      const j: number = Math.floor(Math.random() * pool.length);
      g[pool[j]] = true; pool.splice(j, 1);
    }
    this.goal = unfold(g, this.diffTotal); this.mine = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false); this.shown = unfold(this.mine, this.diffTotal);
    this.steps = 0; this.over = false; this.won = false;
    this.msg = TG2('展开后要有 {0} 个孔，位置你自己找', String(HOLES * 4));
    this.startAt = Date.now();
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
    if (this.steps >= LIMIT) {
      return true;
    }
    this.punch(this.mine.map((v: boolean, i: number) => (v !== this.goal[Math.floor(i / this.diffTotal) * (this.diffTotal * 2) + (i % this.diffTotal)]) ? i : -1).filter((k: number) => k >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const q: number = this.diffTotal;
    const f: number = q * 2;
    const need: string[] = [];
    for (let i = 0; i < q * q; i++) {
      const want: boolean = this.goal[Math.floor(i / q) * f + (i % q)];
      if (want && !this.mine[i]) {
        need.push(TG2('第 {0} 行第 {1} 列', String(Math.floor(i / q) + 1), String((i % q) + 1)));
      }
    }
    if (need.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('在折好的纸上打这些孔：{0}', need.join('、')),
      TG2('Punch these on the folded paper: {0}', need.join(', ')), t0);
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

  private punch(i: number): void {
    if (this.over) { return; }
    const m: boolean[] = this.mine.slice();
    m[i] = !m[i];
    this.mine = m; this.shown = unfold(m, this.diffTotal); this.steps = this.steps + 1;
    if (sameMap(this.shown, this.goal)) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.steps >= LIMIT) { this.finish(false); return; }
    this.msg = TG2("已打 {0} 孔（展开后 {1} 个）", String(countOf(m)), String(countOf(this.shown)));
  }
  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 展开后与目标完全一致！' : '😵 步数用尽，图案还没对上';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'paper_folding', solved: solved,
      score: solved ? 100 + (LIMIT - this.steps) * 40 : countOf(this.shown) * 6,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 3 : 1
    });
  }
  /** mode 1 = 目标图，0 = 我的展开图 */
  private hasHole(mode: number, i: number): boolean { return mode === 1 ? this.goal[i] : this.shown[i]; }
  build() {
    Column({ space: Space.sm }) {
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
        Text((TG('目标孔'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(HOLES * 4))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已打'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(countOf(this.mine) * 4))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(LIMIT))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          Text(TG('折好的纸 · 点它打孔')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: Space.xs }) {
            ForEach(idxOf(this.diffTotal), (r: number) => {
              Row({ space: Space.xs }) {
                ForEach(idxOf(this.diffTotal), (c: number) => { Stack() {
                Text(this.mine[(r * this.diffTotal + c)] ? '🕳️' : '').fontSize(FontSize.sm)
                }.layoutWeight(1).aspectRatio(1)
                .backgroundColor(this.mine[(r * this.diffTotal + c)] ? Palette.amber : this.theme.surface)
                .borderRadius(Radius.sm).borderWidth(2)
                .borderColor(this.mine[(r * this.diffTotal + c)] ? Palette.primaryDeep : this.theme.line)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
                // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
                .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                  .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
                .onClick(() => { Haptics.tick(); this.punch((r * this.diffTotal + c)); })
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.punch((r * this.diffTotal + c)); }); }) }, (c: number) => 'fc' + c)
              }.width('100%')
            }, (r: number) => 'fr' + r)
          }.width('100%').aspectRatio(1).padding(Space.xs)
          // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
          //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
          .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
        }.layoutWeight(2)
        Column({ space: Space.xs }) {
          Text(TG('目标')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(idxOf(this.diffTotal * 2), (r: number) => {
          Row({ space: 1 }) {
          ForEach(idxOf(this.diffTotal * 2), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.hasHole((1), r * F + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
          }, (c: number) => (true ? 'gc' : 'mc') + c)
          }.width('100%')
          }, (r: number) => (true ? 'gr' : 'mr') + r)
          }.width('100%')
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('我的')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Column({ space: 1 }) {
          ForEach(idxOf(this.diffTotal * 2), (r: number) => {
          Row({ space: 1 }) {
          ForEach(idxOf(this.diffTotal * 2), (c: number) => {
          Text('').layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.hasHole((0), r * F + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
          }, (c: number) => (false ? 'gc' : 'mc') + c)
          }.width('100%')
          }, (r: number) => (false ? 'gr' : 'mr') + r)
          }.width('100%')
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
