/** 回文构造 —— 用给定的字母摆出回文（6 题解出 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 900;
const LIMIT_MS: number = 25000; const TICK_MS: number = 100;
const WORDS: string[] = ['RACECAR', 'LEVEL', 'RADAR', 'MADAM', 'REFER', 'KAYAK',
  'CIVIC', 'DEIFIED', 'ROTATOR', 'SOLOS', 'MINIM', 'NOON'];
function shuffled(text: string): string[] {
  const out: string[] = text.split('');
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: string = out[i]; out[i] = out[j]; out[j] = tmp;
  }
  return out;
}
function isPalindrome(s: string): boolean {
  let i: number = 0; let j: number = s.length - 1;
  while (i < j) {
    if (s.charAt(i) !== s.charAt(j)) { return false; } else { i = i + 1; j = j - 1; }
  }
  return true;
}

@Component
export struct GPalindromeBuilder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State word: string = ''; @State pool: string[] = []; @State used: number[] = [];
  @State qIndex: number = 0; @State right: number = 0; @State score: number = 0;
  @State leftMs: number = this.diffTotal; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false; @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private reset(): void {
    this.stop(); this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    const w: string = WORDS[Math.floor(Math.random() * WORDS.length)];
    this.word = w; this.pool = shuffled(w); this.used = [];
    this.leftMs = this.diffTotal; this.roundAt = Date.now(); this.msg = TG('按顺序点字母，摆出一个回文');
  }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：例如 {0}', this.word); this.advance(); }
  }
  private tap(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    if (i >= this.pool.length || this.used.indexOf(i) >= 0) { return; }
    const next: number[] = this.used.concat([i]); this.used = next;
    if (next.length >= this.pool.length) { this.check(); }
  }
  private back(): void {
    if (this.over || this.feed >= 0 || this.used.length === 0) { return; } else { this.used = this.used.slice(0, this.used.length - 1); }
  }
  private built(full: boolean): string {
    const parts: string[] = [];
    for (let i = 0; i < this.pool.length; i++) {
      parts.push(i < this.used.length ? this.pool[this.used[i]] : (full ? '' : '·'));
    }
    return parts.join(full ? '' : ' ');
  }
  private check(): void {
    const s: string = this.built(true);
    if (isPalindrome(s)) {
      const gain: number = 100 + Math.floor(this.leftMs / 60); this.right = this.right + 1; this.score = this.score + gain;
      this.msg = TG2('✅ {0} 是回文　+{1}', s, String(gain));
      this.advance();
      return;
    }
    this.msg = TG2('❌ {0} 正读倒读不一样，再摆一次', s); this.used = [];
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("解出 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'palindrome_builder', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
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
        Text(TG('摆出的回文')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.built(false)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
          .textAlign(TextAlign.Center).width('100%')
        Text(TG2("共 {0} 个字母，已用 {1}", String(this.pool.length), String(this.used.length)))
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(this.pool, (ch: string, i: number) => {
          Text((ch)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.used.indexOf((i)) >= 0 ? this.theme.inkFaint : this.theme.ink)
          .layoutWeight(1).height(Cell.of(54))
          .backgroundColor(this.used.indexOf((i)) >= 0 ? this.theme.line : this.theme.surface)
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .scale({ x: this.pressed === (i) ? Motion.pressScale : 1, y: this.pressed === (i) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onTouch((e: TouchEvent) => { if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; } })
          .onClick(() => { Haptics.tick(); this.tap((i)); })
        }, (ch: string, i: number) => 'p' + i)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('退一格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.back(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
