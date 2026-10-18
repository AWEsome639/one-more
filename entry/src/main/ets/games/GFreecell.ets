/**
 * 空当接龙（迷你版）—— 四列自由搬运 🐉
 *
 * 规则：两门花色各 A~8 共 16 张；右上角「家」按 A→8 收牌，
 *      列内只能压「刚好小一点」的牌（♠黑 ♥红 天然交替），4 个自由格可各存 1 张。
 * 胜负：两门全部归位 = 通关；再也走不动 = 失败
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const COLS: number = 4;
const FREES: number = 4;
const TOP: number = 8;

interface Card {
  suit: number;   // 0 = ♠，1 = ♥
  rank: number;   // 1..8，0 表示空位
}

function isBlank(c: Card): boolean {
  return c.rank === 0;
}

function suitChar(s: number): string {
  return s === 0 ? '♠' : '♥';
}

@Component
export struct GFreecell {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 COLS=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private cols: Card[][] = [];
  @State private frees: Card[] = [];
  @State private found: number[] = [0, 0];
  @State private moves: number = 0;
  @State private sel: number = -1;    // -1 无；0..3 自由格；10..13 列
  @State private over: boolean = false;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private blank(): Card {
    return { suit: 0, rank: 0 };
  }

  private reset(): void {
    const deck: Card[] = [];
    for (let s = 0; s < 2; s++) {
      for (let r = 1; r <= TOP; r++) {
        deck.push({ suit: s, rank: r });
      }
    }
    for (let i = deck.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: Card = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
    const cs: Card[][] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      cs.push([]);
    }
    for (let i = 0; i < deck.length; i++) {
      cs[i % this.diffTotal].push(deck[i]);
    }
    const fs: Card[] = [];
    for (let i = 0; i < FREES; i++) {
      fs.push(this.blank());
    }
    this.cols = cs;
    this.frees = fs;
    this.found = [0, 0];
    this.moves = 0;
    this.sel = -1;
    this.over = false;
    this.startAt = Date.now();
  }

  /** 取某个来源最上面的牌：0..3 自由格 / 10..13 列 */
  private cardAt(src: number): Card {
    if (src < 10) {
      return this.frees[src];
    }
    const col: Card[] = this.cols[src - 10];
    return col.length > 0 ? col[col.length - 1] : this.blank();
  }

  private freeUsed(): number {
    let n: number = 0;
    for (let i = 0; i < FREES; i++) {
      if (!isBlank(this.frees[i])) {
        n++;
      }
    }
    return n;
  }

  /** kind: 0=自由格 1=家 2=列 */
  private applyMove(src: number, kind: number, idx: number): boolean {
    if (this.over) {
      return false;
    }
    const card: Card = this.cardAt(src);
    if (isBlank(card)) {
      return false;
    }
    if (kind === 1 && this.found[card.suit] + 1 !== card.rank) {
      return false;
    }
    if (kind === 2) {
      const d: Card[] = this.cols[idx];
      if (d.length > 0 && d[d.length - 1].rank !== card.rank + 1) {
        return false;
      }
    }

    const nc: Card[][] = this.cols.map((x: Card[]) => x.slice());
    const nf: Card[] = this.frees.slice();
    if (src < 10) {
      nf[src] = this.blank();
    } else {
      nc[src - 10].pop();
    }
    if (kind === 0) {
      nf[idx] = card;
    } else if (kind === 1) {
      const nf2: number[] = this.found.slice();
      nf2[card.suit] = card.rank;
      this.found = nf2;
    } else {
      nc[idx].push(card);
    }
    this.cols = nc;
    this.frees = nf;
    this.moves = this.moves + 1;
    this.sel = -1;
    this.check();
    return true;
  }

  private check(): void {
    if (this.found[0] === TOP && this.found[1] === TOP) {
      this.over = true;
      this.finish(true);
      return;
    }
    if (!this.hasMove()) {
      this.over = true;
      this.finish(false);
    }
  }

  /** 还有没有「有意义」的一步 */
  private hasMove(): boolean {
    for (let i = 0; i < FREES; i++) {
      const c: Card = this.frees[i];
      if (isBlank(c)) {
        return true;
      }
      if (this.found[c.suit] + 1 === c.rank) {
        return true;
      }
    }
    for (let i = 0; i < this.diffTotal; i++) {
      const col: Card[] = this.cols[i];
      if (col.length === 0) {
        continue;
      }
      const t: Card = col[col.length - 1];
      if (this.found[t.suit] + 1 === t.rank) {
        return true;
      }
      for (let j = 0; j < this.diffTotal; j++) {
        if (i === j) {
          continue;
        }
        const d: Card[] = this.cols[j];
        if (d.length === 0 || d[d.length - 1].rank === t.rank + 1) {
          return true;
        }
      }
    }
    return false;
  }

  private tapFree(i: number): void {
    if (this.over) {
      return;
    }
    const c: Card = this.frees[i];
    if (this.sel === -1) {
      if (!isBlank(c)) {
        this.sel = i;
      }
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    if (isBlank(c)) {
      this.applyMove(this.sel, 0, i);
    } else {
      this.sel = i;
    }
  }

  private tapCol(i: number): void {
    if (this.over) {
      return;
    }
    if (this.sel === -1) {
      if (this.cols[i].length > 0) {
        this.sel = 10 + i;
      }
      return;
    }
    if (this.sel === 10 + i) {
      this.sel = -1;
      return;
    }
    if (!this.applyMove(this.sel, 2, i)) {
      // 放不下就顺手改选这一列最上面的牌
      this.sel = this.cols[i].length > 0 ? 10 + i : -1;
    }
  }

  private tapFound(s: number): void {
    if (this.over || this.sel === -1) {
      return;
    }
    this.applyMove(this.sel, 1, s);
  }

  /** 能归位的全部自动归位 */
  private autoHome(): void {
    let moved: boolean = true;
    while (moved) {
      moved = false;
      for (let i = 0; i < FREES; i++) {
        const c: Card = this.frees[i];
        if (!isBlank(c) && this.found[c.suit] + 1 === c.rank) {
          moved = this.applyMove(i, 1, c.suit);
          break;
        }
      }
      if (moved) {
        continue;
      }
      for (let i = 0; i < this.diffTotal; i++) {
        const col: Card[] = this.cols[i];
        if (col.length > 0) {
          const c: Card = col[col.length - 1];
          if (this.found[c.suit] + 1 === c.rank) {
            moved = this.applyMove(10 + i, 1, c.suit);
            break;
          }
        }
      }
    }
  }

  private finish(solved: boolean): void {
    const placed: number = this.found[0] + this.found[1];
    const r: GameResult = {
      gameId: 'freecell',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 5) : placed * 20,
      durationMs: Date.now() - this.startAt,
      levelReached: placed
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已归位'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.found[0] + this.found[1]) + '/16')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('自由格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.freeUsed()) + '/4')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      // 4 个自由格 + 2 个家
      Row({ space: Space.xs }) {
        ForEach(this.rowIdx(), (i: number) => {
          Stack() {
          Text(isBlank(this.frees[(i)]) ? '＋'
          : suitChar(this.frees[(i)].suit) + String(this.frees[(i)].rank))
          .fontSize(FontSize.md)
          .fontWeight(FontWeight.Bold)
          .fontColor(isBlank(this.frees[(i)]) ? this.theme.inkFaint
          : (this.frees[(i)].suit === 0 ? this.theme.ink : Palette.rose))
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.sel === (i) ? '#226366F1' : this.theme.surfaceAlt)
          .borderRadius(Radius.sm)
          .border({ width: 1, color: this.sel === (i) ? Palette.primary : this.theme.line })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          this.tapFree((i));
          })
        }, (i: number) => 'f' + i)
        ForEach([0, 1], (s: number) => {
          Stack() {
          Text(suitChar((s)) + ' ' + String(this.found[(s)]) + '/' + String(TOP))
          .fontSize(FontSize.xs)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.found[(s)] === TOP ? Palette.emerald : this.theme.inkSoft)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .border({ width: 1, color: this.found[(s)] === TOP ? Palette.emerald : this.theme.line })
          .onClick(() => {
          this.tapFound((s));
          })
        }, (s: number) => 'h' + s)
      }
      .width('100%')

      // 4 列
      Row({ space: Space.xs }) {
        ForEach(this.rowIdx(), (i: number) => {
          Column({ space: 2 }) {
          ForEach(this.cols[(i)].slice().reverse(), (c: Card, k: number) => {
          Row() {
          Text(suitChar((c).suit) + String((c).rank))
          .fontSize(FontSize.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor((c).suit === 0 ? this.theme.ink : Palette.rose)
          }
          .width('100%')
          .height(Cell.of(30))
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.xs)
          .border({ width: 1, color: (k) === 0 ? Palette.primary : this.theme.line })
          .shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (c: Card, k: number) => 'k' + (i) + '-' + k + '-' + c.suit + '-' + c.rank)
          }
          .layoutWeight(1)
          .height('100%')
          .padding(2)
          .backgroundColor(this.sel === 10 + (i) ? '#146366F1' : '#00000000')
          .borderRadius(Radius.sm)
          .justifyContent(FlexAlign.End)
          .onClick(() => {
          this.tapCol((i));
          })
        }, (i: number) => 'c' + i)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.over ? (this.found[0] === TOP ? '🎉 全部归位，通关！' : '走不动了…重开一局') :
        (this.sel === -1 ? '点一张牌选中，再点目标位置' : '已选中，点自由格 / 家 / 列放下'))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? Palette.emerald : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.primary).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .onClick(() => {
            this.reset();
          })
        Button(TG('自动归位'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .onClick(() => {
            this.autoHome();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }










}
