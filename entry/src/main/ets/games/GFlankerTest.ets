/**
 * 侧抑制（Flanker）—— 只看中间那个箭头，忽略两侧干扰
 * 胜负：12 题答对 ≥ 11 且平均反应 < 900 ms ⇒ 通关；进度：题号 / 正确 / 平均反应
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TRIALS: number = 12;
const LIMIT_MS: number = 900;
const NEED_HIT: number = 11;

@Component
export struct GFlankerTest {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};

  @State private arrows: string[] = [];
  @State private centerRight: boolean = true;
  @State private live: boolean = false;
  @State private trialNo: number = 1;
  @State private rightN: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private rightNPulse: number = 1;
  @State private totalRt: number = 0;
  @State private pick: number = -1;      // -1 未答 0 左 1 右
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
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.rightN = 0; this.totalRt = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.arm();
  }

  /** 随机等 0.7~1.6 秒后亮出一排箭头（一半同向、一半反向） */
  private arm(): void {
    this.live = false;
    this.pick = -1;
    this.msg = TG('盯住中间那个箭头');
    const isRight: boolean = Math.random() < 0.5;
    this.centerRight = isRight;
    const flank: string = (Math.random() < 0.5 ? isRight : !isRight) ? '→' : '←';
    const center: string = isRight ? '→' : '←';
    this.arrows = [flank, flank, center, flank, flank];
    this.waitTo = setTimeout(() => {
      this.waitTo = -1;
      this.shownAt = Date.now();
      this.live = true;
      this.msg = TG('中间朝哪边？');
    }, 700 + Math.floor(Math.random() * 900));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔直取：侧抑制，答案就在 this.centerRight
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.pick >= 0) {
      return true;              // 已答，等它换下一题
    }
    this.answer(this.centerRight);
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

  private answer(saidRight: boolean): void {
    if (this.over || !this.live) { return; }
    const rt: number = Date.now() - this.shownAt;
    this.live = false;
    this.pick = saidRight ? 1 : 0;
    if (saidRight === this.centerRight) {
      this.rightN = this.rightN + 1; this.rightNPulse = 1.3; setTimeout(() => { this.rightNPulse = 1; }, 140);
      this.totalRt = this.totalRt + rt;
      this.msg = '✅ ' + String(rt) + ' ms';
    } else {
      this.totalRt = this.totalRt + LIMIT_MS * 2;
      this.msg = TG2("❌ 中间是 {0}（按 {1} ms 计）", (this.centerRight ? '→' : '←'), String(LIMIT_MS * 2));
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.trialNo >= this.diffTotal) { this.judge(); return; }
      this.trialNo = this.trialNo + 1;
      this.arm();
    }, 640);
  }

  private avgRt(): number {
    return Math.round(this.totalRt / this.diffTotal);
  }

  private judge(): void {
    const avg: number = this.avgRt();
    this.over = true;
    this.won = this.rightN >= NEED_HIT && avg < LIMIT_MS;
    this.msg = TG2(this.won ? '🎉 通关！正确 {0}/{1}' : '💤 结束，正确 {0}/{1}',Digits(String(this.rightN), this.langCode),Digits(String(this.diffTotal), this.langCode))
      + TG2(' · 平均 {0} ms', String(avg));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'flanker_test', solved: this.won,
        score: this.rightN * 100 + Math.max(0, LIMIT_MS - avg),
        durationMs: Date.now() - this.startAt, levelReached: this.rightN
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.over ? this.diffTotal : this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('正确'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.rightN), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.rightNPulse, y: this.rightNPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('平均'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rightN > 0 ? (String(this.avgRt()) + 'ms') : '—')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        if (this.live) {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (i: number) => {
              Text(this.arrows[(i)])
              .fontSize((i) === 2 ? FontSize.hero : FontSize.xxl)
              .fontWeight((i) === 2 ? FontWeight.Bold : FontWeight.Normal)
              .fontColor((i) === 2 ? Palette.sky : this.theme.inkFaint)
              .textAlign(TextAlign.Center).layoutWeight(1)
            }, (i: number) => 'a' + i + this.arrows[i])
          }.width('100%')
        } else {
          Text('👀').fontSize(FontSize.hero)
            .accessibilityLevel('no')
        }
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
      }.width('100%').height(Space.xxxl * 2).justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Row({ space: Space.md }) {
        HintBar({
          onAutoTap: () => { this.askAuto(); },
          showHint: false,
          autoOn: this.autoId >= 0
        })
        Button(('←'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.xxl).fontColor('#FFFFFF')
        .backgroundColor(this.pick === ((false) ? 1 : 0) ? Palette.primaryDeep : ((false) ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg).layoutWeight(1).height(Space.xxxl * 2)
        .opacity(this.live || this.pick >= 0 ? 1 : 0.55)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer((false)); })
        Button(('→'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.xxl).fontColor('#FFFFFF')
        .backgroundColor(this.pick === ((true) ? 1 : 0) ? Palette.primaryDeep : ((true) ? Palette.sky : Palette.violet))
        .borderRadius(Radius.lg).layoutWeight(1).height(Space.xxxl * 2)
        .opacity(this.live || this.pick >= 0 ? 1 : 0.55)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.answer((true)); })
      }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('判定：答对 ≥ {0}/{1} 且平均 < {2} ms', String(NEED_HIT), String(this.diffTotal), String(LIMIT_MS)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
