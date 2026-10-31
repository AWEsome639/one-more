/**
 * 运算广度 —— 一组小题按顺序算，算完记住结果，题目全部结束后按原顺序回忆这些结果
 * 胜负：组长度 2 → 3 → 4 全部走通 ⇒ 通关；算错或回忆错顺序 ⇒ 失败
 * 进度：组长度 / 已记住 / 得分
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

const START_SPAN: number = 2;
const MAX_SPAN: number = 4;
const OPT_N: number = 4;
const OPT_IDX: number[] = [0, 1, 2, 3];
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1, 2];

@Component
export struct GOperationSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 START_SPAN=2，按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(2);
  onFinish: (r: GameResult) => void = () => {};
  @State phase: number = 0;        // 0 算式　1 回忆　2 结算
  @State span: number = this.diffTotal; @State pos: number = 0; @State got: number = 0;
  @State lhs: number = 0; @State rhs: number = 0; @State opSym: string = '+'; @State ans: number = 0;
  @State opts: number[] = []; @State stored: number[] = []; @State pool: string[] = [];
  @State score: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GOperationSpan')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(2);
     this.reset(); }

  private shuffleNums(src: number[]): number[] {
    const out: number[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  private shuffleStrs(src: string[]): string[] {
    const out: string[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
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
    if (this.phase === 2) {
      return true;
    }
    this.aiStepOne(0);
    return !this.over;
  }

  /** 提示：这道算式的答案 / 该回忆第几个结果 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 0) {
      return Hint.make([this.ans], TG2('这道算式等于 {0}', String(this.ans)),
        TG2('This one equals {0}', String(this.ans)), t0);
    }
    if (this.phase === 1) {
      const want: number = this.stored[this.got];
      return Hint.make([this.got], TG2('第 {0} 个结果应该是 {1}', String(this.got + 1), String(want)),
        TG2('Result {0} should be {1}', String(this.got + 1), String(want)), t0);
    }
    return Hint.none('none');
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

  private reset(): void {
    this.span = this.diffTotal; this.score = 0; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newSet();
  }

  private newSet(): void {
    this.stored = []; this.pos = 0; this.got = 0; this.pool = []; this.phase = 0;
    this.makeProblem();
    this.msg = TG2('本轮 {0} 个算式：先算对，最后一起回忆结果', this.span);
  }

  /** 出题，且结果不与本组已记住的重复（避免回忆时歧义） */
  private makeProblem(): void {
    let a: number = 0; let b: number = 0; let res: number = 0; let plus: boolean = true; let guard: number = 0;
    while (guard < 80) {
      a = 2 + Math.floor(Math.random() * 8); b = 2 + Math.floor(Math.random() * 8);
      plus = Math.random() < 0.5;
      res = plus ? a + b : Math.abs(a - b);
      if (res > 0 && this.stored.indexOf(res) < 0) { break; }
      guard = guard + 1;
    }
    const cand: number[] = [res + 1, res - 1, res + 2, res - 2, res + 3];
    const opts: number[] = [res];
    for (let i = 0; i < cand.length && opts.length < OPT_N; i++) {
      const v: number = cand[i];
      if (v > 0 && opts.indexOf(v) < 0) { opts.push(v); }
    }
    this.lhs = a; this.rhs = b; this.ans = res; this.opSym = plus ? '+' : '-';
    this.opts = this.shuffleNums(opts);
  }

  private pickOpt(v: number): void {
    if (this.phase !== 0) { return; }
    if (v !== this.ans) {
      this.end(false, '❌ 算错了：' + this.lhs + ' ' + this.opSym + ' ' + this.rhs + ' = ' + this.ans);
      return;
    }
    this.stored = this.stored.concat([this.ans]);
    this.score = this.score + 30; this.pos = this.pos + 1;
    if (this.pos >= this.span) { this.beginRecall(); return; }
    this.makeProblem();
    this.msg = TG2('存下第 {0} 个结果，继续算', this.pos);
  }

  private beginRecall(): void {
    this.phase = 1; this.got = 0;
    const pool: string[] = [];
    for (let i = 0; i < this.stored.length; i++) { pool.push(String(this.stored[i])); }
    let extra: number = 0; let guard: number = 0;
    while (extra < 2 && guard < 80) {
      const decoy: number = 2 + Math.floor(Math.random() * 16);
      if (this.stored.indexOf(decoy) < 0) { pool.push(String(decoy)); extra = extra + 1; }
      guard = guard + 1;
    }
    this.pool = this.shuffleStrs(pool);
    this.msg = TG('算式做完了，按顺序点出这些结果');
  }

  private pickPool(i: number): void {
    if (this.phase !== 1 || this.pool[i] === '✔') { return; }
    const want: number = this.stored[this.got];
    if (this.pool[i] !== String(want)) {
      this.end(false, TG('❌ 第 ') + (this.got + 1) + ' 个结果应该是 ' + want);
      return;
    }
    const next: string[] = this.pool.slice();
    next[i] = '✔'; this.pool = next;
    this.got = this.got + 1; this.score = this.score + 40;
    if (this.got >= this.stored.length) {
      if (this.span >= MAX_SPAN) { this.end(true, TG2('✅ {0} 个结果按顺序全对', MAX_SPAN)); return; }
      this.span = this.span + 1; this.newSet();
      return;
    }
    this.msg = TG2("对，继续点第 {0} 个", (this.got + 1));
  }

  private end(solved: boolean, note: string): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true; this.won = solved; this.phase = 2;
    this.msg = note + (solved ? '　🎉 通关' : '　💤 结束');
    const r: GameResult = { gameId: 'operation_span', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.span };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** AI 用：算式阶段点正确答案；回忆阶段按顺序点已存的结果 */
  private aiStepOne(_d: number): void {
    if (this.phase === 0) {
      this.pickOpt(this.ans);
      return;
    }
    if (this.phase === 1) {
      const want: string = String(this.stored[this.got]);
      for (let i = 0; i < this.pool.length; i++) {
        if (this.pool[i] === want) { this.pickPool(i); return; }
      }
    }
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
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('组长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('已记住'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.stored.length + ' / ' + this.span)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        if (this.phase === 0) {
          Column({ space: Space.xs }) {
            Text(TG('算出来并记住结果')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint); Text(this.lhs + ' ' + this.opSym + ' ' + this.rhs + ' = ?').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
          }

              // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        } else if (this.phase === 1) {
          Column({ space: Space.xs }) {
            Text(TG('按顺序回忆')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
            Text(TG2("第 {0} 个结果是几？", (this.got + 1))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
          }

              // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        } else {
          Text(this.won ? '🎉' : '🏁').fontSize(FontSize.hero)
          // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        }
      }.width('100%').height(130).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      if (this.phase === 0) {
        Row({ space: Space.sm }) {
          ForEach(OPT_IDX, (i: number) => { Button(String(this.opts.length > (i) ? this.opts[(i)] : 0))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(Palette.orange)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 0).onClick(() => { Haptics.tap(); this.pickOpt(this.opts[(i)]); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickOpt(this.opts[(i)]); }); }) }, (i: number) => 'os' + i)
        }.width('100%')
      } else if (this.phase === 1) {
        Column({ space: Space.sm }) {
          ForEach(ROWS, (row: number) => {
            Row({ space: Space.sm }) {
              ForEach(COLS, (col: number) => {
                if (row * 3 + col < this.pool.length) { Button(this.pool[(row * 3 + col)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(this.pool[(row * 3 + col)] === '✔' ? Palette.lime : Palette.teal)
                .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(this.pool[(row * 3 + col)] !== '✔').onClick(() => { Haptics.tap(); this.pickPool((row * 3 + col)); })
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pickPool((row * 3 + col)); }); }) }
              }, (col: number) => 'pc' + row + '_' + col)
            }.width('100%')
          }, (row: number) => 'pr' + row)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('提示：算对不算完 —— 题目全部结束后还要按顺序回忆结果')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
