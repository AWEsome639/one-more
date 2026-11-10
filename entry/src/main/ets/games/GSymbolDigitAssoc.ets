/**
 * 符号数字（symbol_digit_assoc）—— 看上方对照表，给符号选对应数字（SDMT 玩法）
 * 胜负：12 题答对 ≥9 ⇒ 通关；进度：题号 / 答对 / 用时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits, Sec } from '../core/I18n';
import { Tv } from '../core/Tv';
import { AppClock } from '../core/AppClock';

const SYMS: string[] = ['●', '▲', '■', '★', '◆', '✚'];
const IDX6: number[] = [0, 1, 2, 3, 4, 5];
const COLS: number[] = [0, 1, 2];
const ROWS: number[] = [0, 1];
const TOTAL: number = 12;
const NEED: number = 9;

@Component
export struct GSymbolDigitAssoc {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State idx: number = 0;           // 当前符号下标 ⇒ 对应数字 = idx + 1
  @State no: number = 1;
  @State right: number = 0;
  @State pick: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  @State secs: number = 0;
  private startAt: number = 0;
  private to: number = -1;
  private tick: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.secs = Math.floor((Date.now() - this.startAt) / 1000);
    }, 1000);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSymbolDigitAssoc')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.to >= 0) { clearTimeout(this.to); this.to = -1; }
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    if (this.pick >= 0) {
      return true;
    }
    // ★ 2026-11-08（ai-fixer-a）**不再直接读 this.idx（答案）**：
    //   屏幕中下方有图例（SYMS[k] = k+1）⇒ 拿当前大符号去图例里反查序号。
    const sym: string = SYMS[this.idx];      // 屏幕中央的大符号（题面）
    let k: number = -1;
    for (let i = 0; i < SYMS.length; i++) {
      if (SYMS[i] === sym) {
        k = i;
        break;
      }
    }
    if (k < 0) {
      return false;
    }
    this.answer(k);
    return !this.over;
  }

  /** 提示：这个符号对应哪个数字 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.idx], TG2('{0} 对应的数字是 {1}', SYMS[this.idx], String(this.idx + 1)),
      TG2('{0} corresponds to {1}', SYMS[this.idx], String(this.idx + 1)), t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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
    if (this.to >= 0) { clearTimeout(this.to); this.to = -1; }
    this.no = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.secs = 0; this.msg = TG('看清上方对照表，选出这个符号对应的数字');
    this.startAt = Date.now();
    this.nextSym();
  }

  private nextSym(): void {
    let s: number = Math.floor(Math.random() * SYMS.length);
    if (s === this.idx) { s = (s + 1) % SYMS.length; }
    this.idx = s;
    this.pick = -1;
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    const want: number = this.idx + 1;
    if (i + 1 === want) { this.right = this.right + 1; this.msg = TG2('✅ 对，{0} = {1}', SYMS[this.idx], String(want)); }
    else { this.msg = TG2('❌ {0} 应该是 {1}', SYMS[this.idx], String(want)); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.no >= this.diffTotal) { this.finishUp(); return; }
      this.no = this.no + 1;
      this.nextSym();
    }, 560);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal))
      + TG2(' · 用时 {0}s', String(this.secs));
    this.clearAll();
    const r: GameResult = {
      gameId: 'symbol_digit_assoc', solved: this.won,
      score: this.right * 100 + Math.max(0, 120 - this.secs),
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.xxs }) {
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
      Row({ space: Space.xs }) {
        ForEach(IDX6, (k: number) => {
          Text(SYMS[k] + '=' + String(k + 1)).fontSize(FontSize.xxs).fontColor(this.theme.inkSoft)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30)).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.xs)
        }, (k: number) => 'lg' + k)
      }.width('100%')

      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((this.no + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((String(this.secs) + Sec())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Text(SYMS[this.idx]).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
        .textAlign(TextAlign.Center).width('100%').height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (c: number) => {
              Text(String((r * 3 + c) + 1)).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.pick >= 0 ? '#FFFFFF' : this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(32))
              .backgroundColor(this.pick === (r * 3 + c) ? Palette.rose : this.theme.surfaceAlt)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .scale({ x: this.pick === (r * 3 + c) ? Motion.pressScale : 1, y: this.pick === (r * 3 + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.answer((r * 3 + c)); })
              .focusable(Tv.on())
              .onFocus(() => { this.tvFocus = 'L303'; })
              .onBlur(() => { if (this.tvFocus === 'L303') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L303'))
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((r * 3 + c)); }); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      // ★ 2026-11-09：矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.rose).borderRadius(Radius.md).width('100%').height(Cell.of(32)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L314'; })
        .onBlur(() => { if (this.tvFocus === 'L314') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L314'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：先扫一眼对照表再点；同一个符号不会连着出现'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
