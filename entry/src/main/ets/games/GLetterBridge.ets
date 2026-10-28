/**
 * 字母桥 —— 单词缺了一个字母，从四个候选里把桥补上
 * 胜负：8 题答对 ≥5 通关｜进度：题号 / 答对 / 剩余秒数（点错罚 2 秒）
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

const QN: number = 8; const PASS: number = 5;
const LIMIT_S: number = 15; const TICK_MS: number = 1000;

interface LB { left: string; right: string; letter: string; cn: string; opts: string[] }

const BANK: LB[] = [
  { left: 'GAR', right: 'EN', letter: 'D', cn: TG('花园'), opts: ['D', 'T', 'N', 'B'] },
  { left: 'WIN', right: 'ER', letter: 'T', cn: TG('冬天'), opts: ['T', 'D', 'S', 'L'] },
  { left: 'MAR', right: 'ET', letter: 'K', cn: '市场', opts: ['K', 'G', 'C', 'Q'] },
  { left: 'BRI', right: 'GE', letter: 'D', cn: TG('桥'), opts: ['D', 'T', 'G', 'B'] },
  { left: 'CAS', right: 'LE', letter: 'T', cn: '城堡', opts: ['T', 'D', 'S', 'L'] },
  { left: 'PEN', right: 'IL', letter: 'C', cn: TG('铅笔'), opts: ['C', 'S', 'K', 'G'] },
  { left: 'CL', right: 'OUD', letter: 'O', cn: '云', opts: ['O', 'A', 'U', 'E'] },
  { left: 'RIV', right: 'R', letter: 'E', cn: TG('河流'), opts: ['E', 'A', 'O', 'I'] },
  { left: 'PLAN', right: 'T', letter: 'E', cn: '行星', opts: ['E', 'A', 'I', 'O'] },
  { left: 'SIL', right: 'ER', letter: 'V', cn: '银', opts: ['V', 'F', 'W', 'B'] },
  { left: 'MUS', right: 'C', letter: 'I', cn: '音乐', opts: ['I', 'E', 'A', 'U'] },
  { left: 'FLO', right: 'ER', letter: 'W', cn: '花', opts: ['W', 'V', 'R', 'U'] },
  { left: 'DOC', right: 'OR', letter: 'T', cn: '医生', opts: ['T', 'D', 'K', 'S'] },
  { left: 'TEA', right: 'ER', letter: 'CH', cn: '老师', opts: ['CH', 'SH', 'TH', 'CK'] },
  { left: 'WEI', right: 'HT', letter: 'G', cn: '重量', opts: ['G', 'K', 'H', 'J'] },
  { left: 'BR', right: 'AD', letter: 'E', cn: '面包', opts: ['E', 'A', 'O', 'I'] }
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
export struct GLetterBridge {
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
    this.msg = TG('缺的是哪个字母？');
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.leftS--; this.tick(); }, TICK_MS);
  }
  private cur(): LB { return BANK[this.queue[this.qIdx < QN ? this.qIdx : QN - 1]]; }
  private tick(): void {
    if (this.over) { return; }
    if (this.leftS <= 0) {
      this.msg = TG2('⌛ 超时 —— 答案 {0}（{1}）', this.cur().letter, this.cur().cn);
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
    if (this.over) {
      return true;
    }
    this.pick(this.cur().letter);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const q: LB = this.cur();
    const word: string = q.left + q.letter + q.right;
    return Hint.make([],
      TG2('缺的是「{0}」⇒ {1}（{2}）', q.letter, word, q.cn),
      TG2('The missing letter is {0} — {1} ({2})', q.letter, word, q.cn), t0);
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

  private pick(l: string): void {
    if (this.over) { return; }
    if (l !== this.cur().letter) {
      this.msg = TG2('❌ 不对，答案 {0}（{1}）', this.cur().letter, this.cur().cn);
      const keep: number = this.leftS - 2;
      this.leftS = keep > 1 ? keep : 1;
      return;
    }
    this.right = this.right + 1;
    this.score = this.score + 100 + this.leftS * 10;
    this.msg = '✅ ' + this.cur().left + l + this.cur().right + ' —— ' + this.cur().cn;
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
    const r: GameResult = { gameId: 'letter_bridge', solved: solved, score: this.score,
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
        Text((Math.min(this.qIdx + 1, QN) + ' / ' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
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
        Text(TG('补上缺的字母')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          Text(('#FFFFFF')).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).textAlign(TextAlign.Center).padding(Space.sm).backgroundColor((this.theme.surfaceAlt)).borderRadius(Radius.sm)
          Text(TG('桥')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.primary)
          Text((this.cur().right)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).textAlign(TextAlign.Center).padding(Space.sm).backgroundColor((this.theme.surfaceAlt)).borderRadius(Radius.sm)
        }.justifyContent(FlexAlign.Center).width('100%')
        Text(TG2('释义：{0}', this.cur().cn)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Button(this.cur().opts[(i)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick(this.cur().opts[(i)]); })
        }, (i: number) => 'p' + i)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("{0} 题，每题 {1} 秒；答对 ≥{2} 通关",Digits(String(QN), this.langCode),Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
