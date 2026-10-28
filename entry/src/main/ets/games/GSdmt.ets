/**
 * 符号数字转换 —— 🧠 照图例把符号换成数字，90 秒内尽量多答（id: sdmt）
 * 胜负：答对 ≥ 25 ⇒ 通关；进度：答对/25 · 剩余秒数 · 答错
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
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';
const SECONDS: number = 90;
const GOAL: number = 25;
const SYMS: string[] = ['★', '●', '▲', '■', '◆', '✚', '☂', '☀', '♣'];
@Component
export struct GSdmt {
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
  @State private map: number[] = [];
  @State private cur: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SECONDS);
  @State private left: number = 0;
  @State private tapped: number = -1;
  @State private ok: boolean = true;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private ivId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(SECONDS);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stopTick(); }
  private stopTick(): void {
    if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
  }
  private reset(): void {
    this.stopTick();
    const base: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    for (let i = base.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = base[i];
      base[i] = base[j];
      base[j] = t;
    }
    this.map = base;
    this.cur = Math.floor(Math.random() * SYMS.length);
    this.right = 0; this.wrong = 0; this.left = this.total; this.tapped = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.msg = TG('照图例点数字，90 秒冲 25 个');
    this.ivId = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) { this.end(); }
    }, 1000);
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
    if (this.over) {
      return true;
    }
    this.keyTap(this.map[this.cur]);
    return !this.over;
  }

  /** 提示：这个符号对应哪个键 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const need: number = this.map[this.cur];
    return Hint.make([need], TG2('符号对应第 {0} 个', String(need + 1)),
      TG2('Symbol maps to {0}', String(need + 1)), t0);
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
    if (this.over) { return; }
    const need: number = this.map[this.cur];
    this.tapped = d;
    if (d === need) {
      this.ok = true; this.right = this.right + 1; this.msg = '✅ +1';
    } else {
      this.ok = false; this.wrong = this.wrong + 1; this.msg = TG2('❌ 该符号是 {0}', String(need)); this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    }
    this.cur = Math.floor(Math.random() * SYMS.length);
    if (this.right >= GOAL) { this.end(); }
  }
  private end(): void {
    if (this.done) { return; }
    this.stopTick();
    this.done = true; this.over = true; this.won = this.right >= GOAL;
    if (this.left < 0) { this.left = 0; }
    this.msg = (this.won ? TG('🎉 通关 · 答对 ') : TG('💤 时间到 · 答对 ')) +TG2("{0} 个", String(this.right));
    const r: GameResult = {
      gameId: 'sdmt', solved: this.won, score: Math.max(0, this.right * 40 - this.wrong * 10),
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
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
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(GOAL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (i: number) => {
          Column({ space: Space.xs }) {
          Text(SYMS[(i)]).fontSize(FontSize.sm).fontColor(this.theme.ink)
          Text(this.map.length > (i) ? String(this.map[(i)]) : '·').fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
          }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.xs)
        }, (i: number) => 'L' + i)
      }.width('100%').padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Column({ space: Space.xs }) {
        Text(SYMS[this.cur]).fontSize(FontSize.hero).fontColor(Palette.lime)
        Text(TG('这个符号对应哪个数字？')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').height(120).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          ForEach([1, 2, 3], (d: number) => {
            Text(String((d))).fontSize(FontSize.xl).fontColor('#FFFFFF').textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(54)).borderRadius(Radius.md)
            .backgroundColor(this.tapped === (d) ? (this.ok ? Palette.emerald : Palette.rose) : Palette.primary)
            .scale({ x: this.tapped === (d) ? Motion.pressScale : 1, y: this.tapped === (d) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { Haptics.tick(); this.keyTap((d)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.keyTap((d)); }); })
          }, (d: number) => 'k' + d)
        }.width('100%')
        Row({ space: Space.sm }) {
          ForEach([4, 5, 6], (d: number) => {
            Text(String((d))).fontSize(FontSize.xl).fontColor('#FFFFFF').textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(54)).borderRadius(Radius.md)
            .backgroundColor(this.tapped === (d) ? (this.ok ? Palette.emerald : Palette.rose) : Palette.primary)
            .scale({ x: this.tapped === (d) ? Motion.pressScale : 1, y: this.tapped === (d) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { Haptics.tick(); this.keyTap((d)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.keyTap((d)); }); })
          }, (d: number) => 'k' + d)
        }.width('100%')
        Row({ space: Space.sm }) {
          ForEach([7, 8, 9], (d: number) => {
            Text(String((d))).fontSize(FontSize.xl).fontColor('#FFFFFF').textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(54)).borderRadius(Radius.md)
            .backgroundColor(this.tapped === (d) ? (this.ok ? Palette.emerald : Palette.rose) : Palette.primary)
            .scale({ x: this.tapped === (d) ? Motion.pressScale : 1, y: this.tapped === (d) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { Haptics.tick(); this.keyTap((d)); })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.keyTap((d)); }); })
          }, (d: number) => 'k' + d)
        }.width('100%')
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：90 秒内答对 ≥ 25 个通关（答错只影响分数）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
