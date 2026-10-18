/** 向量对齐 —— 对齐向量网格
 *  玩法：网格上给出起点与目标格，按方向键走「向量 (dx, dy)」那么多步，把点走进目标格
 *  胜负：5 个向量全对齐 ⇒ 通关；某回合步数用尽还没对齐 ⇒ 失败 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const N: number = 5; const ROUNDS: number = 5; const NEXT_MS: number = 700;
function sign(n: number): string { return n >= 0 ? '+' + String(n) : String(n); }
@Component
export struct GVectorGridAlignment {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  @State private diffTotal: number = GameDiff.sizeNow(5);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private pos: number = 0; @State private goal: number = 0; @State private vecX: number = 1;
  @State private vecY: number = 1; @State private round: number = 1; @State private cleared: number = 0;
  @State private movesLeft: number = 0; @State private score: number = 0; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.startAt = Date.now(); this.done = false; this.round = 1; this.cleared = 0; this.score = 0; this.over = false;
    this.won = false; this.genRound(); this.msg = TG('按方向键，把 🧭 走到 🎯');
  }
  private genRound(): void {
    let ok: boolean = false; let px: number = 1; let py: number = 1; let p0: number = 0; let g0: number = 6;
    let mv: number = 4;
    for (let k = 0; k < 60 && !ok; k++) {
      const tr: number = Math.floor(Math.random() * this.diffTotal); const tc: number = Math.floor(Math.random() * this.diffTotal);
      const dx: number = (Math.random() < 0.5 ? -1 : 1) * (1 + Math.floor(Math.random() * 3));
      const dy: number = (Math.random() < 0.5 ? -1 : 1) * (1 + Math.floor(Math.random() * 3));
      const sr: number = tr - dy; const sc: number = tc - dx;
      if (sr >= 0 && sr < this.diffTotal && sc >= 0 && sc < this.diffTotal) {
        px = dx; py = dy; p0 = sr * this.diffTotal + sc; g0 = tr * this.diffTotal + tc; mv = Math.abs(dx) + Math.abs(dy) + 2; ok = true;
      }
    }
    this.vecX = px; this.vecY = py; this.pos = p0; this.goal = g0; this.movesLeft = mv;
  }
  private move(dx: number, dy: number): void {
    if (this.over || this.nextTo >= 0) { return; }
    const r: number = Math.floor(this.pos / this.diffTotal) + dy; const c: number = (this.pos % this.diffTotal) + dx;
    if (r < 0 || r >= this.diffTotal || c < 0 || c >= this.diffTotal) { this.msg = TG('🧱 出界了，换个方向'); return; }
    this.pos = r * this.diffTotal + c; this.movesLeft = this.movesLeft - 1;
    if (this.pos === this.goal) {
      this.cleared = this.cleared + 1; this.score = this.score + 20 + this.movesLeft * 5; this.msg = TG('✅ 对齐成功！');
      if (this.cleared >= ROUNDS) {
        this.over = true; this.won = true; this.msg = TG2('🎉 {0} 个向量全部对齐！', String(ROUNDS)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.nextTo = setTimeout(() => {
        this.nextTo = -1; this.round = this.round + 1; this.genRound(); this.msg = TG('新向量来了，继续对齐');
      }, NEXT_MS);
      return;
    }
    if (this.movesLeft <= 0) {
      this.over = true; this.won = false; this.msg = TG('😵 步数用尽，还没走进 🎯'); this.finish(false); return;
    }
    const gapC: number = (this.goal % this.diffTotal) - (this.pos % this.diffTotal);
    const gapR: number = Math.floor(this.goal / this.diffTotal) - Math.floor(this.pos / this.diffTotal);
    this.msg = TG2("还差 {0} 列、{1} 行", String(gapC), String(gapR));
  }
  private finish(solved: boolean): void { if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'vector_grid_alignment', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cleared };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r); }

  private cellKey(i: number): string { return 'g' + i + (this.pos === i ? 'p' : '') + (this.goal === i ? 't' : ''); }
  private cellInk(i: number): string {
    if (this.pos === i) { return '#FFFFFF'; }
    return this.theme.ink;
  }
  private cellBg(i: number): string {
    if (this.pos === i) { return Palette.berry; }
    return this.goal === i ? this.theme.surfaceAlt : this.theme.bg;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('回合'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.movesLeft), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
        .shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG2('➡️ 向量 v = ({0}, {1})', sign(this.vecX), sign(this.vecY))).fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold).fontColor(Palette.berry)
        Column({ space: Space.xs }) {
          ForEach(this.rowIdx(), (r: number) => {
            Row({ space: Space.xs }) {
              ForEach(this.rowIdx(), (c: number) => {
                Stack() {
                Text(this.pos === (r * this.diffTotal + c) ? '🧭' : (this.goal === (r * this.diffTotal + c) ? '🎯' : '')).fontSize(FontSize.lg).fontColor(this.cellInk((r * this.diffTotal + c)))
                }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cellBg((r * this.diffTotal + c))).borderRadius(Radius.sm)
                .border({ width: this.goal === (r * this.diffTotal + c) ? 2 : 1, color: this.goal === (r * this.diffTotal + c) ? Palette.emerald : this.theme.line })
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => this.cellKey(r * this.diffTotal + c))
            }.width('100%')
          }, (r: number) => 'r' + r)
        }.width('100%').aspectRatio(1).padding(Space.xs).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.lg)
        Text(TG('(dx, dy)：+ 列向右、+ 行向下')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Button(('←'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.move((-1), (0));
        })
        Button(('↑'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.move((0), (-1));
        })
        Button(('↓'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.move((0), (1));
        })
        Button(('→'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(50)).animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => {
        this.move((1), (0));
        })
      }.width('100%')
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46)).onClick(() => {
          this.reset();
        })
      Text(TG('提示：走错一步要花两步补回来，步数很紧')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
