/**
 * 计数广度 —— 边数边记：数完每张卡的黄点数，再按顺序回忆
 * 胜负：全对且张数到 5 通关，2 条命用完判负　｜　进度：张数 / 最长 / 生命
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const DOTS: number = 9;
const MAX_COUNT: number = 5;
const START_SPAN: number = 2;
const WIN_SPAN: number = 5;
const LIVES: number = 2;
const PER_CARD: number = 100;

@Component
export struct GCountingSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：DOTS 按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(DOTS);
  onFinish: (r: GameResult) => void = () => {};

  @State counts: number[] = [];
  @State dots: boolean[] = [];
  @State cardIdx: number = 0;
  @State recallIdx: number = 0;
  @State span: number = START_SPAN;
  @State best: number = 0;
  @State life: number = LIVES;
  @State phase: number = 0;      // 0=数卡 1=回忆 2=结束
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(DOTS);
     this.reset(); }

  private reset(): void {
    this.span = START_SPAN; this.best = 0; this.life = LIVES;
    this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now();
    this.startRound();
  }

  private startRound(): void {
    const cs: number[] = [];
    for (let i = 0; i < this.span; i++) { cs.push(1 + Math.floor(Math.random() * MAX_COUNT)); }
    this.counts = cs;
    this.cardIdx = 0;
    this.recallIdx = 0;
    this.phase = 0;
    this.msg = TG('数出每张卡有几个黄点，别写下来');
    this.deal();
  }

  /** 当前卡上随机铺 n 个黄点（n = 该卡真实计数） */
  private deal(): void {
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) { pool.push(i); }
    for (let k = pool.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: number = pool[k];
      pool[k] = pool[j];
      pool[j] = tmp;
    }
    const cells: boolean[] = [];
    for (let i = 0; i < this.diffTotal; i++) { cells.push(false); }
    const n: number = this.counts[this.cardIdx];
    for (let i = 0; i < n; i++) { cells[pool[i]] = true; }
    this.dots = cells;
  }

  private nextCard(): void {
    if (this.phase !== 0 || this.over) { return; }
    if (this.cardIdx + 1 < this.span) {
      this.cardIdx++;
      this.deal();
      return;
    }
    this.phase = 1;
    this.recallIdx = 0;
    this.msg = TG2('第 1 / {0} 张有几个黄点？', this.span);
  }

  private answerCount(k: number): void {
    if (this.phase !== 1 || this.over) { return; }
    const truth: number = this.counts[this.recallIdx];
    if (k === truth) {
      this.recallIdx++;
      if (this.recallIdx >= this.span) {
        this.best = this.span;
        if (this.best >= WIN_SPAN) { this.end(true); return; }
        this.span++;
        this.msg = TG2('✅ 全对！张数升到 {0}', this.span);
        this.startRound();
        return;
      }
      this.msg = TG2("✅ 第 {0} / {1} 张有几个黄点？", (this.recallIdx + 1), this.span);
      return;
    }
    this.life--;
    if (this.life <= 0) { this.end(false); return; }
    this.msg = TG2("❌ 那一张是 {0} 个，还剩 {1} 条命", truth,Digits(String(this.life), this.langCode));
    this.startRound();
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.phase = 2;
    this.msg = TG2("{0}{1} 张", (solved ? '🎉 通关：一口气记住 ' : '最长记住 '), this.best);
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'counting_span', solved: solved, score: this.best * PER_CARD,
      durationMs: Date.now() - this.startAt, levelReached: this.best
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('张数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('最长'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.best), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.life + ' / ' + LIVES)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Text('●').accessibilityLevel('no').fontSize(FontSize.xl)
              .fontColor(this.dots.length > (r * 3 + c) && this.dots[(r * 3 + c)] ? Palette.amber : this.theme.lineSoft)
              }.layoutWeight(1).aspectRatio(1)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.md)
        .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      if (this.phase === 0) {
        Button(TG2('数好了，下一张（{0} / {1}）', (this.cardIdx + 1), this.span))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.amber)
          .borderRadius(Radius.md).width('100%').height(Cell.of(48))
          .onClick(() => { Haptics.tap(); this.nextCard(); })
      } else {
        Row({ space: Space.xs }) {
          ForEach([1, 2, 3, 4, 5], (k: number) => {
            Button(String((k)))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.lg).fontColor('#FFFFFF').backgroundColor(Palette.primary)
            .borderRadius(Radius.sm).layoutWeight(1).height(Cell.of(52)).enabled(this.phase === 1)
            .onClick(() => { Haptics.tap(); this.answerCount((k)); })
          }, (k: number) => 'n' + k)
        }.width('100%')
      }

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2('张数升到 {0} 即通关；黄点 1~5 个不等',Digits(String(WIN_SPAN), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
