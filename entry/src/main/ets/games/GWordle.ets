/**
 * 猜词游戏 —— 5 个字母的英文单词，5 次机会
 *
 * 玩法：用屏幕键盘输入 5 个字母 → ⏎ 提交；绿=位置对，黄=字母对位置错，灰=没有
 * 判据：5 次内猜中 ⇒ 通关；5 次用完没中 ⇒ 失败
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const LEN: number = 5;
const TRIES: number = 5;
const TICK_MS: number = 1000;
const KEY_H: number = 40;
const GAP: number = 6;

const WORDS: string[] = [
  'APPLE', 'BRAIN', 'CHAIR', 'DREAM', 'EAGLE', 'FLAME', 'GRAPE', 'HOUSE',
  'JUICE', 'KNIFE', 'LIGHT', 'MOUSE', 'NIGHT', 'OCEAN', 'PIANO', 'QUEEN',
  'RIVER', 'SMILE', 'TABLE', 'UNDER', 'VOICE', 'WATER', 'YOUTH', 'ZEBRA',
  'BREAD', 'CLOUD', 'DANCE', 'EARTH', 'FRUIT', 'GHOST', 'HONEY', 'IVORY',
  'JOKER', 'LEMON', 'MAGIC', 'NOBLE', 'OLIVE', 'PEACH', 'QUILT', 'ROBOT',
  'SUGAR', 'TIGER', 'UNCLE', 'VIVID', 'WHEAT', 'AUDIO', 'BLEND', 'CANDY'
];

const KEY_ROWS: string[] = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM⌫⏎'];

/** 把一行键盘字符串拆成字符数组 */
function charsOf(row: string): string[] {
  const out: string[] = [];
  for (let i = 0; i < row.length; i++) {
    out.push(row.charAt(i));
  }
  return out;
}

@Component
export struct GWordle {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：TRIES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(TRIES);
  onFinish: (r: GameResult) => void = () => {};

  @State private answer: string = '';
  @State private guesses: string[] = [];
  @State private marks: number[] = [];      // 摊平：行 × 5；0 未定 1 无 2 位置错 3 位置对
  @State private cur: string = '';
  @State private status: string = '';
  @State private seconds: number = 0;
  @State private over: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordle')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(TRIES);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    this.answer = WORDS[Math.floor(Math.random() * WORDS.length)];
    this.guesses = [];
    this.marks = new Array<number>(this.diffTotal * LEN).fill(0);
    this.cur = '';
    this.status = TG('输入 5 个字母，⏎ 提交');
    this.seconds = 0;
    this.over = false;
    this.finished = false;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.over && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    if (this.cur.length < LEN) {
      this.tapKey(this.answer.charAt(this.cur.length));
      return true;
    }
    this.tapKey('⏎');
    return !this.over;
  }

  /** 提示：答案就存在 this.answer 里 —— 直接报单词 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('答案是 {0}', this.answer),
      TG2('The word is {0}', this.answer), t0);
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

  private tapKey(ch: string): void {
    if (this.over || this.finished) {
      return;
    }
    if (ch === '⌫') {
      if (this.cur.length > 0) {
        this.cur = this.cur.substring(0, this.cur.length - 1);
      }
      return;
    }
    if (ch === '⏎') {
      this.submit();
      return;
    }
    if (this.cur.length >= LEN) {
      this.status = TG('已经 5 个字母了，⏎ 提交');
      return;
    }
    this.cur = this.cur + ch;
    this.status = TG2("还差 {0} 个字母", (LEN - this.cur.length));
  }

  private submit(): void {
    if (this.cur.length < LEN) {
      this.status = TG2("还差 {0} 个字母", (LEN - this.cur.length));
      return;
    }
    const guess: string = this.cur;
    const judged: number[] = this.judge(guess);
    const all: number[] = this.marks.slice();
    const row: number = this.guesses.length;
    for (let i = 0; i < LEN; i++) {
      all[row * LEN + i] = judged[i];
    }
    const next: string[] = this.guesses.slice();
    next.push(guess);
    this.guesses = next;
    this.marks = all;
    this.cur = '';

    if (guess === this.answer) {
      this.over = true;
      this.status = TG2("🎉 猜中了！用了 {0} 次", next.length);
      this.finish(true);
      return;
    }
    if (next.length >= this.diffTotal) {
      this.over = true;
      this.status = TG2('机会用完了，答案是 {0}', this.answer);
      this.finish(false);
      return;
    }
    this.status = TG2("还差 {0} 次机会", (this.diffTotal - next.length));
  }

  /** 3=位置对 2=有这个字母但位置错 1=没有（两趟扫描，重复字母也算得对） */
  private judge(guess: string): number[] {
    const res: number[] = new Array<number>(LEN).fill(1);
    const used: boolean[] = new Array<boolean>(LEN).fill(false);
    for (let i = 0; i < LEN; i++) {
      if (guess.charAt(i) === this.answer.charAt(i)) {
        res[i] = 3;
        used[i] = true;
      }
    }
    for (let i = 0; i < LEN; i++) {
      if (res[i] === 3) {
        continue;
      }
      const ch: string = guess.charAt(i);
      for (let j = 0; j < LEN; j++) {
        if (!used[j] && this.answer.charAt(j) === ch) {
          res[i] = 2;
          used[j] = true;
          break;
        }
      }
    }
    return res;
  }

  /** 键盘上的字母状态：0 没猜过 1 无 2 位置错 3 位置对 */
  private letterState(ch: string): number {
    let best: number = 0;
    for (let r = 0; r < this.guesses.length; r++) {
      const g: string = this.guesses[r];
      for (let i = 0; i < LEN; i++) {
        if (g.charAt(i) === ch) {
          const m: number = this.marks[r * LEN + i];
          if (m > best) {
            best = m;
          }
        }
      }
    }
    return best;
  }

  /** 第 r 行第 c 列显示的字母 */
  private letterAt(r: number, c: number): string {
    if (r < this.guesses.length) {
      return this.guesses[r].charAt(c);
    }
    if (r === this.guesses.length) {
      return c < this.cur.length ? this.cur.charAt(c) : '';
    }
    return '';
  }

  private markAt(r: number, c: number): number {
    if (r < this.guesses.length) {
      return this.marks[r * LEN + c];
    }
    return 0;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const used: number = this.guesses.length;
    const r: GameResult = {
      gameId: 'wordle',
      solved: solved,
      score: solved ? Math.max(200, 1000 - (used - 1) * 120 - this.seconds * 2) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: used
    };
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
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      Column({ space: GAP }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: GAP }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              this.tileView(r, c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('72%')

      Column({ space: Space.xs }) {
        ForEach(KEY_ROWS, (row: string, ri: number) => {
          Row({ space: Space.xs }) {
            ForEach(charsOf(row), (ch: string) => {
              this.keyView(ch)
            }, (ch: string) => 'k' + ri + ch)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }, (row: string, ri: number) => 'row' + ri)
      }
      .width('100%')

      Row({ space: Space.md }) {
                Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Text(this.status)
          .fontSize(FontSize.xs)
          .fontColor(this.over ? Palette.emerald : this.theme.inkSoft)
          .layoutWeight(2)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Text(TG('提示：5 个字母的常用英文单词；重复字母会按剩余次数判定'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=次数 1=已用 2=用时 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '机会' : (kind === 1 ? '已猜' : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.diffTotal - this.guesses.length)
        : (kind === 1 ? (this.guesses.length + '/' + this.diffTotal) : (this.seconds + 's')))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  tileView(r: number, c: number) {
    Stack() {
      Text(this.letterAt(r, c))
        .fontSize(FontSize.xl)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.tileInk(r, c))
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.tileBg(r, c))
    .borderRadius(Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  keyView(ch: string) {
    Text(ch)
      .fontSize(ch === '⌫' || ch === '⏎' ? FontSize.md : FontSize.sm)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.keyInk(ch))
      .textAlign(TextAlign.Center)
      .layoutWeight(ch === '⌫' || ch === '⏎' ? 2 : 1)
      .height(KEY_H)
      .backgroundColor(this.keyBg(ch))
      .borderRadius(Radius.xs)
      .onClick(() => {
        Haptics.tick();
        this.tapKey(ch);
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapKey(ch); }); })
  }

  private tileBg(r: number, c: number): string {
    const m: number = this.markAt(r, c);
    if (m === 3) {
      return Palette.emerald;
    }
    if (m === 2) {
      return Palette.amber;
    }
    if (m === 1) {
      return this.theme.isDark ? '#33333F' : '#CBD5E1';
    }
    return this.letterAt(r, c) === '' ? '#00000000' : (this.theme.isDark ? '#242438' : '#EDE9FE');
  }

  private tileInk(r: number, c: number): string {
    if (this.letterAt(r, c) === '') {
      return this.theme.inkFaint;
    }
    return this.markAt(r, c) === 0 ? this.theme.ink : '#FFFFFF';
  }

  private keyBg(ch: string): string {
    const s: number = this.letterState(ch);
    if (s === 3) {
      return Palette.emerald;
    }
    if (s === 2) {
      return Palette.amber;
    }
    if (s === 1) {
      return this.theme.isDark ? '#33333F' : '#CBD5E1';
    }
    return this.theme.surface;
  }

  private keyInk(ch: string): string {
    const s: number = this.letterState(ch);
    return s === 0 || s === 1 ? this.theme.ink : '#FFFFFF';
  }
}
