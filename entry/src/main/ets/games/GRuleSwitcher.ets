/**
 * 规则切换器 —— 🧠 规则每 3 题在「奇偶」与「大小」之间换一次，快速判断（id: rule_switcher）
 * 胜负：15 题答对 ≥ 12 且平均 < 1600ms ⇒ 通关；进度：题号/15 · 答对 · 平均
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const TOTAL: number = 15;
const SWITCH_EVERY: number = 3;
const WIN_RIGHT: number = 12;
const WIN_AVG: number = 1600;
@Component
export struct GRuleSwitcher {
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
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private rule: number = 0;
  @State private val: number = 0;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private totalMs: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private toId: number = -1;
  private done: boolean = false;
  private answered: number = 0;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GRuleSwitcher')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearTo(); }
  private clearTo(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearTo();
    this.round = 1; this.right = 0; this.totalMs = 0; this.pick = -1; this.answered = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.next();
  }
  /** 每 3 题换一次规则；数值 1~99 */
  private next(): void {
    const r: number = Math.floor((this.round - 1) / SWITCH_EVERY) % 2;
    const changed: boolean = this.round === 1 || r !== this.rule;
    this.rule = r;
    this.val = 1 + Math.floor(Math.random() * 99);
    this.pick = -1; this.shownAt = Date.now();
    this.msg = changed ? '⚡ 换规则了！' : '按当前规则作答';
  }
  /** 当前题的正确选项：0 = 左键（奇 / 大），1 = 右键（偶 / 小） */
  private need(): number {
    const r: number = this.rule;
    const v: number = this.val;
    if (r === 0) { return v % 2 === 1 ? 0 : 1; }
    return v > 50 ? 0 : 1;
  }
  private avg(): number {
    return this.answered > 0 ? Math.round(this.totalMs / this.answered) : 0;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：规则切换
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
    if (this.over || this.pick >= 0) {
      return true;
    }
    this.answer(this.need());
    return !this.over;
  }

  /** 提示：直接报正确选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.need();
    return Hint.make([k],
      TG2('答案是第 {0} 个', String(k + 1)),
      TG2('The answer is option {0}', String(k + 1)), t0);
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

  private answer(choice: number): void {
    if (this.over || this.pick >= 0) { return; }
    const v: number = this.val;
    const r: number = this.rule;
    const rt: number = Date.now() - this.shownAt;
    const ok: boolean = choice === this.need();
    this.totalMs = this.totalMs + rt; this.answered = this.answered + 1;
    this.pick = choice;
    if (ok) {
      this.right = this.right + 1;
      this.msg = TG2('✅ 对 · {0} ms', String(rt));
    } else {
      let why: string = v > 50 ? ' 大于 50' : ' 不大于 50';
      if (r === 0) { why = v % 2 === 1 ? ' 是奇数' : ' 是偶数'; }
      this.msg = '❌ ' + String(v) + why;
    }
    this.toId = setTimeout(() => {
      this.toId = -1;
      if (this.round >= this.diffTotal) { this.end(); return; }
      this.round = this.round + 1;
      this.next();
    }, 420);
  }
  private end(): void {
    if (this.done) { return; }
    const a: number = this.avg();
    this.clearTo();
    this.done = true; this.over = true; this.won = this.right >= WIN_RIGHT && a < WIN_AVG;
    this.msg = (this.won ? TG('🎉 通关 · 对 ') : TG('💤 结束 · 对 ')) +TG2("{0}/{1} · 平均 {2} ms", String(this.right), String(this.diffTotal), String(a));
    const r: GameResult = {
      gameId: 'rule_switcher', solved: this.won, score: Math.max(0, this.right * 100 - Math.round(a / 20)),
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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.avg() > 0 ? String(this.avg()) + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Text(this.rule === 0 ? '规则：看奇偶' : '规则：比 50 大小')
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').textAlign(TextAlign.Center)
        .width('100%').height(Cell.of(40)).borderRadius(Radius.full)
        .backgroundColor(this.rule === 0 ? Palette.sky : Palette.violet)
        .animation({ duration: Motion.base, curve: Motion.snap() })
      Column({ space: Space.xs }) {
        Text(Digits(String(this.val), this.langCode)).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.rule === 0 ? '是奇数还是偶数？' : '大于 50 吗？').fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').height(140).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.md }) {
        Button((this.rule === 0 ? '奇' : '大'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
        .backgroundColor(this.pick === (0) && (0) !== this.need() ? Palette.primaryDeep : Palette.sky)
        .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(80))
        .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer((0)); }); })
        Button((this.rule === 0 ? '偶' : '小'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
        .backgroundColor(this.pick === (1) && (1) !== this.need() ? Palette.primaryDeep : Palette.sky)
        .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(80))
        .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer((1)); }); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：15 题答对 ≥ 12 且平均 < 1600 ms（每 3 题换一次规则）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
