/** 记忆矩阵 —— 亮格闪一下，凭记忆全部点出来；过 5 关通关，点错 3 次失败 */
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

const N: number = 3;
const CELLS: number = N * N;
const PASS_LEVEL: number = 5;
const LIVES: number = 3;
const SHOW_MS: number = 1500;

@Component
export struct GMemoryMatrix {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private lit: boolean[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private need: number = 0;
  @State private picks: number[] = [];
  @State private wrong: number[] = [];
  @State private level: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private phase: number = 0;   // 0 展示 / 1 作答 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private showTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMemoryMatrix')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.showTo >= 0) { clearTimeout(this.showTo); this.showTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  /** 本局要画几颗心（读 this.lives 建立 ArkUI 依赖，否则不重渲染） */
  private heartIdx(): number[] {
    const observed: number = this.lives;
    const n: number = this.total > 0 ? this.total : 3;
    const a: number[] = [];
    for (let i = 0; i < n; i++) {
      a.push(i);
    }
    return observed >= 0 ? a : a;
  }

  private reset(): void {
    this.clearAll();
    this.level = 1; this.lives = this.total; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newLevel();
  }

  private newLevel(): void {
    const k: number = Math.min(1 + this.level, CELLS - 2);
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    const flags: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let i = 0; i < k; i++) { flags[slots[i]] = true; }
    this.lit = flags; this.need = k; this.picks = []; this.wrong = []; this.phase = 0;
    this.msg = TG('第 ') + String(this.level) + ' 关：记住 ' + String(k) + ' 个亮格';
    this.showTo = setTimeout(() => {
      this.showTo = -1; this.phase = 1; this.msg = TG(TG(TG('把亮过的格子点出来')));
    }, SHOW_MS);
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
    if (this.phase !== 1 || this.memNext() < 0) {
      return true;
    }
    this.tap(this.memNext());
    return !this.over;
  }

  /** 代打/提示共用：下一个还没点过的亮格（-1 = 没有） */
  private memNext(): number {
    for (let i = 0; i < CELLS; i++) {
      if (this.lit[i] && this.picks.indexOf(i) < 0) {
        return i;
      }
    }
    return -1;
  }

  /** 提示：展示阶段报「要记哪几格」，作答阶段报「下一个点哪格」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 0) {
      let s: string = '';
      for (let i = 0; i < CELLS; i++) {
        if (this.lit[i]) {
          const r0: number = Math.floor(i / N) + 1;
          const c0: number = i - Math.floor(i / N) * N + 1;
          s = s + (s.length > 0 ? '、' : '') + '(' + String(r0) + ',' + String(c0) + ')';
        }
      }
      return Hint.make([], TG2('要记的格子（行,列）：{0}', s),
        TG2('Cells to remember (row,col): {0}', s), t0);
    }
    const k: number = this.memNext();
    if (k < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(k / N) + 1;
    const c: number = k - Math.floor(k / N) * N + 1;
    return Hint.make([k],
      TG2('点第 {0} 行第 {1} 列（还差 {2} 格）', String(r), String(c), String(this.need - this.picks.length)),
      TG2('Tap row {0}, column {1} ({2} to go)', String(r), String(c), String(this.need - this.picks.length)), t0);
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

  private tap(i: number): void {
    if (this.over || this.phase !== 1) { return; }
    if (this.picks.indexOf(i) >= 0 || this.wrong.indexOf(i) >= 0) { return; }
    if (this.lit[i]) {
      const next: number[] = this.picks.slice();
      next.push(i);
      this.picks = next;
      if (next.length < this.need) {
        this.msg = TG('还差 ') + String(this.need - next.length) + TG(' 格');
        return;
      }
      this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.level >= PASS_LEVEL) {
        this.phase = 2; this.over = true; this.won = true;
        this.msg = TG('🎉 通关！') + String(PASS_LEVEL) + ' 关全过';
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.level = this.level + 1;
      this.msg = TG(TG(TG('✅ 过关')));
      this.nextTo = setTimeout(() => { this.nextTo = -1; this.newLevel(); }, 620);
      return;
    }
    const bad: number[] = this.wrong.slice();
    bad.push(i);
    this.wrong = bad;
    this.lives = this.lives - 1;
    if (this.lives <= 0) {
      this.phase = 2; this.over = true; this.won = false;
      this.msg = '❌ 生命耗尽，止步第 ' + String(this.level) + TG(' 关');
      this.finish(false);
      return;
    }
    this.msg = '❌ 这格没亮过，还剩 ' + String(this.lives) + TG(' 条命');
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'memory_matrix', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 0) { return this.lit[i] ? Palette.primary : this.theme.surfaceAlt; }
    if (this.phase === 1) {
      if (this.picks.indexOf(i) >= 0) { return Palette.emerald; }
      return this.wrong.indexOf(i) >= 0 ? Palette.rose : this.theme.surfaceAlt;
    }
    return this.lit[i] ? Palette.emerald : this.theme.surfaceAlt;
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
        Text(TG2('关卡 {0}', (String(this.level) + '/' + String(PASS_LEVEL)))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2("得分 {0}",Digits(String(this.score), this.langCode))).fontSize(FontSize.xs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.ink)
        Text(TG2('还需 {0}', this.phase === 1 ? String(Math.max(this.need - this.picks.length, 0)) : '—')).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Row({ space: Space.xs }) {
        // ★ 心数按**本局实际命数**渲染（简单 5 / 普通 3 / 困难 1），
        //   以前写死 [0,1,2] ⇒ 简单档 5 条命只画 3 颗，玩家看不出难度差别
        ForEach(this.heartIdx(), (k: number) => {
          Text('❤️').accessibilityLevel('no').fontSize(FontSize.md).opacity(k < this.lives ? 1 : 0.2).animation({ duration: Motion.fast, curve: Motion.snap() })
        }, (k: number) => 'h' + k)
      }.width('100%').justifyContent(FlexAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：每关多一格，点错扣一条命'))
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
      Text(this.phase === 1 && this.picks.indexOf(i) >= 0 ? '✓'
        : (this.phase === 1 && this.wrong.indexOf(i) >= 0 ? '✕' : ''))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
