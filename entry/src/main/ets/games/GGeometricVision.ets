/**
 * 几何直觉 📐
 * 玩法：A、B 两块图形各由 12 个小方格里的若干格拼成，比一比谁占的格子多。
 * 胜负：10 题全过 = 通关；答错 3 题 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const ROUNDS: number = 10;
const LIVES: number = 3;
const CELLS: number = 12;
const COLS: number[] = [0, 1, 2, 3]; const ROWS: number[] = [0, 1, 2];

@Component
export struct GGeometricVision {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private aCells: boolean[] = [];
  @State private bCells: boolean[] = [];
  @State private na: number = 0; @State private nb: number = 0;
  @State private idx: number = 0; @State private score: number = 0; @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private over: boolean = false; @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GGeometricVision')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  /** 12 格里随机点亮 k 格 */
  private scatter(k: number): boolean[] {
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i); }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i]; pool[i] = pool[j]; pool[j] = t;
    }
    const out: boolean[] = [];
    for (let i = 0; i < CELLS; i++) { out.push(false); }
    for (let i = 0; i < k; i++) { out[pool[i]] = true; }
    return out;
  }

  private roll(): void {
    const na: number = 3 + Math.floor(Math.random() * 9);
    let nb: number = 3 + Math.floor(Math.random() * 9);
    while (nb === na) { nb = 3 + Math.floor(Math.random() * 9); }
    this.na = na; this.nb = nb;
    this.aCells = this.scatter(na); this.bCells = this.scatter(nb);
  }

  private reset(): void {
    this.idx = 0; this.score = 0; this.wrong = 0;
    this.over = false; this.won = false; this.note = TG(TG(TG('哪块占的格子多？👀')));
    this.roll();
    this.startAt = Date.now();
  }

  /** pick: 0=A 多 1=B 多 */
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.over) {
      return true;
    }
    this.answer(this.na > this.nb ? 0 : 1);
    return !this.over;
  }

  /** 提示：哪边格子多 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const a: number = this.na;
    const b: number = this.nb;
    const pickA: boolean = a > b;
    return Hint.make([pickA ? 0 : 1], pickA ? TG('选 A 那边') : TG('选 B 那边'),
      pickA ? TG('Pick side A') : TG('Pick side B'), t0);
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

  private answer(pick: number): void {
    if (this.over) { return; }
    const na: number = this.na;
    const nb: number = this.nb;
    const expect: number = na > nb ? 0 : 1;
    if (pick === expect) {
      this.score += 10;
      this.note = TG2('对！A {0} 格、B {1} 格 ✅', na, nb);
    } else {
      this.wrong++; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.note = '错：A ' + na + ' 格、B ' + nb + ' 格（失误 ' + this.wrong + '/' + LIVES + '）';
    }
    this.idx++;
    if (this.wrong >= LIVES) { this.finish(false); return; }
    if (this.idx >= this.diffTotal) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    this.roll();
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.note = solved ? '十道几何判断全过，通关 🎉' : '看走眼三次，这局结束 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({ gameId: 'geometric_vision', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.idx + 1 });
  }

  build() {
    Column({ space: Space.md }) {
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
      Text(TG2("第 {0}/{1} 题　得分 {2}", Math.min(this.idx + 1, this.diffTotal),Digits(String(this.diffTotal), this.langCode),Digits(String(this.score), this.langCode)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          Text(TG('A 图形')).fontSize(FontSize.xxs).fontColor(Palette.emerald)
          this.gridA()
        }.layoutWeight(1)
        Text('VS').fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        Column({ space: Space.xs }) {
          Text(TG('B 图形')).fontSize(FontSize.xxs).fontColor(Palette.sky)
          this.gridB()
        }.layoutWeight(1)
      }.width('100%')
      Text(this.note).fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button(TG('A 更多'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(0); }); }).onClick(() => { Haptics.tap(); this.answer(0); })
        Button(TG('B 更多'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.sky)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(1); }); }).onClick(() => { Haptics.tap(); this.answer(1); })
      }.width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  gridA() {
    Column({ space: 2 }) {
      ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
          ForEach(COLS, (c: number) => { this.blkA(r * 4 + c) }, (c: number) => 'ac' + r + '_' + c)
        }.width('100%')
      }, (r: number) => 'ar' + r)
    }.width('100%')
  }

  @Builder
  gridB() {
    Column({ space: 2 }) {
      ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
          ForEach(COLS, (c: number) => { this.blkB(r * 4 + c) }, (c: number) => 'bc' + r + '_' + c)
        }.width('100%')
      }, (r: number) => 'br' + r)
    }.width('100%')
  }

  @Builder
  blkA(i: number) {
    Text('').layoutWeight(1).aspectRatio(1).backgroundColor(this.aCells[i] ? Palette.emerald : this.theme.surfaceAlt)
      .borderRadius(Radius.xs).borderWidth(1).borderColor(this.theme.line)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  blkB(i: number) {
    Text('').layoutWeight(1).aspectRatio(1).backgroundColor(this.bCells[i] ? Palette.sky : this.theme.surfaceAlt)
      .borderRadius(Radius.xs).borderWidth(1).borderColor(this.theme.line)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }
}
