/**
 * 数羊 🐑 —— 狼披着羊皮混进羊圈：羊 🐑 是 1 只，狼 🐺 占 2 格
 * 题型一「按格数」：合计占了几格；题型二「按只数」：真正的羊有几只
 * 胜负：10 题答对 ≥7 通关　进度：题号 / 答对 / 得分
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const CELLS: number = N * N;
const TOTAL: number = 10;
const PASS: number = 7;
const NEXT_MS: number = 750;
const SEED: number[] = [5, 11, 23, 41, 62, 78, 91, 104, 137, 158];

/** 把 total 格分给 sheep 只羊 + wolf 只狼（狼吃 2 格）；不够就减羊 */
function build(seed: number): number[] {
  let x: number = seed * 7919 + 104729;
  const rnd: () => number = (): number => {
    x = (x * 48271) % 2147483647;
    return x / 2147483647;
  };
  const out: number[] = new Array<number>(CELLS).fill(0);   // 0 空 1 羊 2 狼
  const sheep: number = 2 + Math.floor(rnd() * 3);
  const wolves: number = 1 + Math.floor(rnd() * 2);
  const need: number = sheep + wolves * 2;
  const pool: number[] = [];
  for (let i = 0; i < CELLS; i++) { pool.push(i); }
  for (let i = pool.length - 1; i > 0; i--) {   // Fisher–Yates 洗牌，取前 need 格
    const j: number = Math.floor(rnd() * (i + 1));
    const t: number = pool[i]; pool[i] = pool[j]; pool[j] = t;
  }
  for (let i = 0; i < need && i < pool.length; i++) {
    out[pool[i]] = i < sheep ? 1 : 2;
  }
  return out;
}

@Component
export struct GCountingSheep {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private byArea: boolean = true;
  @State private opts: number[] = [];
  @State private qi: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private hint: string = '';
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  private reset(): void {
    this.right = 0; this.score = 0; this.qi = 0; this.over = false; this.hint = '';
    this.load(0); this.startAt = Date.now();
  }

  private load(i: number): void {
    const cells: number[] = build(SEED[i]);
    let sheep: number = 0;
    let area: number = 0;
    for (let k = 0; k < cells.length; k++) {
      if (cells[k] === 1) { sheep++; area++; }
      if (cells[k] === 2) { area += 2; }
    }
    const byArea: boolean = i % 2 === 0;
    const ans: number = byArea ? area : sheep;
    const set: number[] = [ans];
    let d: number = 1;
    while (set.length < 4) {
      const a: number = ans + d;
      const b: number = ans - d;
      if (b >= 1) { set.splice(1, 0, b); }
      if (a <= CELLS * 2 && set.length < 4) { set.push(a); }
      d++;
    }
    this.cells = cells; this.byArea = byArea; this.opts = set.slice(0, 4);
    this.qi = i; this.locked = false; this.hint = '';
  }

  private pick(v: number): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    let sheep: number = 0;
    let area: number = 0;
    for (let k = 0; k < this.cells.length; k++) {
      if (this.cells[k] === 1) { sheep++; area++; }
      if (this.cells[k] === 2) { area += 2; }
    }
    const ans: number = this.byArea ? area : sheep;
    if (v === ans) { this.right++; this.score += 100; this.hint = TG(TG(TG('对了 ✅'))); }
    else { this.hint = TG2('答案是 {0} ❌', ans); }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'counting_sheep', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      });
      return;
    }
    this.timer = setTimeout(() => { this.load(this.qi + 1); }, NEXT_MS);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); }
  }





  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", (this.qi + 1), this.diffTotal)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG('答对 ') + this.right).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG('得分 ') + this.score).fontSize(FontSize.md).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')

      Text(this.byArea ? '🐑 按格数：羊占 1 格、狼占 2 格 —— 一共占几格？'
        : '🐑 按只数：别被狼骗了 —— 真正的羊有几只？')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              Stack() {
              Text((this.cells[r * N + c]) === 1 ? '🐑' : ((this.cells[r * N + c]) === 2 ? '🐺' : '')).fontSize(FontSize.xl)
              }
              .layoutWeight(1).aspectRatio(1)
              .backgroundColor((this.cells[r * N + c]) === 0 ? (this.theme.isDark ? '#1A1A1A' : '#F1F5F9') : Palette.amber)
              .borderRadius(Radius.sm)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Text(this.hint.length > 0 ? this.hint : '🐺 是干扰项：按格数时它算 2 格，按只数时它不算羊')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Button(String((this.opts[0])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { this.pick((this.opts[0])); })
        Button(String((this.opts[1])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { this.pick((this.opts[1])); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(String((this.opts[2])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { this.pick((this.opts[2])); })
        Button(String((this.opts[3])))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(50)).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(Palette.teal).borderRadius(Radius.md).shadow(Shadow.card)
        .onClick(() => { this.pick((this.opts[3])); })
      }.width('100%')

      Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .onClick(() => { this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
