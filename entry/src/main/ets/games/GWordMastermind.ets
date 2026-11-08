/**
 * 猜词大师 —— 猜隐藏的 5 字母单词，逐格给出「位置对 / 字母在 / 都没有」
 * 胜负：7 次内猜中通关｜次数用完未猜中失败｜进度：第几次 / 剩余机会 / 得分
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
const LEN: number = 5; const TRIES: number = 7; const KEYS: number = 28;
const LETTERS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const BANK: string[] = [
  'APPLE', 'BEACH', 'BRAIN', 'BREAD', 'BRICK', 'CHAIR', 'CHESS', 'CLOUD', 'DANCE', 'DREAM',
  'DRINK', 'EARTH', 'FIELD', 'FLAME', 'FRUIT', 'GHOST', 'GRAPE', 'GREEN', 'HAPPY', 'HEART',
  'HONEY', 'HOUSE', 'JUICE', 'KNIFE', 'LEMON', 'LIGHT', 'MONEY', 'MOUSE', 'MUSIC', 'NIGHT',
  'OCEAN', 'PAPER', 'PEACH', 'PIANO', 'PLANT', 'PLATE', 'QUEEN', 'RIVER', 'ROBOT', 'SHEEP',
  'SHIRT', 'SMILE', 'SNAKE', 'SPACE', 'SPOON', 'STONE', 'STORM', 'SUGAR', 'TABLE', 'TIGER',
  'TOAST', 'TRAIN', 'WATER', 'WHALE', 'WHEEL', 'WORLD', 'YOUTH', 'ZEBRA'
];
@Component
export struct GWordMastermind {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 LEN=5
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
  @State private diffTotal: number = GameDiff.sizeNow(5);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};
  @State answer: string = ''; @State rows: string[] = []; @State marks: string[] = [];
  @State typed: string = ''; @State score: number = 0; @State msg: string = '';
  /** ★ 2026-11-08（ai-fixer-a）代打当前这一猜的词（每轮重算；空 = 未算） */
  private autoGuess: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private settled: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordMastermind')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
     this.reset(); }
  private reset(): void {
    this.answer = BANK[Math.floor(Math.random() * BANK.length)];
    this.rows = []; this.marks = []; this.typed = ''; this.score = 0;
    this.over = false; this.won = false; this.settled = false; this.startAt = Date.now();
    this.msg = TG2('凑满 {0} 个字母后按 ⏎ 提交', this.diffTotal);
  }
  /** 逐格标记：2 = 位置对，1 = 字母在但位置错，0 = 词里没有 */
  private mark(g: string): string {
    const res: string[] = new Array<string>(this.diffTotal).fill('0');
    const left: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      if (g.charAt(i) === this.answer.charAt(i)) { res[i] = '2'; }
      else { left.push(this.answer.charAt(i)); }
    }
    for (let i = 0; i < this.diffTotal; i++) {
      if (res[i] === '2') { continue; }
      const k: number = left.indexOf(g.charAt(i));
      if (k >= 0) { res[i] = '1'; left.splice(k, 1); }
    }
    return res.join('');
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
    if (this.over) {
      return true;
    }
    // ★ 2026-11-08（ai-fixer-a）**不再读 answer**：按历史反馈逐位排除，逐字母按键输入。
    if (this.typed.length < LEN) {
      if (this.autoGuess.length !== LEN) {
        this.autoGuess = this.autoNext();
      }
      this.press(LETTERS.indexOf(this.autoGuess.charAt(this.typed.length)));
      return !this.over;
    }
    this.autoGuess = '';
    this.press(27);            // ⏎ 提交
    return !this.over;
  }

  /**
   * ★ 2026-11-08（ai-fixer-a）代打推理：**只看历史行与反馈标记**（'2' 对位 / '1' 在位 / '0' 无）。
   *   规则：某位出现过 '2' ⇒ 该位定死；出现过 '0' ⇒ 该位排除这个字母；
   *   未知位优先用「还没试过的字母」填（信息增益最大）。全程不碰 answer。
   */
  private autoNext(): string {
    const banned: boolean[][] = [];
    for (let c = 0; c < LEN; c++) {
      banned.push(new Array<boolean>(26).fill(false));
    }
    const fixed: number[] = new Array<number>(LEN).fill(-1);
    const tried: boolean[] = new Array<boolean>(26).fill(false);
    for (let r = 0; r < this.rows.length; r++) {
      const g: string = this.rows[r];
      const mk: string = this.marks[r];
      for (let c = 0; c < LEN; c++) {
        const li: number = LETTERS.indexOf(g.charAt(c));
        if (li < 0) {
          continue;
        }
        tried[li] = true;
        if (mk.charAt(c) === '2') {
          fixed[c] = li;
        } else if (mk.charAt(c) === '0') {
          banned[c][li] = true;
        }
      }
    }
    let out: string = '';
    for (let c = 0; c < LEN; c++) {
      if (fixed[c] >= 0) {
        out = out + LETTERS.charAt(fixed[c]);
        continue;
      }
      let pick: number = -1;
      for (let li = 0; li < 26; li++) {
        if (!banned[c][li] && !tried[li]) {
          pick = li;
          break;
        }
      }
      if (pick < 0) {
        for (let li = 0; li < 26; li++) {
          if (!banned[c][li]) {
            pick = li;
            break;
          }
        }
      }
      out = out + (pick >= 0 ? LETTERS.charAt(pick) : 'A');
    }
    return out;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值就是 this.answer；press 一次敲一格，敲满再按一次提交
  /** 提示：直接报隐藏的词 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('要猜的词是 {0}', this.answer),
      TG2('The hidden word is {0}', this.answer), t0);
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private press(k: number): void {
    if (this.over) { return; }
    if (k < 26) {
      if (this.typed.length < this.diffTotal) { this.typed = this.typed + LETTERS.charAt(k); }
      return;
    }
    if (k === 26) {
      this.typed = this.typed.length > 0 ? this.typed.substring(0, this.typed.length - 1) : '';
      return;
    }
    this.submit();
  }
  private submit(): void {
    // ★★ 2026-11-07（死亡判定巡检 ③）：**收尾防重入**
    //   finish() 本身已有 `if (this.settled) return;`（所以不会重复结算），
    //   但这条入口不判 over ⇒ 结算后还能继续记行/改状态。守卫补在这条入口上。
    if (this.over) { return; }
    if (this.typed.length < this.diffTotal) { this.msg = TG2('还差 {0} 个字母', this.diffTotal - this.typed.length); return; }
    const g: string = this.typed;
    this.rows = this.rows.concat([g]);
    this.marks = this.marks.concat([this.mark(g)]);
    this.typed = '';
    if (g === this.answer) {
      this.over = true; this.won = true; this.score = (TRIES - this.rows.length + 1) * 100;
      this.msg = TG2('🎉 猜中了：{0}', this.answer); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    if (this.rows.length >= TRIES) {
      this.over = true; this.won = false; this.score = 0; this.msg = TG2('❌ 机会用完，答案是 {0}', this.answer);
      this.finish(false); return;
    }
    this.msg = TG2("第 {0} 次：🟩 对位 🟨 在位 ⬜ 无", this.rows.length);
  }
  private finish(solved: boolean): void {
    if (this.settled) { return; }
    this.settled = true;
    const r: GameResult = { gameId: 'word_mastermind', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rows.length };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private letterAt(r: number, c: number): string {
    if (r < this.rows.length) { return this.rows[r].charAt(c); }
    if (r === this.rows.length && c < this.typed.length) { return this.typed.charAt(c); }
    return '';
  }
  private toneAt(r: number, c: number): string {
    if (r >= this.marks.length) { return this.theme.surface; }
    const k: string = this.marks[r].charAt(c);
    if (k === '2') { return Palette.emerald; }
    if (k === '1') { return Palette.amber; }
    return this.theme.isDark ? '#2A2A2A' : '#D8DDE6';
  }
  private keyLabel(k: number): string {
    if (k < 26) { return LETTERS.charAt(k); }
    return k === 26 ? '⌫' : '⏎';
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
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('第几次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((this.rows.length + ' / ' + TRIES)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text((String(TRIES - this.rows.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textOverflow({ overflow: TextOverflow.Ellipsis }).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5, 6], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => { Text(this.letterAt((r), (c))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(34)).backgroundColor(this.toneAt((r), (c))).borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() }) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() }).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4, 5, 6], (c: number) => {
              if (r * 7 + c < KEYS) {
                Text(this.keyLabel((r * 7 + c))).fontSize(FontSize.xs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).fontColor(this.theme.ink).layoutWeight(1).height(Cell.of(36)).backgroundColor(this.theme.surface).borderRadius(Radius.xs).shadow(Shadow.card).onClick(() => { Haptics.tick(); this.press((r * 7 + c)); })
                .focusable(Tv.on())
                .onFocus(() => { this.tvFocus = 'L311'; })
                .onBlur(() => { if (this.tvFocus === 'L311') { this.tvFocus = ''; } })
                .outline(Tv.focusOutline(this.tvFocus === 'L311', Radius.xs))
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.press((r * 7 + c)); }); })
              }
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).layoutWeight(1).height(Cell.tap(44)).onClick(() => { Haptics.tap(); this.reset(); })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L322'; })
      .onBlur(() => { if (this.tvFocus === 'L322') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L322'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        Button(TG('删一个'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).layoutWeight(1).height(Cell.tap(44)).onClick(() => { Haptics.tap(); this.press(26); })
      .focusable(Tv.on())
      .onFocus(() => { this.tvFocus = 'L327'; })
      .onBlur(() => { if (this.tvFocus === 'L327') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L327'))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.press(26); }); })
      }.width('100%')
      Text(TG('提示：🟩 字母与位置都对｜🟨 字母在词里但位置错｜⬜ 词里没有')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
