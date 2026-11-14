/**
 * 猜词游戏 —— 5 个字母的英文单词，5 次机会
 *
 * 玩法：用屏幕键盘输入 5 个字母 → ⏎ 提交；绿=位置对，黄=字母对位置错，灰=没有
 * 判据：5 次内猜中 ⇒ 通关；5 次用完没中 ⇒ 失败
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { Hint, HintResult } from '../ai/Hint';
import { Bp } from '../core/Bp';
import { Sec } from '../core/I18n';
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
import { AppClock } from '../core/AppClock';

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
// fix20261113: 预计算成稳定的二维数组 —— 在 builder 里每次 `charsOf(row)` 都会产生**新数组**，
//   ArkUI 的 ForEach 拿到的数据源每帧都变身份 ⇒ 可能直接跳过。
const KEY_CHARS: string[][] = [['Q','W','E','R','T','Y','U','I','O','P'],
  ['A','S','D','F','G','H','J','K','L'], ['Z','X','C','V','B','N','M','⌫','⏎']];

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
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = GameDiff.livesNow(TRIES);
  onFinish: (r: GameResult) => void = () => {};

  @State private answer: string = '';
  @State private guesses: string[] = [];
  @State private marks: number[] = [];      // 摊平：行 × 5；0 未定 1 无 2 位置错 3 位置对
  @State private cur: string = '';
  /** ★ 2026-11-08（ai-fixer-a）代打当前要打的候选词（每猜一次重算；空 = 候选耗尽） */
  private autoWord: string = '';
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
      if (AppClock.isPaused()) { return; }
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    // ★ 2026-11-08（ai-fixer-a）**不再读 answer**：用历史反馈筛候选词，逐字母输入。
    if (this.cur.length < LEN) {
      if (this.autoWord.length !== LEN) {
        this.autoWord = this.autoPick();
      }
      if (this.autoWord.length !== LEN) {
        return false;
      }
      this.tapKey(this.autoWord.charAt(this.cur.length));
      return true;
    }
    this.autoWord = '';
    this.tapKey('⏎');
    return !this.over;
  }

  /**
   * ★ 2026-11-08（ai-fixer-a）代打选词：**只依赖历史上的猜词与反馈**，不读 answer。
   *   对词库里每个候选 w，用与 judge() 同规则的 scoreOf 重放每一行历史；
   *   与 marks 全部一致才算候选。第一条候选就是下一步要打的词。
   */
  private autoPick(): string {
    const rows: number = this.guesses.length;
    for (let k = 0; k < WORDS.length; k++) {
      const w: string = WORDS[k];
      if (w.length !== LEN) {
        continue;
      }
      let ok: boolean = true;
      for (let r = 0; r < rows && ok; r++) {
        const sc: number[] = this.scoreOf(this.guesses[r], w);
        for (let i = 0; i < LEN; i++) {
          if (sc[i] !== this.marks[r * LEN + i]) {
            ok = false;
            break;
          }
        }
      }
      if (ok) {
        return w;
      }
    }
    return '';
  }

  /** 与 judge() 完全同规则，但目标是任意词（不碰 answer） */
  private scoreOf(guess: string, target: string): number[] {
    const res: number[] = new Array<number>(LEN).fill(1);
    const used: boolean[] = new Array<boolean>(LEN).fill(false);
    for (let i = 0; i < LEN; i++) {
      if (guess.charAt(i) === target.charAt(i)) {
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
        if (!used[j] && target.charAt(j) === ch) {
          res[i] = 2;
          used[j] = true;
          break;
        }
      }
    }
    return res;
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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
    Scroll() {
      Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
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
              // fix20261112: inner ForEach key was 'c'+c, identical across all 5 rows -> duplicate keys
              }, (c: number) => 'c' + r + '-' + c)
            }
            .width('100%')
          }, (r: number) => 'r' + r)
        }
              // 2026-11-13 第二档：键盘在 1518..1600 只露上半截 ⇒ 棋盘再收 40px（220 → 185）
        .width(Bp.isShort() ? 120 : 614)

        Column({ space: Space.xs }) {
          ForEach(KEY_CHARS, (row: string[], ri: number) => {
            Row({ space: Space.xs }) {
              ForEach(row, (ch: string) => {
                this.keyView(ch)
              // diag20261113 FIX: key 生成器原来引用外层 `ri` —— ArkUI 在 diff 阶段调用它时
              //   外层变量可能尚未绑定 ⇒ 内层 items 被静默跳过（日志证明 charsOf 正常返回 10/9/9）。
              //   ⇒ key 只用内层 `ch`（同一行内字母不重复）。
              }, (ch: string) => 'k' + ri + '-' + ch)
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
            .onFocus(() => { this.tvFocus = 'L443'; })
            .onBlur(() => { if (this.tvFocus === 'L443') { this.tvFocus = ''; } })
            .outline(Tv.focusOutline(this.tvFocus === 'L443'))
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
      // .height('100%')  ← 2026-11-14：套 Scroll 后不能用 100%（内容高=视口高⇒滚不动），判据见 _巡检记录
      .justifyContent(FlexAlign.Start)
    }
  }

  /** kind: 0=次数 1=已用 2=用时 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('机会') : (kind === 1 ? TG('已猜') : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.diffTotal - this.guesses.length)
        : (kind === 1 ? (this.guesses.length + '/' + this.diffTotal) : (this.seconds + Sec())))
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
        // 2026-11-13（队友审出）：棋盘宽 120vp ⇒ 格子 24vp，而 `FontSize.xl`=20 装进去很挤
        .fontSize(Bp.isShort() ? FontSize.md : FontSize.xl)
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
      .onFocus(() => { this.tvFocus = 'L518'; })
      .onBlur(() => { if (this.tvFocus === 'L518') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L518', Radius.xs))
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
