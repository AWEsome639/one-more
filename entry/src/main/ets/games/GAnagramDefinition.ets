/**
 * 字谜定义 —— 看中文释义，按顺序点字母把单词拼回来
 * 胜负：6 题答对 ≥4 ⇒ 通关｜进度：题号 / 答对 / 每题倒计时（点错罚 3 秒） */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const QN: number = 6; const PASS: number = 4;
const LIMIT_MS: number = 20000; const TICK_MS: number = 100;
const PENALTY_MS: number = 3000; const FEED_MS: number = 800;
const EIGHT: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
interface AnaQ { word: string; def: string }
const BANK: AnaQ[] = [
  { word: 'ORANGE', def: '橙子；橙色' }, { word: 'GARDEN', def: TG('花园') }, { word: 'WINTER', def: TG('冬天') }, { word: 'PLANET', def: '行星' },
  { word: 'SILVER', def: '银；银色的' }, { word: 'MARKET', def: '市场' }, { word: 'BRIDGE', def: TG('桥') }, { word: 'CASTLE', def: '城堡' },
  { word: 'PENCIL', def: TG('铅笔') }, { word: 'CLOUD', def: '云' }, { word: 'MUSIC', def: '音乐' }, { word: 'RIVER', def: TG('河流') }
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
function shuffleStr(arr: string[]): string[] {
  const out: string[] = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GAnagramDefinition {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State letters: string[] = []; @State picked: number[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State leftMs: number = this.diffTotal; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private roundAt: number = 0;
  private timer: number = -1; private feed: number = -1; private done: boolean = false;

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
    this.queue = pickIndexes(BANK.length, QN);
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void {
    this.letters = shuffleStr(this.curWord().split(''));
    this.picked = []; this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('把字母拼回这个单词');
  }
  private cur(): AnaQ { return this.qIndex >= QN ? BANK[0] : BANK[this.queue[this.qIndex]]; }
  private curWord(): string { return this.qIndex >= QN ? '' : this.cur().word; }
  private guess(): string { return this.picked.map((k: number) => this.letters[k]).join(''); }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时，答案是 {0}', this.curWord()); this.picked = []; this.advance(); }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.feed >= 0) {
      return true;
    }
    this.tap(this.letters.map((ch: string, i: number) => (ch === this.curWord().charAt(this.picked.length) && this.picked.indexOf(i) < 0) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const w: string = this.curWord();
    // ★ 单词里可能有重复字母（RIVER 有两个 R）⇒ 必须跳过已经点过的位置
    const cs: number[] = [];
    const used: number[] = [];
    for (let i = 0; i < w.length; i++) {
      for (let k = 0; k < this.letters.length; k++) {
        if (this.letters[k] === w.charAt(i) && used.indexOf(k) < 0) {
          cs.push(k);
          used.push(k);
          break;
        }
      }
    }
    return Hint.make(cs,
      TG2('答案是「{0}」', w),
      TG2('The answer is "{0}"', w), t0);
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

  private tap(i: number): void {
    if (this.over || this.feed >= 0 || i >= this.letters.length || this.picked.indexOf(i) >= 0) { return; }
    this.picked = this.picked.concat([i]);
    if (this.picked.length >= this.curWord().length) { this.check(); }
  }
  private check(): void {
    const word: string = this.curWord();
    if (this.guess() === word) {
      const gain: number = 100 + Math.floor(this.leftMs / 100);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = TG2('✅ {0} 正确！+{1}', word, gain); this.picked = []; this.advance();
      return;
    }
    this.msg = TG('❌ 拼错了，再试一次'); this.picked = [];
    const keep: number = this.leftMs - PENALTY_MS > 600 ? this.leftMs - PENALTY_MS : 600;
    this.leftMs = keep; this.roundAt = Date.now() - (this.diffTotal - keep);
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1;
    if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, QN); this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.load(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'anagram_definition', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private bar(): string {
    return TG('题 ') + Math.min(this.qIndex + 1, QN) + '/' + QN + TG('　答对 ') + this.right + '　剩余 ' + (this.leftMs / 1000).toFixed(1) + 's';
  }
  private answerText(): string {
    const w: string = this.curWord(); const parts: string[] = [];
    for (let i = 0; i < w.length; i++) { parts.push(i < this.picked.length ? this.letters[this.picked[i]] : '·'); }
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
      Text(this.bar()).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        Text(this.qIndex >= QN ? TG('本局结束') : this.cur().def).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG2("共 {0} 个字母　点字母拼词", this.curWord().length)).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Text(this.answerText()).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .width('100%').textAlign(TextAlign.Center).height(Cell.of(44))
      Row({ space: Space.xs }) {
        ForEach(EIGHT, (i: number) => { this.letterBtn(i) }, (i: number) => 'L' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('退一格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.picked = this.picked.slice(0, this.picked.length - 1); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  letterBtn(i: number) {
    Text(i < this.letters.length ? this.letters[i] : '')
      .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      .fontColor(this.picked.indexOf(i) >= 0 ? this.theme.inkFaint : this.theme.ink)
      .layoutWeight(1).aspectRatio(1)
      .backgroundColor(this.picked.indexOf(i) >= 0 ? this.theme.line : this.theme.surface)
      .borderRadius(Radius.sm).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
