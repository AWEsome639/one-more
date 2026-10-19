/**
 * 色相排序 —— 交换格子，把 16 个色块按色相排成一道彩虹
 * 胜负：18 步内排成严格递增 ⇒ 通关｜进度：已归位 / 16 + 剩余步数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4;
const MAX_MOVES: number = 18;
const R4: number[] = [0, 1, 2, 3];

function hueColor(h: number): string {  // hsl(h,100%,55%) → #RRGGBB
  const c: number = 1 - Math.abs(2 * 0.55 - 1);
  const hp: number = h / 60;
  const x: number = c * (1 - Math.abs(hp % 2 - 1));
  let r: number = 0; let g: number = 0; let b: number = 0;
  if (hp < 1) { r = c; g = x; } else if (hp < 2) { r = x; g = c; }
  else if (hp < 3) { g = c; b = x; } else if (hp < 4) { g = x; b = c; }
  else if (hp < 5) { r = x; b = c; } else { r = c; b = x; }
  const m: number = 0.55 - c / 2;
  const rgb: number[] = [Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255)];
  let out: string = '#';
  for (let i = 0; i < 3; i++) {
    const s: string = rgb[i].toString(16).toUpperCase();
    out = out + (s.length < 2 ? '0' + s : s);
  }
  return out;
}

@Component
export struct GHueSort {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State hues: number[] = [];
  @State sel: number = -1; @State moves: number = 0; @State score: number = 0;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
     this.reset(); }

  private reset(): void {
    const mixed: number[] = [];
    for (let i = 0; i < N * N; i++) { mixed.push(Math.round(i * 360 / (N * N))); }
    for (let i = mixed.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = mixed[i]; mixed[i] = mixed[j]; mixed[j] = t;
    }
    this.hues = mixed; this.sel = -1; this.moves = 0; this.score = 0;
    this.msg = TG(TG(TG('先点一块，再点另一块交换')));
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
  }

  /** 从左上起连续「比前一块色相大」的格子数 */
  private fixed(): number {
    let n: number = 1;
    for (let i = 1; i < this.hues.length; i++) {
      if (this.hues[i] > this.hues[i - 1]) { n++; } else { break; }
    }
    return this.hues.length === 0 ? 0 : n;
  }

  private sortedAll(): boolean {
    for (let i = 1; i < this.hues.length; i++) {
      if (this.hues[i] <= this.hues[i - 1]) { return false; }
    }
    return true;
  }

  private tap(i: number): void {
    if (this.over) { return; }
    if (this.sel < 0) { this.sel = i; this.msg = TG(TG(TG('已选中，再点一块交换'))); return; }
    if (this.sel === i) { this.sel = -1; this.msg = TG('已取消选择'); return; }
    const nh: number[] = this.hues.slice();
    const t: number = nh[this.sel]; nh[this.sel] = nh[i]; nh[i] = t;
    this.hues = nh; this.sel = -1;
    this.moves = this.moves + 1; this.score = this.score + 10; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    if (this.sortedAll()) {
      this.over = true; this.won = true;
      this.score = this.score + (this.diffTotal - this.moves) * 15;
      this.msg = TG2('🎉 彩虹排好了！还剩 {0} 步没用', (this.diffTotal - this.moves));
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.msg = TG2('💤 步数用尽，归位 {0}/{1}', this.fixed(), (N * N));
      this.finish(false);
      return;
    }
    this.msg = TG(TG(TG('换了一步，继续')));
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'hue_sort', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.fixed() };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Text(TG2("归位 {0}/{1}", this.fixed(), (N * N)))
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(Palette.sky)
        .width('100%').textAlign(TextAlign.Center).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Column({ space: Space.xs }) {
        ForEach(R4, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(R4, (c: number) => { this.swatch(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#EEF2F7').borderRadius(Radius.lg)
      Row({ space: Space.md }) {
        Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
      Text(TG(TG(TG('正确顺序：左上 → 右下，色相 0° 递增到 337°'))))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  swatch(i: number) {
    Stack() {
      Text(this.sel === i ? '◉' : '').fontSize(FontSize.lg).fontColor('#FFFFFF')
    }
    .layoutWeight(1).aspectRatio(1)
    .backgroundColor(hueColor(this.hues[i]))
    .borderRadius(Radius.sm).borderWidth(this.sel === i ? 3 : 0).borderColor('#FFFFFF')
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
