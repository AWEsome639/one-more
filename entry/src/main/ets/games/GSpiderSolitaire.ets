/**
 * 蜘蛛纸牌（单花色版）—— 同花顺序排列
 *
 * 规则：8 副黑桃 A~K 共 104 张，10 列。可以整段搬「点数递减」的正面牌，
 *       放到比它大一点的牌上（空列放任意牌）。集齐 K→A 一整组就收走。
 * 结算：收满本档组数（简单 4 / 普通 6 / 困难 8，见 diffTotal）⇒ 通关；牌堆空了又无处可搬 ⇒ 失败。
 *
 * 牌编码：slot = 点数×2 + 是否正面（A=0…K=12，全黑桃所以不用存花色）。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

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
  //   ★ 2026-10-29 修「困难档数学上不可能赢」：
  //     要收的组数 = GameDiff.sizeNow(8) = 6 / 8 / 10，但整副牌只有 SETS=8 组 A~K（104 张）
  //     ⇒ 困难档要 10 组 > 牌里存在的 8 组，永远收不齐、必输。
  //     base 改 6 ⇒ 4 / 6 / 8，再用 min(难度值, SETS) 兜底：困难档刚好用满 8 组（能赢的最难值），
  //     简单档只收 4 组 ⇒ 仍是 易 < 普 < 难。牌堆、发牌、收组判定一概没动。
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = Math.min(GameDiff.sizeNow(6), SETS);
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
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSpiderSolitaire')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = Math.min(GameDiff.sizeNow(6), SETS);
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

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.selP >= 0) {
      this.selP = -1;                 // 先清掉玩家留下的选中态，免得把整段搬错
    }
    const mv: number[] = this.spBest(true);
    if (mv.length < 2) {
      return false;                   // 真走不动了：老实停手，绝不空转
    }
    const down0: number = this.spDown();
    const done0: number = this.done;
    if (mv[2] < 0) {
      this.deal();
      this.spStall = 0;
      return !this.over;
    }
    this.selP = mv[0];
    this.selI = mv[1];
    this.tryMoveTo(mv[2]);
    if (this.done > done0 || this.spDown() < down0) {
      this.spStall = 0;               // 收走一组 / 翻开一张 = 真进度
    } else {
      this.spStall = this.spStall + 1;
    }
    return !this.over;
  }

  /** 走出来的局面（防兜圈子） */
  private spSeen: Map<string, number> = new Map<string, number>();
  /** 连续多少步没有真进度（翻牌 / 收组） */
  private spStall: number = 0;

  /** 盖着的牌还有几张（代打的「真进度」判据：翻牌或收组才算往前走） */
  private spDown(): number {
    let n: number = 0;
    for (let p = 0; p < PILES; p++) {
      const pile: number[] = this.piles[p];
      for (let i = 0; i < pile.length; i++) {
        if (!isUp(pile[i])) {
          n = n + 1;
        }
      }
    }
    return n;
  }

  /** 这一列末尾连着的递减顺子有多长（越长相越好） */
  private spChain(pile: number[]): number {
    if (pile.length === 0) {
      return 0;
    }
    let c: number = 1;
    let k: number = pile.length - 1;
    while (k > 0 && isUp(pile[k - 1]) && rankOf(pile[k - 1]) === rankOf(pile[k]) + 1) {
      c = c + 1;
      k = k - 1;
    }
    return c;
  }

  /** 纯查询版的 canDrop（不碰状态） */
  private spCanDrop(card: number, q: number): boolean {
    const d: number[] = this.piles[q];
    if (d.length === 0) {
      return true;
    }
    const top: number = d[d.length - 1];
    return isUp(top) && rankOf(top) === rankOf(card) + 1;
  }

  /** 纯函数：搬一段（不点 UI 状态、不结算），返回新牌面 */
  private spMove(ps: number[][], p: number, i: number, q: number): number[][] {
    const np: number[][] = [];
    for (let k = 0; k < ps.length; k++) {
      np.push(ps[k].slice());
    }
    const moved: number[] = np[p].slice(i);
    const keep: number[] = np[p].slice(0, i);
    if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
      keep[keep.length - 1] = keep[keep.length - 1] + 1;
    }
    np[p] = keep;
    for (let k = 0; k < moved.length; k++) {
      np[q].push(moved[k]);
    }
    return np;
  }

  /** 纯函数：收走已集齐的 K→A（与 checkComplete 同语义） */
  private spSettle(ps: number[][]): number[][] {
    const np: number[][] = [];
    for (let p = 0; p < ps.length; p++) {
      let keep: number[] = ps[p].slice();
      while (keep.length >= 13) {
        let ok: boolean = true;
        for (let k = 0; k < 13; k++) {
          const slot: number = keep[keep.length - 13 + k];
          if (!isUp(slot) || rankOf(slot) !== 12 - k) {
            ok = false;
            break;
          }
        }
        if (!ok) {
          break;
        }
        keep = keep.slice(0, keep.length - 13);
        if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
          keep[keep.length - 1] = keep[keep.length - 1] + 1;
        }
      }
      np.push(keep);
    }
    return np;
  }

  /** 局面指纹（各列内容 + 牌堆剩几张）—— 用来记「走过的局面」，防止兜圈子 */
  private spHash(ps: number[][]): string {
    let s: string = '';
    for (let p = 0; p < ps.length; p++) {
      s = s + ps[p].join(',') + '|';
    }
    return s + '#' + String(this.stock.length);
  }

  /** 打包「分数 + (p,i,q)」成一个正整数（i 上限 127、p/q 上限 15；分数先 +3000 保证非负） */
  private spPack(score: number, p: number, i: number, q: number): number {
    return (((score + 3000) * 128 + i) * 16 + q) * 16 + p;
  }

  // ═══════════ 代打选步（启发式 + 局面记忆）═══════════
  // 蜘蛛纸牌 104 张、要收满 8 组 K→A，没法穷举；这里的判断顺序是：
  //   ① 能翻开盖牌的一步最值钱　② 别把已经排好的顺子拆开　③ 落点那边能接出更长的顺子更好
  //   ④ 清空一整列很值　⑤ 实在没得搬才发牌
  // ★ 终止性：每一步都把「走出来的局面」记进 spSeen，回到走过的局面直接否决
  //   （这是硬约束 —— 否则会在两列之间来回搬，代打看起来像卡死）。
  //   ★ 再加上 spStall（连续 120 步没有翻牌/收组就停手）和总步数上限 700，代打一定会自己停。

  /** 挑一步（mark=true 时把局面记进记忆；提示用 mark=false，免得把记忆弄脏） */
  private spBest(mark: boolean): number[] {
    if (mark && (this.moves > 700 || this.spStall > 120)) {
      return [];                       // 只有代打会被上限拦住；提示随时能给
    }
    const cand: number[] = [];
    for (let p = 0; p < PILES; p++) {
      const pile: number[] = this.piles[p];
      for (let i = 0; i < pile.length; i++) {
        if (!isUp(pile[i]) || !this.runOk(p, i)) {
          continue;
        }
        const card: number = pile[i];
        const ln: number = pile.length - i;
        for (let q = 0; q < PILES; q++) {
          if (q === p || !this.spCanDrop(card, q)) {
            continue;
          }
          const d: number[] = this.piles[q];
          let sc: number = 0;
          if (i > 0 && !isUp(pile[i - 1])) {
            sc = sc + 1000;                    // 翻开盖牌：唯一真进度
          }
          if (d.length === 0) {
            if (i === 0) {
              continue;                        // 整列搬到空列 = 白走一步
            }
            sc = sc + 40;
          } else {
            if (i === 0) {
              sc = sc + 200;                   // 能清空一列
            }
            sc = sc + this.spChain(d) * 20;     // 落点那边接得越长越好
          }
          sc = sc + ln;
          if (i > 0 && isUp(pile[i - 1]) && rankOf(pile[i - 1]) === rankOf(card) + 1) {
            sc = sc - 600;                     // 别拆开已经排好的段
          }
          cand.push(this.spPack(sc, p, i, q));
        }
      }
    }
    cand.sort((a: number, b: number) => b - a);
    for (let k = 0; k < cand.length; k++) {
      const v: number = cand[k];
      const p: number = v % 16;
      const q: number = Math.floor(v / 16) % 16;
      const i: number = Math.floor(v / 256) % 128;
      const nx: number[][] = this.spSettle(this.spMove(this.piles, p, i, q));
      const key: string = this.spHash(nx);
      if (this.spSeen.has(key)) {
        continue;                          // 回到走过的局面 ⇒ 只会兜圈子
      }
      if (mark) {
        this.spSeen.set(key, 1);
      }
      return [p, i, q];
    }
    // 一步都搬不动才发牌（蜘蛛纸牌的正规打法：有空列时不能发）
    let empty: boolean = false;
    for (let p = 0; p < PILES; p++) {
      if (this.piles[p].length === 0) {
        empty = true;
      }
    }
    if (this.stock.length >= PILES && !empty) {
      return [0, 0, -1];
    }
    return [];
  }


  /** 提示：报「哪一列的哪张牌搬到哪一列」；没路可走时报「先发一排牌」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const mv: number[] = this.spBest(false);
    if (mv.length < 2) {
      return Hint.none(TG('这局已经走不动了，换一局吧'));
    }
    if (mv[2] < 0) {
      return Hint.make([], TG('先发一排牌（每列各一张）'), TG('Deal a new row (one card per column)'), t0);
    }
    const card: number = this.piles[mv[0]][mv[1]];
    const txt: string = RANKS[rankOf(card)];
    if (this.piles[mv[2]].length === 0) {
      return Hint.make([mv[2]],
        TG2('把第 {0} 列的 {1} 搬到空列（第 {2} 列）', String(mv[0] + 1), txt, String(mv[2] + 1)),
        TG2('Move {1} from column {0} to the empty column {2}', String(mv[0] + 1), txt, String(mv[2] + 1)), t0);
    }
    return Hint.make([mv[2]],
      TG2('把第 {0} 列的 {1} 搬到第 {2} 列', String(mv[0] + 1), txt, String(mv[2] + 1)),
      TG2('Move {1} from column {0} onto column {2}', String(mv[0] + 1), txt, String(mv[2] + 1)), t0);
  }
  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.spSeen = new Map<string, number>();
    this.spStall = 0;
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
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
            Haptics.tap();
            this.deal();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.deal(); }); })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(TG('单花色（全黑桃）· 集齐 K→A 收一组 · 空列时可放任意牌'))
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
      Haptics.tick();
      this.tapPileBlank(p);
    })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPileBlank(p); }); })
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
      Haptics.tick();
      this.tapPileCard(p, i);
    })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPileCard(p, i); }); })
  }
}
