/**
 * 猜球 —— 🎲 看清球在哪个碗下，洗牌后点出它的位置（id: shell_game）
 * 胜负：连中 5 关 ⇒ 通关（每关多洗 2 次）；进度：猜中/5 · 洗牌次数 · 阶段
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
const LEVELS: number = 5;
const BASE_SWAPS: number = 4;
const SHOW_MS: number = 1400;
const SWAP_MS: number = 360;
@Component
export struct GShellGame {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};
  @State private order: number[] = [0, 1, 2];
  @State private ballCup: number = 0;
  @State private level: number = 0;
  @State private wins: number = 0;
  @State private swaps: number = BASE_SWAPS;
  @State private phase: string = 'show';
  @State private hotA: number = -1;
  @State private hotB: number = -1;
  @State private reveal: boolean = false;
  @State private pickSlot: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private toId: number = -1;
  private ivId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GShellGame')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
    if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.level = 0; this.wins = 0; this.hotA = -1; this.hotB = -1; this.pickSlot = -1;
    this.reveal = false; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newRound();
  }
  private newRound(): void {
    this.order = [0, 1, 2];
    this.ballCup = Math.floor(Math.random() * 3);
    this.swaps = BASE_SWAPS + this.level * 2;
    this.phase = 'show'; this.reveal = true; this.hotA = -1; this.hotB = -1; this.pickSlot = -1;
    this.msg = TG2("看好球 → 第 {0} 关，洗 {1} 次", String(this.level + 1),Digits(String(this.swaps), this.langCode));
    this.toId = setTimeout(() => { this.toId = -1; this.startShuffle(); }, SHOW_MS);
  }
  private startShuffle(): void {
    this.reveal = false; this.phase = 'shuffle'; this.msg = TG('洗牌中…');
    let left: number = this.swaps;
    this.ivId = setInterval(() => {
      const i: number = Math.floor(Math.random() * 3);
      const j: number = (i + 1) % 3;
      const nx: number[] = this.order.slice();
      const t: number = nx[i];
      nx[i] = nx[j];
      nx[j] = t;
      this.order = nx;
      this.hotA = i; this.hotB = j;
      left = left - 1;
      if (left <= 0) {
        if (this.ivId >= 0) { clearInterval(this.ivId); this.ivId = -1; }
        this.hotA = -1; this.hotB = -1; this.phase = 'pick'; this.msg = TG('球在哪个碗下？');
      }
    }, SWAP_MS);
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
    if (this.phase !== 'pick') {
      return true;
    }
    this.pick(this.order.indexOf(this.ballCup));
    return !this.over;
  }

  /** 提示：洗完之后球就在某个碗下面 —— 直接报「从左数第几个」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 'pick') {
      return Hint.none('none');
    }
    const k: number = this.order.indexOf(this.ballCup);
    if (k < 0) {
      return Hint.none('none');
    }
    return Hint.make([k],
      TG2('球在从左数第 {0} 个碗下', String(k + 1)),
      TG2('The ball is under cup {0} from the left', String(k + 1)), t0);
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

  private pick(slot: number): void {
    if (this.phase !== 'pick' || this.over) { return; }
    this.phase = 'done'; this.pickSlot = slot; this.reveal = true;
    const cup: number = this.order[slot];
    if (cup === this.ballCup) {
      this.wins = this.wins + 1;
      this.msg = TG('✅ 命中！');
      if (this.wins >= this.diffTotal) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 通关 · 连中 {0} 关",Digits(String(this.diffTotal), this.langCode));
        this.end();
        return;
      }
      this.level = this.level + 1;
      this.toId = setTimeout(() => { this.toId = -1; this.newRound(); }, 850);
      return;
    }
    this.over = true; this.won = false; this.msg = TG('❌ 球在另一个碗下');
    this.end();
  }
  private end(): void {
    if (this.done) { return; }
    this.clearAll();
    this.done = true;
    const r: GameResult = {
      gameId: 'shell_game', solved: this.won, score: this.wins * 100 + this.level * 20,
      durationMs: Date.now() - this.startAt, levelReached: this.wins
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
        Column({ space: Space.xs }) {
        Text((TG('猜中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.wins) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('洗牌'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.swaps) + TG(' 次'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('状态'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'shuffle' ? '洗牌' : (this.phase === 'pick' ? '快选' : '看球'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        ForEach([0, 1, 2], (slot: number) => {
          Column({ space: Space.xs }) {
          Text(this.reveal && this.order[(slot)] === this.ballCup ? '⚪' : '').fontSize(FontSize.xl).height(Cell.of(30))
          Text('🥣').fontSize(FontSize.hero)
            .accessibilityLevel('no')
          }.layoutWeight(1).height(160).justifyContent(FlexAlign.End).padding(Space.sm)
          .borderRadius(Radius.lg).shadow(Shadow.card)
          .backgroundColor(this.pickSlot === (slot) ? Palette.primaryDeep : (this.hotA === (slot) || this.hotB === (slot) ? Palette.amber : this.theme.surface))
          .scale({ x: this.pickSlot === (slot) ? Motion.pressScale : 1, y: this.pickSlot === (slot) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.pick((slot)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((slot)); }); })
        }, (slot: number) => 's' + slot)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：连中 5 关通关；每过一关多洗 2 次'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
