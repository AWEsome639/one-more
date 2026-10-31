/**
 * 填字游戏 —— 5×5 迷你填字：按线索从词库里挑词，逐行填满
 * 秘密：前五个词横竖皆成词（词方阵 HEART / EMBER / ABUSE / RESIN / TREND）
 *       困难档要多填两行（STONE / FLAME）⇒ 词库共 7 个词，七行都填得满
 * 胜负：行数全填对通关；挑错 3 次即失败　进度：已填行数 / 失误 / 得分
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
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
const SIZE: number = 5; const MAX_MISS: number = 3;
/**
 * ★ 2026-10-29 修「困难档 7 行填不满」：
 *   行数 = GameDiff.sizeNow(5) = 4 / 5 / 7，但原来答案词只有 5 个 ⇒ 第 6、7 行没有正解
 *   （WORDS[cur] === undefined，点什么都算失误）⇒ 困难档**必输**。
 *   把原来只当干扰项的两个词 STONE / FLAME 提为第 6、7 个答案并补上线索
 *   ⇒ 词库 7 个词，4 / 5 / 7 行全填得满；简单、普通只用前 4 / 5 行，没轮到的词照旧当干扰项。
 *   ⚠️ 填字池 UI 只有 7 个格子 ⇒ 词库不能再多，EXTRA 已并入 WORDS（保留 concat 结构不动）。
 */
const WORDS: string[] = ['HEART', 'EMBER', 'ABUSE', 'RESIN', 'TREND', 'STONE', 'FLAME'];
const CLUES: string[] = [
  '1 行：胸腔里日夜跳动的器官（5 字母）',
  '2 行：炭火里将熄未熄的红光（5 字母）',
  '3 行：错误地、过度地使用权力或药物（5 字母）',
  '4 行：松柏伤口渗出的黏稠物（5 字母）',
  '5 行：风向；潮流所向（5 字母）',
  '6 行：地上坚硬的矿物块（5 字母）',
  '7 行：燃烧时窜起的光（5 字母）'
];
const EXTRA: string[] = [];
/** 列数固定 = 词长 5（★ 原来列数跟着行数走，简单档 4 列会把 5 字母词截成 4 个字母） */
const COLS: number[] = [0, 1, 2, 3, 4];
@Component
export struct GCrossword {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：**行数**（原 SIZE=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3 ⇒ 4 / 5 / 7 行）
  //   列数固定 = 词长 5（COLS）—— 词都是 5 字母，列数跟着行数变只会把词截短
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  /** 行数 = min(难度值, 答案词数)：词库几个词就只能填几行，多出来的行必输 */
  @State private diffTotal: number = Math.min(GameDiff.sizeNow(5), WORDS.length);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State rows: string[] = []; @State bank: string[] = []; @State used: string[] = [];
  @State cur: number = 0; @State miss: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCrossword')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = Math.min(GameDiff.sizeNow(5), WORDS.length);
     this.reset(); }
  private isUsed(i: number): boolean {
    return i < this.bank.length && this.used.indexOf(this.bank[i]) >= 0;
  }
  private reset(): void {
    this.rows = new Array<string>(this.diffTotal).fill(''); this.used = [];
    this.cur = 0; this.miss = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('从词库里挑一个词，填进这一行'); this.startAt = Date.now();
    const arr: string[] = WORDS.concat(EXTRA);
    for (let i = arr.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    this.bank = arr;
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
    if (this.cur >= WORDS.length) {
      return false;
    }
    const i: number = this.bank.indexOf(WORDS[this.cur]);
    if (i < 0) {
      return false;
    }
    this.place(i);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.cur >= WORDS.length) {
      return Hint.none('none');
    }
    const w: string = WORDS[this.cur];
    return Hint.make([],
      TG2('第 {0} 行该填 {1}（线索：{2}）', this.cur + 1, w, CLUES[this.cur]),
      TG2('Row {0} takes {1}', this.cur + 1, w), t0);
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

  private place(i: number): void {
    if (this.over || i >= this.bank.length || this.isUsed(i)) { return; }
    const w: string = this.bank[i];
    if (w !== WORDS[this.cur]) {
      this.miss = this.miss + 1;
      this.msg = TG2('❌ 「{0}」对不上线索，失误 {1} / {2}', w, this.miss, MAX_MISS);
      if (this.miss >= MAX_MISS) { this.end(false); }
      return;
    }
    const next: string[] = this.rows.slice();
    next[this.cur] = w; this.rows = next;
    this.used = this.used.concat([w]);
    this.score = this.score + 100;
    this.cur = this.cur + 1;
    if (this.cur >= this.diffTotal) { this.end(true); return; }
    this.msg = TG2("✅ 第 {0} 行填好了，接着下一行", this.cur);
  }
  private end(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 通关！横竖同词：HEART · EMBER · ABUSE · RESIN · TREND'
      : TG2('💤 失误 {0} 次，这一局结束', MAX_MISS);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'crossword', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.cur };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.cur + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.miss + '/' + MAX_MISS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(COLS, (c: number) => {
              Stack() {
              Text(this.rows[(r)].length > (c) ? this.rows[(r)].charAt((c)) : '')
              .fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
              .fontColor((r) === this.cur && !this.over ? '#FFFFFF' : this.theme.ink)
              }
              .layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
              .backgroundColor((r) === this.cur && !this.over ? Palette.amber : this.theme.surface)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      Text(this.over ? this.msg : CLUES[this.cur]).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
        .width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.ink)
      Text(this.msg).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.xs }) {
        Text((0) < this.bank.length ? this.bank[(0)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((0)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((0)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((0)); }); })
        .onClick(() => { Haptics.tick(); this.place((0)); })
        Text((1) < this.bank.length ? this.bank[(1)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((1)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((1)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((1)); }); })
        .onClick(() => { Haptics.tick(); this.place((1)); })
        Text((2) < this.bank.length ? this.bank[(2)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((2)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((2)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((2)); }); })
        .onClick(() => { Haptics.tick(); this.place((2)); })
        Text((3) < this.bank.length ? this.bank[(3)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((3)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((3)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((3)); }); })
        .onClick(() => { Haptics.tick(); this.place((3)); })
      }
      .width('100%')
      Row({ space: Space.xs }) {
        Text((4) < this.bank.length ? this.bank[(4)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((4)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((4)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((4)); }); })
        .onClick(() => { Haptics.tick(); this.place((4)); })
        Text((5) < this.bank.length ? this.bank[(5)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((5)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((5)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((5)); }); })
        .onClick(() => { Haptics.tick(); this.place((5)); })
        Text((6) < this.bank.length ? this.bank[(6)] : '')
        .fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.isUsed((6)) ? this.theme.inkFaint : '#FFFFFF')
        .layoutWeight(1).height(Cell.of(42)).borderRadius(Radius.sm).shadow(Shadow.card)
        .backgroundColor(this.isUsed((6)) ? this.theme.surfaceAlt : Palette.primary)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.place((6)); }); })
        .onClick(() => { Haptics.tick(); this.place((6)); })
      }
      .width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
