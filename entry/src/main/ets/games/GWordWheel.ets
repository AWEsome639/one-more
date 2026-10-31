/**
 * 单词轮 —— 从 6 个字母里拼英文单词（每个字母一轮只能用一次）
 * 胜负：找齐 5 个词通关；拼错 3 次失败　进度：已找到 / 得分 / 剩余机会
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

interface WheelSet { letters: string; words: string[]; }
const SETS: WheelSet[] = [
  { letters: 'SILENT', words: ['SIT', 'TIN', 'TIE', 'LIE', 'LINE', 'LIST', 'NEST', 'SENT', 'TILE', 'SILT'] },
  { letters: 'MASTER', words: ['ARM', 'ART', 'EAT', 'SEA', 'TEAM', 'EAST', 'MAST', 'STEM', 'TEAR', 'RATE'] },
  { letters: 'GARDEN', words: ['AGE', 'END', 'RAN', 'RED', 'DEAR', 'READ', 'DARE', 'RANG', 'GRAND', 'GRADE'] },
  { letters: 'PLANET', words: ['PLAN', 'LANE', 'TALE', 'LATE', 'NEAT', 'PLEA', 'PLANE', 'PLANT', 'PETAL'] },
  { letters: 'CANDLE', words: ['CAN', 'AND', 'END', 'LAND', 'LANE', 'DEAL', 'LEAD', 'LEND', 'DANCE', 'CLEAN'] }
];
const GOAL: number = 5; const LIVES: number = 3;

@Component
export struct GWordWheel {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GOAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(GOAL);
  onFinish: (r: GameResult) => void = () => {};

  @State letters: string[] = []; @State bank: string[] = []; @State found: string[] = [];
  @State typed: string = ''; @State score: number = 0; @State life: number = LIVES;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3, 4, 5];

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GWordWheel')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GOAL);
     this.reset(); }

  private reset(): void {
    const s: WheelSet = SETS[Math.floor(Math.random() * SETS.length)];
    this.letters = s.letters.split(''); this.bank = s.words; this.found = []; this.typed = '';
    this.score = 0; this.life = LIVES; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.msg = TG('点字母拼词 —— 每个字母一轮只能用一次');
  }

  private goal(): number { return Math.min(this.diffTotal, this.bank.length); }

  private cnt(src: string, ch: string): number {
    let n: number = 0;
    for (let i = 0; i < src.length; i++) { if (src.charAt(i) === ch) { n = n + 1; } }
    return n;
  }

  private pick(i: number): void {
    if (this.over) { return; }
    const ch: string = this.letters[i];
    if (this.cnt(this.typed, ch) >= this.cnt(this.letters.join(''), ch)) {
      this.msg = TG2('「{0}」这一轮已经用掉了', ch); return;
    }
    this.typed = this.typed + ch;
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
    let target: string = '';
    for (let i = 0; i < this.bank.length; i++) {
      if (this.found.indexOf(this.bank[i]) < 0) {
        target = this.bank[i];
        break;
      }
    }
    if (target.length === 0) {
      return false;
    }
    if (this.typed.length > 0 && target.substring(0, this.typed.length) !== this.typed) {
      this.typed = '';           // 玩家留下的半截词，先清掉
      return true;
    }
    if (this.typed.length < target.length) {
      this.pick(this.letters.indexOf(target.charAt(this.typed.length)));
      return !this.over;
    }
    this.submit();
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.bank.length; i++) {
      const w: string = this.bank[i];
      if (this.found.indexOf(w) < 0) {
        return Hint.make([],
          TG2('下一个可以拼「{0}」（{1} 个字母）', w, String(w.length)),
          TG2('Try "{0}" next', w), t0);
      }
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

  private submit(): void {
    if (this.over) { return; }
    const w: string = this.typed;
    if (w.length < 3) { this.msg = TG('至少 3 个字母才算词'); return; }
    if (this.found.indexOf(w) >= 0) { this.msg = TG2('「{0}」已经找过了', w); return; }
    if (this.bank.indexOf(w) < 0) {
      this.life = this.life - 1; this.score = Math.max(0, this.score - 20); this.typed = '';
      if (this.life <= 0) { this.end(false); return; }
      this.msg = TG2('❌ 本组词里没有「{0}」，只剩 {1} 次机会', w,Digits(String(this.life), this.langCode)); return;
    }
    const gain: number = 40 + w.length * 10;
    const f: string[] = this.found.slice(); f.push(w); this.found = f;
    this.score = this.score + gain; this.typed = '';
    if (f.length >= this.goal()) { this.end(true); return; }
    this.msg = TG2("✅ 「{0}」+ {1} 分", w, gain);
  }

  private end(solved: boolean): void {
    this.over = true; this.won = solved;
    this.msg = solved ? '🎉 找齐 ' + this.goal() + ' 个词，通关！'
      : '💤 机会用完 —— 本组共有 ' + this.bank.length + TG(' 个词');
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'word_wheel', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.found.length };
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
        Column({ space: 2 }) {
        Text((TG('找到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found.length + '/' + this.goal())).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.cyan))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('机会'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + '/' + LIVES)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Text(this.typed.length === 0 ? '＿ ＿ ＿' : this.typed)
        .fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).width('100%').height(Cell.of(56))
        .textAlign(TextAlign.Center)
        .fontColor(this.typed.length === 0 ? this.theme.inkFaint : Palette.primaryDeep)
        .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.xs }) {
        ForEach(this.slots, (i: number) => {
          Text(this.letters[(i)]).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .textAlign(TextAlign.Center).layoutWeight(1).aspectRatio(1)
          .backgroundColor(this.theme.isDark ? Palette.primaryDeep : Palette.primary)
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { Haptics.tick(); this.pick((i)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((i)); }); })
        }, (i: number) => 'L' + i)
      }
      .width('100%')

      Text(this.found.length === 0 ? '已找到：（空）' : '已找到：' + this.found.join(' · '))
        .fontSize(FontSize.xs).fontColor(this.theme.inkFaint).width('100%')

      Row({ space: Space.sm }) {
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.submit(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.submit(); }); })
        Button(TG('退格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).width(76).height(Cell.of(46))
          .onClick(() => { Haptics.tap(); this.typed = this.typed.substring(0, Math.max(0, this.typed.length - 1)); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.typed = this.typed.substring(0, Math.max(0, this.typed.length - 1)); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).fontColor('#FFFFFF').backgroundColor(Palette.cyan)
          .borderRadius(Radius.md).width(76).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Text(TG('提示：词都是 3~6 个字母的常见英文词，先凑短的再拼长的'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
