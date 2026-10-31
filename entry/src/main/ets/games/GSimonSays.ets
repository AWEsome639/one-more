/**
 * 西蒙说（Simon Says）—— 跟着做动作
 *
 * 玩法：四个色块依次亮起，按同样的顺序点回去；每过一关序列加长一位。
 * 结算：按错 ⇒ 失败；撑到第 12 关 ⇒ 通关。
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
import { A11y } from '../core/A11y';

const PADS: number = 4;
const WIN_LEN: number = 12;   // 难度会覆盖它        // 通关长度
const SHOW_TICK: number = 430;     // 演示时每半拍
const FLASH_MS: number = 180;      // 点中时的闪光
const GAP_MS: number = 700;        // 过关后到下一关
const PAD_COLORS: string[] = [Palette.emerald, Palette.rose, Palette.sky, Palette.amber];
const PAD_ICON: string[] = ['🐸', '🍎', '💧', '⭐'];
const IDX: number[] = [0, 1, 2, 3];

@Component
export struct GSimonSays {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  // ★ 难度作用到玩法：通关序列长度（简单 8 步 / 普通 12 / 困难 16）
  private winLen: number = GameDiff.pick(8, 12, 16);

  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private lit: number = -1;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private len: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private phase: string = 'show';    // show | input | over
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private seq: number[] = [];
  private showIdx: number = -1;
  private inputIdx: number = 0;
  private showTimer: number = -1;
  private flashTimer: number = -1;
  private gapTimer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSimonSays')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.winLen = GameDiff.pick(8, 12, 16);
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
      this.showTimer = -1;
    }
    if (this.flashTimer >= 0) {
      clearTimeout(this.flashTimer);
      this.flashTimer = -1;
    }
    if (this.gapTimer >= 0) {
      clearTimeout(this.gapTimer);
      this.gapTimer = -1;
    }
  }

  private reset(): void {
    this.clearTimers();
    this.seq = [];
    this.len = 0;
    this.score = 0;
    this.lit = -1;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.nextRound();
  }

  /** 序列加长一位，然后演示 */
  private nextRound(): void {
    this.seq.push(Math.floor(Math.random() * PADS));
    this.len = this.seq.length;
    this.showIdx = -1;
    this.inputIdx = 0;
    this.lit = -1;
    this.phase = 'show';
    this.msg = TG2("看好了… 第 {0} 关",Digits(String(this.len), this.langCode));
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
    }
    this.showTimer = setInterval(() => {
      this.showStep();
    }, SHOW_TICK);
  }

  /** 演示一步：先灭掉上一个，再亮下一个 */
  private showStep(): void {
    if (this.lit >= 0) {
      this.lit = -1;
      return;
    }
    if (this.showIdx + 1 < this.seq.length) {
      this.showIdx++;
      this.lit = this.seq[this.showIdx];
      return;
    }
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
      this.showTimer = -1;
    }
    this.lit = -1;
    this.phase = 'input';
    this.inputIdx = 0;
    this.msg = TG2("轮到你了，按顺序点 {0} 下", this.len);
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
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
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
    if (this.phase !== 'input') {
      return true;
    }
    this.tapPad(this.seq[this.inputIdx]);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值在 seq 里；phase !== input 是「演示中/过关间隙」⇒ 只能等
  /** 提示：报下一个该点的色块（用它的图标，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 'input') {
      return Hint.none('none');
    }
    const i: number = this.seq[this.inputIdx];
    return Hint.make([i],
      TG2('下一个按 {0}', PAD_ICON[i]),
      TG2('Next tap: {0}', PAD_ICON[i]), t0);
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

  private tapPad(i: number): void {
    if (this.phase !== 'input' || this.over) {
      return;
    }
    if (this.seq[this.inputIdx] !== i) {
      this.fail();
      return;
    }
    this.flash(i);
    this.inputIdx++;
    if (this.inputIdx < this.seq.length) {
      return;
    }
    // 这一关过了
    this.score += this.len * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.phase = 'wait';
    this.msg = TG2("✅ 第 {0} 关通过",Digits(String(this.len), this.langCode));
    if (this.len >= this.winLen) {
      this.won = true;
      this.over = true;
      this.phase = 'over';
      this.msg = TG2('🎉 撑到第 {0} 关，通关！', this.winLen);
      this.clearTimers();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.gapTimer >= 0) {
      clearTimeout(this.gapTimer);
    }
    this.gapTimer = setTimeout(() => {
      this.gapTimer = -1;
      this.nextRound();
    }, GAP_MS);
  }

  private flash(i: number): void {
    this.lit = i;
    if (this.flashTimer >= 0) {
      clearTimeout(this.flashTimer);
    }
    this.flashTimer = setTimeout(() => {
      this.flashTimer = -1;
      this.lit = -1;
    }, FLASH_MS);
  }

  private fail(): void {
    this.over = true;
    this.won = false;
    this.phase = 'over';
    this.lit = -1;
    this.msg = TG2("❌ 按错了，最长撑到 {0} 关",Digits(String(this.len), this.langCode));
    this.clearTimers();
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'simon_says',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.len
    };
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
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.len + '/' + this.winLen))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('状态'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'input' ? '你来' : (this.phase === 'show' ? '演示' : TG('结束'))))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      // ★ 色盲辅助（项目 D ③）：四块按钮的右上角各印一个固定字母 A/B/C/D。
      //   · 为什么放角落：中间被图标（🐸🍎💧⭐）占着；角落既不盖图标，也不遮整块「亮起」时的
      //     亮度与放大 —— 那是除颜色之外唯一能看出「哪块在闪」的提示。
      //   · 为什么 18 号：一块按钮约 155vp 见方（两列 =（屏宽-40-10)/2），18 号醒目又不喧宾夺主。
      //   · 字母与底色无关（A11y.glyph(按钮下标)）⇒ 红绿色盲/全色盲按字母记序列即可，玩法等价。
      //   · 叠层 hitTestBehavior(None)：它永远不接走点击，点到的仍然是原来那块按钮。
      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Stack() {
          Text(PAD_ICON[(0)]).fontSize(FontSize.xxxl)
          // ★ 色盲辅助：右上角字母 A~D
          Stack({ alignContent: Alignment.TopEnd }) {
          Text(A11y.glyph((0)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(A11y.glyphInk((0)))
          .textShadow(A11y.glyphShadow())
          }
          .width('100%')
          .height('100%')
          .padding(Space.sm)
          .hitTestBehavior(HitTestMode.None)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (0) ? Palette.amber : PAD_COLORS[(0)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (0) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (0) ? 1.06 : 1, y: this.lit === (0) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((0));
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPad((0)); }); })
          Stack() {
          Text(PAD_ICON[(1)]).fontSize(FontSize.xxxl)
          // ★ 色盲辅助：右上角字母 A~D
          Stack({ alignContent: Alignment.TopEnd }) {
          Text(A11y.glyph((1)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(A11y.glyphInk((1)))
          .textShadow(A11y.glyphShadow())
          }
          .width('100%')
          .height('100%')
          .padding(Space.sm)
          .hitTestBehavior(HitTestMode.None)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (1) ? Palette.amber : PAD_COLORS[(1)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (1) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (1) ? 1.06 : 1, y: this.lit === (1) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((1));
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPad((1)); }); })
        }
        .width('100%')
        Row({ space: Space.sm }) {
          Stack() {
          Text(PAD_ICON[(2)]).fontSize(FontSize.xxxl)
          // ★ 色盲辅助：右上角字母 A~D
          Stack({ alignContent: Alignment.TopEnd }) {
          Text(A11y.glyph((2)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(A11y.glyphInk((2)))
          .textShadow(A11y.glyphShadow())
          }
          .width('100%')
          .height('100%')
          .padding(Space.sm)
          .hitTestBehavior(HitTestMode.None)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (2) ? Palette.amber : PAD_COLORS[(2)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (2) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (2) ? 1.06 : 1, y: this.lit === (2) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((2));
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPad((2)); }); })
          Stack() {
          Text(PAD_ICON[(3)]).fontSize(FontSize.xxxl)
          // ★ 色盲辅助：右上角字母 A~D
          Stack({ alignContent: Alignment.TopEnd }) {
          Text(A11y.glyph((3)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(A11y.glyphInk((3)))
          .textShadow(A11y.glyphShadow())
          }
          .width('100%')
          .height('100%')
          .padding(Space.sm)
          .hitTestBehavior(HitTestMode.None)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (3) ? Palette.amber : PAD_COLORS[(3)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (3) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (3) ? 1.06 : 1, y: this.lit === (3) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((3));
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPad((3)); }); })
        }
        .width('100%')
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.md)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontWeight(FontWeight.Bold)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.orange)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
