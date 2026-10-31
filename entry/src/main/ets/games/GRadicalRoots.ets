/** 根式化简 —— √n 化成 a√b｜8 题答对 6 题过关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const TOTAL: number = 8;
const PASS: number = 6;
const A_POOL: number[] = [2, 3, 4, 5, 6, 7, 8, 9];
const B_POOL: number[] = [2, 3, 5, 6, 7, 10, 11, 13, 14, 15];

interface Rad { text: string; value: number }
interface RadQ { q: string; ans: string; opts: string[] }

function makeQ(): RadQ {
  const a: number = A_POOL[Math.floor(Math.random() * A_POOL.length)];
  const b: number = B_POOL[Math.floor(Math.random() * B_POOL.length)];
  const value: number = a * a * b;
  const ans: string = String(a) + '√' + String(b);
  const cands: Rad[] = [
    { text: String(a) + '√' + String(b + 1), value: a * a * (b + 1) },
    { text: String(a + 1) + '√' + String(b), value: (a + 1) * (a + 1) * b },
    { text: String(b) + '√' + String(a), value: b * b * a },
    { text: String(a + 2) + '√' + String(b), value: (a + 2) * (a + 2) * b },
    { text: String(a) + '√' + String(b + 2), value: a * a * (b + 2) }
  ];
  if (a > 2) { cands.push({ text: String(a - 1) + '√' + String(b + 3), value: (a - 1) * (a - 1) * (b + 3) }); }
  const opts: string[] = [ans];
  const vals: number[] = [value];
  for (let i = 0; i < cands.length && opts.length < 4; i++) {
    const cd: Rad = cands[i];
    if (cd.value !== value && vals.indexOf(cd.value) < 0 && opts.indexOf(cd.text) < 0) {
      opts.push(cd.text);
      vals.push(cd.value);
    }
  }
  for (let i = opts.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = opts[i];
    opts[i] = opts[j];
    opts[j] = t;
  }
  return { q: '√' + String(value), ans: ans, opts: opts };
}

@Component
export struct GRadicalRoots {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private q: string = '';
  @State private ans: string = '';
  @State private opts: string[] = [];
  @State private picked: string = '';
  @State private idx: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG('化成最简根式：根号里不能再有平方因子');
  private startAt: number = 0;
  private wait: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GRadicalRoots')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; } }


  /**
   * ★ 2026-10-23 第二期：根式化简提示
   *
   * 提示只做两步：
   *   ① 找出被开方数里**最大的完全平方因子**
   *   ② 说明「可以把它开出来」
   * ⇒ 不直接给答案，玩家自己把外面的倍数算出来。
   *
   * 例：√48 → 48 = 16 × 3，16 = 4² ⇒ 「48 里有 4²=16，可以开成 4√3 的一部分」
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const v: number = Number(this.q.replace('√', ''));
    if (!(v > 0)) {
      return Hint.none('none');
    }
    let sq: number = 1;
    for (let k = 2; k * k <= v; k++) {
      if (v % (k * k) === 0) {
        sq = k;
      }
    }
    if (sq === 1) {
      return Hint.make([],
        TG2('{0} 里没有能开出来的平方因子，它本身已经最简', String(v)),
        TG2('{0} has no square factor — it is already simplest', String(v)), t0);
    }
    const rest: number = v / (sq * sq);
    // ⚠️ 模板最多 4 个占位符（TG4 上限）⇒ 只说「提出几、剩几」，让玩家自己组合
    return Hint.make([],
      TG2('{0} 里有 {1}²，能开出来 —— 外面写 {1}，根号里剩 {2}',
        String(v), String(sq), String(rest)),
      TG2('{0} contains {1}² — take {1} outside, leave {2} under the root',
        String(v), String(sq), String(rest)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private reset(): void {
    this.startAt = Date.now();
    this.idx = 0;
    this.right = 0;
    this.wrong = 0;
    this.score = 0;
    this.over = false;
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
    this.ask();
  }

  private ask(): void {
    const item: RadQ = makeQ();
    this.q = item.q;
    this.ans = item.ans;
    this.opts = item.opts;
    this.picked = '';
    this.tip = TG2("{0} 化成 a√b", item.q);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案 this.ans 是字符串，作答函数的参数也是字符串
  // ★ 守卫 this.picked 也是字符串 ⇒ 判据是 length > 0，不是 >= 0
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
    if (this.picked.length > 0) {
      return true;              // 这题答过了，等下一题
    }
    this.choose(this.ans);
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

  private choose(s: string): void {
    if (this.picked.length > 0 || this.over) { return; }
    this.picked = s;
    if (s === this.ans) {
      this.right++;
      this.score += 12;
      this.tip = '✓ ' + this.q + ' = ' + this.ans;
    } else {
      this.wrong++;
      this.score -= 2;
      this.tip = '✗ ' + this.q + ' = ' + this.ans;
    }
    this.wait = setTimeout(() => { this.next(); }, 850);
  }

  private next(): void {
    this.wait = -1;
    this.idx++;
    if (this.idx >= this.diffTotal) {
      this.over = true;
      this.tip = TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'radical_roots', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(res);
      return;
    }
    this.ask();
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('= ?（最简根式）')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      Row({ space: Space.sm }) {
        ForEach([0, 1], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.choose(this.opts[(i)]); }); }); }, (i: number) => 'a' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        ForEach([2, 3], (i: number) => { Button(this.opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.optInk((i))).backgroundColor(this.optTone((i)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.picked.length === 0 && !this.over)
        .onClick(() => { Haptics.tap(); this.choose(this.opts[(i)]); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.choose(this.opts[(i)]); }); }); }, (i: number) => 'b' + i)
      }.width('100%')
      Row({ space: Space.md }) {
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.amber)
          .borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Text(TG('把 n 拆成 平方数 × 无平方因子数')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }





  private optTone(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0) { return Palette.amber; }
    if (s === this.ans) { return Palette.emerald; }
    if (s === this.picked) { return Palette.danger; }
    return this.theme.surfaceAlt;
  }

  private optInk(i: number): string {
    const s: string = this.opts[i];
    if (this.picked.length === 0 || s === this.ans || s === this.picked) { return '#FFFFFF'; }
    return this.theme.ink;
  }
}
