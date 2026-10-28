/** 缺元音 —— 元音被挖空，按顺序补回去（6 题答对 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
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

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 900;
const LIMIT_MS: number = 15000; const TICK_MS: number = 100;
const VOWELS: string[] = ['A', 'E', 'I', 'O', 'U']; const VS: number[] = [0, 1, 2, 3, 4];
interface VQ { word: string; def: string }
const BANK: VQ[] = [
  { word: 'APPLE', def: TG('苹果') }, { word: 'ORANGE', def: '橙子' },
  { word: 'BANANA', def: TG('香蕉') }, { word: 'RIVER', def: TG('河流') },
  { word: 'MUSIC', def: '音乐' }, { word: 'PLANET', def: '行星' },
  { word: 'GARDEN', def: TG('花园') }, { word: 'PENCIL', def: TG('铅笔') },
  { word: 'CASTLE', def: '城堡' }, { word: 'TIGER', def: TG('老虎') },
  { word: 'ROBOT', def: '机器人' }, { word: 'WINTER', def: TG('冬天') },
  { word: 'DOCTOR', def: '医生' }, { word: 'SUGAR', def: '糖' }
];
function isVowel(ch: string): boolean { return VOWELS.indexOf(ch) >= 0; }
function pickIndexes(total: number, k: number): number[] {
  const pool: number[] = []; const out: number[] = []; for (let i = 0; i < total; i++) { pool.push(i); }
  while (out.length < k) { out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
  return out;
}

@Component
export struct GMissingVowels {
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
  onFinish: (r: GameResult) => void = () => {};
  @State queue: number[] = []; @State qIndex: number = 0; @State right: number = 0;
  @State score: number = 0; @State filled: string[] = []; @State leftMs: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop(); this.queue = pickIndexes(BANK.length, QN);
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.startAt = Date.now(); this.load();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private word(): string { return this.qIndex >= QN ? '' : BANK[this.queue[this.qIndex]].word; }
  private blanks(): number {
    let n: number = 0; const w: string = this.word();
    for (let i = 0; i < w.length; i++) { if (isVowel(w.charAt(i))) { n = n + 1; } }
    return n;
  }
  private load(): void { this.filled = []; this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('依次点元音，补全这个单词'); }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：答案是 {0}', this.word()); this.advance(); }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 没有"答案字段"—— 答案就是当前单词的元音序列，按顺序一个个点
  /** 当前该点的下一个元音（'' = 没有了） */
  private aiNextVowel(): string {
    const w: string = this.word();
    let k: number = 0;
    for (let i = 0; i < w.length; i++) {
      const ch: string = w.charAt(i);
      if (isVowel(ch)) {
        if (k === this.filled.length) {
          return ch;
        }
        k = k + 1;
      }
    }
    return '';
  }

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
    if (this.feed >= 0) {
      return true;              // 反馈中，等下一题
    }
    const v: string = this.aiNextVowel();
    if (v.length === 0) {
      return false;
    }
    this.tap(v);
    return !this.over;
  }

  /** 提示：报下一个该点的元音（单词已显示，报字母而不是下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.feed >= 0) {
      return Hint.none('none');
    }
    const v: string = this.aiNextVowel();
    if (v.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('下一个元音是 {0}（第 {1} 个）', v, this.filled.length + 1),
      TG2('Next vowel: {0}', v), t0);
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

  private tap(v: string): void {
    if (this.over || this.feed >= 0 || this.filled.length >= this.blanks()) { return; }
    const next: string[] = this.filled.concat([v]); this.filled = next;
    if (next.length === this.blanks()) { this.check(); }
  }
  private back(): void {
    if (this.over || this.feed >= 0 || this.filled.length === 0) { return; } else { this.filled = this.filled.slice(0, this.filled.length - 1); }
  }
  private fill(forShow: boolean): string {
    const w: string = this.word(); const parts: string[] = []; let k: number = 0;
    for (let i = 0; i < w.length; i++) {
      const ch: string = w.charAt(i);
      if (isVowel(ch)) { parts.push(k < this.filled.length ? this.filled[k] : (forShow ? '_' : '')); k = k + 1; } else { parts.push(ch); }
    }
    return parts.join(forShow ? ' ' : '');
  }
  private check(): void {
    const w: string = this.word();
    if (this.fill(false) === w) {
      const gain: number = 100 + Math.floor(this.leftMs / 40); this.right = this.right + 1; this.score = this.score + gain;
      this.msg = '✅ ' + w + '　' + BANK[this.queue[this.qIndex]].def + '　+' + String(gain);
    } else { this.msg = TG2('❌ 应该是 {0}', w); }
    this.advance();
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.load(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'missing_vowels', solved: solved, score: this.score,
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
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.teal))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        Text(this.qIndex < QN ? BANK[this.queue[this.qIndex]].def : '')
          .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(this.fill(true)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
          .textAlign(TextAlign.Center).width('100%')
        Text(TG2('缺 {0} 个元音', String(this.blanks()))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        ForEach(VS, (i: number) => {
          Text(VOWELS[(i)]).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(58)).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).shadow(Shadow.card)
          .scale({ x: this.pressed === (i) ? Motion.pressScale : 1, y: this.pressed === (i) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; } })
          .onClick(() => { Haptics.tick(); this.tap(VOWELS[(i)]); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(VOWELS[(i)]); }); })
        }, (i: number) => 'v' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('退一格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.back(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.back(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
