/** 全字母句 —— 句子被抠掉几个字母，从 A–Z 里挑出缺的（6 题答对 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 1000;
const LIMIT_MS: number = 20000; const TICK_MS: number = 100;
const PAN: string = 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG';
const ALPHA: string[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
const ROWS: number[][] = [[0, 1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12, 13, 14, 15, 16, 17],
  [18, 19, 20, 21, 22, 23, 24, 25]];
interface PanQ { text: string; missing: string[] }
function removeAll(text: string, ch: string): string {
  let out: string = '';
  for (let i = 0; i < text.length; i++) {
    const c: string = text.charAt(i);
    if (c !== ch) { out = out + c; }
  }
  return out;
}
function makeQ(): PanQ {
  const k: number = 3 + Math.floor(Math.random() * 3);
  const pool: string[] = ALPHA.slice(); const missing: string[] = [];
  for (let i = 0; i < k; i++) { missing.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
  let text: string = PAN;
  for (let i = 0; i < missing.length; i++) { text = removeAll(text, missing[i]); }
  return { text: text, missing: missing };
}

@Component
export struct GPangramSprint {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State q: PanQ = makeQ(); @State sel: number[] = []; @State qIndex: number = 0;
  @State right: number = 0; @State score: number = 0; @State leftMs: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  @State pressed: number = -1;
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
    this.stop();
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    this.q = makeQ(); this.sel = []; this.leftMs = this.diffTotal; this.roundAt = Date.now();
    this.msg = TG('这句话里少了哪几个字母？');
  }
  private need(): number { return this.q.missing.length; }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：少了 {0}', this.q.missing.join(' ')); this.advance(); }
  }
  private tap(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    const at: number = this.sel.indexOf(i);
    if (at >= 0) { this.sel = this.sel.slice(0, at).concat(this.sel.slice(at + 1)); return; }
    if (this.sel.length >= this.need()) { return; }
    const next: number[] = this.sel.concat([i]);
    this.sel = next;
    if (next.length === this.need()) { this.check(); }
  }
  private check(): void {
    let ok: boolean = true; const mine: string[] = [];
    for (let i = 0; i < this.sel.length; i++) { mine.push(ALPHA[this.sel[i]]); }
    for (let i = 0; i < mine.length; i++) { if (this.q.missing.indexOf(mine[i]) < 0) { ok = false; } }
    if (ok) {
      const gain: number = 120 + Math.floor(this.leftMs / 50);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = TG2('✅ 缺的正是 {0}　+{1}', this.q.missing.join(' '), String(gain));
    } else { this.msg = TG2('❌ 缺的是 {0}', this.q.missing.join(' ')); }
    this.advance();
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'pangram_sprint', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.lime))
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
      Column({ space: Space.xs }) {
        Text(TG('全字母句')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.lime)
        Text(this.q.text).fontSize(FontSize.md).fontColor(this.theme.ink).width('100%')
        Text(TG2("已选 {0}/{1} 个", String(this.sel.length), String(this.need())))
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      ForEach(ROWS, (row: number[]) => {
        Row({ space: Space.xs }) {
          ForEach(row, (i: number) => {
            Text(ALPHA[(i)]).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor(this.sel.indexOf((i)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(40))
            .backgroundColor(this.sel.indexOf((i)) >= 0 ? Palette.lime : this.theme.surface)
            .borderRadius(Radius.xs).shadow(Shadow.card)
            .scale({ x: this.pressed === (i) ? Motion.pressScale : 1, y: this.pressed === (i) ? Motion.pressScale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) { this.pressed = (i); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
            })
            .onClick(() => { this.tap((i)); })
          }, (i: number) => 'lt' + i)
        }.width('100%')
      }, (row: number[], idx: number) => 'row' + idx)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
