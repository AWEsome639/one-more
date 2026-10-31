/**
 * 网格位移 —— 心里执行一串位移指令，落到哪一格就点哪一格
 * 胜负：6 题答对 ≥4 ⇒ 通关｜进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 4;
const QN: number = 6;
const PASS: number = 4;
const ARROWS: string[] = ['↑', '→', '↓', '←'];
const R4: number[] = [0, 1, 2, 3];

/** 一步位移：d 0上1右2下3左；ok=false 表示撞墙原地不动 */
interface Step { d: number; ok: boolean }

@Component
export struct GGridDisplacement {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PASS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(PASS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State steps: Step[] = [];
  @State startPos: number = 0; @State curPos: number = 0;
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GGridDisplacement')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PASS);
     this.reset(); }

  private reset(): void {
    this.qIndex = 0; this.right = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.load();
  }

  /** 抽一个新起点，逐步走一遍指令串；越界的指令记为「被墙挡住」 */
  private load(): void {
    const sp: number = Math.floor(Math.random() * (N * N));
    const list: Step[] = [];
    let r: number = Math.floor(sp / N);
    let c: number = sp % N;
    const count: number = 3 + Math.floor(Math.random() * 3);
    for (let i = 0; i < count; i++) {
      const d: number = Math.floor(Math.random() * 4);
      const nr: number = d === 0 ? r - 1 : (d === 2 ? r + 1 : r);
      const nc: number = d === 1 ? c + 1 : (d === 3 ? c - 1 : c);
      const ok: boolean = nr >= 0 && nr < N && nc >= 0 && nc < N;
      if (ok) { r = nr; c = nc; }
      list.push({ d: d, ok: ok });
    }
    this.startPos = sp; this.curPos = sp; this.steps = list;
    this.msg = TG(TG(TG('被墙挡住的那一步，原地不动')));
  }

  private seqText(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.steps.length; i++) { parts.push(ARROWS[this.steps[i].d]); }
    return parts.join(' ');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：网格位移
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
    if (this.over) {
      return true;
    }
    this.tap(this.curPos);
    return !this.over;
  }

  /** 提示：直接报该点的位置 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.curPos;
    return Hint.make([k],
      TG2('点第 {0} 个', String(k + 1)),
      TG2('Tap number {0}', String(k + 1)), t0);
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

  private tap(cell: number): void {
    if (this.over) { return; }
    if (cell === this.curPos) {
      const gain: number = 100 + (QN - this.qIndex) * 10;
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.score = this.score + gain;
      this.msg = TG2('✅ 落点正确 +{0}', gain);
    } else {
      this.msg = '❌ 应落在第 ' + (Math.floor(this.curPos / N) + 1) + ' 行第 ' + (this.curPos % N + 1) + TG(' 列');
    }
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= this.diffTotal;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", this.right, QN);
      this.finish(this.won);
      return;
    }
    this.load();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'grid_displacement', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
      Text(TG2("题 {0}/{1}", Math.min(this.qIndex + 1, QN), QN))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Text(this.seqText())
        .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .width('100%').textAlign(TextAlign.Center).padding(Space.md)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Column({ space: Space.xs }) {
        ForEach(R4, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(R4, (c: number) => { this.cell(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.isDark ? '#141414' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG('🚩 是起点，点你心里算出来的落点')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cell(cell: number) {
    Stack() {
      Text(cell === this.startPos ? '🚩' : '').fontSize(FontSize.lg)
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(cell === this.startPos ? Palette.violet : this.theme.line)
    .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(cell); }); })
    .onClick(() => { Haptics.tick(); this.tap(cell); })
  }
}
