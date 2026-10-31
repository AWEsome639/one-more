/** 分数匹配 —— 找相等分数；玩法：给出一个分数，从四个分数里选出与它等值的那个；胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */
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

const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 780; const LETTERS: string[] = ['A', 'B', 'C', 'D'];
@Component
export struct GFractionMatcher {
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
  @State private a: number = 1;
  @State private b: number = 2;
  @State private opts: string[] = [];
  @State private ans: number = 0;
  @State private picked: number = -1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private nextTo: number = -1; private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFractionMatcher')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.right = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG('选出与它等值的分数（同乘同一个数）');
  }
  /** 出题：正确项 = 同乘 k；三个干扰项都与原分数不等值 */
  private ask(): void {
    this.a = 1 + Math.floor(Math.random() * 5);                     // 1 ~ 5
    this.b = this.a + 1 + Math.floor(Math.random() * 5);            // 比 a 大
    const k: number = 2 + Math.floor(Math.random() * 3);            // 2 ~ 4
    const good: string = String(this.a * k) + '/' + String(this.b * k);
    const pool: string[] = [
      String(this.a + 1) + '/' + String(this.b),
      String(this.a) + '/' + String(this.b + 1),
      String(this.a * k) + '/' + String(this.b * k + 1),
      String(this.a * k + 1) + '/' + String(this.b * k),
      String(this.a + 2) + '/' + String(this.b)
    ]; const list: string[] = [good];
    for (let i = 0; i < pool.length && list.length < 4; i++) {
      if (list.indexOf(pool[i]) < 0) { list.push(pool[i]); }
    }
    for (let i = list.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: string = list[i]; list[i] = list[j]; list[j] = t;
    }
    this.opts = list; this.ans = list.indexOf(good); this.picked = -1;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是「{0}」', this.opts[n]),
      TG2('The answer is "{0}"', this.opts[n]), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

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
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
    return !this.over;
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i; const good: string = this.opts[this.ans];
    if (i === this.ans) {
      this.right = this.right + 1; this.score += 130; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ {0}/{1} = {2}（上下同乘）', String(this.a), String(this.b), good);
    } else {
      this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ {0} 不等值，正确是 {1}', this.opts[i], good); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask();
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'fraction_matcher', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private optBg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.ans) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private optInk(i: number): string {
    if (this.picked < 0) { return this.theme.ink; }
    if (i === this.ans) { return '#FFFFFF'; }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('½').fontSize(FontSize.xxl)
        Row({ space: Space.sm }) {
          Column({ space: 2 }) {
            Text(Digits(String(this.a), this.langCode)).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
            Row().width(48).height(2).backgroundColor(this.theme.lineSoft)
            Text(Digits(String(this.b), this.langCode)).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
          }.alignItems(HorizontalAlign.Center)
          Text('= ?').fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
        }.alignItems(VerticalAlign.Center)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i]).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
            Text(this.opts[i]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1)
          }.width('100%').height(Cell.of(48)).padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); }).onClick(() => { Haptics.tick(); this.pick(i); })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'fmat' + i + '_' + this.opts[i])
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
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
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：分子分母同乘（同除）一个非零数，分数的值不变')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
