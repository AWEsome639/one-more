/**
 * 瞬脱探针 —— 两问：流里那个数字 T1 是几？T1 之后有没有闪过「探针 ✦」？
 * 胜负：4 轮共 8 分，拿到 6 分以上 ⇒ 通关；进度：轮次 / 得分 / 阶段
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

const TRIALS: number = 4;
const NEED: number = 6;
const LEN: number = 14;
const GAP: number = 3;               // 探针出现在 T1 之后第 3 个位置（正是瞬脱窗口）
const LETTERS: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'K', 'M', 'P', 'R', 'S', 'T', 'V', 'X', 'Z'];
const SLOTS: number[] = [0, 1, 2, 3];

@Component
export struct GAttentionalBlinkProbe {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State private seq: string[] = [];
  @State private t1: string = '0';
  @State private hasProbe: boolean = false;
  @State private idx: number = -1;
  @State private showing: boolean = false;
  @State private phase: number = 0;    // 0=播流 1=问T1 2=问探针
  @State private trialNo: number = 1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private opts: string[] = [];
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private tickTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.tickTo >= 0) { clearTimeout(this.tickTo); this.tickTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.score = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }
  private newTrial(): void {
    const digits: string[] = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const list: string[] = [];
    for (let i = 0; i < LEN; i++) { list.push(LETTERS[Math.floor(Math.random() * LETTERS.length)]); }
    const at: number = 3 + Math.floor(Math.random() * 4);
    const t1: string = digits[Math.floor(Math.random() * digits.length)];
    list[at] = t1;
    const probe: boolean = Math.random() < 0.5;
    if (probe && at + GAP < LEN) { list[at + GAP] = '✦'; }
    const pool: string[] = [t1];
    while (pool.length < 4) {
      const x: string = digits[Math.floor(Math.random() * digits.length)];
      if (pool.indexOf(x) < 0) { pool.push(x); }
    }
    const mixed: string[] = [];
    while (pool.length > 0) { mixed.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
    this.seq = list;
    this.t1 = t1;
    this.hasProbe = probe;
    this.opts = mixed;
    this.pick = -1; this.idx = -1; this.showing = false; this.phase = 0;
    this.msg = TG2("第 {0} 轮：记住数字，并留意它之后有没有 ✦", String(this.trialNo));
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.play(0); }, 700);
  }
  private play(k: number): void {
    if (k >= this.seq.length) {
      this.idx = LEN;
      this.showing = false;
      this.phase = 1;
      this.msg = TG('第一问：刚才的数字是几？');
      return;
    }
    this.idx = k;
    this.showing = true;
    this.tickTo = setTimeout(() => {
      this.tickTo = -1;
      this.showing = false;
      this.tickTo = setTimeout(() => { this.tickTo = -1; this.play(k + 1); }, 60);
    }, 190);
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase === 0 || this.pick >= 0) {
      return true;
    }
    if (this.phase === 1) {
      const k: number = this.opts.indexOf(this.t1);
      if (k < 0) {
        return false;
      }
      this.answerDigit(k);
      return !this.over;
    }
    this.answerProbe(this.hasProbe);
    return !this.over;
  }

  /** 提示：两问分别报「数字是几」「有没有 ✦」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 1) {
      const k: number = this.opts.indexOf(this.t1);
      return Hint.make([k < 0 ? 0 : k],
        TG2('刚才的数字是 {0}', this.t1),
        TG2('The number was {0}', this.t1), t0);
    }
    if (this.phase === 2) {
      return this.hasProbe
        ? Hint.make([1], TG('这一轮有 ✦ 探针'), TG('There was a ✦ probe'), t0)
        : Hint.make([0], TG('这一轮没有 ✦ 探针'), TG('There was no ✦ probe'), t0);
    }
    return Hint.none(TG('序列还在闪现，等出题之后再提示'));
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

  private answerDigit(i: number): void {
    if (this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i] === this.t1) {
      this.score = this.score + 1; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG('✅ 数字对了（+1）');
    } else {
      this.msg = TG2('❌ 数字是 {0}', this.t1);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.phase = 2;
      this.pick = -1;
      this.msg = TG('第二问：数字之后出现过 ✦ 探针吗？');
    }, 750);
  }
  private answerProbe(said: boolean): void {
    if (this.phase !== 2 || this.pick >= 0) { return; }
    this.pick = said ? 1 : 0;
    if (said === this.hasProbe) {
      this.score = this.score + 1; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG('✅ 探针判断对了（+1）');
    } else {
      this.msg = this.hasProbe ? '❌ 这轮其实有 ✦' : '❌ 这轮没有 ✦';
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.trialNo >= this.diffTotal) {
        this.over = true;
        this.won = this.score >= NEED;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("共 {0}/{1} 分",Digits(String(this.score), this.langCode), String(this.diffTotal * 2));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
    }, 800);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'attentional_blink_probe', solved: solved, score: this.score * 150,
      durationMs: Date.now() - this.startAt, levelReached: this.trialNo
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.trialNo + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint); Text((this.score + '/' + this.diffTotal * 2)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.phase === 0 ? '闪现中' : (this.phase === 1 ? '答数字' : '答探针'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        Text(this.showing && this.idx >= 0 ? this.seq[this.idx] : '·')
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.idx >= 0 && this.idx < this.seq.length && this.seq[this.idx] === '✦' ? Palette.sky : Palette.violet)
      }.width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.phase === 0 ? this.theme.inkFaint : this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      if (this.phase === 2) {
        Row({ space: Space.sm }) {
          Button(TG('有 ✦'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
            .backgroundColor(this.pick === 1 ? Palette.primaryDeep : Palette.sky)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).onClick(() => { Haptics.tap(); this.answerProbe(true); })
          Button(TG('没有'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
            .backgroundColor(this.pick === 0 ? Palette.primaryDeep : Palette.inkFaint)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).onClick(() => { Haptics.tap(); this.answerProbe(false); })
        }.width('100%')
      } else {
        Row({ space: Space.sm }) { Text(this.opts[(0)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (0) ? '#FFFFFF' : (this.phase === 1 ? this.theme.ink : this.theme.inkFaint))
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (0) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.phase === 1 ? 1 : 0.4).shadow(Shadow.card)
        .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answerDigit((0)); }); Text(this.opts[(1)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (1) ? '#FFFFFF' : (this.phase === 1 ? this.theme.ink : this.theme.inkFaint))
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (1) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.phase === 1 ? 1 : 0.4).shadow(Shadow.card)
        .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answerDigit((1)); }) }.width('100%')
        Row({ space: Space.sm }) { Text(this.opts[(2)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (2) ? '#FFFFFF' : (this.phase === 1 ? this.theme.ink : this.theme.inkFaint))
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (2) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.phase === 1 ? 1 : 0.4).shadow(Shadow.card)
        .scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answerDigit((2)); }); Text(this.opts[(3)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (3) ? '#FFFFFF' : (this.phase === 1 ? this.theme.ink : this.theme.inkFaint))
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (3) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.phase === 1 ? 1 : 0.4).shadow(Shadow.card)
        .scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answerDigit((3)); }) }.width('100%')
      }
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：探针只会出现在数字之后，出现与否各半')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}