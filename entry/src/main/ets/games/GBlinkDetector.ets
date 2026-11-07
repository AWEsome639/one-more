/**
 * 眨眼检测 —— 眼睛偶尔快速眨一下（约 0.2 秒），看到就立刻点按钮
 * 胜负：10 次眨眼内命中 ≥6 且误报 ≤3 通关
 * 进度：进度 / 抓到 / 误报 / 得分
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

const TOTAL: number = 30; const BLINKS: number = 10; const TICK_MS: number = 620;
const BLINK_MS: number = 200; const NEED_HIT: number = 6; const MAX_FA: number = 3;

@Component
export struct GBlinkDetector {
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

  @State eye: boolean = false; @State tickN: number = 0; @State hits: number = 0;
  @State fa: number = 0; @State score: number = 0; @State over: boolean = false;
  @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false;
  private timer: number = -1; private blinkTo: number = -1;
  private plan: number[] = []; private responded: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBlinkDetector')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.blinkTo >= 0) { clearTimeout(this.blinkTo); this.blinkTo = -1; }
    this.stopAuto();                   // ★ 代打是 120ms 的定时器，离页必须停
  }

  private reset(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    const plan: number[] = [];
    while (plan.length < BLINKS) {
      const t: number = 2 + Math.floor(Math.random() * (this.diffTotal - 3));
      if (plan.indexOf(t) < 0) { plan.push(t); }
    }
    this.plan = plan;
    this.eye = false; this.tickN = 0; this.hits = 0; this.fa = 0; this.score = 0;
    this.over = false; this.won = false; this.finished = false; this.responded = false;
    this.startAt = Date.now(); this.msg = TG('盯住眼睛 —— 眨的瞬间点「眨眼了！」');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.tickN = this.tickN + 1;
    if (this.plan.indexOf(this.tickN) >= 0) { this.openBlink(); }
    if (this.tickN >= this.diffTotal) { this.end(); }
  }

  private openBlink(): void {
    this.eye = true; this.responded = false;
    // ═════════════════════════════════════════════════════════════════════
    // ★★★ 2026-11-05（第 1366 轮，判据 1043/1055/1056）：**修「代打可能完全错过眨眼」**
    //
    // 根因（可复算）：
    //   · 眨眼窗口 `BLINK_MS = 200ms`
    //   · 而代打靠 `Hint.autoRun` 每 `AUTO_MS = 320ms` 轮询一次
    //   · **320 > 200** ⇒ 一次眨眼可能**一次都没被采样到** ⇒ 必 miss
    //
    // 修法（判据 1056）：**在事件产生的那一行之后，立刻替玩家响应**
    //   ⛔ 不改轮询频率（那是全局的，会影响 355 款）
    // ═════════════════════════════════════════════════════════════════════
    if (this.autoId >= 0) {
      this.tap();
    }
    if (this.blinkTo >= 0) { clearTimeout(this.blinkTo); }
    this.blinkTo = setTimeout(() => { this.blinkTo = -1; this.eye = false; }, BLINK_MS);
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

  /**
   * 代打的一步。
   * ★★★ 2026-11-05（第 1366 轮，判据 1055/1058）：**点击已交给 `openBlink` 事件驱动**
   *
   * 为什么必须删掉这里的 `tap()`：
   *   · 眨眼窗口 `BLINK_MS = 200ms`，而代打轮询 `AUTO_MS = 320ms`
   *     ⇒ **320 > 200** ⇒ 轮询**结构上可能一次都碰不到**
   *   · 已在 `openBlink()` 里加了「事件驱动响应」（眨眼一出现就点，误差 ≈ 0）
   *   · 而 `tap()` 的实现是：
   *       `if (this.eye && !this.responded) { 命中 } else { **误报 +1** }`
   *     ⇒ 事件响应把 `responded` 置 true 后，
   *       **轮询再点一次就会落到 else ⇒ 命中被变成误报**（判据 1058）
   *   ⇒ 所以这里**只保活**，绝不再点
   */
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    // ★ 2026-11-06 真机 bug（同 GAbReversalOddball 的 autoStep 空实现）：
    //   原来什么都不做 ⇒ AI 代打永远不点，永远命中不了。
    //   「眼睛正闭着」只在 eye 为真时成立，且每题只能判一次（responded）。
    if (this.eye && !this.responded) {
      this.tap();
    }
    return true;
  }

  /** 下一次眨眼还有几拍（-1 = 本局不再眨眼） */
  private nextBlinkIn(): number {
    let best: number = -1;
    for (let i = 0; i < this.plan.length; i++) {
      const d: number = this.plan[i] - this.tickN;
      if (d > 0 && (best < 0 || d < best)) {
        best = d;
      }
    }
    return best;
  }

  // 答案就在状态里（眼睛闭着的这 0.2 秒就是答案）+ 有"已回应"守卫
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.eye && !this.responded) {
      return Hint.make([], TG('眼睛正闭着 —— 立刻点「眨眼了！」'),
        'Eyes are closed right now - tap now', t0);
    }
    const k: number = this.nextBlinkIn();
    if (k < 0) {
      return Hint.make([], TG('本局不会再眨了，等结算'),
        'No more blinks this round', t0);
    }
    return Hint.make([],
      TG2('再过 {0} 拍才眨（约 {1} 秒），先别点', String(k), String(Math.max(1, Math.round(k * TICK_MS / 1000)))),
      'Next blink in ' + String(k) + ' ticks - hold', t0);
  }


  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    // ★★★ 这款不能用 Hint.AUTO_MS(320ms)：眨眼窗口只有 BLINK_MS=200ms，
    //    320ms 一拍只能碰上约六成眨眼 ⇒ 命中经常卡在 6/10 的及格线上。
    //    节拍缩到 120ms（< 200ms 窗口）就能拍进每一次眨眼，逻辑与 Hint.autoRun 完全一致。
    let id: number = -1;
    id = setInterval(() => {
      let more: boolean = false;
      try {
        more = this.autoStep();
      } catch (e) {
        more = false;
      }
      if (!more && id >= 0) {
        clearInterval(id);
      }
    }, 120);
    this.autoId = id;
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

  private tap(): void {
    if (this.over) { return; }
    if (this.eye && !this.responded) {
      this.hits = this.hits + 1; this.responded = true; this.score = this.score + 100;
      this.msg = TG2('✅ 抓到眨眼！（第 {0} 次）',Digits(String(this.hits), this.langCode));
    } else {
      this.fa = this.fa + 1; this.score = Math.max(0, this.score - 40);
      this.msg = TG('❌ 这时候眼睛是睁着的');
    }
  }

  private end(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.eye = false; this.over = true;
    this.won = this.hits >= NEED_HIT && this.fa <= MAX_FA;
    this.msg = this.won ? '🎉 抓到 ' + this.hits + '/' + BLINKS + ' 次、误报 ' + this.fa + TG('，通关！')
      : TG2('💤 只抓到 {0}/{1} 次（误报 {2}）',Digits(String(this.hits), this.langCode), NEED_HIT,Digits(String(this.fa), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'blink_detector', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.tickN + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('抓到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.hits + '/' + BLINKS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.fa), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Stack() {
        Text(this.eye ? '😑' : '👁').fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
      }
      .width('100%').height(170)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg).shadow(Shadow.lifted)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Button(TG('眨眼了！'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(64)).focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L333'; })
        .onBlur(() => { if (this.tvFocus === 'L333') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L333')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tap(); }); }).onClick(() => { Haptics.tap(); this.tap(); })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L340'; })
        .onBlur(() => { if (this.tvFocus === 'L340') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L340'))
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(TG2('提示：一共会眨 {0} 次；乱点会扣分，误报超过 {1} 次就输了', BLINKS, MAX_FA))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
