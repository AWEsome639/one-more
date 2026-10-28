/**
 * 记忆广度 —— 🃏 数字一个个闪过，最后按顺序点出「最后 N 个」（id: running_memory_span）
 * 胜负：连过 广度 3 → 4 → 5 三关 ⇒ 通关；进度：关卡/3 · 广度 · 阶段
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const SPAN_START: number = 3;
const LEVELS: number = 3;
const EXTRA: number = 5;
const SHOW_MS: number = 700;
@Component
export struct GRunningMemorySpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State private phase: string = 'show';
  @State private level: number = 0;
  @State private span: number = SPAN_START;
  @State private stream: number[] = [];
  @State private cur: number = -1;
  @State private typed: string = '';
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private ivId: number = -1;
  private toId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GRunningMemorySpan')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.level = 0; this.cur = -1; this.typed = ''; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.startLevel();
  }
  /** 闪出 span+5 个数字，然后要求回忆最后 span 个 */
  private startLevel(): void {
    this.span = SPAN_START + this.level;
    const st: number[] = [];
    for (let i = 0; i < this.span + EXTRA; i++) { st.push(Math.floor(Math.random() * 10)); }
    this.stream = st; this.typed = ''; this.cur = st[0]; this.phase = 'show';
    this.msg = TG2('记住「最后 {0} 个」，按顺序', String(this.span));
    let idx: number = 0;
    this.ivId = setInterval(() => {
      idx = idx + 1;
      if (idx >= this.stream.length) {
        if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
        this.phase = 'input'; this.cur = -1;
        this.msg = TG2("按顺序点出最后 {0} 个", String(this.span));
        return;
      }
      this.cur = this.stream[idx];
    }, SHOW_MS);
  }
  /** 正确序列 = 流里最后 span 个 */
  private tail(): string {
    let s: string = '';
    for (let i = this.stream.length - this.span; i < this.stream.length; i++) { s = s + String(this.stream[i]); }
    return s;
  }
  private slots(): string {
    const need: number = this.span - this.typed.length;
    let s: string = this.typed;
    for (let i = 0; i < need; i++) { s = s + ' _'; }
    return s;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    if (this.phase !== 'input' || this.typed.length >= this.span) {
      return true;
    }
    this.keyTap(this.stream[this.stream.length - this.span + this.typed.length]);
    return !this.over;
  }

  /** 提示：要点的就是流里最后 span 个数字，按顺序报出来 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    if (this.phase !== 'input') { return Hint.none('none'); }
    return Hint.make([],
      TG2('按顺序点 {0}', this.tail()),
      'Type the digits ' + this.tail(), t0);
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

  private keyTap(d: number): void {
    if (this.phase !== 'input' || this.over) { return; }
    this.typed = this.typed + String(d);
    if (this.typed.length < this.span) { this.msg = TG2('已点 {0}', this.typed); return; }
    const target: string = this.tail();
    if (this.typed === target) {
      this.level = this.level + 1;
      if (this.level >= this.diffTotal) {
        this.phase = 'done'; this.over = true; this.won = true;
        this.msg = TG2('🎉 通关 · 广度 {0} 全过',Digits(String(this.span), this.langCode));
        this.end();
        return;
      }
      this.msg = TG('✅ 过关！下一关更长');
      this.toId = setTimeout(() => { this.toId = -1; this.startLevel(); }, 850);
      return;
    }
    this.phase = 'done'; this.over = true; this.won = false;
    this.msg = TG2('❌ 应为 {0}，你点的是 {1}', target, this.typed);
    this.end();
  }
  private end(): void {
    if (this.done) { return; }
    this.clearAll();
    this.done = true;
    const r: GameResult = { gameId: 'running_memory_span', solved: this.won, score: (this.level + (this.won ? 1 : 0)) * 120, durationMs: Date.now() - this.startAt, levelReached: this.span };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.level + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('广度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'show' ? '闪数字' : (this.phase === 'input' ? '回忆' : TG('结束')))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.phase === 'show' ? (this.cur < 0 ? '…' : String(this.cur)) : this.slots())
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.phase === 'show' ? Palette.rose : this.theme.ink).scale({ x: this.phase === 'show' ? 1.08 : 1, y: this.phase === 'show' ? 1.08 : 1 })
        Text(this.phase === 'show' ? '看，别点' : '点出最后 ' + String(this.span) + TG(' 个'))
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').height(130).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4, 5], (d: number) => {
          Text(String((d))).fontSize(FontSize.xl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(50)).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
          .opacity(this.phase === 'input' ? 1 : 0.4)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.keyTap((d)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.keyTap((d)); }); })
        }, (d: number) => 'a' + d)
      }.width('100%')
      Row({ space: Space.xs }) {
        ForEach([6, 7, 8, 9, 0], (d: number) => {
          Text(String((d))).fontSize(FontSize.xl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(50)).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
          .opacity(this.phase === 'input' ? 1 : 0.4)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.keyTap((d)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.keyTap((d)); }); })
        }, (d: number) => 'b' + d)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.rose).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：连过 广度 3 → 4 → 5 三关；数字 700 ms 一个'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
