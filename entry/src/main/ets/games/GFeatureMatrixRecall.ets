/**
 * 特征矩阵 —— 4×4 里亮起 3 红 3 蓝，遮蔽后只点出被指定那一种颜色
 * 胜负：选中的 3 格完全正确 ⇒ 通关；进度：倒计时 / 已选 n/3 / 判分明细
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { AppClock } from '../core/AppClock';

const N: number = 4;
const TOTAL: number = N * N;
const PER_COLOR: number = 3;
const SHOW_SEC: number = 5;

@Component
export struct GFeatureMatrixRecall {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private hiColors: string[] = [];
  @State private picked: boolean[] = [];
  @State private askColor: string = Palette.rose;
  @State private phase: number = 0;      // 0 记忆 1 作答 2 判定
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SHOW_SEC);
  @State private secLeft: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(SHOW_SEC);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }

  private reset(): void {
    this.clearAll();
    const colors: string[] = new Array<string>(TOTAL).fill('');
    const slots: number[] = [];
    for (let i = 0; i < TOTAL; i++) { slots.push(i); }
    for (let i = 0; i < PER_COLOR * 2; i++) {          // 洗牌取前 6 格
      const j: number = i + Math.floor(Math.random() * (TOTAL - i));
      const tmp: number = slots[i]; slots[i] = slots[j]; slots[j] = tmp;
    }
    for (let i = 0; i < PER_COLOR; i++) { colors[slots[i]] = Palette.rose; }
    for (let i = PER_COLOR; i < PER_COLOR * 2; i++) { colors[slots[i]] = Palette.sky; }
    this.hiColors = colors;
    this.picked = new Array<boolean>(TOTAL).fill(false);
    this.askColor = Math.random() < 0.5 ? Palette.rose : Palette.sky;   // 遮蔽后才公布问哪种
    this.phase = 0; this.secLeft = this.total; this.over = false; this.won = false; this.done = false;
    this.msg = TG('记住两种颜色各在哪 3 格');
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.phase !== 0) { return; }
      this.secLeft = this.secLeft - 1;
      if (this.secLeft <= 0) {
        this.clearAll();
        this.phase = 1;
        this.msg = TG2('点出全部「{0}」格子（3 格）', this.colorName(this.askColor));
      }
    }, 1000);
  }

  private colorName(c: string): string {
    return c === Palette.rose ? '红色' : '蓝色';
  }

  private toggle(i: number): void {
    if (this.phase !== 1) { return; }
    const next: boolean[] = this.picked.slice();
    next[i] = !next[i];
    this.picked = next;
  }

  private pickCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.picked.length; i++) { if (this.picked[i]) { n = n + 1; } }
    return n;
  }

  private hitCount(): number {
    let n: number = 0;
    for (let i = 0; i < TOTAL; i++) {
      if (this.hiColors[i] === this.askColor && this.picked[i]) { n = n + 1; }
    }
    return n;
  }

  private judge(): void {
    if (this.phase !== 1 || this.pickCount() !== PER_COLOR) { return; }
    let ok: boolean = true;
    for (let i = 0; i < TOTAL; i++) {
      if (this.picked[i] !== (this.hiColors[i] === this.askColor)) { ok = false; }
    }
    this.phase = 2; this.over = true; this.won = ok;
    this.msg = ok ? '🎉 全对！特征记忆通关' : TG2("💤 错了 {0} 格", String(PER_COLOR - this.hitCount()));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'feature_matrix_recall', solved: ok, score: ok ? 300 : this.hitCount() * 40,
        durationMs: Date.now() - this.startAt, levelReached: this.hitCount()
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  private cellInk(i: number): string {
    if (this.phase === 2) {
      const isTarget: boolean = this.hiColors[i] === this.askColor;
      if (isTarget && this.picked[i]) { return '✅'; }
      if (isTarget) { return '❌'; }
      return this.picked[i] ? '⛔' : '';
    }
    return this.phase === 1 && this.picked[i] ? '🎯' : '';
  }

  private cellBg(i: number): string {
    if (this.phase === 1) { return this.picked[i] ? Palette.primary : this.theme.surfaceAlt; }
    return this.hiColors[i] === '' ? this.theme.surfaceAlt : this.hiColors[i];
  }

  /** 键里带上格子外观，确保状态一变 ForEach 就重绘 */
  private cellKey(i: number): string {
    return 'k' + String(i) + this.cellBg(i) + (this.picked[i] ? '1' : '0') + this.cellInk(i);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? TG('记忆') : (this.phase === 2 ? '判定' : '作答'))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已选'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.pickCount()) + '/' + String(PER_COLOR))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('要点的颜色'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.colorName(this.askColor))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Text(this.phase === 0 ? ('⏳ ' + String(this.secLeft) + ' 秒后遮蔽') : this.msg)
        .fontSize(FontSize.sm).fontColor(this.phase === 0 ? Palette.amber : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (row: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (col: number) => {
              Stack() {
              Text(this.cellInk((row * N + col))).fontSize(FontSize.lg)
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.cellBg((row * N + col))).borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { this.toggle((row * N + col)); })
            }, (col: number) => this.cellKey(row * N + col))
          }.width('100%')
        }, (row: number) => 'r' + row)
      }.width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Button(this.phase === 2 ? TG('再来一局') : TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .enabled(this.phase === 1 && this.pickCount() === PER_COLOR)
        .opacity(this.phase === 1 && this.pickCount() === PER_COLOR ? 1 : 0.5)
        .onClick(() => { if (this.phase === 2) { this.reset(); } else { this.judge(); } })

      Text(TG('只看不抄：3 红 3 蓝，遮蔽后按指定颜色复原'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
