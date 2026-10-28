/**
 * 双重麻烦 —— 一屏两个任务同时来：左边算算术，右边认颜色（斯特鲁普）
 *
 * 玩法：每轮要**两个都答对**才算过。算术题给 4 个数字选项；颜色题给一个"字义与颜色不符"的字
 *       （比如"红"字用绿墨水写），必须点**墨水颜色**对应的按钮（按钮上是颜色名，且用该颜色涂）
 * 胜负：撑过 8 轮 ⇒ solved=true；答错 3 次（生命用尽）⇒ solved=false
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

const ROUNDS: number = 8;
const LIVES: number = 3;
const PER_CORRECT: number = 50;

const COLOR_NAMES: string[] = [TG('红'), TG('绿'), TG('蓝')];
const COLOR_VALUES: string[] = [Palette.rose, Palette.emerald, Palette.sky];

@Component
export struct GDoubleTrouble {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private round: number = 1;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  @State private right: number = 0;          // 累计答对的小任务数
  @State private aDone: boolean = false;
  @State private bDone: boolean = false;
  @State private qText: string = '';
  @State private aAns: number = 0;
  @State private aOpts: number[] = [];
  @State private word: string = '';
  @State private ink: string = '';
  @State private bAns: string = '';
  @State private bOpts: string[] = [];
  @State private msg: string = TG('两个任务都做完才算过一轮');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDoubleTrouble')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);
    this.reset();
  }

  private reset(): void {
    this.round = 1;
    this.lives = this.total;
    this.right = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('两个任务都做完才算过一轮');
    this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    // ── 任务①：乘法 ──
    const a: number = 2 + Math.floor(Math.random() * 8);
    const b: number = 2 + Math.floor(Math.random() * 8);
    this.aAns = a * b;
    this.qText = a + ' × ' + b + ' = ?';
    const opts: number[] = [this.aAns];
    while (opts.length < 4) {
      const delta: number = (1 + Math.floor(Math.random() * 9)) * (Math.random() < 0.5 ? -1 : 1);
      const cand: number = this.aAns + delta;
      if (cand > 0 && opts.indexOf(cand) < 0) {
        opts.push(cand);
      }
    }
    for (let k = opts.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: number = opts[k];
      opts[k] = opts[j];
      opts[j] = t;
    }
    this.aOpts = opts;

    // ── 任务②：字义与颜色不符 ──
    const wi: number = Math.floor(Math.random() * COLOR_NAMES.length);
    let ii: number = Math.floor(Math.random() * COLOR_NAMES.length);
    if (ii === wi) {
      ii = (ii + 1) % COLOR_NAMES.length;
    }
    this.word = COLOR_NAMES[wi];
    this.ink = COLOR_VALUES[ii];
    this.bAns = COLOR_NAMES[ii];
    const bo: string[] = [];
    for (let i = 0; i < COLOR_NAMES.length; i++) {
      bo.push(COLOR_NAMES[i]);
    }
    this.bOpts = bo;

    this.aDone = false;
    this.bDone = false;
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
    if (!this.aDone) {
      this.pickA(this.aAns);
      return !this.over;
    }
    if (!this.bDone) {
      this.pickB(this.bAns);
      return !this.over;
    }
    return true;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 两个真值都在状态里：aAns（乘法结果）、bAns（墨水颜色的名字）
  /** 提示：先报算术答案，答完再报颜色 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (!this.aDone) {
      return Hint.make([],
        TG2('算术：{0} 的答案是 {1}', this.qText, String(this.aAns)),
        TG2('Math: {0} → {1}', this.qText, String(this.aAns)), t0);
    }
    return Hint.make([],
      TG2('颜色：点「{0}」—— 要看墨水色，不是字义', this.bAns),
      TG2('Colour: tap {0} — the ink colour, not the word', this.bAns), t0);
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

  private pickA(v: number): void {
    if (this.over || this.aDone) {
      return;
    }
    if (v === this.aAns) {
      this.aDone = true;
      this.right++;
      this.msg = TG('算术对了 ✅');
      this.checkRound();
    } else {
      this.penalty(TG('算术答错了'));
    }
  }

  private pickB(name: string): void {
    if (this.over || this.bDone) {
      return;
    }
    if (name === this.bAns) {
      this.bDone = true;
      this.right++;
      this.msg = TG('颜色对了 ✅');
      this.checkRound();
    } else {
      this.penalty(TG('颜色认错了（要选墨水色，不是字义）'));
    }
  }

  private penalty(why: string): void {
    this.lives--;
    if (this.lives <= 0) {
      this.msg = TG2('❌ {0}，生命用尽', why);
      this.end(false);
      return;
    }
    this.msg = TG2("❌ {0}，还剩 {1} 条命", why,Digits(String(this.lives), this.langCode));
  }

  private checkRound(): void {
    if (this.over || !this.aDone || !this.bDone) {
      return;
    }
    if (this.round >= ROUNDS) {
      this.end(true);
      return;
    }
    this.round++;
    this.msg = TG2("第 {0} 轮开始，两个任务都做完", this.round);
    this.newRound();
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.msg = solved
      ? '🎉 撑过 ' + ROUNDS + ' 轮，答对 ' + this.right + ' 个小任务'
      : TG2('结束：撑到第 {0} 轮，答对 {1} 个小任务', this.round, this.right);
    this.finish(solved);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'double_trouble',
      solved: solved,
      score: this.right * PER_CORRECT + this.lives * 30,
      durationMs: Date.now() - this.startAt,
      levelReached: this.round
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + ROUNDS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hearts())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      // 任务①：算术
      Column({ space: Space.xs }) {
        Text(TG2("任务① 算术{0}", (this.aDone ? ' ✅' : '')))
          .fontSize(FontSize.xs)
          .fontColor(this.theme.inkFaint)
        Text(this.qText)
          .fontSize(FontSize.xxl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
        Row({ space: Space.xs }) {
          ForEach(this.aOpts, (v: number) => {
            Text(String(v))
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ink)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(Cell.of(46))
              .backgroundColor(this.theme.surfaceAlt)
              .borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pickA(v); }); })
              .onClick(() => {
                Haptics.tick();
                this.pickA(v);
              })
          }, (v: number) => 'a' + v)
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      // 任务②：颜色
      Column({ space: Space.xs }) {
        Text(TG2("任务② 认颜色{0}（点「墨水」的颜色）", (this.bDone ? ' ✅' : '')))
          .fontSize(FontSize.xs)
          .fontColor(this.theme.inkFaint)
        Text(this.word)
          .fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.ink)
        Row({ space: Space.xs }) {
          ForEach(this.bOpts, (n: string, i: number) => {
            Text(n)
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(Cell.of(46))
              .backgroundColor(COLOR_VALUES[i % COLOR_VALUES.length])
              .borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pickB(n); }); })
              .onClick(() => {
                Haptics.tick();
                this.pickB(n);
              })
          }, (n: string) => 'b' + n)
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.primary)
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

      Text(TG2('每轮两个任务都要答对；答错扣一条命，{0} 条命用完就结束，撑过 {1} 轮通关',Digits(String(LIVES), this.langCode),Digits(String(ROUNDS), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** 生命显示：❤ = 还剩，🤍 = 已扣 */
  private hearts(): string {
    let s: string = '';
    for (let i = 0; i < LIVES; i++) {
      s += i < this.lives ? '❤' : '🤍';
    }
    return s;
  }


}
