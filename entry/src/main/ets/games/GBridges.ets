/**
 * 桥梁（Hashi / Bridges）—— 5×5 棋盘上按数字架桥
 *
 * 规则：
 *   · 两岛之间最多 2 座桥；同一行/列、中间没有别的岛才能连
 *   · 桥不能交叉；岛上的数字 = 连到它的桥数（必须刚好相等）
 *   · 全部数字满足，且所有岛连成一片 ⇒ 通关
 * 出题：随机撒岛 → 随机生成一棵「可连且不交叉」的生成树 → 再补些额外桥 ⇒ 一定有解
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5;              // 棋盘边
const CELLS: number = N * N;
const K: number = 7;              // 岛数
const MAX_BRIDGE: number = 2;     // 两岛之间最多 2 座桥
const MAX_DEG: number = 8;        // 岛的数字上限
const EXTRA_P: number = 0.35;     // 补桥概率
const MAX_WRONG: number = 10;
const TICK_MS: number = 1000;
const KEY_H: number = 46;
const ISLE: string = '72%';       // 岛圆点占格子的比例

interface Board {
  ix: number[];
  iy: number[];
  val: number[];
  link: number[];
}

function shuffled(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

/** 同一行/列、中间没有别的岛 ⇒ 可以架桥 */
function visible(a: number, b: number, ix: number[], iy: number[], n: number): boolean {
  if (a === b) {
    return false;
  }
  if (iy[a] === iy[b]) {
    // 同一行：看 x 方向有没有别的岛夹在中间
    const x1: number = Math.min(ix[a], ix[b]);
    const x2: number = Math.max(ix[a], ix[b]);
    if (x2 - x1 < 2) {
      return false;
    }
    for (let k = 0; k < n; k++) {
      if (k !== a && k !== b && iy[k] === iy[a] && ix[k] > x1 && ix[k] < x2) {
        return false;
      }
    }
    return true;
  }
  if (ix[a] === ix[b]) {
    // 同一列：看 y 方向有没有别的岛夹在中间
    const y1: number = Math.min(iy[a], iy[b]);
    const y2: number = Math.max(iy[a], iy[b]);
    if (y2 - y1 < 2) {
      return false;
    }
    for (let k = 0; k < n; k++) {
      if (k !== a && k !== b && ix[k] === ix[a] && iy[k] > y1 && iy[k] < y2) {
        return false;
      }
    }
    return true;
  }
  return false;
}

/** 两座桥是否十字交叉 */
function crosses(a: number, b: number, u: number, v: number, ix: number[], iy: number[]): boolean {
  let h1: number = -1;
  let h2: number = -1;
  let v1: number = -1;
  let v2: number = -1;
  if (iy[a] === iy[b]) {
    h1 = a;
    h2 = b;
  } else {
    v1 = a;
    v2 = b;
  }
  if (iy[u] === iy[v]) {
    if (h1 >= 0) {
      return false;
    }
    h1 = u;
    h2 = v;
  } else {
    if (v1 >= 0) {
      return false;
    }
    v1 = u;
    v2 = v;
  }
  const hy: number = iy[h1];
  const hx1: number = Math.min(ix[h1], ix[h2]);
  const hx2: number = Math.max(ix[h1], ix[h2]);
  const vx: number = ix[v1];
  const vy1: number = Math.min(iy[v1], iy[v2]);
  const vy2: number = Math.max(iy[v1], iy[v2]);
  return vx > hx1 && vx < hx2 && hy > vy1 && hy < vy2;
}

function crossAny(a: number, b: number, link: number[], ix: number[], iy: number[], n: number): boolean {
  for (let u = 0; u < n; u++) {
    for (let v = u + 1; v < n; v++) {
      if (u === a && v === b) {
        continue;
      }
      if (link[u * n + v] <= 0) {
        continue;
      }
      if (crosses(a, b, u, v, ix, iy)) {
        return true;
      }
    }
  }
  return false;
}

function deg(link: number[], i: number, n: number): number {
  let s: number = 0;
  for (let j = 0; j < n; j++) {
    s = s + link[i * n + j];
  }
  return s;
}

/** 可架桥的图上是否连通 */
function connectedByVisible(ix: number[], iy: number[], n: number): boolean {
  const seen: boolean[] = new Array<boolean>(n).fill(false);
  seen[0] = true;
  const queue: number[] = [0];
  let head: number = 0;
  while (head < queue.length) {
    const a: number = queue[head];
    head++;
    for (let b = 0; b < n; b++) {
      if (!seen[b] && visible(a, b, ix, iy, n)) {
        seen[b] = true;
        queue.push(b);
      }
    }
  }
  return queue.length === n;
}

/** 已架的桥是否连通所有岛 */
function connectedByLink(link: number[], n: number): boolean {
  const seen: boolean[] = new Array<boolean>(n).fill(false);
  seen[0] = true;
  const queue: number[] = [0];
  let head: number = 0;
  while (head < queue.length) {
    const a: number = queue[head];
    head++;
    for (let b = 0; b < n; b++) {
      if (!seen[b] && link[a * n + b] > 0) {
        seen[b] = true;
        queue.push(b);
      }
    }
  }
  return queue.length === n;
}

/** 随机生成树：每次从「树内 → 树外」的可连边里随机挑一条 */
function growTree(ix: number[], iy: number[], n: number): number[] {
  const link: number[] = new Array<number>(n * n).fill(0);
  const used: boolean[] = new Array<boolean>(n).fill(false);
  used[0] = true;
  let count: number = 1;
  while (count < n) {
    const cand: number[] = [];
    for (let u = 0; u < n; u++) {
      if (!used[u]) {
        continue;
      }
      for (let v = 0; v < n; v++) {
        if (used[v] || u === v) {
          continue;
        }
        if (!visible(u, v, ix, iy, n) || crossAny(u, v, link, ix, iy, n)) {
          continue;
        }
        cand.push(u * n + v);
      }
    }
    if (cand.length === 0) {
      return [];
    }
    const pick: number = cand[Math.floor(Math.random() * cand.length)];
    const a: number = Math.floor(pick / n);
    const b: number = pick % n;
    const w: number = Math.random() < 0.5 ? 1 : 2;
    link[a * n + b] = w;
    link[b * n + a] = w;
    used[b] = true;
    count++;
  }
  return link;
}

/** 再补些桥，让数字更大更有嚼头 */
function addExtra(link: number[], ix: number[], iy: number[], n: number): void {
  const order: number[] = shuffled(n * n);
  for (let t = 0; t < order.length; t++) {
    const p: number = order[t];
    const a: number = Math.floor(p / n);
    const b: number = p % n;
    if (a === b || link[p] <= 0 || link[p] >= MAX_BRIDGE) {
      continue;
    }
    if (Math.random() > EXTRA_P) {
      continue;
    }
    if (deg(link, a, n) + 1 > MAX_DEG || deg(link, b, n) + 1 > MAX_DEG) {
      continue;
    }
    if (crossAny(a, b, link, ix, iy, n)) {
      continue;
    }
    const w: number = link[p] + 1;
    link[a * n + b] = w;
    link[b * n + a] = w;
  }
}

interface IslandPos {
  x: number[];
  y: number[];
}

/** 从第一座岛开始，一座一座「看得见地」长出来 ⇒ 可连图必定连通 */
function sprinkle(k: number, size: number): IslandPos | null {
  for (let attempt = 0; attempt < 300; attempt++) {
    const ix: number[] = [];
    const iy: number[] = [];
    ix.push(Math.floor(Math.random() * size));
    iy.push(Math.floor(Math.random() * size));
    let guard: number = 0;
    while (ix.length < k && guard < 600) {
      guard++;
      const a: number = Math.floor(Math.random() * ix.length);
      const horiz: boolean = Math.random() < 0.5;
      const dist: number = 2 + Math.floor(Math.random() * (size - 2));
      const sgn: number = Math.random() < 0.5 ? -1 : 1;
      const nx: number = horiz ? ix[a] + sgn * dist : ix[a];
      const ny: number = horiz ? iy[a] : iy[a] + sgn * dist;
      if (nx < 0 || nx >= size || ny < 0 || ny >= size) {
        continue;
      }
      let ok: boolean = true;
      for (let j = 0; j < ix.length; j++) {
        if (ix[j] === nx && Math.abs(iy[j] - ny) < 2) {
          ok = false;
        }
        if (iy[j] === ny && Math.abs(ix[j] - nx) < 2) {
          ok = false;
        }
      }
      if (!ok) {
        continue;
      }
      for (let j = 0; j < ix.length; j++) {
        if (horiz && iy[j] === ny) {
          const lo: number = Math.min(ix[a], nx);
          const hi: number = Math.max(ix[a], nx);
          if (ix[j] > lo && ix[j] < hi) {
            ok = false;
          }
        }
        if (!horiz && ix[j] === nx) {
          const lo: number = Math.min(iy[a], ny);
          const hi: number = Math.max(iy[a], ny);
          if (iy[j] > lo && iy[j] < hi) {
            ok = false;
          }
        }
      }
      if (!ok) {
        continue;
      }
      ix.push(nx);
      iy.push(ny);
    }
    if (ix.length === k && connectedByVisible(ix, iy, k)) {
      const out: IslandPos = { x: ix, y: iy };
      return out;
    }
  }
  return null;
}

function makeBoard(k: number, size: number): Board | null {
  for (let attempt = 0; attempt < 300; attempt++) {
    const pos: IslandPos | null = sprinkle(k, size);
    if (pos === null) {
      continue;
    }
    const ix: number[] = pos.x;
    const iy: number[] = pos.y;
    const link: number[] = growTree(ix, iy, k);
    if (link.length === 0) {
      continue;
    }
    addExtra(link, ix, iy, k);
    const val: number[] = [];
    let ok: boolean = true;
    for (let i = 0; i < k; i++) {
      const d: number = deg(link, i, k);
      val.push(d);
      if (d < 1 || d > MAX_DEG) {
        ok = false;
      }
    }
    if (!ok) {
      continue;
    }
    const out: Board = { ix: ix, iy: iy, val: val, link: link };
    return out;
  }
  return null;
}

/** 兜底盘面：等距点阵蛇形连成一条链，稳连通、不交叉 */
function fallbackBoard(k: number, size: number): Board {
  const step: number = 2;
  const ix: number[] = [];
  const iy: number[] = [];
  let y: number = 0;
  let right: boolean = true;
  while (iy.length < k && y < size) {
    if (right) {
      for (let x = 0; x < size && iy.length < k; x = x + step) {
        ix.push(x);
        iy.push(y);
      }
    } else {
      for (let x = size - 1; x >= 0 && iy.length < k; x = x - step) {
        ix.push(x);
        iy.push(y);
      }
    }
    right = !right;
    y = y + step;
  }
  const n: number = ix.length;
  const link: number[] = new Array<number>(n * n).fill(0);
  for (let i = 0; i + 1 < n; i++) {
    link[i * n + i + 1] = 1;
    link[(i + 1) * n + i] = 1;
  }
  const val: number[] = [];
  for (let i = 0; i < n; i++) {
    val.push(deg(link, i, n));
  }
  const out: Board = { ix: ix, iy: iy, val: val, link: link };
  return out;
}

/** 由桥反推每格该显示什么：0 空 1 横一 2 横二 3 竖一 4 竖二 */
function segments(link: number[], ix: number[], iy: number[], n: number, size: number): number[] {
  const seg: number[] = new Array<number>(size * size).fill(0);
  for (let a = 0; a < n; a++) {
    for (let b = a + 1; b < n; b++) {
      const c: number = link[a * n + b];
      if (c <= 0) {
        continue;
      }
      if (iy[a] === iy[b]) {
        const y: number = iy[a];
        const x1: number = Math.min(ix[a], ix[b]);
        const x2: number = Math.max(ix[a], ix[b]);
        for (let x = x1 + 1; x < x2; x++) {
          seg[y * size + x] = c === 1 ? 1 : 2;
        }
      } else if (ix[a] === ix[b]) {
        const x: number = ix[a];
        const y1: number = Math.min(iy[a], iy[b]);
        const y2: number = Math.max(iy[a], iy[b]);
        for (let y = y1 + 1; y < y2; y++) {
          seg[y * size + x] = c === 1 ? 3 : 4;
        }
      }
    }
  }
  return seg;
}

@Component
export struct GBridges {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：K 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(K);
  onFinish: (r: GameResult) => void = () => {};

  @State private ix: number[] = [];
  @State private iy: number[] = [];
  @State private val: number[] = [];
  @State private link: number[] = [];
  @State private seg: number[] = [];
  @State private sel: number = -1;
  @State private steps: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private hints: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;

  private sol: number[] = [];
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBridges')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(K);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    const made: Board | null = makeBoard(this.diffTotal, N);
    const b: Board = made === null ? fallbackBoard(this.diffTotal, N) : made;
    this.ix = b.ix;
    this.iy = b.iy;
    this.val = b.val;
    this.sol = b.link.slice();                                  // 参考答案（提示用）
    const n: number = this.ix.length;
    this.link = new Array<number>(n * n).fill(0);               // ★ 玩家从零座桥开始
    this.seg = segments(this.link, this.ix, this.iy, n, N);
    this.sel = -1;
    this.steps = 0;
    this.wrong = 0;
    this.hints = 0;
    this.seconds = 0;
    this.status = TG('点一个岛 → 点另一个岛，桥数 0→1→2→0 循环');
    this.done = false;
    this.finished = false;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.done && !this.finished) {
        this.seconds = this.seconds + 1;
      }
    }, TICK_MS);
  }

  private stopTimer(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private islandAt(cell: number): number {
    for (let i = 0; i < this.ix.length; i++) {
      if (this.iy[i] * N + this.ix[i] === cell) {
        return i;
      }
    }
    return -1;
  }

  private degOf(i: number): number {
    return deg(this.link, i, this.ix.length);
  }

  private bridgesOn(): number {
    const n: number = this.ix.length;
    let s: number = 0;
    for (let a = 0; a < n; a++) {
      for (let b = a + 1; b < n; b++) {
        s = s + this.link[a * n + b];
      }
    }
    return s;
  }

  private bridgesNeed(): number {
    let s: number = 0;
    for (let i = 0; i < this.val.length; i++) {
      s = s + this.val[i];
    }
    return Math.floor(s / 2);
  }

  private doneIslands(): number {
    let n: number = 0;
    for (let i = 0; i < this.val.length; i++) {
      if (this.degOf(i) === this.val[i]) {
        n++;
      }
    }
    return n;
  }

  private tapCell(cell: number): void {
    if (this.done || this.finished) {
      return;
    }
    const isl: number = this.islandAt(cell);
    if (isl < 0) {
      this.status = TG('空格子不能站，点带数字的圆点');
      return;
    }
    if (this.sel < 0) {
      this.sel = isl;
      this.status = TG('再点一个能直连的岛架桥');
      return;
    }
    if (this.sel === isl) {
      this.sel = -1;
      this.status = TG('已取消选择');
      return;
    }
    this.tryLink(this.sel, isl);
  }

  private tryLink(a: number, b: number): void {
    const n: number = this.ix.length;
    if (!visible(a, b, this.ix, this.iy, n)) {
      this.penalty(TG('这两个岛不在同一条直线，或中间隔着别的岛'));
      return;
    }
    const cur: number = this.link[a * n + b];
    const next: number = (cur + 1) % 3;
    if (next > cur) {
      if (this.degOf(a) - cur + next > this.val[a] || this.degOf(b) - cur + next > this.val[b]) {
        this.penalty(TG('岛上的数字要刚好相等，这个岛已经满了'));
        return;
      }
      if (crossAny(a, b, this.link, this.ix, this.iy, n)) {
        this.penalty(TG('桥不能交叉'));
        return;
      }
    }
    const link: number[] = this.link.slice();
    link[a * n + b] = next;
    link[b * n + a] = next;
    this.link = link;
    this.seg = segments(link, this.ix, this.iy, n, N);
    this.sel = -1;
    this.steps = this.steps + 1;
    this.status = next === 0 ? '拆掉一座桥' : TG2("架了 {0} 座桥", next);
    if (this.isWin()) {
      this.done = true;
      this.status = TG('🎉 数字全对、全岛连通！');
      this.finish(true);
    }
  }

  /** 提示：照参考答案补上「第一对还差桥的岛」 */
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款本来就有 this.sol + hint()（提示按钮调的就是它）
  // ⇒ 代打只要反复调 hint()，直到补不动为止。
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.done || this.finished) {
      return false;
    }
    const before: number = this.bridgesOn();
    this.hint();
    return !this.done && this.bridgesOn() > before;
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

  private hint(): void {
    if (this.done || this.finished || this.sol.length === 0) {
      return;
    }
    const n: number = this.ix.length;
    for (let a = 0; a < n; a++) {
      for (let b = a + 1; b < n; b++) {
        const want: number = this.sol[a * n + b];
        const cur: number = this.link[a * n + b];
        if (want <= cur) {
          continue;
        }
        // 自己先把合法性查一遍：提示绝不能变成「违规 +1」
        if (!visible(a, b, this.ix, this.iy, n)) {
          continue;
        }
        if (this.degOf(a) + 1 > this.val[a] || this.degOf(b) + 1 > this.val[b]) {
          continue;
        }
        if (crossAny(a, b, this.link, this.ix, this.iy, n)) {
          continue;
        }
        this.tryLink(a, b);
        if (this.link[a * n + b] > cur) {
          this.hints = this.hints + 1;
          this.status = TG2('提示：{0} 号岛与 {1} 号岛之间要 {2} 座桥', a, b, want);
          return;
        }
      }
    }
    this.status = TG('照参考解补不动了，先拆掉几座挡路的桥');
  }

  private penalty(msg: string): void {
    this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    this.status = msg;
    if (this.wrong >= MAX_WRONG) {
      this.done = true;
      this.status = TG2("违规满 {0} 次，这一局没通关",Digits(String(MAX_WRONG), this.langCode));
      this.finish(false);
    }
  }

  private isWin(): boolean {
    for (let i = 0; i < this.val.length; i++) {
      if (this.degOf(i) !== this.val[i]) {
        return false;
      }
    }
    return connectedByLink(this.link, this.ix.length);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const r: GameResult = {
      gameId: 'bridges',
      solved: solved,
      score: solved ? Math.max(150, 1000 - this.steps * 8 - this.wrong * 60 - this.hints * 150 - this.seconds * 2) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneIslands()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      Column() {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row() {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              this.cellView(r * N + c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('88%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor('#1AEC4899')
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        Button(TG('拆光重来'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.done || this.finished) { return; } const n: number = this.ix.length; this.link = new Array<number>(n * n).fill(0); this.seg = segments(this.link, this.ix, this.iy, n, N); this.sel = -1; this.status = TG('桥都拆了，重新来'); }); })
          .onClick(() => {
            Haptics.tap();
            if (this.done || this.finished) {
              return;
            }
            const n: number = this.ix.length;
            this.link = new Array<number>(n * n).fill(0);
            this.seg = segments(this.link, this.ix, this.iy, n, N);
            this.sel = -1;
            this.status = TG('桥都拆了，重新来');
          })
        Button(TG('提示'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.hint(); }); })
          .onClick(() => {
            Haptics.tap();
            this.hint();
          })
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('放弃'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (!this.finished) { this.done = true; this.status = TG('已放弃这一局'); this.finish(false); } }); })
          .onClick(() => {
            Haptics.tap();
            if (!this.finished) {
              this.done = true;
              this.status = TG('已放弃这一局');
              this.finish(false);
            }
          })
      }
      .width('100%')

      Text(this.status + TG2('　违规 {0}/{1}', this.wrong, MAX_WRONG))
        .fontSize(FontSize.sm)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)
        .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /** kind: 0=桥 1=完成岛 2=用时 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('桥') : (kind === 1 ? '完成岛' : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? (this.bridgesOn() + '/' + this.bridgesNeed())
        : (kind === 1 ? (this.doneIslands() + '/' + this.diffTotal) : (this.seconds + 's')))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  cellView(cell: number) {
    Stack() {
      if (this.islandAt(cell) >= 0) {
        Text(String(this.val[this.islandAt(cell)]))
          .fontSize(FontSize.md)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width(ISLE)
          .aspectRatio(1)
          .backgroundColor(this.isleColor(this.islandAt(cell)))
          .borderRadius(Radius.full)
          .borderWidth(this.sel === this.islandAt(cell) ? 3 : 0)
          .borderColor(Palette.amber)
      } else if (this.glyphOf(cell) !== '') {
        Text(this.glyphOf(cell))
          .fontSize(FontSize.lg)
          .fontColor(Palette.berry)
      }
    }
    .layoutWeight(1)
    .aspectRatio(1)
    // ★★ 2026-10-14 修复【死动画】：原来这里读的都是常量 ⇒ .animation() 从不触发
    //    现在绑【选中状态】⇒ 选中的岛会弹大一点（动画真的活了）
    .scale({
      x: (this.sel >= 0 && this.sel === this.islandAt(cell)) ? 1.08 : 1,
      y: (this.sel >= 0 && this.sel === this.islandAt(cell)) ? 1.08 : 1
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell(cell); }); })
    .onClick(() => {
      Haptics.tick();
      this.tapCell(cell);
    })
  }

  private glyphOf(cell: number): string {
    const s: number = cell < this.seg.length ? this.seg[cell] : 0;
    if (s === 1) {
      return '─';
    }
    if (s === 2) {
      return '═';
    }
    if (s === 3) {
      return '│';
    }
    if (s === 4) {
      return '║';
    }
    return '';
  }

  private isleColor(i: number): string {
    if (i === this.sel) {
      return Palette.primary;
    }
    if (this.degOf(i) === this.val[i]) {
      return Palette.emerald;
    }
    return this.degOf(i) > 0 ? Palette.sky : this.theme.inkFaint;
  }
}
