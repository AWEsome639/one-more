/** 数列堆叠 —— 按规律往塔上堆下一层
 *  玩法：屏幕给出已堆好的数列，从 4 个候选里选出下一项（等差 / 等比）
 *  胜负：堆满 8 层 ⇒ 通关；错 3 次 ⇒ 失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const GOAL: number = 8; const LIVES: number = 3; const SHOWN: number = 5;
interface SeqInfo { kind: number; start: number; step: number }
function makeSeq(): SeqInfo {
  const kind: number = Math.random() < 0.62 ? 0 : 1;
  if (kind === 0) {
    const s: SeqInfo = { kind: 0, start: 1 + Math.floor(Math.random() * 9), step: 2 + Math.floor(Math.random() * 8) };
    return s;
  }
  const g: SeqInfo = { kind: 1, start: 1 + Math.floor(Math.random() * 3), step: 2 + Math.floor(Math.random() * 2) };
  return g;
}
function nextOf(last: number, info: SeqInfo): number { return info.kind === 0 ? last + info.step : last * info.step; }
function shuffle(a: number[]): number[] {
  const out: number[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1)); const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
function buildOpts(ans: number, last: number, info: SeqInfo): number[] {
  const delta: number = info.kind === 0 ? info.step : Math.max(1, Math.floor(last / 2));
  const cands: number[] = [ans + delta, ans - delta, ans + 1, ans - 1, ans + 2, ans + last];
  const out: number[] = [ans];
  for (let i = 0; i < cands.length && out.length < 4; i++) {
    const v: number = cands[i];
    if (v > 0 && v !== ans && out.indexOf(v) < 0) { out.push(v); }
  }
  let extra: number = 3;
  while (out.length < 4) {
    const v: number = ans + extra * 5;
    if (out.indexOf(v) < 0) { out.push(v); }
    extra++;
  }
  return out;
}
@Component
export struct GSequenceStack {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 GOAL=8
  @State private diffTotal: number = GameDiff.sizeNow(8);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State private terms: number[] = []; @State private opts: number[] = []; @State private answer: number = 0;
  @State private built: number = 0; @State private wrong: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private pick: number = -1; @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false;
  private info: SeqInfo = { kind: 0, start: 1, step: 2 };
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
     this.reset(); }

  /**
   * ★ 2026-10-23 第二期：数列堆叠提示
   *
   * 这款的规律只有两种：等差（每次 +step）与等比（每次 ×step）。
   * ⇒ **提示只说出「是哪种规律、步长多少」，不直接给答案。**
   *   玩家自己算一下就能得到下一项 —— 这才算「帮他想」而不是「替他想」。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const last: number = this.terms.length > 0 ? this.terms[this.terms.length - 1] : 0;
    if (this.info.kind === 0) {
      return Hint.make([],
        TG2('这是等差数列：每一项比前一项多 {0}（用 {1} 加一加）',
          String(this.info.step), String(last)),
        TG2('Arithmetic sequence: each term adds {0} (try {1} + {0})',
          String(this.info.step), String(last)), t0);
    }
    return Hint.make([],
      TG2('这是等比数列：每一项是前一项的 {0} 倍（用 {1} 乘一乘）',
        String(this.info.step), String(last)),
      TG2('Geometric sequence: each term multiplies by {0} (try {1} × {0})',
        String(this.info.step), String(last)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private reset(): void {
    this.startAt = Date.now(); this.done = false; this.built = 0; this.wrong = 0; this.score = 0; this.pick = -1;
    this.over = false; this.won = false; this.info = makeSeq(); this.terms = [this.info.start];
    this.msg = TG('看规律，选出下一层'); this.ask();
  }
  private ask(): void {
    const last: number = this.terms[this.terms.length - 1]; this.answer = nextOf(last, this.info);
    this.opts = shuffle(buildOpts(this.answer, last, this.info)); this.pick = -1;
  }
  private shownTerms(): number[] {
    const n: number = this.terms.length; return n <= SHOWN ? this.terms : this.terms.slice(n - SHOWN);
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款把正确答案存在 this.answer 里 ⇒ 每拍直接选它。
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
    // ★ choose(v) 里有"和上次选的一样就跳过"的判定，所以要先清掉 pick
    this.pick = -1;
    this.choose(this.answer);
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

  private choose(v: number): void {
    if (this.over || v === this.pick) { return; }
    this.pick = v; const ans: number = this.answer;
    if (v === ans) {
      const next: number[] = this.terms.slice(); next.push(ans); this.terms = next; this.built = this.built + 1;
      this.score = this.score + 15; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.built >= this.diffTotal) {
        this.over = true; this.won = true; this.msg = TG2('🎉 堆满 {0} 层，塔立住了！', String(this.diffTotal)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2("✅ 第 {0} 层落定", String(this.built)); this.ask();
    } else {
      this.wrong = this.wrong + 1; this.score = Math.max(0, this.score - 10); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.wrong >= LIVES) {
        this.over = true; this.won = false; this.msg = TG2('😵 错 {0} 次，塔塌了', String(LIVES)); this.finish(false); return;
      }
      this.msg = TG2('❌ {0} 不对，还剩 {1} 次机会', String(v), String(LIVES - this.wrong));
    }
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'sequence_stack', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.built };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('层数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.built) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.wrong) + '/' + String(LIVES))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(TG('🏗️ 数列堆叠')).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        Row({ space: Space.xs }) {
          ForEach(this.shownTerms(), (v: number, i: number) => {
            Text((String(v))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((this.theme.ink)).textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(48)).backgroundColor((this.theme.surfaceAlt)).borderRadius(Radius.sm)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (v: number, i: number) => 't' + i + '_' + v)
          Text(('?')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(('#FFFFFF')).textAlign(TextAlign.Center)
          .layoutWeight(1).height(Cell.of(48)).backgroundColor((Palette.sky)).borderRadius(Radius.sm)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.width('100%')
        Text(this.terms.length >= 2 ? '相邻两项差相同 ⇒ 等差；比相同 ⇒ 等比' : '先算出第二项，规律就露出来了').fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Button(this.opts.length > (i) ? String(this.opts[(i)]) : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg)
          .fontColor(this.opts.length > (i) && this.opts[(i)] === this.pick ? '#FFFFFF' : this.theme.ink)
          .backgroundColor(this.opts.length > (i) && this.opts[(i)] === this.pick
          ? (this.opts[(i)] === this.answer ? Palette.emerald : Palette.rose)
          : this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tap();
          if (this.opts.length > (i)) { this.choose(this.opts[(i)]); }
          })
        }, (i: number) => 'o' + i)
      }.width('100%')
      Button(TG('提示'))
        .fontSize(FontSize.sm)
        .fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)
        .width('100%').height(Cell.of(40)).onClick(() => {
          this.askHint();
        })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      Text(TG('提示：答错不换题，想清楚再点')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
