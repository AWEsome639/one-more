/**
 * 计算冲刺 —— 限时连算
 *
 * 玩法：加减乘除心算，四选一；答对连击加分，答错扣 3 秒。
 * 胜负：60 秒内答对 15 题 ⇒ 通关；时间归零还没达标 ⇒ 失败。
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
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const TIME_LIMIT: number = 60;
const GOAL: number = 15;         // 通关需答对
const PICK: number = 4;
const NEXT_MS: number = 460;
const PENALTY: number = 3;       // 答错扣秒
const TICK_MS: number = 1000;
const LETTERS: string[] = ['A', 'B', 'C', 'D'];
const OPS: string[] = ['＋', '−', '×', '÷'];

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GCalculationSprint {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private opts: number[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private quiz: string = '';
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private combo: number = 0;
  @State private best: number = 0;
  @State private score: number = 0;
  // ★ 难度作用到玩法：本局实际时限 = 基础 60s × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  //   必须在这里算 —— TIME_LIMIT 是模块常量，模块加载时就算死了，中途改难度不会重算
  private total: number = GameDiff.timeNow(TIME_LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private timer: number = -1;
  private nextTo: number = -1;
  private finished: boolean = false;
  private optsIdx: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GCalculationSprint')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    // ★ 难度可能刚变过 ⇒ 时限必须**重算**，不能只靠字段初始化（构造时那一次）
    this.total = GameDiff.timeNow(TIME_LIMIT);
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearAll();
  }

  private clearAll(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    this.clearAll();
    this.right = 0;
    this.wrong = 0;
    this.combo = 0;
    this.best = 0;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.ask();
    this.msg = TG2("算得越快，连击越高；答错扣 {0} 秒",Digits(String(PENALTY), this.langCode));
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.tick();
    }, TICK_MS);
  }

  private tick(): void {
    if (this.over) {
      return;
    }
    this.left = this.left - 1;
    if (this.left <= 0) {
      this.left = 0;
      this.lose(TG('⏰ 时间到，答对 ') + String(this.right) + ' 题，没到 ' + String(GOAL) + TG(' 题'));
    }
  }

  private ask(): void {
    const op: number = Math.floor(Math.random() * 4);
    let a: number = 0;
    let b: number = 0;
    let correct: number = 0;
    if (op === 0) {
      a = randInt(12, 99);
      b = randInt(12, 99);
      correct = a + b;
    } else if (op === 1) {
      a = randInt(30, 99);
      b = randInt(10, a - 1);
      correct = a - b;
    } else if (op === 2) {
      a = randInt(3, 12);
      b = randInt(3, 19);
      correct = a * b;
    } else {
      b = randInt(3, 12);
      correct = randInt(3, 12);
      a = b * correct;
    }
    const pool: number[] = [correct + 1, correct - 1, correct + 2, correct - 2, correct + 10];
    const opts: number[] = [correct];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (pool[i] > 0 && opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i];
      opts[i] = opts[j];
      opts[j] = t;
    }
    this.opts = opts;
    this.ans = opts.indexOf(correct);
    this.picked = -1;
    this.quiz = String(a) + ' ' + OPS[op] + ' ' + String(b) + ' = ?';
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ans 里） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是 {0}', String(this.opts[n])),
      TG2('The answer is {0}', String(this.opts[n])), t0);
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
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.combo = this.combo + 1;
      if (this.combo > this.best) {
        this.best = this.combo;
      }
      this.score += 60 + this.combo * 10;
      this.msg = TG2('✅ 答对！连击 ×{0}', String(this.combo));
    } else {
      this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.combo = 0;
      this.score = Math.max(0, this.score - 20);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒（正确答案已标绿）",Digits(String(PENALTY), this.langCode));
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.advance();
    }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) {
      return;
    }
    if (this.right >= GOAL) {
      this.over = true;
      this.won = true;
      this.msg = TG2("🎉 答对 {0} 题，通关！剩 {1} 秒",Digits(String(GOAL), this.langCode),Digits(String(this.left), this.langCode));
      this.clearAll();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.left <= 0) {
      this.lose(TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题'));
      return;
    }
    this.ask();
  }

  private lose(why: string): void {
    if (this.finished) {
      return;
    }
    this.over = true;
    this.won = false;
    this.msg = why;
    this.clearAll();
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'calculation_sprint',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private optBg(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.emerald;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private optInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 时间条
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.full)
        Row()
          .width(this.left * 100 / this.total + '%')
          .height('100%')
          .backgroundColor(this.left <= 15 ? Palette.rose : Palette.amber)
          .borderRadius(Radius.full)
          .animation({ duration: Motion.base, curve: Motion.snap() })
      }
      .width('100%')
      .height(8)

      Column({ space: Space.xs }) {
        Text(this.quiz)
          .fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.amber)
        Text(TG2('连击 ×{0} · 最高 ×{1} · 第 {2} 题', String(this.combo), String(this.best), String(this.right + this.wrong + 1)))
          .fontSize(FontSize.xxs)
          // ★ 错误抖动
          .translate({ x: this.shakeX })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .fontColor(this.theme.inkFaint)
      }
      .width('100%')
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Column({ space: Space.sm }) {
        ForEach(this.optsIdx, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i])
              .fontSize(FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.inkFaint)
            Text(String(this.opts[i]))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.optInk(i))
              .layoutWeight(1)
          }
          .width('100%')
          .height(Cell.of(52))
          .padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i))
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick(i); }); })
          .onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'cs' + i)
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')

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

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('提示：答对一题 +1，答错扣 {0} 秒 —— 稳一点比快一点划算',Digits(String(PENALTY), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=剩余 1=答对 2=得分 */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('剩余') : (kind === 1 ? TG('答对') : TG('得分')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.left + 's'
        : (kind === 1 ? this.right + '/' + GOAL : String(this.score)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 && this.left <= 15 ? Palette.rose : this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }
}
