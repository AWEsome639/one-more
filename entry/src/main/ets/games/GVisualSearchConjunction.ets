/**
 * 联合搜索 —— 目标要「形状 + 颜色」两个特征同时对上，干扰项各只占一个
 * 胜负：6 局找对 ≥5 ⇒ 通关｜进度：局数 / 找对 / 得分（每局 9 秒，点错罚 1.5 秒）
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5; const CELLS: number = N * N; const IDX: number[] = [0, 1, 2, 3, 4];
const ROUNDS: number = 6; const PASS: number = 5;
const LIMIT_MS: number = 9000; const TICK_MS: number = 100;
const PENALTY_MS: number = 1500; const GAP_MS: number = 550;
const SHAPES: string[] = ['●', '▲', '■', '★'];
const COLORS: string[] = [Palette.rose, Palette.sky, Palette.emerald, Palette.amber];

@Component
export struct GVisualSearchConjunction {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State shapes: number[] = []; @State colors: number[] = [];
  @State tShape: number = 0; @State tColor: number = 0;
  @State round: number = 1; @State hits: number = 0; @State score: number = 0;
  @State leftMs: number = LIMIT_MS; @State msg: string = ''; @State badIdx: number = -1;
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private roundAt: number = 0;
  private timer: number = -1; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  /** 在 n 个下标里取一个与 cur 不同的 */
  private other(cur: number, n: number): number {
    const step: number = 1 + Math.floor(Math.random() * (n - 1));
    return (cur + step) % n;
  }
  private reset(): void {
    this.stop();
    this.round = 1; this.hits = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.newRound();
  }
  /** 干扰项只与目标共享一个特征：同形状异色，或同色异形状 */
  private newRound(): void {
    const ts: number = Math.floor(Math.random() * SHAPES.length);
    const tc: number = Math.floor(Math.random() * COLORS.length);
    const sh: number[] = []; const co: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (Math.random() < 0.5) { sh.push(ts); co.push(this.other(tc, COLORS.length)); }
      else { sh.push(this.other(ts, SHAPES.length)); co.push(tc); }
    }
    const at: number = Math.floor(Math.random() * CELLS);
    sh[at] = ts; co[at] = tc;
    this.shapes = sh; this.colors = co; this.tShape = ts; this.tColor = tc; this.badIdx = -1;
    this.leftMs = LIMIT_MS; this.roundAt = Date.now();
    this.msg = TG2("第 {0} 局：形状和颜色都要对上",Digits(String(this.round), this.langCode));
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= LIMIT_MS ? 0 : LIMIT_MS - gap;
    if (gap >= LIMIT_MS) { this.endRound(false); }
  }
  /** ★ AI 代打/提示共用：唯一那个形状+颜色都对上的格子（没有就 -1） */
  private targetCell(): number {
    for (let i = 0; i < this.shapes.length; i++) {
      if (this.shapes[i] === this.tShape && this.colors[i] === this.tColor) { return i; }
    }
    return -1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.feed >= 0 || this.targetCell() < 0) {
      return true;
    }
    this.pick(this.targetCell());
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const at: number = this.targetCell();
    if (at < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(at / N) + 1;
    const c: number = at % N + 1;
    return Hint.make([at],
      TG2('形状和颜色都对上的 {0} 在第 {1} 行第 {2} 列', SHAPES[this.tShape], r, c),
      TG2('The {0} matching both shape and colour is at row {1}, column {2}', SHAPES[this.tShape], r, c), t0);
  }
  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private pick(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    if (this.shapes[i] === this.tShape && this.colors[i] === this.tColor) {
      const gain: number = 30 + Math.floor(this.leftMs / 100);
      this.hits = this.hits + 1; this.score = this.score + gain;
      this.msg = TG2('✅ 两个特征都对！+{0}', gain); this.endRound(true);
      return;
    }
    this.badIdx = i; this.roundAt = this.roundAt - PENALTY_MS; this.msg = TG('❌ 只对了一半，罚 1.5 秒');
  }
  private endRound(ok: boolean): void {
    this.stop();
    if (!ok) { this.msg = TG('⌛ 超时了'); }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("找对 {0} / {1}", this.hits, this.diffTotal);
      this.finish(this.won);
      return;
    }
    this.round = this.round + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.newRound(); }, GAP_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'visual_search_conjunction', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text(('局')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('找对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hits), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(SHAPES[this.tShape]).fontSize(FontSize.xxl).fontColor(COLORS[this.tColor])
        Text(TG('要找：这个形状 + 这个颜色')).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Row() {
        Row().height(Space.xs).width(String(Math.round((this.leftMs / LIMIT_MS) * 100)) + '%')
          .backgroundColor(this.leftMs > 2500 ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.full).animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%').height(Space.xs).backgroundColor(this.theme.line).borderRadius(Radius.full)
      Column({ space: Space.xs }) {
        ForEach(IDX, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(IDX, (c: number) => {
              Text(SHAPES[this.shapes[(r * N + c)]])
              .fontSize(FontSize.xxl).fontColor(COLORS[this.colors[(r * N + c)]]).textAlign(TextAlign.Center)
              .layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.badIdx === (r * N + c) ? Palette.rose : this.theme.surface)
              .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.pick((r * N + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
