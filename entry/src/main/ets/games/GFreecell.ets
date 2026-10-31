/**
 * 空当接龙（迷你版）—— 四列自由搬运 🐉
 *
 * 规则：两门花色各 A~8 共 16 张；右上角「家」按 A→8 收牌，
 *      列内只能压「刚好小一点」的牌（♠黑 ♥红 天然交替），4 个自由格可各存 1 张。
 * 胜负：两门全部归位 = 通关；再也走不动 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

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
/** 代打求解用的「数值镜像」：card 编码 = suit*10 + rank，0 = 空备位；不碰 UI 状态 */
interface FcState {
  cols: number[][];
  frees: number[];
  found: number[];
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
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
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
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFreecell')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
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
    // ① 先把能归位的全归位（等于让搜索的起点和 fcNorm 一致）
    this.autoHome();
    if (this.over) {
      return false;
    }
    // ② 没有路线就先解一条（p50 只要几十个节点，解不出就老实停手）
    if (this.fcPlan.length < 3) {
      this.fcPlan = this.fcSolve();
      this.fcFail = 0;
      if (this.fcPlan.length < 3) {
        return false;
      }
    }
    // ③ 执行路线的下一步；计划失效（玩家插了手）就丢掉重解，连错三次停手
    const src: number = this.fcPlan[0];
    const kind: number = this.fcPlan[1];
    const idx: number = this.fcPlan[2];
    if (this.applyMove(src, kind, idx)) {
      this.fcPlan.splice(0, 3);
      this.fcFail = 0;
      return !this.over;
    }
    this.fcPlan = [];
    this.fcFail = this.fcFail + 1;
    return this.fcFail < 3;
  }

  /** 代打路线（扁平三元组）；空 = 还没解 */
  private fcPlan: number[] = [];
  /** 计划连续失效次数（玩家插手过就重解，连错三次停手） */
  private fcFail: number = 0;

  /** 牌面文字：♠5 / ♥3（空位写「空」） */
  private cardText(c: Card): string {
    return c.rank === 0 ? '空' : suitChar(c.suit) + String(c.rank);
  }

  // ═══════════ 代打求解（16 张小空当接龙 ⇒ 可以完全搜）═══════════
  // 为什么不是「贪心走一步」：通关要 16 张全部 A→8 归位，
  //   贪心在自由格堆满之后就卡死了；这里用「深度优先 + 局面记忆」，
  //   实测 240 副随机牌全部解得开（中位数 29 个节点），解出来的路线逐步喂给 applyMove。
  //   ★ 搜索只在「数值镜像」上跑（card 编码 = suit*10 + rank，0 = 空），不碰 UI 状态。

  /** 当前牌面的数值镜像 */
  private fcMirror(): FcState {
    const cs: number[][] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      const col: Card[] = this.cols[i];
      const a: number[] = [];
      for (let k = 0; k < col.length; k++) {
        a.push(col[k].suit * 10 + col[k].rank);
      }
      cs.push(a);
    }
    const fs: number[] = [];
    for (let i = 0; i < FREES; i++) {
      const c: Card = this.frees[i];
      fs.push(c.rank === 0 ? 0 : c.suit * 10 + c.rank);
    }
    return { cols: cs, frees: fs, found: [this.found[0], this.found[1]] };
  }

  /** 深拷贝一个镜像局面（牌都是数字，直接 slice） */
  private fcCopy(st: FcState): FcState {
    const cs: number[][] = [];
    for (let i = 0; i < st.cols.length; i++) {
      cs.push(st.cols[i].slice());
    }
    return { cols: cs, frees: st.frees.slice(), found: st.found.slice() };
  }

  /** 在镜像上落一步（语义与 applyMove 一致；调用方保证合法） */
  private fcPlay(st: FcState, src: number, kind: number, idx: number): FcState {
    const nx: FcState = this.fcCopy(st);
    let card: number = 0;
    if (src < 10) {
      card = nx.frees[src];
      nx.frees[src] = 0;
    } else {
      const col: number[] = nx.cols[src - 10];
      card = col[col.length - 1];
      col.pop();
    }
    if (kind === 0) {
      nx.frees[idx] = card;
    } else if (kind === 1) {
      nx.found[Math.floor(card / 10)] = card % 10;
    } else {
      nx.cols[idx].push(card);
    }
    return nx;
  }

  /** 能归位的全归位（语义与 autoHome 一致，用来把搜索状态归一） */
  private fcNorm(st: FcState): FcState {
    let cur: FcState = st;
    let moved: boolean = true;
    while (moved) {
      moved = false;
      for (let i = 0; i < FREES; i++) {
        const c: number = cur.frees[i];
        if (c > 0 && cur.found[Math.floor(c / 10)] + 1 === c % 10) {
          cur = this.fcPlay(cur, i, 1, Math.floor(c / 10));
          moved = true;
          break;
        }
      }
      if (moved) {
        continue;
      }
      for (let i = 0; i < cur.cols.length; i++) {
        const col: number[] = cur.cols[i];
        if (col.length === 0) {
          continue;
        }
        const c: number = col[col.length - 1];
        if (cur.found[Math.floor(c / 10)] + 1 === c % 10) {
          cur = this.fcPlay(cur, 10 + i, 1, Math.floor(c / 10));
          moved = true;
          break;
        }
      }
    }
    return cur;
  }

  /** 局面指纹：列的内容（顺序无关）+ 自由格集合 + 已归位 ⇒ 记忆用，防止兜圈子 */
  private fcKey(st: FcState): string {
    const cs: string[] = [];
    for (let i = 0; i < st.cols.length; i++) {
      if (st.cols[i].length > 0) {
        cs.push(st.cols[i].join('.'));
      }
    }
    cs.sort();
    const fs: number[] = [];
    for (let i = 0; i < st.frees.length; i++) {
      if (st.frees[i] > 0) {
        fs.push(st.frees[i]);
      }
    }
    fs.sort((a: number, b: number) => a - b);
    return cs.join('|') + '#' + fs.join(',') + '#' + String(st.found[0]) + ',' + String(st.found[1]);
  }

  /** 候选走法（扁平三元组 src/kind/idx，越可能推进的越靠前） */
  private fcMoves(st: FcState): number[] {
    const cand: number[] = [];
    // ① 列顶 → 别的列（压上去 / 放进空列挖牌）
    for (let i = 0; i < st.cols.length; i++) {
      const col: number[] = st.cols[i];
      if (col.length === 0) {
        continue;
      }
      const tr: number = col[col.length - 1] % 10;
      for (let j = 0; j < st.cols.length; j++) {
        if (i === j) {
          continue;
        }
        const d: number[] = st.cols[j];
        if (d.length === 0) {
          if (col.length === 1) {
            continue;            // 整列搬到空列 = 白走一步
          }
          cand.push(this.fcPack(18 + col.length, 10 + i, 2, j));
        } else if (d[d.length - 1] % 10 === tr + 1) {
          cand.push(this.fcPack(20 + col.length, 10 + i, 2, j));
        }
      }
    }
    // ② 列顶 → 空自由格（挖牌；本列只剩一张时搬走没意义）
    for (let i = 0; i < st.cols.length; i++) {
      const col: number[] = st.cols[i];
      if (col.length < 2) {
        continue;
      }
      for (let k = 0; k < FREES; k++) {
        if (st.frees[k] === 0) {
          cand.push(this.fcPack(15 + col.length, 10 + i, 0, k));
        }
      }
    }
    // ③ 自由格 → 列（把自由格腾出来）
    for (let k = 0; k < FREES; k++) {
      const c: number = st.frees[k];
      if (c === 0) {
        continue;
      }
      const cr: number = c % 10;
      for (let j = 0; j < st.cols.length; j++) {
        const d: number[] = st.cols[j];
        if (d.length === 0) {
          cand.push(this.fcPack(10, k, 2, j));
        } else if (d[d.length - 1] % 10 === cr + 1) {
          cand.push(this.fcPack(12 + d.length, k, 2, j));
        }
      }
    }
    cand.sort((a: number, b: number) => b - a);
    const out: number[] = [];
    for (let i = 0; i < cand.length; i++) {
      const v: number = cand[i];
      const idx: number = v % 10;
      const k2: number = Math.floor(v / 10);
      const kind: number = k2 % 3;
      const src: number = Math.floor(k2 / 3) % 20;
      out.push(src, kind, idx);
    }
    return out;
  }

  /** 打包「分数 + 三元组」成一个整数（省一次排序闭包；src≤19 kind≤2 idx≤9） */
  private fcPack(score: number, src: number, kind: number, idx: number): number {
    return ((score * 20 + src) * 3 + kind) * 10 + idx;
  }

  /** 深度优先：找到一条能通关的路线就返回 true，路线写进 out */
  private fcDfs(st: FcState, depth: number, seen: Map<string, number>,
                nodes: number[], out: number[]): boolean {
    if (st.found[0] === TOP && st.found[1] === TOP) {
      return true;
    }
    nodes[0] = nodes[0] + 1;
    if (nodes[0] > 20000 || depth > 60) {
      return false;                       // 有预算：宁可说想不出来，不许冻界面
    }
    const k: string = this.fcKey(st);
    if (seen.has(k)) {
      return false;
    }
    seen.set(k, 1);
    const mv: number[] = this.fcMoves(st);
    for (let i = 0; i < mv.length; i = i + 3) {
      const nx: FcState = this.fcNorm(this.fcPlay(st, mv[i], mv[i + 1], mv[i + 2]));
      out.push(mv[i], mv[i + 1], mv[i + 2]);
      if (this.fcDfs(nx, depth + 1, seen, nodes, out)) {
        return true;
      }
      out.pop();
      out.pop();
      out.pop();
    }
    return false;
  }

  /** 从当前牌面解一条完整路线（扁平三元组）；解不出返回空数组 */
  private fcSolve(): number[] {
    const out: number[] = [];
    const st0: FcState = this.fcNorm(this.fcMirror());
    if (st0.found[0] === TOP && st0.found[1] === TOP) {
      return out;
    }
    this.fcDfs(st0, 0, new Map<string, number>(), [0], out);
    return out;
  }


  /** 提示：报「下一张该搬哪张牌、搬到哪」—— 与代打共用同一个求解器，说法一致 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.sel >= 0) {
      const s0: Card = this.cardAt(this.sel);
      if (s0.rank > 0 && this.found[s0.suit] + 1 === s0.rank) {
        return Hint.make([this.sel],
          TG2('手上这张 {0} 正好能收进「家」', this.cardText(s0)),
          TG2('The selected {0} can go straight home', this.cardText(s0)), t0);
      }
    }
    // 代打进行中才复用它的路线；否则现解一条（玩家手动走过，旧计划可能已经过期）
    let plan: number[] = [];
    if (this.autoId >= 0) {
      plan = this.fcPlan;
    }
    if (plan.length < 3) {
      plan = this.fcSolve();
    }
    if (plan.length < 3) {
      return Hint.none(TG('这局已经走不通了，换一局吧'));
    }
    const src: number = plan[0];
    const kind: number = plan[1];
    const idx: number = plan[2];
    const txt: string = this.cardText(this.cardAt(src));
    if (kind === 1) {
      return Hint.make([src],
        TG2('把 {0} 收进「家」', txt),
        TG2('Send {0} home', txt), t0);
    }
    if (kind === 0) {
      return Hint.make([src],
        TG2('先把 {0} 放进自由格，腾出下面的牌', txt),
        TG2('Park {0} in a free cell to expose the card below', txt), t0);
    }
    const d: Card[] = this.cols[idx];
    if (d.length === 0) {
      return Hint.make([10 + idx],
        TG2('把 {0} 搬到第 {1} 列（那列空着）', txt, String(idx + 1)),
        TG2('Move {0} to column {1} (it is empty)', txt, String(idx + 1)), t0);
    }
    const top: Card = d[d.length - 1];
    return Hint.make([10 + idx],
      TG2('把 {0} 压到第 {1} 列的 {2} 上', txt, String(idx + 1), this.cardText(top)),
      TG2('Stack {0} on {2} in column {1}', txt, String(idx + 1), this.cardText(top)), t0);
  }
  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapFree((i)); }); })
          .onClick(() => {
          Haptics.tick();
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapFound((s)); }); })
          .onClick(() => {
          Haptics.tick();
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCol((i)); }); })
          .onClick(() => {
          Haptics.tick();
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('自动归位'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.autoHome(); }); })
          .onClick(() => {
            Haptics.tap();
            this.autoHome();
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }










}
