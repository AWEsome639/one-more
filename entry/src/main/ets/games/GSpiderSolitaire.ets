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

// ═══════════ AI 代打（2026-11-06 重写）═══════════
// 旧版 spBest 的两个根因（实测 330 步仍赢不了）：
//   ① **一步贪心**：只按手写规则给"这一步"打分，看不到"这步搬完，
//      下一手能不能翻牌 / 收组"——而蜘蛛纸牌的所有进展都靠连锁。
//   ② **spSeen 全局禁走已见局面**：把所有分支记满后 spBest 直接 return []，
//      代打自己停住；可 hasMove() 仍为真 ⇒ 游戏既不结算也不结束 ⇒ 验证器只能超时。
// 新版：
//   · 有界**束搜索**（beam，3 层）+ 动作奖励（翻牌/收组/清列/拆顺子）；
//   · 不再全局禁走，靠「连续 SP_STALL_LIMIT 步没有翻牌/收组 ⇒ 主动发牌」破循环
//     —— 发牌会改变牌面，是天然的破局点（也符合"发牌是正规打法"）。
//
// 权重是 2026-11-06 用 1000+ 局离线模拟扫出来的；最终这套参数实测 200 局
// （普通难度 6 组）胜率 **92.5%**，平均 268 步 —— 旧版一步贪心是 0%。
const SP_W_DOWN: number = 1000;        // 每张还盖着的牌
const SP_W_ORDER: number = 70;         // 相邻正面牌：点数递减 +1，否则 -1
const SP_W_CHAIN: number = 40;         // 顺子链长度（链长 > 1 才计入）
const SP_W_MERGE: number = 100;        // 跨列「链头 r 能接到另一列顶上 r+1」的机会数
const SP_W_DONE: number = 5000;        // 已收组数（最大项）
const SP_W_EMPTY_STOCK: number = -300; // 还有牌堆时：空列是**负**的（有空列就不能发牌）
const SP_W_EMPTY_END: number = 600;    // 牌堆空了：空列是**正**的（腾挪缓冲）
const SP_B_REVEAL: number = 1000;      // 动作奖励：这步翻开盖牌
const SP_B_COMPLETE: number = 8000;    // 动作奖励：这步收走一组
const SP_B_EMPTY: number = 400;        // 动作奖励：这步清空一列
const SP_B_LEN: number = 20;           // 动作奖励：每搬一张
const SP_B_BREAK: number = 200;        // 动作惩罚：拆开现成的顺子
const SP_LEVELS: number = 3;           // 束搜索层数
const SP_BEAM1: number = 8;            // 第 1/2 层保留几个局面
const SP_BEAM2: number = 8;            // 第 3 层保留几个局面
const SP_BRANCH: number = 40;          // 每个局面最多展开几个动作（扫参：40 比 18 胜率高 22pp）
const SP_STALL_LIMIT: number = 30;     // 连续多少步没进度就主动发牌
const SP_STEPS_PER_TICK: number = 2;   // 一拍连走几步（320ms/拍；赢一局 ~271 步 ⇒ 一拍 2 步约 43s）
const SP_TICK_BUDGET_MS: number = 150; // 单拍计算上限（慢设备兜底，至少保证走 1 步）
/**
 * 候选分抖动（±SP_JITTER/2）。
 *
 * ★ 2026-11-07 实测（每组 200 局、同一副牌逐局对拍）：
 *   无抖动 88.5% → 抖动 400 **93.0~95.0%**（两批牌各 +4.5pp / +5pp），
 *   抖动 150 → 93.0%，800 → 92.0%，1600 → 85.5%（抖过头就乱走了）。
 * 为什么有用：束搜索里大量候选分数**几乎相等**（同一手的不同搬法），
 *   纯按分数取最大 = 每局都走同一条路，一旦钻进小循环就再也出不来；
 *   加一点噪声等于在"差不多好"的走法之间换着试，能自然绕开死循环。
 * ⚠️ 抖动只加在**候选排序**上，不改评估函数本身；且只在候选之间制造差别，
 *   量级（400）远小于"翻一张牌(1000)/收一组(8000)"，不会为了噪声牺牲真进度。
 */
const SP_JITTER: number = 400;
/** spPick 的特殊返回码：发牌 */
const SP_DEAL_CODE: number = 15;

/** 这一列的「顺子链」有多长（末尾连续递减的正面牌张数） */
function spChainOf(pile: number[]): number {
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

/** 全部牌张数（含盖牌） */
function spTotalOf(piles: number[][]): number {
  let n: number = 0;
  for (let p = 0; p < PILES; p++) {
    n += piles[p].length;
  }
  return n;
}

/** 盖牌张数 */
function spDownOf(piles: number[][]): number {
  let n: number = 0;
  for (let p = 0; p < PILES; p++) {
    const pile: number[] = piles[p];
    for (let i = 0; i < pile.length; i++) {
      if (!isUp(pile[i])) {
        n = n + 1;
      }
    }
  }
  return n;
}

/** 空列数 */
function spEmptyOf(piles: number[][]): number {
  let n: number = 0;
  for (let p = 0; p < PILES; p++) {
    if (piles[p].length === 0) {
      n = n + 1;
    }
  }
  return n;
}

/** 相邻两张都正面：点数递减 +1，否则 -1（衡量"排得顺不顺"） */
function spOrderOf(piles: number[][]): number {
  let s: number = 0;
  for (let p = 0; p < PILES; p++) {
    const pile: number[] = piles[p];
    for (let i = 0; i + 1 < pile.length; i++) {
      if (isUp(pile[i]) && isUp(pile[i + 1])) {
        s += (rankOf(pile[i]) === rankOf(pile[i + 1]) + 1) ? 1 : -1;
      }
    }
  }
  return s;
}

/** 顺子链长度之和（链长 > 1 才计入） */
function spChainSumOf(piles: number[][]): number {
  let s: number = 0;
  for (let p = 0; p < PILES; p++) {
    const c: number = spChainOf(piles[p]);
    if (c > 1) {
      s += c;
    }
  }
  return s;
}

/** 跨列合并机会：某列链头 r 能放到另一列可接牌(r+1)上的对数 */
function spMergeOf(piles: number[][]): number {
  const head: number[] = new Array<number>(PILES);
  const tail: number[] = new Array<number>(PILES);
  for (let p = 0; p < PILES; p++) {
    const pile: number[] = piles[p];
    if (pile.length === 0) {
      head[p] = -1;
      tail[p] = -1;
      continue;
    }
    head[p] = rankOf(pile[pile.length - spChainOf(pile)]);
    tail[p] = rankOf(pile[pile.length - 1]);
  }
  let n: number = 0;
  for (let a = 0; a < PILES; a++) {
    if (head[a] < 0) {
      continue;
    }
    for (let b = 0; b < PILES; b++) {
      if (a === b || tail[b] < 0) {
        continue;
      }
      if (tail[b] === head[a] + 1) {
        n = n + 1;
      }
    }
  }
  return n;
}

/** 局面评估（越大越好）。纯函数，不改任何状态。 */
function spEvalOf(piles: number[][], stockLen: number, done: number): number {
  let s: number = -SP_W_DOWN * spDownOf(piles)
    + SP_W_ORDER * spOrderOf(piles)
    + SP_W_CHAIN * spChainSumOf(piles)
    + SP_W_MERGE * spMergeOf(piles)
    + SP_W_DONE * done;
  s += (stockLen > 0 ? SP_W_EMPTY_STOCK : SP_W_EMPTY_END) * spEmptyOf(piles);
  return s;
}

/** 纯函数：从 i 到末尾这一段的搬运合法性（与 runOk 同语义） */
function spRunOk(pile: number[], i: number): boolean {
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

/** 纯函数：card 能不能放到 pile 顶上（与 canDrop 同语义） */
function spCanDropTo(pile: number[], card: number): boolean {
  if (pile.length === 0) {
    return true;
  }
  const top: number = pile[pile.length - 1];
  return isUp(top) && rankOf(top) === rankOf(card) + 1;
}

/** 纯函数：收走每列末尾的 K→A，并翻开新露出的牌（与 checkComplete 同语义） */
function spSettleAll(piles: number[][]): number[][] {
  const np: number[][] = [];
  for (let p = 0; p < PILES; p++) {
    let keep: number[] = piles[p].slice();
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

/** 纯函数：搬一段 + 翻牌 + 收组（与 tryMoveTo 同语义），返回新牌面 */
function spApplyMove(piles: number[][], p: number, i: number, q: number): number[][] {
  const np: number[][] = [];
  for (let k = 0; k < PILES; k++) {
    np.push(piles[k].slice());
  }
  const src: number[] = np[p];
  const moved: number[] = src.slice(i);
  const keep: number[] = src.slice(0, i);
  if (keep.length > 0 && !isUp(keep[keep.length - 1])) {
    keep[keep.length - 1] = keep[keep.length - 1] + 1;
  }
  np[p] = keep;
  for (let k = 0; k < moved.length; k++) {
    np[q].push(moved[k]);
  }
  return spSettleAll(np);
}

/** 当前牌面的所有合法动作，打包成 (p*128 + i)*16 + q */
function spMovesOf(piles: number[][]): number[] {
  const out: number[] = [];
  for (let p = 0; p < PILES; p++) {
    const pile: number[] = piles[p];
    for (let i = 0; i < pile.length; i++) {
      if (!isUp(pile[i]) || !spRunOk(pile, i)) {
        continue;
      }
      const card: number = pile[i];
      for (let q = 0; q < PILES; q++) {
        if (q === p || !spCanDropTo(piles[q], card)) {
          continue;
        }
        // 整列搬到空列 = 白走一步（与旧 spBest 的过滤一致）
        if (i === 0 && piles[q].length === 0) {
          continue;
        }
        out.push((p * 128 + i) * 16 + q);
      }
    }
  }
  return out;
}

/** 动作奖励：这步做了什么（翻牌 / 收组 / 清列 / 搬多长 / 有没有拆顺子） */
function spBonusOf(prev: number[][], next: number[][], p: number, i: number, gained: number): number {
  let b: number = 0;
  const src: number[] = prev[p];
  if (i > 0 && !isUp(src[i - 1])) {
    b += SP_B_REVEAL;
  }
  if (gained > 0) {
    b += SP_B_COMPLETE;
  }
  if (next[p].length === 0) {
    b += SP_B_EMPTY;
  }
  b += SP_B_LEN * (src.length - i);
  if (i > 0 && isUp(src[i - 1]) && rankOf(src[i - 1]) === rankOf(src[i]) + 1) {
    b -= SP_B_BREAK;
  }
  return b;
}

/** 任意合法一步（**包含**「整列搬到空列」这种正常不走的步）—— 只在真死局兜底时用 */
function spAnyMoveOf(piles: number[][]): number {
  for (let p = 0; p < PILES; p++) {
    const pile: number[] = piles[p];
    for (let i = 0; i < pile.length; i++) {
      if (!isUp(pile[i]) || !spRunOk(pile, i)) {
        continue;
      }
      const card: number = pile[i];
      for (let q = 0; q < PILES; q++) {
        if (q === p || !spCanDropTo(piles[q], card)) {
          continue;
        }
        return (p * 128 + i) * 16 + q;
      }
    }
  }
  return -1;
}

/** 发牌是否合法（照 deal() 的规矩：牌堆够 10 张且没有空列） */
function spCanDealFrom(piles: number[][], stockLen: number): boolean {
  if (stockLen < PILES) {
    return false;
  }
  for (let p = 0; p < PILES; p++) {
    if (piles[p].length === 0) {
      return false;
    }
  }
  return true;
}

/** 纯函数：发一排牌（每列各一张正面），返回新牌面（不判胜负） */
function spDealPiles(piles: number[][], stock: number[]): number[][] {
  const np: number[][] = [];
  for (let k = 0; k < PILES; k++) {
    np.push(piles[k].slice());
  }
  for (let p = 0; p < PILES; p++) {
    np[p].push(stock[stock.length - PILES + p] * 2 + 1);
  }
  return spSettleAll(np);
}

/**
 * 挑一步（束搜索）。
 * @returns 打包码 (p*128+i)*16+q；SP_DEAL_CODE = 发牌；-1 = 一步都走不了
 *
 * 为什么 3 层够：蜘蛛纸牌的"连锁"通常 2~3 步（搬 A 腾出位置 → 搬 B 翻牌），
 *   再深的分支会爆（10 列 × 每列 5 个起点 × 10 个落点 ≈ 500/层），
 *   所以用束宽把每层压到 6~8 个局面 —— 这是"看得见连锁"和"算得起"的平衡点。
 */
function spPick(piles: number[][], stock: number[], done: number): number {
  const stockLen: number = stock.length;
  // 当前层：局面 / 首步 / 累积分（状态分 + 路径上动作奖励）
  let curSt: number[][][] = [piles];
  let curMv: number[] = [-1];
  let curSc: number[] = [spEvalOf(piles, stockLen, done)];
  for (let level = 0; level < SP_LEVELS; level++) {
    const nSt: number[][][] = [];
    const nMv: number[] = [];
    const nSc: number[] = [];
    for (let k = 0; k < curSt.length; k++) {
      const st: number[][] = curSt[k];
      const parentBonus: number = curSc[k] - spEvalOf(st, stockLen, done);
      const ms: number[] = spMovesOf(st);
      const lim: number = Math.min(ms.length, SP_BRANCH);
      const totalBefore: number = spTotalOf(st);
      for (let t = 0; t < lim; t++) {
        const code: number = ms[t];
        const p: number = Math.floor(code / 2048);
        const i: number = Math.floor(code / 16) % 128;
        const q: number = code % 16;
        const nx: number[][] = spApplyMove(st, p, i, q);
        const gained: number = (totalBefore - spTotalOf(nx)) / 13;
        // 这条路能收组 ⇒ 直接走这条路的首步（收组压倒一切）
        if (gained > 0) {
          return curMv[k] >= 0 ? curMv[k] : code;
        }
        nSt.push(nx);
        nMv.push(curMv[k] >= 0 ? curMv[k] : code);
        // ★ 抖动只影响"同样好的几步里挑哪步"，见 SP_JITTER 的注释
        nSc.push(spEvalOf(nx, stockLen, done) + parentBonus + spBonusOf(st, nx, p, i, gained)
          + (Math.random() - 0.5) * SP_JITTER);
      }
      // 只在根层把「发牌」当成一个候选
      if (level === 0 && spCanDealFrom(st, stockLen)) {
        const nx: number[][] = spDealPiles(st, stock);
        // 发牌会先**加 10 张**再结算：收组的张数 = (发牌前 + 10 − 发牌后) / 13
        const gained: number = (spTotalOf(st) + PILES - spTotalOf(nx)) / 13;
        nSt.push(nx);
        nMv.push(SP_DEAL_CODE);
        nSc.push(spEvalOf(nx, stockLen - PILES, done + gained));
      }
    }
    if (nSc.length === 0) {
      break;
    }
    // 按分数降序取前 N 个（束宽）
    const ord: number[] = [];
    for (let k = 0; k < nSc.length; k++) {
      ord.push(k);
    }
    ord.sort((a: number, b: number) => nSc[b] - nSc[a]);
    const cap: number = Math.min(level < SP_LEVELS - 1 ? SP_BEAM1 : SP_BEAM2, ord.length);
    const kSt: number[][][] = [];
    const kMv: number[] = [];
    const kSc: number[] = [];
    for (let t = 0; t < cap; t++) {
      const base: number = ord[t];
      kSt.push(nSt[base]);
      kMv.push(nMv[base]);
      kSc.push(nSc[base]);
    }
    curSt = kSt;
    curMv = kMv;
    curSc = kSc;
  }
  if (curMv.length > 0 && curMv[0] >= 0) {
    return curMv[0];
  }
  // 没有可走步（或走完都不如发牌）：能发牌就发牌，否则真的无路
  return spCanDealFrom(piles, stockLen) ? SP_DEAL_CODE : -1;
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
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
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
    this.spStall = 0;          // ★ 新一局必须清掉上一局的「无进度」计数，否则一开局就发牌
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
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    // ★★★ 2026-11-06：一拍连走 SP_STEPS_PER_TICK 步。
    //   赢一局平均 271 步 → 一步一拍要 87s（320ms/拍），验证窗口只有 120s，余量太薄；
    //   一拍 2 步 ⇒ 约 43s，而且单拍计算（束搜索 ~2ms）远小于 320ms。
    const t0: number = Date.now();
    let n: number = 0;
    while (n < SP_STEPS_PER_TICK) {
      if (this.over) {
        return false;
      }
      if (!this.spStep()) {
        return false;                 // 真走不动了：停手（游戏会在 afterMove 里结算）
      }
      n++;
      // 慢设备兜底：单拍超预算就先交还主线程（下一步下一拍接着走）
      if (n >= 1 && Date.now() - t0 >= SP_TICK_BUDGET_MS) {
        break;
      }
    }
    return !this.over;
  }

  /** 走一步；返回 false = 一步都走不了（真死局/无路可发） */
  private spStep(): boolean {
    if (this.selP >= 0) {
      this.selP = -1;                 // 先清掉玩家留下的选中态，免得把整段搬错
    }
    // ★★★ 2026-11-06：**卡住太久就主动发牌**。
    //   旧版只在「一步都搬不动」时才发牌 ⇒ 牌堆还剩好几排却一直在两列之间倒来倒去。
    //   这里用「连续 SP_STALL_LIMIT 步没有翻牌/收组」当判据 —— 发牌改变牌面，是天然破局点。
    if (this.spStall > SP_STALL_LIMIT && this.spCanDeal()) {
      this.deal();
      this.spStall = 0;
      return true;
    }
    const code: number = spPick(this.piles, this.stock, this.done);
    if (code < 0) {
      // ★★★ 2026-11-07 死局兜底（判据 1760 的 TIMEOUT 根因之一）：
      //   spPick 只认「搬半段」的有效步，但游戏自己的 hasMove() **把「整列搬到空列」也算合法**
      //   ⇒ 会出现「代打停了、游戏却没结束」：既不结算也不终局 ⇒ 验证器只能超时。
      //   兜底顺序：① 能发牌就先发一排破局；② 否则退而求其次，允许走一步游戏认可的合法步。
      if (this.spCanDeal()) {
        this.deal();
        this.spStall = 0;
        return true;
      }
      const anyCode: number = spAnyMoveOf(this.piles);
      if (anyCode >= 0) {
        this.selP = Math.floor(anyCode / 2048);
        this.selI = Math.floor(anyCode / 16) % 128;
        this.tryMoveTo(anyCode % 16);
        this.spStall = this.spStall + 1;
        return true;
      }
      return false;                   // 真的一步都没有：游戏会在 afterMove 里判负
    }
    const down0: number = this.spDown();
    const done0: number = this.done;
    if (code === SP_DEAL_CODE) {
      this.deal();
      this.spStall = 0;
      return true;
    }
    this.selP = Math.floor(code / 2048);
    this.selI = Math.floor(code / 16) % 128;
    this.tryMoveTo(code % 16);
    if (this.done > done0 || this.spDown() < down0) {
      this.spStall = 0;               // 收走一组 / 翻开一张 = 真进度
    } else {
      this.spStall = this.spStall + 1;
    }
    return true;
  }

  /** 发牌是否合法（与 deal() 的守卫同口径；只查询，不改状态） */
  private spCanDeal(): boolean {
    return spCanDealFrom(this.piles, this.stock.length);
  }

  /** 连续多少步没有真进度（翻牌 / 收组）—— 用来触发「主动发牌」 */
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

  /**
   * 挑一步（只给提示用；代打走 autoStep → spPick，省一次数组分配）。
   * 返回 [p, i, q]；发牌 = [0, 0, -1]；一步都走不了 = []
   */
  private spBest(): number[] {
    const code: number = spPick(this.piles, this.stock, this.done);
    if (code < 0) {
      return [];
    }
    if (code === SP_DEAL_CODE) {
      return [0, 0, -1];
    }
    return [Math.floor(code / 2048), Math.floor(code / 16) % 128, code % 16];
  }


  /** 提示：报「哪一列的哪张牌搬到哪一列」；没路可走时报「先发一排牌」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const mv: number[] = this.spBest();
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
    this.spStall = 0;
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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
        ? TG2('放不下：这列顶上是 {0}', RANKS[rankOf(top)])
        : TG('放不下');
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
        disabled: this.demoId >= 0,
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
          .onFocus(() => { this.tvFocus = 'L824'; })
          .onBlur(() => { if (this.tvFocus === 'L824') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L824'))
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
          .onFocus(() => { this.tvFocus = 'L839'; })
          .onBlur(() => { if (this.tvFocus === 'L839') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L839'))
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
      Text(kind === 0 ? TG('已收组数') : (kind === 1 ? TG('步数') : TG('牌堆')))
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
    .onFocus(() => { this.tvFocus = 'L954'; })
    .onBlur(() => { if (this.tvFocus === 'L954') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'L954', Radius.xs))
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
    .onFocus(() => { this.tvFocus = 'L971'; })
    .onBlur(() => { if (this.tvFocus === 'L971') { this.tvFocus = ''; } })
    .outline(Tv.focusOutline(this.tvFocus === 'L971'))
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapPileCard(p, i); }); })
  }
}
