/**
 * 词汇冲刺 —— 60 秒内按中文释义抢答英文单词，连击加分
 * 胜负：答对 12 个通关｜时间耗尽失败｜进度：答对 / 连击 / 剩余时间
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const LIMIT_MS: number = 60000; const TICK_MS: number = 100;
const TARGET: number = 12; const PENALTY_MS: number = 3000; const FEED_MS: number = 480;
interface Quiz { w: string; hint: string }
const BANK: Quiz[] = [
  { w: 'APPLE', hint: TG('苹果') }, { w: 'BRIDGE', hint: TG('桥') }, { w: 'CANDLE', hint: '蜡烛' },
  { w: 'DOCTOR', hint: '医生' }, { w: 'ENGINE', hint: '发动机' }, { w: 'FOREST', hint: '森林' },
  { w: 'GARDEN', hint: TG('花园') }, { w: 'HARBOR', hint: '港口' }, { w: 'ISLAND', hint: '岛屿' },
  { w: 'JUNGLE', hint: '丛林' }, { w: 'KITCHEN', hint: '厨房' }, { w: 'LADDER', hint: '梯子' },
  { w: 'MARKET', hint: '市场' }, { w: 'NEEDLE', hint: '针' }, { w: 'ORCHID', hint: '兰花' },
  { w: 'POCKET', hint: '口袋' }, { w: 'QUARTZ', hint: '石英' }, { w: 'RIBBON', hint: '丝带' },
  { w: 'SILVER', hint: '银' }, { w: 'TEMPLE', hint: '庙宇' }, { w: 'UMBRELLA', hint: '雨伞' },
  { w: 'VILLAGE', hint: '村庄' }, { w: 'WHISPER', hint: '低语' }, { w: 'YELLOW', hint: '黄色' }
];
function mixQuiz(src: Quiz[]): Quiz[] {
  const out: Quiz[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: Quiz = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
function mixText(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GWordSurge {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State hint: string = ''; @State answer: string = ''; @State opts: string[] = [];
  @State hits: number = 0; @State score: number = 0; @State streak: number = 0;
  @State best: number = 0; @State leftMs: number = this.diffTotal; @State picked: number = -1;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private pool: Quiz[] = []; private at: number = 0; private penalty: number = 0;
  private startAt: number = 0; private timer: number = -1; private feed: number = -1;
  private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordSurge')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stopAll(); }
  private stopAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stopAll();
    this.pool = mixQuiz(BANK);
    this.at = 0; this.hits = 0; this.score = 0; this.streak = 0; this.best = 0;
    this.penalty = 0; this.leftMs = this.diffTotal; this.picked = -1;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private load(): void {
    const q: Quiz = this.pool[this.at % this.pool.length];
    const others: string[] = [];
    for (let i = 0; i < this.pool.length; i++) {
      if (this.pool[i].w !== q.w) { others.push(this.pool[i].w); }
    }
    this.answer = q.w; this.hint = q.hint;
    this.opts = mixText(mixText(others).slice(0, 3).concat([q.w]));
    this.picked = -1;
  }
  private tick(): void {
    if (this.over) { return; }
    const gap: number = Date.now() - this.startAt + this.penalty;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) {
      this.over = true; this.msg = TG2("⌛ 时间到 —— 答对 {0} 个", this.hits); this.finish(false);
    }
  }
  /** 提示：和代打同一个循环，只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.answer) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项型直取：找 opts[i] === answer
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.picked >= 0) {
      return true;              // 答完了，等它换下一题
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.answer) {
        this.tap(i);
        return true;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private tap(i: number): void {
    if (this.over || this.picked >= 0 || this.opts.length <= i) { return; }
    this.picked = i;
    if (this.opts[i] === this.answer) {
      this.hits = this.hits + 1; this.streak = this.streak + 1;
      if (this.streak > this.best) { this.best = this.streak; }
      this.score = this.score + 100 + this.streak * 20;
      this.msg = TG2('✅ {0} = {1}（连击 {2}）', this.answer, this.hint, this.streak);
      if (this.hits >= TARGET) {
        this.over = true; this.won = true; this.msg = TG('🎉 答对 ') + TARGET + ' 个，通关！';
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
    } else {
      this.streak = 0; this.penalty = this.penalty + PENALTY_MS;
      this.score = this.score > 30 ? this.score - 30 : 0;
      this.msg = TG2('❌ 正确是 {0}（{1}），扣 3 秒', this.answer, this.hint);
    }
    this.feed = setTimeout(() => { this.feed = -1; this.at = this.at + 1; this.load(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true; this.stopAll();
    const r: GameResult = { gameId: 'word_surge', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private toneAt(i: number): string {
    if (this.picked < 0 || this.opts.length <= i) { return this.theme.surface; }
    if (this.opts[i] === this.answer) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private inkAt(i: number): string {
    if (this.picked >= 0 && this.opts.length > i
      && (this.opts[i] === this.answer || i === this.picked)) { return '#FFFFFF'; }
    return this.theme.ink;
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + TARGET)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('连击'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.streak), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('「' + this.hint + '」').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG('选出对应的英文单词')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => { Text(this.opts.length > (i) ? this.opts[(i)] : '').fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.inkAt((i))).width('100%').height(Cell.of(52)).backgroundColor(this.toneAt((i))).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((i)); }); }) }, (i: number) => 'o' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG2("得分 {0}｜最好连击 {1}｜答错扣 3 秒",Digits(String(this.score), this.langCode),Digits(String(this.best), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
