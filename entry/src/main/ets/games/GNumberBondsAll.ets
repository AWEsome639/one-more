/**
 * 数字拆分 —— 拆数练习
 *
 * 玩法：目标数 n，棋盘上每个 1..n 各出现两次；每次点两块，点中两块之和 = n
 *       即拆出一组（两块随即作废），把所有拆法找齐。
 * 胜负：拆齐 ⌊n/2⌋ 组 ⇒ 通关；点错 3 次 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const COLS: number = 4;
const LIVES: number = 3;

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GNumberBondsAll {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private tiles: number[] = [];
  @State private used: boolean[] = [];
  @State private target: number = 0;
  @State private sel: number = -1;
  @State private found: string[] = [];
  @State private err: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private rows: number[] = [];
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private cols: number[] = [0, 1, 2, 3];

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
    const t: number = randInt(6, 12);
    const bag: number[] = [];
    for (let i = 1; i <= t; i++) {
      bag.push(i);
      bag.push(i);
    }
    for (let i = bag.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = bag[i];
      bag[i] = bag[j];
      bag[j] = tmp;
    }
    this.target = t;
    this.tiles = bag;
    this.used = new Array<boolean>(bag.length).fill(false);
    this.sel = -1;
    this.found = [];
    this.err = 0;
    const r: number[] = [];
    for (let i = 0; i < Math.ceil(bag.length / COLS); i++) {
      r.push(i);
    }
    this.rows = r;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG2('点两块，凑出 {0}（每个数各两块，用完就不能再点）', t);
  }

  private total(): number {
    return Math.floor(this.target / 2);
  }

  private tap(i: number): void {
    if (this.over || this.used[i]) {
      return;
    }
    if (this.sel < 0) {
      this.sel = i;
      this.msg = TG2("选中 {0}，再点一块凑 {1}", this.tiles[i], this.target);
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      this.msg = TG('取消选择');
      return;
    }
    const a: number = this.tiles[this.sel];
    const b: number = this.tiles[i];
    if (a + b === this.target) {
      const nextUsed: boolean[] = this.used.slice();
      nextUsed[this.sel] = true;
      nextUsed[i] = true;
      this.used = nextUsed;
      const lo: number = a < b ? a : b;
      const hi: number = a < b ? b : a;
      const list: string[] = this.found.slice();
      list.push(lo + '+' + hi);
      this.found = list;
      this.sel = -1;
      this.msg = '✅ ' + lo + ' + ' + hi + ' = ' + this.target;
      if (this.found.length >= this.total()) {
        this.msg = TG2('🎉 {0} 的 {1} 种拆法全找齐！', this.target, this.total());
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.sel = -1;
    this.err = this.err + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.err >= this.diffTotal) {
      this.msg = TG2('❌ 点错 {0} 次，休息一下',Digits(String(this.diffTotal), this.langCode));
      this.finish(false);
      return;
    }
    this.msg = '❌ ' + a + ' + ' + b + ' = ' + (a + b) + '，不是 ' + this.target;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'number_bonds_all',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.err * 200) : this.found.length * 150,
      durationMs: Date.now() - this.startAt,
      levelReached: this.found.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.target), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已拆'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found.length + '/' + this.total())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              if ((r * COLS + c) < this.tiles.length) {
              Text(String(this.tiles[(r * COLS + c)])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.used[(r * COLS + c)] ? this.theme.inkFaint : (this.sel === (r * COLS + c) ? '#FFFFFF' : this.theme.ink)).animation({ duration: Motion.fast, curve: Motion.snap() })
              }
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.used[(r * COLS + c)] ? this.theme.surfaceAlt
              : (this.sel === (r * COLS + c) ? Palette.violet : this.theme.surface)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              if ((r * COLS + c) < this.tiles.length) {
              this.tap((r * COLS + c));
              }
              })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').layoutWeight(1)

      Text(this.found.length > 0 ? '已拆出：' + this.found.join('  ') : '还没拆出任何一组').fontSize(FontSize.xs).fontColor(Palette.violet).width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.violet).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          this.reset();
        })
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
