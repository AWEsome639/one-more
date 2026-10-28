/** 曼陀罗回忆 —— 彩格亮 2 秒后熄灭，凭记忆把亮过的格子点回来；连过 4 关通关，错一次即负 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 3;
const CELLS: number = N * N;
const ROUNDS: number = 4;
const MEM_MS: number = 2000;
const TINT: string[] = [
  Palette.primary, Palette.berry, Palette.emerald, Palette.amber,
  Palette.teal, Palette.violet, Palette.rose, Palette.cyan
];

function sameSet(a: number[], b: number[]): boolean {
  if (a.length !== b.length) { return false; }
  for (let i = 0; i < a.length; i++) { if (b.indexOf(a[i]) < 0) { return false; } }
  return true;
}

@Component
export struct GMandalaRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private lit: number[] = [];
  @State private picks: number[] = [];
  @State private level: number = 1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private phase: number = 0;   // 0 记忆 / 1 作答 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private memTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMandalaRecall')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.memTo >= 0) { clearTimeout(this.memTo); this.memTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.level = 1; this.score = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const need: number = Math.min(2 + this.level, CELLS - 1);
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    this.lit = slots.slice(0, need);
    this.picks = [];
    this.phase = 0;
    this.msg = '记住亮格（' + String(need) + TG(' 个）');
    this.memTo = setTimeout(() => {
      this.memTo = -1; this.phase = 1; this.msg = TG(TG(TG('把亮过的格子都点回来')));
    }, MEM_MS);
  }

  /** ★ AI 代打/提示共用：下一个还没点回去的亮格（没有就 -1） */
  private nextLit(): number {
    for (let i = 0; i < this.lit.length; i++) {
      if (this.picks.indexOf(this.lit[i]) < 0) { return this.lit[i]; }
    }
    return -1;
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
    if (this.phase !== 1 || this.nextLit() < 0) {
      return true;
    }
    this.tap(this.nextLit());
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 1) {
      return Hint.none('none');
    }
    const at: number = this.nextLit();
    if (at < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(at / N) + 1;
    const c: number = at % N + 1;
    return Hint.make([at],
      TG2('亮过的一共 {2} 格；还差点第 {0} 行第 {1} 列', r, c, this.lit.length),
      TG2('Tap row {0}, column {1} — {2} cells were lit in total', r, c, this.lit.length), t0);
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

  private tap(i: number): void {
    if (this.over || this.phase !== 1) { return; }
    if (this.picks.indexOf(i) >= 0) {
      const keep: number[] = [];
      for (let k = 0; k < this.picks.length; k++) { if (this.picks[k] !== i) { keep.push(this.picks[k]); } }
      this.picks = keep;
      return;
    }
    const next: number[] = this.picks.slice();
    next.push(i);
    this.picks = next;
    if (next.length < this.lit.length) {
      this.msg = TG('还差 ') + String(this.lit.length - next.length) + TG(' 格');
      return;
    }
    if (sameSet(next, this.lit)) {
      this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.level >= this.diffTotal) {
        this.phase = 2; this.over = true; this.won = true;
        this.msg = TG('🎉 通关！') + String(this.diffTotal) + ' 关全过';
        this.finish(true);
        return;
      }
      this.level = this.level + 1;
      this.msg = TG(TG(TG('✅ 对了，下一关')));
      this.nextTo = setTimeout(() => { this.nextTo = -1; this.newRound(); }, 700);
      return;
    }
    this.phase = 2; this.over = true; this.won = false;
    this.msg = '❌ 记错了，止步第 ' + String(this.level) + TG(' 关');
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'mandala_recall', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.level };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 0) {
      const k: number = this.lit.indexOf(i);
      return k >= 0 ? TINT[k % TINT.length] : this.theme.surfaceAlt;
    }
    if (this.phase === 1) { return this.picks.indexOf(i) >= 0 ? Palette.primaryDeep : this.theme.surfaceAlt; }
    if (this.lit.indexOf(i) >= 0) { return Palette.emerald; }
    return this.picks.indexOf(i) >= 0 ? Palette.rose : this.theme.surfaceAlt;
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
      Row() {
        Text(TG2('关卡 {0}', (String(this.level) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2('还差点 {0}', this.phase === 0 ? TG('看') : String(Math.max(this.lit.length - this.picks.length, 0)))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.xs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：只看位置，颜色只是帮你分组；点满即自动判定'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.phase === 1 && this.picks.indexOf(i) >= 0 ? '●' : '').fontSize(FontSize.md).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
