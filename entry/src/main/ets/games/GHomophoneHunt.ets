/**
 * 同音词 —— 给出发音 /aɪ/ 这类提示，从四个词里挑出与它同音的那个
 * 胜负：10 题答对 ≥6 通关｜进度：题号 / 答对 / 剩余秒数（点错罚 2 秒）
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
import { Tv } from '../core/Tv';

const QN: number = 10; const PASS: number = 6;
const LIMIT_S: number = 15; const TICK_MS: number = 1000;

interface HP { ipa: string; hint: string; word: string; opts: string[] }

const BANK: HP[] = [
  { ipa: '/aɪ/', hint: '眼睛（单数）', word: 'EYE', opts: ['EYE', 'I\'LL', 'AIL', 'OIL'] },
  { ipa: '/miː/', hint: '我（宾格）', word: 'ME', opts: ['ME', 'MAY', 'MY', 'MOW'] },
  { ipa: '/piːs/', hint: '和平；一片', word: 'PEACE', opts: ['PEACE', 'PIECE', 'PEAS', 'PACE'] },
  { ipa: '/siː/', hint: '看见', word: 'SEE', opts: ['SEE', 'SEA', 'SAY', 'SO'] },
  { ipa: '/tuː/', hint: '也（用于句末）', word: 'TOO', opts: ['TOO', 'TO', 'TWO', 'TOW'] },
  { ipa: '/hiːl/', hint: '治愈', word: 'HEAL', opts: ['HEAL', 'HEEL', 'HELL', 'HALE'] },
  { ipa: '/weɪ/', hint: '称重', word: 'WEIGH', opts: ['WEIGH', 'WAY', 'WHEY', 'WADE'] },
  { ipa: '/nəʊ/', hint: '知道', word: 'KNOW', opts: ['KNOW', 'NO', 'NOW', 'NOD'] },
  { ipa: '/sʌn/', hint: '儿子', word: 'SON', opts: ['SON', 'SUN', 'SIN', 'SEWN'] },
  { ipa: '/flaɪ/', hint: '苍蝇', word: 'FLY', opts: ['FLY', 'FLEA', 'FLEE', 'FLAY'] },
  { ipa: '/bɔːl/', hint: '碗', word: 'BOWL', opts: ['BOWL', 'BALL', 'BOIL', 'BULL'] },
  { ipa: '/lesn/', hint: '课程', word: 'LESSON', opts: ['LESSON', 'LESSEN', 'LESSER', 'LISTEN'] },
  { ipa: '/səʊl/', hint: '唯一', word: 'SOLE', opts: ['SOLE', 'SOUL', 'SALE', 'SILL'] },
  { ipa: '/səʊ/', hint: '缝纫；播种', word: 'SEW', opts: ['SEW', 'SO', 'SAW', 'SIP'] },
  { ipa: '/raɪt/', hint: '写作', word: 'WRITE', opts: ['WRITE', 'RIGHT', 'RITE', 'RATE'] }
];

function shuffleIdx(): number[] {
  const out: number[] = [];
  for (let i = 0; i < BANK.length; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out.slice(0, QN);
}

@Component
export struct GHomophoneHunt {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_S 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_S);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State qIdx: number = 0;
  @State right: number = 0; @State score: number = 0; @State leftS: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_S);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }
  private reset(): void {
    this.stop();
    this.queue = shuffleIdx();
    this.qIdx = 0; this.right = 0; this.score = 0; this.leftS = this.diffTotal;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('哪个词是这个读音？');
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.leftS--; this.tick(); }, TICK_MS);
  }
  private cur(): HP { return BANK[this.queue[this.qIdx < QN ? this.qIdx : QN - 1]]; }
  private tick(): void {
    if (this.over) { return; }
    if (this.leftS <= 0) {
      this.msg = TG2('⌛ 超时 —— 答案是 {0}', this.cur().word);
      this.advance();
    }
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
    if (false) {
      return true;
    }
    this.pick(this.cur().word);
    return !this.over;
  }

  /** 提示：这类题的正确词就存在 BANK 里，直接报词本身 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    const w: string = this.cur().word;
    return Hint.make([],
      TG2('答案是「{0}」，读音 {1}', w, this.cur().ipa),
      'The answer is ' + w, t0);
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

  private pick(w: string): void {
    if (this.over) { return; }
    if (w !== this.cur().word) {
      this.msg = TG2('❌ {0} 读音不同，答案是 {1}', w, this.cur().word);
      const keep: number = this.leftS - 2;
      this.leftS = keep > 1 ? keep : 1;
      return;
    }
    this.right = this.right + 1;
    this.score = this.score + 100 + this.leftS * 10;
    this.msg = TG2("✅ {0} 与 {1} 同音", w, this.cur().ipa);
    this.advance();
  }
  private advance(): void {
    this.qIdx = this.qIdx + 1;
    if (this.qIdx >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, QN);
      this.finish(this.won); return;
    }
    this.leftS = this.diffTotal;
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'homophone_hunt', solved: solved, score: this.score,
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIdx + 1, QN) + ' / ' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(this.cur().ipa).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
        Text(TG2('释义提示：{0}', this.cur().hint)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Button(this.cur().opts[(0)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(this.cur().opts[(0)]); }); }).onClick(() => { Haptics.tap(); this.pick(this.cur().opts[(0)]); })
          Button(this.cur().opts[(1)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(this.cur().opts[(1)]); }); }).onClick(() => { Haptics.tap(); this.pick(this.cur().opts[(1)]); })
        }.width('100%')
        Row({ space: Space.sm }) {
          Button(this.cur().opts[(2)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(this.cur().opts[(2)]); }); }).onClick(() => { Haptics.tap(); this.pick(this.cur().opts[(2)]); })
          Button(this.cur().opts[(3)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(this.cur().opts[(3)]); }); }).onClick(() => { Haptics.tap(); this.pick(this.cur().opts[(3)]); })
        }.width('100%')
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("{0} 题，每题 {1} 秒；答对 ≥{2} 通关",Digits(String(QN), this.langCode),Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
