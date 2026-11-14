/** 分数匹配 —— 找相等分数；玩法：给出一个分数，从四个分数里选出与它等值的那个；胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 900; const LETTERS: string[] = ['A', 'B', 'C', 'D'];
@Component
export struct GFractionMatcher {
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
  // ★ 2026-11-08 常驻结果行：反馈不再依赖显示的几秒，随时能回看上一题的对错
  @State private lastFb: string = '';
  @State private lastOk: boolean = true;
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
    this.lastFb = ''; this.lastOk = true;   // ★ 重开清常驻结果行
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
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    // 屏幕题面是 a/b，选项是 "p/q"：**等值**判据 = p*b === a*q（约分后相同）
    for (let i = 0; i < this.opts.length; i++) {
      const parts: string[] = this.opts[i].split('/');
      if (parts.length !== 2) {
        continue;
      }
      const p: number = Number.parseInt(parts[0], 10);
      const q: number = Number.parseInt(parts[1], 10);
      if (isNaN(p) || isNaN(q)) {
        continue;
      }
      if (p * this.b === this.a * q) {
        this.pick(i);
        return !this.over;
      }
    }
    return false;             // 没有等值项 ⇒ 停手（不读 ans 下标）
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
    // ★ 2026-11-08 常驻结果行：在加载下一题之前，把上一题的反馈存下来（窗口再短也能回看）
      const fbV: string = this.msg;
      if (fbV.indexOf('✅') >= 0 || fbV.indexOf('🎉') >= 0) { this.lastFb = fbV; this.lastOk = true; }
      else if (fbV.indexOf('❌') >= 0 || fbV.indexOf('💤') >= 0 || fbV.indexOf('😵') >= 0 || fbV.indexOf('⏰') >= 0 || fbV.indexOf('⌛') >= 0) { this.lastFb = fbV; this.lastOk = false; }

    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG2('🎉 答对 {0}/{1}，通关！', String(this.right), String(this.diffTotal))
        : TG2('😵 只答对 {0}/{1}，差 {2} 题', String(this.right), String(this.diffTotal), String(PASS - this.right));
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

  // ★ 2026-11-14：选项卡片抽成 Builder —— 矮屏 2×2 时用 `layoutWeight(1)` 平分宽度，
  //   高屏竖列时用 `width('100%')` 独占一行。其余样式与原来逐字一致。
  @Builder optCard(i: number, inGrid: boolean) {
    Row({ space: Space.sm }) {
      Text(LETTERS[i]).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      Text(this.opts[i]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1)
    }.width('100%').layoutWeight(inGrid ? 1 : 0).height(Cell.of(48))
    .padding({ left: Space.sm, right: Space.sm })
    .backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on())
    .onFocus(() => { this.tvFocus = 'L306'; })
    .onBlur(() => { if (this.tvFocus === 'L306') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'L306'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); })
    .onClick(() => { Haptics.tick(); this.pick(i); })
    .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
      .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
  }

  build() {
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.right + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        // 2026-11-13 真机截图（lowest='B' 在 1600）：**选项 B 被切** ⇒ 按判据 1886 缩**上方**的题卡
        Text('½').fontSize(Bp.isShort() ? FontSize.lg : FontSize.xxl)
        Row({ space: Space.sm }) {
          Column({ space: 2 }) {
            Text(Digits(String(this.a), this.langCode)).fontSize(Bp.isShort() ? FontSize.xxl : FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
            Row().width(48).height(2).backgroundColor(this.theme.lineSoft)
            Text(Digits(String(this.b), this.langCode)).fontSize(Bp.isShort() ? FontSize.xxl : FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
          }.alignItems(HorizontalAlign.Center)
          Text('= ?')          // ★ 2026-11-03（第 1119 轮）**装饰性元素从无障碍树摘掉**
          //   「= ?」是题目版式的一部分（题目本身由 q 表达），
          //   读屏念「等于问号」只是噪音 ⇒ accessibilityLevel('no')
          .accessibilityLevel('no')
          .fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
        }.alignItems(VerticalAlign.Center)
      // ★ 2026-11-14：`md(16) → sm(10)`，上下共省 12vp = 36px（题卡内部，不碰触控区）
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      // ★ 常驻结果行：答过之后固定显示上一次对错（用全角空格占位，避免布局跳动）
      Text(this.lastFb.length > 0 && this.lastFb !== this.msg ? this.lastFb : '　')
        .fontSize(FontSize.xxs).fontColor(this.lastOk ? Palette.emerald : Palette.rose)
        .width('100%').textAlign(TextAlign.Center)
      // ★ 2026-11-14 真机（判据 2605）：**矮屏上 4 个选项竖排装不下** ——
      //   每个 `Cell.of(48)`≈41vp、间隙 `Space.sm`=10vp ⇒ 选项区本身就要 ~194vp，
      //   而题卡之后只剩 ~148vp ⇒ 实测（`截图-Fraction_Matcher-185409.jpeg`）：
      //   只有 `A` 完整、`B` 被屏底切掉、**`C`/`D` 完全不在屏内**。
      //   而 `L90` 明确生成 **4 个**选项 ⇒ 答案落在 C/D 时玩家**根本点不到** = 不能正常玩。
      //   ⇒ 矮屏改 **2×2**（省约 102vp，且选项更宽、点击目标更大），高屏保留竖列。
      Column({ space: Bp.isShort() ? Space.xs : Space.sm }) {
        ForEach(Bp.isShort() ? [0, 2] : [0, 1, 2, 3], (i: number) => {
          if (Bp.isShort()) {
            Row({ space: Space.sm }) {
              this.optCard(i, true)
              this.optCard(i + 1, true)
            }.width('100%')
          } else {
            this.optCard(i, false)
          }
        }, (i: number) => 'fmat' + i + '_' + this.opts[i] + '_' + (Bp.isShort() ? this.opts[i + 1] : ''))
      }.width('100%')
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L326'; })
        .onBlur(() => { if (this.tvFocus === 'L326') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L326')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：分子分母同乘（同除）一个非零数，分数的值不变'))
        // ★ 2026-11-12（判据 1950）：纯说明行，矮屏隐藏腾 ~17vp
        .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
