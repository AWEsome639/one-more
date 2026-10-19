/** 多目标追踪 —— 高亮目标混进圆点里移动，停下后指出来；3 轮全对 ≥2 轮通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const CELLS: number = N * N;
const DOTS: number = 7;
const ROUNDS: number = 3;
const TICK_MS: number = 420;
const TICKS: number = 6;
const SHOW_MS: number = 1700;

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GMultipleObjectTracking {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private pos: number[] = [];
  @State private targets: number = 3;
  @State private picks: number[] = [];
  @State private good: number[] = [];
  @State private missed: number[] = [];
  @State private round: number = 1;
  @State private hitRounds: number = 0;
  @State private score: number = 0;
  @State private phase: number = 0;   // 0 高亮 / 1 移动 / 2 作答 / 3 揭晓 / 4 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private ticks: number = 0;
  private moveId: number = -1;
  private showTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.moveId >= 0) { clearInterval(this.moveId); this.moveId = -1; } if (this.showTo >= 0) { clearTimeout(this.showTo); this.showTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.hitRounds = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const cnt: number = 1 + this.round;
    const slots: number[] = [];
    for (let i = 0; i < CELLS; i++) { slots.push(i); }
    for (let i = slots.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = slots[i]; slots[i] = slots[j]; slots[j] = t;
    }
    this.targets = cnt;
    this.pos = slots.slice(0, DOTS);
    this.picks = []; this.good = []; this.missed = []; this.phase = 0;
    this.msg = TG2('盯住 {0} 个高亮目标', String(cnt));
    this.showTo = setTimeout(() => {
      this.showTo = -1; this.phase = 1; this.ticks = 0; this.msg = TG(TG(TG('它们动起来了，盯住')));
      this.moveId = setInterval(() => { this.step(); }, TICK_MS);
    }, SHOW_MS);
  }

  /** 每一拍让两对圆点互换位置，看起来就在移动 */
  private step(): void {
    if (this.phase !== 1) { return; }
    for (let k = 0; k < 2; k++) {
      const i: number = Math.floor(Math.random() * DOTS);
      let j: number = Math.floor(Math.random() * DOTS);
      if (j === i) { j = (j + 1) % DOTS; }
      const next: number[] = this.pos.slice();
      const t: number = next[i]; next[i] = next[j]; next[j] = t;
      this.pos = next;
    }
    this.ticks = this.ticks + 1;
    if (this.ticks >= TICKS) {
      if (this.moveId >= 0) { clearInterval(this.moveId); this.moveId = -1; }
      this.phase = 2;
      this.msg = TG(TG(TG('停！点出刚才的高亮目标')));
    }
  }

  private tap(i: number): void {
    if (this.over || this.phase !== 2 || has(this.picks, i)) { return; }
    const next: number[] = this.picks.slice();
    next.push(i);
    this.picks = next;
    if (next.length < this.targets) {
      this.msg = TG('还差 ') + String(this.targets - next.length) + TG(' 个');
      return;
    }
    this.judge();
  }

  private judge(): void {
    const tgt: number[] = this.pos.slice(0, this.targets);
    const good: number[] = [];
    const missed: number[] = [];
    for (let i = 0; i < this.picks.length; i++) { if (has(tgt, this.picks[i])) { good.push(this.picks[i]); } }
    for (let i = 0; i < tgt.length; i++) { if (!has(this.picks, tgt[i])) { missed.push(tgt[i]); } }
    this.good = good;
    this.missed = missed;
    this.score = this.score + good.length * 100;
    if (good.length === this.targets) { this.hitRounds = this.hitRounds + 1; }
    this.phase = 3;
    this.msg = good.length === this.targets ? '✅ 全对' : TG2("差了 {0} 个", String(missed.length));
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.phase = 4; this.over = true; this.won = this.hitRounds >= 2;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("全对 {0}/{1} 轮", String(this.hitRounds), String(this.diffTotal));
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.newRound();
    }, 1300);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'multiple_object_tracking', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 3 || this.phase === 4) {
      if (has(this.good, i)) { return Palette.emerald; }
      if (has(this.missed, i)) { return Palette.amber; }
      return has(this.picks, i) ? Palette.rose : this.theme.surfaceAlt;
    }
    if (!has(this.pos, i)) { return this.theme.surfaceAlt; }
    if (this.phase === 0) { return has(this.pos.slice(0, this.targets), i) ? Palette.amber : this.theme.lineSoft; }
    if (this.phase === 2 && has(this.picks, i)) { return Palette.primary; }
    return this.theme.lineSoft;
  }

  /** 圆点本身的颜色：目标格用白点，其余用深点 */
  private dotInk(i: number): string {
    if (this.phase === 0) { return has(this.pos.slice(0, this.targets), i) ? '#FFFFFF' : '#334155'; }
    if (this.phase === 2 && has(this.picks, i)) { return '#FFFFFF'; }
    if (this.phase >= 3) { return has(this.good, i) || has(this.missed, i) ? '#FFFFFF' : this.theme.surfaceAlt; }
    return this.theme.surface;
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("轮次 {0}", (String(this.round) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2('目标 {0}', String(this.targets))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2('全对 {0}', String(this.hitRounds))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：先扫全场再锁定目标；目标数 3/4/5 递增'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(has(this.pos, i) ? '●' : '').fontSize(FontSize.lg).fontColor(this.dotInk(i))
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
