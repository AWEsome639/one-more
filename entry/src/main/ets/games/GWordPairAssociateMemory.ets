/**
 * 词对记忆 —— 先记住 6 组词对，再看词选搭档
 * 胜负：6 题答对 ≥5 ⇒ 通关｜进度：记忆倒计时 / 题号 / 答对 / 得分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const PAIRS_N: number = 6; const PASS: number = 5; const OPT_N: number = 4;
const STUDY_S: number = 8; const TICK_MS: number = 1000; const FEED_MS: number = 750;

interface WordPair { a: string; b: string }

const BANK: WordPair[] = [
  { a: '太阳', b: '月亮' }, { a: '蜜蜂', b: '花朵' }, { a: '钥匙', b: '锁' }, { a: TG('铅笔'), b: '橡皮' },
  { a: '大海', b: '鲸鱼' }, { a: TG('冬天'), b: '雪花' }, { a: '舞台', b: '演员' }, { a: '厨师', b: '炒锅' },
  { a: TG('电脑'), b: '键盘' }, { a: '雨伞', b: '阵雨' }, { a: '医生', b: '听诊器' }, { a: '森林', b: TG('老虎') },
  { a: '图书馆', b: '书架' }, { a: '足球', b: '球门' }, { a: '咖啡', b: '杯子' }, { a: '相机', b: '镜头' }
];

/** 从 0..total-1 里随机取 k 个互不相同的下标 */
function pickIndexes(total: number, k: number): number[] {
  const out: number[] = [];
  while (out.length < k) {
    const j: number = Math.floor(Math.random() * total);
    if (out.indexOf(j) < 0) { out.push(j); }
  }
  return out;
}
@Component
export struct GWordPairAssociateMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 PAIRS_N=6
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);
  onFinish: (r: GameResult) => void = () => {};

  @State pairs: WordPair[] = []; @State opts: string[] = [];
  @State phase: number = 0; @State leftS: number = STUDY_S;
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State pickedOk: number = -1; @State lastPick: string = ''; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordPairAssociateMemory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  private reset(): void {
    this.stop();
    this.pairs = pickIndexes(BANK.length, this.diffTotal).map((k: number) => BANK[k]);
    this.phase = 0; this.leftS = STUDY_S; this.qIndex = 0; this.right = 0; this.score = 0;
    this.pickedOk = -1; this.lastPick = ''; this.over = false; this.won = false; this.done = false;
    this.msg = TG2("记住这 {0} 组词对", this.diffTotal); this.startAt = Date.now();
    this.timer = setInterval(() => { this.countdown(); }, TICK_MS);
  }
  private countdown(): void {
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) { this.startQuiz(); }
  }
  private startQuiz(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.phase = 1; this.leftS = 0; this.ask();
  }
  /** 3 个别的搭档 + 正确答案塞进随机位置 */
  private ask(): void {
    const p: WordPair = this.pairs[this.qIndex];
    const others: string[] = [];
    while (others.length < OPT_N - 1) {
      const cand: string = this.pairs[Math.floor(Math.random() * this.pairs.length)].b;
      if (cand !== p.b && others.indexOf(cand) < 0) { others.push(cand); }
    }
    others.splice(Math.floor(Math.random() * OPT_N), 0, p.b);
    this.opts = others; this.pickedOk = -1; this.lastPick = '';
    this.msg = TG2('「{0}」的搭档是？', p.a);
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
    if (this.pickedOk >= 0) {
      return true;
    }
    this.pick(this.pairs[this.qIndex].b);
    return !this.over;
  }

  /** 提示：直接报搭档词 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.pickedOk >= 0 || this.over) {
      return Hint.none('none');
    }
    const correct: string = this.pairs[this.qIndex].b;
    return Hint.make([], TG2('它的搭档是「{0}」', correct),
      TG2('Its partner is {0}', correct), t0);
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

  private pick(o: string): void {
    if (this.pickedOk >= 0 || this.over) { return; }
    const correct: string = this.pairs[this.qIndex].b;
    this.lastPick = o;
    if (o === correct) {
      this.pickedOk = 1; this.right = this.right + 1; this.score = this.score + 100; this.msg = TG('✅ 记住了');
    } else {
      this.pickedOk = 0; this.msg = TG2('❌ 它的搭档是「{0}」', correct);
    }
    this.feed = setTimeout(() => { this.feed = -1; this.advance(); }, FEED_MS);
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= this.diffTotal) {
      this.phase = 2; this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won);
      return;
    }
    this.ask();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'word_pair_associate_memory', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private bar(): string {
    const stage: string = this.phase === 0 ? '记忆 ' + this.leftS + 's'
      : (this.phase === 1 ? '回忆 ' + Math.min(this.qIndex + 1, this.diffTotal) + '/' + this.diffTotal : TG('结束'));
    return TG2("{0}　答对 {1}　得分 {2}", stage,Digits(String(this.right), this.langCode),Digits(String(this.score), this.langCode));
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
      Text(this.bar()).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      if (this.phase === 0) {
        ForEach(this.pairs, (p: WordPair) => { this.pairRow(p) }, (p: WordPair) => p.a)
      } else if (this.phase === 1) {
        Text(TG2('「{0}」的搭档是？', this.pairs[this.qIndex].a)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
        ForEach(this.opts, (o: string) => { this.optBtn(o) }, (o: string) => o)
      }
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  pairRow(p: WordPair) {
    Row({ space: Space.sm }) {
      Text(p.a).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1).textAlign(TextAlign.End)
      Text('↔').accessibilityText(TG('对应')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        .accessibilityLevel('no')
      Text(p.b).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Palette.violet).layoutWeight(1)
    }.width('100%').padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
  }
  @Builder
  optBtn(o: string) {
    Button(o)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
      .backgroundColor(this.tone(o)).borderRadius(Radius.md).width('100%').height(Cell.of(48))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tap(); this.pick(o); })
  }
  private tone(o: string): string {
    if (this.pickedOk < 0 || this.qIndex >= this.diffTotal) { return Palette.violet; }
    return o === this.pairs[this.qIndex].b ? Palette.emerald
      : (o === this.lastPick ? Palette.rose : Palette.violet);
  }
}
