/**
 * 双编码 —— 词与图一起记（言语 + 视觉两条通道），再按词找图
 *
 * 胜负：6 题答对 5 题以上 ⇒ 通关
 * 进度：记忆倒计时 / 题号 / 答对数
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
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';
const KEEP: number = 6;      // 要记的词图对
const NEED: number = 5; const SECONDS: number = 8;
interface Pair {
  word: string;
  icon: string;
}
const PAIRS: Pair[] = [
  { word: TG('苹果'), icon: '🍎' }, { word: '汽车', icon: '🚗' },
  { word: '火箭', icon: '🚀' }, { word: '小猫', icon: '🐱' },
  { word: '雨伞', icon: '☂️' }, { word: '钢琴', icon: '🎹' },
  { word: '相机', icon: '📷' }, { word: '闹钟', icon: '⏰' },
  { word: '足球', icon: '⚽' }, { word: '蛋糕', icon: '🍰' },
  { word: '灯泡', icon: '💡' }, { word: '钥匙', icon: '🔑' }
];
@Component
export struct GDualCoding {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private pairs: Pair[] = [];
  @State private quiz: Pair[] = [];
  @State private phase: number = 0;        // 0 记忆 1 答题
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SECONDS);
  @State private left: number = 0;
  @State private qNo: number = 0;
  @State private right: number = 0;
  @State private opts: string[] = [];
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private timer: number = -1;
  private to1: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDualCoding')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(SECONDS);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
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
    if (this.phase !== 1 || this.pick >= 0) {
      return true;
    }
    this.answer(this.aiOpt());
    return !this.over;
  }

  /** 提示：这个词配哪张图 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase !== 1) {
      return Hint.make([], TG2('先记住这 {0} 组词和图', String(this.pairs.length)),
        TG2('Memorise these {0} word-picture pairs first', String(this.pairs.length)), t0);
    }
    const ic: string = this.quiz[this.qNo].icon;
    return Hint.make([this.opts.indexOf(ic)], TG2('答案是 {0}', ic),
      TG2('The answer is {0}', ic), t0);
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

  private reset(): void {
    this.stop();
    const bag: Pair[] = PAIRS.slice(); const kept: Pair[] = [];
    while (kept.length < KEEP) {
      kept.push(bag.splice(Math.floor(Math.random() * bag.length), 1)[0]);
    }
    const order: Pair[] = kept.slice(); const mixed: Pair[] = [];
    while (order.length > 0) {
      mixed.push(order.splice(Math.floor(Math.random() * order.length), 1)[0]);
    }
    this.pairs = kept; this.quiz = mixed; this.phase = 0; this.left = this.total; this.qNo = 0;
    this.right = 0; this.pick = -1; this.opts = []; this.over = false; this.won = false;
    this.done = false; this.msg = TG('看图记词，两条通道一起用'); this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.phase !== 0) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) { this.startQuiz(); }
    }, 1000);
  }
  private startQuiz(): void {
    this.stop(); this.phase = 1; this.qNo = 0; this.pick = -1; this.buildOpts();
  }
  private buildOpts(): void {
    const target: Pair = this.quiz[this.qNo]; const others: string[] = [];
    for (let i = 0; i < this.pairs.length; i++) {
      if (this.pairs[i].icon !== target.icon) { others.push(this.pairs[i].icon); }
    }
    const list: string[] = [target.icon];
    while (list.length < 4 && others.length > 0) {
      list.push(others.splice(Math.floor(Math.random() * others.length), 1)[0]);
    }
    const mixed: string[] = [];
    while (list.length > 0) {
      mixed.push(list.splice(Math.floor(Math.random() * list.length), 1)[0]);
    }
    this.opts = mixed; this.msg = TG2("第 {0} 题：这个词配哪张图？", String(this.qNo + 1));
  }
  private answer(i: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i] === this.quiz[this.qNo].icon) {
      this.right = this.right + 1; this.msg = TG('✅ 对！');
    } else {
      this.msg = TG2("❌ 应该是 {0}", this.quiz[this.qNo].icon);
    }
    this.to1 = setTimeout(() => {
      this.to1 = -1;
      if (this.qNo >= this.quiz.length - 1) {
        this.finish();
        return;
      }
      this.qNo = this.qNo + 1; this.pick = -1; this.buildOpts();
    }, 850);
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG('答对 ') + String(this.right) + '/' + String(KEEP);
    const r: GameResult = {
      gameId: 'dual_coding', solved: this.won,
      score: this.right * 150, durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  /** AI 用：当前词对应的那张图，在 opts 里的下标 */
  private aiOpt(): number {
    const ic: string = this.quiz[this.qNo].icon;
    return this.opts.indexOf(ic);
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
        Column({ space: 2 }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? TG('记忆') : '答题')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((this.phase === 0 ? '倒计时' : TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? String(this.left) + 's' : String(this.qNo + 1) + '/' + String(KEEP))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      if (this.phase === 0) {
        Column({ space: Space.sm }) {
          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1], (c: number) => {
                Column({ space: 2 }) {
                Text((r * 2 + c) < this.pairs.length ? this.pairs[(r * 2 + c)].icon : '').fontSize(FontSize.xxl)
                Text((r * 2 + c) < this.pairs.length ? this.pairs[(r * 2 + c)].word : '').fontSize(FontSize.xs).fontColor(this.theme.inkSoft)
                }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'mc' + c)
            }.width('100%')
          }, (r: number) => 'mr' + r)
        }.width('100%')
      } else {
        Column({ space: Space.sm }) {
          Text(this.quiz.length > 0 ? this.quiz[this.qNo].word : '').fontSize(FontSize.xxl)
            .fontWeight(FontWeight.Bold).fontColor(Palette.cyan).textAlign(TextAlign.Center).width('100%')
            .height(Cell.of(56)).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
          ForEach([0, 1], (r: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1], (c: number) => {
                Text((r * 2 + c) < this.opts.length ? this.opts[(r * 2 + c)] : '·').fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
                .backgroundColor(this.pick === (r * 2 + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
                .borderRadius(Radius.md).opacity(this.pick >= 0 && this.pick !== (r * 2 + c) ? 0.5 : 1)
                .scale({ x: this.pick === (r * 2 + c) ? Motion.pressScale : 1, y: this.pick === (r * 2 + c) ? Motion.pressScale : 1 })
                .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((r * 2 + c)); }); }).onClick(() => { Haptics.tick(); this.answer((r * 2 + c)); })
              }, (c: number) => 'qc' + c)
            }.width('100%')
          }, (r: number) => 'qr' + r)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        if (this.phase === 0) {
          Button(TG('我记住了 ▶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.cyan)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.startQuiz(); }); }).onClick(() => { Haptics.tap(); this.startQuiz(); })
        }
        Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.phase === 0 ? '#FFFFFF' : this.theme.ink)
          .backgroundColor(this.phase === 0 ? Palette.primary : this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
