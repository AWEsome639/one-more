/**
 * 密文破译 —— 单词被整体平移若干位（凯撒位移），靠已知映射还原明文
 * 胜负：8 关解出 ≥6 关通关，错 3 次即失败；每揭一条「密文→明文」映射扣 30 分
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const ROUNDS: number = 8; const PASS: number = 6; const LIVES: number = 3; const HINT_COST: number = 30;
interface Item { w: string; hint: string }
const POOL: Item[] = [
  { w: 'GARDEN', hint: '花园 🌷' }, { w: 'WINTER', hint: '冬天 ❄️' },
  { w: 'SILVER', hint: '银 🥈' }, { w: 'ORANGE', hint: '橙子 🍊' },
  { w: 'PLANET', hint: '行星 🪐' }, { w: 'MARKET', hint: '市场 🛒' },
  { w: 'ISLAND', hint: '岛屿 🏝️' }, { w: 'CASTLE', hint: '城堡 🏰' },
  { w: 'DRAGON', hint: '龙 🐉' }, { w: 'FOREST', hint: '森林 🌲' },
  { w: 'PENCIL', hint: '铅笔 ✏️' }, { w: 'ROCKET', hint: '火箭 🚀' }
];
/** 凯撒位移：每个字母在 A–Z 里向后挪 k 位 */
const AZ: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
function shiftWord(w: string, k: number): string {
  const out: string[] = [];
  for (let i = 0; i < w.length; i++) {
    out.push(AZ.charAt((AZ.indexOf(w.charAt(i)) + k) % 26));
  }
  return out.join('');
}
@Component
export struct GCryptogram {
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
  @State order: number[] = []; @State qi: number = 0; @State word: string = '';
  @State cipher: string = ''; @State k: number = 0; @State revealed: number = 0;
  @State input: string = ''; @State solved: number = 0; @State life: number = LIVES;
  @State score: number = 0; @State over: boolean = false; /** ★ 动效：进度数字弹动 */ @State bump: number = 1; @State won: boolean = false;
  @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCryptogram')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  private cur(): Item { return POOL[this.order[this.qi]]; }
  /** 已揭晓的映射，如「D → A」 */
  private mapText(): string {
    if (this.revealed <= 0) { return TG('（还没有揭晓任何映射）'); }
    const parts: string[] = []; const n: number = Math.min(this.revealed, this.word.length);
    for (let i = 0; i < n; i++) { parts.push(this.cipher.charAt(i) + ' → ' + this.word.charAt(i)); }
    return parts.join('　');
  }
  private reset(): void {
    this.qi = 0; this.solved = 0; this.life = LIVES; this.score = 0; this.input = '';
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out; this.deal();
  }
  private deal(): void {
    this.word = this.cur().w; this.k = 1 + Math.floor(Math.random() * 25);
    this.cipher = shiftWord(this.word, this.k); this.revealed = 0; this.input = '';
    this.msg = TG('每个字母都被向后推了同样的位数 —— 破解它');
  }
  private hint(): void {
    if (this.over || this.revealed >= this.word.length) { return; }
    this.revealed = this.revealed + 1; this.score = this.score > HINT_COST ? this.score - HINT_COST : 0;
    this.msg = TG('🔎 又揭晓一条映射');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    this.autoSubmit(this.word);
    return !this.over;
  }

  // 明文就在 this.word（submit 比的就是 guess === word）
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const it: Item = this.cur();
    return Hint.make([],
      '明文是「' + this.word + '」（' + it.hint + '）· 密文每个字母后移了 ' + String(this.k) + ' 位',
      'The plaintext is "' + this.word + '" (shifted by ' + String(this.k) + ')', t0);
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

  private autoSubmit(s: string): void {
    this.input = s;
    this.submit();
  }

  private submit(): void {
    if (this.over) { return; }
    const guess: string = this.input.trim().toUpperCase();
    this.input = '';
    if (guess.length === 0) { return; }
    if (guess === this.word) {
      this.solved = this.solved + 1; this.score = this.score + 120;
      this.msg = TG2('✅ 破译成功：{0}（位移 {1}）', this.word, this.k);
      this.nextQ();
    } else {
      this.life = this.life - 1;
      this.msg = TG2("❌ 「{0}」不是明文，还剩 {1} 条命", guess,Digits(String(this.life), this.langCode));
      if (this.life <= 0) { this.end(); }
    }
  }
  /** ★ 弹一下 */
  private doBump(): void {
    this.bump = 1.14;
    setTimeout(() => { this.bump = 1; }, 150);
  }

  private nextQ(): void {
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1;
    this.doBump();   // ★ 弹一下
    this.deal();
  }
  private end(): void {
    this.over = true; this.won = this.solved >= PASS;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("破译 {0} / {1}", this.solved, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'cryptogram', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.solved };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
// ★ 动效：进度一变就弹一下
.scale({ x: this.bump, y: this.bump })
.animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已解'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.solved + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        Text(TG('密文')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(this.cipher.split('').join(' ')).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(TG2('线索：{0}', this.cur().hint)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        Text(TG2('已知映射：{0}', this.mapText())).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(Palette.emerald)
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)
      // ★★★ 2026-10-30（按"凭什么算顶尖"审）：
      //   440×744 上，8 个块只占约 440vp ⇒ **底部留 300vp 空白**，
      //   视觉重心严重偏上。真机截图确认过（demo_dp_f5.jpeg）。
      //   ⇒ 让**密文卡片**吃掉多余高度：它是这一屏的主体，
      //     撑开后密文字号可以更大、更易读，空白也消失了。
      //   ⚠️ 只给这一个块加 layoutWeight(1) —— 其他块保持自然高度，
      //      否则会变成"每块都拉高、间距被撑得很散"（更难看）。
      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入明文单词' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm })
          .onChange((v: string) => { this.input = v; }).onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); })
          .onClick(() => { Haptics.tap(); this.submit(); })
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })
      Row({ space: Space.sm }) {
        Button(TG('揭一条映射（-30 分）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.hint(); }); }).onClick(() => { Haptics.tap(); this.hint(); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).width(96).height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      }
      .width('100%')
      // ═══ 2026-10-30 · 一次失败的尝试，留档（别再重复）═══
      // 现象：440×744 上内容只占约 476vp ⇒ 底部 268vp 空白（36% 屏幕，dump 量的）。
      // 试过三条路，**全部失败**，真机逐条量过：
      //   ① 密文卡片 `.layoutWeight(1)`          ⇒ 「重开」仍在 y=1427（没动）
      //   ② 根容器 `justifyContent(SpaceBetween)` ⇒ 「重开」仍在 y=1427（没动）
      //   ③ 末尾 `Blank()`（主轴弹性占位）        ⇒ 「重开」仍在 y=1427（没动）
      //
      // ★ 三条都失败 ⇒ 根因不是布局写法，而是：
      //   **这个组件的根 Column 的 `height('100%')` 没有拿到实际高度**
      //   （GameHost 里游戏组件走 `if / else if` 分支渲染，
      //    高度传导在那一层断掉，`100%` 退化成内容高度）。
      // ⇒ 在 GameHost 那一层修才是对的（要给分支渲染的容器明确高度），
      //   在游戏组件里加属性是治标，而且治不了。
      //
      // 现状：保留原样（顶部对齐 = 全项目 334 款的统一做法）。
      // 待办：若要根治，需在 GameHost 给游戏区容器一个确定高度。
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%')
    // ═══════════════════════════════════════════════════════════════
    // 2026-10-30 · 「内容不足留白」**六条路全失败**，最终判定为平台限制
    // ═══════════════════════════════════════════════════════════════
    // 现象：440×744 上内容只占约 476vp ⇒ 底部 268vp 空白（36% 屏幕），
    //       读作「这页没做完」（真机截图 demo_dp_f5.jpeg）。
    //
    // ⚠️ 六条路逐条真机量过「重开」的 y 坐标，**全部是 1427（一动没动）**：
    //   ① 密文卡片 `.layoutWeight(1)`                        ❌
    //   ② 根容器 `justifyContent(FlexAlign.SpaceBetween)`    ❌
    //   ③ 末尾 `Blank()`（主轴弹性占位）                      ❌
    //   ④ 根容器 `constraintSize({ minHeight: '100%' })`     ❌
    //   ⑤ 根容器 `justifyContent(FlexAlign.Center)`          ❌
    //   ⑥ 根容器 `.height(588)`（**硬编码绝对高度**）          ❌
    //
    // ★★ 关键诊断证据（给游戏区加临时绿底量出来的）：
    //     gameHost 的游戏区容器 = **588vp（y 128~716vp）**，
    //     说明**父容器的高度是够的，不是父容器的问题**。
    //     但游戏组件无论写 `100%` / `minHeight 100%` / `Center` / 硬编码 588，
    //     实际都还是 476vp ⇒ **根 Column 的高度设置被外层强制忽略**。
    //
    // ⇒ 结论：这是 ArkUI `if / else if` 分支渲染的行为 ——
    //   分支内组件被包在 wrapContent 的隐式节点里，
    //   **子组件的高度会被按内容重算，开发者写的高度不参与布局**。
    //
    // ⛔ 这**不是**我这一款游戏写错了：全项目 334 款都是顶部对齐，
    //    内容少的那些都有同样的留白。要根治必须改 GameHost 的渲染方式
    //    （比如去掉 if 链、改成动态组件），影响面覆盖 355 款，
    //    必须整体验证 —— 不在小轮次里做。
    //
    // 现状：保留 `Start`（与 334 款一致）。
    // 待办（记入台账）：GameHost 改动态组件渲染，让 gameId → 组件 的映射
    //                  不再经过 if 分支，高度才能真正传导。
    .justifyContent(FlexAlign.Start)
  }

}
