/** 首音互换 —— 挑出「互换首音」后得到的那一对词（Spoonerism）｜胜负：6 题答对 ≥4 通关 */
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

const ROUNDS: number = 6; const PASS: number = 4; const GAP_MS: number = 800;

interface SP { a: string; b: string; ok: string; bad: string[] }

const ITEMS: SP[] = [
  { a: 'LIGHT', b: 'RAIN', ok: 'RIGHT LAIN', bad: ['RAIN LIGHT', 'LIGHT LAIN', 'LAIN RIGHT'] },
  { a: 'SAD', b: 'BALLADS', ok: 'BAD SALADS', bad: ['BALLADS SAD', 'SAD SALADS', 'SALADS BAD'] },
  { a: 'TRAIL', b: 'SNACKS', ok: 'SNAIL TRACKS', bad: ['SNACKS TRAIL', 'TRAIL TRACKS', 'TRACKS SNAIL'] },
  { a: 'KEYS', b: 'PARROTS', ok: 'PEAS CARROTS', bad: ['PARROTS KEYS', 'KEYS CARROTS', 'CARROTS PEAS'] },
  { a: 'BUNNY', b: 'RABBIT', ok: 'RUNNY BABBIT', bad: ['RABBIT BUNNY', 'BUNNY BABBIT', 'BABBIT RUNNY'] },
  { a: 'CHIP', b: 'SHOP', ok: 'SHIP CHOP', bad: ['SHOP CHIP', 'CHIP CHOP', 'CHOP SHIP'] }
];

function shufStr(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

function shufNums(src: number[]): number[] {
  const out: number[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSpoonerismSolver {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State plan: number[] = []; @State opts: string[] = []; @State ans: number = 0;
  @State picked: number = -1; @State qi: number = 0; @State right: number = 0;
  @State score: number = 0; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSpoonerismSolver')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }
  private cur(): SP { return ITEMS[this.plan[this.qi]]; }

  private reset(): void {
    this.stop();
    const order: number[] = [];
    for (let i = 0; i < ITEMS.length; i++) { order.push(i); }
    this.plan = shufNums(order);
    this.qi = 0; this.right = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.next();
  }

  private next(): void {
    const it: SP = this.cur();
    const four: string[] = shufStr([it.ok, it.bad[0], it.bad[1], it.bad[2]]);
    this.opts = four; this.ans = four.indexOf(it.ok); this.picked = -1;
    this.msg = TG2('把「{0} · {1}」的首音对调，得到？', it.a, it.b);
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
    if (this.over || this.picked >= 0) { return; }
    const it: SP = this.cur();
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1; this.score = this.score + 100; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ ' + it.a + ' ' + it.b + ' → ' + it.ok;
    } else { this.msg = TG2('❌ 正解是 {0} {1} → {2}', it.a, it.b, it.ok); }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'spoonerism_solver', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 原词')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.cur().a + ' · ' + this.cur().b)
          .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.violet)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.violet
        : ((0) === this.ans ? Palette.emerald : ((0) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((0)); }); })
        Button(this.opts.length > (1) ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.violet
        : ((1) === this.ans ? Palette.emerald : ((1) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((1)); }); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.opts.length > (2) ? this.opts[(2)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.violet
        : ((2) === this.ans ? Palette.emerald : ((2) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((2)); }); })
        Button(this.opts.length > (3) ? this.opts[(3)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.violet
        : ((3) === this.ans ? Palette.emerald : ((3) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((3)); }); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG2("{0} 题，答对 ≥{1} 通关：首音对调后仍是真词",Digits(String(this.diffTotal), this.langCode), PASS))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
