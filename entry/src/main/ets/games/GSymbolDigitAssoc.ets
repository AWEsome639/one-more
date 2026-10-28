/**
 * 符号数字（symbol_digit_assoc）—— 看上方对照表，给符号选对应数字（SDMT 玩法）
 * 胜负：12 题答对 ≥9 ⇒ 通关；进度：题号 / 答对 / 用时
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

const SYMS: string[] = ['●', '▲', '■', '★', '◆', '✚'];
const IDX6: number[] = [0, 1, 2, 3, 4, 5];
const COLS: number[] = [0, 1, 2];
const ROWS: number[] = [0, 1];
const TOTAL: number = 12;
const NEED: number = 9;

@Component
export struct GSymbolDigitAssoc {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State idx: number = 0;           // 当前符号下标 ⇒ 对应数字 = idx + 1
  @State no: number = 1;
  @State right: number = 0;
  @State pick: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  @State secs: number = 0;
  private startAt: number = 0;
  private to: number = -1;
  private tick: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => { this.secs = Math.floor((Date.now() - this.startAt) / 1000); }, 1000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.to >= 0) { clearTimeout(this.to); this.to = -1; }
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.pick >= 0) {
      return true;
    }
    this.answer(this.idx);
    return !this.over;
  }

  /** 提示：这个符号对应哪个数字 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.idx], TG2('{0} 对应的数字是 {1}', SYMS[this.idx], String(this.idx + 1)),
      TG2('{0} corresponds to {1}', SYMS[this.idx], String(this.idx + 1)), t0);
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

  private reset(): void {
    if (this.to >= 0) { clearTimeout(this.to); this.to = -1; }
    this.no = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.secs = 0; this.msg = TG('看清上方对照表，选出这个符号对应的数字');
    this.startAt = Date.now();
    this.nextSym();
  }

  private nextSym(): void {
    let s: number = Math.floor(Math.random() * SYMS.length);
    if (s === this.idx) { s = (s + 1) % SYMS.length; }
    this.idx = s;
    this.pick = -1;
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    const want: number = this.idx + 1;
    if (i + 1 === want) { this.right = this.right + 1; this.msg = TG2('✅ 对，{0} = {1}', SYMS[this.idx], String(want)); }
    else { this.msg = TG2('❌ {0} 应该是 {1}', SYMS[this.idx], String(want)); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.no >= this.diffTotal) { this.finishUp(); return; }
      this.no = this.no + 1;
      this.nextSym();
    }, 560);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal))
      + TG2(' · 用时 {0}s', String(this.secs));
    this.clearAll();
    const r: GameResult = {
      gameId: 'symbol_digit_assoc', solved: this.won,
      score: this.right * 100 + Math.max(0, 120 - this.secs),
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.xs }) {
        ForEach(IDX6, (k: number) => {
          Text(SYMS[k] + '=' + String(k + 1)).fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30)).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.xs)
        }, (k: number) => 'lg' + k)
      }.width('100%')

      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.no + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.secs) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Text(SYMS[this.idx]).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .textAlign(TextAlign.Center).width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (c: number) => {
              Text(String((r * 3 + c) + 1)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.pick >= 0 ? '#FFFFFF' : this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(56))
              .backgroundColor(this.pick === (r * 3 + c) ? Palette.rose : this.theme.surfaceAlt)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .scale({ x: this.pick === (r * 3 + c) ? Motion.pressScale : 1, y: this.pick === (r * 3 + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.answer((r * 3 + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.rose).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：先扫一眼对照表再点；同一个符号不会连着出现'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
