/**
 * 连续配对 —— 经典的"成对联想"记忆任务
 *
 * 玩法：先看 4 组配对（学会阶段），点「记住了」开始答题；
 *       之后连续 8 题：给出左项，从 4 个右项里选出刚才配对的它
 * 胜负：答完 8 题 ⇒ solved=true；中途错满 3 题 ⇒ solved=false（答完立刻出下一题，节奏不断）
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const PAIRS_PER_ROUND: number = 4;   // 学会阶段记几对
const TRIALS: number = 8;            // 答题总题数
const MAX_MISTAKE: number = 3;       // 错满就结束
const PER_CORRECT: number = 100;

interface Pair {
  a: string;
  b: string;
}

const POOL: Pair[] = [
  { a: '🐶', b: '🍖' },
  { a: '🐱', b: '🐟' },
  { a: '🐰', b: '🥕' },
  { a: '🐻', b: '🍯' },
  { a: '🐼', b: '🎋' },
  { a: '🐵', b: '🍌' },
  { a: '🐧', b: '🧊' },
  { a: '🦊', b: '🍇' },
  { a: '🐝', b: '🌻' },
  { a: '🐳', b: '🌊' }
];

@Component
export struct GContinuousPairedAssociate {
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

  @State private phase: number = 0;          // 0 = 学会，1 = 答题，2 = 结束
  @State private pairs: Pair[] = [];
  @State private trial: number = 0;
  @State private correct: number = 0;
  @State private mistakes: number = 0;
  @State private options: string[] = [];
  @State private lastMsg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TRIALS);
    this.reset();
  }

  private reset(): void {
    const idx: number[] = [];
    for (let i = 0; i < POOL.length; i++) {
      idx.push(i);
    }
    for (let k = idx.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: number = idx[k];
      idx[k] = idx[j];
      idx[j] = t;
    }
    const ps: Pair[] = [];
    for (let i = 0; i < PAIRS_PER_ROUND; i++) {
      ps.push(POOL[idx[i]]);
    }
    this.pairs = ps;
    this.phase = 0;
    this.trial = 0;
    this.correct = 0;
    this.mistakes = 0;
    this.options = [];
    this.lastMsg = TG('看 4 组配对，记住谁配谁');
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
  }

  private cur(): Pair {
    const i: number = this.trial % this.pairs.length;
    return this.pairs[i];
  }

  /** 出题：正确项 + 3 个别的右项，打乱 */
  private startTrial(): void {
    const right: string = this.cur().b;
    const others: string[] = [];
    for (let i = 0; i < this.pairs.length; i++) {
      if (this.pairs[i].b !== right) {
        others.push(this.pairs[i].b);
      }
    }
    const opts: string[] = [right];
    while (opts.length < 4 && others.length > 0) {
      const j: number = Math.floor(Math.random() * others.length);
      opts.push(others[j]);
      others.splice(j, 1);
    }
    for (let k = opts.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: string = opts[k];
      opts[k] = opts[j];
      opts[j] = t;
    }
    this.options = opts;
  }

  /** 提示：直接报答案（连续配对，字符串） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const a: string = this.cur().b;
    if (a.length === 0) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('答案是 {0}', a),
      TG2('The answer is {0}', a), t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 按 phase 分步：等作答 → 作答 → 推进下一题。每一步只做一件事。
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
    if (this.phase === 0) {
      this.phase = 1;
      this.startTrial();
      return true;
    }
    if (this.phase === 1) {
      this.answer(this.cur().b);
    }
    return !this.over;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private answer(pick: string): void {
    if (this.over || this.phase !== 1) {
      return;
    }
    if (pick === this.cur().b) {
      this.correct++;
      this.lastMsg = TG2("✅ 答对 {0} 题", this.correct);
    } else {
      this.mistakes++;
      this.lastMsg = TG2('❌ 它配的是 {0}', this.cur().b);
    }
    this.trial++;
    if (this.mistakes >= MAX_MISTAKE) {
      this.end(false);
      return;
    }
    if (this.trial >= this.diffTotal) {
      this.end(true);
      return;
    }
    this.startTrial();
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.phase = 2;
    this.lastMsg = solved
      ? '🎉 8 题答完，错误 ' + this.mistakes + TG(' 次')
      : TG2('错了 {0} 次，本轮结束',Digits(String(this.mistakes), this.langCode));
    this.finish(solved);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'continuous_paired_associate',
      solved: solved,
      score: this.correct * PER_CORRECT,
      durationMs: Date.now() - this.startAt,
      levelReached: this.correct
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

        autoOn: this.autoId >= 0

      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题目'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.trial + 1, this.diffTotal) + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.correct), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.mistakes + ' / ' + MAX_MISTAKE)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      if (this.phase === 0) {
        Column({ space: Space.sm }) {
          Text(TG2("记住这 {0} 组", PAIRS_PER_ROUND)).fontSize(FontSize.md).fontColor(this.theme.inkSoft)
          ForEach(this.pairs, (p: Pair) => {
            Row({ space: Space.md }) {
              Text(p.a).fontSize(FontSize.xxl)
              Text('→').accessibilityText(TG('指向')).fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
              Text(p.b).fontSize(FontSize.xxl)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding(Space.sm)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.md)
            .shadow(Shadow.card)
          }, (p: Pair) => 'p' + p.a)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Button(TG('记住了，开始答题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width('100%')
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.phase = 1;
            this.lastMsg = TG('选出刚才和它配对的');
            this.startTrial();
          })
      } else {
        Column({ space: Space.md }) {
          Text(this.cur().a)
            .fontSize(FontSize.hero)
            .padding(Space.lg)
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.lg)
            .shadow(Shadow.card)
          Text(TG('它配的是？')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Row({ space: Space.sm }) {
          ForEach(this.options, (o: string) => {
            Text(o)
              .fontSize(FontSize.xxl)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(Cell.of(72))
              .backgroundColor(this.theme.surface)
              .borderRadius(Radius.md)
              .shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
                Haptics.tick();
                this.answer(o);
              })
          }, (o: string) => 'o' + o)
        }
        .width('100%')
      }

      Text(this.lastMsg)
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
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('错 {0} 题就结束；答满 {1} 题算通关',Digits(String(MAX_MISTAKE), this.langCode),Digits(String(this.diffTotal), this.langCode)))
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


}
