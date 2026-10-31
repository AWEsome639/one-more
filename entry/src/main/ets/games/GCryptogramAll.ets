/**
 * 密文进阶 🔐 —— 凯撒移位密文，给出部分密钥（key），推出原词
 * 每个字母被移位 +k 加密；密钥只露出几位，其余靠四个候选词反推
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const TOTAL: number = 8;
const PASS: number = 6;
const NEXT_MS: number = 780;
const AZ: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const WORDS: string[] = [
  'CIPHER', 'PUZZLE', 'SHADOW', 'GALAXY', 'MARBLE',
  'FOSSIL', 'ORCHID', 'VELVET', 'BEACON', 'THRIVE'
];
const REVEAL: string[] = ['012', '123', '234', '045', '135', '246', '056', '147'];

@Component
export struct GCryptogramAll {
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

  @State private word: string = '';
  @State private cipher: string = '';
  @State private shown: string = '';
  @State private opts: string[] = [];
  @State private qi: number = 0;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-14 动效：进度数字弹动 */
  @State private bump: number = 1;
  @State private over: boolean = false;
  @State private hint: string = '';
  private startAt: number = 0;
  private locked: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCryptogramAll')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }

  private reset(): void {
    this.right = 0; this.score = 0; this.qi = 0; this.over = false; this.hint = '';
    this.load(0); this.startAt = Date.now();
  }

  /** 生成本题：原词 + 随机移位 + 只露几位密钥 */
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private load(i: number): void {
    this.doBump();   // ★ 换题弹一下
    const word: string = WORDS[i % WORDS.length];
    const shift: number = 3 + (i % 7);
    let cipher: string = '';
    for (let k = 0; k < word.length; k++) {
      const p: number = AZ.indexOf(word.charAt(k));
      cipher += p < 0 ? word.charAt(k) : AZ.charAt((p + shift) % 26);
    }
    const reveal: string = REVEAL[i % REVEAL.length];
    let shown: string = '';
    for (let k = 0; k < reveal.length; k++) {
      const at: number = Number.parseInt(reveal.charAt(k));
      if (at < word.length && shown.indexOf(cipher.charAt(at)) < 0) {
        shown += (shown.length > 0 ? '  ' : '') + cipher.charAt(at) + '→' + word.charAt(at);
      }
    }
    const pool: string[] = ['BAFFLE', 'MEADOW', 'SPIRAL', 'THRONE', 'ZEPHYR', 'QUARTZ'];
    const opts: string[] = [word];
    for (let k = 0; k < pool.length && opts.length < 4; k++) {
      if (pool[k] !== word) { opts.push(pool[k]); }
    }
    for (let k = opts.length - 1; k > 0; k--) {   // 洗牌，正确项不固定在最后一格
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: string = opts[k]; opts[k] = opts[j]; opts[j] = t;
    }
    this.word = word; this.cipher = cipher; this.shown = shown; this.opts = opts;
    this.qi = i; this.locked = false; this.hint = '';
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
    if (this.locked) {
      return true;
    }
    this.pick(this.word);
    return !this.over;
  }

  /** 提示：原词是什么 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.locked || this.over) {
      return Hint.none('none');
    }
    const w: string = this.word;
    if (w.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('原词是「{0}」', w),
      TG2('The word is {0}', w), t0);
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

  private pick(v: string): void {
    if (this.locked || this.over) { return; }
    this.locked = true;
    const plain: string = this.word;
    if (v === plain) { this.right++; this.score += 130; this.hint = TG(TG(TG('破译成功 ✅'))); }
    else { this.hint = TG2('原词是 {0} ❌', plain); }
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true;
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'cryptogram_all', solved: this.right >= PASS,
        score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.right
      });
      return;
    }
    this.timer = setTimeout(() => { this.load(this.qi + 1); }, NEXT_MS);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) { clearTimeout(this.timer); }
  }





  build() {
    Column({ space: Space.sm }) {
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
      Row({ space: Space.md }) {
        Text(TG2("第 {0}/{1}", (this.qi + 1), this.diffTotal)).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        Text(TG('答对 ') + this.right).fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
        Text(TG('得分 ') + this.score).fontSize(FontSize.md).fontColor(this.theme.inkSoft).layoutWeight(1)
      }.width('100%')

      Text(TG('🔐 每个字母都被移位加密了；密钥只露出一部分，推出原词'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.cipher.split(''), (ch: string, i: number) => {
          Stack() {
          Text((ch)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .layoutWeight(1).height(Cell.of(46)).backgroundColor(Palette.violet).borderRadius(Radius.sm)
        }, (ch: string, i: number) => 'cc' + i)
      }.width('100%')

      Text(TG2('🔑 已知：{0}', this.shown))
        .fontSize(FontSize.sm).fontColor(Palette.violet).width('100%').textAlign(TextAlign.Center)

      Text(this.hint.length > 0 ? this.hint : '提示：同一位移的凯撒密码，密钥里的字母差就是位移量')
        .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Button((this.opts.length > 0 ? this.opts[0] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[0] : '')); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[0] : '')); })
        Button((this.opts.length > 0 ? this.opts[1] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[1] : '')); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[1] : '')); })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button((this.opts.length > 0 ? this.opts[2] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[2] : '')); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[2] : '')); })
        Button((this.opts.length > 0 ? this.opts[3] : ''))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .layoutWeight(1).height(Cell.of(48)).fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[3] : '')); }); })
        .onClick(() => { Haptics.tap(); this.pick((this.opts.length > 0 ? this.opts[3] : '')); })
      }.width('100%')

      Button(this.over ? (this.right >= PASS ? TG('通关 🎉') : TG('结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .height(Cell.of(44)).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%')
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
