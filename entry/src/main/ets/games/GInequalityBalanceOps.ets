/** 不等式天平 —— 天平不等关系；玩法：比较左右两边的算式，选出正确的 < / = / >；胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */
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

const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 800;
/** 0 = '<'，1 = '='，2 = '>' */
function sym(k: number): string {
  if (k === 0) { return '<'; }
  return k === 1 ? '=' : '>';
}
@Component
export struct GInequalityBalanceOps {
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
  @State private exprL: string = '';
  @State private exprR: string = '';
  @State private panL: number = 0;
  @State private panR: number = 0;
  @State private cmp: number = 1;
  @State private picked: number = -1;
  @State private round: number = 1;
  @State private hits: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private hitsPulse: number = 1;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private nextTo: number = -1; private finished: boolean = false;
  private slots: number[] = [0, 1, 2];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GInequalityBalanceOps')) {
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
    this.round = 1; this.hits = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG('先各算一边，再放符号');
  }
  private ask(): void {
    const a: number = 2 + Math.floor(Math.random() * 8); const b: number = 1 + Math.floor(Math.random() * 6);
    const c: number = 1 + Math.floor(Math.random() * 9); this.panL = a * b + c;
    this.exprL = String(a) + '×' + String(b) + '+' + String(c);
    if (Math.random() < 0.25) {
      // 四分之一概率造出「相等」的一题
      const e: number = 1 + Math.floor(Math.random() * (this.panL - 2)); this.panR = this.panL;
      this.exprR = '1×' + String(e) + '+' + String(this.panL - e);
    } else {
      const d: number = 2 + Math.floor(Math.random() * 8); const e: number = 1 + Math.floor(Math.random() * 6);
      const f: number = 1 + Math.floor(Math.random() * 9); this.panR = d * e + f;
      this.exprR = String(d) + '×' + String(e) + '+' + String(f);
    }
    this.cmp = this.panL < this.panR ? 0 : (this.panL === this.panR ? 1 : 2); this.picked = -1;
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.cmp],
      TG2('答案是第 {0} 个', String(this.cmp + 1)),
      TG2('The answer is option {0}', String(this.cmp + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.cmp  ｜ 守卫取自它自己的 if (...) { return; }
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
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
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
    if (this.picked >= 0 || this.over) {
      return true;
    }
    this.pick(this.cmp);
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
    if (i === this.cmp) {
      this.hits = this.hits + 1; this.score += 130; this.hitsPulse = 1.3; setTimeout(() => { this.hitsPulse = 1; }, 140);
      this.msg = TG2('✅ 左边 {0} {1} 右边 {2}', String(this.panL), sym(this.cmp), String(this.panR));
    } else {
      this.score = Math.max(0, this.score - 20);
      this.msg = TG2("❌ {0} 与 {1} 应是 {2}", String(this.panL), String(this.panR), )
        sym(this.cmp) + TG2('，不是 {0}', sym(i));
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.hits) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.hits) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.hits) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask();
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'inequality_balance_ops', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private btnBg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.cmp) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private btnInk(i: number): string {
    if (this.picked < 0) { return this.theme.ink; }
    if (i === this.cmp) { return '#FFFFFF'; }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + '/' + PASS)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.hitsPulse, y: this.hitsPulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text(true ? this.exprL : this.exprR).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(this.picked < 0 ? '？' : String(true ? this.panL : this.panR)).fontSize(FontSize.xl).fontColor(this.theme.ink)
        }.layoutWeight(1)
        Column({ space: 2 }) {
          Text('⚖️').fontSize(FontSize.xxl)
            .accessibilityLevel('no')
          Text(this.picked < 0 ? '?' : sym(this.cmp)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
            .fontColor(this.picked < 0 ? this.theme.inkFaint : Palette.emerald)
        }
        Column({ space: 2 }) {
        Text(false ? this.exprL : this.exprR).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(this.picked < 0 ? '？' : String(false ? this.panL : this.panR)).fontSize(FontSize.xl).fontColor(this.theme.ink)
        }.layoutWeight(1)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Button(sym(i))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xxl).fontColor(this.btnInk(i))
            .backgroundColor(this.btnBg(i)).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
            .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick(i); }); }).onClick(() => { Haptics.tap(); this.pick(i); })
            // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
            .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
              .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'ibo' + i)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：先算乘、再算加；两边都算完才好放符号')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
  /** which: 0 = 左盘，1 = 右盘 */



}
