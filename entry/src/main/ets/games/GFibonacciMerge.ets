/** 斐波那契合并 —— 合并斐波那契数；玩法：点两个相邻格子，若两数之和也是斐波那契数 ⇒ 合并成和，另一格补新数；胜负：合出 21 ⇒ 通关；错 3 次 ⇒ 失败 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const SLOT: number = 6; const GOAL: number = 21; const LIVES: number = 3;
const FIB: number[] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]; const SEED: number[] = [1, 2, 3];
function isFib(v: number): boolean {
  return FIB.indexOf(v) >= 0;
}
@Component
export struct GFibonacciMerge {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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
  @State private cells: number[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private sel: number = -1;
  @State private best: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private score: number = 0;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private slots: number[] = [0, 1, 2, 3, 4, 5];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFibonacciMerge')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  private reset(): void {
    const list: number[] = [];
    for (let i = 0; i < SLOT; i++) {
      list.push(SEED[Math.floor(Math.random() * SEED.length)]);
    }
    this.cells = list; this.sel = -1; this.best = 1; this.lives = this.total; this.score = 0; this.moves = 0; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now(); this.msg = TG('点两个相邻格子：和是斐波那契数就合并');
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    const lo: number = this.findPair();
    if (lo < 0) {
      return false;
    }
    if (this.sel < 0) {
      this.tap(lo);
      return true;
    }
    this.tap(this.sel === lo ? lo + 1 : this.sel);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 相邻两格的和是斐波那契数就能合 ⇒ 每次挑「和最大」的那一对，冲 21
  /** 该合哪一对的左格（没有合法对返回 -1 —— 这时绝不能乱点，会掉命） */
  private findPair(): number {
    let best: number = -1;
    let bestSum: number = 0;
    for (let i = 0; i + 1 < this.cells.length; i++) {
      const sum: number = this.cells[i] + this.cells[i + 1];
      if (isFib(sum) && sum > bestSum) {
        bestSum = sum;
        best = i;
      }
    }
    return best;
  }

  /** 提示：报要合的两格和它们的和 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const lo: number = this.findPair();
    if (lo < 0) {
      return Hint.none('none');
    }
    const sum: number = this.cells[lo] + this.cells[lo + 1];
    return Hint.make([lo, lo + 1],
      TG2('合第 {0}、{1} 格 —— 和是 {2}', String(lo + 1), String(lo + 2), String(sum)),
      TG2('Merge cells {0} and {1} — their sum is {2}', String(lo + 1), String(lo + 2), String(sum)), t0);
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
    if (this.over) { return; }
    if (this.sel < 0) { this.sel = i; return; }
    if (this.sel === i) { this.sel = -1; return; }
    const lo: number = Math.min(this.sel, i); const hi: number = Math.max(this.sel, i);
    const sum: number = this.cells[lo] + this.cells[hi]; this.sel = -1;
    if (hi - lo === 1 && isFib(sum)) {
      const next: number[] = this.cells.slice(); next[lo] = sum;
      next[hi] = SEED[Math.floor(Math.random() * SEED.length)]; this.cells = next; this.moves = this.moves + 1;
      this.score += sum * 10;
      if (sum > this.best) { this.best = sum; }
      if (sum >= GOAL) {
        this.over = true; this.won = true; this.msg = TG2('🎉 合出 {0}！第 {1} 步通关', String(sum),Digits(String(this.moves), this.langCode));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2('✅ {0} 也是斐波那契数，继续往 {1} 冲', String(sum), String(GOAL)); return;
    }
    this.lives = this.lives - 1; this.score = Math.max(0, this.score - 20); this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.lives <= 0) {
      this.over = true; this.won = false; this.msg = TG2('💔 只能合相邻两格、且和要是斐波那契数（这次和是 {0}）', String(sum)); this.finish(false); return;
    }
    this.msg = TG2('❌ 要相邻两格、和还要是斐波那契数（这次和是 {0}），还剩 {1} 次', String(sum),Digits(String(this.lives), this.langCode));
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'fibonacci_merge', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.best
    }; LanRace.noteDone(); this.onFinish(r);
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
        Text((TG('最大'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.best + '/' + GOAL)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('机会'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(('❤️×' + String(this.lives))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('🌀').fontSize(FontSize.xxl)
          .accessibilityLevel('no')
        Text(TG('把相邻两数合成斐波那契数')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.primary)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(this.slots, (i: number) => {
          Stack() {
          Text(String(this.cells[(i)])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.sel === (i) ? '#FFFFFF' : this.theme.ink)
          }.layoutWeight(1).height(Cell.of(72)).backgroundColor(this.sel === (i) ? Palette.violet : this.theme.surface)
          .borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); })
          .onClick(() => { Haptics.tick(); this.tap((i)); })
        }, (i: number) => 'fbm' + i + '_' + this.cells[i])
      }.width('100%').height(Cell.of(72))
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：相邻两格之和要落在 1,2,3,5,8,13,21… 里；合到 21 即通关')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
