/**
 * 互锁拼图 —— 卡榫互相咬住，只能先抽没人压着的那一块
 * 胜负：步数预算内全部抽出 ⇒ 通关｜进度：已抽 / 总数 + 剩余步数
 * ★ 步数预算 = 难度换算 livesNow(8)，下限 = 零件数 6（简单 12 / 普通 8 / 困难 6）——
 *   抽完 6 个零件至少要 6 步，原困难档 4 步在数学上永远赢不了。
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

const SLOTS: number = 9;
const PIECES: number = 6;
const MAX_MOVES: number = 8;
const GLYPH: string[] = ['🔩', '🔗', '🧩', '🪝', '⚙️', '🪢'];
const TINT: string[] = [Palette.rose, Palette.sky, Palette.amber, Palette.emerald, Palette.violet, Palette.teal];
const R3: number[] = [0, 1, 2];
const FALSE6: boolean[] = [false, false, false, false, false, false];

@Component
export struct GInterlockPuzzle {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  /** ★ 2026-10-28 修正：下限必须 ≥ PIECES —— 抽完 6 个零件至少要 6 步，
   *  困难档 livesNow(8) = floor(8×0.6) = 4 < 6 ⇒ 原来数学上永远赢不了。
   *  简单 12 / 普通 8 / 困难 6，三档都够用且难度递进。 */
  @State private diffTotal: number = Math.max(PIECES, GameDiff.livesNow(MAX_MOVES));
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State parts: number[] = [];       // 槽位 → 零件号（-1 空）
  @State gone: boolean[] = [];       // 零件是否已抽出
  @State blockers: number[][] = [];  // 每个零件被谁压着
  @State moves: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GInterlockPuzzle')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = Math.max(PIECES, GameDiff.livesNow(MAX_MOVES));   // 同上：永远 ≥ 零件数
     this.reset(); }

  /** 生成：按 0..5 顺序层层压 —— 编号大的被编号小的压，天然无环、必定有解 */
  private reset(): void {
    const order: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    const slots: number[] = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
    for (let i = 0; i < PIECES; i++) { slots[order[i]] = i; }
    const blk: number[][] = [];
    const used: boolean[] = FALSE6.slice();
    for (let i = 0; i < PIECES; i++) {
      const dep: number[] = [];
      for (let j = 0; j < i; j++) {
        if (!used[j] && Math.random() < 0.45) { dep.push(j); used[j] = true; }
      }
      blk.push(dep);
    }
    this.parts = slots; this.gone = FALSE6.slice(); this.blockers = blk;
    this.moves = 0; this.score = 0;
    this.msg = TG(TG(TG('亮色的零件没人压着，可以抽')));
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
  }

  private takenCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.gone.length; i++) { if (this.gone[i]) { n++; } }
    return n;
  }

  /** 还压着零件 p 的、尚未抽走的零件数 */
  private pressure(p: number): number {
    let n: number = 0;
    const dep: number[] = this.blockers.length > p ? this.blockers[p] : [];
    for (let i = 0; i < dep.length; i++) { if (!this.gone[dep[i]]) { n++; } }
    return n;
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
    if (this.moves >= this.diffTotal) {
      return true;
    }
    this.pull(this.parts.map((p: number, i: number) => (p >= 0 && !this.gone[p] && this.pressure(p) === 0) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let slot = 0; slot < this.parts.length; slot++) {
      const p: number = this.parts[slot];
      if (p < 0 || this.gone[p] || this.pressure(p) > 0) {
        continue;
      }
      const r: number = Math.floor(slot / 3) + 1;
      const c: number = (slot % 3) + 1;
      return Hint.make([slot],
        TG2('抽第 {0} 行第 {1} 格这个 {2}（没人压着）', String(r), String(c), GLYPH[p]),
        TG2('Pull the {2} at row {0}, column {1} — nothing is holding it down', String(r), String(c), GLYPH[p]), t0);
    }
    return Hint.none('none');
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

  private pull(slot: number): void {
    if (this.over) { return; }
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return; }
    if (this.pressure(p) > 0) {
      this.msg = TG2('🔒 {0} 还被 {1} 个零件压着', GLYPH[p], this.pressure(p));
      return;
    }
    const ng: boolean[] = this.gone.slice();
    ng[p] = true; this.gone = ng;
    this.moves = this.moves + 1;
    this.score = this.score + 100 + (this.blockers[p].length === 0 ? 30 : 0); this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    if (this.takenCount() === PIECES) {
      this.over = true; this.won = true;
      this.score = this.score + (this.diffTotal - this.moves) * 25;
      this.msg = '🎉 全部拆开！用了 ' + this.moves + TG(' 步');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.msg = TG2('💤 步数用尽，还剩 {0} 个零件', (PIECES - this.takenCount()));
      this.finish(false);
      return;
    }
    this.msg = TG2('✅ 抽出 {0}，看看谁松了', GLYPH[p]);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'interlock_puzzle', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.takenCount() };
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
      Text(TG2("已拆 {0}/{1}", this.takenCount(), PIECES))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(R3, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(R3, (c: number) => { this.part(r * 3 + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.md)
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
      Text(TG('格子里的数字 = 还压着它的零件数（灰色 = 抽不动）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  part(slot: number) {
    Stack() {
      Text(this.deco(slot)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF').textAlign(TextAlign.Center)
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(this.cellColor(slot))
    .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pull(slot); }); })
    .onClick(() => { Haptics.tick(); this.pull(slot); })
  }

  private deco(slot: number): string {
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return ''; }
    const press: number = this.pressure(p);
    return GLYPH[p] + (press > 0 ? '\n' + press : '');
  }

  private cellColor(slot: number): string {
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return this.theme.line; }
    if (this.pressure(p) > 0) { return this.theme.isDark ? '#3A3A3A' : '#CBD5E1'; }
    return TINT[p];
  }
}
