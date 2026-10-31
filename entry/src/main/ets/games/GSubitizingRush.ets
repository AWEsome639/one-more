/**
 * 数量直觉 —— 一团圆点只亮 420 ms，来不及数，只能"一眼看出"有几个
 * 胜负：10 题答对 ≥8 题通关
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 3;
const CELLS: number = N * N;
const ROUNDS: number = 10;
const SHOW_MS: number = 420;

const LEVELS: number[] = [2, 3, 4, 5, 5, 6, 6, 7, 8, 9];

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GSubitizingRush {
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

  @State private dots: number[] = [];
  @State private cnt: number = 0;
  @State private shown: boolean = true;   // 圆点是否还亮着
  @State private round: number = 1;
  @State private right: number = 0;
  @State private best: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private hideTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSubitizingRush')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.dots = []; this.cnt = 0; this.shown = true; this.round = 1; this.right = 0;
    this.best = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }

  /** 随机撒 n 个点，亮 420 ms 就收起 */
  private newTrial(): void {
    const n: number = LEVELS[(this.round - 1) % LEVELS.length];
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i); }
    const out: number[] = [];
    for (let i = 0; i < n; i++) {
      const j: number = Math.floor(Math.random() * pool.length);
      out.push(pool[j]);
      pool.splice(j, 1);
    }
    this.dots = out;
    this.cnt = n;
    this.shown = true;
    this.pick = -1;
    this.msg = TG(TG(TG('一眼看出有几个点')));
    this.hideTo = setTimeout(() => {
      this.hideTo = -1;
      this.shown = false;
      this.msg = TG(TG(TG('刚才有几个点？')));
    }, SHOW_MS);
  }

  /** 三个选项：正确答案 + 两个邻近数 */
  private option(k: number): number {
    const offs: number[] = [0, -1, 2];
    let v: number = this.cnt + offs[k];
    if (v < 2) { v = this.cnt + 1; }
    if (v > 9) { v = this.cnt - 2; }
    return v;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.pick >= 0 || this.shown) {
      return true;
    }
    this.answer(this.cnt);
    return !this.over;
  }

  /** 提示：直接报个数 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.pick >= 0 || this.shown) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('一共 {0} 个', String(this.cnt)),
      TG2('There are {0} items', String(this.cnt)), t0);
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

  private answer(v: number): void {
    if (this.over || this.pick >= 0 || this.shown) { return; }
    const truth: number = this.cnt;
    this.pick = v;
    if (v === truth) {
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ 就是 ' + String(truth) + TG(' 个');
    } else {
      this.msg = '❌ 其实是 ' + String(truth) + TG(' 个');
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 680);
  }

  private advance(): void {
    if (this.round >= this.diffTotal) {
      const win: boolean = this.right >= 8;
      this.over = true; this.won = win;
      if (this.right > this.best) { this.best = this.right; }
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'subitizing_rush', solved: win,
        score: this.right * 110 + (win ? 200 : 0),
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.newTrial();
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
        Text(TG2("题号 {0}/{1}", String(this.round), String(this.diffTotal))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.right)).fontSize(FontSize.sm).fontColor(Palette.violet)
        Text(TG2('最佳 {0}', this.best > 0 ? String(this.best) : '—')).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              this.cellView(r * N + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.pick >= 0 ? Palette.violet : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        this.optBtn(0)
        this.optBtn(1)
        this.optBtn(2)
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：10 题答对 ≥ 8 题；≤ 4 个靠直觉，≥ 5 个得靠分组'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.shown && has(this.dots, i) ? '●' : '')
        .fontSize(FontSize.xxl).fontColor(Palette.violet)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
  }

  @Builder
  optBtn(k: number) {
    Button(String(this.option(k)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
      .fontSize(FontSize.xl).fontColor('#FFFFFF')
      .backgroundColor(this.pick === this.option(k) ? Palette.primaryDeep : Palette.violet)
      .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
      .opacity(this.shown ? 0.45 : 1)
      .scale({ x: this.pick === this.option(k) ? Motion.pressScale : 1, y: this.pick === this.option(k) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tap(); this.answer(this.option(k)); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(this.option(k)); }); })
  }
}
