/**
 * 明灯（Akari / Light Up）—— 用灯照亮所有空格
 *
 * 规则：
 *   · 灯照亮自己所在格，并向上下左右直照，遇到黑墙停
 *   · 两盏灯不能互相照到（之间有墙才行）
 *   · 墙上的数字 = 紧挨着它的灯数量，必须刚好相等
 * 判据：所有空格都被照亮 + 墙上数字全部满足 ⇒ 通关；违规满 8 次 ⇒ 失败
 * 出题：先随机摆墙，再用「贪心 + 随机」求出一组合法灯位 ⇒ 题目一定有解
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const CELLS: number = N * N;
const WALL_P: number = 0.22;      // 每格是墙的概率
const MAX_TRY: number = 300;
const MAX_WRONG: number = 8;
const TICK_MS: number = 1000;
const GAP: number = 2;
const KEY_H: number = 46;

interface Level {
  wall: boolean[];
  clue: number[];     // 墙上的数字；-1 表示不是墙 / 没有数字
  bulb: number[];     // 参考解
}

/** 从已有灯出发算照亮情况 */
function computeLit(wall: boolean[], bulb: number[]): boolean[] {
  const lit: boolean[] = new Array<boolean>(CELLS).fill(false);
  const dirs: number[][] = [[0, -1], [0, 1], [-1, 0], [1, 0]];
  for (let i = 0; i < CELLS; i++) {
    if (bulb[i] === 0) {
      continue;
    }
    lit[i] = true;
    const x: number = i % N;
    const y: number = Math.floor(i / N);
    for (let d = 0; d < 4; d++) {
      let cx: number = x + dirs[d][0];
      let cy: number = y + dirs[d][1];
      while (cx >= 0 && cx < N && cy >= 0 && cy < N) {
        const k: number = cy * N + cx;
        if (wall[k]) {
          break;
        }
        lit[k] = true;
        cx = cx + dirs[d][0];
        cy = cy + dirs[d][1];
      }
    }
  }
  return lit;
}

/** 这格能不能放灯（四方向到墙之间没有别的灯） */
function canBulb(wall: boolean[], bulb: number[], idx: number): boolean {
  if (wall[idx] || bulb[idx] === 1) {
    return false;
  }
  const x: number = idx % N;
  const y: number = Math.floor(idx / N);
  const dirs: number[][] = [[0, -1], [0, 1], [-1, 0], [1, 0]];
  for (let d = 0; d < 4; d++) {
    let cx: number = x + dirs[d][0];
    let cy: number = y + dirs[d][1];
    while (cx >= 0 && cx < N && cy >= 0 && cy < N) {
      const k: number = cy * N + cx;
      if (wall[k]) {
        break;
      }
      if (bulb[k] === 1) {
        return false;
      }
      cx = cx + dirs[d][0];
      cy = cy + dirs[d][1];
    }
  }
  return true;
}

/** 放灯能新照亮几个还没亮的空格 */
function gainOf(wall: boolean[], bulb: number[], lit: boolean[], idx: number): number {
  const probe: number[] = bulb.slice();
  probe[idx] = 1;
  const after: boolean[] = computeLit(wall, probe);
  let gain: number = 0;
  for (let i = 0; i < CELLS; i++) {
    if (!wall[i] && !lit[i] && after[i]) {
      gain++;
    }
  }
  return gain;
}

/** 贪心摆灯：每次挑「新照亮最多」的位置，带随机打破平局 */
function trySolve(wall: boolean[]): number[] | null {
  const bulb: number[] = new Array<number>(CELLS).fill(0);
  for (let step = 0; step < CELLS; step++) {
    const lit: boolean[] = computeLit(wall, bulb);
    let unlit: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (!wall[i] && !lit[i]) {
        unlit++;
      }
    }
    if (unlit === 0) {
      return bulb;
    }
    let best: number = -1;
    let bestGain: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (!canBulb(wall, bulb, i)) {
        continue;
      }
      const g: number = gainOf(wall, bulb, lit, i);
      if (g > bestGain || (g === bestGain && g > 0 && Math.random() < 0.4)) {
        best = i;
        bestGain = g;
      }
    }
    if (best < 0 || bestGain === 0) {
      return null;
    }
    bulb[best] = 1;
  }
  return null;
}

function makeLevel(): Level {
  for (let attempt = 0; attempt < MAX_TRY; attempt++) {
    const wall: boolean[] = new Array<boolean>(CELLS).fill(false);
    for (let i = 0; i < CELLS; i++) {
      wall[i] = Math.random() < WALL_P;
    }
    const sol: number[] | null = trySolve(wall);
    if (sol === null) {
      continue;
    }
    const clue: number[] = new Array<number>(CELLS).fill(-1);
    for (let i = 0; i < CELLS; i++) {
      if (!wall[i]) {
        continue;
      }
      const x: number = i % N;
      const y: number = Math.floor(i / N);
      let n: number = 0;
      if (x > 0 && sol[i - 1] === 1) {
        n++;
      }
      if (x < N - 1 && sol[i + 1] === 1) {
        n++;
      }
      if (y > 0 && sol[i - N] === 1) {
        n++;
      }
      if (y < N - 1 && sol[i + N] === 1) {
        n++;
      }
      clue[i] = n;
    }
    const out: Level = { wall: wall, clue: clue, bulb: sol };
    return out;
  }
  // 兜底：全空的 6×6（贪心必能照亮）
  const wall: boolean[] = new Array<boolean>(CELLS).fill(false);
  const clue: number[] = new Array<number>(CELLS).fill(-1);
  const sol: number[] = new Array<number>(CELLS).fill(0);
  sol[0] = 1;
  sol[4] = 1;
  sol[2 * N + 2] = 1;
  sol[4 * N + 4] = 1;
  const out: Level = { wall: wall, clue: clue, bulb: sol };
  return out;
}

@Component
export struct GAkari {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：容错次数（简单 12 / 普通 8 / 困难 5）
  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_WRONG);
  onFinish: (r: GameResult) => void = () => {};

  @State private wall: boolean[] = [];
  @State private clue: number[] = [];
  @State private bulbs: number[] = [];
  @State private wrong: number = 0;
  @State private seconds: number = 0;
  @State private status: string = '';
  @State private done: boolean = false;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';

  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAkari')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_WRONG);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private reset(): void {
    this.stopTimer();
    const lv: Level = makeLevel();
    this.wall = lv.wall;
    this.clue = lv.clue;
    this.bulbs = new Array<number>(CELLS).fill(0);
    this.wrong = 0;
    this.seconds = 0;
    this.status = TG('点空格放灯，点灯撤掉');
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

  private isWall(i: number): boolean {
    return i >= 0 && i < this.wall.length ? this.wall[i] : false;
  }

  private litNow(): boolean[] {
    return computeLit(this.wall, this.bulbs);
  }

  private bulbCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.bulbs.length; i++) {
      if (this.bulbs[i] === 1) {
        n++;
      }
    }
    return n;
  }

  private litCount(): number {
    const lit: boolean[] = this.litNow();
    let n: number = 0;
    let empty: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (!this.isWall(i)) {
        empty++;
        if (lit[i]) {
          n++;
        }
      }
    }
    return empty === 0 ? 0 : n;
  }

  private emptyCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (!this.isWall(i)) {
        n++;
      }
    }
    return n;
  }


  /**
   * ★ 2026-10-23 第二期：明灯提示
   *
   * 用的是一条**严格成立的局部规则**：
   *   对每个带数字的墙：如果「周围已放的灯数 + 周围还能放灯的空格数」正好等于这个数字，
   *   那么那些空格**必须全部放灯**（不然数字凑不满）。
   *
   * ⚠️ 只说"这一格必须放灯"，不说"这一格不能放"（后者需要更复杂的推理）。
   *    一格都推不出 ⇒ Hint.none()（明灯开局常常确实没有确定步）。
   */
  // ═══════════ 明灯求解器（2026-10-24 第三期）═══════════
  // 明灯的提示原来只有一条计数规则，多数开局触发不了，代打因此立刻停。
  // 6×6 = 36 格，加剪枝的 DFS 在毫秒级就能求出完整解。
  // 有了它：提示能兜底，代打能一路走到底。

  /** 这一格此刻是否被照亮（含它自己有灯） */
  private litAt(i: number, bulbs: number[]): boolean {
    if (bulbs[i] === 1) {
      return true;
    }
    const x: number = i % N;
    const y: number = Math.floor(i / N);
    if (x > 0) {
      for (let k = i - 1; k >= y * N; k--) {
        if (this.wall[k]) {
          break;
        }
        if (bulbs[k] === 1) {
          return true;
        }
      }
    }
    if (x < N - 1) {
      for (let k = i + 1; k < y * N + N; k++) {
        if (this.wall[k]) {
          break;
        }
        if (bulbs[k] === 1) {
          return true;
        }
      }
    }
    if (y > 0) {
      for (let k = i - N; k >= 0; k -= N) {
        if (this.wall[k]) {
          break;
        }
        if (bulbs[k] === 1) {
          return true;
        }
      }
    }
    if (y < N - 1) {
      for (let k = i + N; k < CELLS; k += N) {
        if (this.wall[k]) {
          break;
        }
        if (bulbs[k] === 1) {
          return true;
        }
      }
    }
    return false;
  }

  /** 剪枝：数字墙的余量 + 每个空格是否还"有可能"被照亮 */
  private akariPrune(bulbs: number[], decided: boolean[]): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (!this.wall[i] || this.clue[i] < 0) {
        continue;
      }
      const want: number = this.clue[i];
      const x: number = i % N;
      const y: number = Math.floor(i / N);
      let cnt: number = 0;
      let free: number = 0;
      const nb: number[] = [];
      if (y > 0) { nb.push(i - N); }
      if (y < N - 1) { nb.push(i + N); }
      if (x > 0) { nb.push(i - 1); }
      if (x < N - 1) { nb.push(i + 1); }
      for (let k = 0; k < nb.length; k++) {
        const j: number = nb[k];
        if (this.wall[j]) {
          continue;
        }
        if (bulbs[j] === 1) {
          cnt++;
        } else if (!decided[j]) {
          free++;
        }
      }
      if (cnt > want || cnt + free < want) {
        return false;
      }
    }
    for (let i = 0; i < CELLS; i++) {
      if (this.wall[i] || this.litAt(i, bulbs)) {
        continue;
      }
      // 还没亮：只要还有一格能放灯照到它，就还有希望
      let hope: boolean = false;
      if (!decided[i]) {
        hope = true;
      } else {
        const x: number = i % N;
        const y: number = Math.floor(i / N);
        const dirs: number[][] = [[0, -1], [0, 1], [-1, 0], [1, 0]];
        for (let d = 0; d < 4 && !hope; d++) {
          let cx: number = x + dirs[d][0];
          let cy: number = y + dirs[d][1];
          while (cx >= 0 && cx < N && cy >= 0 && cy < N) {
            const k: number = cy * N + cx;
            if (this.wall[k]) {
              break;
            }
            if (bulbs[k] === 1) {
              hope = true;
              break;
            }
            if (!decided[k]) {
              hope = true;
              break;
            }
            cx = cx + dirs[d][0];
            cy = cy + dirs[d][1];
          }
        }
      }
      if (!hope) {
        return false;
      }
    }
    return true;
  }

  private akariDfs(bulbs: number[], decided: boolean[]): boolean {
    let idx: number = -1;
    for (let i = 0; i < CELLS; i++) {
      if (!this.wall[i] && !decided[i]) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      for (let i = 0; i < CELLS; i++) {
        if (!this.wall[i] && !this.litAt(i, bulbs)) {
          return false;
        }
      }
      return true;
    }
    // 先试"不放灯"
    decided[idx] = true;
    bulbs[idx] = 0;
    if (this.akariPrune(bulbs, decided) && this.akariDfs(bulbs, decided)) {
      return true;
    }
    // 再试"放灯"
    if (canBulb(this.wall, bulbs, idx)) {
      bulbs[idx] = 1;
      if (this.akariPrune(bulbs, decided) && this.akariDfs(bulbs, decided)) {
        return true;
      }
      bulbs[idx] = 0;
    }
    decided[idx] = false;
    return false;
  }

  /** 求一组完整灯位；无解返回空数组 */
  private solveAkari(): number[] {
    const bulbs: number[] = new Array<number>(CELLS).fill(0);
    const decided: boolean[] = new Array<boolean>(CELLS).fill(false);
    if (!this.akariDfs(bulbs, decided)) {
      return [];
    }
    const out: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (bulbs[i] === 1) {
        out.push(i);
      }
    }
    return out;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let i = 0; i < CELLS; i++) {
      const want: number = this.clue[i];
      if (!this.wall[i] || want < 0) {
        continue;
      }
      const x: number = i % N;
      const y: number = Math.floor(i / N);
      let haveBulb: number = 0;
      let freeCnt: number = 0;
      let onlyIdx: number = -1;
      // 四个方向紧邻的格（只差一位，不沿射线走）
      const nb: number[] = [];
      if (y > 0) { nb.push(i - N); }
      if (y < N - 1) { nb.push(i + N); }
      if (x > 0) { nb.push(i - 1); }
      if (x < N - 1) { nb.push(i + 1); }
      for (let k = 0; k < nb.length; k++) {
        const j: number = nb[k];
        if (this.wall[j]) {
          continue;
        }
        if (this.bulbs[j] === 1) {
          haveBulb++;
        } else {
          freeCnt++;
          onlyIdx = j;
        }
      }
      if (haveBulb + freeCnt !== want || freeCnt === 0) {
        continue;
      }
      // freeCnt 个空格必须全部放灯 ⇒ 报第一个
      if (onlyIdx >= 0 && canBulb(this.wall, this.bulbs, onlyIdx)) {
        const r: number = Math.floor(onlyIdx / N) + 1;
        const c: number = (onlyIdx % N) + 1;
        return Hint.make([onlyIdx],
          TG4('第 {0} 行第 {1} 列必须放灯（旁边那个 {2} 的数字还剩 {3} 个空位）',
            String(r), String(c), String(want), String(freeCnt)),
          TG4('Row {0}, column {1} must get a lamp (that {2} still needs {3})',
            String(r), String(c), String(want), String(freeCnt)), t0);
      }
    }
    // ★ 2026-10-24 第三期：计数规则找不到时，用求解器兜底
    const sol: number[] = this.solveAkari();
    if (sol.length > 0) {
      for (let k = 0; k < sol.length; k++) {
        const i: number = sol[k];
        if (this.bulbs[i] !== 1 && canBulb(this.wall, this.bulbs, i)) {
          const r: number = Math.floor(i / N) + 1;
          const c: number = (i % N) + 1;
          return Hint.make([i],
            TG2('第 {0} 行第 {1} 列可以放灯（求解器算出来的完整解里就有这一盏）',
              String(r), String(c)),
            TG2('Row {0}, column {1} takes a lamp (part of the full solution)',
              String(r), String(c)), t0);
        }
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第二期：AI 代打（明灯，一次放一盏灯）
   *
   * 直接复用 computeHint()：
   * 它已经能算出"某格必须放灯"，这里只要把那一格放上去。
   */
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
    const sol: number[] = this.solveAkari();
    if (sol.length === 0) {
      return false;
    }
    for (let k = 0; k < sol.length; k++) {
      const i: number = sol[k];
      if (this.bulbs[i] !== 1 && canBulb(this.wall, this.bulbs, i)) {
        this.tap(i);
        return !this.done;
      }
    }
    return false;
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
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.status = r.zh;
      setTimeout(() => { this.status = ''; }, 5000);
      return;
    }
    this.status = TG('这一步看不出哪格必须放灯，先随便点几个试试');
    setTimeout(() => { this.status = ''; }, 5000);
  }

  private tap(i: number): void {
    if (this.done || this.finished || this.isWall(i) || i < 0 || i >= CELLS) {
      return;
    }
    const next: number[] = this.bulbs.slice();
    if (next[i] === 1) {
      next[i] = 0;
      this.bulbs = next;
      this.status = TG('撤掉一盏灯');
      return;
    }
    if (!canBulb(this.wall, next, i)) {
      this.wrong = this.wrong + 1;
      this.status = TG('这盏灯会照到别的灯，换个位置');
      if (this.wrong >= this.diffTotal) {
        this.done = true;
        this.status = TG2("违规满 {0} 次，这一局没通关",Digits(String(this.diffTotal), this.langCode));
        this.finish(false);
      }
      return;
    }
    next[i] = 1;
    this.bulbs = next;
    this.status = TG('放下一盏灯');
    if (this.isWin()) {
      this.done = true;
      this.status = TG('🎉 全部照亮，灯位也对！');
      this.finish(true);
    }
  }

  private isWin(): boolean {
    const lit: boolean[] = this.litNow();
    for (let i = 0; i < CELLS; i++) {
      if (!this.isWall(i) && !lit[i]) {
        return false;
      }
    }
    for (let i = 0; i < CELLS; i++) {
      if (!this.isWall(i) || this.clue[i] < 0) {
        continue;
      }
      let n: number = 0;
      const x: number = i % N;
      const y: number = Math.floor(i / N);
      if (x > 0 && this.bulbs[i - 1] === 1) {
        n++;
      }
      if (x < N - 1 && this.bulbs[i + 1] === 1) {
        n++;
      }
      if (y > 0 && this.bulbs[i - N] === 1) {
        n++;
      }
      if (y < N - 1 && this.bulbs[i + N] === 1) {
        n++;
      }
      if (n !== this.clue[i]) {
        return false;
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const r: GameResult = {
      gameId: 'akari',
      solved: solved,
      score: solved ? Math.max(150, 1100 - this.seconds * 4 - this.wrong * 80) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.bulbCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      Column({ space: GAP }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: GAP }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              this.cellView(r * N + c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('86%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor('#1AF59E0B')
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        Button(TG('换一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('清空灯'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
          .onClick(() => {
            Haptics.tap();
            if (!this.done && !this.finished) {
              this.bulbs = new Array<number>(CELLS).fill(0);
              this.status = TG('灯都撤掉了');
            }
          })
        Button(TG('放弃'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(KEY_H)
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

      Text(this.status)
        .fontSize(FontSize.sm)
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

  /** kind: 0=已照亮 1=灯数 2=违规 */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '照亮' : (kind === 1 ? '灯' : TG('违规')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? (this.litCount() + '/' + this.emptyCount())
        : (kind === 1 ? String(this.bulbCount()) : (this.wrong + '/' + this.diffTotal)))
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
  cellView(i: number) {
    Stack() {
      Text(this.markOf(i))
        .fontSize(this.isWall(i) ? FontSize.lg : FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isWall(i) ? '#FFFFFF' : this.theme.ink)
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.cellBg(i))
    .borderRadius(this.isWall(i) ? Radius.xs : Radius.sm)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      Haptics.tick();
      this.tap(i);
    })
  }

  private markOf(i: number): string {
    if (this.isWall(i)) {
      const c: number = i < this.clue.length ? this.clue[i] : -1;
      return c > 0 ? String(c) : '';
    }
    return i < this.bulbs.length && this.bulbs[i] === 1 ? '💡' : '';
  }

  private cellBg(i: number): string {
    if (this.isWall(i)) {
      return this.theme.isDark ? '#2B2B33' : '#3F3F46';
    }
    if (i < this.bulbs.length && this.bulbs[i] === 1) {
      return '#FDE68A';
    }
    const lit: boolean[] = this.litNow();
    if (i < lit.length && lit[i]) {
      return this.theme.isDark ? '#3A3320' : '#FEF3C7';
    }
    return this.theme.surface;
  }
}
