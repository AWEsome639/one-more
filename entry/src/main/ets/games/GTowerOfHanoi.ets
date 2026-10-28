/** 汉诺塔 🗼（id: tower_of_hanoi）
 * 大盘不能压小盘，把整摞盘从最左柱搬到最右柱；搬到 ⇒ 通关，40 步搬不完 ⇒ 失败。 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
const PEGS: number = 3;
const DISKS: number = 4;
const BEST: number = 15;
const LIMIT: number = 40;
const COLORS: string[] = [Palette.amber, Palette.emerald, Palette.sky, Palette.violet];
const TOWERS: number[] = [0, 1, 2];
@Component
export struct GTowerOfHanoi {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State pegs: number[][] = [];
  @State sel: number = -1;
  @State moves: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT);
     this.reset(); }
  private reset(): void {
    const first: number[] = [];
    for (let d = DISKS; d >= 1; d--) { first.push(d); }
    this.pegs = [first, [], []];
    this.sel = -1; this.moves = 0; this.over = false; this.won = false; this.done = false;
    this.note = TG('点柱子拿起最上面的盘，再点另一根放下');
    this.startAt = Date.now();
  }
  /** ★ AI 代打/提示共用：从当前局面到「全堆在最右柱」的最优首步 [起柱, 落柱]（无步可走返回空） */
  /** 经典递归：让第 k 号盘归位之前，先把 1..k-1 挪到中间柱；pos 边模拟边更新 */
  private hanoiPlan(k: number, target: number, pos: number[], out: number[]): void {
    if (k <= 0) {
      return;
    }
    if (pos[k] === target) {
      this.hanoiPlan(k - 1, target, pos, out);
      return;
    }
    const via: number = 3 - pos[k] - target;
    this.hanoiPlan(k - 1, via, pos, out);
    out.push(pos[k]);
    out.push(target);
    pos[k] = target;
    this.hanoiPlan(k - 1, target, pos, out);
  }

  private hanoiFirst(): number[] {
    const pos: number[] = new Array<number>(DISKS + 1).fill(-1);
    for (let p = 0; p < PEGS; p++) {
      if (p >= this.pegs.length) {
        continue;
      }
      for (let k = 0; k < this.pegs[p].length; k++) {
        pos[this.pegs[p][k]] = p;
      }
    }
    const out: number[] = [];
    this.hanoiPlan(DISKS, 2, pos, out);
    return out;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const mv: number[] = this.hanoiFirst();
    if (mv.length < 2) {
      return false;
    }
    if (this.sel >= 0) {
      if (mv[0] !== this.sel) {
        return false;
      }
      this.tapPeg(mv[1]);
      return !this.over;
    }
    this.tapPeg(mv[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const mv: number[] = this.hanoiFirst();
    if (mv.length < 2) {
      return Hint.none('none');
    }
    const pile: number[] = this.pegs[mv[0]];
    if (pile.length === 0) {
      return Hint.none('none');
    }
    const disk: number = pile[pile.length - 1];
    return Hint.make([mv[0], mv[1]],
      TG2('把 {0} 号盘从第 {1} 根柱搬到第 {2} 根柱', disk, mv[0] + 1, mv[1] + 1),
      TG2('Move disk {0} from peg {1} to peg {2}', disk, mv[0] + 1, mv[1] + 1), t0);
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

  private tapPeg(i: number): void {
    if (this.over) { return; }
    if (this.sel < 0) {
      if (this.pegs[i].length === 0) { this.note = TG('这根柱是空的'); return; }
      this.sel = i; this.note = TG2('拿起 {0} 号盘', String(this.pegs[i][this.pegs[i].length - 1]));
      return;
    }
    if (this.sel === i) { this.sel = -1; this.note = TG('放回原处，重新选'); return; }
    const from: number[] = this.pegs[this.sel];
    const to: number[] = this.pegs[i];
    const disk: number = from[from.length - 1];
    const top: number = to.length === 0 ? 99 : to[to.length - 1];
    if (disk > top) { this.note = TG('❌ 大盘不能压在小盘上'); return; }
    const next: number[][] = [];
    for (let k = 0; k < PEGS; k++) { next.push(this.pegs[k].slice()); }
    next[this.sel].pop(); next[i].push(disk);
    this.pegs = next; this.moves++; this.sel = -1;
    if (next[2].length === DISKS) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.moves >= this.diffTotal) { this.note = TG('步数用光了'); this.finish(false); return; }
    this.note = TG2('✅ 好，继续 · 右柱已有 {0} 个盘', String(next[2].length));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved;
    const r: GameResult = {
      gameId: 'tower_of_hanoi', solved: solved,
      score: solved ? Math.max(30, 200 - (this.moves - BEST) * 8) : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.pegs[2].length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  /** 顶盘在前，方便从上往下画 */
  private view(i: number): number[] {
    const out: number[] = [];
    if (i >= this.pegs.length) { return out; }
    for (let k = this.pegs[i].length - 1; k >= 0; k--) { out.push(this.pegs[i][k]); }
    return out;
  }
  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG('步数 ') + String(this.moves) + ' · 最少 ' + String(BEST) + ' · 上限 ' + String(this.diffTotal) +
        ' · 右柱 ' + String(this.pegs.length > 2 ? this.pegs[2].length : 0) + '/' + String(DISKS))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Row({ space: Space.xs }) {
        ForEach(TOWERS, (i: number) => {
          this.peg(i)
        }, (i: number) => 'peg' + i)
      }
      .width('100%').height(Space.xxxl * 3).padding(Space.xs)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  peg(i: number) {
    Column({ space: 2 }) {
      Column({ space: 2 }) {
        ForEach(this.view(i), (d: number) => {
          Stack() {
            Text(String(d)).fontSize(FontSize.xxs).fontColor('#FFFFFF')
          }
          .width(Space.xl + d * Space.md).height(Space.lg).backgroundColor(COLORS[d - 1])
          .borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
          // ★ 2026-10-15 补动画：盘子换柱时是重新创建的 ⇒ 加 transition 才不是"硬切"
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
        }, (d: number) => 'd' + d + '_' + i)
      }
      .layoutWeight(1).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
      Stack()
        .width('100%').height(Space.xs).borderRadius(Radius.xs)
        .backgroundColor(this.sel === i ? Palette.amber : this.theme.lineSoft)
    }
    .layoutWeight(1).height('100%').padding(Space.xs).borderRadius(Radius.md)
    .borderWidth(this.sel === i ? 2 : 0).borderColor(Palette.amber)
    .onClick(() => { Haptics.tick(); this.tapPeg(i); })
  }
}
