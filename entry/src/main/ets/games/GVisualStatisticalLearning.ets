/** 统计学习 📐（id: visual_statistical_learning）
 * 一串图形逐个闪过，其中某三个总是连着出现；看完后从四个组合里挑出那一组；
 * 3 轮答对 ≥2 ⇒ 通关，否则失败。 */
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
const POOL: string[] = ['🍎', '🍌', '🍇', '🍓', '🍑', '🥝'];
const TOTAL: number = 15;
const AT: number[] = [0, 5, 10];
const ROUNDS: number = 3;
const NEED: number = 2;
const GAP: number = 520;
const PAUSE: number = 900;
const SLOTS: number[] = [0, 1, 2, 3];
@Component
export struct GVisualStatisticalLearning {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State stream: string[] = [];
  @State cursor: number = 0;
  @State asking: boolean = false;
  @State opts: string[][] = [];
  @State ans: number = 0;
  @State round: number = 0;
  @State hits: number = 0;
  @State picked: number = -1;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  private wait: number = -1;
  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVisualStatisticalLearning')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 0; this.hits = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }
  /** 随机取 3 个互不相同的图形 */
  private pickThree(): string[] {
    const out: string[] = [];
    while (out.length < 3) {
      const e: string = POOL[Math.floor(Math.random() * POOL.length)];
      if (out.indexOf(e) < 0) { out.push(e); } }
    return out;
  }
  private newRound(): void {
    const base: string[] = this.pickThree(); const s: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) { s.push(POOL[Math.floor(Math.random() * POOL.length)]); }
    for (let k = 0; k < AT.length; k++) { for (let j = 0; j < 3; j++) { s[AT[k] + j] = base[j]; } }
    this.stream = s; this.cursor = 0; this.asking = false; this.picked = -1; this.opts = [];
    this.note = TG('盯住反复连着出现的那三个'); this.clearAll();
    this.timer = setInterval(() => {
      this.cursor = this.cursor + 1;
      if (this.cursor >= this.diffTotal) { this.ask(base); }
    }, GAP);
  }
  /** 打乱四个组合选项后上屏 */
  private ask(base: string[]): void {
    this.clearAll();
    const rest: string[][] = [];
    const seen: string[] = [base.join('')];
    while (rest.length < 3) {
      const t: string[] = this.pickThree();
      if (seen.indexOf(t.join('')) >= 0) { continue; }
      seen.push(t.join('')); rest.push(t); }
    const at: number = Math.floor(Math.random() * 4);
    const out: string[][] = []; let k: number = 0;
    for (let i = 0; i < 4; i++) {
      if (i === at) { out.push(base); } else { out.push(rest[k]); k++; }
    }
    this.opts = out; this.ans = at; this.asking = true; this.note = TG('哪三个总是连着出现？');
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
    if (this.over || !this.asking || this.picked >= 0) { return; }
    this.picked = i;
    if (i === this.ans) { this.hits++; this.note = TG('✅ 就是这一组'); } else { this.note = TG('❌ 绿框那组才是'); }
    this.clearAll();
    this.wait = setTimeout(() => {
      this.wait = -1;
      if (this.round + 1 >= ROUNDS) { this.finish(this.hits >= NEED); return; }
      this.round++; this.newRound();
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.clearAll();
    const r: GameResult = {
      gameId: 'visual_statistical_learning', solved: solved, score: this.hits * 60,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private now(): string {
    return this.stream.length === 0 ? '' : this.stream[Math.min(this.cursor, this.stream.length - 1)];
  }
  private label(t: string[]): string {
    return t.length < 3 ? '' : t[0] + ' › ' + t[1] + ' › ' + t[2];
  }
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
      Text(TG('第 ') + String(Math.min(this.round + 1, ROUNDS)) + '/' + String(ROUNDS) + ' 轮 · 答对 ' +
        String(this.hits) + '/' + String(NEED) + ' · ' + String(Math.min(this.cursor + 1, this.diffTotal)) +
        '/' + String(this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      if (!this.asking) {
        Column({ space: Space.xs }) {
          Text(this.now()).fontSize(FontSize.hero)
          Text(TG('看 · 记住连在一起的那三个')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .width('100%').height(Space.xxxl * 2).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      } else {
        ForEach(SLOTS, (i: number) => {
          this.option(i)
        }, (i: number) => 'so' + i)
      }
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
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
  option(i: number) {
    Text(this.opts.length > i ? this.label(this.opts[i]) : '')
      .fontSize(FontSize.xl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52)).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .borderWidth(2)
      .borderColor(this.picked < 0 ? this.theme.line :
        (i === this.ans ? Palette.emerald : (i === this.picked ? Palette.rose : this.theme.line)))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.pick(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); })
  }
}
