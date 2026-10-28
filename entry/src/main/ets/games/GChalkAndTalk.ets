/** 边写边说 —— 双任务：判断词语类别（说）+ 等光标踩中 ✦ 时落笔（写）
 * 胜负：得分 ≥12 且落笔 ≥3 即通关｜说对 +2 / 说错 -2 / 写对 +1 / 写歪 -1｜进度：剩余 / 得分 / 说·写 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SLOTS: number = 8; const SLOT_IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
const TOTAL_S: number = 30; const TICK_MS: number = 500;
const PASS: number = 12; const WRITE_MIN: number = 3; const SAY_GAP_MS: number = 600;

const CAT_NAMES: string[] = ['水果', '动物', '颜色', '交通工具'];
const CATS: string[][] = [
  [TG('苹果'), TG('香蕉'), '橙子', '葡萄'],
  [TG('老虎'), '大象', '熊猫', '兔子'],
  ['红色', '蓝色', '绿色', '黄色'],
  ['汽车', '火车', '飞机', '轮船']
];

@Component
export struct GChalkAndTalk {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PASS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(PASS);
  onFinish: (r: GameResult) => void = () => {};

  @State cursor: number = 0; @State goal: number = 3; @State ticks: number = 0;
  @State leftS: number = TOTAL_S; @State score: number = 0; @State talkOk: number = 0;
  @State writeOk: number = 0; @State word: string = ''; @State cat: string = '';
  @State truth: boolean = true; @State trueCat: string = ''; @State msg: string = '';
  @State sayLock: boolean = false; @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private gap: number = -1; private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PASS);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } if (this.gap >= 0) { clearTimeout(this.gap); this.gap = -1; } }
  private reset(): void {
    this.stop();
    this.cursor = 0; this.ticks = 0; this.leftS = TOTAL_S; this.score = 0;
    this.talkOk = 0; this.writeOk = 0; this.over = false; this.won = false;
    this.done = false; this.sayLock = false; this.startAt = Date.now();
    this.newGoal(); this.newTalk();
    this.msg = TG('两件事同时干：说类别 + 踩点落笔');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    if (this.over) { return; }
    this.ticks = this.ticks + 1;
    this.cursor = (this.cursor + 1) % SLOTS;
    if (this.ticks % 2 === 0) {
      this.leftS = this.leftS - 1;
      if (this.leftS <= 0) { this.end(); }
    }
  }
  private newGoal(): void { this.goal = Math.floor(Math.random() * SLOTS); }
  /** 一半概率抽到真类别，一半概率抽到错的 */
  private newTalk(): void {
    const a: number = Math.floor(Math.random() * CATS.length);
    const b: number = (a + 1 + Math.floor(Math.random() * (CATS.length - 1))) % CATS.length;
    const ok: boolean = Math.random() < 0.5;
    this.word = CATS[a][Math.floor(Math.random() * CATS[a].length)];
    this.cat = ok ? CAT_NAMES[a] : CAT_NAMES[b];
    this.trueCat = CAT_NAMES[a]; this.truth = ok;
  }
  /** 通关 = 说得准 + 真落过笔，防「只刷说」或「只刷写」 */
  private target(): boolean { return this.score >= this.diffTotal && this.writeOk >= WRITE_MIN; }
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
    if (this.cursor === this.goal) {
      this.write();
      return !this.over;
    }
    if (this.sayLock) {
      return true;
    }
    this.say(this.truth);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.cursor === this.goal) {
      return Hint.make([],
        TG2('光标正踩在 ✦ 上 ⇒ 立刻点「落笔 ✍️」'),
        TG2('The cursor is on ✦ — tap 落笔 ✍️ now'), t0);
    }
    if (this.truth) {
      return Hint.make([],
        TG2('「{0}」确实属于{1} ⇒ 说「是」', this.word, this.trueCat),
        TG2('{0} really is a kind of {1} — answer 是', this.word, this.trueCat), t0);
    }
    return Hint.make([],
      TG2('「{0}」其实属于{1}，不是{2} ⇒ 说「否」', this.word, this.trueCat, this.cat),
      TG2('{0} is a {1}, not a {2} — answer 否', this.word, this.trueCat, this.cat), t0);
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

  private say(said: boolean): void {
    if (this.over || this.sayLock) { return; }
    if (said === this.truth) {
      this.score = this.score + 2; this.talkOk = this.talkOk + 1; this.msg = TG('✅ 说对了 +2');
    } else {
      this.score = this.score > 2 ? this.score - 2 : 0;
      this.msg = TG2('❌ 说错了 -2（{0} 属于{1}）', this.word, this.trueCat);
    }
    this.newTalk(); this.sayLock = true;
    this.gap = setTimeout(() => { this.gap = -1; this.sayLock = false; }, SAY_GAP_MS);
    if (this.target()) { this.end(); }
  }
  private write(): void {
    if (this.over) { return; }
    if (this.cursor === this.goal) {
      this.score = this.score + 1; this.writeOk = this.writeOk + 1; this.msg = TG('✍️ 落笔成功 +1');
      this.newGoal(); if (this.target()) { this.end(); }
      return;
    }
    this.score = this.score > 0 ? this.score - 1 : 0; this.msg = TG('✍️ 写歪了 -1');
  }
  private end(): void {
    this.stop();
    this.over = true; this.won = this.target();
    this.msg = TG2("{0}得分 {1}　落笔 {2}", (this.won ? TG('🎉 通关：') : TG('💤 结束：')),Digits(String(this.score), this.langCode),Digits(String(this.writeOk), this.langCode)); this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'chalk_and_talk', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.talkOk + this.writeOk };
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
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('说/写'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.talkOk + '/' + this.writeOk)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text(TG2('说：「{0}」属于「{1}」吗？', this.word, this.cat)).fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
        Row({ space: Space.sm }) {
          Button(('是'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor((true) ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over && !this.sayLock).onClick(() => { Haptics.tap(); this.say((true)); })
          Button(('否'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF')
          .backgroundColor((false) ? Palette.emerald : Palette.rose)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over && !this.sayLock).onClick(() => { Haptics.tap(); this.say((false)); })
        }.width('100%')
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Text(TG2("写：光标踩中 ✦ 时落笔　得分 ≥{0} 且落笔 ≥{1} 通关",Digits(String(this.diffTotal), this.langCode), WRITE_MIN)).fontSize(FontSize.xs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.xs }) {
        ForEach(SLOT_IDX, (i: number) => { Text((i) === this.cursor ? '✍️' : ((i) === this.goal ? '✦' : '·'))
        .fontSize(FontSize.md).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(36))
        .backgroundColor((i) === this.cursor ? Palette.orange : ((i) === this.goal ? Palette.amber : this.theme.surface))
        .borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() }) }, (i: number) => 's' + i)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Button(TG('落笔 ✍️'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(Palette.orange)
        .borderRadius(Radius.md).width('100%').height(Cell.of(56))
        .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tap(); this.write(); })
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
