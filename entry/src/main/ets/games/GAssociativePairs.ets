/**
 * 联想配对 —— 给出一个词，从四个词里挑出跟它成对的那个
 * 胜负：8 题拿满 600 分以上 ⇒ 通关；进度：题号 / 连对 / 用时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface WordPair { a: string; b: string; }
interface WordChoice { w: string; ok: boolean; }
const PAIRS: WordPair[] = [
  { a: '☀️ 太阳', b: '🌙 月亮' }, { a: '🔑 钥匙', b: '🔒 锁' }, { a: '🖌️ 画笔', b: '🎨 颜料' },
  { a: '🐟 鱼', b: '🌊 水' }, { a: '✉️ 信封', b: '📮 邮筒' }, { a: '🧵 针', b: '🪡 线' },
  { a: '⚡ 闪电', b: '⛈️ 雷声' }, { a: '🌱 种子', b: '🌳 大树' }, { a: '🍚 米饭', b: '🥢 筷子' },
  { a: '🚗 汽车', b: '🛣️ 公路' }, { a: '🕯️ 蜡烛', b: '🔥 火苗' }, { a: '🎻 提琴', b: '🎵 旋律' },
  { a: '☂️ 雨伞', b: '🌧️ 下雨' }, { a: '📚 书', b: '📖 阅读' }, { a: '🐝 蜜蜂', b: '🍯 蜂蜜' },
  { a: '❄️ 雪', b: '⛄ 雪人' }, { a: '🍞 面包', b: '🧈 黄油' }, { a: '🧊 冰', b: '🥤 冷饮' },
  { a: '🎣 鱼钩', b: '🐠 上钩' }, { a: '🪁 风筝', b: '💨 风' }, { a: '⏰ 闹钟', b: '🛏️ 起床' },
  { a: '🖥️ 电脑', b: '⌨️ 键盘' }, { a: '🌋 火山', b: '🪨 岩浆' }, { a: '🏹 弓', b: '🎯 靶心' }
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
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private used: number[] = [];
  @State private stem: WordPair = { a: '☀️ 太阳', b: '🌙 月亮' };
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
    setTimeout(() => { this.demoStart(); }, 3000);
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
    this.timer = setInterval(() => { if (!this.over) { this.clock = this.clock + 1; } }, 1000);
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
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
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
    this.autoId = Hint.autoRun(() => this.autoStep());
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
    Column({ space: Space.md }) {
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) { Column({ space: 2 }) {
      Text((TG('题目'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('连对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.streak), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: 2 }) {
      Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG('与它最相配的是？')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.stem.a).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) { Text(this.opts[(0)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (0) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (0) ? (this.opts[(0)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (0) ? Motion.pressScale : 1, y: this.pick === (0) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((0)); }); Text(this.opts[(1)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (1) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (1) ? (this.opts[(1)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (1) ? Motion.pressScale : 1, y: this.pick === (1) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((1)); }); Text(this.opts[(2)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (2) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (2) ? (this.opts[(2)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (2) ? Motion.pressScale : 1, y: this.pick === (2) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((2)); }); Text(this.opts[(3)].w).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
      .fontColor(this.pick === (3) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
      .width('100%').height(Cell.of(52))
      .backgroundColor(this.pick === (3) ? (this.opts[(3)].ok ? Palette.emerald : Palette.rose) : this.theme.surfaceAlt)
      .borderRadius(Radius.md).shadow(Shadow.card)
      .scale({ x: this.pick === (3) ? Motion.pressScale : 1, y: this.pick === (3) ? Motion.pressScale : 1 })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer((3)); }) }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.fb === 1 ? Palette.rose : (this.fb === 0 ? Palette.emerald : this.theme.inkSoft))
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG2('用时 {0}s · 连对越长分越高',Digits(String(this.clock), this.langCode))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}