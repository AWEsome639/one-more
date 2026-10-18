/**
 * 路径回忆 📐
 * 规则：格子依次亮起，连成一条路径；看完后按同样顺序点出来。
 * 胜负：连过 6 轮（路径 3→8 格）⇒ 通关；点错一格 ⇒ 失败。　进度：轮次 / 路径长度 / 已点
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5; const ROUNDS: number = 6; const START: number = 3; const FLASH: number = 520;
const IDXN: number[] = [0, 1, 2, 3, 4];

@Component
export struct GPathRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5）
  //   ⚠️ 原本 ForEach(IDXN, …) 是常量数组，已改成按尺寸生成
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
  @State private seq: number[] = []; @State private playIdx: number = -1; @State private step: number = 0;
  @State private round: number = 1; @State private phase: string = '看';
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  aboutToDisappear(): void { this.halt(); }
  private halt(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.halt(); this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound(1);
  }
  /** 自避路径：每步只走向没走过的邻居；实在走不动就整条重来 */
  private makeSeq(len: number): number[] {
    for (let attempt = 0; attempt < 60; attempt++) {
      const path: number[] = [];
      let cur: number = Math.floor(Math.random() * this.diffTotal * this.diffTotal);
      path.push(cur);
      let bad: boolean = false;
      while (path.length < len && !bad) {
        const r: number = Math.floor(cur / this.diffTotal); const c: number = cur % this.diffTotal;
        const nb: number[] = [];
        if (r > 0) { nb.push(cur - this.diffTotal); }
        if (r < this.diffTotal - 1) { nb.push(cur + this.diffTotal); }
        if (c > 0) { nb.push(cur - 1); }
        if (c < this.diffTotal - 1) { nb.push(cur + 1); }
        const cand: number[] = [];
        for (let i = 0; i < nb.length; i++) { if (path.indexOf(nb[i]) < 0) { cand.push(nb[i]); } }
        if (cand.length === 0) { bad = true; } else {
          cur = cand[Math.floor(Math.random() * cand.length)];
          path.push(cur);
        }
      }
      if (!bad && path.length === len) { return path; }
    }
    const fallback: number[] = [];
    for (let i = 0; i < len; i++) { fallback.push(Math.floor(Math.random() * this.diffTotal * this.diffTotal)); }
    return fallback;
  }
  private newRound(round: number): void {
    this.round = round; this.step = 0; this.seq = this.makeSeq(START + round - 1);
    this.halt(); this.phase = TG('看'); this.playIdx = -1; this.msg = TG('看清亮起的顺序…');
    let i: number = -1;
    this.timer = setInterval(() => {
      i = i + 1;
      if (i >= this.seq.length) {
        this.halt(); this.playIdx = -1; this.phase = TG('点');
        this.msg = TG2("按顺序点出这 {0} 格", String(this.seq.length));
        return;
      }
      this.playIdx = i;
    }, FLASH);
  }
  private inTrail(i: number): boolean {
    for (let k = 0; k < this.step; k++) { if (this.seq[k] === i) { return true; } }
    return false;
  }
  private lit(i: number): boolean {
    const p: number = this.playIdx;
    if (p >= 0 && p < this.seq.length) { return this.seq[p] === i; }
    return this.phase === TG('点') && this.inTrail(i);
  }
  private tap(i: number): void {
    if (this.over || this.phase !== TG('点')) { return; }
    if (i !== this.seq[this.step]) { this.finish(false); return; }
    this.step = this.step + 1;
    if (this.step < this.seq.length) { this.msg = '✅ ' + String(this.step) + '/' + String(this.seq.length); return; }
    if (this.round >= ROUNDS) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
    this.newRound(this.round + 1);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.halt();
    this.over = true; this.won = solved; this.phase = TG('结束'); this.playIdx = -1;
    this.msg = solved ? '🎉 六轮全过，路都记住了！' : '❌ 顺序错了，本局结束';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'path_recall', solved: solved,
      score: solved ? 200 + ROUNDS * 30 : (this.round - 1) * 30 + this.step * 5,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    });
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('路径'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(START + this.round - 1) + TG(' 格'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.step) + '/' + String(this.seq.length))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (c: number) => { Stack() {
            Text(this.lit((r * this.diffTotal + c)) ? '●' : '').fontSize(FontSize.md).fontColor('#FFFFFF')
            }.layoutWeight(1).aspectRatio(1)
            .backgroundColor(this.lit((r * this.diffTotal + c)) ? Palette.sky : this.theme.surfaceAlt)
            .borderRadius(Radius.md)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onClick(() => { this.tap((r * this.diffTotal + c)); }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('86%').aspectRatio(1)
      Text(this.phase === '看' ? '👀 看清顺序' : (this.phase === TG('点') ? '👆 轮到你了' : '🏁 本局结束'))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(this.phase === TG('点') ? Palette.emerald : this.theme.inkSoft)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
