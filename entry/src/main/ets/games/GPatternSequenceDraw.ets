/**
 * 画规律 —— 按规律画图案
 *
 * 玩法：3×3 格子按 1~9 编号；从 1 出发，每次前进 k 格（数满 9 回到 1），
 *       按这个规律依次点格子，把整幅图案画出来。
 * 胜负：9 格全部按序点亮 ⇒ 通关；点错 3 次 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIDE: number = 3;
const COUNT: number = SIDE * SIDE;
const LIVES: number = 3;
const STEPS: number[] = [2, 4, 5, 7];   // 与 9 互质 ⇒ 一定不重复地走遍 9 格

@Component
export struct GPatternSequenceDraw {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private step: number = 2;
  @State private trail: number[] = [];
  @State private err: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = [0, 1, 2];
  private cols: number[] = [0, 1, 2];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
    this.reset();
  }

  private reset(): void {
    this.step = STEPS[Math.floor(Math.random() * STEPS.length)];
    this.trail = [];
    this.err = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG2('从 1 开始，每次 +{0}（数满 {1} 回到 1），按顺序点',Digits(String(this.step), this.langCode),Digits(String(COUNT), this.langCode));
  }

  /** 下一个该点的格子编号（1~9） */
  private want(): number {
    const cur: number = this.trail.length === 0 ? 1 : this.trail[this.trail.length - 1];
    return ((cur - 1 + this.step) % COUNT) + 1;
  }

  private tap(n: number): void {
    if (this.over) {
      return;
    }
    const need: number = this.want();
    if (n === need) {
      const t: number[] = this.trail.slice();
      t.push(n);
      this.trail = t;
      this.msg = TG2('✅ 画到 {0}', n);
      if (this.trail.length >= COUNT) {
        this.msg = TG('🎉 规律走满 9 格，图案画完了！');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.err = this.err + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.err >= this.diffTotal) {
      this.msg = TG2('❌ 点错 {0} 次，规律断了',Digits(String(this.diffTotal), this.langCode));
      this.finish(false);
      return;
    }
    this.msg = TG2('❌ 这一笔该点 {0}', need);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'pattern_sequence_draw',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.err * 200) : this.trail.length * 100,
      durationMs: Date.now() - this.startAt,
      levelReached: this.trail.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private rank(n: number): number {
    return this.trail.indexOf(n);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('规律'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((TG2('每次 +{0}',Digits(String(this.step), this.langCode)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.trail.length + '/' + COUNT)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.err + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (c: number) => {
              Stack() {
              Column({ space: 2 }) {
              Text(String((r * SIDE + c + 1))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.rank((r * SIDE + c + 1)) >= 0 ? '#FFFFFF' : this.theme.ink)
              Text(this.rank((r * SIDE + c + 1)) >= 0 ? '第' + (this.rank((r * SIDE + c + 1)) + 1) + '笔' : '').fontSize(FontSize.xxs).fontColor('#FFFFFF')
              }
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.rank((r * SIDE + c + 1)) >= 0 ? Palette.rose : this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              this.tap((r * SIDE + c + 1));
              })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').layoutWeight(1)

      Text(this.over ? this.msg : ('下一笔该点 ' + this.want() + ' —— ' + this.msg)).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.rose).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          this.reset();
        })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
