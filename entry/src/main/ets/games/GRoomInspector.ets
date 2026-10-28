/**
 * 房间检查 📐
 * 规则：上下两间房，下面那间有 3 处摆设和上面不一样，点出来。
 * 胜负：找齐 3 处 ⇒ 通关；错点 3 次或超过 60 秒 ⇒ 失败。　进度：找到几处 / 失误 / 剩余秒
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const COLS: number = 4; const ROWS: number = 3; const CELLS: number = COLS * ROWS;
const DIFFS: number = 3; const MISS: number = 3; const LIMIT: number = 60;
const IDXR: number[] = [0, 1, 2];
const IDXC: number[] = [0, 1, 2, 3];
const BANK: string[] = ['🛋️', '🪑', '🛏️', '🖼️', '🪴', '📺', '🕰️', '🧸', '💡', '🚪', '🪟', '📚'];

@Component
export struct GRoomInspector {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private up: string[] = []; @State private down: string[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private diffs: number[] = []; @State private found: number[] = [];
  @State private miss: number = 0; // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  private total: number = GameDiff.timeNow(LIMIT);
  @State private secs: number = 0; @State private bad: number = -1;
  @State private over: boolean = false; @State private won: boolean = false; @State private msg: string = '';
  private startAt: number = 0; private clock: number = -1; private flash: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    if (this.flash >= 0) { clearTimeout(this.flash); this.flash = -1; }
  }
  private reset(): void {
    this.stop();
    const base: string[] = [];
    for (let i = 0; i < CELLS; i++) { base.push(BANK[Math.floor(Math.random() * BANK.length)]); }
    const other: string[] = base.slice();
    const used: number[] = []; const ds: number[] = [];
    while (ds.length < DIFFS) {
      let i: number = Math.floor(Math.random() * CELLS);
      while (used.indexOf(i) >= 0) { i = Math.floor(Math.random() * CELLS); }
      used.push(i);
      let e: string = BANK[Math.floor(Math.random() * BANK.length)];
      while (e === base[i]) { e = BANK[Math.floor(Math.random() * BANK.length)]; }
      other[i] = e; ds.push(i);
    }
    this.up = base; this.down = other; this.diffs = ds; this.found = [];
    this.miss = 0; this.secs = this.total; this.bad = -1;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG2('下面那间有 {0} 处不同，点它', String(DIFFS));
    this.startAt = Date.now();
    this.clock = setInterval(() => { this.tick(); }, 1000);
  }
  private tick(): void {
    if (this.over) { return; }
    this.secs = this.secs - 1;
    if (this.secs <= 0) { this.finish(false); }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 2026-10-28 修：不能拿 found.length 当 diffs 的下标 ——
  //   diffs 是随机生成顺序，found 是点击顺序；玩家先点了 diffs[2]，
  //   代打就会一直点已经找到的 diffs[1]（tap 里 return）⇒ 原地卡死、永远赢不了。
  private nextDiff(): number {
    for (let k: number = 0; k < this.diffs.length; k++) {
      if (this.found.indexOf(this.diffs[k]) < 0) {
        return this.diffs[k];
      }
    }
    return -1;
  }

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
    const d: number = this.nextDiff();
    if (d < 0) {
      return true;
    }
    this.tap(d);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值就是 this.diffs（生成时抽出来的三处不同）
  /** 提示：报第几行第几列不同 + 两边分别是什么（报内容，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.found.length >= DIFFS) {
      return Hint.none('none');
    }
    const i: number = this.nextDiff();
    if (i < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(i / COLS) + 1;
    const c: number = (i % COLS) + 1;
    return Hint.make([i],
      TG2('第 {0} 行第 {1} 列不同 —— 上面是 {2}', String(r), String(c), this.up[i]) + '，下面是 ' + this.down[i],
      TG2('Row {0}, column {1} differs: {2}', String(r), String(c), this.up[i]) + ' → ' + this.down[i], t0);
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

  private tap(i: number): void {
    if (this.over) { return; }
    if (this.diffs.indexOf(i) >= 0) {
      if (this.found.indexOf(i) >= 0) { return; }
      const f: number[] = this.found.slice();
      f.push(i); this.found = f;
      if (f.length >= DIFFS) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return; }
      this.msg = TG2('✅ 找到 {0}/{1} 处', String(f.length), String(DIFFS));
      return;
    }
    this.miss = this.miss + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    this.bad = i;
    if (this.flash >= 0) { clearTimeout(this.flash); }
    this.flash = setTimeout(() => { this.flash = -1; this.bad = -1; }, 420);
    if (this.miss >= MISS) { this.finish(false); return; }
    this.msg = TG2("❌ 这里一样 · 还能错 {0} 次", String(MISS - this.miss));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.stop();
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 三处全找到了！' : TG2("😵 本局结束 · 找到 {0} 处", String(this.found.length));
    const raw: number = solved ? 200 + this.secs * 3 - this.miss * 40 : this.found.length * 40;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'room_inspector', solved: solved, score: raw > 0 ? raw : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.found.length
    });
  }
  /** mode 1 = 下面那间（可点），0 = 上面那间 */
  private bgOf(i: number, mode: number): string {
    if (mode === 0) { return this.theme.surfaceAlt; }
    if (this.found.indexOf(i) >= 0) { return '#2210B981'; }
    if (this.bad === i) { return '#22EF4444'; }
    return this.theme.surfaceAlt;
  }
  private borderOf(i: number, mode: number): string {
    if (mode === 0) { return this.theme.line; }
    if (this.found.indexOf(i) >= 0) { return Palette.emerald; }
    if (this.bad === i) { return Palette.rose; }
    return this.theme.line;
  }
  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('找到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.found.length) + '/' + String(DIFFS))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.miss) + '/' + String(MISS))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.secs > 0 ? this.secs : 0) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Text(TG('🔍 原样')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
      Column({ space: Space.xs }) {
      ForEach(IDXR, (r: number) => {
      Row({ space: Space.xs }) {
      ForEach(IDXC, (c: number) => { Stack() {
      Text(false ? this.down[(r * COLS + c)] : this.up[(r * COLS + c)]).fontSize(FontSize.xl)
      }.layoutWeight(1).height(Cell.of(46))
      .backgroundColor(this.bgOf((r * COLS + c), ((0)))).borderRadius(Radius.sm).borderWidth(2)
      .borderColor(this.borderOf((r * COLS + c), ((0))))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
      Haptics.tick();
      if (false) { this.tap((r * COLS + c)); }
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (false) { this.tap((r * COLS + c)); } }); }) }, (c: number) => 'c' + c)
      }.width('100%')
      }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.xs).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).borderWidth(2)
      .borderColor(false ? Palette.violet : this.theme.line)
      Text(TG('❗ 找不同 · 点下面这间')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
      Column({ space: Space.xs }) {
      ForEach(IDXR, (r: number) => {
      Row({ space: Space.xs }) {
      ForEach(IDXC, (c: number) => { Stack() {
      Text(true ? this.down[(r * COLS + c)] : this.up[(r * COLS + c)]).fontSize(FontSize.xl)
      }.layoutWeight(1).height(Cell.of(46))
      .backgroundColor(this.bgOf((r * COLS + c), ((1)))).borderRadius(Radius.sm).borderWidth(2)
      .borderColor(this.borderOf((r * COLS + c), ((1))))
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => {
      Haptics.tick();
      if (true) { this.tap((r * COLS + c)); }
      })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (true) { this.tap((r * COLS + c)); } }); }) }, (c: number) => 'c' + c)
      }.width('100%')
      }, (r: number) => 'r' + r)
      }.width('100%').padding(Space.xs).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).borderWidth(2)
      .borderColor(true ? Palette.violet : this.theme.line)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Button(this.over ? (this.won ? TG('再来一局 🎉') : TG('再试一次')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(this.won ? Palette.emerald : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
