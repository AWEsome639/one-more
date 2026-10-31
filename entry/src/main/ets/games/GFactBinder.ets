/**
 * 事实绑定 📐
 * 玩法：左栏 5 条事实、右栏 5 个答案（已打乱）；左右各点一个即成对绑定，配对成功变绿。
 * 胜负：5 组全部绑定 = 通关；失误满 3 次 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

interface FactPair { ask: string; ans: string; }

const PAIRS: FactPair[] = [
  { ask: '🇨🇳 中国', ans: '北京' }, { ask: '🇯🇵 日本', ans: '东京' },
  { ask: '🇫🇷 法国', ans: '巴黎' }, { ask: '🇪🇬 埃及', ans: '开罗' },
  { ask: '🇦🇺 澳大利亚', ans: '堪培拉' }
];
const IDX: number[] = [0, 1, 2, 3, 4];
const LIVES: number = 3;

@Component
export struct GFactBinder {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private order: number[] = [];
  @State private done: boolean[] = [];
  @State private pickL: number = -1;
  @State private pickR: number = -1;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFactBinder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
     this.reset(); }

  private reset(): void {
    const order: number[] = IDX.slice();
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    const flags: boolean[] = [];
    for (let i = 0; i < IDX.length; i++) { flags.push(false); }
    this.order = order; this.done = flags; this.pickL = -1; this.pickR = -1;
    this.wrong = 0; this.over = false; this.won = false;
    this.note = TG(TG(TG('左右各点一个，把事实与答案绑起来 🔗')));
    this.startAt = Date.now();
  }

  private bound(): number {
    let n: number = 0;
    for (let i = 0; i < this.done.length; i++) { if (this.done[i]) { n++; } }
    return n;
  }

  private tryBind(): void {
    const li: number = this.pickL;
    const ri: number = this.pickR;
    if (li < 0 || ri < 0) { return; }
    if (li === ri) {
      const flags: boolean[] = this.done.slice();
      flags[li] = true;
      this.done = flags; this.pickL = -1; this.pickR = -1;
      this.note = TG2('绑上了：{0} → {1} ✅', PAIRS[li].ask, PAIRS[li].ans);
      if (this.bound() >= IDX.length) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); }
      return;
    }
    this.wrong++; this.pickL = -1; this.pickR = -1;
    this.note = TG2('对不上，再想想 🤔（失误 {0}/{1}）', this.wrong, this.diffTotal);
    if (this.wrong >= this.diffTotal) { this.finish(false); }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const li: number = this.pickL;
    if (li >= 0 && !this.done[li]) {
      this.tapR(li);
      return !this.over;
    }
    let next: number = -1;
    for (let i = 0; i < IDX.length; i++) {
      if (!this.done[i]) {
        next = i;
        break;
      }
    }
    if (next < 0) {
      return false;
    }
    this.tapL(next);
    return !this.over;
  }

  /** 提示：报「哪条事实配哪个答案」（左边 i 与右边同 i 才绑得上） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    let li: number = this.pickL;
    if (li < 0) {
      for (let i = 0; i < IDX.length; i++) {
        if (!this.done[i]) {
          li = i;
          break;
        }
      }
    }
    if (li < 0) {
      return Hint.none('none');
    }
    return Hint.make([li],
      TG2('「{0}」配「{1}」', PAIRS[li].ask, PAIRS[li].ans),
      TG2('"{0}" goes with "{1}"', PAIRS[li].ask, PAIRS[li].ans), t0);
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

  private tapL(i: number): void {
    if (this.over || this.done[i]) { return; }
    this.pickL = i;
    this.tryBind();
  }

  private tapR(i: number): void {
    if (this.over || this.done[i]) { return; }
    this.pickR = i;
    this.tryBind();
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.note = solved ? '五组全部绑定，通关 🎉' : '失误太多，这局没绑完 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'fact_binder', solved: solved,
      score: solved ? 60 + (IDX.length - this.wrong) * 10 : this.bound() * 12,
      durationMs: Date.now() - this.startAt, levelReached: this.bound() + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Text(TG2("已绑定 {0}/{1}", this.bound(), IDX.length))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          ForEach(IDX, (i: number) => { this.tileL(i); }, (i: number) => 'L' + i)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          ForEach(this.order, (i: number) => { this.tileR(i); }, (i: number) => 'R' + i)
        }.layoutWeight(1)
      }.width('100%')
      Text(this.note).fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  tileL(i: number) {
    Stack() {
      Text(this.done[i] ? '✅ ' + PAIRS[i].ans : PAIRS[i].ask)
        .fontSize(FontSize.sm).maxLines(1)
        .fontColor(this.done[i] ? '#FFFFFF' : this.theme.ink)
    }
    .width('100%').height(Space.xxxl)
    .backgroundColor(this.done[i] ? Palette.emerald : (this.pickL === i ? Palette.primary : this.theme.surface))
    .borderRadius(Radius.sm).shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapL(i); }); })
    .onClick(() => { Haptics.tick(); this.tapL(i); })
  }

  @Builder
  tileR(i: number) {
    Stack() {
      Text(this.done[i] ? '✅ ' + PAIRS[i].ans : PAIRS[i].ans)
        .fontSize(FontSize.sm).maxLines(1)
        .fontColor(this.done[i] ? '#FFFFFF' : this.theme.ink)
    }
    .width('100%').height(Space.xxxl)
    .backgroundColor(this.done[i] ? Palette.emerald : (this.pickR === i ? Palette.primary : this.theme.surface))
    .borderRadius(Radius.sm).shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapR(i); }); })
    .onClick(() => { Haptics.tick(); this.tapR(i); })
  }
}
