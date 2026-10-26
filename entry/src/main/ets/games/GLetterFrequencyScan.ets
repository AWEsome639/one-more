/** 字母频率 —— 数字母出现几次（8 题答对 ≥5 通关 ｜ 进度：题号/答对/每题倒计时） */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 8; const PASS: number = 5; const OPT_N: number = 4;
const LIMIT_MS: number = 6000; const TICK_MS: number = 100; const FEED_MS: number = 700;
const ALPHA: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
const WORDS: string[] = ['PINEAPPLE', 'BANANA', 'STRAWBERRY', 'CHOCOLATE', 'BUTTERFLY', 'MOUNTAIN',
  'ELEPHANT', 'SANDWICH', 'UMBRELLA', 'KANGAROO', 'LIBRARY', 'TREASURE'];
interface FreqQ { text: string; target: string; opts: number[]; ans: number }
function countIn(text: string, ch: string): number {
  let n: number = 0;
  for (let i = 0; i < text.length; i++) { if (text.charAt(i) === ch) { n = n + 1; } }
  return n;
}
function makeQ(): FreqQ {
  const word: string = WORDS[Math.floor(Math.random() * WORDS.length)];
  const want: boolean = Math.random() < 0.7;
  let target: string = ALPHA[Math.floor(Math.random() * ALPHA.length)];
  for (let t = 0; t < 12 && (countIn(word, target) > 0) !== want; t++) {
    target = ALPHA[Math.floor(Math.random() * ALPHA.length)];
  }
  const ans: number = countIn(word, target);
  const opts: number[] = [ans];
  let step: number = 1;
  while (opts.length < OPT_N) {
    const cand: number = ans + step;
    if (cand >= 0 && opts.indexOf(cand) < 0) { opts.push(cand); }
    step = step > 0 ? -step : -step + 1;
  }
  opts.sort((x: number, y: number) => x - y);
  return { text: word, target: target, opts: opts, ans: opts.indexOf(ans) };
}

@Component
export struct GLetterFrequencyScan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State q: FreqQ = makeQ(); @State qIndex: number = 0; @State right: number = 0;
  @State score: number = 0; @State leftMs: number = this.diffTotal; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false; @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop();
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.q = makeQ(); this.load(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void { this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('点出这个字母出现了几次'); }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：其实是 {0} 次', String(this.q.opts[this.q.ans])); this.advance(); }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：字母频率
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.feed >= 0) {
      return true;
    }
    this.pick(this.q.ans);
    return !this.over;
  }

  /** 提示：直接报正确选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.q.ans],
      TG2('答案是第 {0} 个', String(this.q.ans + 1)),
      TG2('The answer is option {0}', String(this.q.ans + 1)), t0);
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

  private pick(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    const truth: number = this.q.opts[this.q.ans];
    if (i === this.q.ans) {
      const gain: number = 100 + Math.floor(this.leftMs / 20);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = TG2('✅ {0} 次，+{1}', String(truth), String(gain));
    } else { this.msg = TG2("❌ 其实是 {0} 次", String(truth)); }
    this.advance();
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.q = makeQ(); this.load(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'letter_frequency_scan', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private spaced(): string {
    const parts: string[] = []; const t: string = this.q.text;
    for (let i = 0; i < t.length; i++) { parts.push(t.charAt(i)); }
    return parts.join(' ');
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
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG2('字母 {0} 出现了几次？', this.q.target)).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        Text(this.spaced()).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink).textAlign(TextAlign.Center).width('100%')
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Text(String(this.q.opts[(i)])).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(64)).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).shadow(Shadow.card)
          .scale({ x: this.pressed === (i) ? Motion.pressScale : 1, y: this.pressed === (i) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
          })
          .onClick(() => { Haptics.tick(); this.pick((i)); })
        }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：看清整串字母再选，别只数开头几个')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
