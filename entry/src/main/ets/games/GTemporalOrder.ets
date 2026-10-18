/**
 * 时间顺序 —— 把打乱的 4 件事按"发生先后"依次点出来
 * 胜负：5 题答对 ≥ 4 ⇒ 通关　｜　进度：题号 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

interface Ev { e: string; t: string; }

const ROUNDS: number = 5; const PASS: number = 4; const FEED_MS: number = 1100;

const SETS: Ev[][] = [
  [{ e: '🌱', t: '播种' }, { e: '🌿', t: '发芽' }, { e: '🌸', t: '开花' }, { e: '🍎', t: '结果' }],
  [{ e: '🥚', t: '下蛋' }, { e: '🐣', t: '破壳' }, { e: '🐥', t: '雏鸟' }, { e: '🐔', t: '成鸡' }],
  [{ e: '🧊', t: '冰块' }, { e: '💧', t: '化成水' }, { e: '♨️', t: '烧成汽' }, { e: '☁️', t: '聚成云' }],
  [{ e: '🌰', t: '种子' }, { e: '🌳', t: '长成树' }, { e: '🪵', t: '伐成木' }, { e: '🪑', t: '做成椅' }],
  [{ e: '🍇', t: '采摘' }, { e: '🧺', t: '装筐' }, { e: '🍷', t: '压榨' }, { e: '🍾', t: '装瓶' }],
  [{ e: '📄', t: '写草稿' }, { e: '✏️', t: '反复改' }, { e: '🖨️', t: '打印' }, { e: '📮', t: '寄出去' }]
];

@Component
export struct GTemporalOrder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State opts: Ev[] = []; @State orig: number[] = []; @State picked: number[] = []; @State plan: number[] = [];
  @State round: number = 1; @State hits: number = 0; @State score: number = 0;
  @State locked: boolean = false; @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll();
    const pl: number[] = [0, 1, 2, 3, 4, 5];
    for (let i = pl.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pl[i]; pl[i] = pl[j]; pl[j] = t;
    }
    this.plan = pl; this.round = 1; this.hits = 0; this.score = 0; this.locked = false;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.loadRound();
  }

  private loadRound(): void {
    const set: Ev[] = SETS[this.plan[this.round - 1]];
    const order: number[] = [0, 1, 2, 3];
    for (let i = 3; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    const shown: Ev[] = [];
    for (let i = 0; i < order.length; i++) { shown.push(set[order[i]]); }
    this.opts = shown; this.orig = order; this.picked = []; this.locked = false;
    this.msg = TG2("第 {0} / {1} 题：按发生先后依次点",Digits(String(this.round), this.langCode),Digits(String(this.diffTotal), this.langCode));
  }

  private tap(i: number): void {
    if (this.over || this.locked) { return; }
    const p: number[] = this.picked.slice();
    const hit: number = p.indexOf(i);
    if (hit >= 0) { p.splice(hit, 1); this.picked = p; return; }
    if (p.length >= 4) { return; }
    p.push(i); this.picked = p;
    if (p.length === 4) { this.judge(p); }
  }

  private judge(p: number[]): void {
    this.locked = true;
    let ok: boolean = true;
    for (let k = 0; k < p.length; k++) { if (this.orig[p[k]] !== k) { ok = false; } }
    if (ok) { this.hits = this.hits + 1; this.score = this.score + 15; this.msg = TG('✅ 顺序完全正确'); } else { this.msg = '❌ 正确顺序：' + this.answerText(); }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private answerText(): string {
    let s: string = '';
    for (let k = 0; k < 4; k++) {
      for (let j = 0; j < this.orig.length; j++) {
        if (this.orig[j] === k) { s = s + this.opts[j].e; }
      }
    }
    return s;
  }
  private next(): void {
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.hits, this.diffTotal);
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.loadRound();
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'temporal_order', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  private badge(i: number): string {
    const hit: number = this.picked.indexOf(i);
    return hit >= 0 ? String(hit + 1) : '·';
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Row({ space: Space.md }) {
          Text(this.badge((i))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .textAlign(TextAlign.Center).width(32).height(Cell.of(32))
          .backgroundColor(this.badge((i)) === '·' ? this.theme.lineSoft : Palette.primary).borderRadius(Radius.full)
          Text(this.opts[(i)].e).fontSize(FontSize.xxl)
          Text(this.opts[(i)].t).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
          Text(this.picked.indexOf((i)) >= 0 ? TG('第 ') + this.badge((i)) + TG(' 步') : '')
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          }.width('100%').height(Cell.of(62)).padding(Space.sm)
          .backgroundColor(this.picked.indexOf((i)) >= 0 ? '#336366F1' : this.theme.surface)
          .borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
          .onClick(() => { this.tap((i)); })
        }, (i: number) => 'o' + i)
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG('点错了再点一下即可取消；四件点满才判定')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
