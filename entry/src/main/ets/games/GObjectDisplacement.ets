/**
 * 物体位移 —— 6 格里摆 5 个物件，遮罩一闪后其中一个偷偷换了格子，指出是谁动了
 * 胜负：8 轮答对 ≥ 6 ⇒ 通关　｜　进度：轮次 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐟', '🔔', '🍀', '🚀', '🎲', '🧩', '🌻', '🍄'];
const SLOTS: number = 6;
const ROUNDS: number = 8;
const NEED: number = 6;
const PEEK_MS: number = 1600;
const VEIL_MS: number = 700;
const CELLS: number[] = [0, 1, 2, 3, 4, 5];

@Component
export struct GObjectDisplacement {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State first: string[] = []; @State second: string[] = [];
  @State phase: number = 0;        // 0 记忆　1 遮罩　2 作答
  @State roundNo: number = 1; @State right: number = 0; @State score: number = 0;
  @State pick: number = -1; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private fromAt: number = -1; private toAt: number = -1;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GObjectDisplacement')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll();
    this.roundNo = 1; this.right = 0; this.score = 0; this.pick = -1; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newRound();
  }

  /** 摆好 5 个物件（留 1 个空格），再让其中一个挪进空格 */
  private newRound(): void {
    const bag: string[] = POOL.slice();
    const rest: string[] = [];
    while (rest.length < SLOTS - 1) {
      const k: number = Math.floor(Math.random() * bag.length);
      rest.push(bag[k]); bag.splice(k, 1);
    }
    const holeAt: number = Math.floor(Math.random() * SLOTS);
    const layout: string[] = rest.slice(0, holeAt).concat(['']).concat(rest.slice(holeAt));
    let srcAt: number = Math.floor(Math.random() * SLOTS);
    while (srcAt === holeAt) { srcAt = Math.floor(Math.random() * SLOTS); }
    const moved: string[] = layout.slice();
    moved[holeAt] = layout[srcAt]; moved[srcAt] = '';
    this.first = layout; this.second = moved; this.fromAt = srcAt; this.toAt = holeAt;
    this.pick = -1; this.phase = 0;
    this.msg = TG2("第 {0} 轮：记住每个物件在哪一格", this.roundNo);
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1; this.msg = TG('遮住了…');
      this.timer = setTimeout(() => {
        this.timer = -1; this.phase = 2; this.msg = TG('哪个物件换了格子？点它');
      }, VEIL_MS);
    }, PEEK_MS);
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.toAt],
      TG2('答案是第 {0} 个', String(this.toAt + 1)),
      TG2('The answer is option {0}', String(this.toAt + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.toAt  ｜ 守卫取自它自己的 if (...) { return; }
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    if (this.phase !== 2 || this.pick >= 0) {
      return true;
    }
    this.answer(this.toAt);
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

  private answer(i: number): void {
    if (this.phase !== 2 || this.pick >= 0) { return; }
    this.pick = i;
    if (i === this.toAt || i === this.fromAt) {
      this.right = this.right + 1; this.score = this.score + 100;
      this.msg = i === this.toAt ? '✅ 对！它挪到了这里' : '✅ 对！它从这里挪走了';
    } else {
      this.msg = TG2('❌ 挪走的是 {0}（原本在第 {1} 格）', this.second[this.toAt], (this.fromAt + 1));
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, 950);
  }

  private next(): void {
    if (this.roundNo >= this.diffTotal) {
      this.over = true; this.won = this.right >= NEED;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.roundNo = this.roundNo + 1;
    this.newRound();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'object_displacement', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.roundNo };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
              onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.roundNo + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Grid() {
        ForEach(CELLS, (i: number) => { GridItem() {
        Stack() {
        if (this.phase === 0) {
        Text(this.first[(i)] === '' ? '·' : this.first[(i)]).fontSize(FontSize.xxl)
        } else if (this.phase === 1) {
        Text('❓').fontSize(FontSize.xl)
          .accessibilityLevel('no')
        } else {
        Text(this.second[(i)] === '' ? '·' : this.second[(i)]).fontSize(FontSize.xxl)
        }
        }.width('100%').aspectRatio(1).backgroundColor(this.pick === (i) ? Palette.lime : this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        .onClick(() => { Haptics.tick(); this.answer((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((i)); }); })

        } }, (i: number) => 'od' + i)
      // ★ 2026-10-31 真机：原写死 .height(260)，在 533 高的横屏上占 47~49%，
      //   加上 HintBar 与统计行后底部按钮被切。改成按屏高自适应（上限仍是原值）。
      }.columnsTemplate('1fr 1fr 1fr').rowsGap(Space.sm).columnsGap(Space.sm).width('100%').height(Math.min(260, Bp.height * 0.35))
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：遮罩后只有一个物件换格，点它（点它原来的位置也算对）')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
