/** 三元逻辑 🧠（id: triplets_logic）
 * 三句「谁比谁高」里挑出唯一说得通的「从高到低」排序；6 题答对 ≥4 ⇒ 通关，否则失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
const NAMES: string[] = ['🦊', '🐼', '🐸'];
const PERMS: number[][] = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];
const SLOTS: number[] = [0, 1, 2, 3];
const ROUNDS: number = 6;
const NEED: number = 4;
const PAUSE: number = 800;
@Component
export struct GTripletsLogic {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State stmts: string[] = [];
  @State opts: number[][] = [];
  @State ans: number = 0;
  @State asked: number = 0;
  @State hits: number = 0;
  @State picked: number = -1;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimer(); }
  private clearTimer(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.clearTimer();
    this.asked = 0; this.hits = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.gen();
  }
  private shuf(n: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < n; i++) { out.push(i); }
    for (let i = n - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = out[i];
      out[i] = out[j]; out[j] = t;
    }
    return out;
  }
  private gen(): void {
    const ord: number[] = this.shuf(3);
    const finger: string = ord.join('');
    const s: string[] = [NAMES[ord[0]] + TG2(' 比 {0} 高', NAMES[ord[1]]),
      NAMES[ord[1]] + TG2(' 比 {0} 高', NAMES[ord[2]])];
    if (Math.random() < 0.5) { s.push(NAMES[ord[0]] + TG2(' 比 {0} 高', NAMES[ord[2]])); }
    const rest: number[][] = [];
    for (let i = 0; i < PERMS.length; i++) { if (PERMS[i].join('') !== finger) { rest.push(PERMS[i]); } }
    const ri: number[] = this.shuf(rest.length);
    const others: number[][] = [rest[ri[0]], rest[ri[1]], rest[ri[2]]];
    const at: number = Math.floor(Math.random() * 4);
    const out: number[][] = [];
    let k: number = 0;
    for (let i = 0; i < 4; i++) {
      if (i === at) { out.push(ord); } else { out.push(others[k]); k++; }
    }
    this.stmts = s; this.opts = out; this.ans = at; this.picked = -1;
    this.note = TG('三句线索合起来只有一种排法');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
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
    this.pick(this.ans);
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
    if (this.over || this.picked >= 0) { return; }
    this.picked = i;
    this.asked++;
    if (i === this.ans) { this.hits++; this.note = TG('✅ 推对了'); } else { this.note = TG('❌ 绿框那条才对'); }
    this.clearTimer();
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.asked >= this.diffTotal) { this.finish(this.hits >= NEED); return; }
      this.gen();
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved;
    this.clearTimer();
    const r: GameResult = {
      gameId: 'triplets_logic', solved: solved, score: this.hits * 18,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private label(o: number[]): string {
    return o.length < 3 ? '' : NAMES[o[0]] + ' › ' + NAMES[o[1]] + ' › ' + NAMES[o[2]];
  }
  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG('第 ') + String(Math.min(this.asked + 1, this.diffTotal)) + '/' + String(this.diffTotal) + ' 题 · 答对 ' +
        String(this.hits) + '/' + String(NEED))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Column({ space: Space.xs }) {
        ForEach(this.stmts, (line: string) => {
          Text('• ' + line).fontSize(FontSize.md).fontColor(this.theme.ink).width('100%')
        }, (line: string, i: number) => 'st' + i)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Text(TG('从高到低排，谁在前？')).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      ForEach(SLOTS, (i: number) => {
        this.option(i)
      }, (i: number) => 'op' + i)
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  option(i: number) {
    Text(this.opts.length > i ? this.label(this.opts[i]) : '')
      .fontSize(FontSize.xl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52)).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .borderWidth(2)
      .borderColor(this.picked < 0 ? this.theme.line :
        (i === this.ans ? Palette.emerald : (i === this.picked ? Palette.rose : this.theme.line)))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.pick(i); })
  }
}
