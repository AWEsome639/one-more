/**
 * 柜子记忆 —— 六格里亮出几件物品，1.5 秒后收起，再问「某件物品在哪一格」
 * 胜负：6 轮答对 ≥5 轮通关
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const COLS: number = 3;
const ROWS: number = 2;
const CELLS: number = COLS * ROWS;
const ITEMS: number = 4;
const ROUNDS: number = 6;
const SHOW_MS: number = 1500;

const ICONS: string[] = ['🍎', '🔑', '☕', '📕', '🎲', '🧸'];

function has(a: number[], v: number): boolean { return a.indexOf(v) >= 0; }

@Component
export struct GSpatialCabinetMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ITEMS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ITEMS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private slotOf: number[] = [];    // 每格放第几件物品，-1 = 空
  @State private items: number[] = [];     // 本局用到的物品
  @State private target: number = -1;      // 问哪件物品
  @State private pick: number = -1;
  @State private phase: number = 0;        // 0 记忆 1 作答 2 揭晓
  @State private round: number = 1;
  @State private hit: number = 0;
  @State private score: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private hideTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSpatialCabinetMemory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ITEMS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.slotOf = []; this.items = []; this.target = -1; this.pick = -1; this.phase = 0;
    this.round = 1; this.hit = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newTrial();
  }

  /** 撒物品：4 件各占一格，然后随机挑一件来问 */
  private newTrial(): void {
    const pool: number[] = [0, 1, 2, 3, 4, 5];
    const slot: number[] = [-1, -1, -1, -1, -1, -1];
    const used: number[] = [];
    for (let k = 0; k < this.diffTotal; k++) {
      const s: number = Math.floor(Math.random() * pool.length);
      const cell: number = pool[s];
      pool.splice(s, 1);
      let icon: number = Math.floor(Math.random() * ICONS.length);
      let guard: number = 0;
      while (has(used, icon) && guard < ICONS.length) { icon = (icon + 1) % ICONS.length; guard = guard + 1; }
      slot[cell] = icon;
      used.push(icon);
    }
    this.slotOf = slot;
    this.items = used;
    this.target = used[Math.floor(Math.random() * used.length)];
    this.pick = -1;
    this.phase = 0;
    this.msg = TG(TG(TG('记住每件物品的柜格')));
    this.hideTo = setTimeout(() => {
      this.hideTo = -1;
      this.phase = 1;
      this.msg = ICONS[this.target] + ' 刚才在哪一格？点它';
    }, SHOW_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 1 || this.pick >= 0) {
      return true;
    }
    this.tap(this.slotOf.indexOf(this.target));
    return !this.over;
  }

  /** 提示：东西在第几格 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 1 || this.pick >= 0) {
      return Hint.none('none');
    }
    const real: number = this.slotOf.indexOf(this.target);
    if (real < 0) {
      return Hint.none('none');
    }
    return Hint.make([real], TG2('第 {0} 格', String(real + 1)),
      TG2('Cell {0}', String(real + 1)), t0);
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

  private tap(cell: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = cell;
    this.phase = 2;
    const real: number = this.slotOf.indexOf(this.target);
    if (cell === real) {
      this.hit = this.hit + 1;
      this.score = this.score + 120; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = TG2('✅ 对！{0} 就在这里', ICONS[this.target]);
    } else {
      this.msg = '❌ 它在第 ' + String(real + 1) + TG(' 格');
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, 1000);
  }

  private advance(): void {
    if (this.round >= ROUNDS) {
      const win: boolean = this.hit >= 5;
      this.over = true; this.won = win;
      this.msg = (win ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1} 轮", String(this.hit), String(ROUNDS));
      const res: GameResult = {
        gameId: 'spatial_cabinet_memory', solved: win, score: this.score,
        durationMs: Date.now() - this.startAt, levelReached: this.round
      };
      if (!this.done) { this.done = true; LanRace.noteDone(); this.onFinish(res); }
      return;
    }
    this.round = this.round + 1;
    this.newTrial();
  }

  /** 记忆阶段显示物品；作答后只把点过的那格翻开 */
  private face(cell: number): string {
    const v: number = this.slotOf.length > 0 ? this.slotOf[cell] : -1;
    if (this.phase === 0) { return v >= 0 ? ICONS[v] : ''; }
    return this.pick === cell ? '❓' : '';
  }

  private tint(cell: number): string {
    const v: number = this.slotOf.length > 0 ? this.slotOf[cell] : -1;
    if (this.phase === 0) { return v >= 0 ? Palette.primaryDeep : this.theme.surface; }
    if (this.pick !== cell) { return this.theme.surface; }
    return v === this.target ? Palette.emerald : Palette.rose;
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row() {
        Text(TG2("轮次 {0}/{1}",Digits(String(this.round), this.langCode),Digits(String(ROUNDS), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + String(this.hit)).fontSize(FontSize.sm).fontColor(Palette.primaryDeep)
        Text(TG('得分 ') + String(this.score)).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => {
              this.cellView(r * COLS + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.md).fontColor(this.phase === 0 ? this.theme.ink : Palette.primaryDeep)
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(cell: number) {
    Stack() {
      Text(this.face(cell)).fontSize(FontSize.xxl)
    }
    .layoutWeight(1).height(Cell.of(64)).backgroundColor(this.tint(cell)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(cell); })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(cell); }); })
  }
}
