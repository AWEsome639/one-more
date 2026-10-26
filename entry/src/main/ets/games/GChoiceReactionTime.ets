/**
 * 选择反应 —— 数字一亮就按「奇」或「偶」，测平均反应时
 * 胜负：10 题平均 < 900ms 且答错不超过 1 次 ⇒ 通关；进度：题号 / 平均 / 最快
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 10;
const LIMIT_MS: number = 900;
const MAX_WAIT: number = 2200;

@Component
export struct GChoiceReactionTime {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private val: number = 0;
  @State private live: boolean = false;     // 刺激是否已出现
  @State private round: number = 1;
  @State private total: number = 0;         // 累计毫秒（答错按 1800ms 计）
  @State private best: number = 0;
  @State private wrong: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private shownAt: number = 0;
  private waitTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 1; this.total = 0; this.best = 0; this.wrong = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.live = false;
    this.startAt = Date.now();
    this.arm();
  }
  /** 随机等 0.7~2.2 秒再亮出数字 */
  private arm(): void {
    this.live = false;
    this.pick = -1;
    this.msg = TG('准备… 数字一出现就按');
    this.waitTo = setTimeout(() => {
      this.waitTo = -1;
      this.val = 10 + Math.floor(Math.random() * 90);
      this.shownAt = Date.now();
      this.live = true;
      this.msg = TG('是奇数还是偶数？');
    }, 700 + Math.floor(Math.random() * (MAX_WAIT - 700)));
  }
  private avg(): number {
    const doneN: number = this.round - 1;
    return doneN > 0 ? Math.round(this.total / doneN) : 0;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔现算：this.val % 2 === 0
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || !this.live || this.pick >= 0) {
      return true;
    }
    const rt: number = Date.now() - this.shownAt;
    this.answer(this.val % 2 === 0);
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

  private answer(saidEven: boolean): void {
    if (this.over || !this.live || this.pick >= 0) { return; }
    const rt: number = Date.now() - this.shownAt;
    const isEven: boolean = this.val % 2 === 0;
    this.pick = saidEven ? 1 : 0;
    this.live = false;
    if (saidEven === isEven) {
      this.total = this.total + rt;
      if (this.best === 0 || rt < this.best) { this.best = rt; }
      this.msg = '✅ ' + String(rt) + ' ms';
    } else {
      this.total = this.total + LIMIT_MS * 2;
      this.wrong = this.wrong + 1;
      this.msg = TG2("❌ {0} 是{1}，这题按 {2} ms 计", String(this.val), (isEven ? '偶数' : TG('奇数')), String(LIMIT_MS * 2));
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        const a: number = this.avg();
        this.over = true;
        this.won = a < LIMIT_MS && this.wrong <= 1;
        this.msg = TG2("{0}平均 {1} ms · 错 {2} 次", (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')), String(a),Digits(String(this.wrong), this.langCode));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.arm();
    }, 560);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const avg: number = this.avg();
    const r: GameResult = {
      gameId: 'choice_reaction_time', solved: solved, score: Math.max(0, LIMIT_MS * 2 - avg) * 2,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.avg() > 0 ? this.avg() + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最快'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.best > 0 ? this.best + 'ms' : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.live ? String(this.val) : '👀').fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.live ? Palette.orange : this.theme.inkFaint)
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }.width('100%').height(170).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.md }) {
        HintBar({
          onAutoTap: () => { this.askAuto(); },
          showHint: false,
          autoOn: this.autoId >= 0
        })
        Button(TG('奇'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 0 ? Palette.primaryDeep : Palette.orange)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(78)).opacity(this.live ? 1 : 0.55)
          .scale({ x: this.pick === 0 ? Motion.pressScale : 1, y: this.pick === 0 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tap(); this.answer(false); })
        Button(TG('偶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor('#FFFFFF')
          .backgroundColor(this.pick === 1 ? Palette.primaryDeep : Palette.sky)
          .borderRadius(Radius.lg).layoutWeight(1).height(Cell.of(78)).opacity(this.live ? 1 : 0.55)
          .scale({ x: this.pick === 1 ? Motion.pressScale : 1, y: this.pick === 1 ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tap(); this.answer(true); })
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('判定：平均 < {0} ms 且答错 ≤ 1 次（答错一题按 1800 ms 计）',Digits(String(LIMIT_MS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}