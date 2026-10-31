/**
 * 视角切换 📐
 * 规则：给一张俯视图与一个观察方向，选出「从那一侧看过去」的排列。
 * 胜负：8 题答对 ≥6 ⇒ 通关；否则失败。　进度：第几题 / 已答对
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
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

const N: number = 3; const TOTAL: number = 8; const NEED: number = 6;
const IDXN: number[] = [0, 1, 2];
const LETTERS: string[] = ['A', 'B', 'C'];
const COLORS: string[] = [Palette.primary, Palette.berry, Palette.emerald, Palette.amber, Palette.sky, Palette.violet];
const DIRS: string[] = [TG('北 ⬆️'), TG('东 ➡️'), TG('南 ⬇️'), TG('西 ⬅️')];
/** 方向 → 顺时针转几次，近边才落到视图下方 */
const ROTS: number[] = [2, 1, 0, 3];

/**
 * 把地图顺时针转 times 次。
 *
 * ★★★ 2026-10-23 修：原来全部用模块常量 N（=3），
 *   但难度会改棋盘边长（简单 ×0.7→2 / 普通 3 / 困难 ×1.3→4）。
 *   渲染按 diffTotal，旋转却按 3 ⇒ 3 以外的尺寸下旋转矩阵全错位。
 *   ⇒ 把边长当参数传进来。
 */
function spin(map: string[], times: number, n: number): string[] {
  let cur: string[] = map.slice();
  for (let t = 0; t < times % 4; t++) {
    const next: string[] = new Array<string>(n * n).fill('');
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        next[c * n + (n - 1 - r)] = cur[r * n + c];
      }
    }
    cur = next;
  }
  return cur;
}
function sameMap(a: string[], b: string[]): boolean {
  for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } }
  return true;
}

@Component
export struct GPerspectiveShiftView {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(3);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private base: string[] = []; @State private opts: string[][] = [];
  @State private dir: number = 0; @State private answer: number = 0;
  @State private q: number = 1; @State private correct: number = 0; @State private chosen: number = -1;
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0; private delay: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPerspectiveShiftView')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  aboutToDisappear(): void { this.halt(); }
  private halt(): void {
    if (this.delay >= 0) { clearTimeout(this.delay); this.delay = -1; }
  }
  private reset(): void {
    this.halt(); this.q = 1; this.correct = 0; this.chosen = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.question();
    this.msg = TG(TG(TG('看清俯视图，再想想从那一侧看会是什么样')));
  }
  /** 随机摆 4 个色块 + 随机方向；三个选项必须是三张互不相同的图，否则重来 */
  private question(): void {
    let done: boolean = false;
    while (!done) {
      const b: string[] = new Array<string>(this.diffTotal * this.diffTotal).fill('');
      const used: number[] = [];
      for (let k = 0; k < 4; k++) {
        let i: number = Math.floor(Math.random() * this.diffTotal * this.diffTotal);
        while (used.indexOf(i) >= 0) { i = Math.floor(Math.random() * this.diffTotal * this.diffTotal); }
        used.push(i); b[i] = COLORS[k];
      }
      const way: number = Math.floor(Math.random() * 4);
      const right: string[] = spin(b, ROTS[way], this.diffTotal);
      const opts: string[][] = [right, spin(b, (ROTS[way] + 1) % 4, this.diffTotal), spin(b, (ROTS[way] + 2) % 4, this.diffTotal)];
      if (sameMap(opts[0], opts[1]) || sameMap(opts[0], opts[2]) || sameMap(opts[1], opts[2])) { continue; }
      for (let k = 2; k > 0; k--) {
        const j: number = Math.floor(Math.random() * (k + 1));
        const t: string[] = opts[k]; opts[k] = opts[j]; opts[j] = t;
      }
      let ans: number = 0;
      for (let k = 0; k < 3; k++) { if (sameMap(opts[k], right)) { ans = k; } }
      this.base = b; this.dir = way; this.opts = opts; this.answer = ans;
      done = true;
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  /** 提示：报答案（字段 this.dir） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.answer],
      TG2('答案是第 {0} 个', String(this.answer + 1)),
      TG2('The answer is option {0}', String(this.answer + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
    // ★ 关键：choose() 答完会等 1000ms 才 next()。
    //   如果这里每拍都重置 chosen 再作答，1 秒内会被调用 3 次
    //   ⇒ 每题多加几次 correct、排多个 next() ⇒ 题目被跳过、计数错乱。
    //   ⇒ 答过的这一轮什么都不做，只等 next()。
    if (this.chosen >= 0) {
      return true;
    }
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

  private choose(k: number): void {
    if (k < 0 || this.over || this.chosen >= 0) { return; }
    this.chosen = k;
    if (k === this.answer) { this.correct = this.correct + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); }
    this.msg = k === this.answer ? '✅ 就是这个视角' : '❌ 正确答案已标绿';
    this.halt();
    this.delay = setTimeout(() => { this.delay = -1; this.next(); }, 1000);
  }
  private next(): void {
    if (this.q >= TOTAL) { this.finish(); return; }
    this.q = this.q + 1; this.chosen = -1;
    this.question();
    this.msg = '继续：第 ' + String(this.q) + TG(' 题');
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.halt();
    const solved: boolean = this.correct >= NEED;
    const raw: number = this.correct * 60 - (TOTAL - this.correct) * 20;
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 视角全对！' : TG2("本局答对 {0}/{1} 题",Digits(String(this.correct), this.langCode), String(TOTAL));
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'perspective_shift_view', solved: solved, score: raw > 0 ? raw : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.correct
    });
  }
  /** kind < 0 = 俯视图本体（不可点），0/1/2 = 选项 */
  private colorAt(kind: number, i: number): string {
    if (kind < 0) { return this.base[i] === '' ? this.theme.surfaceAlt : this.base[i]; }
    if (this.opts.length <= kind) { return this.theme.surfaceAlt; }
    const m: string = this.opts[kind][i];
    return m === '' ? this.theme.surfaceAlt : m;
  }
  private borderOf(kind: number): string {
    if (kind < 0) { return this.theme.line; }
    if (this.chosen < 0) { return this.theme.line; }
    if (kind === this.answer) { return Palette.emerald; }
    if (kind === this.chosen) { return Palette.rose; }
    return this.theme.line;
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
      Text(TG('第 ') + String(this.q) + '/' + String(TOTAL) + ' 题 · 答对 ' + String(this.correct)
        + ' · 需要 ' + String(NEED) + TG(' 题'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
          Text(TG('俯视图')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
          this.mini(-1)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(TG('观察方向')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
          Text(DIRS[this.dir]).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.berry)
          Text(TG(TG('站在这一侧看过去，看到的是哪一张？'))).fontSize(FontSize.xs).fontColor(this.theme.inkSoft)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(this.rowIdx(), (k: number) => {
          Column({ space: Space.xs }) {
            Text(LETTERS[k]).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
            this.mini(k)
          }.layoutWeight(1)
        }, (k: number) => 'opt' + k)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
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
  @Builder
  mini(kind: number) {
    Column({ space: 2 }) {
      ForEach(this.rowIdx(), (r: number) => {
        Row({ space: 2 }) {
          ForEach(this.rowIdx(), (c: number) => {
            Text('').layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.colorAt(kind, r * this.diffTotal + c)).borderRadius(Radius.xs)
          }, (c: number) => 'c' + c)
        }.width('100%')
      }, (r: number) => 'r' + r)
    }.width('100%').aspectRatio(1).padding(Space.xs)
    // ★ 2026-10-31 真机：宽驱动 aspectRatio 无上限 ⇒ 矮屏（横屏 533）棋盘撑爆、下方按钮在窗外。
    .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
    .backgroundColor(this.theme.surface).borderRadius(Radius.md)
    .borderWidth(2).borderColor(this.borderOf(kind))
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.choose(kind); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.choose(kind); }); })
  }
}
