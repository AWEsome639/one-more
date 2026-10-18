/**
 * 蜘蛛纸牌（单花色版）—— 同花顺序排列
 *
 * 规则：8 副黑桃 A~K 共 104 张，10 列。可以整段搬「点数递减」的正面牌，
 *       放到比它大一点的牌上（空列放任意牌）。集齐 K→A 一整组就收走。
 * 结算：收满 8 组 ⇒ 通关；牌堆空了又无处可搬 ⇒ 失败。
 *
 * 牌编码：slot = 点数×2 + 是否正面（A=0…K=12，全黑桃所以不用存花色）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const PILES: number = 10;
const SETS: number = 8;            // 8 组 A~K
const CARDS: number = 13 * SETS;   // 104
const CARD_H: number = 26;
const STEP: number = 13;
const GAP: number = 3;
const BTN_H: number = 44;
const PILE_IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const RANKS: string[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

function isUp(slot: number): boolean {
  return slot % 2 === 1;
}

function rankOf(slot: number): number {
  return Math.floor(slot / 2);
}

@Component
export struct GSpiderSolitaire {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 SETS=8
  @State private diffTotal: number = GameDiff.sizeNow(8);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private piles: number[][] = [];
  @State private stock: number[] = [];     // 剩余待发的牌（点数）
  @State private done: number = 0;         // 已收走的整组
  @State private selP: number = -1;
  @State private selI: number = 0;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(8);
    this.reset();
  }

  private reset(): void {
    const deck: number[] = [];
    for (let i = 0; i < CARDS; i++) {
      deck.push(i % 13);
    }
    for (let i = deck.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
    const ps: number[][] = [];
    let k: number = 0;
    for (let p = 0; p < PILES; p++) {
      const n: number = p < 4 ? 6 : 5;      // 前四列 6 张，其余 5 张（共 54 张）
      const pile: number[] = [];
      for (let j = 0; j < n; j++) {
        pile.push(deck[k] * 2 + (j === n - 1 ? 1 : 0));
        k++;
      }
      ps.push(pile);
    }
    const st: number[] = [];
    while (k < CARDS) {
      st.push(deck[k]);
      k++;
    }
    this.piles = ps;
    this.stock = st;
    this.done = 0;
    this.selP = -1;
    this.selI = 0;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点正面牌选中，再点目标列放下');
    this.startAt = Date.now();
  }

  private copyPiles(): number[][] {
    const np: number[][] = [];
    for (let p = 0; p < PILES; p++) {
      np.push(this.piles[p].slice());
    }
    return np;
  }

  private pileH(p: number): number {
    const n: number = this.piles[p].length;
    return n === 0 ? CARD_H : (n - 1) * STEP + CARD_H;
  }

  private selCard(): number {
    if (this.selP >= 0 && this.selP < PILES) {
      const pile: number[] = this.piles[this.selP];
      if (this.selI >= 0 && this.selI < pile.length) {
        return pile[this.selI];
      }
    }
    return -1;
  }

  /** 一列里从 i 到末尾是不是「正面 + 点数递减」 */
  private runOk(p: number, i: number): boolean {
    const pile: number[] = this.piles[p];
    if (i < 0 || i >= pile.length) {
      return false;
    }
    for (let k = i; k < pile.length; k++) {
      if (!isUp(pile[k])) {
        return false;
      }
      if (k > i && rankOf(pile[k]) !== rankOf(pile[k - 1]) - 1) {
        return false;
      }
    }
    return true;
  }

  private canDrop(card: number, q: number): boolean {
    const pile: number[] = this.piles[q];
    if (pile.length === 0) {
      return true;
    }
    const top: number = pile[pile.length - 1];
    return isUp(top) && rankOf(top) === rankOf(card) + 1;
  }

  private tapPileCard(p: number, i: number): void {
    if (this.over) {
      return;
    }
    const pile: number[] = this.piles[p];
    const slot: number = pile[i];
    // ★★★ P16 根因：这里原来只有「选着牌 ⇒ tryMoveTo(p)」。
    //   再点一次**已经选中**的那张时，tryMoveTo 会拿它去和自己所在列比
    //   （canDrop 要求"目标列顶 = 自己的点数+1"）⇒ 必然失败 ⇒ 只弹一句「放不下」，
    //   selP 一直不清 ⇒ **选中永远取消不掉**。
    //   修法：同一张牌再点 = 开关式取消选中。
    if (this.selP === p && this.selI === i) {
      this.selP = -1;
      this.msg = TG('已取消选择');
      return;
    }
    if (this.selP >= 0) {
      const card: number = this.selCard();
      // ① 放得下 ⇒ tryMoveTo 里会直接搬过去
      if (card >= 0 && this.canDrop(card, p)) {
        this.tryMoveTo(p);
        return;
      }
      // ② 放不下，但点的这张本身能选 ⇒ 改选它（不要把人卡在上一张牌上）
      if (isUp(slot) && this.runOk(p, i)) {
        this.selP = p;
        this.selI = i;
        this.msg = TG2("选中 {0} 起 {1} 张", RANKS[rankOf(slot)], (pile.length - i));
        return;
      }
      // ③ 都不是 ⇒ 保留原来的解释性提示
      this.tryMoveTo(p);
      return;
    }
    if (!isUp(slot)) {
      if (i === pile.length - 1) {
        const np: number[][] = this.copyPiles();
        np[p][i] = slot + 1;
        this.piles = np;
        this.moves++;
        this.msg = TG2('翻开 {0}', RANKS[rankOf(slot)]);
        this.afterMove();
      } else {
        this.msg = TG('这张还盖着');
      }
      return;
    }
    if (this.runOk(p, i)) {
      this.selP = p;
      this.selI = i;
      this.msg = TG2("选中 {0} 起 {1} 张", RANKS[rankOf(slot)], (pile.length - i));
    } else {
      this.msg = TG('这一段点数不连续，搬不动');
    }
  }

  private tapPileBlank(p: number): void {
    if (this.over) {
      return;
    }
    // ★ P16：在"选中那一列"的空白处再点一下也算取消选中
    if (this.selP === p) {
      this.selP = -1;
      this.msg = TG('已取消选择');
      return;
    }
    if (this.selP >= 0) {
      this.tryMoveTo(p);
    }
  }

  private tryMoveTo(p: number): void {
    const card: number = this.selCard();
    if (card < 0) {
      this.selP = -1;
      return;
    }
    if (!this.canDrop(card, p)) {
      const pile: number[] = this.piles[p];
      const top: number = pile.length > 0 ? pile[pile.length - 1] : -1;
      this.msg = top >= 0
        ? '放不下：这列顶上是 ' + RANKS[rankOf(top)]
        : '放不下';
      return;
    }
    const np: number[][] = this.copyPiles();
    const moved: number[] = [];
    const src: number[] = np[this.selP];
    for (let i = this.selI; i < src.length; i++) {
      moved.push(src[i]);
    }
    const keep: number[] = [];
    for (let i = 0; i < this.selI; i++) {
      keep.push(src[i]);
    }
    if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
      keep[keep.length - 1] = keep[keep.length - 1] + 1;
    }
    np[this.selP] = keep;
    const dst: number[] = np[p];
    for (let i = 0; i < moved.length; i++) {
      dst.push(moved[i]);
    }
    np[p] = dst;
    this.piles = np;
    this.selP = -1;
    this.moves++;
    this.msg = TG2("搬到第 {0} 列", (p + 1));
    this.afterMove();
  }

  /** 发一轮牌：每列各一张正面牌（有空列时按规矩不能发） */
  private deal(): void {
    if (this.over) {
      return;
    }
    this.selP = -1;
    if (this.stock.length < PILES) {
      this.msg = TG('牌堆空了');
      return;
    }
    for (let p = 0; p < PILES; p++) {
      if (this.piles[p].length === 0) {
        this.msg = TG('有空列时不能发牌，先往空列搬一张');
        return;
      }
    }
    const np: number[][] = this.copyPiles();
    const st: number[] = [];
    for (let i = 0; i < this.stock.length - PILES; i++) {
      st.push(this.stock[i]);
    }
    for (let p = 0; p < PILES; p++) {
      const rank: number = this.stock[this.stock.length - PILES + p];
      np[p].push(rank * 2 + 1);
    }
    this.piles = np;
    this.stock = st;
    this.moves++;
    this.msg = TG('发了一轮牌');
    this.afterMove();
  }

  /** 收走所有已集齐的 K→A（从每列末尾 13 张看） */
  private checkComplete(): void {
    let removed: boolean = false;
    for (let p = 0; p < PILES; p++) {
      const pile: number[] = this.piles[p];
      if (pile.length < 13) {
        continue;
      }
      let ok: boolean = true;
      for (let k = 0; k < 13; k++) {
        const slot: number = pile[pile.length - 13 + k];
        if (!isUp(slot) || rankOf(slot) !== 12 - k) {
          ok = false;
          break;
        }
      }
      if (!ok) {
        continue;
      }
      const np: number[][] = this.copyPiles();
      const keep: number[] = [];
      for (let k = 0; k < np[p].length - 13; k++) {
        keep.push(np[p][k]);
      }
      if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
        keep[keep.length - 1] = keep[keep.length - 1] + 1;
      }
      np[p] = keep;
      this.piles = np;
      this.done++;
      removed = true;
    }
    if (removed) {
      this.msg = TG2('✅ 收好一组 K→A，还差 {0} 组', (this.diffTotal - this.done));
    }
  }

  private afterMove(): void {
    if (this.over) {
      return;
    }
    this.checkComplete();
    if (this.done >= this.diffTotal) {
      this.over = true;
      this.won = true;
      this.msg = TG('🎉 8 组全收齐，通关！');
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (!this.hasMove()) {
      this.over = true;
      this.won = false;
      this.msg = TG('😵 牌堆空了又无处可搬，这局走不通');
      this.finish(false);
    }
  }

  private hasMove(): boolean {
    for (let p = 0; p < PILES; p++) {
      const pile: number[] = this.piles[p];
      for (let i = 0; i < pile.length; i++) {
        if (!isUp(pile[i]) || !this.runOk(p, i)) {
          continue;
        }
        const card: number = pile[i];
        for (let q = 0; q < PILES; q++) {
          if (q !== p && this.canDrop(card, q)) {
            return true;
          }
        }
      }
    }
    if (this.stock.length >= PILES) {
      for (let p = 0; p < PILES; p++) {
        if (this.piles[p].length === 0) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'spider_solitaire',
      solved: solved,
      score: this.done * 100 + (solved ? Math.max(0, 300 - this.moves * 2) : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.done
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      Scroll() {
        Row({ space: GAP }) {
          ForEach(PILE_IDX, (p: number) => {
            this.pileView(p)
          }, (p: number) => 'p' + p)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.Top)

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        Button(TG('发牌'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.sky)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over)
          .onClick(() => {
            this.deal();
          })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')

      Text(TG('单花色（全黑桃）· 集齐 K→A 收一组 · 空列时可放任意牌'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /**
   * 顶部小格：kind 0=已收组数 1=步数 2=牌堆
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三个数整局不变。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '已收组数' : (kind === 1 ? TG('步数') : '牌堆'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.done + '/' + this.diffTotal
        : (kind === 1 ? String(this.moves) : (this.stock.length / PILES).toFixed(0) + TG(' 轮')))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  // ── 取牌（走方法：让"读状态"发生在 @Builder 闭包**内部**，才会刷新）──
  private slotAt(p: number, i: number): number {
    const pile: number[] = this.piles[p];
    return (i >= 0 && i < pile.length) ? pile[i] : -1;
  }

  /** 这张是不是"选中的那张"（★ 选中高亮以前是当参数传进来的 ⇒ 永远不刷新） */
  private isSel(p: number, i: number): boolean {
    return this.selP === p && this.selI === i;
  }

  /**
   * 一张牌：只收 (p, i) 位置，牌面与选中态都在内部读
   *
   * ★★★ P14「图片错位」：背面原来画的是字形 FACE_DOWN='✦'（FontSize.xxs），
   *   而正面是数字（FontSize.xs）—— 两个不同字体的度量/proxy 下来，
   *   真机上 ✦ 直接回落成 "?" 之类的替代字形，**和相邻列的数字上下对不齐**。
   *   ⇒ 背面改成**纯色块画的牌背**（内部一个小圆角块），不依赖任何字形度量，
   *     既不可能错位，也不会因为缺字变"?"。
   */
  @Builder
  face(p: number, i: number) {
    Stack() {
      if (this.slotAt(p, i) >= 0) {
        if (isUp(this.slotAt(p, i))) {
          Text(RANKS[rankOf(this.slotAt(p, i))])
            .fontSize(FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
        } else {
          Row()
            .width('46%')
            .height('38%')
            .backgroundColor('#FFFFFF2E')
            .borderRadius(Radius.xs)
        }
      }
    }
    .width('100%')
    .height(CARD_H)
    .backgroundColor(this.slotAt(p, i) < 0
      ? Color.Transparent
      : (isUp(this.slotAt(p, i)) ? '#FFFFFF' : Palette.teal))
    .borderRadius(Radius.xs)
    .border({
      width: this.isSel(p, i) ? 2 : 1,
      color: this.isSel(p, i) ? Palette.amber : this.theme.lineSoft
    })
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  @Builder
  pileView(p: number) {
    Stack() {
      if (this.piles[p].length === 0) {
        Row()
          .width('100%')
          .height(CARD_H)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.xs)
          .border({ width: 1, color: this.theme.lineSoft })
      }
      // ⚠️ key 带 i 与 slot：翻牌改 slot、搬运改 i，任一变了都要重建这一项
      ForEach(this.piles[p], (slot: number, i: number) => {
        this.pileCard(p, i)
      }, (slot: number, i: number) => 'c' + p + '_' + i + '_' + slot)
    }
    .layoutWeight(1)
    .height(this.pileH(p))
    .onClick(() => {
      this.tapPileBlank(p);
    })
  }

  @Builder
  pileCard(p: number, i: number) {
    Stack() {
      this.face(p, i)
    }
    .width('100%')
    .height(CARD_H)
    .position({ x: 0, y: i * STEP })
    .onClick(() => {
      this.tapPileCard(p, i);
    })
  }
}
