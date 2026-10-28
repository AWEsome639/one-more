/** 整除冲刺（Divisibility Dash）—— 限时判断整除
 *  玩法：快速点「能整除 / 不能整除」。过关判据：45 秒内答对 ≥ 12 题
 */

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

const LIMIT: number = 45;
const NEED: number = 12;

@Component
export struct GDivisibilityDash {
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
  @State private num: number = 24;
  @State private div: number = 4;
  @State private yes: boolean = true;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private streak: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('整除吗？');

  private startAt: number = 0;
  private tick: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => {
      if (this.over) { return; }
      this.left--;
      if (this.left <= 0) {
        this.left = 0;
        this.over = true;
        this.tip = TG2("时间到｜答对 {0} 题", String(this.right));
        this.finish(false);
      }
    }, 1000);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }

  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
  }

  private reset(): void {
    this.startAt = Date.now();
    this.left = this.total;
    this.right = 0;
    this.wrong = 0;
    this.score = 0;
    this.streak = 0;
    this.over = false;
    this.tip = TG('整除吗？');
    this.roll();
  }

  private roll(): void {
    const d: number = 2 + Math.floor(Math.random() * 11);
    const base: number = d * (2 + Math.floor(Math.random() * 28));
    const clean: boolean = Math.random() < 0.5;
    const n: number = clean ? base : base + 1 + Math.floor(Math.random() * (d - 1));
    this.div = d;
    this.num = n;
    this.yes = n % d === 0;
  }


  /**
   * ★ 2026-10-23 第二期：整除冲刺提示
   *
   * 这是判断题，直接说"能/不能"就等于给答案。
   * ⇒ 改给**整除规则**：玩家照着规则自己判断。
   *   除数只可能是 2..12，规则全都能用一句话说清。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const d: number = this.div;
    const n: string = String(this.num);
    let zh: string = '';
    let en: string = '';
    if (d === 2) {
      zh = TG('看末位：末位是偶数就能被 2 整除'); en = TG('Look at the last digit: even ⇒ divisible by 2');
    } else if (d === 3) {
      zh = TG('把各位数字加起来，和能被 3 整除就行'); en = TG('Sum the digits; if the sum divides by 3, so does the number');
    } else if (d === 4) {
      zh = TG('只看末两位，末两位能被 4 整除就行'); en = TG('Look at the last two digits only: divisible by 4 ⇒ yes');
    } else if (d === 5) {
      zh = TG('看末位：末位是 0 或 5 就能被 5 整除'); en = TG('Last digit 0 or 5 ⇒ divisible by 5');
    } else if (d === 6) {
      zh = TG('同时满足两条：能被 2 整除，也能被 3 整除'); en = TG('Both at once: divisible by 2 AND by 3');
    } else if (d === 7) {
      zh = TG('7 没有简便规则，最快是直接除一下'); en = TG('No shortcut for 7 — just divide it');
    } else if (d === 8) {
      zh = TG('只看末三位，末三位能被 8 整除就行'); en = TG('Look at the last three digits only: divisible by 8 ⇒ yes');
    } else if (d === 9) {
      zh = TG('把各位数字加起来，和能被 9 整除就行'); en = TG('Sum the digits; if the sum divides by 9, so does the number');
    } else if (d === 10) {
      zh = TG('看末位：末位是 0 就能被 10 整除'); en = TG('Last digit 0 ⇒ divisible by 10');
    } else if (d === 11) {
      zh = TG('奇数位之和减偶数位之和，差能被 11 整除就行'); en = TG('Alternating digit sum difference divisible by 11 ⇒ yes');
    } else if (d === 12) {
      zh = TG('同时满足两条：能被 3 整除，也能被 4 整除'); en = TG('Both at once: divisible by 3 AND by 4');
    } else {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('判断 {0} 能不能被 {1} 整除 —— {2}', n, String(d), zh),
      TG2('Can {0} divide by {1}? — {2}', n, String(d), en), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔直取：整除判定，答案就在 this.yes
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
    this.answer(this.yes);
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

  private answer(said: boolean): void {
    if (this.over) { return; }
    if (said === this.yes) {
      this.right++;
      this.streak++;
      this.score += 10 + (this.streak >= 5 ? 5 : 0); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.tip = TG2('✓ 对了，连击 {0}', String(this.streak));
      if (this.right >= NEED) {
        this.over = true;
        this.tip = TG2('达标！答对 {0} 题 🎉', String(this.right));
        this.finish(true);
        return;
      }
    } else {
      this.wrong++;
      this.streak = 0;
      this.score = Math.max(0, this.score - 5); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.tip = '✗ ' + String(this.num) + ' ÷ ' + String(this.div) + ' ' +
        (this.yes ? '能整除' : '不能整除');
    }
    this.roll();
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'divisibility_dash', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onAutoTap: () => { this.askAuto(); },
        showHint: false,
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(NEED))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('🔢 整除吗？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        Text(String(this.num) + ' ÷ ' + String(this.div))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG2("连击 {0}", String(this.streak))).fontSize(FontSize.xs).fontColor(this.streak >= 5 ? Palette.orange : this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.md }) {
        Button(TG('能整除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(Palette.emerald).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('不能整除'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(72)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.tip.startsWith('✓') ? Palette.emerald : this.theme.inkSoft).height(20)

      Row({ space: Space.sm }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(40))
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('答错 -5 分；连击 5 次起加分')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
