/**
 * 联想配对 —— 给出一个词，从四个词里挑出跟它成对的那个
 * 胜负：8 题拿满 600 分以上 ⇒ 通关；进度：题号 / 连对 / 用时
 */
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
import { AppClock } from '../core/AppClock';

interface WordPair { a: string; b: string; }
interface WordChoice { w: string; ok: boolean; }
const PAIRS: WordPair[] = [
  { a: TG('☀️ 太阳'), b: TG('🌙 月亮') }, { a: '🔑 钥匙', b: '🔒 锁' }, { a: '🖌️ 画笔', b: '🎨 颜料' },
  { a: TG('🐟 鱼'), b: TG('🌊 水') }, { a: TG('✉️ 信封'), b: TG('📮 邮筒') }, { a: TG('🧵 针'), b: TG('🪡 线') },
  { a: TG('⚡ 闪电'), b: TG('⛈️ 雷声') }, { a: TG('🌱 种子'), b: TG('🌳 大树') }, { a: TG('🍚 米饭'), b: TG('🥢 筷子') },
  { a: TG('🚗 汽车'), b: TG('🛣️ 公路') }, { a: TG('🕯️ 蜡烛'), b: TG('🔥 火苗') }, { a: TG('🎻 提琴'), b: TG('🎵 旋律') },
  { a: TG('☂️ 雨伞'), b: TG('🌧️ 下雨') }, { a: TG('📚 书'), b: TG('📖 阅读') }, { a: TG('🐝 蜜蜂'), b: TG('🍯 蜂蜜') },
  { a: TG('❄️ 雪'), b: TG('⛄ 雪人') }, { a: TG('🍞 面包'), b: TG('🧈 黄油') }, { a: TG('🧊 冰'), b: TG('🥤 冷饮') },
  { a: TG('🎣 鱼钩'), b: TG('🐠 上钩') }, { a: TG('🪁 风筝'), b: TG('💨 风') }, { a: TG('⏰ 闹钟'), b: TG('🛏️ 起床') },
  { a: TG('🖥️ 电脑'), b: TG('⌨️ 键盘') }, { a: TG('🌋 火山'), b: TG('🪨 岩浆') }, { a: TG('🏹 弓'), b: TG('🎯 靶心') }
];
const ROUNDS: number = 8;
const NEED: number = 600;

@Component
export struct GAssociativePairs {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
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
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private used: number[] = [];
  @State private stem: WordPair = { a: TG('☀️ 太阳'), b: TG('🌙 月亮') };
  @State private opts: WordChoice[] = [];
  @State private round: number = 1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private streak: number = 0;
  @State private pick: number = -1;
  @State private fb: number = -1;
  @State private msg: string = '';
  @State private clock: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private timer: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAssociativePairs')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearAll();
    this.used = []; this.round = 1; this.score = 0; this.streak = 0; this.pick = -1; this.fb = -1;
    this.over = false; this.won = false; this.done = false; this.clock = 0;
    this.msg = TG('看上面的词，选它最自然的搭档');
    this.startAt = Date.now();
    this.nextRound();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (!this.over) { this.clock = this.clock + 1; }
    }, 1000);
  }
  /** 取一个没用过的词对，再配 3 个干扰项 */
  private nextRound(): void {
    let pi: number = Math.floor(Math.random() * PAIRS.length);
    let guard: number = 0;
    while (this.used.indexOf(pi) >= 0 && guard < 40) {
      pi = Math.floor(Math.random() * PAIRS.length);
      guard = guard + 1;
    }
    const kept: number[] = this.used.slice();
    kept.push(pi);
    this.used = kept;
    this.stem = PAIRS[pi];
    const pool: WordChoice[] = [{ w: PAIRS[pi].b, ok: true }];
    while (pool.length < 4) {
      const di: number = Math.floor(Math.random() * PAIRS.length);
      if (di === pi) { continue; }
      let dup: boolean = false;
      for (let i = 0; i < pool.length; i++) { if (pool[i].w === PAIRS[di].b) { dup = true; } }
      if (!dup) { pool.push({ w: PAIRS[di].b, ok: false }); }
    }
    const mixed: WordChoice[] = [];
    while (pool.length > 0) { mixed.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]); }
    this.opts = mixed;
    this.pick = -1;
    this.fb = -1;
  }
  /** 提示：哪个选项是对的（代打就是找 opts[i].ok） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
        return Hint.make([i],
          TG2('选「{0}」', this.opts[i].w),
          TG2('Pick "{0}"', this.opts[i].w), t0);
      }
    }
    // ★ 找不到 ok ⇒ 不是"算不出"，是"还没出题"：明确告诉玩家等一等
    return Hint.make([],
      TG('还没出题，等一下再点'),
      TG('Not dealt yet — try again in a moment'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 选项对象自带对错：opts[i].ok ｜ 守卫取自它自己的第一道 if
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
    if (this.over || this.pick >= 0) {
      return true;
    }
    for (let i = 0; i < this.opts.length; i++) {
      if (this.opts[i].ok) {
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private answer(i: number): void {
    if (this.over || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i].ok) {
      this.streak = this.streak + 1;
      this.score += 100 + this.streak * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.fb = 0;
      this.msg = TG('✅ 配对成功！');
    } else {
      this.streak = 0;
      this.fb = 1;
      this.msg = TG2("❌ 应该是 {0}", this.stem.b);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.over = true;
        this.won = this.score >= NEED;
        this.msg = TG2(this.won ? '🎉 通关！总分 {0}' : '💤 本局结束，总分 {0}',Digits(String(this.score), this.langCode));
        this.clearAll();
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.nextRound();
    }, 660);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = {
      gameId: 'associative_pairs', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.xxs }) {
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
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('题目'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('连对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs); Text(Digits(String(this.streak), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis }); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('与它最相配的是？')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(2).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.stem.a).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) { Text(this.opts[(0)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (0) ? (this.opts[(0)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L336'; })
      .onBlur(() => { if (this.tvFocus === 'L336') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L336'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((0)); }); })
      .onClick(() => { Haptics.tick(); this.answer((0)); }); Text(this.opts[(1)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (1) ? (this.opts[(1)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L346'; })
      .onBlur(() => { if (this.tvFocus === 'L346') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L346'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((1)); }); })
      .onClick(() => { Haptics.tick(); this.answer((1)); }); Text(this.opts[(2)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (2) ? (this.opts[(2)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L356'; })
      .onBlur(() => { if (this.tvFocus === 'L356') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L356'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((2)); }); })
      .onClick(() => { Haptics.tick(); this.answer((2)); }); Text(this.opts[(3)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (3) ? (this.opts[(3)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L366'; })
      .onBlur(() => { if (this.tvFocus === 'L366') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L366'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((3)); }); })
      .onClick(() => { Haptics.tick(); this.answer((3)); }) }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.fb === 1 ? Palette.rose : (this.fb === 0 ? Palette.emerald : this.theme.inkSoft))
        .width('100%').textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Button(this.over ? TG('再来一局') : TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on())
        .onFocus(() => { this.tvFocus = 'L375'; })
        .onBlur(() => { if (this.tvFocus === 'L375') { this.tvFocus = ''; } })
        .outline(Tv.focusOutline(this.tvFocus === 'L375')).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('用时 {0}s · 连对越长分越高',Digits(String(this.clock), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}