/**
 * 矩阵乘法 —— 计算矩阵乘积
 * 玩法：给出 2×2 矩阵 A、B，求乘积 C 的指定元素（A 的行、B 的列高亮）。
 * 胜负：60 秒内答对 8 题 ⇒ 通关；时间归零 ⇒ 失败。
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

const SIZE: number = 2; const CELLS: number = 4; const GOAL: number = 8;
const LIMIT: number = 60; const TICK_MS: number = 1000; const PENALTY: number = 3; const NEXT_MS: number = 420;
const HOT: string = '#33F43F5E';
const ROWS: number[] = [0, 1];
const OPT_IDX: number[] = [0, 1, 2, 3];

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GMatrixMultiplier {
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
  @State private ma: number[] = [];
  @State private mb: number[] = [];
  @State private wantR: number = 0;
  @State private wantC: number = 0;
  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private right: number = 0;
  @State private combo: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private press: number = -1;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1;
  private nextTo: number = -1; private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMatrixMultiplier')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.stop();
    this.right = 0; this.combo = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.ask();
    this.msg = TG('取 A 的一行 与 B 的一列，对应项相乘再相加');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); }
  }

  private ask(): void {
    const ma: number[] = [];
    const mb: number[] = [];
    for (let i = 0; i < CELLS; i++) { ma.push(ri(1, 9)); mb.push(ri(1, 9)); }
    const wantR: number = ri(0, 1);
    const wantC: number = ri(0, 1);
    const correct: number = ma[wantR * SIZE] * mb[wantC] + ma[wantR * SIZE + 1] * mb[SIZE + wantC];
    const cand: number[] = [
      ma[wantR * SIZE] * mb[wantC], ma[wantR * SIZE + 1] * mb[SIZE + wantC],
      correct + 1, correct - 1, correct + ri(3, 7)
    ];
    const opts: number[] = [correct];
    for (let i = 0; i < cand.length && opts.length < 4; i++) {
      if (cand[i] > 0 && opts.indexOf(cand[i]) < 0) { opts.push(cand[i]); }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i]; opts[i] = opts[j]; opts[j] = t;
    }
    this.ma = ma; this.mb = mb; this.wantR = wantR; this.wantC = wantC;
    this.opts = opts; this.ans = opts.indexOf(correct); this.picked = -1;
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
      TG2('答案是 {0}', String(this.opts[n])),
      TG2('The answer is {0}', String(this.opts[n])), t0);
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
      this.right = this.right + 1; this.combo = this.combo + 1;
      this.score = this.score + 60 + this.combo * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ 答对！连击 ×{0}', String(this.combo));
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒（正确答案已标绿）", String(PENALTY));
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) { return; }
    if (this.right >= GOAL) { this.end(true, TG('🎉 答对 ') + String(GOAL) + TG(' 题，通关！剩 ') + String(this.left) + TG(' 秒')); return; }
    if (this.left <= 0) { this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); return; }
    this.ask();
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'matrix_multiplier', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private hot(isA: boolean, rr: number, cc: number): boolean {
    return isA ? rr === this.wantR : cc === this.wantC;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(GOAL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Column({ space: Space.xs }) {
          ForEach(ROWS, (rr: number) => {
          Row({ space: Space.xs }) {
          ForEach(ROWS, (cc: number) => {
          Text(String((true) ? this.ma[rr * SIZE + cc] : this.mb[rr * SIZE + cc]))
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.hot((true), rr, cc) ? '#FFFFFF' : this.theme.ink)
          .layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
          .backgroundColor(this.hot((true), rr, cc) ? Palette.rose : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (cc: number) => 'gc' + cc)
          }.width('100%')
          }, (rr: number) => 'gr' + rr)
          }.layoutWeight(1)
          Text('×').accessibilityText(TG('乘')).fontSize(FontSize.xl).fontColor(this.theme.inkSoft)
          Column({ space: Space.xs }) {
          ForEach(ROWS, (rr: number) => {
          Row({ space: Space.xs }) {
          ForEach(ROWS, (cc: number) => {
          Text(String((false) ? this.ma[rr * SIZE + cc] : this.mb[rr * SIZE + cc]))
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.hot((false), rr, cc) ? '#FFFFFF' : this.theme.ink)
          .layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
          .backgroundColor(this.hot((false), rr, cc) ? Palette.rose : this.theme.surfaceAlt)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (cc: number) => 'gc' + cc)
          }.width('100%')
          }, (rr: number) => 'gr' + rr)
          }.layoutWeight(1)
          Text('=').accessibilityText(TG('等于')).fontSize(FontSize.xl).fontColor(this.theme.inkSoft)
          Text('?').accessibilityText(TG('待求')).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
            .textAlign(TextAlign.Center).width(48).height(Cell.of(48)).backgroundColor(HOT).borderRadius(Radius.xs)
        }.width('100%').alignItems(VerticalAlign.Center)

        Text(TG2("求 C 的第 {0} 行第 {1} 列", String(this.wantR + 1), String(this.wantC + 1)))
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Row({ space: Space.sm }) {
        ForEach(OPT_IDX, (i: number) => { Text(String(this.opts[(i)]))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.picked < 0 ? this.theme.ink
        : ((i) === this.ans ? '#FFFFFF' : ((i) === this.picked ? '#FFFFFF' : this.theme.inkFaint)))
        .layoutWeight(1).height(Cell.of(64)).borderRadius(Radius.md).shadow(Shadow.card)
        .backgroundColor(this.picked < 0 ? this.theme.surface
        : ((i) === this.ans ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surface)))
        .scale({ x: this.press === (i) ? Motion.pressScale : 1, y: this.press === (i) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => { this.press = e.type === TouchType.Down ? (i) : -1; })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((i)); }); })
        .onClick(() => { Haptics.tick(); this.pick((i)); }) }, (i: number) => 'mo' + i)
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

        autoOn: this.autoId >= 0

      })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：C(r,c) = A[r][0]×B[0][c] + A[r][1]×B[1][c]'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



  /** isA=true 画 A（按行高亮），false 画 B（按列高亮） */



}
