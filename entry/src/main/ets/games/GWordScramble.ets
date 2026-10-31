/**
 * 单词重排 —— 打乱的字母按正确顺序点回去，中文释义给线索
 * 胜负：150 秒内拼对 8 个词通关｜超时失败｜进度：第几个 / 拼对 / 剩余时间
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const ROUNDS: number = 8; const LIMIT_MS: number = 150000;
const TICK_MS: number = 100; const FEED_MS: number = 620;
interface Entry { w: string; hint: string }
const BANK: Entry[] = [
  { w: 'APPLE', hint: TG('苹果') }, { w: 'BANANA', hint: TG('香蕉') }, { w: 'ORANGE', hint: '橙子' },
  { w: 'GRAPE', hint: '葡萄' }, { w: 'TIGER', hint: TG('老虎') }, { w: 'RABBIT', hint: '兔子' },
  { w: 'PENCIL', hint: TG('铅笔') }, { w: 'FLOWER', hint: '花朵' }, { w: 'WINDOW', hint: '窗户' },
  { w: 'GARDEN', hint: TG('花园') }, { w: 'SUMMER', hint: '夏天' }, { w: 'WINTER', hint: TG('冬天') },
  { w: 'MUSIC', hint: '音乐' }, { w: 'RIVER', hint: TG('河流') }, { w: 'CANDLE', hint: '蜡烛' },
  { w: 'KITCHEN', hint: '厨房' }, { w: 'MORNING', hint: '早晨' }, { w: 'MONKEY', hint: '猴子' }
];
function mixEntries(src: Entry[]): Entry[] {
  const out: Entry[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: Entry = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
function mixLetters(w: string): string[] {
  const src: string[] = w.split('');
  for (let i = src.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = src[i]; src[i] = src[j]; src[j] = t;
  }
  return src;
}
@Component
export struct GWordScramble {
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
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State queue: Entry[] = []; @State idx: number = 0; @State tiles: string[] = [];
  @State used: boolean[] = []; @State typed: string[] = []; @State msg: string = '';
  @State score: number = 0; @State solved: number = 0; @State leftMs: number = LIMIT_MS;
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private feed: number = -1;
  private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordScramble')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stopAll(); }
  private stopAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private word(): string { return this.queue.length > this.idx ? this.queue[this.idx].w : ''; }
  private hint(): string { return this.queue.length > this.idx ? this.queue[this.idx].hint : ''; }
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
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
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
    if (this.feed >= 0) {
      return true;
    }
    this.aiTap(0);
    return !this.over;
  }

  /** 提示：这个词拼成什么 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const w: string = this.word();
    if (w.length === 0) { return Hint.none('none'); }
    return Hint.make([], TG2('这个词是「{0}」（{1}）', w, this.hint()),
      TG2('The word is {0}', w), t0);
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

  private reset(): void {
    this.stopAll();
    this.queue = mixEntries(BANK).slice(0, this.diffTotal);
    this.idx = 0; this.score = 0; this.solved = 0; this.leftMs = LIMIT_MS;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void {
    const w: string = this.word();
    let t: string[] = mixLetters(w);
    for (let guard = 0; guard < 20 && t.join('') === w; guard++) { t = mixLetters(w); }
    this.tiles = t; this.used = new Array<boolean>(w.length).fill(false); this.typed = [];
    this.msg = TG2('按顺序点字母，拼出「{0}」', this.hint());
  }
  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.startAt;
    this.leftMs = gap >= LIMIT_MS ? 0 : LIMIT_MS - gap;
    if (gap >= LIMIT_MS) {
      this.over = true; this.msg = TG2("⌛ 时间到 —— 拼对 {0} 个词", this.solved); this.finish(false);
    }
  }
  private tap(i: number): void {
    if (this.over || this.feed >= 0 || (this.used.length > i && this.used[i])) { return; }
    const next: boolean[] = this.used.slice(); next[i] = true; this.used = next;
    this.typed = this.typed.concat([this.tiles[i]]);
    if (this.typed.length >= this.word().length) { this.check(); }
  }
  private undo(): void {
    if (this.over || this.typed.length === 0) { return; }
    const last: string = this.typed[this.typed.length - 1];
    const next: boolean[] = this.used.slice();
    for (let i = next.length - 1; i >= 0; i--) {
      if (next[i] && this.tiles[i] === last) { next[i] = false; break; }
    }
    this.used = next; this.typed = this.typed.slice(0, this.typed.length - 1);
  }
  private check(): void {
    const guess: string = this.typed.join(''); const w: string = this.word();
    if (guess === w) {
      this.solved = this.solved + 1; this.score = this.score + 100 + Math.floor(this.leftMs / 1000);
      this.msg = '✅ ' + w + '（' + this.hint() + '）';
      if (this.solved >= this.diffTotal) {
        this.over = true; this.won = true; this.msg = TG2('🎉 {0} 个词全拼对，通关！',Digits(String(this.diffTotal), this.langCode));
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.feed = setTimeout(() => { this.feed = -1; this.idx = this.idx + 1; this.load(); }, FEED_MS);
      return;
    }
    this.msg = TG2('❌ {0} 不对，再试一次', guess);
    this.feed = setTimeout(() => { this.feed = -1; this.used = new Array<boolean>(w.length).fill(false); this.typed = []; }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true; this.stopAll();
    const r: GameResult = { gameId: 'word_scramble', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solved };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private tileTone(i: number): string { return this.used.length > i && this.used[i] ? (this.theme.isDark ? '#2A2A2A' : '#D8DDE6') : this.theme.surface; }
  /** AI 用：按单词顺序，点出下一个字母 */
  private aiTap(_d: number): void {
    const w: string = this.word();
    if (this.typed.length >= w.length) { return; }
    const ch: string = w[this.typed.length];
    for (let i = 0; i < this.tiles.length; i++) {
      if (this.tiles[i] === ch && !this.used[i]) { this.tap(i); return; }
    }
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
        Column({ space: Space.xs }) {
        Text((TG('第几个'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.idx + 1) + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('拼对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.solved), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('「' + this.hint() + '」').fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.typed.length > 0 ? this.typed.join(' ') : '· · ·').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.primary)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(this.tiles, (c: string, i: number) => { Text((c)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).aspectRatio(1).backgroundColor(this.tileTone((i))).borderRadius(Radius.sm).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); }) }, (c: string, i: number) => 't' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Row({ space: Space.sm }) {
        Button(TG('撤销'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.undo(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.undo(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(TG2('提示：拼错会自动清空重来；共 {0} 个词，慢慢想 🐳', this.diffTotal)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
