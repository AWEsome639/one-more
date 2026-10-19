/**
 * 接龙（Klondike Solitaire）—— 经典纸牌接龙
 *
 * 规则：7 列牌堆按「颜色相反、点数递减」叠放，空列只放 K；
 *       右上 4 个基础堆按花色从 A 收到 K。牌堆翻 1 张，最多洗 3 遍。
 * 结算：52 张全进基础堆 ⇒ 通关；没牌可翻又无处可放 ⇒ 失败。
 *
 * 牌编码：cardId = 花色×13 + 点数（A=0…K=12）；slot = cardId×2 + 是否正面。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const PILES: number = 7;
const CARD_H: number = 30;
const STEP: number = 16;          // 叠放时每张露出的高度
const GAP: number = 4;
const MAX_PASS: number = 3;       // 最多洗几遍牌
const BTN_H: number = 44;
const PILE_IDX: number[] = [0, 1, 2, 3, 4, 5, 6];
const FOUND_IDX: number[] = [0, 1, 2, 3];
const SUITS: string[] = ['♠', '♥', '♦', '♣'];
const RANKS: string[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
const RED_INK: string = '#D92D20';
const DARK_INK: string = '#0F172A';

function cardId(slot: number): number {
  return Math.floor(slot / 2);
}

function isUp(slot: number): boolean {
  return slot % 2 === 1;
}

function rankOf(slot: number): number {
  return cardId(slot) % 13;
}

function suitOf(slot: number): number {
  return Math.floor(cardId(slot) / 13);
}

function redOf(slot: number): boolean {
  const s: number = suitOf(slot);
  return s === 1 || s === 2;
}

function labelOf(slot: number): string {
  return RANKS[rankOf(slot)] + SUITS[suitOf(slot)];
}

@Component
export struct GSolitaire {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 GAP=4）
  @State private diffTotal: number = GameDiff.sizeNow(4);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private piles: number[][] = [];
  @State private stock: number[] = [];
  @State private waste: number[] = [];
  @State private founds: number[] = [0, 0, 0, 0];
  @State private selP: number = -1;      // 7 = 废牌堆
  @State private selI: number = 0;
  @State private moves: number = 0;
  @State private passes: number = 0;
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
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private reset(): void {
    const deck: number[] = [];
    for (let i = 0; i < 52; i++) {
      deck.push(i);
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
      const pile: number[] = [];
      for (let j = 0; j <= p; j++) {
        pile.push(deck[k] * 2 + (j === p ? 1 : 0));
        k++;
      }
      ps.push(pile);
    }
    const st: number[] = [];
    while (k < 52) {
      st.push(deck[k] * 2);
      k++;
    }
    this.piles = ps;
    this.stock = st;
    this.waste = [];
    this.founds = [0, 0, 0, 0];
    this.selP = -1;
    this.selI = 0;
    this.moves = 0;
    this.passes = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点牌堆翻牌，选牌后再点目标列');
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

  private foundTotal(): number {
    return this.founds[0] + this.founds[1] + this.founds[2] + this.founds[3];
  }

  /** 选中了哪张牌（-1 = 没选） */
  private selCard(): number {
    if (this.selP === 7) {
      return this.waste.length > 0 ? this.waste[this.waste.length - 1] : -1;
    }
    if (this.selP >= 0 && this.selP < PILES) {
      const pile: number[] = this.piles[this.selP];
      if (this.selI >= 0 && this.selI < pile.length) {
        return pile[this.selI];
      }
    }
    return -1;
  }

  /** 一列里从 i 到末尾是不是「正面 + 颜色相反 + 点数递减」 */
  private runOk(p: number, i: number): boolean {
    const pile: number[] = this.piles[p];
    if (i < 0 || i >= pile.length) {
      return false;
    }
    for (let k = i; k < pile.length; k++) {
      if (!isUp(pile[k])) {
        return false;
      }
      if (k > i) {
        if (rankOf(pile[k]) !== rankOf(pile[k - 1]) - 1) {
          return false;
        }
        if (redOf(pile[k]) === redOf(pile[k - 1])) {
          return false;
        }
      }
    }
    return true;
  }

  private stackOk(card: number, q: number): boolean {
    const pile: number[] = this.piles[q];
    if (pile.length === 0) {
      return rankOf(card) === 12;
    }
    const top: number = pile[pile.length - 1];
    if (!isUp(top)) {
      return false;
    }
    return rankOf(top) === rankOf(card) + 1 && redOf(top) !== redOf(card);
  }

  private toFoundOk(card: number): boolean {
    return this.founds[suitOf(card)] === rankOf(card);
  }

  // ── 交互 ────────────────────────────────────────────────
  private tapStock(): void {
    if (this.over) {
      return;
    }
    this.selP = -1;
    if (this.stock.length > 0) {
      const n: number = this.stock.length;
      const next: number[] = [];
      for (let i = 0; i < n - 1; i++) {
        next.push(this.stock[i]);
      }
      const slot: number = this.stock[n - 1];
      this.stock = next;
      const w: number[] = this.waste.slice();
      w.push(slot + 1);
      this.waste = w;
      this.msg = TG2('翻到 {0}', labelOf(slot));
      return;
    }
    if (this.waste.length === 0) {
      this.msg = TG('牌堆和废牌堆都空了');
      return;
    }
    if (this.passes >= MAX_PASS) {
      this.msg = TG2('已经洗过 {0} 遍，不能再洗了', MAX_PASS);
      return;
    }
    const st: number[] = [];
    for (let i = this.waste.length - 1; i >= 0; i--) {
      st.push(this.waste[i] - 1);
    }
    this.stock = st;
    this.waste = [];
    this.passes++;
    this.msg = TG2('把废牌堆收回牌堆（第 {0} 遍）', this.passes);
    this.afterMove();
  }

  private tapWaste(): void {
    if (this.over || this.waste.length === 0) {
      return;
    }
    if (this.selP === 7) {
      this.selP = -1;
      return;
    }
    if (this.selP >= 0) {
      this.tryMoveToPileTarget();
      return;
    }
    this.selP = 7;
    this.selI = this.waste.length - 1;
    this.msg = TG2("选中 {0}，点目标列或基础堆", labelOf(this.waste[this.waste.length - 1]));
  }

  /** 选着牌的时候又点了别的列 ⇒ 当成"放这里" */
  private tryMoveToPileTarget(): void {
    this.selP = -1;
    this.msg = TG('已取消选择');
  }

  private tapPileCard(p: number, i: number): void {
    if (this.over) {
      return;
    }
    const pile: number[] = this.piles[p];
    const slot: number = pile[i];
    // ★★★ P15 根因：这里原来只有「选着牌 ⇒ tryMoveTo(p)」一条路。
    //   再点一次**已经选中**的那张牌时，tryMoveTo 会去算 stackOk(自己, 自己所在列)
    //   —— 自己下面那张牌的点数当然不是"自己的点数+1" ⇒ 判定失败 ⇒ 只回一句
    //   「放不下」，selP 一直不清 ⇒ 用户**永远取消不掉选中**。
    //   修法：同一张牌再点 = 取消选中（开关式），这是纸牌类的通用手势。
    if (this.selP === p && this.selI === i) {
      this.selP = -1;
      this.msg = TG('已取消选择');
      return;
    }
    if (this.selP >= 0) {
      const card: number = this.selCard();
      // ① 能放 ⇒ 直接放
      if (card >= 0 && this.stackOk(card, p)) {
        this.moveToPile(p);
        return;
      }
      // ② 放不下，但点的这张本身可以选 ⇒ 改选它（别把人卡在上一张牌上）
      if (isUp(slot) && this.runOk(p, i)) {
        this.selP = p;
        this.selI = i;
        this.msg = TG2("选中 {0}（{1} 张），点目标列或基础堆", labelOf(slot), (pile.length - i));
        return;
      }
      // ③ 都不是 ⇒ 给原来的解释性提示（顺带把废牌/坏选中的状态兜住）
      this.tryMoveTo(p);
      return;
    }
    if (!isUp(slot)) {
      if (i === pile.length - 1) {
        const np: number[][] = this.copyPiles();
        np[p][i] = slot + 1;
        this.piles = np;
        this.moves++;
        this.msg = TG2('翻开 {0}', labelOf(slot));
        this.afterMove();
      } else {
        this.msg = TG('这张还盖着，先把它上面的牌搬走');
      }
      return;
    }
    if (this.runOk(p, i)) {
      this.selP = p;
      this.selI = i;
      this.msg = TG2("选中 {0}（{1} 张），点目标列或基础堆", labelOf(slot), (pile.length - i));
    } else {
      this.msg = TG('这一串不是同色递减，搬不动');
    }
  }

  private tapPileBlank(p: number): void {
    if (this.over) {
      return;
    }
    if (this.selP >= 0) {
      this.tryMoveTo(p);
    }
  }

  private tapFound(f: number): void {
    if (this.over) {
      return;
    }
    if (this.selP < 0) {
      // 没选牌时点基础堆 ⇒ 自动把废牌堆顶能收的收进去
      if (this.waste.length > 0) {
        const w: number = this.waste[this.waste.length - 1];
        if (this.toFoundOk(w) && suitOf(w) === f) {
          this.selP = 7;
          this.selI = this.waste.length - 1;
          this.moveToFound(f);
        } else {
          this.msg = TG2('基础堆 {0} 还等着 {1}', SUITS[f], RANKS[this.founds[f]]);
        }
      }
      return;
    }
    this.moveToFound(f);
  }

  private tryMoveTo(p: number): void {
    const card: number = this.selCard();
    if (card < 0) {
      this.selP = -1;
      return;
    }
    if (!this.stackOk(card, p)) {
      this.msg = rankOf(card) === 12
        ? 'K 只能放到空列'
        : TG2('放不下：这列要接 {0} 且颜色相反', RANKS[rankOf(card) + 1]);
      return;
    }
    this.moveToPile(p);
  }

  private moveToPile(p: number): void {
    const np: number[][] = this.copyPiles();
    const moved: number[] = [];
    if (this.selP === 7) {
      moved.push(this.waste[this.waste.length - 1]);
      const w: number[] = [];
      for (let i = 0; i < this.waste.length - 1; i++) {
        w.push(this.waste[i]);
      }
      this.waste = w;
    } else {
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
    }
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

  private moveToFound(f: number): void {
    const card: number = this.selCard();
    if (card < 0) {
      return;
    }
    if (suitOf(card) !== f || rankOf(card) !== this.founds[f]) {
      this.msg = TG2('基础堆 {0} 还等着 {1}', SUITS[f], RANKS[this.founds[f]]);
      return;
    }
    if (this.selP !== 7 && this.selI !== this.piles[this.selP].length - 1) {
      this.msg = TG('只有每列最上面那张能收进基础堆');
      return;
    }
    const nf: number[] = this.founds.slice();
    nf[f] = nf[f] + 1;
    this.founds = nf;
    if (this.selP === 7) {
      const w: number[] = [];
      for (let i = 0; i < this.waste.length - 1; i++) {
        w.push(this.waste[i]);
      }
      this.waste = w;
    } else {
      const np: number[][] = this.copyPiles();
      const keep: number[] = [];
      const src: number[] = np[this.selP];
      for (let i = 0; i < src.length - 1; i++) {
        keep.push(src[i]);
      }
      if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
        keep[keep.length - 1] = keep[keep.length - 1] + 1;
      }
      np[this.selP] = keep;
      this.piles = np;
    }
    this.selP = -1;
    this.moves++;
    this.msg = TG2('收进基础堆 {0}', SUITS[f]);
    this.afterMove();
  }

  /** 能自动收进基础堆的统统收掉 */
  private autoCollect(): void {
    if (this.over) {
      return;
    }
    this.selP = -1;
    let guard: number = 0;
    let moved: boolean = true;
    while (moved && !this.over && guard < 200) {
      guard++;
      moved = false;
      if (this.waste.length > 0) {
        const w: number = this.waste[this.waste.length - 1];
        if (this.toFoundOk(w)) {
          this.selP = 7;
          this.selI = this.waste.length - 1;
          this.moveToFound(suitOf(w));
          moved = true;
          continue;
        }
      }
      for (let p = 0; p < PILES; p++) {
        const pile: number[] = this.piles[p];
        if (pile.length === 0) {
          continue;
        }
        const t: number = pile[pile.length - 1];
        if (isUp(t) && this.toFoundOk(t)) {
          this.selP = p;
          this.selI = pile.length - 1;
          this.moveToFound(suitOf(t));
          moved = true;
          break;
        }
      }
    }
    if (!this.over) {
      this.msg = TG('能自动收的已经收完了');
    }
  }

  private afterMove(): void {
    if (this.over) {
      return;
    }
    if (this.foundTotal() === 52) {
      this.over = true;
      this.won = true;
      this.msg = TG('🎉 52 张全部归位，通关！');
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (!this.hasMove()) {
      this.over = true;
      this.won = false;
      this.msg = TG('😵 没牌可翻也没处可放了，这局走不通');
      this.finish(false);
    }
  }

  /** 还有没有活路：能收基础堆 / 能叠到别的列 / 还能翻牌 */
  private hasMove(): boolean {
    for (let p = 0; p < PILES; p++) {
      const pile: number[] = this.piles[p];
      for (let i = 0; i < pile.length; i++) {
        if (!isUp(pile[i]) || !this.runOk(p, i)) {
          continue;
        }
        const card: number = pile[i];
        if (i === pile.length - 1 && this.toFoundOk(card)) {
          return true;
        }
        for (let q = 0; q < PILES; q++) {
          if (q !== p && this.stackOk(card, q)) {
            return true;
          }
        }
      }
    }
    if (this.waste.length > 0) {
      const w: number = this.waste[this.waste.length - 1];
      if (this.toFoundOk(w)) {
        return true;
      }
      for (let q = 0; q < PILES; q++) {
        if (this.stackOk(w, q)) {
          return true;
        }
      }
    }
    if (this.stock.length > 0) {
      return true;
    }
    return this.waste.length > 0 && this.passes < MAX_PASS;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'solitaire',
      solved: solved,
      score: this.foundTotal() * 20 + (solved ? Math.max(0, 300 - this.moves * 2) : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.foundTotal()
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

      // 顶行：牌堆 · 废牌堆 · 空位 · 4 个基础堆
      Row({ space: this.diffTotal }) {
        this.stockCell()
        this.wasteCell()
        Row()
          .layoutWeight(1)
          .height(CARD_H)
        ForEach(this.rowIdx(), (f: number) => {
          this.foundCell(f)
        }, (f: number) => 'f' + f)
      }
      .width('100%')

      Scroll() {
        Row({ space: this.diffTotal }) {
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
        Button(TG('自动收牌'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.emerald)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.autoCollect();
          })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.emerald)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /**
   * 顶部小格：kind 0=归位 1=步数 2=洗牌
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值的话这三个数
   *    整局都不会变（P6/P8/P17 同族）。读取必须落在闭包内。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '归位' : (kind === 1 ? TG('步数') : TG('洗牌')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.foundTotal() + '/52'
        : (kind === 1 ? String(this.moves) : this.passes + '/' + MAX_PASS))
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

  // ── 取牌（一律走方法：让"读状态"发生在 @Builder 闭包**内部**才会刷新）──
  /** kind 0=第 a 列第 i 张 1=废牌堆顶 2=第 a 个基础堆顶 3=空位 */
  private faceSlot(kind: number, a: number, i: number): number {
    if (kind === 0) {
      const pile: number[] = this.piles[a];
      return (i >= 0 && i < pile.length) ? pile[i] : -1;
    }
    if (kind === 1) {
      return this.waste.length > 0 ? this.waste[this.waste.length - 1] : -1;
    }
    if (kind === 2) {
      return this.founds[a] === 0 ? -1 : (a * 13 + this.founds[a] - 1) * 2 + 1;
    }
    return -1;
  }

  /** 这张牌是不是"选中的那张"（★ P15 的选中高亮要靠它刷新，不能再当参数传进来） */
  private faceHl(kind: number, a: number, i: number): boolean {
    if (kind === 0) {
      return this.selP === a && this.selI === i;
    }
    return kind === 1 && this.selP === 7;
  }

  private faceInk(kind: number, a: number, i: number): string {
    const slot: number = this.faceSlot(kind, a, i);
    if (slot < 0 || !isUp(slot)) {
      return '#FFFFFF';
    }
    return redOf(slot) ? RED_INK : DARK_INK;
  }

  private faceBg(kind: number, a: number, i: number): string {
    return isUp(this.faceSlot(kind, a, i)) ? '#FFFFFF' : Palette.primaryDeep;
  }

  /** 一张牌的正面/背面（kind/a/i 只表示"位置"，牌面与选中态都在内部读） */
  @Builder
  face(kind: number, a: number, i: number) {
    Stack() {
      if (this.faceSlot(kind, a, i) >= 0) {
        if (isUp(this.faceSlot(kind, a, i))) {
          Text(labelOf(this.faceSlot(kind, a, i)))
            .fontSize(FontSize.xs)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.faceInk(kind, a, i))
        } else {
          // ★ P14 同类：背面不用字形（✦ 在真机字体里缺失 ⇒ 回落成 "?" 且与数字上下错位），
          //   改成纯色块画的牌背 —— 不依赖任何字形度量。
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
    .backgroundColor(this.faceSlot(kind, a, i) < 0
      ? Color.Transparent
      : this.faceBg(kind, a, i))
    .borderRadius(Radius.xs)
    .border({
      width: this.faceHl(kind, a, i) ? 2 : 1,
      color: this.faceHl(kind, a, i) ? Palette.amber : this.theme.lineSoft
    })
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  /** 牌堆 */
  @Builder
  stockCell() {
    Stack() {
      if (this.stock.length > 0) {
        // ★ P14 同类：牌背不用字形（缺字会回落成 "?"），用色块画
        Row()
          .width('46%')
          .height('38%')
          .backgroundColor('#FFFFFF2E')
          .borderRadius(Radius.xs)
      } else {
        Text('↻')
          .accessibilityLevel('no')
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkFaint)
      }
    }
    .layoutWeight(1)
    .height(CARD_H)
    .backgroundColor(this.stock.length > 0 ? Palette.primaryDeep : this.theme.surfaceAlt)
    .borderRadius(Radius.xs)
    .border({ width: 1, color: this.theme.lineSoft })
    .onClick(() => {
      Haptics.tick();
      this.tapStock();
    })
  }

  /** 废牌堆顶 */
  @Builder
  wasteCell() {
    Stack() {
      this.face(1, 0, 0)
    }
    .layoutWeight(1)
    .height(CARD_H)
    .onClick(() => {
      Haptics.tick();
      this.tapWaste();
    })
  }

  /** 基础堆 */
  @Builder
  foundCell(f: number) {
    Stack() {
      if (this.founds[f] === 0) {
        Text(RANKS[0] + SUITS[f])
          .fontSize(FontSize.xs)
          .fontColor(this.theme.lineSoft)
      } else {
        this.face(2, f, 0)
      }
    }
    .layoutWeight(1)
    .height(CARD_H)
    .backgroundColor(this.theme.surfaceAlt)
    .borderRadius(Radius.xs)
    .border({ width: 1, color: this.theme.lineSoft })
    .onClick(() => {
      Haptics.tick();
      this.tapFound(f);
    })
  }

  /** 一列牌 */
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
      // ⚠️ key 里必须带 i 与 slot：翻牌会改 slot、插入会改 i，
      //    两者任一变了都要让这一项重建（否则位置/牌面会是旧的）
      ForEach(this.piles[p], (slot: number, i: number) => {
        this.pileCard(p, i)
      }, (slot: number, i: number) => 'c' + p + '_' + i + '_' + slot)
    }
    .layoutWeight(1)
    .height(this.pileH(p))
    .onClick(() => {
      Haptics.tick();
      this.tapPileBlank(p);
    })
  }

  @Builder
  pileCard(p: number, i: number) {
    Stack() {
      this.face(0, p, i)
    }
    .width('100%')
    .height(CARD_H)
    .position({ x: 0, y: i * STEP })
    .onClick(() => {
      Haptics.tick();
      this.tapPileCard(p, i);
    })
  }
}
