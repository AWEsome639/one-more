/**
 * 拥挤视力（visual_crowding_acuity）—— 只答正中间那个字母：两侧干扰越挤，越难认
 * 胜负：8 题答对 ≥6 ⇒ 通关；进度：题号 / 答对 / 当前间距
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

const POOL: string[] = ['E', 'F', 'H', 'N', 'P', 'R', 'T', 'Z'];
const FIVE: number[] = [0, 1, 2, 3, 4];
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1];
const TOTAL: number = 8;
const NEED: number = 6;

@Component
export struct GVisualCrowdingAcuity {
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
  @State trialNo: number = 1;
  @State right: number = 0;
  @State target: string = 'E';
  @State flank: string = 'H';
  @State opts: string[] = [];
  @State pick: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private to: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GVisualCrowdingAcuity')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.to >= 0) { clearTimeout(this.to); this.to = -1; } }

  /** 越往后两侧贴得越近 ⇒ 拥挤越强 */
  private gap(): number { return Math.max(0, Space.xxxl - (this.trialNo - 1) * Space.xs); }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.msg = TG('只答正中间那个字母，两侧都是干扰');
    this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const t: string = POOL[Math.floor(Math.random() * POOL.length)];
    let f: string = POOL[Math.floor(Math.random() * POOL.length)];
    while (f === t) { f = POOL[Math.floor(Math.random() * POOL.length)]; }
    const opts: string[] = [t];
    while (opts.length < 4) {
      const x: string = POOL[Math.floor(Math.random() * POOL.length)];
      if (opts.indexOf(x) < 0) { opts.push(x); }
    }
    this.target = t;
    this.flank = f;
    this.opts = opts;
    this.pick = -1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：opts[i] === this.target 的那个选项
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
    if (this.pick >= 0 || this.over) {
      return true;              // 还在刺激/过渡阶段，等
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i] === this.target) {
        this.answer(i);
        return true;
      }
    }
    return false;
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

  // ═══════════ 提示（2026-10-29：策略提示，**不报答案**）═══════════
  // ★ 为什么这种给法、以及为什么 cells 恒为 []：
  //   这款的「正确答案」this.target 本来就明明白白画在屏幕正中（Row 第 3 个，
  //   颜色 Palette.berry），选项里也包括它 ⇒ **一旦说出是哪个字母，就等于代答**，
  //   这道题（拥挤视力）的测点当场作废。
  //   ⇒ 有用的只有「怎么看」：位置（第 3 个 / 共 5 个）、
  //     看哪个特征（横线条数 / 有没有斜线或腿，而不是整体轮廓）——
  //     字母表就是 E F H N P R T Z，彼此的差别全在这一两笔上；
  //     下一步动作（先在选项里挑「只差一笔」的一对，再比这一笔有没有）。
  //   这些都是方法，不是结果 —— 照做仍要玩家自己读出那个字母。
  //   全函数只读字段 + 一次 String 拼接，无循环无搜索 ⇒ 远低于 50ms。
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');          // 已经结束了，没有"下一步"可指
    }
    // 两侧间距随题号收紧（gap() 从 Space.xxxl 一路减到 0）⇒ 后半段换成更硬的招
    if (this.gap() <= Space.md) {
      return Hint.make([],
        TG('两侧快贴住中间了 —— 它们都是同一个字母；只认正中第 3 个的笔画（横线条数、有没有斜线或腿），别把三个当整体一起读'),
        TG('The flankers almost touch it and are all the same letter: judge the 3rd letter by its bars, diagonal or leg — never all three at once'),
        t0);
    }
    return Hint.make([],
      TG2('第 {0}/{1} 题 —— 只看正中间第 3 个字母（粉的那个）：数横线条数、看有没有斜线或腿，别整体认字；选项里先比只差一笔的一对',
        String(this.trialNo), String(this.diffTotal)),
      TG2('Trial {0}/{1} — read only the 3rd letter (the pink one): count its horizontal bars, check for a diagonal or a leg; compare the two options that differ by one stroke',
        String(this.trialNo), String(this.diffTotal)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    // 兜底话只在 over 时用得上（其余分支都给得出提示），绝不会抛
    Hint.toastResult(r, TG('这局已经结束，点「再来一局」'));
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    if (this.opts[i] === this.target) { this.right = this.right + 1; this.msg = TG2('✅ 正确，中间是 {0}', this.target); }
    else { this.msg = TG2('❌ 中间是 {0}', this.target); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.trialNo >= this.diffTotal) { this.finishUp(); return; }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
    }, 700);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
    this.clearAll();
    const r: GameResult = {
      gameId: 'visual_crowding_acuity', solved: this.won, score: this.right * 130,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({

        onHintTap: () => { this.askHint(); },

        onAutoTap: () => { this.askAuto(); },

        showHint: true,

        demoOn: false,

        disabled: this.demoId >= 0,

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('间距'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.gap()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Row({ space: this.gap() }) {
          ForEach(FIVE, (c: number) => {
            Text(c === 2 ? this.target : this.flank).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(c === 2 ? Palette.berry : this.theme.inkSoft).textAlign(TextAlign.Center)
          }, (c: number) => 'l' + c)
        }.width('100%').justifyContent(FlexAlign.Center)
        Text(TG('两侧越挤，中间越难认')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').height(148).justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (c: number) => {
              Text(this.opts[(r * 2 + c)]).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.pick === (r * 2 + c) ? '#FFFFFF' : this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(58))
              .backgroundColor(this.pick === (r * 2 + c) ? Palette.berry : this.theme.surfaceAlt)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .scale({ x: this.pick === (r * 2 + c) ? Motion.pressScale : 1, y: this.pick === (r * 2 + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { Haptics.tick(); this.answer((r * 2 + c)); })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((r * 2 + c)); }); })
            }, (c: number) => 'o' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')


      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.berry).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })

      Text(TG('提示：越挤越要靠特征辨认，别猜整体轮廓'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
