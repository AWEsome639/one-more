/**
 * 物体换位 —— 看清 💎 在哪只盒子下，盒子两两换位，盯住它的落点
 * 胜负：8 轮猜中 ≥ 6 ⇒ 通关　｜　进度：轮次 / 猜中 / 洗牌步数
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

const CUPS: number = 4;
const ROUNDS: number = 8;
const NEED: number = 6;
const PEEK_MS: number = 1100;
const SWAP_MS: number = 330;
const SLOTS: number[] = [0, 1, 2, 3];

@Component
export struct GObjectShuffle {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State cups: string[] = [];
  @State phase: number = 0;      // 0 亮底　1 洗牌　2 选盒　3 结果
  @State left: number = 0; @State stepTotal: number = 0;
  @State pairA: number = -1; @State pairB: number = -1; @State pick: number = -1;
  @State roundNo: number = 1; @State right: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private gemAt: number = 0; private startAt: number = 0;
  private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  /** 全部扣上（只看得见盒底） */
  private hide(): string[] {
    const out: string[] = [];
    for (let i = 0; i < CUPS; i++) { out.push('📦'); }
    return out;
  }

  private reset(): void {
    this.clearAll();
    this.roundNo = 1; this.right = 0; this.score = 0; this.pick = -1; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newRound();
  }

  private newRound(): void {
    const gem: number = Math.floor(Math.random() * CUPS);
    const cups: string[] = [];
    for (let i = 0; i < CUPS; i++) { cups.push(i === gem ? '💎' : '📦'); }
    this.gemAt = gem; this.cups = cups;
    this.stepTotal = 3 + Math.floor((this.roundNo - 1) / 2);
    this.left = this.stepTotal;
    this.pairA = -1; this.pairB = -1; this.pick = -1; this.phase = 0;
    this.msg = TG2("第 {0} 轮：看清 💎 在哪只盒子下", this.roundNo);
    this.timer = setTimeout(() => {
      this.timer = -1; this.cups = this.hide(); this.phase = 1;
      this.msg = TG2('洗牌 {0} 步：高亮的两只盒子在互换',Digits(String(this.stepTotal), this.langCode));
      this.shuffleStep();
    }, PEEK_MS);
  }

  /** 每一步交换两只盒子；💎 跟着它所在的那只走 */
  private shuffleStep(): void {
    if (this.left <= 0) {
      this.pairA = -1; this.pairB = -1; this.phase = 2;
      this.msg = TG('💎 现在在哪只盒子下？点它');
      return;
    }
    const a: number = Math.floor(Math.random() * CUPS);
    let b: number = Math.floor(Math.random() * CUPS);
    while (b === a) { b = Math.floor(Math.random() * CUPS); }
    const next: string[] = this.cups.slice();
    const tmp: string = next[a]; next[a] = next[b]; next[b] = tmp;
    this.cups = next;
    if (this.gemAt === a) { this.gemAt = b; } else if (this.gemAt === b) { this.gemAt = a; }
    this.pairA = a; this.pairB = b;
    this.left = this.left - 1;
    this.timer = setTimeout(() => { this.timer = -1; this.shuffleStep(); }, SWAP_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.gemAt  ｜ 守卫取自它自己的 if (...) { return; }
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 2) {
      return true;
    }
    this.answer(this.gemAt);
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
    if (this.phase !== 2) { return; }
    this.pick = i;
    const hit: boolean = i === this.gemAt;
    const shown: string[] = this.hide();
    shown[this.gemAt] = '💎';
    this.cups = shown; this.phase = 3;
    if (hit) {
      this.right = this.right + 1; this.score = this.score + 120;
      this.msg = TG('✅ 跟住了！');
    } else {
      this.msg = TG('❌ 它在这只盒子里');
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, 950);
  }

  private next(): void {
    if (this.roundNo >= this.diffTotal) {
      this.over = true; this.won = this.right >= NEED;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("猜中 {0} / {1}", this.right, this.diffTotal);
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.roundNo = this.roundNo + 1;
    this.newRound();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'object_shuffle', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.roundNo };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
              onAutoTap: () => { this.askAuto(); },
        showHint: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.roundNo + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('猜中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.stepTotal), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Row({ space: Space.sm }) {
        ForEach(SLOTS, (i: number) => { Stack() {
        Text(this.cups.length > (i) ? this.cups[(i)] : '📦').fontSize(FontSize.xxxl)
        }.layoutWeight(1).aspectRatio(0.8).backgroundColor(this.phase === 1 && ((i) === this.pairA || (i) === this.pairB) ? Palette.amber : this.theme.surfaceAlt)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 }).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.answer((i)); }) }, (i: number) => 'os' + i)
      }.width('100%').layoutWeight(1)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：洗牌时高亮的一对盒子正在互换，跟着 💎 走')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
