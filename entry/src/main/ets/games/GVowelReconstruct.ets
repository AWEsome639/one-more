/**
 * 元音重建 —— 单词里的元音在 AEIOU 里被整体挪了若干格，点亮元音把它一格一格转回来
 * 胜负：题数（简单 4/普通 6/困难 8）里还原 ≥ 通关线（3/5/7）个通关
 *       ★ 通关线原来固定 5，但简单档只有 4 个词 ⇒ 数学上不可能赢；改为随题数换算（passNeed）。
 *       进度：第几词 / 已还原 / 剩余步数 / 得分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const ROUNDS: number = 6; const PASS: number = 5; const VOWELS: string = 'AEIOU'; const FEED_MS: number = 900;

interface VW { w: string; gloss: string }

const BANK: VW[] = [
  { w: 'MUSIC', gloss: '音乐 🎵' }, { w: 'GARDEN', gloss: '花园 🌷' }, { w: 'PENCIL', gloss: '铅笔 ✏️' },
  { w: 'CASTLE', gloss: '城堡 🏰' }, { w: 'RIVER', gloss: '河流 🏞️' }, { w: 'TIGER', gloss: '老虎 🐯' },
  { w: 'WINTER', gloss: '冬天 ❄️' }, { w: 'DOCTOR', gloss: '医生 🩺' }, { w: 'PLANET', gloss: '行星 🪐' },
  { w: 'MARKET', gloss: '市场 🛒' }, { w: 'SUMMER', gloss: '夏天 ☀️' }, { w: 'ROBOT', gloss: '机器人 🤖' },
  { w: 'CANDLE', gloss: '蜡烛 🕯️' }, { w: 'SILVER', gloss: '银 🥈' }, { w: 'WINDOW', gloss: '窗户 🪟' },
  { w: 'BRIDGE', gloss: '桥 🌉' }, { w: 'KITCHEN', gloss: '厨房 🍳' }, { w: 'MONKEY', gloss: '猴子 🐒' }
];

function isVowel(ch: string): boolean { return VOWELS.indexOf(ch) >= 0; }

function vowelCount(w: string): number {
  let n: number = 0;
  for (let i = 0; i < w.length; i++) { if (isVowel(w.charAt(i))) { n = n + 1; } }
  return n;
}

/** 每个元音在 AEIOU 里往后挪 shift 格（循环），辅音不动 */
function encodeWord(w: string, shift: number): string {
  const out: string[] = [];
  for (let i = 0; i < w.length; i++) {
    const ch: string = w.charAt(i); const k: number = VOWELS.indexOf(ch);
    out.push(k < 0 ? ch : VOWELS.charAt((k + shift) % 5));
  }
  return out.join('');
}

/** 往前转一格：A→U，E→A，I→E，O→I，U→O */
function backOne(ch: string): string {
  const k: number = VOWELS.indexOf(ch);
  return k < 0 ? ch : VOWELS.charAt((k + 4) % 5);
}
/** 从 0..total-1 中随机取 k 个互不相同的下标 */
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = [];
  for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { const j: number = Math.floor(Math.random() * pool.length); out.push(pool[j]); pool.splice(j, 1); }
  return out;
}

@Component
export struct GVowelReconstruct {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private order: number[] = []; @State private qi: number = 0;
  @State private letters: string[] = []; @State private stepsLeft: number = 0;
  @State private solvedCount: number = 0; @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private msg: string = ''; @State private over: boolean = false;
  @State private won: boolean = false; @State private pressed: number = -1;

  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVowelReconstruct')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private cur(): VW { return BANK[this.order[this.qi]]; }
  private reset(): void {
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
    this.order = pickIndexes(BANK.length, this.diffTotal);
    this.qi = 0; this.solvedCount = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.startAt = Date.now(); this.load();
  }
  private load(): void {
    const word: VW = this.cur(); const shift: number = 1 + Math.floor(Math.random() * 3);
    this.letters = encodeWord(word.w, shift).split('');
    this.stepsLeft = vowelCount(word.w) * 3 + 3; this.msg = TG('点亮元音，一格一格转回来');
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
    if (this.feed >= 0) {
      return true;
    }
    this.tap(this.letters.map((ch: string, i: number) => (isVowel(ch) && ch !== this.cur().w.charAt(i)) ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const w: VW = this.cur();
    return Hint.make([],
      TG2('要还原成「{0}」（{1}）', w.w, w.gloss),
      TG2('The word should become "{0}"', w.w), t0);
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
    if (this.over || this.feed >= 0) { return; }
    const ch: string = this.letters[i];
    if (!isVowel(ch)) { return; }
    const next: string[] = this.letters.slice(); next[i] = backOne(ch);
    this.letters = next; this.stepsLeft = this.stepsLeft - 1;
    if (this.score >= 10) { this.score = this.score - 10; }
    const word: VW = this.cur();
    if (next.join('') === word.w) {
      this.solvedCount = this.solvedCount + 1; this.score = this.score + 150; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = '✅ ' + word.w + '　' + word.gloss;
      this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS);
      return;
    }
    if (this.stepsLeft <= 0) {
      this.msg = TG2('⌛ 步数用完，答案是 {0}', word.w);
      this.feed = setTimeout(() => { this.feed = -1; this.next(); }, FEED_MS * 2);
      return;
    }
    this.msg = TG2("还剩 {0} 步",Digits(String(this.stepsLeft), this.langCode));
  }
  private next(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1; this.load();
  }
  /**
   * ★ 2026-10-28 修正：通关线不能是常量 —— 题数按难度变（简单 4 / 普通 6 / 困难 8），
   *   原来固定 PASS=5，简单档最多只能还原 4 个 ⇒ 数学上不可能赢。
   *   公式 = min(题数, PASS + (题数 - ROUNDS))：简单 4→3、普通 6→5、困难 8→7。
   *   每个词都能还原（步数 = 元音数×3+3 ≥ 需要的最大步数 元音数×3），所以「实际能拿到的最大值 = 题数」。
   */
  private passNeed(): number {
    const v: number = PASS + (this.diffTotal - ROUNDS);
    return Math.max(1, Math.min(this.diffTotal, v));
  }
  private end(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.solvedCount >= this.passNeed();
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("还原 {0}/{1}", this.solvedCount, this.diffTotal);
    const r: GameResult = { gameId: 'vowel_reconstruct', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solvedCount };
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Text(TG2('词 {0}/{1}　还原 {2}', Math.min(this.qi + 1, this.diffTotal), this.diffTotal, this.solvedCount)
          + TG2('　步数 {0}',Digits(String(this.stepsLeft), this.langCode))).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).layoutWeight(1)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.xl)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        Text(TG2('释义：{0}', this.cur().gloss)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Row({ space: Space.xs }) {
          ForEach(this.letters, (ch: string, i: number) => { this.letterTile(ch, i) },
            (ch: string, i: number) => 'v' + i + ch)
        }.width('100%')
        Text(TG('点元音字母：A→U，E→A，I→E，O→I，U→O')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(2)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(88).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(TG('提示：元音被整体挪过 1～3 格，辅音位置没动')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  @Builder
  letterTile(ch: string, i: number) {
    Text(ch).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      .fontColor(isVowel(ch) ? '#FFFFFF' : this.theme.inkFaint)
      .layoutWeight(1).height(Cell.of(46)).borderRadius(Radius.sm)
      .backgroundColor(isVowel(ch) ? Palette.primary : this.theme.surfaceAlt)
      .scale({ x: this.pressed === i ? Motion.pressScale : 1, y: this.pressed === i ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap(i); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
      .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressed = i; } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; } })
  }
}
