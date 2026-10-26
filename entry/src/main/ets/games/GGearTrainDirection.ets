/**
 * 齿轮组 ⚙️
 * 玩法：一串齿轮首尾相接，连接处可能是啮合（⛓ 反向）或皮带（🪢 同向）。
 * 已知 1 号齿轮转向，逐级推到最后一级该怎么转。
 * 胜负：8 题全过 = 通关；答错 3 题 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 8;
const LIVES: number = 3;

function spinText(cw: boolean): string {
  return cw ? '↻ 顺时针' : '↺ 逆时针';
}

@Component
export struct GGearTrainDirection {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private gearIds: number[] = [];
  @State private links: boolean[] = [];
  @State private firstCw: boolean = true;
  @State private idx: number = 0;
  @State private score: number = 0;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  /** 抽一组 3~5 个齿轮 + 每段连接方式 */
  private roll(): void {
    const n: number = 3 + Math.floor(Math.random() * 3);
    const ids: number[] = [];
    const ls: boolean[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
      if (i < n - 1) { ls.push(Math.random() < 0.65); }
    }
    this.gearIds = ids; this.links = ls;
    this.firstCw = Math.random() < 0.5;
  }

  private reset(): void {
    this.idx = 0; this.score = 0; this.wrong = 0;
    this.over = false; this.won = false;
    this.note = TG(TG(TG('沿齿轮组一路推下去 ⚙️')));
    this.roll();
    this.startAt = Date.now();
  }

  /** 末级转向：每遇一次啮合就翻转一次 */
  private lastCw(): boolean {
    let cw: boolean = this.firstCw;
    for (let i = 0; i < this.links.length; i++) {
      if (this.links[i]) { cw = !cw; }
    }
    return cw;
  }

  private dirLabel(i: number): string {
    if (i === 0) { return spinText(this.firstCw); }
    if (i === this.gearIds.length - 1) { return '?'; }
    return '·';
  }

  /** 提示：报「是 / 否」——代打用的表达式算出来是它 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const truth: boolean = this.lastCw();
    return Hint.make([],
      truth ? TG('答案是「是」') : TG('答案是「否」'),
      truth ? TG('The answer is Yes') : TG('The answer is No'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔现算：this.lastCw()
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over) {
      return true;
    }
    this.answer(this.lastCw());
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

  private answer(userCw: boolean): void {
    if (this.over) { return; }
    const expect: boolean = this.lastCw();
    if (userCw === expect) {
      this.score += 12;
      this.note = TG2('对！末级 {0} ✅', spinText(expect));
    } else {
      this.wrong++;
      this.note = TG2('错：正确答案是 {0}（失误 {1}/{2}）', spinText(expect), this.wrong, LIVES);
    }
    this.idx++;
    if (this.wrong >= LIVES) { this.finish(false); return; }
    if (this.idx >= this.diffTotal) { this.finish(true); return; }
    this.roll();
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.note = solved ? '八组传动全推对，通关 🎉' : '失误三次，传动链断了 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'gear_train_direction', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.idx + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        autoOn: this.autoId >= 0
      })
      Text(TG('第 ') + Math.min(this.idx + 1, this.diffTotal) + '/' + this.diffTotal + ' 题　得分 ' + this.score
        + TG('　失误 ') + this.wrong + '/' + LIVES)
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.gearIds, (i: number) => {
          this.gearRow(i)
          if (i < this.links.length) {
            this.linkRow(i)
          }
        }, (i: number) => 'g' + i)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button(TG('↻ 顺时针'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.berry)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('↺ 逆时针'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  gearRow(i: number) {
    Row({ space: Space.sm }) {
      Text(TG2('齿轮 {0}', (i + 1))).fontSize(FontSize.sm).fontColor(this.theme.ink).layoutWeight(1)
      Text('⚙️').accessibilityLevel('no').fontSize(FontSize.lg)
      Text(this.dirLabel(i)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width(80).textAlign(TextAlign.End)
    }
    .width('100%').height(Cell.of(36))
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  linkRow(i: number) {
    Text(this.links[i] ? '⛓ 啮合 ⇒ 反向' : '🪢 皮带 ⇒ 同向')
      .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      .width('100%').textAlign(TextAlign.Center)
  }
}
