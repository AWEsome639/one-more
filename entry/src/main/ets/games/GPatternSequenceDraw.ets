/**
 * 画规律 —— 按规律画图案
 *
 * 玩法：3×3 格子按 1~9 编号；从 1 出发，每次前进 k 格（数满 9 回到 1），
 *       按这个规律依次点格子，把整幅图案画出来。
 * 胜负：9 格全部按序点亮 ⇒ 通关；点错 3 次 ⇒ 失败。
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

const SIDE: number = 3;
const COUNT: number = SIDE * SIDE;
const LIVES: number = 3;
const STEPS: number[] = [2, 4, 5, 7];   // 与 9 互质 ⇒ 一定不重复地走遍 9 格

@Component
export struct GPatternSequenceDraw {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private step: number = 2;
  @State private trail: number[] = [];
  @State private err: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = [0, 1, 2];
  private cols: number[] = [0, 1, 2];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPatternSequenceDraw')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
    this.reset();
  }

  private reset(): void {
    this.step = STEPS[Math.floor(Math.random() * STEPS.length)];
    this.trail = [];
    this.err = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG2('从 1 开始，每次 +{0}（数满 {1} 回到 1），按顺序点',Digits(String(this.step), this.langCode),Digits(String(COUNT), this.langCode));
  }

  /** 下一个该点的格子编号（1~9） */
  private want(): number {
    const cur: number = this.trail.length === 0 ? 1 : this.trail[this.trail.length - 1];
    return ((cur - 1 + this.step) % COUNT) + 1;
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
    this.tap(this.want());
    return !this.over;
  }

  /** 提示：下一个该画的点 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const need: number = this.want();
    return Hint.make([need], TG2('下一个画到 {0}', String(need)),
      TG2('Next point {0}', String(need)), t0);
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

  private tap(n: number): void {
    if (this.over) {
      return;
    }
    const need: number = this.want();
    if (n === need) {
      const t: number[] = this.trail.slice();
      t.push(n);
      this.trail = t;
      this.msg = TG2('✅ 画到 {0}', n);
      if (this.trail.length >= COUNT) {
        this.msg = TG('🎉 规律走满 9 格，图案画完了！');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.err = this.err + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.err >= this.diffTotal) {
      this.msg = TG2('❌ 点错 {0} 次，规律断了',Digits(String(this.diffTotal), this.langCode));
      this.finish(false);
      return;
    }
    this.msg = TG2('❌ 这一笔该点 {0}', need);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'pattern_sequence_draw',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.err * 200) : this.trail.length * 100,
      durationMs: Date.now() - this.startAt,
      levelReached: this.trail.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private rank(n: number): number {
    return this.trail.indexOf(n);
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
        Text((TG('规律'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((TG2('每次 +{0}',Digits(String(this.step), this.langCode)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trail.length + '/' + COUNT)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.err + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (c: number) => {
              Stack() {
              Column({ space: 2 }) {
              Text(String((r * SIDE + c + 1))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.rank((r * SIDE + c + 1)) >= 0 ? '#FFFFFF' : this.theme.ink)
              Text(this.rank((r * SIDE + c + 1)) >= 0 ? '第' + (this.rank((r * SIDE + c + 1)) + 1) + '笔' : '').fontSize(FontSize.xxs).fontColor('#FFFFFF')
              }
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.rank((r * SIDE + c + 1)) >= 0 ? Palette.rose : this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              Haptics.tick();
              this.tap((r * SIDE + c + 1));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * SIDE + c + 1)); }); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').layoutWeight(1)

      Text(this.over ? this.msg : ('下一笔该点 ' + this.want() + ' —— ' + this.msg)).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.rose).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
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
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
