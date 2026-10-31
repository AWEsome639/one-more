/**
 * 数字文氏图 —— 两个集合（A = 3 的倍数，B = 偶数），把数字点进正确区域
 * 胜负：6 个数全部归位且错不超过 3 次 ⇒ 通关；进度：归位 / 答错 / 用时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

interface VennItem { v: number; zone: number; }   // zone: 0=只在A 1=只在B 2=交集 -1=已归位
const BANK: number[][] = [
  [2, 3, 4, 6, 8, 12], [3, 5, 6, 9, 10, 15], [2, 4, 6, 8, 10, 20],
  [3, 4, 6, 8, 9, 12], [5, 6, 10, 12, 15, 30], [2, 3, 6, 7, 14, 21]
];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5];

@Component
export struct GVennNumbers {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：要归类的数字个数（简单 4 / 普通 6 / 困难 8）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.pick(4, 6, 8);

  /** 0..diffTotal-1 */
  private slotIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private items: VennItem[] = [];
  @State private sel: number = -1;
  @State private placed: number = 0;
  @State private wrong: number = 0;
  @State private msg: string = '';
  @State private fb: number = -1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private clock: number = 0;
  private startAt: number = 0;
  private timer: number = -1;
  private fbTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVennNumbers')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.pick(4, 6, 8);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.fbTo >= 0) { clearTimeout(this.fbTo); this.fbTo = -1; }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
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
    if (this.over) {
      return true;
    }
    this.aiPlace(0);
    return !this.over;
  }

  /** 提示：这个数该放哪一块 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].zone < 0) { continue; }
      return Hint.make([i], TG2('{0} 属于「{1}」', String(this.items[i].v), this.zoneName(this.items[i].zone)),
        TG2('{0} belongs to "{1}"', String(this.items[i].v), this.zoneName(this.items[i].zone)), t0);
    }
    return Hint.none('none');
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

  private reset(): void {
    this.clearAll();
    const src: number[] = BANK[Math.floor(Math.random() * BANK.length)];
    const made: VennItem[] = [];
    for (let i = 0; i < 6; i++) { made.push({ v: src[i], zone: i < 2 ? 0 : (i < 4 ? 1 : 2) }); }
    const mixed: VennItem[] = [];
    while (made.length > 0) { mixed.push(made.splice(Math.floor(Math.random() * made.length), 1)[0]); }
    this.items = mixed;
    this.sel = -1; this.placed = 0; this.wrong = 0; this.fb = -1;
    this.over = false; this.won = false; this.clock = 0; this.startAt = Date.now();
    this.msg = TG('A 是 3 的倍数，B 是偶数 —— 先选数字，再点区域');
    this.timer = setInterval(() => { if (!this.over) { this.clock = this.clock + 1; } }, 1000);
  }
  private live(i: number): boolean { return this.items[i].zone >= 0; }
  private zoneName(z: number): string { return z === 0 ? '只在 A' : (z === 1 ? '只在 B' : 'A ∩ B'); }
  private tapChip(i: number): void {
    if (this.over || !this.live(i)) { return; }
    this.sel = i;
    this.msg = TG2("选中 {0}，它属于哪一块？", String(this.items[i].v));
  }
  private tapZone(zone: number): void {
    if (this.over) { return; }
    let idx: number = this.sel;
    if (idx < 0) {
      for (let i = 0; i < this.items.length; i++) { if (this.live(i)) { idx = i; } }
    }
    if (idx < 0) { return; }
    const it: VennItem = this.items[idx];
    if (it.zone === zone) {
      const next: VennItem[] = this.items.slice();
      next[idx] = { v: it.v, zone: -1 };
      this.items = next;
      this.sel = -1; this.placed = this.placed + 1; this.fb = 0;
      this.msg = TG2('✅ {0} 放进「{1}」', String(it.v), this.zoneName(zone));
      if (this.placed >= 6) {
        this.over = true;
        this.won = this.wrong <= 3;
        this.msg = (this.won ? '🎉 全部归位，通关！' : '💤 归位完成，错了 ' + String(this.wrong) + TG(' 次'));
        this.clearAll();
        this.finish(this.won);
      }
    } else {
      this.wrong = this.wrong + 1;
      this.fb = 1;
      this.msg = TG2('❌ {0} 不在「{1}」，再想想', String(it.v), this.zoneName(zone));
    }
    if (this.fbTo < 0 && !this.over) {
      this.fbTo = setTimeout(() => { this.fbTo = -1; this.fb = -1; }, 420);
    }
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'venn_numbers', solved: solved, score: this.placed * 100 - this.wrong * 40,
      durationMs: Date.now() - this.startAt, levelReached: this.placed
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  /** AI 用：选一个还没归位的数，点进它真正属于的区域 */
  private aiPlace(_d: number): void {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].zone < 0) { continue; }
      const z: number = this.items[i].zone;
      this.tapChip(i);
      this.tapZone(z);
      return;
    }
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
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('归位'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.placed + '/6')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.clock + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        Circle({ width: 118, height: 118 }).fill(this.theme.isDark ? '#22314A34' : '#3334D399')
          .stroke(Palette.emerald).strokeWidth(3).position({ x: 8, y: 12 })
        Circle({ width: 118, height: 118 }).fill(this.theme.isDark ? '#221D4ED8' : '#332563EB')
          .stroke(Palette.primary).strokeWidth(3).position({ x: 78, y: 12 })
        Row() { Text(('A')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .textAlign(TextAlign.Center).width((96)).height(Cell.of(44)).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).border({ width: 2, color: this.fb === 1 ? Palette.rose : this.theme.line })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapZone((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapZone((0)); }); }); Text(('B')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .textAlign(TextAlign.Center).width((96)).height(Cell.of(44)).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).border({ width: 2, color: this.fb === 1 ? Palette.rose : this.theme.line })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapZone((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapZone((1)); }); }); Text(('A∩B')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .textAlign(TextAlign.Center).width((74)).height(Cell.of(44)).backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md).border({ width: 2, color: this.fb === 1 ? Palette.rose : this.theme.line })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapZone((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapZone((2)); }); }) }
          .width('100%').height(150).justifyContent(FlexAlign.Center)
      }.width('100%').height(150)
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.slotIdx(), (i: number) => { Text(this.live((i)) ? String(this.items[(i)].v) : '·')
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.live((i)) ? (this.sel === (i) ? '#FFFFFF' : this.theme.ink) : this.theme.inkFaint)
        .textAlign(TextAlign.Center).width(58).height(Cell.of(52)).margin(Space.xs)
        .backgroundColor(this.live((i)) ? (this.sel === (i) ? Palette.primaryDeep : this.theme.surfaceAlt) : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.sel === (i) ? 1.06 : 1, y: this.sel === (i) ? 1.06 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tapChip((i)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapChip((i)); }); }) }, (i: number) => 'vn' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.fb === 1 ? Palette.rose : (this.fb === 0 ? Palette.emerald : this.theme.inkSoft))
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：A ∩ B = 既是 3 的倍数又是偶数，比如 6')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}