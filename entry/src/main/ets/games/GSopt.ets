/**
 * 自定顺序（SOPT）—— 9 个方格随机布号，按 1→9 依次点，序号每轮重排
 * 胜负：撑过 3 轮通关 / 点错 3 次失败
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 3;
const CELLS: number = N * N;
const ROUNDS: number = 3;

@Component
export struct GSopt {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
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

  @State private spots: number[] = [];   // 每格上的序号，0 = 空位
  @State private filled: number[] = [];  // 已点的格子
  @State private next: number = 1;       // 下一个该点的号
  @State private round: number = 1;
  @State private wrong: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = TG(TG(TG('按 1 → 9 依次点')));
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private roundAt: number = 0;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSopt')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); } }

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
    if (this.nextTo >= 0) {
      return true;
    }
    this.aiTap(0);
    return !this.over;
  }

  /** 提示：下一个号码在哪格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.next < 1 || this.next > CELLS) { return Hint.none('none'); }
    const i: number = this.spots.indexOf(this.next);
    if (i < 0) { return Hint.none('none'); }
    const rr: string = String(Math.floor(i / N) + 1);
    const cc: string = String((i % N) + 1);
    return Hint.make([i], TG2('下一个是 {0} 号，在第 {1} 行第 {2} 列', String(this.next), rr, cc),
      TG2('Next is {0}: row {1}, column {2}', String(this.next), rr, cc), t0);
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
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.filled = []; this.score = 0; this.wrong = 0; this.round = 1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.shuffle();
  }

  /** 9 个号随机撒进 3×3 */
  private shuffle(): void {
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i + 1); }
    const out: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      const j: number = Math.floor(Math.random() * pool.length);
      out.push(pool[j]);
      pool.splice(j, 1);
    }
    this.spots = out;
    this.filled = [];
    this.next = 1;
    this.roundAt = Date.now();
    this.msg = TG('第 ') + String(this.round) + '/' + String(this.diffTotal) + ' 轮：按 1 → 9 依次点';
  }

  private tap(i: number): void {
    if (this.over || this.spots.length === 0 || this.filled.indexOf(i) >= 0) { return; }
    if (this.spots[i] !== this.next) {
      const want: number = this.next;
      this.wrong = this.wrong + 1;
      this.msg = TG2('❌ 该点 {0} 号', String(want));
      if (this.wrong >= 3) { this.stop(false); }
      return;
    }
    const hit: number[] = this.filled.slice();
    hit.push(i);
    this.filled = hit;
    this.next = this.next + 1;
    if (this.next <= CELLS) {
      this.msg = TG2('下一个 {0} 号', String(this.next));
      return;
    }
    const used: number = Date.now() - this.roundAt;
    this.score = this.score + Math.max(0, CELLS * 800 - used); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.round >= this.diffTotal) { this.stop(true); return; }
    this.round = this.round + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    this.msg = TG2('✅ 本轮 {0} ms，下一轮重排', String(used));
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.shuffle(); }, 700);
  }

  private stop(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.over = true; this.won = solved;
    const went: number = solved ? this.diffTotal : this.round - 1;
    this.msg = (solved ? TG('🎉 通关 ') : TG('💤 失败 ')) +TG2("完成 {0}/{1}", String(went), String(this.diffTotal))
      + TG2(' 轮 · 点错 {0} 次',Digits(String(this.wrong), this.langCode));
    const r: GameResult = {
      gameId: 'sopt', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    return this.filled.indexOf(i) >= 0 ? Palette.cyan : this.theme.surface;
  }

  private face(i: number): string {
    return this.filled.indexOf(i) >= 0 ? '✔' : String(this.spots[i]);
  }

  /** AI 用：下一个该点的号在哪格，就点哪格 */
  private aiTap(_d: number): void {
    if (this.next < 1 || this.next > CELLS) { return; }
    const i: number = this.spots.indexOf(this.next);
    if (i >= 0) { this.tap(i); }
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
        Text(TG2("轮次 {0}/{1}",Digits(String(this.round), this.langCode),Digits(String(this.diffTotal), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2('下一个 {0}', String(this.next))).fontSize(FontSize.sm).fontColor(Palette.cyan)
        Text(TG2('点错 {0}/3', String(this.wrong))).fontSize(FontSize.sm).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.sm)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              this.dot(r * N + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.cyan)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
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
  dot(i: number) {
    Stack() {
      Text(this.face(i))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
        .fontColor(this.filled.indexOf(i) >= 0 ? '#FFFFFF' : this.theme.ink)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
  }
}
