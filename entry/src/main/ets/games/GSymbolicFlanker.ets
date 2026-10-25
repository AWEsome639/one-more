/**
 * 符号侧抑制（symbolic_flanker）—— 只看正中间那个箭头的方向，两侧一律是干扰项
 * 胜负：16 轮答对 ≥13 ⇒ 通关；进度：轮次 / 答对 / 答错 / 两侧是否同向
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

const LEFT: string = '◀';
const RIGHT: string = '▶';
const OFFS: number[] = [-2, -1, 0, 1, 2];
const TRIALS: number = 16;
const NEED: number = 13;

@Component
export struct GSymbolicFlanker {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};
  @State trialNo: number = 1;
  @State right: number = 0;
  @State wrong: number = 0;
  @State dir: number = 0;           // 中间目标的方向：0=左 1=右
  @State cong: boolean = true;      // 两侧与目标同向 ⇒ 一致
  @State pick: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private to: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.to >= 0) { clearTimeout(this.to); this.to = -1; } }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.right = 0; this.wrong = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('只认中间那个箭头，别被两边带偏');
    this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const d: number = Math.random() < 0.5 ? 0 : 1;
    this.dir = d;
    this.cong = Math.random() < 0.5;
    this.pick = -1;
  }

  private symAt(o: number): string {
    const d: number = this.dir;
    const center: string = d === 0 ? LEFT : RIGHT;
    if (o === 0 || this.cong) { return center; }
    return d === 0 ? RIGHT : LEFT;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.dir   ｜ 守卫条件取自它自己的 if (...) { return; }
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.pick >= 0 || this.over) {
      return true;              // 还没到能作答的时刻 / 已经答过，等推进
    }
    this.answer(this.dir);
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

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    if (i === this.dir) { this.right = this.right + 1; this.msg = TG('✅ 对'); }
    else { this.wrong = this.wrong + 1; this.msg = '❌ 中间是向' + (this.dir === 0 ? TG('左') : TG('右')); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.trialNo >= this.diffTotal) { this.finishUp(); return; }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
    }, 460);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
    this.clearAll();
    const r: GameResult = {
      gameId: 'symbolic_flanker', solved: this.won, score: this.right * 90,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trialNo + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          ForEach(OFFS, (o: number) => {
            Text(this.symAt((o))).fontSize((o) === 0 ? FontSize.xxl : FontSize.xl).fontWeight(FontWeight.Bold)
            .fontColor((o) === 0 ? Palette.orange : this.theme.inkFaint)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(60))
            .backgroundColor((o) === 0 ? this.theme.surfaceAlt : this.theme.surface)
            .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (o: number) => 'a' + o)
        }.width('100%')
        Text(this.cong ? '两侧与目标同向' : '两侧与目标反向')
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Text((TG('◀ 向左'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (0) ? Palette.orange : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answer((0)); })
        Text((TG('向右 ▶'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink)
        .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.pick === (1) ? Palette.orange : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answer((1)); })
      }.width('100%')

      HintBar({

        showHint: false,

        onAutoTap: () => { this.askAuto(); },

        autoOn: this.autoId >= 0

      })

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.orange).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：两侧反向时会被明显拖慢 —— 那就是侧抑制'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
