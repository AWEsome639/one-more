/**
 * 叠方块 🧊 —— 物理堆叠
 * 规则：三根柱子各有内宽/限高，方块宽度必须与柱内宽完全相等才塞得进（不许悬空压边）。
 * 胜负：清单放完 = 通关；某柱超高失衡 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const SLOT: number = 5; const EMJ: string[] = ['', '🟦', '🟩', '🟨', '🟥'];

interface StackLevel {
  inner: number[]; cap: number;
  queue: number[];
}

const LEVELS: StackLevel[] = [
  // ★ 2026-10-28 修正：第 1、3 关队列 7 块，但每根柱只收同宽的块 ——
  //   两关的方块都是「宽 2×3、宽 3×2、宽 4×2」，而宽 2 只有一根柱 ⇒ 那根柱得能叠 3 层；
  //   3 柱 × 限高 2 = 6 个位置 < 7 块 ⇒ 原来两关数学上无解。限高改 3（9 个位置）后全部塞得下。
  { inner: [2, 3, 4], cap: 3, queue: [4, 2, 3, 2, 3, 2, 4] },
  { inner: [2, 3, 2], cap: 2, queue: [3, 2, 2, 3, 2, 2] },
  { inner: [4, 2, 3], cap: 3, queue: [2, 2, 3, 3, 4, 2, 4] }
];

@Component
export struct GBlockStackingPhysics {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 SLOT=5
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-10-28：槽位跨距必须 ≥ UI 的 5 行，否则简单档 sizeNow(5)=4 会让第 2 根柱的块显示到第 1 根柱顶上。
  @State private diffTotal: number = Math.max(SLOT, GameDiff.sizeNow(5));
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private level: number = 0;
  @State private heights: number[] = [0, 0, 0];
  @State private slots: number[] = [];
  @State private queue: number[] = [];
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBlockStackingPhysics')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = Math.max(SLOT, GameDiff.sizeNow(5));
     this.reset(); }

  private reset(): void {
    this.level = 0; this.queue = LEVELS[0].queue.slice();
    this.heights = [0, 0, 0]; this.slots = [];
    this.over = false; this.won = false;
    this.note = TG('点柱子把方块放进去'); this.startAt = Date.now();
  }

  private at(a: number[], i: number): number { return a[i]; }
  private placed(): number { return LEVELS[this.level].queue.length - this.queue.length; }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    if (this.queue.length === 0 || this.bestPillar() < 0) {
      return true;
    }
    this.place(this.bestPillar());
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.queue.length === 0) {
      return Hint.none('none');
    }
    const w: number = this.queue[0];
    const best: number = this.bestPillar();
    if (best < 0) {
      return Hint.none('none');
    }
    return Hint.make([best],
      TG2('这块宽 {0}，正好塞进第 {1} 根柱子（内宽 {2}）', String(w), String(best + 1), String(LEVELS[this.level].inner[best])),
      TG2('This block is {0} wide — it fits pillar {1} (inner width {2})', String(w), String(best + 1), String(LEVELS[this.level].inner[best])), t0);
  }

  /** 能塞进当前方块、且已经叠得最矮的那根柱子（都塞不进返回 -1） */
  private bestPillar(): number {
    const w: number = this.queue.length > 0 ? this.queue[0] : -1;
    let best: number = -1;
    for (let k = 0; k < 3; k++) {
      if (LEVELS[this.level].inner[k] !== w) {
        continue;
      }
      if (best < 0 || this.heights[k] < this.heights[best]) {
        best = k;
      }
    }
    return best;
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

  private place(k: number): void {
    if (this.over || this.queue.length === 0) { return; }
    const w: number = this.queue[0]; const inner: number = LEVELS[this.level].inner[k];
    if (w !== inner) {
      this.note = TG2('内宽 {0}，这块 {1} 塞不进 🚫', inner, w); return;
    }
    const hs: number[] = this.heights.slice(); const sl: number[] = this.slots.slice();
    hs[k]++; sl[k * this.diffTotal + hs[k] - 1] = w;
    this.heights = hs; this.slots = sl;
    this.queue = this.queue.slice(1);
    if (hs[k] > LEVELS[this.level].cap) {
      this.note = TG2("第 {0} 根超高，塌了 💥", (k + 1)); this.finish(false);
      return;
    }
    if (this.queue.length === 0) {
      this.note = TG('全部就位，稳如泰山 ✅'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.note = TG('放稳了，继续 👌');
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'block_stacking_physics', solved: solved,
      score: this.placed() * 10 + (solved ? 60 : 0),
      durationMs: Date.now() - this.startAt, levelReached: this.level + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Text(TG2("第 {0}/{1} 关　已放 {2}/", (this.level + 1), LEVELS.length, this.placed())
        + LEVELS[this.level].queue.length + TG2(' 块　限高 {0} 层', LEVELS[this.level].cap))
.fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2], (k: number) => {
          Column({ space: 2 }) {
            Text(TG2('内宽 {0}', this.at(LEVELS[this.level].inner, k)))
.fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
            ForEach([4, 3, 2, 1, 0], (row: number) => {
              Text(this.at(this.slots, k * this.diffTotal + row) === 0 ? ''
                : EMJ[this.at(this.slots, k * this.diffTotal + row)])
.fontSize(FontSize.lg).textAlign(TextAlign.Center).width('100%').height(Cell.of(34))
.backgroundColor(this.at(this.slots, k * this.diffTotal + row) === 0
                  ? this.theme.surfaceAlt : this.theme.surface)
.borderRadius(Radius.xs).borderWidth(1)
.borderColor(this.at(this.slots, k * this.diffTotal + row) === 0
                  ? this.theme.line : Palette.sky)
.animation({ duration: Motion.fast, curve: Motion.snap() })
// ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
.transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
  .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (row: number) => 's' + row)
            Text(this.at(this.heights, k) + '/' + LEVELS[this.level].cap).fontSize(FontSize.xs)
.fontColor(this.at(this.heights, k) > LEVELS[this.level].cap
                ? Palette.danger : this.theme.inkSoft)
          }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
.borderRadius(Radius.md).borderWidth(1).borderColor(this.theme.line)
.focusable(Tv.on())
.focusBox(Tv.box())
.onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place(k); }); })
.onClick(() => { Haptics.tick(); this.place(k); })
        }, (k: number) => 'k' + k)
      }.width('100%').alignItems(VerticalAlign.Bottom)
      Column({ space: Space.xs }) {
        Text(this.queue.length > 0 ? '待放 ' + this.queue.length + TG(' 块') : '清单已空')
.fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.queue.length > 0 ? EMJ[this.queue[0]] + ' 宽 ' + this.queue[0] : '🏁')
.fontSize(FontSize.xxl)
      }
.width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft)
.width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
.backgroundColor(Palette.primary).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
        Button(TG('换一关'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.md).fontColor(this.theme.ink)
.backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); const n: number = (this.level + 1) % LEVELS.length; this.reset(); this.level = n; this.queue = LEVELS[n].queue.slice(); }); }).onClick(() => {
            Haptics.tap();
            const n: number = (this.level + 1) % LEVELS.length; this.reset();
            this.level = n; this.queue = LEVELS[n].queue.slice();
          })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
