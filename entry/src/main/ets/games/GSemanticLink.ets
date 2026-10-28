/** 语义连接 —— 沿语义链一环扣一环往下接｜胜负：接通整条 6 词链通关，生命耗尽即失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const LIVES: number = 3; const GAP_MS: number = 700;

/** 每条链内部逐环语义递进 */
const CHAINS: string[][] = [
  ['种子', '嫩芽', '树苗', '大树', '森林', '地球'],
  ['面粉', '面团', '面包', '早餐', '能量', '奔跑'],
  ['露水', '小溪', TG('河流'), '大江', '海洋', '云朵'],
  ['字母', '单词', '句子', '段落', '文章', '书籍']
];

function shufStr(src: string[]): string[] {
  const out: string[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSemanticLink {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State chain: string[] = []; @State at: number = 0; @State opts: string[] = [];
  @State ans: number = 0; @State picked: number = -1; @State lives: number = this.diffTotal;
  @State score: number = 0; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private feed: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSemanticLink')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void { if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; } }

  private reset(): void {
    this.stop();
    this.chain = CHAINS[Math.floor(Math.random() * CHAINS.length)].slice();
    this.at = 0; this.lives = this.diffTotal; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.next();
  }

  private next(): void {
    const correct: string = this.chain[this.at + 1];
    const sameWrong: string[] = [];
    for (let i = 0; i < this.chain.length; i++) {
      if (i !== this.at + 1) { sameWrong.push(this.chain[i]); }
    }
    const two: string[] = shufStr(sameWrong);
    let oi: number = Math.floor(Math.random() * CHAINS.length);
    if (CHAINS[oi][0] === this.chain[0]) { oi = (oi + 1) % CHAINS.length; }
    const other: string[] = CHAINS[oi];
    const four: string[] = shufStr([correct, two[0], two[1], other[Math.floor(Math.random() * other.length)]]);
    this.opts = four; this.ans = four.indexOf(correct); this.picked = -1;
    this.msg = TG2('「{0}」后面接哪个？', this.chain[this.at]);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：报答案（字段 this.at） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.at],
      TG2('答案是第 {0} 个', String(this.at + 1)),
      TG2('The answer is option {0}', String(this.at + 1)), t0);
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
    this.picked = i;
    if (i === this.ans) {
      this.at = this.at + 1; this.score = this.score + 120;
      this.msg = TG2('✅ 接上「{0}」', this.chain[this.at]);
    } else {
      this.lives = this.lives - 1;
      this.msg = TG2('❌ 断了 —— 该接「{0}」', this.chain[this.at + 1]);
    }
    if (this.at + 1 >= this.chain.length) {
      this.over = true; this.won = true;
      this.msg = TG2('🎉 通关：链已接通 —— {0}', this.chain.join(' → '));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 生命耗尽，链停在「{0}」', this.chain[this.at]);
      this.finish(false); return;
    }
    this.feed = setTimeout(() => { this.feed = -1; this.next(); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'semantic_link', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.at + 1 };
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
        Column({ space: Space.xs }) {
        Text((TG('已连'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.at + 1) + '/' + this.chain.length)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.berry))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(TG('📖 语义链')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.chain.slice(0, this.at + 1).join(' → '))
          .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).textAlign(TextAlign.Center)
        Text('?').accessibilityText(TG('待求')).fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
          .accessibilityLevel('no')
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(this.opts.length > (0) ? this.opts[(0)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.berry
        : ((0) === this.ans ? Palette.emerald : ((0) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((0)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((0)); }); })
        Button(this.opts.length > (1) ? this.opts[(1)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.berry
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
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.berry
        : ((2) === this.ans ? Palette.emerald : ((2) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((2)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((2)); }); })
        Button(this.opts.length > (3) ? this.opts[(3)] : '')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
        .backgroundColor(this.picked < 0 ? Palette.berry
        : ((3) === this.ans ? Palette.emerald : ((3) === this.picked ? Palette.rose : this.theme.lineSoft)))
        .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .enabled(!this.over && this.picked < 0).onClick(() => { Haptics.tap(); this.pick((3)); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pick((3)); }); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('每错一环少一条命；接通全链即通关')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
