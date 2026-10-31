/**
 * AB 反转 —— 刺激按「圆/菱」交替出现，偶尔连续两次相同（= 反转）
 * 一击：看到反转立刻点「反转！」；正常交替时点 = 误报
 * 胜负：24 帧内命中 ≥5 且误报 ≤2 通关　进度：帧号 / 命中 / 误报 / 得分
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

const TOTAL: number = 24; const FRAME_MS: number = 700; const BLINK_MS: number = 260;
const FLIP_CHANCE: number = 0.2; const NEED_HIT: number = 5; const MAX_FA: number = 2;
const A: string = '●'; const B: string = '◆';

@Component
export struct GAbReversalOddball {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State sym: string = A; @State flip: boolean = false; @State flash: string = '';
  @State frame: number = 0; @State hits: number = 0; @State fa: number = 0; @State miss: number = 0;
  @State score: number = 0; @State over: boolean = false; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private resp: boolean = false;
  private timer: number = -1; private flashTo: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAbReversalOddball')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.flashTo >= 0) { clearTimeout(this.flashTo); this.flashTo = -1; }
  }

  private reset(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.sym = Math.random() < 0.5 ? A : B; this.flip = false; this.resp = false; this.flash = '';
    this.frame = 1; this.hits = 0; this.fa = 0; this.miss = 0; this.score = 0;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.msg = TG('看到「反常」（连续两次同一个）就点按钮');
    this.timer = setInterval(() => { this.tick(); }, FRAME_MS);
  }

  /** 推进一帧；先把上一帧判掉：反转没点 ⇒ 记一次漏 */
  private tick(): void {
    if (this.over) { return; }
    if (this.flip && !this.resp) { this.miss = this.miss + 1; }
    if (this.frame >= this.diffTotal) { this.end(); return; }
    const last: string = this.sym;
    let next: string = last === A ? B : A;
    if (Math.random() < FLIP_CHANCE) { next = last; }
    this.flip = next === last; this.sym = next; this.resp = false; this.frame = this.frame + 1;
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
    if (!this.flip || this.resp) {
      return true;
    }
    this.tapFlip();
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.flip) {
      return Hint.make([], TG2('这一帧是反常（连着两次同一个图形）⇒ 点「反转！」'),
        TG2('This frame repeats the same shape — tap 反转！'), t0);
    }
    return Hint.make([], TG2('这一帧是正常交替 ⇒ 别点，等下一帧'),
      TG2('Normal alternation this frame — do not tap'), t0);
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

  private tapFlip(): void {
    if (this.over) { return; }
    if (this.resp) { this.msg = TG('这一帧已经判过了'); return; }
    const isFlip: boolean = this.flip;
    this.resp = true;
    if (isFlip) {
      this.hits = this.hits + 1; this.score = this.score + 120;
      this.flash = Palette.emerald; this.msg = TG('✅ 抓到反转！');
    } else {
      this.fa = this.fa + 1; this.score = Math.max(0, this.score - 40);
      this.flash = Palette.rose; this.msg = TG('❌ 这次是正常交替');
    }
    if (this.flashTo >= 0) { clearTimeout(this.flashTo); }
    this.flashTo = setTimeout(() => { this.flashTo = -1; this.flash = ''; }, BLINK_MS);
  }

  private end(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.over = true; this.won = this.hits >= NEED_HIT && this.fa <= MAX_FA;
    this.msg = this.won ? '🎉 命中 ' + this.hits + ' 次、误报 ' + this.fa + ' 次，通关！'
      : '💤 命中 ' + this.hits + '/' + NEED_HIT + '、误报 ' + this.fa + '（限 ' + MAX_FA + '）';
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'ab_reversal_oddball', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private boxColor(): string {
    if (this.flash.length > 0) { return this.flash; }
    return this.theme.surface;
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
        Text((TG('帧号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.frame + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('命中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hits), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('误报'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.fa), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Stack() {
        Text(this.sym).fontSize(FontSize.hero).fontWeight(FontWeight.Bold)
          .fontColor(this.flash.length > 0 ? '#FFFFFF' : this.theme.ink)
      }
      .width('100%').height(160)
      .backgroundColor(this.boxColor()).borderRadius(Radius.lg).shadow(Shadow.lifted)
      .animation({ duration: Motion.fast, curve: Motion.snap() })

      Button(TG('反转！'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(64)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tapFlip(); }); }).onClick(() => { Haptics.tap(); this.tapFlip(); })

      Row({ space: Space.sm }) {
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : '正在跑…')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44)).enabled(false)
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Text(TG2('提示：漏掉的反转 {0} 次 —— 只在连续两次同一个时点才抓对了',Digits(String(this.miss), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
