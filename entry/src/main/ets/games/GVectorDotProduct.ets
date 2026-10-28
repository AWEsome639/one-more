/** 向量点积 —— 计算点积
 *  玩法：给出两个向量（2 维或 3 维），从 4 个选项里选出正确的点积
 *  胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 8; const PASS: number = 6; const NEXT_MS: number = 800;
interface Pair { u: number[]; v: number[] }
function makePair(): Pair {
  const dim: number = Math.random() < 0.55 ? 2 : 3; const u: number[] = []; const v: number[] = [];
  for (let i = 0; i < dim; i++) {
    u.push(-6 + Math.floor(Math.random() * 13)); v.push(-6 + Math.floor(Math.random() * 13));
  }
  const p: Pair = { u: u, v: v };
  return p;
}
function dot(u: number[], v: number[]): number {
  let s: number = 0;
  for (let i = 0; i < u.length; i++) { s = s + u[i] * v[i]; }
  return s;
}
function vecText(name: string, a: number[]): string { return name + ' = (' + a.join(', ') + ')'; }
function shuffle(a: number[]): number[] {
  const out: number[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
function buildOpts(ans: number, u: number[], v: number[]): number[] {
  const swap: number = u.length === 2 ? u[0] * v[1] + u[1] * v[0] : u[0] * v[1] + u[1] * v[2] + u[2] * v[0];
  const minus: number = u.length === 2 ? u[0] * v[0] - u[1] * v[1] : u[0] * v[0] - u[1] * v[1] - u[2] * v[2];
  const cands: number[] = [swap, minus, ans + u[0] + v[0], ans - u[1] - v[1], ans + 1, ans - 1];
  const out: number[] = [ans];
  for (let i = 0; i < cands.length && out.length < 4; i++) {
    if (out.indexOf(cands[i]) < 0) { out.push(cands[i]); }
  }
  let extra: number = 3;
  while (out.length < 4) {
    if (out.indexOf(ans + extra * 7) < 0) { out.push(ans + extra * 7); }
    extra++;
  }
  return out;
}
@Component
export struct GVectorDotProduct {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=8
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(8);
  onFinish: (r: GameResult) => void = () => {};
  @State private u: number[] = []; @State private v: number[] = []; @State private opts: number[] = [];
  @State private answer: number = 0; @State private round: number = 1; @State private right: number = 0;
  @State private score: number = 0; @State private pick: number = -1; @State private answered: boolean = false;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.right = 0; this.score = 0; this.over = false;
    this.won = false; this.ask(); this.msg = TG('算一算 u · v 等于多少');
  }
  private ask(): void {
    const p: Pair = makePair(); this.u = p.u; this.v = p.v; this.answer = dot(p.u, p.v);
    this.opts = shuffle(buildOpts(this.answer, p.u, p.v)); this.pick = -1; this.answered = false;
  }
  /** 提示：和代打同一个循环（含局部常量），只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.answer) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 答完要等一会儿才进下一题 ⇒ 先看"这一轮答过没有"，答过就等着，
  //   否则每拍都会重复提交、把计数打乱。
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
    if (this.answered) {
      return true;
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.answer) {
        this.submit(i);
        break;
      }
    }
    return !this.over;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private submit(i: number): void {
    if (this.answered || this.over || this.opts.length <= i) { return; }
    this.answered = true; this.pick = i; const ans: number = this.answer; const got: number = this.opts[i];
    if (got === ans) {
      this.right = this.right + 1; this.score = this.score + 140; this.msg = '✅ u · v = ' + String(ans); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    } else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 你选了 {0}，正确是 {1}', String(got), String(ans)); }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1; this.next();
    }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG('算一算 u · v 等于多少');
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'vector_dot_product', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(PASS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('➡️ 点积')).fontSize(FontSize.sm).fontColor(Palette.primary)
        Text(vecText('u', this.u)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(vecText('v', this.v)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.u.length === 2 ? 'u · v = u₁v₁ + u₂v₂' : 'u · v = u₁v₁ + u₂v₂ + u₃v₃').fontSize(FontSize.xs)
          .fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? String(this.opts[(0)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (0)
        ? ((0) < this.opts.length && this.opts[(0)] === this.answer ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((0));
        })
        Button(this.opts.length > (1) ? String(this.opts[(1)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (1)
        ? ((1) < this.opts.length && this.opts[(1)] === this.answer ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((1));
        })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (2) ? String(this.opts[(2)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (2)
        ? ((2) < this.opts.length && this.opts[(2)] === this.answer ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((2));
        })
        Button(this.opts.length > (3) ? String(this.opts[(3)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
        .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink).backgroundColor(this.pick === (3)
        ? ((3) < this.opts.length && this.opts[(3)] === this.answer ? Palette.emerald : Palette.rose)
        : this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(54)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        Haptics.tap();
        this.submit((3));
        })
      }.width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      Text(TG('提示：对应分量相乘再全部相加，负号也算进去')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
