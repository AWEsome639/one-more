/** 拼写冲刺 —— 60 秒内看着中文释义把英文单词敲出来｜胜负：答对 ≥8 通关，超时或错满 3 次失败 */
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

const TOTAL: number = 12; const PASS: number = 8; const LIVES: number = 3;
const LIMIT_S: number = 60; const TICK_MS: number = 1000; const GAP_MS: number = 600;

interface SPW { zh: string; w: string }

const BANK: SPW[] = [
  { zh: TG('苹果'), w: 'APPLE' }, { zh: TG('桥'), w: 'BRIDGE' }, { zh: '风暴', w: 'STORM' },
  { zh: '沉默', w: 'SILENCE' }, { zh: '勇气', w: 'COURAGE' }, { zh: '森林', w: 'FOREST' },
  { zh: '窗户', w: 'WINDOW' }, { zh: TG('铅笔'), w: 'PENCIL' }, { zh: '海洋', w: 'OCEAN' },
  { zh: '灯笼', w: 'LANTERN' }, { zh: '友谊', w: 'FRIENDSHIP' }, { zh: '影子', w: 'SHADOW' },
  { zh: '旅程', w: 'JOURNEY' }, { zh: '珍珠', w: 'PEARL' }, { zh: '图书馆', w: 'LIBRARY' },
  { zh: '清晨', w: 'MORNING' }
];

function shufIdx(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSpellingSprint {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
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

  @State plan: number[] = []; @State qi: number = 0; @State right: number = 0;
  @State lives: number = LIVES; @State score: number = 0; @State leftS: number = LIMIT_S;
  @State input: string = ''; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private feed: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSpellingSprint')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private cur(): SPW { return BANK[this.plan[this.qi]]; }

  private reset(): void {
    this.stop();
    this.plan = shufIdx(BANK.length).slice(0, this.diffTotal);
    this.qi = 0; this.right = 0; this.lives = LIVES; this.score = 0;
    this.leftS = LIMIT_S; this.input = '';
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.msg = TG2('拼出「{0}」', this.cur().zh);
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = TG2('⌛ 时间到 —— 答对 {0} / {1}', this.right, this.diffTotal);
      this.finish(this.won);
    }
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
    if (this.feed >= 0) {
      return true;               // 换题间隙
    }
    this.input = this.cur().w;  // 直接把词填进输入框（submit 读的是 this.input）
    this.submit();
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const c: SPW = this.cur();
    return Hint.make([],
      TG2('答案是 {0}（{1}）', c.w, c.zh),
      TG2('The answer is {0}', c.w), t0);
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

  private submit(): void {
    if (this.over) { return; }
    const c: SPW = this.cur();
    const typed: string = this.input.trim().toUpperCase();
    if (typed.length === 0) { return; }
    if (typed === c.w) {
      this.right = this.right + 1; this.score = this.score + 100 + this.leftS;
      this.msg = '✅ ' + c.zh + ' = ' + c.w;
    } else {
      this.lives = this.lives - 1; this.msg = TG2('❌ {0} 应是 {1}', c.zh, c.w);
    }
    this.input = '';
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 错满 3 次 —— 答对 {0} / {1}',Digits(String(this.right), this.langCode),Digits(String(this.diffTotal), this.langCode));
      this.finish(false); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.msg = TG2('拼出「{0}」', this.cur().zh); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.stop();
    const r: GameResult = { gameId: 'spelling_sprint', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.teal))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 看释义拼写')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.over ? TG('本局结束') : this.cur().zh)
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(TG2("首字母 {0} · 共 {1} 个字母", this.cur().w.charAt(0), this.cur().w.length))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入英文单词' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm }).enabled(!this.over)
          .onChange((v: string) => { this.input = v; })
          .onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .onClick(() => { Haptics.tap(); this.submit(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG2("{0} 秒内答对 ≥{1} 通关",Digits(String(LIMIT_S), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
