/**
 * 正交剪影 📐（id: silhouette_match_ortho）
 * 三层 3×3 方块叠在一起，从正上方看（正投影）得到哪个剪影？——「有方块就算」。
 * 胜负：6 题答对 ≥4 ⇒ 通关；进度：题号 / 答对。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const M: number = 3; const CELLS: number = M * M; const LAYERS: number = 3;
const ROUNDS: number = 6; const NEED: number = 4;
const ROWS: number[] = [0, 1, 2]; const LAYER_IDX: number[] = [0, 1, 2];
const LAYER_NAMES: string[] = [TG('1层 底'), TG('2层'), TG('3层 顶')];

function sig(a: number[]): string { return a.join(''); }

@Component
export struct GSilhouetteMatchOrtho {
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
  @State layers: number[][] = []; @State opts: number[][] = []; @State answerAt: number = 0;
  @State asked: number = 0; @State hits: number = 0; @State picked: number = -1;
  @State over: boolean = false; @State won: boolean = false; @State note: string = '';
  private startAt: number = 0; private done: boolean = false; private nextTimer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSilhouetteMatchOrtho')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stopTimer(); }
  private stopTimer(): void { if (this.nextTimer >= 0) { clearTimeout(this.nextTimer); this.nextTimer = -1; } }
  private reset(): void {
    this.stopTimer(); this.asked = 0; this.hits = 0; this.picked = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    const ls: number[][] = [[1, 0, 0, 0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0, 0, 1, 0], [0, 0, 1, 1, 0, 0, 1, 0, 0]];
    const uni: number[] = [1, 1, 1, 1, 1, 0, 1, 1, 0];
    this.layers = ls; this.opts = [uni, ls[0], ls[1], ls[2]]; this.answerAt = 0;
    this.note = TG('把三层压在一起，就是俯视剪影');
    this.newRound();
  }
  private newRound(): void {
    for (let attempt = 0; attempt < 90; attempt++) {
      const ls: number[][] = [];
      for (let l = 0; l < LAYERS; l++) {
        const g: number[] = new Array<number>(CELLS).fill(0);
        const n: number = 2 + Math.floor(Math.random() * 3);
        for (let i = 0; i < n; i++) { g[Math.floor(Math.random() * CELLS)] = 1; }
        ls.push(g);
      }
      const uni: number[] = new Array<number>(CELLS).fill(0); let filled: number = 0;
      for (let i = 0; i < CELLS; i++) {
        if (ls[0][i] === 1 || ls[1][i] === 1 || ls[2][i] === 1) { uni[i] = 1; filled++; }
      }
      const su: string = sig(uni);
      if (filled < 4) { continue; }                                        // 太稀疏不好看
      if (sig(ls[0]) === su || sig(ls[1]) === su || sig(ls[2]) === su) { continue; }  // 一层就看穿 ⇒ 换题
      if (sig(ls[0]) === sig(ls[1]) || sig(ls[1]) === sig(ls[2]) || sig(ls[0]) === sig(ls[2])) { continue; }
      // 一正三误：正确投影 + 三层各自的样子（经典错误：只盯着一层看）
      const list: number[][] = [uni, ls[0], ls[1], ls[2]];
      const shift: number = Math.floor(Math.random() * 4);
      const opts: number[][] = [list[shift], list[(shift + 1) % 4], list[(shift + 2) % 4], list[(shift + 3) % 4]];
      let ans: number = 0;
      for (let i = 0; i < 4; i++) { if (opts[i] === uni) { ans = i; } }
      this.layers = ls; this.opts = opts; this.answerAt = ans; this.picked = -1;
      this.note = TG('三层压在一起，俯视剪影是哪个？');
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
    if (i === this.answerAt) { this.hits++; this.note = TG('✅ 投影就是这个'); }
    else { this.note = TG('❌ 漏层或多算了，绿框才对'); }
    this.stopTimer();
    this.nextTimer = setTimeout(() => {
      this.nextTimer = -1;
      if (this.asked >= this.diffTotal) { this.finish(this.hits >= NEED); return; }
      this.newRound();
    }, 900);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.stopTimer();
    const res: GameResult = { gameId: 'silhouette_match_ortho', solved: solved, score: this.hits * 15, durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }
  /** mode < 0 ⇒ 单层方块（青）；mode ≥ 0 ⇒ 第 mode 个剪影选项 */
  private cellColor(cells: number[], mode: number, i: number): string {
    if (cells.length <= i || cells[i] !== 1) { return this.theme.surfaceAlt; }
    if (mode < 0) { return Palette.cyan; }
    return this.picked >= 0 && mode === this.answerAt ? Palette.emerald : (this.theme.isDark ? '#E2E8F0' : '#334155');
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
      Text(TG2("题号 {0}/{1}", Math.min(this.asked + 1, this.diffTotal), this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: Space.sm }) {
        ForEach(LAYER_IDX, (l: number) => {
          Column({ space: 2 }) {
            Column() { Column({ space: 2 }) {
            ForEach(ROWS, (r: number) => {
            Row({ space: 2 }) {
            ForEach(ROWS, (c: number) => {
            Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
            .backgroundColor(this.cellColor((this.layers[l]), (-1), r * M + c))
            }, (c: number) => 'gc' + c)
            }.width('100%')
            }, (r: number) => 'gr' + r)
            }.width('100%') }.width('74%')
            Text(LAYER_NAMES[l]).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.xs)
            .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        }, (l: number) => 'ly' + l)
      }.width('100%')
      Text(this.note).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(0)]), ((0)), r * M + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('64%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((0) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((0)); }); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(1)]), ((1)), r * M + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('64%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((1) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((1)); }); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(2)]), ((2)), r * M + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('64%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((2) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((2)); }); })
        Column({ space: 2 }) {
        Column() { Column({ space: 2 }) {
        ForEach(ROWS, (r: number) => {
        Row({ space: 2 }) {
        ForEach(ROWS, (c: number) => {
        Stack().layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
        .backgroundColor(this.cellColor((this.opts[(3)]), ((3)), r * M + c))
        }, (c: number) => 'gc' + c)
        }.width('100%')
        }, (r: number) => 'gr' + r)
        }.width('100%') }.width('64%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .borderWidth(this.picked >= 0 || this.over ? 3 : 1)
        .borderColor(this.picked >= 0 || this.over
        ? ((3) === this.answerAt ? Palette.emerald : Palette.rose) : this.theme.line)
        .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((3)); }); })
      }.width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
