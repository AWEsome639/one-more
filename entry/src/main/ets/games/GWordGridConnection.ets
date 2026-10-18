/**
 * 词格连线 —— 4×4 词格里点两个意思相近的词，把它们连成一对
 * 胜负：连完 8 对通关｜连错 5 次失败｜进度：已连 / 失误 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const N: number = 4; const MAX_MISS: number = 5; const PAIR_N: number = 8;
interface WordPair { a: string; b: string }
const PAIRS: WordPair[] = [
  { a: 'BIG', b: 'LARGE' }, { a: 'FAST', b: 'QUICK' }, { a: 'HAPPY', b: 'GLAD' }, { a: 'SMALL', b: 'TINY' },
  { a: 'ANGRY', b: 'MAD' }, { a: 'BEGIN', b: 'START' }, { a: 'HARD', b: 'TOUGH' }, { a: 'SMART', b: 'CLEVER' }
];
function mixWords(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}
@Component
export struct GWordGridConnection {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State cells: string[] = []; @State done: boolean[] = []; @State sel: number[] = [];
  @State score: number = 0; @State miss: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  private reset(): void {
    const pool: string[] = [];
    for (let i = 0; i < PAIRS.length; i++) { pool.push(PAIRS[i].a); pool.push(PAIRS[i].b); }
    this.cells = mixWords(pool); this.done = new Array<boolean>(this.diffTotal * this.diffTotal).fill(false);
    this.sel = []; this.score = 0; this.miss = 0; this.over = false; this.won = false;
    this.settled = false; this.startAt = Date.now();
    this.msg = TG('点两个意思相近的词，把它们连起来');
  }
  private related(w1: string, w2: string): boolean {
    for (let i = 0; i < PAIRS.length; i++) {
      const p: WordPair = PAIRS[i];
      if ((p.a === w1 && p.b === w2) || (p.a === w2 && p.b === w1)) { return true; }
    }
    return false;
  }
  private linked(): number {
    let n: number = 0;
    for (let i = 0; i < this.done.length; i++) { if (this.done[i]) { n++; } }
    return n / 2;
  }
  private tap(i: number): void {
    if (this.over || (this.done.length > i && this.done[i])) { return; }
    if (this.sel.length === 0) { this.sel = [i]; this.msg = TG('再点一个意思相近的词'); return; }
    const first: number = this.sel[0];
    if (first === i) { this.sel = []; this.msg = TG('已取消选择'); return; }
    const w1: string = this.cells[first]; const w2: string = this.cells[i];
    if (this.related(w1, w2)) {
      const next: boolean[] = this.done.slice(); next[first] = true; next[i] = true;
      this.done = next; this.sel = []; this.score = this.score + 120;
      if (this.linked() >= PAIR_N) {
        this.over = true; this.won = true; this.msg = TG('🎉 8 对全部连上，通关！'); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      } else { this.msg = TG2('✅ {0} ↔ {1} 连上了', w1, w2); }
      return;
    }
    this.sel = []; this.miss = this.miss + 1;
    this.score = this.score > 20 ? this.score - 20 : 0;
    if (this.miss >= MAX_MISS) {
      this.over = true; this.msg = TG2('❌ 连错 {0} 次，本局结束', MAX_MISS); this.finish(false);
    } else { this.msg = TG2("❌ {0} 与 {1} 意思不相近", w1, w2); }
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true;
    const r: GameResult = { gameId: 'word_grid_connection', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.linked() };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private inkOf(i: number): string {
    if (this.done.length > i && this.done[i]) { return '#FFFFFF'; }
    return this.sel.indexOf(i) >= 0 ? '#FFFFFF' : this.theme.ink;
  }
  private bgOf(i: number): string {
    if (this.done.length > i && this.done[i]) { return Palette.emerald; }
    return this.sel.indexOf(i) >= 0 ? Palette.primary : this.theme.surface;
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('已连'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.linked() + ' / ' + PAIR_N)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.miss + ' / ' + MAX_MISS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => { Text(this.cells.length > (r * this.diffTotal + c) ? this.cells[(r * this.diffTotal + c)] : '').fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.inkOf((r * this.diffTotal + c))).layoutWeight(1).aspectRatio(1).backgroundColor(this.bgOf((r * this.diffTotal + c))).borderRadius(Radius.sm).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { this.tap((r * this.diffTotal + c)); }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG2('提示：8 对同义词混在 16 格里；连错扣分，错满 {0} 次结束', MAX_MISS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
