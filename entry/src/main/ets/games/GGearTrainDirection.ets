/**
 * 齿轮组 ⚙️
 * 玩法：一串齿轮首尾相接，连接处可能是啮合（⛓ 反向）或皮带（🪢 同向）。
 * 已知 1 号齿轮转向，逐级推到最后一级该怎么转。
 * 胜负：8 题全过 = 通关；答错 3 题 = 失败。
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
import { Tv } from '../core/Tv';

const ROUNDS: number = 8;
const LIVES: number = 3;

function spinText(cw: boolean): string {
  return cw ? '↻ 顺时针' : '↺ 逆时针';
}

@Component
export struct GGearTrainDirection {
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
  onFinish: (r: GameResult) => void = () => {};

  @State private gearIds: number[] = [];
  @State private links: boolean[] = [];
  @State private firstCw: boolean = true;
  @State private idx: number = 0;
  @State private score: number = 0;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GGearTrainDirection')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  /** 抽一组 3~5 个齿轮 + 每段连接方式 */
  private roll(): void {
    const n: number = 3 + Math.floor(Math.random() * 3);
    const ids: number[] = [];
    const ls: boolean[] = [];
    for (let i = 0; i < n; i++) {
      ids.push(i);
      if (i < n - 1) { ls.push(Math.random() < 0.65); }
    }
    this.gearIds = ids; this.links = ls;
    this.firstCw = Math.random() < 0.5;
  }

  private reset(): void {
    this.idx = 0; this.score = 0; this.wrong = 0;
    this.over = false; this.won = false;
    this.note = TG(TG(TG('沿齿轮组一路推下去 ⚙️')));
    this.roll();
    this.startAt = Date.now();
  }

  /** 末级转向：每遇一次啮合就翻转一次 */
  private lastCw(): boolean {
    let cw: boolean = this.firstCw;
    for (let i = 0; i < this.links.length; i++) {
      if (this.links[i]) { cw = !cw; }
    }
    return cw;
  }

  private dirLabel(i: number): string {
    if (i === 0) { return spinText(this.firstCw); }
    if (i === this.gearIds.length - 1) { return '?'; }
    return '·';
  }

  /** 提示：报「是 / 否」——代打用的表达式算出来是它 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const truth: boolean = this.lastCw();
    return Hint.make([],
      truth ? TG('答案是「是」') : TG('答案是「否」'),
      truth ? TG('The answer is Yes') : TG('The answer is No'), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔现算：this.lastCw()
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
    if (this.over) {
      return true;
    }
    this.answer(this.lastCw());
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

  private answer(userCw: boolean): void {
    if (this.over) { return; }
    const expect: boolean = this.lastCw();
    if (userCw === expect) {
      this.score += 12;
      this.note = TG2('对！末级 {0} ✅', spinText(expect));
    } else {
      this.wrong++;
      this.note = TG2('错：正确答案是 {0}（失误 {1}/{2}）', spinText(expect), this.wrong, LIVES);
    }
    this.idx++;
    if (this.wrong >= LIVES) { this.finish(false); return; }
    if (this.idx >= this.diffTotal) { this.finish(true); return; }
    this.roll();
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.note = solved ? '八组传动全推对，通关 🎉' : '失误三次，传动链断了 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'gear_train_direction', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.idx + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
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
      Text(TG('第 ') + Math.min(this.idx + 1, this.diffTotal) + '/' + this.diffTotal + ' 题　得分 ' + this.score
        + TG('　失误 ') + this.wrong + '/' + LIVES)
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.gearIds, (i: number) => {
          this.gearRow(i)
          if (i < this.links.length) {
            this.linkRow(i)
          }
        }, (i: number) => 'g' + i)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
      Text(this.note).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button(TG('↻ 顺时针'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.berry)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(true); }); })
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('↺ 逆时针'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.answer(false); }); })
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
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

  @Builder
  gearRow(i: number) {
    Row({ space: Space.sm }) {
      Text(TG2('齿轮 {0}', (i + 1))).fontSize(FontSize.sm).fontColor(this.theme.ink).layoutWeight(1)
      Text('⚙️').accessibilityLevel('no').fontSize(FontSize.lg)
      Text(this.dirLabel(i)).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width(80).textAlign(TextAlign.End)
    }
    .width('100%').height(Cell.of(36))
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  linkRow(i: number) {
    Text(this.links[i] ? '⛓ 啮合 ⇒ 反向' : '🪢 皮带 ⇒ 同向')
      .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      .width('100%').textAlign(TextAlign.Center)
  }
}
