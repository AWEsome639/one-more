/**
 * 叠方块 🧊 —— 物理堆叠
 * 规则：三根柱子各有内宽/限高，方块宽度必须与柱内宽完全相等才塞得进（不许悬空压边）。
 * 胜负：清单放完 = 通关；某柱超高失衡 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const SLOT: number = 5; const EMJ: string[] = ['', '🟦', '🟩', '🟨', '🟥'];

interface StackLevel {
  inner: number[]; cap: number;
  queue: number[];
}

const LEVELS: StackLevel[] = [
  { inner: [2, 3, 4], cap: 2, queue: [4, 2, 3, 2, 3, 2, 4] },
  { inner: [2, 3, 2], cap: 2, queue: [3, 2, 2, 3, 2, 2] },
  { inner: [4, 2, 3], cap: 2, queue: [2, 2, 3, 3, 4, 2, 4] }
];

@Component
export struct GBlockStackingPhysics {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 SLOT=5
  @State private diffTotal: number = GameDiff.sizeNow(5);
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

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }

  private reset(): void {
    this.level = 0; this.queue = LEVELS[0].queue.slice();
    this.heights = [0, 0, 0]; this.slots = [];
    this.over = false; this.won = false;
    this.note = TG('点柱子把方块放进去'); this.startAt = Date.now();
  }

  private at(a: number[], i: number): number { return a[i]; }
  private placed(): number { return LEVELS[this.level].queue.length - this.queue.length; }

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
.backgroundColor(Palette.primary).borderRadius(Radius.md).onClick(() => { Haptics.tap(); this.reset(); })
        Button(TG('换一关'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44)).fontSize(FontSize.md).fontColor(this.theme.ink)
.backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).onClick(() => {
            Haptics.tap();
            const n: number = (this.level + 1) % LEVELS.length; this.reset();
            this.level = n; this.queue = LEVELS[n].queue.slice();
          })
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
