/**
 * 坐标绘图 📊
 * 玩法：网格是 5×5 画布，按给出的坐标顺序依次点格子，点完就围出一个菱形。
 * 坐标写作（列, 行），列从左往右 1→5、行从上往下 1→5。
 * 胜负：8 个点全部按顺序点亮 = 通关；点错 3 次 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const NEED: number = 8;
const LIVES: number = 3;
const CELL: number = 46;
const RC: number[] = [0, 1, 2, 3, 4];
/** 菱形轮廓的 8 个点：(列, 行)，均为 0 基 */
const PX: number[] = [2, 3, 4, 3, 2, 1, 0, 1];
const PY: number[] = [0, 1, 2, 3, 4, 3, 2, 1];

@Component
export struct GGraphCoordinatePlot {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private done: boolean[] = [];
  @State private step: number = 0;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
     this.reset(); }

  private reset(): void {
    const flags: boolean[] = [];
    for (let i = 0; i < N * N; i++) { flags.push(false); }
    this.done = flags;
    this.step = 0;
    this.wrong = 0;
    this.over = false;
    this.won = false;
    this.note = TG(TG(TG('照坐标顺序点，把菱形围出来 ✏️')));
    this.startAt = Date.now();
  }

  private hintList(): string {
    let s: string = '';
    for (let i = 0; i < NEED; i++) {
      s = s + '(' + (PX[i] + 1) + ',' + (PY[i] + 1) + ')';
      if (i < NEED - 1) { s = s + '→'; }
    }
    return s;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.step >= NEED) {
      return true;
    }
    this.tap(PY[this.step] * N + PX[this.step]);
    return !this.over;
  }

  /** 提示：按顺序报下一个点（坐标是内容，不是下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.step >= NEED) {
      return Hint.none('none');
    }
    const c: number = PX[this.step] + 1;
    const r: number = PY[this.step] + 1;
    const i: number = PY[this.step] * N + PX[this.step];
    return Hint.make([i],
      TG2('下一个点 ({0},{1})（列 {0} 行 {1}）', String(c), String(r)),
      TG2('Next point ({0},{1})', String(c), String(r)), t0);
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

  private tap(i: number): void {
    if (this.over) { return; }
    if (this.done[i]) {
      this.note = TG(TG(TG('这里已经画过了 ✏️')));
      return;
    }
    const need: number = this.step;
    const col: number = i % N;
    const row: number = Math.floor(i / N);
    if (col === PX[need] && row === PY[need]) {
      const flags: boolean[] = this.done.slice();
      flags[i] = true;
      this.done = flags;
      this.step++;
      if (this.step >= NEED) {
        this.note = TG(TG(TG('菱形画完，通关 🎉')));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.note = TG2('好，下一个 ({0},{1}) ✅', (PX[this.step] + 1), (PY[this.step] + 1));
      return;
    }
    this.wrong++;
    this.note = TG2('不是这个点 ✏️（失误 {0}/{1}）', this.wrong, this.diffTotal);
    if (this.wrong >= this.diffTotal) {
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.note = solved ? '菱形画完，通关 🎉' : '画歪三次，这局结束 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'graph_coordinate_plot',
      solved: solved,
      score: solved ? 40 + this.step * 6 - this.wrong * 10 : this.step * 5,
      durationMs: Date.now() - this.startAt,
      levelReached: this.step + 1
    });
  }

  build() {
    Column({ space: Space.xs }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG2("已绘 {0}/{1}", this.step, NEED))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Text(TG2('指令：{0}', this.hintList()))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
      Column({ space: Space.xs }) {
        ForEach(RC, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(RC, (c: number) => {
              this.tile(r * N + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.note)
        .fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  tile(i: number) {
    Stack() {
      Text(this.done[i] ? '🔸' : '')
        .fontSize(FontSize.sm)
    }
    .layoutWeight(1).height(CELL)
    .backgroundColor(this.done[i] ? Palette.amber : this.theme.surface).animation({ duration: Motion.fast, curve: Motion.snap() })
    .borderRadius(Radius.sm)
    .borderWidth(1).borderColor(this.theme.line)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
