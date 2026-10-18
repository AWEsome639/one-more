/**
 * 数量直觉 —— 一团圆点只亮 420 ms，来不及数，只能"一眼看出"有几个
 * 胜负：10 题答对 ≥8 题通关
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 3;
const CELLS: number = N * N;
const ROUNDS: number = 10;
const SHOW_MS: number = 420;

const LEVELS: number[] = [2, 3, 4, 5, 5, 6, 6, 7, 8, 9];

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GSubitizingRush {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private dots: number[] = [];
  @State private cnt: number = 0;
  @State private shown: boolean = true;   // 圆点是否还亮着
  @State private round: number = 1;
  @State private right: number = 0;
  @State private best: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private hideTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.dots = []; this.cnt = 0; this.shown = true; this.round = 1; this.right = 0;
    this.best = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }

  /** 随机撒 n 个点，亮 420 ms 就收起 */
  private newTrial(): void {
    const n: number = LEVELS[(this.round - 1) % LEVELS.length];
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { pool.push(i); }
    const out: number[] = [];
    for (let i = 0; i < n; i++) {
      const j: number = Math.floor(Math.random() * pool.length);
      out.push(pool[j]);
      pool.splice(j, 1);
    }
    this.dots = out;
    this.cnt = n;
    this.shown = true;
    this.pick = -1;
    this.msg = TG(TG(TG('一眼看出有几个点')));
    this.hideTo = setTimeout(() => {
      this.hideTo = -1;
      this.shown = false;
      this.msg = TG(TG(TG('刚才有几个点？')));
    }, SHOW_MS);
  }

  /** 三个选项：正确答案 + 两个邻近数 */
  private option(k: number): number {
    const offs: number[] = [0, -1, 2];
    let v: number = this.cnt + offs[k];
    if (v < 2) { v = this.cnt + 1; }
    if (v > 9) { v = this.cnt - 2; }
    return v;
  }

  private answer(v: number): void {
    if (this.over || this.pick >= 0 || this.shown) { return; }
    const truth: number = this.cnt;
    this.pick = v;
    if (v === truth) {
      this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ 就是 ' + String(truth) + TG(' 个');
    } else {
      this.msg = '❌ 其实是 ' + String(truth) + TG(' 个');
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 680);
  }

  private advance(): void {
    if (this.round >= this.diffTotal) {
      const win: boolean = this.right >= 8;
      this.over = true; this.won = win;
      if (this.right > this.best) { this.best = this.right; }
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 题", String(this.right), String(this.diffTotal));
      const res: GameResult = {
        gameId: 'subitizing_rush', solved: win,
        score: this.right * 110 + (win ? 200 : 0),
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.newTrial();
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("题号 {0}/{1}", String(this.round), String(this.diffTotal))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.right)).fontSize(FontSize.sm).fontColor(Palette.violet)
        Text(TG2('最佳 {0}', this.best > 0 ? String(this.best) : '—')).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              this.cellView(r * N + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.pick >= 0 ? Palette.violet : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        this.optBtn(0)
        this.optBtn(1)
        this.optBtn(2)
      }.width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('判定：10 题答对 ≥ 8 题；≤ 4 个靠直觉，≥ 5 个得靠分组'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.shown && has(this.dots, i) ? '●' : '')
        .fontSize(FontSize.xxl).fontColor(Palette.violet)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.theme.surface).borderRadius(Radius.sm)
  }

  @Builder
  optBtn(k: number) {
    Button(String(this.option(k)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
      .fontSize(FontSize.xl).fontColor('#FFFFFF')
      .backgroundColor(this.pick === this.option(k) ? Palette.primaryDeep : Palette.violet)
      .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
      .opacity(this.shown ? 0.45 : 1)
      .scale({ x: this.pick === this.option(k) ? Motion.pressScale : 1, y: this.pick === this.option(k) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { this.answer(this.option(k)); })
  }
}
