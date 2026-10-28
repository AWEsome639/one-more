/**
 * 方向回忆 📐 —— 一串箭头依次闪出，然后凭记忆按原顺序点回来
 * 共 5 关，长度 3→7；点错即本关失败、自动进下一关（回放不扣分）
 * 胜负：5 关过 ≥3 关通关　进度：关号 / 长度 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number[] = [3, 4, 5, 6, 7];
const PASS: number = 3;
const FLASH_MS: number = 600;
const GAP_MS: number = 220;
const ARROW: string[] = ['↑', '→', '↓', '←'];

@Component
export struct GDirectionsRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PASS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(PASS);
  onFinish: (r: GameResult) => void = () => {};

  @State private seq: number[] = [];
  @State private input: number[] = [];
  @State private flash: number = -1;
  @State private round: number = 0;
  @State private phase: string = 'show';      // show | input | done
  @State private wins: number = 0;
  @State private score: number = 0;
  @State private note: string = '';
  private startAt: number = 0;
  private timers: number[] = [];

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PASS);
     this.reset(); }

  private clearTimers(): void {
    for (let i = 0; i < this.timers.length; i++) { clearTimeout(this.timers[i]); }
    this.timers = [];
  }

  private reset(): void {
    this.clearTimers();
    this.round = 0; this.wins = 0; this.score = 0; this.note = '';
    this.startAt = Date.now();
    this.show(0);
  }

  /** 依次闪出本关序列 */
  private show(idx: number): void {
    const len: number = ROUNDS[idx];
    const seq: number[] = [];
    for (let i = 0; i < len; i++) { seq.push(Math.floor(Math.random() * 4)); }
    this.seq = seq; this.input = []; this.flash = -1;
    this.phase = 'show';
    this.note = TG2('看好了 —— {0} 个箭头', len);
    for (let i = 0; i < len; i++) {
      this.timers.push(setTimeout(() => { this.flash = seq[i]; }, GAP_MS + i * FLASH_MS));
      this.timers.push(setTimeout(() => { this.flash = -1; }, GAP_MS + i * FLASH_MS + FLASH_MS - 120));
    }
    this.timers.push(setTimeout(() => {
      this.phase = 'input';
      this.note = TG(TG(TG('轮到你了 —— 按原顺序点回来')));
    }, GAP_MS + len * FLASH_MS));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.phase === 'done') {
      return false;
    }
    if (this.phase !== 'input') {
      return true;
    }
    this.tap(this.seq[this.input.length]);
    return true;
  }

  /** 提示：按闪出的顺序报出这一步该点的箭头 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.phase !== 'input') { return Hint.none('none'); }
    if (this.input.length >= this.seq.length) { return Hint.none('none'); }
    const d: number = this.seq[this.input.length];
    return Hint.make([],
      TG2('这一步按 {0}（第 {1} 个）', ARROW[d], String(this.input.length + 1)),
      'Next arrow: ' + ARROW[d], t0);
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

  private tap(d: number): void {
    const ph: string = this.phase;
    if (ph !== 'input') { return; }
    const seq: number[] = this.seq;
    const at: number = this.input.length;
    if (seq[at] !== d) {
      this.note = TG('第 ') + (at + 1) + ' 步点错了 ❌';
      this.nextRound();
      return;
    }
    const grown: number[] = this.input.slice();
    grown.push(d);
    this.input = grown;
    if (grown.length === seq.length) {
      this.wins++; this.score += seq.length * 60;
      this.note = TG(TG(TG('整串对了 ✅')));
      this.nextRound();
    }
  }

  private nextRound(): void {
    this.phase = 'done';
    if (this.round + 1 >= ROUNDS.length) {
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'directions_recall', solved: this.wins >= this.diffTotal,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.wins
      });
      return;
    }
    this.round++;
    this.timers.push(setTimeout(() => { this.show(this.round); }, 900));
  }

  aboutToDisappear(): void { this.clearTimers(); }

  /** show 阶段第 i 格是不是正在闪；input 阶段显示已按的箭头 */
  @Builder
  slot(i: number) {
    Stack() {
      Text(this.flash === i ? ARROW[this.seq[i]] : (i < this.input.length ? ARROW[this.input[i]] : ''))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
    }
    .layoutWeight(1).height(Cell.of(52))
    .backgroundColor(this.flash === i ? Palette.rose : (i < this.input.length ? Palette.sky : this.theme.surfaceAlt))
    .borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  dirBtn(d: number) {
    Text(ARROW[d])
      .fontSize(FontSize.xxl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(64))
      .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(d); })
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
            Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", Math.min(this.round + 1, ROUNDS.length), ROUNDS.length)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG2('长度 {0}', String(this.seq.length > 0 ? this.seq.length : ROUNDS[0]))).fontSize(FontSize.md).fontColor(Palette.sky).layoutWeight(1)
        Text(TG('得分 ') + this.score).fontSize(FontSize.md).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')

      Text('📐 ' + this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.seq, (v: number, i: number) => {
          this.slot(i)
        }, (v: number, i: number) => 's' + i)
      }.width('100%').height(Cell.of(56))

      Text(this.phase === 'input' ? '已按 ' + this.input.length + '/' + this.seq.length : ' ')
        .fontSize(FontSize.xs).fontColor(this.theme.inkFaint).width('100%')

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          this.dirBtn(0)
          this.dirBtn(1)
        }.width('100%')
        Row({ space: Space.sm }) {
          this.dirBtn(3)
          this.dirBtn(2)
        }.width('100%')
      }.width('100%')

      
      Button(this.phase === 'done' ? '下一关…' : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
