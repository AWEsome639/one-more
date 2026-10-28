/**
 * 逻辑三段论 —— 看两个前提和一个结论，判断这个推理站不站得住
 * 胜负：6 题答对 ≥4 ⇒ 通关｜进度：题号 / 答对 / 每题倒计时
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell, Motion } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const QN: number = 6;
const PASS: number = 4;
const LIMIT_MS: number = 18000;
const TICK_MS: number = 100;
const FEED_MS: number = 1100;

/** 题库：valid 是逻辑学上「结论必然成立」的判据，why 给一句人话解释 */
interface Syl { p1: string; p2: string; concl: string; valid: boolean; why: string }

const BANK: Syl[] = [
  { p1: '所有金属都导电。', p2: '铜是金属。', concl: '所以铜导电。', valid: true,
    why: '肯定前件（第一格），有效。' },
  { p1: '所有诗人都是浪漫的人。', p2: '李白是浪漫的人。', concl: '所以李白是诗人。', valid: false,
    why: '「浪漫的人」范围更大，倒推不回去（中项不周延）。' },
  { p1: '有些医生是作家。', p2: '所有作家都喜欢旅行。', concl: '所以有些医生喜欢旅行。', valid: true,
    why: '交集里的那些作家既是医生也爱旅行。' },
  { p1: '如果下雨，操场就湿。', p2: '操场湿了。', concl: '所以下过雨。', valid: false,
    why: '肯定后件无效 —— 洒水车也能把操场弄湿。' },
  { p1: '所有鲸都是哺乳动物。', p2: '没有哺乳动物是鱼。', concl: '所以没有鲸是鱼。', valid: true,
    why: '两个「所有」串联，鲸被排除在鱼之外。' },
  { p1: '有些学生没交作业。', p2: '交了作业的人都能进考场。', concl: '所以有些学生不能进考场。', valid: false,
    why: '「没交作业」与「不能进考场」之间，前提没给规则。' },
  { p1: '所有正方形都是矩形。', p2: '所有矩形都是四边形。', concl: '所以所有正方形都是四边形。', valid: true,
    why: '包含关系可传递：正方形 ⊂ 矩形 ⊂ 四边形。' },
  { p1: '参加会议的人都戴了胸牌。', p2: '小李戴了胸牌。', concl: '所以小李参加了会议。', valid: false,
    why: '戴胸牌的可能是工作人员，推不出他参会。' }
];

@Component
export struct GLogicalSyllogisms {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PASS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(PASS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State order: number[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State leftMs: number = LIMIT_MS; @State feedback: string = ''; @State answered: boolean = false;
  @State over: boolean = false; @State won: boolean = false;
  @State private k: number = 1;
  private startAt: number = 0; private roundAt: number = 0;
  private timer: number = -1; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GLogicalSyllogisms')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PASS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }

  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */

  private bumpK(): void {

    this.k = 1.16;

    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });

  }


  private reset(): void {
    this.stop();
    const ord: number[] = [];
    while (ord.length < QN) {
      const j: number = Math.floor(Math.random() * BANK.length);
      if (ord.indexOf(j) < 0) { ord.push(j); }
    }
    this.order = ord; this.qIndex = 0; this.right = 0; this.score = 0;
    this.feedback = ''; this.answered = false;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.roundAt = Date.now(); this.leftMs = LIMIT_MS;
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private cur(): Syl {
    const qi: number = this.qIndex < QN ? this.qIndex : 0;
    const k: number = this.order.length > qi ? this.order[qi] : 0;
    return BANK[k >= 0 ? k : 0];
  }

  private tick(): void {
    if (this.over || this.answered) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= LIMIT_MS ? 0 : LIMIT_MS - gap;
    if (gap >= LIMIT_MS) { this.judge(false, TG('⌛ 超时，未作答')); }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    if (this.answered) {
      return true;
    }
    this.judge(this.cur().valid, '');
    return !this.over;
  }

  /** 提示：论点是否成立 + 一句人话解释（this.cur().valid 就是判据） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.answered) {
      return Hint.none('none');
    }
    const q: Syl = this.cur();
    const head: string = q.valid ? TG('推理有效') : TG('推理无效');
    return Hint.make([], TG2('{0}：{1}', head, q.why),
      TG2('{0} — {1}', head, q.why), t0);
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

  private judge(pickedValid: boolean, timeoutMsg: string): void {
    if (this.answered || this.over) { return; }
    const q: Syl = this.cur();
    const ok: boolean = timeoutMsg === '' && pickedValid === q.valid;
    if (ok) {
      const gain: number = 120 + Math.floor(this.leftMs / 100);
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    this.bumpK(); this.score = this.score + gain;
      this.feedback = TG2('✅ 判断正确 +{0}　{1}', gain, q.why);
    } else {
      this.feedback = (timeoutMsg === '' ? TG('❌ 判断错了　') : timeoutMsg + '　') + q.why;
    }
    this.answered = true;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= this.diffTotal; this.answered = false;
      this.feedback = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", this.right, QN);
      this.finish(this.won);
      return;
    }
    this.answered = false; this.feedback = '';
    this.leftMs = LIMIT_MS; this.roundAt = Date.now();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'logical_syllogisms', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
      Text(TG2("题 {0}/{1}", Math.min(this.qIndex + 1, QN), QN))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.cyan)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.k, y: this.k })
      Column({ space: Space.xs }) {
        Text(this.qIndex >= QN ? TG('本局结束') : this.cur().p1)
          .fontSize(FontSize.md).fontColor(this.theme.ink).width('100%')
        Text(this.qIndex >= QN ? '' : this.cur().p2)
          .fontSize(FontSize.md).fontColor(this.theme.ink).width('100%')
        Divider().color(this.theme.line)
        Text(this.qIndex >= QN ? '' : '结论：' + this.cur().concl)
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Palette.cyan).width('100%')
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Row({ space: Space.sm }) {
        Button(TG('推理有效 ✓'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.emerald)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge(true, ''); }); }).onClick(() => { Haptics.tap(); this.judge(true, ''); })
        Button(TG('推理无效 ✗'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.rose)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.judge(false, ''); }); }).onClick(() => { Haptics.tap(); this.judge(false, ''); })
      }.width('100%')
      Text(this.feedback.length > 0 ? this.feedback : '结论能从两个前提必然推出吗？')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Row({ space: Space.md }) {
        Text(TG2('分 {0}',Digits(String(this.score), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.inkFaint).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
