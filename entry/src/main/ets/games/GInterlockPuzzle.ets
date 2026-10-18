/**
 * 互锁拼图 —— 卡榫互相咬住，只能先抽没人压着的那一块
 * 胜负：8 步内全部抽出 ⇒ 通关｜进度：已抽 / 总数 + 剩余步数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const SLOTS: number = 9;
const PIECES: number = 6;
const MAX_MOVES: number = 8;
const GLYPH: string[] = ['🔩', '🔗', '🧩', '🪝', '⚙️', '🪢'];
const TINT: string[] = [Palette.rose, Palette.sky, Palette.amber, Palette.emerald, Palette.violet, Palette.teal];
const R3: number[] = [0, 1, 2];
const FALSE6: boolean[] = [false, false, false, false, false, false];

@Component
export struct GInterlockPuzzle {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State parts: number[] = [];       // 槽位 → 零件号（-1 空）
  @State gone: boolean[] = [];       // 零件是否已抽出
  @State blockers: number[][] = [];  // 每个零件被谁压着
  @State moves: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
     this.reset(); }

  /** 生成：按 0..5 顺序层层压 —— 编号大的被编号小的压，天然无环、必定有解 */
  private reset(): void {
    const order: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    const slots: number[] = [-1, -1, -1, -1, -1, -1, -1, -1, -1];
    for (let i = 0; i < PIECES; i++) { slots[order[i]] = i; }
    const blk: number[][] = [];
    const used: boolean[] = FALSE6.slice();
    for (let i = 0; i < PIECES; i++) {
      const dep: number[] = [];
      for (let j = 0; j < i; j++) {
        if (!used[j] && Math.random() < 0.45) { dep.push(j); used[j] = true; }
      }
      blk.push(dep);
    }
    this.parts = slots; this.gone = FALSE6.slice(); this.blockers = blk;
    this.moves = 0; this.score = 0;
    this.msg = TG(TG(TG('亮色的零件没人压着，可以抽')));
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
  }

  private takenCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.gone.length; i++) { if (this.gone[i]) { n++; } }
    return n;
  }

  /** 还压着零件 p 的、尚未抽走的零件数 */
  private pressure(p: number): number {
    let n: number = 0;
    const dep: number[] = this.blockers.length > p ? this.blockers[p] : [];
    for (let i = 0; i < dep.length; i++) { if (!this.gone[dep[i]]) { n++; } }
    return n;
  }

  private pull(slot: number): void {
    if (this.over) { return; }
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return; }
    if (this.pressure(p) > 0) {
      this.msg = TG2('🔒 {0} 还被 {1} 个零件压着', GLYPH[p], this.pressure(p));
      return;
    }
    const ng: boolean[] = this.gone.slice();
    ng[p] = true; this.gone = ng;
    this.moves = this.moves + 1;
    this.score = this.score + 100 + (this.blockers[p].length === 0 ? 30 : 0); this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    if (this.takenCount() === PIECES) {
      this.over = true; this.won = true;
      this.score = this.score + (this.diffTotal - this.moves) * 25;
      this.msg = '🎉 全部拆开！用了 ' + this.moves + TG(' 步');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.msg = TG2('💤 步数用尽，还剩 {0} 个零件', (PIECES - this.takenCount()));
      this.finish(false);
      return;
    }
    this.msg = TG2('✅ 抽出 {0}，看看谁松了', GLYPH[p]);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'interlock_puzzle', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.takenCount() };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Text(TG2("已拆 {0}/{1}", this.takenCount(), PIECES))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(R3, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(R3, (c: number) => { this.part(r * 3 + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.md)
      .backgroundColor(this.theme.isDark ? '#141414' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { this.reset(); })
      }.width('100%')
      Text(TG('格子里的数字 = 还压着它的零件数（灰色 = 抽不动）'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  part(slot: number) {
    Stack() {
      Text(this.deco(slot)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF').textAlign(TextAlign.Center)
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(this.cellColor(slot))
    .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { this.pull(slot); })
  }

  private deco(slot: number): string {
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return ''; }
    const press: number = this.pressure(p);
    return GLYPH[p] + (press > 0 ? '\n' + press : '');
  }

  private cellColor(slot: number): string {
    const p: number = this.parts[slot];
    if (p < 0 || this.gone[p]) { return this.theme.line; }
    if (this.pressure(p) > 0) { return this.theme.isDark ? '#3A3A3A' : '#CBD5E1'; }
    return TINT[p];
  }
}
