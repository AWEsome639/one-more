/** 混合词拆分 —— 合成词由哪两个词拼成？（6 题答对 ≥4 通关 ｜ 进度：题号/答对/倒计时） */
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

const QN: number = 6; const PASS: number = 4; const FEED_MS: number = 1000;
const LIMIT_MS: number = 10000; const TICK_MS: number = 100;
interface Blend { word: string; def: string; a: string; b: string; d1: string; d2: string }
interface BlendRound { word: string; def: string; a: string; b: string; opts: string[] }
const BANK: Blend[] = [
  { word: 'SMOG', def: '烟雾', a: 'SMOKE', b: 'FOG', d1: 'SMOOTH', d2: 'FROST' },
  { word: 'BRUNCH', def: '早午餐', a: 'BREAKFAST', b: 'LUNCH', d1: 'DINNER', d2: 'BUNCH' },
  { word: 'MOTEL', def: '汽车旅馆', a: 'MOTOR', b: 'HOTEL', d1: 'MOTIVE', d2: 'HOSTEL' },
  { word: 'SPORK', def: '叉勺', a: 'SPOON', b: 'FORK', d1: 'SPORT', d2: 'CORK' },
  { word: 'BLOG', def: '博客', a: 'WEB', b: 'LOG', d1: 'GLOBE', d2: 'BOG' },
  { word: 'CHORTLE', def: '咯咯笑', a: 'CHUCKLE', b: 'SNORT', d1: 'CHORUS', d2: 'TURTLE' },
  { word: 'EMOTICON', def: '颜文字', a: 'EMOTION', b: 'ICON', d1: 'EMOTIVE', d2: 'TONIC' },
  { word: 'PIXEL', def: '像素', a: 'PICTURE', b: 'ELEMENT', d1: 'PIXIE', d2: 'EXCEL' },
  { word: 'CYBORG', def: '半机械人', a: 'CYBERNETIC', b: 'ORGANISM', d1: 'CYPRESS', d2: 'ORGAN' }
];
function shuffled(arr: string[]): string[] {
  const out: string[] = arr.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const tmp: string = out[i]; out[i] = out[j]; out[j] = tmp;
  }
  return out;
}
function makeRound(): BlendRound {
  const pick: Blend = BANK[Math.floor(Math.random() * BANK.length)];
  return { word: pick.word, def: pick.def, a: pick.a, b: pick.b,
    opts: shuffled([pick.a, pick.b, pick.d1, pick.d2]) };
}

@Component
export struct GPortmanteauSplit {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT_MS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT_MS);
  onFinish: (r: GameResult) => void = () => {};
  @State q: BlendRound = makeRound(); @State sel: number[] = []; @State qIndex: number = 0;
  @State right: number = 0; @State score: number = 0; @State leftMs: number = this.diffTotal;
  @State msg: string = ''; @State over: boolean = false; @State won: boolean = false;
  @State pressed: number = -1;
  private startAt: number = 0; private roundAt: number = 0; private timer: number = -1;
  private feed: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPortmanteauSplit')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT_MS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
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
    if (this.feed >= 0) {
      return true;
    }
    this.aiPick(0);
    return !this.over;
  }

  /** 提示：由哪两个词拼成 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('{0} = {1} + {2}', this.q.word, this.q.a, this.q.b),
      TG2('{0} = {1} + {2}', this.q.word, this.q.a, this.q.b), t0);
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
    this.stop();
    this.qIndex = 0; this.right = 0; this.score = 0; this.over = false; this.won = false;
    this.done = false; this.pressed = -1; this.nextQ(); this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private nextQ(): void {
    this.q = makeRound(); this.sel = []; this.leftMs = this.diffTotal; this.roundAt = Date.now();
    this.msg = TG('选出拼成它的两个词');
  }
  private tick(): void {
    if (this.over || this.feed >= 0) { return; } const gap: number = Date.now() - this.roundAt;
    this.leftMs = gap >= this.diffTotal ? 0 : this.diffTotal - gap;
    if (gap >= this.diffTotal) { this.msg = TG2('⌛ 超时：{0} + {1}', this.q.a, this.q.b); this.advance(); }
  }
  private tap(i: number): void {
    if (this.over || this.feed >= 0) { return; }
    const at: number = this.sel.indexOf(i);
    if (at >= 0) { this.sel = this.sel.slice(0, at).concat(this.sel.slice(at + 1)); return; }
    if (this.sel.length >= 2) { return; }
    const next: number[] = this.sel.concat([i]);
    this.sel = next;
    if (next.length === 2) { this.check(); }
  }
  private check(): void {
    const picked: string[] = [];
    for (let i = 0; i < this.sel.length; i++) { picked.push(this.q.opts[this.sel[i]]); }
    if (picked.indexOf(this.q.a) >= 0 && picked.indexOf(this.q.b) >= 0) {
      const gain: number = 120 + Math.floor(this.leftMs / 35);
      this.right = this.right + 1; this.score = this.score + gain;
      this.msg = '✅ ' + this.q.word + ' = ' + this.q.a + ' + ' + this.q.b + '　+' + String(gain);
      this.advance();
      return;
    }
    this.msg = TG2('❌ 这两个合不出 {0}，再想想', this.q.word); this.sel = [];
  }
  private advance(): void {
    this.qIndex = this.qIndex + 1; if (this.qIndex >= QN) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0}/{1}", String(this.right), String(QN));
      this.finish(this.won);
      return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.nextQ(); }, FEED_MS);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; } this.done = true;
    const r: GameResult = { gameId: 'portmanteau_split', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  /** AI 用：把拼成这个词的两个词各点一下 */
  private aiPick(_d: number): void {
    for (let k = 0; k < 2; k++) {
      const w: string = k === 0 ? this.q.a : this.q.b;
      for (let i = 0; i < this.q.opts.length; i++) {
        if (this.q.opts[i] === w && this.sel.indexOf(i) < 0) {
          this.tap(i);
          return;
        }
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qIndex + 1, QN) + '/' + QN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.leftMs / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(this.q.word).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.orange)
        Text(this.q.def).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
        Text(TG2('已选 {0}/2', String(this.sel.length))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.sm }) {
        Text(this.q.opts.length > (0) ? this.q.opts[(0)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((0)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((0)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (0) ? Motion.pressScale : 1, y: this.pressed === (0) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (0); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { Haptics.tick(); this.tap((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((0)); }); })
        Text(this.q.opts.length > (1) ? this.q.opts[(1)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((1)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((1)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (1) ? Motion.pressScale : 1, y: this.pressed === (1) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (1); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { Haptics.tick(); this.tap((1)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((1)); }); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Text(this.q.opts.length > (2) ? this.q.opts[(2)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((2)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((2)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (2) ? Motion.pressScale : 1, y: this.pressed === (2) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (2); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { Haptics.tick(); this.tap((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((2)); }); })
        Text(this.q.opts.length > (3) ? this.q.opts[(3)] : '')
        .fontSize(FontSize.sm).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel.indexOf((3)) >= 0 ? '#FFFFFF' : this.theme.ink).layoutWeight(1).height(Cell.of(58))
        .backgroundColor(this.sel.indexOf((3)) >= 0 ? Palette.orange : this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pressed === (3) ? Motion.pressScale : 1, y: this.pressed === (3) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.pressed = (3); } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.pressed = -1; }
        })
        .onClick(() => { Haptics.tick(); this.tap((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((3)); }); })
      }.width('100%')
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
