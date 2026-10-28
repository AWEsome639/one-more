/** 质因数树 —— 把合数一路拆成质因数｜5 棵拆开 4 棵过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 5;
const PASS: number = 4;
const PRIMES: number[] = [2, 3, 5, 7, 11, 13];
const POOL: number[] = [12, 18, 20, 24, 28, 30, 36, 40, 42, 45, 48, 50, 54, 56, 60, 63, 70, 72, 84, 90, 96, 100, 108, 120, 126, 132, 144];

@Component
export struct GPrimeFactorTrees {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private target: number = 12;
  @State private rest: number = 12;
  @State private chain: string[] = [];
  @State private level: number = 0;
  @State private clears: number = 0;
  @State private score: number = 0;
  @State private miss: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('点能整除的质数');
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.level = 0;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.load();
  }

  private load(): void {
    this.target = POOL[Math.floor(Math.random() * POOL.length)];
    this.rest = this.target;
    this.chain = [];
    this.miss = 0;
    this.tip = TG2('把 {0} 拆成质因数', String(this.target));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：找一个能整除 rest 的质数，点它
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.rest <= 1) {
      return true;              // 这一棵分解完了，等它换下一棵
    }
    for (let k = 0; k < PRIMES.length; k++) {
      const p: number = PRIMES[k];
      if (this.rest % p === 0) {
        this.tap(p);
        return !this.over;
      }
    }
    return false;               // 没有能整除的质数（理论上不会发生）
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

  private tap(p: number): void {
    if (this.over || this.rest <= 1) { return; }
    if (this.rest % p === 0) {
      this.rest = this.rest / p;
      const c: string[] = this.chain.slice();
      c.push(String(p));
      this.chain = c;
      this.score += 4;
      if (this.rest === 1) {
        this.clears++;
        this.score += 10;
        this.next('✓ ' + this.chain.join(' × ') + ' = ' + String(this.target));
      } else {
        this.tip = TG2('还剩 {0}，继续拆', String(this.rest));
      }
      return;
    }
    this.miss++;
    this.tip = String(p) + TG2(' 除不尽 {0}，换一个', String(this.rest));
    if (this.miss >= 3) { this.next(TG2('✗ {0} 没能拆完', String(this.target))); }
  }


  /**
   * ★ 2026-10-23 第二期：质因数树提示
   *
   * 玩法是「把目标数一步步拆成质因数」。
   * 提示 = **当前剩余数能被哪个质数整除**（取最小的那个）。
   * 这正好是下一步该点的按钮，而且给出了"为什么"。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.rest;
    if (n <= 1) {
      return Hint.none('none');
    }
    for (let k = 0; k < PRIMES.length; k++) {
      const p: number = PRIMES[k];
      if (n % p === 0) {
        return Hint.make([],
          TG2('{0} 能被 {1} 整除（{0} ÷ {1} = {2}），点 {1}',
            String(n), String(p), String(n / p)),
          TG2('{0} divides by {1} ({0} ÷ {1} = {2}) — tap {1}',
            String(n), String(p), String(n / p)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private next(msg: string): void {
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = msg + TG2('｜共拆开 {0}/{1} 棵', String(this.clears), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'prime_factor_trees', solved: this.clears >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.clears
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.load();
    this.tip = TG2("{0}，接着下一棵", msg);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onAutoTap: () => { this.askAuto(); },
        showHint: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.level + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已拆开'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.clears), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.miss) + '/3')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(Digits(String(this.rest), this.langCode)).fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.rest > 1 ? this.theme.ink : Palette.emerald)
        Text(TG2('目标数 {0}', String(this.target))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.chain.length > 0 ? this.chain.join(' × ') + (this.rest > 1 ? ' × …' : '') : '还没有拆下任何因子')
          .fontSize(FontSize.lg).fontColor(Palette.cyan)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.xs }) {
        ForEach(PRIMES, (p: number) => { Button(String((p)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over && this.rest > 1)
        .onClick(() => { Haptics.tap(); this.tap((p)); }); }, (p: number) => 'p' + p)
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.cyan)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('质因数连乘起来 = 目标数')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
