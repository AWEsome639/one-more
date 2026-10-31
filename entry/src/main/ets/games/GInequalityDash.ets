/** 不等式冲刺 —— 限时解不等式；玩法：把 ax + c ⋚ k 解成 x 的范围，四选一，60 秒内尽量多答；胜负：答对 8 题 ⇒ 通关；时间到 ⇒ 按答对数判失败 */
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
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const LIMIT: number = 60; const TARGET: number = 8; const NEXT_MS: number = 480;
const OPS: string[] = ['<', '≤', '>', '≥']; const ROWS: number[] = [0, 1]; const COLS: number[] = [0, 1];
@Component
export struct GInequalityDash {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
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
  @State private expr: string = '';
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private opts: string[] = [];
  @State private ans: number = 0;
  @State private picked: number = -1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private hits: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private tick: number = -1; private nextTo: number = -1;
  private finished: boolean = false; private cells: number[] = [0, 1, 2, 3];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GInequalityDash')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.left = this.total; this.hits = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG('移项、两边同除系数，注意不等号方向');
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.left = this.left - 1;
      if (this.left > 0) { return; }
      this.left = 0;
      if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
      if (this.over) { return; }
      this.over = true; this.won = this.hits >= TARGET;
      this.msg = this.won ? TG('🎉 答对 ') + String(this.hits) + ' 题，通关！'
        : '⏰ 时间到，只答对 ' + String(this.hits) + '/' + String(TARGET) + TG(' 题');
      this.finish(this.won);
    }, 1000);
  }
  /** 出题：a·x + c ⋚ k ⇒ x ⋚ (k-c)/a，正确答案 + 3 个易错项 */
  private ask(): void {
    const a: number = 2 + Math.floor(Math.random() * 3);        // 2 ~ 4
    const sol: number = 2 + Math.floor(Math.random() * 8);      // 2 ~ 9
    const c: number = 1 + Math.floor(Math.random() * 9); const oi: number = Math.floor(Math.random() * 4);
    const k: number = a * sol + c; this.expr = String(a) + 'x + ' + String(c) + ' ' + OPS[oi] + ' ' + String(k);
    const flip: number = oi < 2 ? oi + 2 : oi - 2; const good: string = OPS[oi] + ' ' + String(sol);
    const pool: string[] = [
      OPS[flip] + ' ' + String(sol),
      OPS[oi] + ' ' + String(sol + 1),
      OPS[oi] + ' ' + String(sol - 1),
      OPS[flip] + ' ' + String(sol + 2)
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
    this.picked = i;
    if (i === this.ans) {
      this.hits = this.hits + 1; this.score += 120 + this.left; this.msg = TG2('✅ 答案 x {0}', this.opts[this.ans]); this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
      if (this.hits >= TARGET) {
        this.over = true; this.won = true;
        this.msg = TG2("🎉 答对 {0} 题，用了 {1} 秒", String(TARGET), String(LIMIT - this.left)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
    } else {
      this.score = Math.max(0, this.score - 25); this.msg = TG2('❌ 应是 x {0}', this.opts[this.ans]);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.ask(); }, NEXT_MS);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    const r: GameResult = {
      gameId: 'inequality_dash', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private btnBg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.ans) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private btnInk(i: number): string {
    if (this.picked < 0) { return this.theme.ink; }
    if (i === this.ans) { return '#FFFFFF'; }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + '/' + TARGET)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('🔢').fontSize(FontSize.xxl)
          .accessibilityLevel('no')
        Text(this.expr).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
        Text(TG('x 的范围是？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (col: number) => {
              Stack() {
              Text('x ' + this.opts[(row * 2 + col)]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.btnInk((row * 2 + col)))
              }.layoutWeight(1).height(Cell.of(56)).backgroundColor(this.btnBg((row * 2 + col))).borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((row * 2 + col)); }); }).onClick(() => { Haptics.tick(); this.pick((row * 2 + col)); })
            }, (col: number) => 'idc' + col)
          }.width('100%')
        }, (row: number) => 'idr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
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
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：ax + c > k ⇒ x > (k−c)/a；两边同除负数才要变号')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
