/** 多目标追踪 —— 高亮目标混进圆点里移动，停下后指出来；3 轮全对 ≥2 轮通关 */
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
const CELLS: number = N * N;
const DOTS: number = 7;
const ROUNDS: number = 3;
const TICK_MS: number = 420;
const TICKS: number = 6;
const SHOW_MS: number = 1700;

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GMultipleObjectTracking {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private pos: number[] = [];
  @State private targets: number = 3;
  @State private picks: number[] = [];
  @State private good: number[] = [];
  @State private missed: number[] = [];
  @State private round: number = 1;
  @State private hitRounds: number = 0;
  @State private score: number = 0;
  @State private phase: number = 0;   // 0 高亮 / 1 移动 / 2 作答 / 3 揭晓 / 4 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private ticks: number = 0;
  private moveId: number = -1;
  private showTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMultipleObjectTracking')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.moveId >= 0) { clearInterval(this.moveId); this.moveId = -1; } if (this.showTo >= 0) { clearTimeout(this.showTo); this.showTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
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
    if (this.phase !== 2) {
      return true;
    }
    this.aiPick(0);
    return !this.over;
  }

  /** 提示：目标是哪几格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase !== 2) {
      return Hint.make([], TG('还没到作答：先盯住高亮的圆点'),
        TG('Not yet: keep your eyes on the highlighted dots'), t0);
    }
    const tgt: number[] = this.pos.slice(0, this.targets);
    let s: string = '';
    for (let i = 0; i < tgt.length; i++) {
      const rr: string = String(Math.floor(tgt[i] / N) + 1);
      const cc: string = String(tgt[i] % N + 1);
      s = s + (i > 0 ? '，' : '') + TG2('第 {0} 行第 {1} 列', rr, cc);
    }
    return Hint.make(tgt, TG2('目标就在：{0}', s),
      TG2('The targets are at: {0}', s), t0);
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

  private reset(): void {
    this.clearAll();
    this.round = 1; this.hitRounds = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const cnt: number = 1 + this.round;
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    this.targets = cnt;
    this.pos = slots.slice(0, DOTS);
    this.picks = []; this.good = []; this.missed = []; this.phase = 0;
    this.msg = TG2('盯住 {0} 个高亮目标', String(cnt));
    this.showTo = setTimeout(() => {
      this.showTo = -1; this.phase = 1; this.ticks = 0; this.msg = TG(TG(TG('它们动起来了，盯住')));
      this.moveId = setInterval(() => { this.step(); }, TICK_MS);
    }, SHOW_MS);
  }

  /** 每一拍让两对圆点互换位置，看起来就在移动 */
  private step(): void {
    if (this.phase !== 1) { return; }
    for (let k = 0; k < 2; k++) {
      const i: number = Math.floor(Math.random() * DOTS);
      let j: number = Math.floor(Math.random() * DOTS);
      if (j === i) { j = (j + 1) % DOTS; }
      const next: number[] = this.pos.slice();
      const t: number = next[i]; next[i] = next[j]; next[j] = t;
      this.pos = next;
    }
    this.ticks = this.ticks + 1;
    if (this.ticks >= TICKS) {
      if (this.moveId >= 0) { clearInterval(this.moveId); this.moveId = -1; }
      this.phase = 2;
      this.msg = TG(TG(TG('停！点出刚才的高亮目标')));
    }
  }

  private tap(i: number): void {
    if (this.over || this.phase !== 2 || has(this.picks, i)) { return; }
    const next: number[] = this.picks.slice();
    next.push(i);
    this.picks = next;
    if (next.length < this.targets) {
      this.msg = TG('还差 ') + String(this.targets - next.length) + TG(' 个');
      return;
    }
    this.judge();
  }

  private judge(): void {
    const tgt: number[] = this.pos.slice(0, this.targets);
    const good: number[] = [];
    const missed: number[] = [];
    for (let i = 0; i < this.picks.length; i++) { if (has(tgt, this.picks[i])) { good.push(this.picks[i]); } }
    for (let i = 0; i < tgt.length; i++) { if (!has(this.picks, tgt[i])) { missed.push(tgt[i]); } }
    this.good = good;
    this.missed = missed;
    this.score = this.score + good.length * 100;
    if (good.length === this.targets) { this.hitRounds = this.hitRounds + 1; }
    this.phase = 3;
    this.msg = good.length === this.targets ? '✅ 全对' : TG2("差了 {0} 个", String(missed.length));
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.phase = 4; this.over = true; this.won = this.hitRounds >= 2;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("全对 {0}/{1} 轮", String(this.hitRounds), String(this.diffTotal));
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.newRound();
    }, 1300);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'multiple_object_tracking', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 3 || this.phase === 4) {
      if (has(this.good, i)) { return Palette.emerald; }
      if (has(this.missed, i)) { return Palette.amber; }
      return has(this.picks, i) ? Palette.rose : this.theme.surfaceAlt;
    }
    if (!has(this.pos, i)) { return this.theme.surfaceAlt; }
    if (this.phase === 0) { return has(this.pos.slice(0, this.targets), i) ? Palette.amber : this.theme.lineSoft; }
    if (this.phase === 2 && has(this.picks, i)) { return Palette.primary; }
    return this.theme.lineSoft;
  }

  /** 圆点本身的颜色：目标格用白点，其余用深点 */
  private dotInk(i: number): string {
    if (this.phase === 0) { return has(this.pos.slice(0, this.targets), i) ? '#FFFFFF' : '#334155'; }
    if (this.phase === 2 && has(this.picks, i)) { return '#FFFFFF'; }
    if (this.phase >= 3) { return has(this.good, i) || has(this.missed, i) ? '#FFFFFF' : this.theme.surfaceAlt; }
    return this.theme.surface;
  }

  /** AI 用：停下那一刻，目标就是 pos 的前 targets 个 */
  private aiPick(_d: number): void {
    if (this.phase !== 2) { return; }
    const tgt: number[] = this.pos.slice(0, this.targets);
    for (let i = 0; i < tgt.length; i++) {
      if (this.picks.indexOf(tgt[i]) < 0) { this.tap(tgt[i]); return; }
    }
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
      Row() {
        Text(TG2("轮次 {0}", (String(this.round) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2('目标 {0}', String(this.targets))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2('全对 {0}', String(this.hitRounds))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：先扫全场再锁定目标；目标数 3/4/5 递增'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(has(this.pos, i) ? '●' : '').fontSize(FontSize.lg).fontColor(this.dotInk(i))
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
  }
}
