/**
 * 变形者 📐（id: shape_shifter）
 * 看 4 个方格图，找出变换规律（每步转 90° / 右移一格 / 多长一格），挑出第 5 个。
 * 胜负：6 题答对 ≥4 ⇒ 通关；进度：题号 / 答对 / 规律。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const M: number = 4; const CELLS: number = M * M;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 6×6 = 36 格，
//   而数组原来按 CELLS = 16 开 ⇒【困难档必越界】✗）
const MAX_N: number = 6;
const MAX_CELLS: number = MAX_N * MAX_N; const ROUNDS: number = 6; const NEED: number = 4;
const ROWS: number[] = [0, 1, 2, 3];
const PATH: number[] = [5, 6, 9, 10, 1, 2, 4, 8, 0, 3, 7, 11, 12, 13, 14, 15];   // 生长规律的固定次序
const RULE_NAMES: string[] = ['每步顺时针转 90°', '每步整块右移一格', '每步多长出一格'];
/** 手挑的 6 个小块（4×4，各 5 格），都是「转 4 次才回原位」的非对称形 */
const BLOBS: number[][] = [
  [0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0], [1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
  [1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0], [0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
  [1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0], [0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0]
];

/** 顺时针 90°：(r,c) → (c, M-1-r) */
function rot(a: number[], n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n * n; i++) { if (a[i] === 1) { out[(i % n) * n + (n - 1 - Math.floor(i / n))] = 1; } }
  return out;
}
/** 整块右移一格（出界绕回） */
function shiftR(a: number[], n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n * n; i++) { out[Math.floor(i / n) * n + (i % n + 1) % n] = a[i]; }
  return out;
}
/** 左右镜像 —— 当干扰项，也是「规律说不说得通」的判据 */
function mirrorH(a: number[], n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n * n; i++) { out[i] = a[Math.floor(i / n) * n + (n - 1 - i % n)]; }
  return out;
}
/** 按 PATH 次序点亮 n 格 */
function grow(n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n && i < PATH.length; i++) { out[PATH[i]] = 1; }
  return out;
}
function sig(a: number[]): string { return a.join(''); }

@Component
export struct GShapeShifter {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 M=4
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(4);
  onFinish: (r: GameResult) => void = () => {};
  @State seq: number[][] = []; @State opts: number[][] = []; @State answerAt: number = 0;
  @State ruleName: string = ''; @State asked: number = 0; @State hits: number = 0;
  @State picked: number = -1; @State over: boolean = false; @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private nextTimer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; } }
  private reset(): void {
    this.stopTimer(); this.asked = 0; this.hits = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.seq = [grow(3), grow(4), grow(5), grow(6)];
    this.opts = [grow(7), rot(grow(6), this.diffTotal), shiftR(grow(6), this.diffTotal), mirrorH(grow(6), this.diffTotal)];
    this.ruleName = RULE_NAMES[2]; this.answerAt = 0;
    this.note = TG(TG(TG('看这 4 个图，第 5 个该是哪个？')));
    this.newRound();
  }
  private newRound(): void {
    for (let attempt = 0; attempt < 90; attempt++) {
      const rule: number = Math.floor(Math.random() * 3);
      const seq: number[][] = []; let ans: number[] = [];
      if (rule === 2) {
        const n0: number = 3 + Math.floor(Math.random() * 2);
        for (let i = 0; i < 4; i++) { seq.push(grow(n0 + i)); }
        ans = grow(n0 + 4);
      } else {
        let cur: number[] = BLOBS[Math.floor(Math.random() * BLOBS.length)];
        for (let i = 0; i < 4; i++) { seq.push(cur); cur = rule === 0 ? rot(cur, this.diffTotal) : shiftR(cur, this.diffTotal); }
        ans = cur;
      }
      const s0: string = sig(seq[0]); const s1: string = sig(seq[1]);
      const s2: string = sig(seq[2]); const s3: string = sig(seq[3]); const sa: string = sig(ans);
      if (s0 === s1 || s1 === s2 || s2 === s3 || sa === s3) { continue; }   // 规律得看得出来
      if (rule === 0 && (sig(shiftR(seq[3], this.diffTotal)) === sa || sig(mirrorH(seq[3], this.diffTotal)) === sa)) { continue; }
      if (rule === 1 && (sig(rot(seq[3], this.diffTotal)) === sa || sig(mirrorH(seq[3], this.diffTotal)) === sa)) { continue; }
      // 一正三误：正确答案 + 把它按错规律变一遍（四张必须互不相同，否则换题）
      const list: number[][] = [ans, rot(ans, this.diffTotal), shiftR(ans, this.diffTotal), mirrorH(ans, this.diffTotal)];
      const d1: string = sig(list[1]); const d2: string = sig(list[2]); const d3: string = sig(list[3]);
      if (d1 === sa || d2 === sa || d3 === sa || d1 === d2 || d2 === d3 || d1 === d3) { continue; }
      const shift: number = Math.floor(Math.random() * 4);
      const opts: number[][] = [list[shift], list[(shift + 1) % 4], list[(shift + 2) % 4], list[(shift + 3) % 4]];
      let ansAt: number = 0;
      for (let i = 0; i < 4; i++) { if (opts[i] === ans) { ansAt = i; } }
      this.seq = seq; this.opts = opts; this.answerAt = ansAt; this.ruleName = RULE_NAMES[rule];
      this.picked = -1; this.note = TG(TG(TG('看这 4 个图，第 5 个该是哪个？')));
      return;
    }
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.answerAt],
      TG2('答案是第 {0} 个', String(this.answerAt + 1)),
      TG2('The answer is option {0}', String(this.answerAt + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里 ⇒ 每一拍"选正确答案"；答过就等下一题（picked 守卫）
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.answerAt);
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
    this.picked = i; this.asked++;
    this.hits = i === this.answerAt ? this.hits + 1 : this.hits;
    this.note = i === this.answerAt ? TG2("✅ 对！规律是「{0}」", this.ruleName) : TG2("❌ 规律是「{0}」，绿框才对", this.ruleName);
    this.stopTimer();
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.asked >= ROUNDS) { this.finish(this.hits >= NEED); return; }
      this.newRound();
    }, 1000);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.stopTimer();
    const res: GameResult = { gameId: 'shape_shifter', solved: solved, score: this.hits * 15, durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  /** mode < 0 ⇒ 题面（青柠）；mode ≥ 0 ⇒ 第 mode 个选项 */
  private cellColor(cells: number[], mode: number, i: number): string {
    if (cells.length <= i || cells[i] !== 1) { return this.theme.surfaceAlt; }
    if (mode < 0) { return Palette.lime; }
    return this.picked >= 0 && mode === this.answerAt ? Palette.emerald : Palette.primary;
  }

  build() {
    Column({ space: Space.sm }) {
      Text(TG2("题号 {0}/{1}", Math.min(this.asked + 1, ROUNDS), ROUNDS))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Column({ space: 2 }) {
            Column() { Column({ space: 2 }) {
            ForEach(ROWS, (r: number) => {
            Row({ space: 2 }) {
            ForEach(ROWS, (c: number) => {
            Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
            .backgroundColor(this.cellColor((this.seq[i]), (-1), r * this.diffTotal + c))
            }, (c: number) => 'gc' + c)
            }.width('100%')
            }, (r: number) => 'gr' + r)
            }.width('100%') }.width('78%')
            Text(String(i + 1)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }, (i: number) => 'sq' + i)
      }.width('100%')
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(0)]), ((0)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('70%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((0) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((0)); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(1)]), ((1)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('70%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((1) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((1)); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(2)]), ((2)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('70%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((2) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((2)); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(3)]), ((3)), r * this.diffTotal + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('70%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((3) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((3)); })
      }.width('100%')
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
