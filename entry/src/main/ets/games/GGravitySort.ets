/**
 * 重力排序 —— 点列让整列重力塌落，同色叠在一起就消掉
 * 胜负：22 步内清空棋盘 ⇒ 通关｜进度：已消 / 总数 + 剩余步数
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROWS: number = 5;
const COLS: number = 5;
const MAX_MOVES: number = 22;
const COLORS: string[] = [Palette.rose, Palette.sky, Palette.amber, Palette.emerald, Palette.violet];
const EMOJI: string[] = ['🍒', '🫐', '🍋', '🥝', '🍇'];
const R5: number[] = [0, 1, 2, 3, 4];

@Component
export struct GGravitySort {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State grid: number[] = [];
  @State moves: number = 0; @State score: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
     this.reset(); }

  private reset(): void {
    const g: number[] = [];
    for (let i = 0; i < ROWS * COLS; i++) { g.push(Math.floor(Math.random() * COLORS.length)); }
    this.grid = g; this.moves = 0; this.score = 0;
    this.msg = TG(TG(TG('点任意一列，它顶端那种颜色会被吸走')));
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
  }

  private idx(r: number, c: number): number { return r * COLS + c; }

  private remain(): number {
    let n: number = 0;
    for (let i = 0; i < this.grid.length; i++) { if (this.grid[i] >= 0) { n++; } }
    return n;
  }

  /** 点一列：取该列最上面那块的颜色，同色全吸走，其余向下塌实 */
  /** 代打：哪一列最值得点（该列最上面那种颜色出现最多的一列） */
  private autoCol(): number {
    let best: number = 0;
    let bestN: number = -1;
    for (let c = 0; c < COLS; c++) {
      let top: number = -1;
      for (let r = 0; r < ROWS; r++) {
        const v: number = this.grid[this.idx(r, c)];
        if (v >= 0) {
          top = v;
          break;
        }
      }
      if (top < 0) {
        continue;
      }
      let cnt: number = 0;
      for (let r = 0; r < ROWS; r++) {
        if (this.grid[this.idx(r, c)] === top) {
          cnt++;
        }
      }
      if (cnt > bestN) {
        bestN = cnt;
        best = c;
      }
    }
    return best;
  }
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
    this.drop(this.autoCol());
    return !this.over;
  }

  // 点列 = 吸走该列最上面那种颜色 ⇒ 挑同色最多的一列报出来
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const c: number = this.autoCol();
    let top: number = -1;
    let cnt: number = 0;
    for (let r = 0; r < ROWS; r++) {
      const v: number = this.grid[this.idx(r, c)];
      if (v >= 0) {
        top = v;
        break;
      }
    }
    for (let r = 0; r < ROWS; r++) {
      if (this.grid[this.idx(r, c)] === top) {
        cnt++;
      }
    }
    if (top < 0) {
      return Hint.none('none');
    }
    return Hint.make([], '点第 ' + String(c + 1) + ' 列，一次吸走 ' + String(cnt) + ' 块同色（还剩 ' + String(this.remain()) + ' 块）',
      'Tap column ' + String(c + 1) + ' to remove ' + String(cnt) + ' blocks', t0);
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

  private drop(c: number): void {
    if (this.over) { return; }
    const live: number[] = [];
    for (let r = 0; r < ROWS; r++) {
      const v: number = this.grid[this.idx(r, c)];
      if (v >= 0) { live.push(v); }
    }
    if (live.length === 0) { return; }
    const keep: number[] = live.filter((v: number) => v !== live[0]);
    const gone: number = live.length - keep.length;
    const ng: number[] = this.grid.slice();
    for (let r = 0; r < ROWS; r++) {
      const row: number = ROWS - 1 - r;
      ng[this.idx(row, c)] = r < keep.length ? keep[keep.length - 1 - r] : -1;
    }
    this.grid = ng;
    this.moves = this.moves + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    this.score = this.score + gone * 10 + (gone > 1 ? 20 : 0);
    const left: number = this.remain();
    if (left === 0) {
      this.over = true; this.won = true;
      this.msg = '🎉 全部归位！用了 ' + this.moves + TG(' 步');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.msg = '💤 步数用尽，还剩 ' + left + TG(' 块');
      this.finish(false);
      return;
    }
    this.msg = '吸走 ' + gone + ' 块同色' + (gone > 1 ? '（连消 +20）' : '');
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'gravity_sort', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.diffTotal - this.moves };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Text(TG2("已消 {0}/{1}", (ROWS * COLS - this.remain()), (ROWS * COLS)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        ForEach(R5, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(R5, (c: number) => { this.cell(r, c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.xs }) {
        ForEach(R5, (c: number) => {
          Text('⬇').fontSize(FontSize.lg).textAlign(TextAlign.Center).fontColor(Palette.teal).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
            .accessibilityLevel('no')
            .layoutWeight(1).height(Cell.of(40)).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm)
            .onClick(() => { Haptics.tick(); this.drop(c); })
        }, (c: number) => 'd' + c)
      }.width('100%')
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cell(r: number, c: number) {
    Stack() {
      Text(this.grid[this.idx(r, c)] >= 0 ? EMOJI[this.grid[this.idx(r, c)]] : '').fontSize(FontSize.xl)
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(this.grid[this.idx(r, c)] >= 0 ? COLORS[this.grid[this.idx(r, c)]] : this.theme.line)
    .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.drop(c); })
  }
}
