/** 统计学习 📐（id: visual_statistical_learning）
 * 一串图形逐个闪过，其中某三个总是连着出现；看完后从四个组合里挑出那一组；
 * 3 轮答对 ≥2 ⇒ 通关，否则失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
const POOL: string[] = ['🍎', '🍌', '🍇', '🍓', '🍑', '🥝'];
const TOTAL: number = 15;
const AT: number[] = [0, 5, 10];
const ROUNDS: number = 3;
const NEED: number = 2;
const GAP: number = 520;
const PAUSE: number = 900;
const SLOTS: number[] = [0, 1, 2, 3];
@Component
export struct GVisualStatisticalLearning {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State stream: string[] = [];
  @State cursor: number = 0;
  @State asking: boolean = false;
  @State opts: string[][] = [];
  @State ans: number = 0;
  @State round: number = 0;
  @State hits: number = 0;
  @State picked: number = -1;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  private timer: number = -1;
  private wait: number = -1;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.wait >= 0) { clearTimeout(this.wait); this.wait = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.round = 0; this.hits = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }
  /** 随机取 3 个互不相同的图形 */
  private pickThree(): string[] {
    const out: string[] = [];
    while (out.length < 3) {
      const e: string = POOL[Math.floor(Math.random() * POOL.length)];
      if (out.indexOf(e) < 0) { out.push(e); } }
    return out;
  }
  private newRound(): void {
    const base: string[] = this.pickThree(); const s: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) { s.push(POOL[Math.floor(Math.random() * POOL.length)]); }
    for (let k = 0; k < AT.length; k++) { for (let j = 0; j < 3; j++) { s[AT[k] + j] = base[j]; } }
    this.stream = s; this.cursor = 0; this.asking = false; this.picked = -1; this.opts = [];
    this.note = TG('盯住反复连着出现的那三个'); this.clearAll();
    this.timer = setInterval(() => {
      this.cursor = this.cursor + 1;
      if (this.cursor >= this.diffTotal) { this.ask(base); }
    }, GAP);
  }
  /** 打乱四个组合选项后上屏 */
  private ask(base: string[]): void {
    this.clearAll();
    const rest: string[][] = [];
    const seen: string[] = [base.join('')];
    while (rest.length < 3) {
      const t: string[] = this.pickThree();
      if (seen.indexOf(t.join('')) >= 0) { continue; }
      seen.push(t.join('')); rest.push(t); }
    const at: number = Math.floor(Math.random() * 4);
    const out: string[][] = []; let k: number = 0;
    for (let i = 0; i < 4; i++) {
      if (i === at) { out.push(base); } else { out.push(rest[k]); k++; }
    }
    this.opts = out; this.ans = at; this.asking = true; this.note = TG('哪三个总是连着出现？');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
    return !this.over;
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

  private pick(i: number): void {
    if (this.over || !this.asking || this.picked >= 0) { return; }
    this.picked = i;
    if (i === this.ans) { this.hits++; this.note = TG('✅ 就是这一组'); } else { this.note = TG('❌ 绿框那组才是'); }
    this.clearAll();
    this.wait = setTimeout(() => {
      this.wait = -1;
      if (this.round + 1 >= ROUNDS) { this.finish(this.hits >= NEED); return; }
      this.round++; this.newRound();
    }, PAUSE);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; this.clearAll();
    const r: GameResult = {
      gameId: 'visual_statistical_learning', solved: solved, score: this.hits * 60,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private now(): string {
    return this.stream.length === 0 ? '' : this.stream[Math.min(this.cursor, this.stream.length - 1)];
  }
  private label(t: string[]): string {
    return t.length < 3 ? '' : t[0] + ' › ' + t[1] + ' › ' + t[2];
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG('第 ') + String(Math.min(this.round + 1, ROUNDS)) + '/' + String(ROUNDS) + ' 轮 · 答对 ' +
        String(this.hits) + '/' + String(NEED) + ' · ' + String(Math.min(this.cursor + 1, this.diffTotal)) +
        '/' + String(this.diffTotal))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        .padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      if (!this.asking) {
        Column({ space: Space.xs }) {
          Text(this.now()).fontSize(FontSize.hero)
          Text(TG('看 · 记住连在一起的那三个')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .width('100%').height(Space.xxxl * 2).justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      } else {
        ForEach(SLOTS, (i: number) => {
          this.option(i)
        }, (i: number) => 'so' + i)
      }
      Text(this.note).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .textAlign(TextAlign.Center).width('100%')
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  option(i: number) {
    Text(this.opts.length > i ? this.label(this.opts[i]) : '')
      .fontSize(FontSize.xl).fontColor(this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52)).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .borderWidth(2)
      .borderColor(this.picked < 0 ? this.theme.line :
        (i === this.ans ? Palette.emerald : (i === this.picked ? Palette.rose : this.theme.line)))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.pick(i); })
  }
}
