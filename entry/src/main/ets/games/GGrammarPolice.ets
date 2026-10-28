/**
 * 语法警察 —— 每句挑出「用错的那一个词」；句子本身没错就点「无错误」
 * 胜负：8 题答对 ≥5 通关｜进度：题号 / 答对 / 剩余秒数（点错罚 3 秒）
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

interface GQ { words: string[]; bad: string }

const BANK: GQ[] = [
  { words: ['She', 'go', 'to', 'school', 'every', 'day'], bad: 'go' },
  { words: ['I', 'have', 'two', 'apple', 'in', 'my', 'bag'], bad: 'apple' },
  { words: ['He', 'is', 'more', 'tall', 'than', 'me'], bad: 'more' },
  { words: ['They', 'was', 'very', 'happy', 'yesterday'], bad: 'was' },
  { words: ['The', 'cat', 'sleep', 'on', 'the', 'sofa'], bad: 'sleep' },
  { words: ['We', 'discussed', 'about', 'the', 'plan'], bad: 'about' },
  { words: ['She', 'has', 'went', 'to', 'Beijing'], bad: 'went' },
  { words: ['I', 'am', 'looking', 'forward', 'to', 'see', 'you'], bad: 'see' },
  { words: ['He', 'runs', 'very', 'quickly', 'today'], bad: '' },
  { words: ['There', 'is', 'many', 'books', 'on', 'the', 'desk'], bad: 'is' },
  { words: ['My', 'sister', 'is', 'good', 'at', 'sing'], bad: 'sing' },
  { words: ['This', 'is', 'the', 'most', 'easy', 'question'], bad: 'most' },
  { words: ['I', 'have', 'been', 'here', 'since', 'three', 'years'], bad: 'since' },
  { words: ['The', 'childrens', 'are', 'playing', 'outside'], bad: 'childrens' },
  { words: ['She', 'said', 'me', 'the', 'truth'], bad: 'said' },
  { words: ['We', 'arrived', 'to', 'the', 'airport', 'early'], bad: 'to' }
];

function shuffleIdx(): number[] {
  const out: number[] = [];
  for (let i = 0; i < BANK.length; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GGrammarPolice {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_S 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_S);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State qIdx: number = 0;
  @State right: number = 0; @State score: number = 0; @State leftS: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_S);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.stop();
    this.queue = shuffleIdx().slice(0, QN);
    this.qIdx = 0; this.right = 0; this.score = 0; this.leftS = this.diffTotal;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('点出用错的那个词；没有错就点「无错误」');
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.leftS--; this.tick(); }, TICK_MS);
  }
  private cur(): GQ { return BANK[this.queue[this.qIdx < QN ? this.qIdx : QN - 1]]; }
  private tick(): void {
    if (this.over) { return; }
    if (this.leftS <= 0) {
      this.msg = TG2("⌛ 超时 —— 错在「{0}」", (this.cur().bad.length > 0 ? this.cur().bad : '本句无误'));
      this.advance();
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.qIdx >= QN) {
      return true;
    }
    this.pick(this.cur().bad);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const bad: string = this.cur().bad;
    if (bad.length === 0) {
      return Hint.make([], TG('本句没有错误，点「无错误」'), TG('No error here — tap "No error"'), t0);
    }
    return Hint.make([],
      TG2('用错的那个词是「{0}」', bad),
      TG2('The misused word is "{0}"', bad), t0);
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
    const bad: string = this.cur().bad;
    if (w !== bad) {
      this.msg = TG2("❌ 不对 —— 错在「{0}」", (bad.length > 0 ? bad : '本句无误'));
      const keep: number = this.leftS - 3;
      this.leftS = keep > 1 ? keep : 1;
      return;
    }
    this.right = this.right + 1;
    this.score = this.score + 100 + this.leftS * 10;
    this.msg = bad.length > 0 ? TG2("✅ 就是「{0}」用错了", bad) : '✅ 本句确实没有错误';
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
    const r: GameResult = { gameId: 'grammar_police', solved: solved, score: this.score,
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIdx + 1, QN) + ' / ' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
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

      Text(TG('找出用错的那个词')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint).width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.cur().words, (w: string) => {
          Text((w)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).padding({ left: Space.md, right: Space.md, top: Space.sm, bottom: Space.sm }).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card).margin({ right: Space.xs, bottom: Space.xs }).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick((w)); })
        }, (w: string, i: number) => 'w' + i + w)
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(TG('无错误 ✅'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.orange).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick(''); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG2("每题 {0} 秒，点错罚 3 秒；答对 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
