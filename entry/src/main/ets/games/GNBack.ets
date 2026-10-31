/** N-back —— 每步判断当前字母与 2 步前那个是否相同；12 试次答对 ≥9 通关 */
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const BACK: number = 2;
const TRIALS: number = 12;
const PASS: number = 9;
const WARM_MS: number = 1100;
const LETTERS: string[] = ['B', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'P', 'R', 'T'];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

@Component
export struct GNBack {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private seq: string[] = [];
  @State private idx: number = 0;
  @State private marks: number[] = [];   // 1 对 / 0 错
  @State private right: number = 0;
  @State private pick: number = -1;      // -1 未答 / 0 不一样 / 1 一样
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private waitTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GNBack')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.waitTo >= 0) { clearTimeout(this.waitTo); this.waitTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    const out: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      if (i >= BACK && Math.random() < 0.34) { out.push(out[i - BACK]); continue; }
      let c: string = LETTERS[Math.floor(Math.random() * LETTERS.length)];
      let guard: number = 0;
      while (i >= BACK && c === out[i - BACK] && guard < 30) {
        c = LETTERS[Math.floor(Math.random() * LETTERS.length)];
        guard = guard + 1;
      }
      out.push(c);
    }
    this.seq = out;
    this.idx = 0; this.marks = []; this.right = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.enter();
  }

  private warm(): boolean { return this.idx < BACK; }

  /** 进入当前试次：热身的两步自动过，之后等作答 */
  private enter(): void {
    if (this.warm()) {
      this.msg = TG2('先记住它（第 {0}/{1} 个热身）', String(this.idx + 1), String(BACK));
      this.waitTo = setTimeout(() => { this.waitTo = -1; this.advance(); }, WARM_MS);
      return;
    }
    this.msg = TG2('与 {0} 步前那个一样吗？',Digits(String(BACK), this.langCode));
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
    if (this.warm() || this.pick >= 0) {
      return true;
    }
    this.answer(this.seq[this.idx] === this.seq[this.idx - BACK]);
    return !this.over;
  }

  /** 提示：直接说是/否 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.warm() || this.pick >= 0) {
      return Hint.none('none');
    }
    const truth: boolean = this.seq[this.idx] === this.seq[this.idx - BACK];
    return Hint.make([],
      truth ? TG('一样') : TG('不一样'),
      truth ? TG('Same') : TG('Different'), t0);
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

  private answer(same: boolean): void {
    if (this.over || this.warm() || this.pick >= 0) { return; }
    const truth: boolean = this.seq[this.idx] === this.seq[this.idx - BACK];
    const hit: boolean = same === truth;
    this.pick = same ? 1 : 0;
    const marks: number[] = this.marks.slice();
    marks.push(hit ? 1 : 0);
    this.marks = marks;
    if (hit) { this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG('✅ 答对了'); }
    else { this.msg = truth ? '❌ 它们其实一样' : '❌ 它们其实不一样'; }
    this.waitTo = setTimeout(() => { this.waitTo = -1; this.advance(); }, 720);
  }

  private advance(): void {
    if (this.over) { return; }
    if (this.idx + 1 < this.diffTotal) {
      this.idx = this.idx + 1;
      this.pick = -1;
      this.enter();
      return;
    }
    this.over = true;
    this.won = this.right >= PASS;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) + String(this.right) + '/' + String(this.diffTotal);
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'n_back', solved: solved, score: this.right * 100, durationMs: Date.now() - this.startAt, levelReached: BACK };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private rate(): string {
    if (this.marks.length === 0) { return '—'; }
    return String(Math.round(this.right * 100 / this.marks.length)) + '%';
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
      Row() {
        Text(TG2('试次 {0}', (String(this.idx + 1) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2("答对 {0}", String(this.right))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2('正确率 {0}', (this.rate()))).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Row({ space: Space.xs }) {
        ForEach(SLOTS, (k: number) => { this.dotView(k) }, (k: number) => 't' + k)
      }.width('100%').justifyContent(FlexAlign.Center)

      Stack() {
        Text(this.seq.length > 0 ? this.seq[this.idx] : '·')
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }
      .width('100%').layoutWeight(1).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) { this.ansBtn(TG('不一样'), false); this.ansBtn(TG('一样'), true) }.width('100%')

      
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：前 2 个字母只是热身，从第 3 个起才计分'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /** 逐题小点：热身两点固定暗灰；已答的按对错上色；当前题高亮 */
  @Builder
  dotView(k: number) {
    Text(k < BACK ? '·' : (this.marks.length > k - BACK ? (this.marks[k - BACK] === 1 ? '●' : '✕') : (k === this.idx ? '◉' : '·')))
      .fontSize(FontSize.xxs)
      .fontColor(k < BACK ? this.theme.inkFaint
        : (this.marks.length > k - BACK
          ? (this.marks[k - BACK] === 1 ? Palette.emerald : Palette.rose)
          : (k === this.idx ? Palette.amber : this.theme.inkFaint)))
      .textAlign(TextAlign.Center).layoutWeight(1).height(22)
  }
  @Builder
  ansBtn(label: string, same: boolean) {
    Text(label).fontSize(FontSize.md).fontColor('#FFFFFF').textAlign(TextAlign.Center)
      .layoutWeight(1).height(Cell.of(52)).backgroundColor(same ? Palette.amber : Palette.inkSoft).borderRadius(Radius.md)
      .opacity(!this.warm() && this.pick < 0 && !this.over ? 1 : 0.4).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer(same); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer(same); }); })
  }
}
