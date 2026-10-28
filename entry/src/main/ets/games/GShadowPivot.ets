/**
 * 影子旋转 🔄（id: shadow_pivot）
 * 给出原形与光源转过的角度，从 4 张剪影里挑出「转过该角度」的那张影子。
 * 胜负：6 题答对 ≥4 ⇒ 通关；进度：题号 / 答对 / 光源角度。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const M: number = 5; const CELLS: number = M * M;
// ★★ 2026-10-13 修复：Difficulty 困难档 ×1.3 ⇒ 棋盘 7×7 = 49 格，
//   数组原来按 CELLS=25 开 ⇒【困难档必越界】✗
const MAX_N: number = 7; const MAX_CELLS: number = MAX_N * MAX_N; const ROUNDS: number = 6; const NEED: number = 4;
const ROWS: number[] = [0, 1, 2, 3, 4];
/** 每个图形 5 行 × 5 列；四个朝向互不相同，正好当四张剪影 */
const SHAPES: string[] = [
  '01100,01100,00100,00000,00000', '01000,11100,01000,00000,00000',
  '11000,01100,00100,00000,00000', '01110,00100,00100,00000,00000',
  '10000,11000,01100,00100,00000', '01100,00100,01100,00000,00000'
];

function parse(s: string): number[] {
  const flat: string = s.split(',').join(''); const out: number[] = [];
  for (let i = 0; i < flat.length; i++) { out.push(flat.charAt(i) === '1' ? 1 : 0); }
  return out;
}
/** 顺时针 90°：(r,c) → (c, M-1-r) */
// ★★ 2026-10-13 修复循环上界（困难档 ×1.3 ⇒ 棋盘更大，原来只转前 CELLS 格）
//   ⇒ 加 n 参数（= 实际边长），M/CELLS 全换成 n/n*n
function rot(a: number[], n: number): number[] {
  const out: number[] = new Array<number>(MAX_CELLS).fill(0);
  for (let i = 0; i < n * n; i++) { if (a[i] === 1) { out[(i % n) * n + (n - 1 - Math.floor(i / n))] = 1; } }
  return out;
}
/** 原形 + 90°/180°/270° 三个朝向 */
function ring4(b: number[], n: number): number[][] {
  const out: number[][] = [b];
  for (let i = 0; i < 3; i++) { out.push(rot(out[i], n)); }
  return out;
}

@Component
export struct GShadowPivot {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 M=5
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(5);
  onFinish: (r: GameResult) => void = () => {};
  @State base: number[] = []; @State angle: number = 90; @State opts: number[][] = [];
  @State answerAt: number = 0; @State asked: number = 0; @State hits: number = 0;
  @State picked: number = -1; @State over: boolean = false; @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private nextTimer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; } }
  private reset(): void {
    this.stopTimer(); this.asked = 0; this.hits = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    const b: number[] = parse(SHAPES[0]); const ring: number[][] = ring4(b, this.diffTotal);
    this.base = b; this.opts = [ring[1], ring[2], ring[3], b]; this.answerAt = 3;
    this.note = TG('光源转多少度，影子就转多少度');
    this.newRound();
  }
  private newRound(): void {
    const b: number[] = parse(SHAPES[Math.floor(Math.random() * SHAPES.length)]);
    const k: number = 1 + Math.floor(Math.random() * 3);       // 影子转 k 个 90°
    const ring: number[][] = ring4(b, this.diffTotal);
    const want: number[] = ring[k];
    // 一正三误：另外三个朝向 + 正确朝向，再整体随机转一圈，正确项位置就随机了
    const list: number[][] = [want, ring[(k + 1) % 4], ring[(k + 2) % 4], ring[(k + 3) % 4]];
    const shift: number = Math.floor(Math.random() * 4);
    const opts: number[][] = [list[shift], list[(shift + 1) % 4], list[(shift + 2) % 4], list[(shift + 3) % 4]];
    let ans: number = 0;
    for (let i = 0; i < 4; i++) { if (opts[i] === want) { ans = i; } }
    this.base = b; this.angle = k * 90; this.opts = opts; this.answerAt = ans;
    this.picked = -1; this.note = TG2('光源顺时针转 {0}°，哪张是它的影子？', (k * 90));
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
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (i === this.answerAt) { this.hits++; this.note = TG('✅ 影子就是它'); }
    else { this.note = TG('❌ 不是这张，绿框才是对的'); }
    this.stopTimer();
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.asked >= ROUNDS) { this.finish(this.hits >= NEED); return; }
      this.newRound();
    }, 900);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.stopTimer();
    const res: GameResult = { gameId: 'shadow_pivot', solved: solved, score: this.hits * 15, durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  /** mode < 0 ⇒ 原形整块同色；mode ≥ 0 ⇒ 第 mode 张剪影 */
  private cellColor(cells: number[], mode: number, i: number): string {
    if (cells.length <= i || cells[i] !== 1) { return this.theme.surfaceAlt; }
    if (mode < 0) { return Palette.rose; }
    return this.picked >= 0 && mode === this.answerAt ? Palette.emerald : (this.theme.isDark ? '#E2E8F0' : '#334155');
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
      Text(TG2("题号 {0}/{1}", Math.min(this.asked + 1, ROUNDS), ROUNDS))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
          Text(TG('原形')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Column() { Column({ space: 2 }) {
          ForEach(ROWS, (r: number) => {
          Row({ space: 2 }) {
          ForEach(ROWS, (c: number) => {
          Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
          .backgroundColor(this.cellColor((this.base), (-1), r * this.diffTotal + c))
          }, (c: number) => 'gc' + c)
          }.width('100%')
          }, (r: number) => 'gr' + r)
          }.width('100%') }.width(104)
        }.layoutWeight(1)
        Column({ space: 2 }) {
          Text(TG('光线')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text('🔄').accessibilityLevel('no').fontSize(FontSize.xxl).rotate({ angle: this.angle }).animation({ duration: Motion.base, curve: Motion.snap() })
          Text(TG2('顺时针 {0}°', this.angle)).fontSize(FontSize.xs).fontColor(Palette.rose)
        }.layoutWeight(1)
      }.width('100%')
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
        }.width('100%') }.width('72%')
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
        }.width('100%') }.width('72%')
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
        }.width('100%') }.width('72%')
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
        }.width('100%') }.width('72%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((3) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((3)); })
      }.width('100%')
      Text(this.note).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
