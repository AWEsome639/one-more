/** 分数配对 —— 匹配等值分数（翻牌记忆）；玩法：8 张牌两两成对，一对是等值的两个分数；每次翻两张；胜负：60 秒内配齐 4 对 ⇒ 通关；超时 ⇒ 失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';

const PAIRS: number = 4; const CARD: number = 8; const LIMIT: number = 60; const HIDE_MS: number = 700;
/** 8 个互不相等的基准分数：分子 / 分母 */
const BASE_N: number[] = [1, 1, 2, 1, 3, 2, 3, 5]; const BASE_D: number[] = [2, 3, 3, 4, 4, 5, 5, 6];
const ROWS: number[] = [0, 1]; const COLS: number[] = [0, 1, 2, 3];
@Component
export struct GFractionMatch {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  @State private labels: string[] = [];
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private keys: string[] = [];
  @State private open: number[] = [];
  @State private done: boolean[] = [];
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private matched: number = 0;
  @State private tries: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private tick: number = -1; private hideTo: number = -1;
  private finished: boolean = false; private pool: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
  }
  private reset(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); this.hideTo = -1; }
    this.left = this.total; this.matched = 0; this.tries = 0; this.score = 0;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now(); this.deal(); this.msg = TG('翻两张：值相等的分数即为一对');
    this.tick = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) {
        this.left = 0;
        if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
        if (!this.over) {
          this.over = true; this.won = false;
          this.msg = TG2('⏰ 时间到，只配了 {0}/{1} 对', String(this.matched), String(PAIRS)); this.finish(false);
        }
      }
    }, 1000);
  }
  /** 发牌：每对给「约分前」与「约分后」各一张，打乱 */
  private deal(): void {
    const pickPool: number[] = this.pool.slice(); const order: number[] = [];
    for (let t = 0; t < PAIRS; t++) {
      const at: number = Math.floor(Math.random() * pickPool.length); const bi: number = pickPool[at];
      pickPool.splice(at, 1); order.push(bi); order.push(bi);
    }
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    const labels: string[] = []; const keys: string[] = []; const seen: number[] = new Array<number>(PAIRS).fill(0);
    for (let i = 0; i < order.length; i++) {
      const bi: number = order[i]; const mult: number = seen[bi] === 0 ? (Math.random() < 0.5 ? 2 : 3) : 1;
      seen[bi] = seen[bi] + 1; labels.push(String(BASE_N[bi] * mult) + '/' + String(BASE_D[bi] * mult)); keys.push(String(bi));
    }
    this.labels = labels; this.keys = keys; this.open = []; this.done = new Array<boolean>(CARD).fill(false);
  }
  private flip(i: number): void {
    if (this.over || this.done[i] || this.open.indexOf(i) >= 0 || this.open.length >= 2) { return; }
    const cur: number[] = this.open.concat([i]); this.open = cur;
    if (cur.length < 2) { return; }
    this.tries = this.tries + 1;
    if (this.keys[cur[0]] === this.keys[cur[1]]) {
      const nd: boolean[] = this.done.slice(); nd[cur[0]] = true; nd[cur[1]] = true; this.done = nd; this.open = [];
      this.matched = this.matched + 1; this.score += 150;
      if (this.matched >= PAIRS) {
        this.over = true; this.won = true; this.msg = TG2("🎉 4 对全配齐，共翻 {0} 次",Digits(String(this.tries), this.langCode)); this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
      }
      this.msg = TG2('✅ 等值！还剩 {0} 对', String(PAIRS - this.matched)); return;
    }
    this.score = Math.max(0, this.score - 10); this.msg = TG('❌ 不等值，记好位置再来');
    if (this.hideTo >= 0) { clearTimeout(this.hideTo); }
    this.hideTo = setTimeout(() => { this.hideTo = -1; this.open = []; }, HIDE_MS);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
    const r: GameResult = {
      gameId: 'fraction_match', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.matched
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private face(i: number): string {
    if (this.done[i] || this.open.indexOf(i) >= 0) { return this.labels[i]; }
    return '?';
  }
  private cardBg(i: number): string {
    if (this.done[i]) { return Palette.emerald; }
    if (this.open.indexOf(i) >= 0) { return Palette.violet; }
    return this.theme.surface;
  }
  private cardInk(i: number): string {
    if (this.done[i] || this.open.indexOf(i) >= 0) { return '#FFFFFF'; }
    return this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('配对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.matched + '/' + PAIRS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('翻牌'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.tries), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach(ROWS, (row: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (col: number) => {
              Stack() {
              Text(this.face((row * 4 + col))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.cardInk((row * 4 + col)))
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cardBg((row * 4 + col))).borderRadius(Radius.md).shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { this.flip((row * 4 + col)); })
            }, (col: number) => 'fmc' + col)
          }.width('100%')
        }, (row: number) => 'fmr' + row)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('提示：2/4 与 1/2 等值 —— 同乘（同除）同一个数，分数大小不变')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
