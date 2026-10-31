/**
 * 多轨计数（id: multi_track_counter）—— 三条轨道各自在涨，凭眼力报总数 📐
 * 3 轮，每轮 +1 轮速；误差 ≤ 2 通关。进度：第几轮 / 题数 / 总分
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

const TRACKS: number = 3;
const ROUNDS: number = 3;
const TICK: number = 120;
const BUDGET: number = 12000;

@Component
export struct GMultiTrackCounter {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;
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
  @State private vals: number[] = []; @State private rounds: number[] = []; @State private seen: number[] = [];
  @State private round: number = 1; @State private ticking: boolean = false;
  // ★ 难度作用到玩法（本局时长按难度换算）
  private total: number = GameDiff.timeNow(BUDGET);
  @State private left: number = 0; @State private answer: number = 0; @State private score: number = 0;
  @State private maxErr: number = 0; @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false; private startAt: number = 0; private timer: number = -1;
  private nextTo: number = -1; private deadline: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMultiTrackCounter')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(BUDGET);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stopTick(); this.clearNext(); }
  private clearNext(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.stopTick();
    this.round = 1;
    this.score = 0;
    this.maxErr = 0;
    this.answer = 0;
    this.over = false;
    this.won = false;
    this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }
  private newRound(): void {
    if (this.done || this.over) { return; }
    const v: number[] = [];
    const rr: number[] = [];
    for (let i = 0; i < TRACKS; i++) {
      v.push(0);
      rr.push(2 + this.round + i);
    }
    this.vals = v;
    this.rounds = rr;
    this.seen = [0, 0, 0];
    this.ticking = true;
    this.left = this.total;
    this.answer = 0;
    this.deadline = Date.now() + BUDGET;
    this.msg = TG('数一数：三条轨道一共跳了多少下？');
    this.startTick();
  }
  private startTick(): void {
    this.stopTick();
    this.timer = setInterval(() => {
      if (!this.ticking || this.done) {
        return;
      }
      const v: number[] = this.vals.slice();
      const s: number[] = this.seen.slice();
      for (let i = 0; i < TRACKS; i++) {
        if (this.left % this.rounds[i] === 0 && this.left > 0) {
          v[i] = v[i] + 1;
          s[i] = s[i] + 1;
        }
      }
      this.vals = v;
      this.seen = s;
      this.left = Math.max(0, this.deadline - Date.now());
      if (this.left === 0) {
        this.ticking = false;
        this.msg = TG('⏰ 时间到，按你数到的数字结算');
      }
    }, TICK);
  }
  private stopTick(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
  private trueSum(): number {
    let n: number = 0;
    for (let i = 0; i < this.seen.length; i++) {
      n = n + this.seen[i];
    }
    return n;
  }
  /** 提示：正确总和是多少（代打用的同一个值） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const s: number = this.trueSum();
    return Hint.make([], TG2('正确总和是 {0}', String(s)),
      TG2('The correct total is {0}', String(s)), t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款的答案由 trueSum() 算出 ⇒ 直接把 answer 设成真值再提交。
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
    this.answer = this.trueSum();
    this.submit();
    return !this.over;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private submit(): void {
    if (this.done || this.over) { return; }
    this.ticking = false;
    const truth: number = this.trueSum();
    const err: number = Math.abs(this.answer - truth);
    const got: number = Math.max(0, 300 - err * 100);
    this.score = this.score + got;
    this.maxErr = Math.max(this.maxErr, err);
    if (this.round >= ROUNDS) {
      this.done = true;
      this.over = true;
      this.won = this.maxErr <= 2;
      this.msg = (this.won ? TG('🎉 通关 · ') : TG('💤 结束 · ')) +TG2("真实 {0}，你报 {1} · 总分 {2}", String(truth),Digits(String(this.answer), this.langCode), String(this.score + (this.won ? 200 : 0)));
      this.finish();
      return;
    }
    this.msg = '真实 ' + String(truth) + '，你报 ' + String(this.answer) + '（差 ' + String(err) + '）⇒ 本轮 ' + String(got) + ' 分 · 累计 ' + String(this.score);
    this.round = this.round + 1;
    this.clearNext();
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (!this.done) {
        this.newRound();
      }
    }, 700);
  }
  private bump(d: number): void {
    if (this.done || this.over) { return; }
    this.answer = Math.max(0, this.answer + d);
  }
  private finish(): void {
    this.stopTick();
    const r: GameResult = {
      gameId: 'multi_track_counter', solved: this.won,
      score: this.score + (this.won ? 200 : 0),
      durationMs: Date.now() - this.startAt, levelReached: this.round
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
        Column({ space: Space.xs }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('偏差'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.maxErr), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.left / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2], (i: number) => {
          Column({ space: Space.xs }) {
          Text(['⚪', '🔵', '🟣'][(i)])
          .fontSize(FontSize.xxl)
          .fontColor(this.theme.ink)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          Text(String(this.vals[(i)]))
          .fontSize(FontSize.xxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.sky)
          Text(TG2('每 {0} 格跳一次', String(this.rounds[(i)])))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
          Text(this.seen[(i)] > 0 ? '已跳 ' + String(this.seen[(i)]) : '…')
          .fontSize(FontSize.xs)
          .fontColor(this.theme.inkSoft)
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }, (i: number) => 'k' + i)
      }
      .width('100%')
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button((-1) > 0 ? '+' + String((-1)) : String((-1)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.lg)
        .fontColor('#FFFFFF')
        .backgroundColor((-1) > 0 ? Palette.amber : Palette.rose)
        .borderRadius(Radius.md)
        .layoutWeight(1)
        .height(Cell.of(48))
        .scale({ x: Motion.pressScale, y: Motion.pressScale })
        .onClick(() => { Haptics.tap(); this.bump((-1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.bump((-1)); }); })
        Button((1) > 0 ? '+' + String((1)) : String((1)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.lg)
        .fontColor('#FFFFFF')
        .backgroundColor((1) > 0 ? Palette.amber : Palette.rose)
        .borderRadius(Radius.md)
        .layoutWeight(1)
        .height(Cell.of(48))
        .scale({ x: Motion.pressScale, y: Motion.pressScale })
        .onClick(() => { Haptics.tap(); this.bump((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.bump((1)); }); })
        Button((5) > 0 ? '+' + String((5)) : String((5)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.lg)
        .fontColor('#FFFFFF')
        .backgroundColor((5) > 0 ? Palette.amber : Palette.rose)
        .borderRadius(Radius.md)
        .layoutWeight(1)
        .height(Cell.of(48))
        .scale({ x: Motion.pressScale, y: Motion.pressScale })
        .onClick(() => { Haptics.tap(); this.bump((5)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.bump((5)); }); })
      }
      .width('100%')
      Button(TG2('报数：共 {0} 下', this.answer))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : Palette.sky)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(48))
        .onClick(() => { Haptics.tap(); this.submit(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); })
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：3 轮各报一次，命中 ≤ 2 通关（每差 1 扣 100 分）'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



}
