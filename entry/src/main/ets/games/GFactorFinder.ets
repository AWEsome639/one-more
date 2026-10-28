/** 找因数 —— 点亮 n 的全部因数；玩法：12 格候选里点出 n 的所有因数；踩到非因数扣一条命；胜负：3 条命内闯完 4 关 ⇒ 通关；命用完 ⇒ 失败 */
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

const ROUNDS: number = 4; const LIVES: number = 3; const CAND: number = 12; const COLS: number = 4;
const ROWS: number[] = [0, 1, 2];
@Component
export struct GFactorFinder {
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
  @State private n: number = 12;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private cands: number[] = [];
  @State private hit: boolean[] = [];
  @State private bad: number = -1;
  @State private need: number = 6;
  @State private found: number = 0;
  @State private round: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private cols: number[] = [0, 1, 2, 3];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFactorFinder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }
  private reset(): void {
    this.round = 1; this.lives = this.total; this.score = 0; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now(); this.ask();
    this.msg = TG2("点亮 {0} 的全部因数（共 {1} 个）", String(this.n), String(this.need));
  }
  /** 出题：真因数 + 干扰项，凑满 12 格 */
  private ask(): void {
    this.n = 12 + Math.floor(Math.random() * 25);        // 12 ~ 36
    const divs: number[] = [];
    for (let v = 1; v <= this.n; v++) {
      if (this.n % v === 0) { divs.push(v); }
    }
    const list: number[] = divs.slice(); let guard: number = 0;
    while (list.length < CAND && guard < 300) {
      guard = guard + 1; const pick: number = 1 + Math.floor(Math.random() * this.n);
      if (this.n % pick !== 0 && list.indexOf(pick) < 0) { list.push(pick); }
    }
    while (list.length < CAND) { list.push(this.n + list.length); }
    for (let i = list.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: number = list[i]; list[i] = list[j]; list[j] = t;
    }
    this.cands = list; this.hit = new Array<boolean>(CAND).fill(false); this.need = divs.length; this.found = 0; this.bad = -1;
  }

  /**
   * ★ 2026-10-23 第二期：找因数提示
   *
   * 这一关要求点亮 n 的**全部**因数 ⇒ 泄露其中一个只是部分答案，够格当提示。
   * 优先给最小的未找到因数（最容易验算的）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    let bestV: number = -1;
    let bestIdx: number = -1;
    for (let i = 0; i < this.cands.length; i++) {
      if (this.hit[i]) {
        continue;
      }
      const v: number = this.cands[i];
      if (v > 0 && this.n % v === 0 && (bestV < 0 || v < bestV)) {
        bestV = v;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) {
      return Hint.none('none');
    }
    return Hint.make([bestIdx],
      TG2('试试 {0} —— 它能整除 {1}（{1} ÷ {0} = {2}）',
        String(bestV), String(this.n), String(this.n / bestV)),
      TG2('Try {0} — it divides {1} ({1} ÷ {0} = {2})',
        String(bestV), String(this.n), String(this.n / bestV)), t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 提示驱动：computeHint 每次给出"下一格" ⇒ 照它点
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
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length === 0) {
      return false;
    }
    this.tap(r.cells[0]);
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private tap(i: number): void {
    if (this.over || this.hit[i] || this.bad === i) { return; }
    const v: number = this.cands[i];
    if (this.n % v === 0) {
      const next: boolean[] = this.hit.slice(); next[i] = true; this.hit = next; this.found = this.found + 1; this.score += 40;
      if (this.found >= this.need) { this.clearRound(); }
      return;
    }
    this.bad = i; this.lives = this.lives - 1; this.score = Math.max(0, this.score - 30); this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.lives <= 0) {
      this.over = true; this.won = false; this.msg = TG2('💔 {0} 不是 {1} 的因数，命用完了', String(v),Digits(String(this.n), this.langCode));
      this.finish(false); return;
    }
    this.msg = TG2("❌ {0} 不是 {1} 的因数，还剩 {2} 条命", String(v),Digits(String(this.n), this.langCode),Digits(String(this.lives), this.langCode));
  }
  private clearRound(): void {
    this.score += 100;
    if (this.round >= ROUNDS) {
      this.over = true; this.won = true; this.msg = TG2('🎉 {0} 关全清，得分 {1}',Digits(String(ROUNDS), this.langCode),Digits(String(this.score), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG2("✅ 过关！接着找 {0} 的全部因数（共 {1} 个）",Digits(String(this.n), this.langCode),Digits(String(this.need), this.langCode));
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'factor_finder', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private cellBg(i: number): string {
    if (this.hit[i]) { return Palette.emerald; }
    if (this.bad === i) { return Palette.rose; }
    return this.theme.surface;
  }
  private cellInk(i: number): string {
    if (this.hit[i] || this.bad === i) { return '#FFFFFF'; }
    return this.theme.ink;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + ROUNDS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('因数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found + '/' + this.need)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(('❤️×' + String(this.lives))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('➗').fontSize(FontSize.xxl)
          .accessibilityLevel('no')
        Text(TG2('找出 {0} 的全部因数', String(this.n))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.isDark ? Palette.primary : Palette.primaryDeep)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (col: number) => {
              Stack() {
              Text(String(this.cands[(row * COLS + col)])).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.cellInk((row * COLS + col)))
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cellBg((row * COLS + col))).borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((row * COLS + col)); })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (col: number) => 'ffc' + col)
          }.width('100%')
        }, (row: number) => 'ffr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .width('100%').height(Cell.of(40)).onClick(() => {
          this.askHint();
        })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：因数成对出现 —— 找到 v 就顺手想想 n÷v；1 与 n 本身也算')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
