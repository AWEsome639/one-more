/**
 * 延迟匹配 —— 看一眼样例，隔一会儿再从 4 个里挑出它
 * 胜负：8 题答对 ≥ 6 通关，错满 3 题判负　｜　进度：题号 / 答对 / 错误
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐟', '🔔', '🍀', '🚀'];
const TRIALS: number = 8;
const PASS: number = 6;
const MAX_WRONG: number = 3;
const SHOW_MS: number = 1400;
const DELAY_MS: number = 1800;
const PER_HIT: number = 100;

@Component
export struct GDelayedMatchSample {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TRIALS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TRIALS);
  onFinish: (r: GameResult) => void = () => {};

  @State phase: number = 0;        // 0=样例 1=延迟 2=作答 3=结束
  @State sample: string = '🍎';
  @State options: string[] = [];
  @State trial: number = 1;
  @State correct: number = 0;
  @State wrong: number = 0;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;
  private t1: number = -1;
  private t2: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDelayedMatchSample')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTimers(); }

  private clearTimers(): void {
    if (this.t1 >= 0) { clearTimeout(this.t1); this.t1 = -1; }
    if (this.t2 >= 0) { clearTimeout(this.t2); this.t2 = -1; }
  }

  private reset(): void {
    this.clearTimers();
    this.trial = 1; this.correct = 0; this.wrong = 0;
    this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now();
    this.nextTrial();
  }

  private nextTrial(): void {
    const s: string = POOL[Math.floor(Math.random() * POOL.length)];
    this.sample = s;
    const others: string[] = [];
    for (let i = 0; i < POOL.length; i++) {
      if (POOL[i] !== s) { others.push(POOL[i]); }
    }
    const opts: string[] = [s];
    while (opts.length < 4 && others.length > 0) {
      const j: number = Math.floor(Math.random() * others.length);
      opts.push(others[j]);
      others.splice(j, 1);
    }
    for (let k = opts.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: string = opts[k];
      opts[k] = opts[j];
      opts[j] = tmp;
    }
    this.options = opts;
    this.phase = 0;
    this.msg = TG('记住它');
    this.t1 = setTimeout(() => {
      this.phase = 1;
      this.msg = TG('遮住了…… 保持住');
      this.t2 = setTimeout(() => {
        this.phase = 2;
        this.msg = TG('选出刚才那个');
      }, DELAY_MS);
    }, SHOW_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.phase !== 2) {
      return true;
    }
    this.answer(this.sample);
    return !this.over;
  }

  /** 提示：直接报答案 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.phase !== 2) {
      return Hint.none('none');
    }
    const a: string = this.sample;
    if (a.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([], TG2('刚才的是「{0}」', a),
      TG2('It was {0}', a), t0);
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

  private answer(pick: string): void {
    if (this.over || this.phase !== 2) { return; }
    const truth: string = this.sample;
    if (pick === truth) {
      this.correct++;
      this.msg = TG2("✅ 答对 {0} 题", this.correct);
    } else {
      this.wrong++;
      this.msg = TG2('❌ 刚才是 {0}', truth);
    }
    if (this.wrong >= MAX_WRONG) { this.end(false); return; }
    if (this.trial >= this.diffTotal) { this.end(this.correct >= PASS); return; }
    this.trial++;
    this.nextTrial();
  }

  private end(solved: boolean): void {
    this.clearTimers();
    this.over = true;
    this.won = solved;
    this.phase = 3;
    this.msg = solved ? '🎉 通关：答对 ' + this.correct + ' / ' + this.diffTotal
      : TG('答对 ') + this.correct + ' 题，再来一局';
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'delayed_match_sample', solved: solved, score: this.correct * PER_HIT,
      durationMs: Date.now() - this.startAt, levelReached: this.correct
    };
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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.trial, this.diffTotal) + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.correct), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.wrong + ' / ' + MAX_WRONG)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Stack() {
        if (this.phase === 0) {
          Text(this.sample).fontSize(FontSize.hero)
        } else if (this.phase === 1) {
          Text('🌫️').fontSize(FontSize.hero).opacity(0.6)
            .accessibilityLevel('no')
        } else {
          Text(this.over ? (this.won ? '🎉' : '🏁') : '❓').fontSize(FontSize.hero)
        }
      }.width('100%').layoutWeight(1).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Text((this.options.length > 0 ? this.options[0] : '')).fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((this.options.length > 0 ? this.options[0] : '')); }); })
        .onClick(() => { Haptics.tick(); this.answer((this.options.length > 0 ? this.options[0] : '')); })
        Text((this.options.length > 1 ? this.options[1] : '')).fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((this.options.length > 1 ? this.options[1] : '')); }); })
        .onClick(() => { Haptics.tick(); this.answer((this.options.length > 1 ? this.options[1] : '')); })
      }.width('100%')

      Row({ space: Space.sm }) {
        Text((this.options.length > 2 ? this.options[2] : '')).fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((this.options.length > 2 ? this.options[2] : '')); }); })
        .onClick(() => { Haptics.tick(); this.answer((this.options.length > 2 ? this.options[2] : '')); })
        Text((this.options.length > 3 ? this.options[3] : '')).fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answer((this.options.length > 3 ? this.options[3] : '')); }); })
        .onClick(() => { Haptics.tick(); this.answer((this.options.length > 3 ? this.options[3] : '')); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("样例亮 1.4 秒 ⇒ 遮挡 1.8 秒 ⇒ 作答；答对 {0} / {1} 通关",Digits(String(PASS), this.langCode),Digits(String(this.diffTotal), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
