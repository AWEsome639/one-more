/**
 * 找词 —— 在 6×6 字母盘里按顺序连点，拼出词库中的单词
 * 胜负：60 秒内找出 ≥5 个通关｜进度：已找到 / 目标 / 倒计时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6; const CELLS: number = N * N;
const WORDS: string[] = ['CAT', 'DOG', 'SUN', 'MAP', 'PEN', 'BOX', 'ICE', 'JAM', 'KEY', 'OWL', 'RAT', 'TUB'];
const ALL_LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const LIMIT_MS: number = 60000; const TICK_MS: number = 100; const PASS: number = 5;
const HIT_MS: number = 700;

@Component
export struct GFindWord {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State g: string[] = []; @State path: number[] = []; @State found: string[] = [];
  @State score: number = 0; @State leftMs: number = this.diffTotal; @State msg: string = '';
  @State locked: boolean = false; @State over: boolean = false; @State won: boolean = false;
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
    const grid: string[] = [];
    for (let i = 0; i < CELLS; i++) {
      grid.push(ALL_LETTERS[Math.floor(Math.random() * ALL_LETTERS.length)]);
    }
    const placed: string[] = WORDS.slice();
    for (let i = placed.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = placed[i]; placed[i] = placed[j]; placed[j] = t;
    }
    const want: number = PASS + 3;
    for (let k = 0; k < want; k++) {
      const w: string = placed[k];
      const base: number = Math.floor(k / 2) * N + (k % 2 === 0 ? 0 : N - w.length);
      for (let c = 0; c < w.length; c++) {
        grid[base + c] = w[c];
      }
    }
    this.g = grid;
    this.path = []; this.found = []; this.score = 0; this.leftMs = this.diffTotal;
    this.locked = false; this.over = false; this.won = false; this.done = false;
    this.msg = TG('按顺序连点字母，拼出 3 个字母的单词'); this.startAt = Date.now(); this.roundAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    if (this.over || this.locked) { return; }
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) {
      this.over = true; this.won = false;
      this.msg = TG2("⌛ 时间到 —— 共找到 {0} 个词", this.found.length);
      this.finish(false);
    }
  }
  private guess(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.path.length; i++) { parts.push(this.g[this.path[i]]); }
    return parts.join('');
  }
  private tap(i: number): void {
    if (this.over || this.locked) { return; }
    if (this.path.indexOf(i) >= 0) { return; }
    this.path = this.path.concat([i]);
    if (this.path.length >= 3) { this.check(); }
  }
  private check(): void {
    const w: string = this.guess();
    if (WORDS.indexOf(w) >= 0 && this.found.indexOf(w) < 0) {
      this.found = this.found.concat([w]);
      this.score = this.score + 100 + Math.floor(this.leftMs / 500); this.msg = TG2('✅ 找到 {0}', w);
      if (this.found.length >= PASS) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 通关：找到 {0} 个词", this.found.length);
        this.path = [];
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
    } else {
      this.msg = WORDS.indexOf(w) >= 0 ? TG2("🔁 {0} 已经找过啦", w) : TG2("❌ {0} 不在词库里", w);
    }
    this.locked = true;
    this.feed = setTimeout(() => { this.feed = -1; this.locked = false; this.path = []; }, HIT_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'find_word', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.found.length };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('已找'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found.length + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.lime))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(this.guess().length > 0 ? this.guess() : '· · ·').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.lime)
        Text(TG('当前拼：先点首字母')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Text(this.g.length > (r * N + c) ? this.g[(r * N + c)] : '').fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.path.indexOf((r * N + c)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).aspectRatio(1).backgroundColor(this.path.indexOf((r * N + c)) >= 0 ? Palette.lime : this.theme.surface).borderRadius(Radius.sm).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * N + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.sm }) {
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).enabled(!this.over).onClick(() => { Haptics.tap(); this.path = []; this.locked = false; this.msg = TG('已清空，重新连'); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')

      Text(TG2('提示：横竖相邻即可，拼 3 个字母；{0} 个通关', PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
