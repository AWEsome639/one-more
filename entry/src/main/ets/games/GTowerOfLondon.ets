/** 伦敦塔 📐（id: tower_of_london）
 * 每次搬一个球、大球不许压小球，把三球摆成目标；摆成 ⇒ 通关，超出「最少步 + 5」⇒ 失败。 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const PEGS: number = 3;
const BALLS: number = 3;
const STATES: number = 27;
const SLACK: number = 5;
/** 三进制权重：球 b 所在柱 = (state / W[b-1]) % 3，球 1 最小 */
const W: number[] = [9, 3, 1];
const COLORS: string[] = [Palette.emerald, Palette.sky, Palette.violet];
const TOWERS: number[] = [0, 1, 2];
@Component
export struct GTowerOfLondon {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 PEGS=3
  @State private diffTotal: number = GameDiff.sizeNow(3);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State state: number = 0;
  @State goalState: number = 1;
  @State sel: number = -1;
  @State moves: number = 0;
  @State best: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State note: string = '';
  private startAt: number = 0;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(3);
     this.reset(); }
  private reset(): void {
    const a: number = Math.floor(Math.random() * STATES);
    let b: number = Math.floor(Math.random() * STATES);
    for (let i = 0; i < 40 && b === a; i++) { b = Math.floor(Math.random() * STATES); }
    this.state = a; this.goalState = b; this.sel = -1; this.moves = 0; this.best = this.bfs(a, b);
    this.over = false; this.won = false; this.done = false;
    this.note = TG('每次搬一个球 · 大球不能压小球 · 摆成目标'); this.startAt = Date.now();
  }
  private ballAt(s: number, b: number): number { return Math.floor(s / W[b - 1]) % this.diffTotal; }
  /** 球 b 能不能落到柱 c：柱 c 上不能有比它更小的球 */
  private canPut(s: number, b: number, c: number): boolean {
    for (let o = 1; o < b; o++) { if (this.ballAt(s, o) === c) { return false; } }
    return true;
  }
  private topBall(s: number, i: number): number {
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === i) { return b; } }
    return -1;
  }
  /** 广度优先求最少步数（合法状态只有 27 种） */
  private bfs(from: number, to: number): number {
    const dist: number[] = new Array<number>(STATES).fill(-1);
    const q: number[] = [from];
    dist[from] = 0;
    for (let h = 0; h < q.length; h++) {
      const s: number = q[h];
      if (s === to) { return dist[s]; }
      for (let b = 1; b <= BALLS; b++) {
        const a: number = this.ballAt(s, b);
        for (let c = 0; c < this.diffTotal; c++) {
          const nx: number = s + (c - a) * W[b - 1];
          if (c !== a && this.canPut(s, b, c) && dist[nx] < 0) { dist[nx] = dist[s] + 1; q.push(nx); }
        }
      }
    }
    return BALLS * 2;
  }
  private rightCount(s: number): number {
    let n: number = 0;
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === this.ballAt(this.goalState, b)) { n++; } }
    return n;
  }
  /** 柱上的球，从上到下（小球在上） */
  private stack(s: number, i: number): number[] {
    const out: number[] = [];
    for (let b = 1; b <= BALLS; b++) { if (this.ballAt(s, b) === i) { out.push(b); } }
    return out;
  }
  private tap(i: number): void {
    if (this.over) { return; }
    if (this.sel < 0) {
      const top: number = this.topBall(this.state, i);
      if (top < 0) { this.note = TG('这根柱是空的'); return; }
      this.sel = i; this.note = TG2('拿起 {0} 号球', String(top));
      return;
    }
    if (this.sel === i) { this.sel = -1; this.note = TG('放回原处，重新选'); return; }
    const ball: number = this.topBall(this.state, this.sel);
    if (!this.canPut(this.state, ball, i)) { this.note = TG('❌ 大球不能压在小球上'); return; }
    const next: number = this.state + (i - this.sel) * W[ball - 1];
    this.state = next; this.moves++; this.sel = -1;
    if (next === this.goalState) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    if (this.moves >= this.best + SLACK) { this.note = TG('步数用光了'); this.finish(false); return; }
    this.note = TG2('✅ 好，继续 · 对位 {0}/{1}', String(this.rightCount(next)), String(BALLS));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = solved; const r: GameResult = {
      gameId: 'tower_of_london', solved: solved,
      score: solved ? Math.max(40, 220 - (this.moves - this.best) * 20) : 0,
      durationMs: Date.now() - this.startAt, levelReached: solved ? 1 : 0
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.sm }) {
      Text(TG2('步数 {0} · 最少 {1} · 上限 {2}',Digits(String(this.moves), this.langCode),Digits(String(this.best), this.langCode), String(this.best + SLACK)) +
        TG2(' · 对位 {0}/{1}', String(this.rightCount(this.state)), String(BALLS)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md)
      Text(TG('目标 · 照着它摆')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
      Row({ space: Space.xs }) {
      ForEach(TOWERS, (i: number) => {
      Column({ space: 2 }) {
      Column({ space: 2 }) {
      ForEach(this.stack(((this.goalState)), (i)), (d: number) => {
      Stack() {
      Text(String(d)).fontSize(FontSize.xxs).fontColor('#FFFFFF')
      }
      .width((((false)) ? Space.xl : Space.md) + d * Space.md).height(((false)) ? Space.lg : Space.sm)
      .backgroundColor(COLORS[d - 1]).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
      }, (d: number) => 'b' + d + '_' + (i) + (((false)) ? 'L' : 'G'))
      }
      .layoutWeight(1).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
      Stack()
      .width('100%').height(Space.xs).borderRadius(Radius.xs)
      .backgroundColor(((false)) && this.sel === (i) ? Palette.amber : this.theme.lineSoft)
      }
      .layoutWeight(1).height('100%').padding(Space.xs).borderRadius(Radius.md)
      .borderWidth(((false)) && this.sel === (i) ? 2 : 0).borderColor(Palette.amber).onClick(() => { Haptics.tick(); if (((false))) { this.tap((i)); } })
      }, (i: number) => ((false) ? 'lp' : 'gp') + i)
      }
      .width('100%').height((false) ? Space.xxxl * 3 : Space.xxxl * 2).padding(Space.xs)
      .borderRadius(Radius.lg).backgroundColor((false) ? this.theme.surface : this.theme.surfaceAlt).shadow(Shadow.card)
      Row({ space: Space.xs }) {
      ForEach(TOWERS, (i: number) => {
      Column({ space: 2 }) {
      Column({ space: 2 }) {
      ForEach(this.stack(((this.state)), (i)), (d: number) => {
      Stack() {
      Text(String(d)).fontSize(FontSize.xxs).fontColor('#FFFFFF')
      }
      .width((((true)) ? Space.xl : Space.md) + d * Space.md).height(((true)) ? Space.lg : Space.sm)
      .backgroundColor(COLORS[d - 1]).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
      }, (d: number) => 'b' + d + '_' + (i) + (((true)) ? 'L' : 'G'))
      }
      .layoutWeight(1).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
      Stack()
      .width('100%').height(Space.xs).borderRadius(Radius.xs)
      .backgroundColor(((true)) && this.sel === (i) ? Palette.amber : this.theme.lineSoft)
      }
      .layoutWeight(1).height('100%').padding(Space.xs).borderRadius(Radius.md)
      .borderWidth(((true)) && this.sel === (i) ? 2 : 0).borderColor(Palette.amber).onClick(() => { Haptics.tick(); if (((true))) { this.tap((i)); } })
      }, (i: number) => ((true) ? 'lp' : 'gp') + i)
      }
      .width('100%').height((true) ? Space.xxxl * 3 : Space.xxxl * 2).padding(Space.xs)
      .borderRadius(Radius.lg).backgroundColor((true) ? this.theme.surface : this.theme.surfaceAlt).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center).width('100%')
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md)
        .fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
