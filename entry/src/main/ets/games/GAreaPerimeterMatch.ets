/**
 * 面积周长 —— 两个矩形，比面积或比周长（题面随机）；长宽按真实比例画，可以目测
 * 判据：面积 = 长×宽，周长 = 2×(长+宽)　胜负：10 题答对 ≥7 通关　进度：题号 / 答对 / 得分
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
const MAXSIDE: number = 12; const TOTAL: number = 10; const PASS: number = 7; const NEXT_MS: number = 820;
const CHOICES: string[] = [TG('A 更大'), TG('B 更大'), TG('一样大')];
@Component
export struct GAreaPerimeterMatch {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：题数（简单 8 / 普通 10 / 困难 13）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private qTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State w1: number = 4; @State h1: number = 3; @State w2: number = 6; @State h2: number = 2;
  @State metric: number = 0; @State ansIdx: number = 0; @State picked: number = -1;
  @State round: number = 1; @State rightN: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private nextTo: number = -1;
  private slots: number[] = [0, 1, 2];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.qTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    this.clearNext(); this.round = 1; this.rightN = 0; this.score = 0; this.over = false;
    this.won = false; this.finished = false; this.startAt = Date.now(); this.ask();
  }
  private rnd(): number { return 2 + Math.floor(Math.random() * (MAXSIDE - 1)); }
  private area(w: number, h: number): number { return w * h; }
  private peri(w: number, h: number): number { return 2 * (w + h); }
  private val(w: number, h: number): number { return this.metric === 0 ? this.area(w, h) : this.peri(w, h); }
  private pct(v: number): string { return Math.round(v / MAXSIDE * 100) + '%'; }
  private ask(): void {
    const w1: number = this.rnd(); const h1: number = this.rnd();
    const w2: number = this.rnd(); let h2: number = this.rnd();
    while (w1 === w2 && h1 === h2) { h2 = this.rnd(); }
    this.w1 = w1; this.h1 = h1; this.w2 = w2; this.h2 = h2;
    this.metric = Math.random() < 0.5 ? 0 : 1; this.picked = -1; this.ansIdx = this.cmp();
    this.msg = TG('看图比一比，然后再选');
  }
  /** 0 = A 大，1 = B 大，2 = 一样大 */
  private cmp(): number {
    const a: number = this.val(this.w1, this.h1);
    const b: number = this.val(this.w2, this.h2);
    if (a > b) { return 0; }
    return a === b ? 2 : 1;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ansIdx）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ansIdx 里） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ansIdx;
    return Hint.make([n],
      TG2('答案是第 {0} 个', String(n + 1)),
      TG2('The answer is option {0}', String(n + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ansIdx);
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i;
    const a: number = this.val(this.w1, this.h1);
    const b: number = this.val(this.w2, this.h2);
    if (i === this.ansIdx) { this.rightN = this.rightN + 1; this.score = this.score + 130; this.msg = TG2('✅ 对了 —— A {0}，B {1}', a, b); }
    else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 错了 —— A {0}，B {1}', a, b); }
    this.clearNext();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round < this.qTotal) { this.round = this.round + 1; this.ask(); return; }
    this.over = true; this.won = this.rightN >= PASS;
    this.msg = this.won ? TG2("🎉 答对 {0}/{1}，通关！",Digits(String(this.rightN), this.langCode),Digits(String(this.qTotal), this.langCode)) : TG2("😵 只答对 {0}/{1}，差 {2} 题", this.rightN, this.qTotal, (PASS - this.rightN));
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'area_perimeter_match', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rightN };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.qTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rightN + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.score))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Text(this.metric === 0 ? '谁的面积更大？' : '谁的周长更大？')
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(Palette.primaryDeep)
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Column() {
        Stack() {
        Text((this.w1) + '×' + (this.h1)).fontSize(FontSize.xxs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }
        .width(this.pct((this.w1))).height(this.pct((this.h1))).backgroundColor((Palette.emerald)).borderRadius(Radius.xs)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .width('100%').height(96).justifyContent(FlexAlign.Center)
        Text(true ? 'A' : 'B').fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        Text(this.picked < 0 ? '面积 ?  周长 ?' : '面积 ' + this.area((this.w1), (this.h1)) + ' · 周长 ' + this.peri((this.w1), (this.h1)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        Column({ space: Space.xs }) {
        Column() {
        Stack() {
        Text((this.w2) + '×' + (this.h2)).fontSize(FontSize.xxs).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }
        .width(this.pct((this.w2))).height(this.pct((this.h2))).backgroundColor((Palette.sky)).borderRadius(Radius.xs)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .width('100%').height(96).justifyContent(FlexAlign.Center)
        Text(false ? 'A' : 'B').fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        Text(this.picked < 0 ? '面积 ?  周长 ?' : '面积 ' + this.area((this.w2), (this.h2)) + ' · 周长 ' + this.peri((this.w2), (this.h2)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      }
      .width('100%')
      Row({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Text(CHOICES[(i)]).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.picked >= 0 && ((i) === this.ansIdx || (i) === this.picked) ? '#FFFFFF' : this.theme.ink)
          .layoutWeight(1).height(Cell.of(54))
          .backgroundColor(this.picked < 0 ? this.theme.surface
          : ((i) === this.ansIdx ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surface)))
          .borderRadius(Radius.md).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick((i)); })
        }, (i: number) => 'c' + i)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：面积看长宽之积，周长看四条边之和 —— 细长条的周长往往更大'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /** kind: 0 = A，1 = B */


}
