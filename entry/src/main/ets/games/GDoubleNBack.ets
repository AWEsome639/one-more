/**
 * 双 N-back —— 位置与字母两条通道同时跟，各自和 N 步前比
 *
 * 胜负：N=2，20 个判断里正确 ≥15 ⇒ 通关
 * 进度：题号 / 正确数 / 判断数 / 当前 N
 */
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const TOTAL: number = 12; const N: number = 2; const NEED: number = 15;
const LETTERS: string[] = ['A', 'B', 'D', 'E', 'F', 'H', 'K', 'L', 'M', 'P', 'R', 'S', 'T', 'X'];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
@Component
export struct GDoubleNBack {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
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
  @State private idx: number = 0;
  @State private selPos: boolean = false;
  @State private selLetter: boolean = false;
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 2026-10-15 错误抖动 */
  @State private shakeX: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private posSeq: number[] = [];
  private letSeq: string[] = [];
  private startAt: number = 0;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDoubleNBack')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  private buildSeq(): void {
    const ps: number[] = []; const ls: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      let p: number = Math.floor(Math.random() * 9);
      if (i >= N && Math.random() < 0.3) { p = ps[i - N]; }
      let ch: string = LETTERS[Math.floor(Math.random() * LETTERS.length)];
      if (i >= N && Math.random() < 0.3) { ch = ls[i - N]; }
      ps.push(p);
      ls.push(ch);
    }
    this.posSeq = ps; this.letSeq = ls;
  }
  private reset(): void {
    this.buildSeq(); this.idx = 0; this.selPos = false; this.selLetter = false; this.right = 0;
    this.wrong = 0; this.over = false; this.won = false; this.done = false;
    this.msg = TG('N = 2：和两步前的比，分别判断位置与字母'); this.startAt = Date.now();
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案 = 「和两步前比相不相同」两个布尔，submit() 里现比 ⇒ 照真值把这俩开关拨对
  private matchPos(): boolean {
    return this.idx >= N && this.posSeq[this.idx] === this.posSeq[this.idx - N];
  }

  private matchLet(): boolean {
    return this.idx >= N && this.letSeq[this.idx] === this.letSeq[this.idx - N];
  }

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
    this.selPos = this.matchPos();
    this.selLetter = this.matchLet();
    this.submit();
    return !this.over;
  }

  /** 提示：报「位置/字母 各自和两步前相不相同」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.idx < N) {
      return Hint.make([], TG('前两题没有可比对象，直接点下一题'),
        TG('Nothing to compare yet — just submit'), t0);
    }
    const ps: string = this.matchPos() ? TG('位置相同') : TG('位置不同');
    const ls: string = this.matchLet() ? TG('字母相同') : TG('字母不同');
    return Hint.make([], TG2('位置：{0}　字母：{1}', ps, ls),
      TG2('Position: {0} · Letter: {1}', ps, ls), t0);
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

  private submit(): void {
    if (this.over) { return; }
    if (this.idx >= N) {
      const pMatch: boolean = this.posSeq[this.idx] === this.posSeq[this.idx - N];
      const lMatch: boolean = this.letSeq[this.idx] === this.letSeq[this.idx - N];
      let r: number = this.right; let w: number = this.wrong;
      if (this.selPos === pMatch) { r = r + 1; } else { w = w + 1; }
      if (this.selLetter === lMatch) { r = r + 1; } else { w = w + 1; }
      this.right = r; this.wrong = w; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    }
    if (this.idx >= this.diffTotal - 1) {
      this.finish();
      return;
    }
    this.idx = this.idx + 1; this.selPos = false; this.selLetter = false;
    this.msg = this.idx < N ? '前两题没有可比对象，直接下一题' : '位置与字母各判断一次，再进入下一题';
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG2('正确 {0} · 错误 {1}', String(this.right), String(this.wrong));
    const raw: number = this.right * 60 - this.wrong * 20; const r: GameResult = {
      gameId: 'double_n_back', solved: this.won,
      score: raw > 0 ? raw : 0, durationMs: Date.now() - this.startAt,
      levelReached: N
    };
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('正确'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('判断'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right + this.wrong))).fontSize(FontSize.md)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text(('N')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(N))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.xs }) {
              ForEach([0, 1, 2], (c: number) => {
                Stack() {
                Text(this.posSeq.length > 0 && (r * 3 + c) === this.posSeq[this.idx] ? '●' : '').fontSize(FontSize.lg).fontColor('#FFFFFF')
                }.layoutWeight(1).aspectRatio(1).backgroundColor(this.posSeq.length > 0 && (r * 3 + c) === this.posSeq[this.idx] ? Palette.orange : this.theme.surfaceAlt)
                .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'nc' + c)
            }.width('100%')
          }, (r: number) => 'nr' + r)
        }.layoutWeight(2)
        Text(this.letSeq.length > 0 ? this.letSeq[this.idx] : '·').fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold).fontColor(Palette.orange).textAlign(TextAlign.Center).layoutWeight(1)
          .height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Text((true ? this.selPos : this.selLetter) ? '✔ ' + (TG('位置 = 2-back')) : (TG('位置 = 2-back'))).fontSize(FontSize.sm)
        .fontColor((true ? this.selPos : this.selLetter) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(44))
        .backgroundColor((true ? this.selPos : this.selLetter) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.idx >= N ? 1 : 0.45).enabled(this.idx >= N)
        .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (true) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; } }); }).onClick(() => {
        Haptics.tick();
        if (true) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; }
        })
        Text((false ? this.selPos : this.selLetter) ? '✔ ' + (TG('字母 = 2-back')) : (TG('字母 = 2-back'))).fontSize(FontSize.sm)
        .fontColor((false ? this.selPos : this.selLetter) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(44))
        .backgroundColor((false ? this.selPos : this.selLetter) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.idx >= N ? 1 : 0.45).enabled(this.idx >= N)
        .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (false) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; } }); }).onClick(() => {
        Haptics.tick();
        if (false) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; }
        })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.idx >= this.diffTotal - 1 ? '提交结算' : '下一题 ▶')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); }).onClick(() => { Haptics.tap(); this.submit(); })
        Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).width(96).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
