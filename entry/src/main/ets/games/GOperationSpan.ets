/**
 * 运算广度 —— 一组小题按顺序算，算完记住结果，题目全部结束后按原顺序回忆这些结果
 * 胜负：组长度 2 → 3 → 4 全部走通 ⇒ 通关；算错或回忆错顺序 ⇒ 失败
 * 进度：组长度 / 已记住 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const START_SPAN: number = 2;
const MAX_SPAN: number = 4;
const OPT_N: number = 4;
const OPT_IDX: number[] = [0, 1, 2, 3];
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1, 2];

@Component
export struct GOperationSpan {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 START_SPAN=2，按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(2);
  onFinish: (r: GameResult) => void = () => {};
  @State phase: number = 0;        // 0 算式　1 回忆　2 结算
  @State span: number = this.diffTotal; @State pos: number = 0; @State got: number = 0;
  @State lhs: number = 0; @State rhs: number = 0; @State opSym: string = '+'; @State ans: number = 0;
  @State opts: number[] = []; @State stored: number[] = []; @State pool: string[] = [];
  @State score: number = 0; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(2);
     this.reset(); }

  private shuffleNums(src: number[]): number[] {
    const out: number[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  private shuffleStrs(src: string[]): string[] {
    const out: string[] = src.slice();
    for (let i = out.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  private reset(): void {
    this.span = this.diffTotal; this.score = 0; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newSet();
  }

  private newSet(): void {
    this.stored = []; this.pos = 0; this.got = 0; this.pool = []; this.phase = 0;
    this.makeProblem();
    this.msg = TG2('本轮 {0} 个算式：先算对，最后一起回忆结果', this.span);
  }

  /** 出题，且结果不与本组已记住的重复（避免回忆时歧义） */
  private makeProblem(): void {
    let a: number = 0; let b: number = 0; let res: number = 0; let plus: boolean = true; let guard: number = 0;
    while (guard < 80) {
      a = 2 + Math.floor(Math.random() * 8); b = 2 + Math.floor(Math.random() * 8);
      plus = Math.random() < 0.5;
      res = plus ? a + b : Math.abs(a - b);
      if (res > 0 && this.stored.indexOf(res) < 0) { break; }
      guard = guard + 1;
    }
    const cand: number[] = [res + 1, res - 1, res + 2, res - 2, res + 3];
    const opts: number[] = [res];
    for (let i = 0; i < cand.length && opts.length < OPT_N; i++) {
      const v: number = cand[i];
      if (v > 0 && opts.indexOf(v) < 0) { opts.push(v); }
    }
    this.lhs = a; this.rhs = b; this.ans = res; this.opSym = plus ? '+' : '-';
    this.opts = this.shuffleNums(opts);
  }

  private pickOpt(v: number): void {
    if (this.phase !== 0) { return; }
    if (v !== this.ans) {
      this.end(false, '❌ 算错了：' + this.lhs + ' ' + this.opSym + ' ' + this.rhs + ' = ' + this.ans);
      return;
    }
    this.stored = this.stored.concat([this.ans]);
    this.score = this.score + 30; this.pos = this.pos + 1;
    if (this.pos >= this.span) { this.beginRecall(); return; }
    this.makeProblem();
    this.msg = TG2('存下第 {0} 个结果，继续算', this.pos);
  }

  private beginRecall(): void {
    this.phase = 1; this.got = 0;
    const pool: string[] = [];
    for (let i = 0; i < this.stored.length; i++) { pool.push(String(this.stored[i])); }
    let extra: number = 0; let guard: number = 0;
    while (extra < 2 && guard < 80) {
      const decoy: number = 2 + Math.floor(Math.random() * 16);
      if (this.stored.indexOf(decoy) < 0) { pool.push(String(decoy)); extra = extra + 1; }
      guard = guard + 1;
    }
    this.pool = this.shuffleStrs(pool);
    this.msg = TG('算式做完了，按顺序点出这些结果');
  }

  private pickPool(i: number): void {
    if (this.phase !== 1 || this.pool[i] === '✔') { return; }
    const want: number = this.stored[this.got];
    if (this.pool[i] !== String(want)) {
      this.end(false, TG('❌ 第 ') + (this.got + 1) + ' 个结果应该是 ' + want);
      return;
    }
    const next: string[] = this.pool.slice();
    next[i] = '✔'; this.pool = next;
    this.got = this.got + 1; this.score = this.score + 40;
    if (this.got >= this.stored.length) {
      if (this.span >= MAX_SPAN) { this.end(true, TG2('✅ {0} 个结果按顺序全对', MAX_SPAN)); return; }
      this.span = this.span + 1; this.newSet();
      return;
    }
    this.msg = TG2("对，继续点第 {0} 个", (this.got + 1));
  }

  private end(solved: boolean, note: string): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true; this.won = solved; this.phase = 2;
    this.msg = note + (solved ? '　🎉 通关' : '　💤 结束');
    const r: GameResult = { gameId: 'operation_span', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.span };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('组长度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.span), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.orange))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('已记住'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.stored.length + ' / ' + this.span)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Stack() {
        if (this.phase === 0) {
          Column({ space: Space.xs }) {
            Text(TG('算出来并记住结果')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint); Text(this.lhs + ' ' + this.opSym + ' ' + this.rhs + ' = ?').fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
          }

              // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        } else if (this.phase === 1) {
          Column({ space: Space.xs }) {
            Text(TG('按顺序回忆')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
            Text(TG2("第 {0} 个结果是几？", (this.got + 1))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
          }

              // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        } else {
          Text(this.won ? '🎉' : '🏁').fontSize(FontSize.hero)
          // ★ 2026-10-14 动效：阶段切换时淡入 + 缩放（原来是硬切）
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
                .animation({ duration: Motion.fast, curve: Motion.spring() }))
        }
      }.width('100%').height(130).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      if (this.phase === 0) {
        Row({ space: Space.sm }) {
          ForEach(OPT_IDX, (i: number) => { Button(String(this.opts.length > (i) ? this.opts[(i)] : 0))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(Palette.orange)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(56)).enabled(this.phase === 0).onClick(() => { Haptics.tap(); this.pickOpt(this.opts[(i)]); }) }, (i: number) => 'os' + i)
        }.width('100%')
      } else if (this.phase === 1) {
        Column({ space: Space.sm }) {
          ForEach(ROWS, (row: number) => {
            Row({ space: Space.sm }) {
              ForEach(COLS, (col: number) => {
                if (row * 3 + col < this.pool.length) { Button(this.pool[(row * 3 + col)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor('#FFFFFF').backgroundColor(this.pool[(row * 3 + col)] === '✔' ? Palette.lime : Palette.teal)
                .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(this.pool[(row * 3 + col)] !== '✔').onClick(() => { Haptics.tap(); this.pickPool((row * 3 + col)); }) }
              }, (col: number) => 'pc' + row + '_' + col)
            }.width('100%')
          }, (row: number) => 'pr' + row)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：算对不算完 —— 题目全部结束后还要按顺序回忆结果')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
