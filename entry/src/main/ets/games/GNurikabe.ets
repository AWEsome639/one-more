/**
 * 数墙 nurikabe（5×5）—— 按数字造墙：每个数字是一块恰含该格数的"岛"，其余格涂黑成连通墙
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：岛格数全对 + 墙连通无 2×2 ⇒ solved:true；不可逆错手 3 次 ⇒ solved:false
 * 进度：已满足提示 ／ 黑格数 ／ 错手数
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，
//   而数组原来按 CELLS = 25 开 ⇒【困难档必越界】✗）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;

/** 3 关提示（数字 = 该岛格数，0 = 无提示）；每关都有合法解 */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    0,3,0,0,0,
    0,0,0,0,0,
    3,0,0,0,2,
    0,0,0,0,0,
    3,0,0,0,0
  ],
  // 第 2 关
  [
    3,0,1,0,2,
    0,0,0,0,0,
    0,0,2,0,0,
    0,0,0,0,0,
    0,2,0,0,1
  ],
  // 第 3 关
  [
    2,0,0,2,0,
    0,0,0,0,0,
    2,0,0,0,0,
    0,0,0,4,0,
    0,1,0,0,0
  ]
];
const NURI_SOL: number[][] = [
  // 与 CLUE_LIB 一一对应：1 = 涂黑，0 = 白（离线算出来的合法解）
  [
    1, 0, 0, 0, 1,
    1, 1, 1, 1, 1,
    0, 0, 0, 1, 0,
    1, 1, 1, 1, 0,
    0, 0, 0, 1, 1
  ],
  [
    0, 1, 0, 1, 0,
    0, 1, 1, 1, 0,
    0, 1, 0, 0, 1,
    1, 1, 1, 1, 1,
    1, 0, 0, 1, 0
  ],
  [
    0, 0, 1, 0, 1,
    1, 1, 1, 0, 1,
    0, 0, 1, 1, 1,
    1, 1, 1, 0, 0,
    1, 0, 1, 0, 0
  ]
];

@Component
export struct GNurikabe {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」第 16 个：
   *   线索来自 CLUE_LIB，是**手工画的 5×5 = 25 格**，
   *   但原来 diffTotal = sizeNow(5)（4/5/7），棋盘按 diffTotal² 开：
   *     · 简单 4×4：只取前 16 个线索 ⇒ 题面错乱（岛屿形状对不上）
   *     · 困难 7×7：索引 25..48 是 undefined ⇒ **一个线索都没有 ⇒ 无解**
   *   ⇒ 修法：**棋盘固定 5×5**，难度改到容错次数上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = 5;
  /** 本局允许的错误次数：简单 6 / 普通 3 / 困难 2 */
  @State private errMax: number = GNurikabe.errNow();

  private static errNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 6;
    }
    if (d === 2) {
      return 2;
    }
    return 3;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State blacks: number[] = [];   // 1 = 涂黑（墙）
  @State clueTotal: number = 0;
  @State errors: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.errMax = GNurikabe.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.blacks = new Array<number>(MAX_CELLS).fill(0);
    let t: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.clues[i] > 0) {
        t++;
      }
    }
    this.clueTotal = t;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private pushCell(arr: number[], seen: number[], queue: number[], j: number, val: number): void {
    if (arr[j] === val && seen[j] === 0) {
      seen[j] = 1;
      queue.push(j);
    }
  }

  /** 同色连通块（val=0 白 / val=1 黑） */
  private flood(arr: number[], start: number, seen: number[], val: number): number[] {
    const comp: number[] = [];
    const queue: number[] = [start];
    seen[start] = 1;
    let head: number = 0;
    while (head < queue.length) {
      const cur: number = queue[head];
      head++;
      comp.push(cur);
      const r: number = Math.floor(cur / this.diffTotal);
      const c: number = cur % this.diffTotal;
      if (r > 0) {
        this.pushCell(arr, seen, queue, cur - this.diffTotal, val);
      }
      if (r < this.diffTotal - 1) {
        this.pushCell(arr, seen, queue, cur + this.diffTotal, val);
      }
      if (c > 0) {
        this.pushCell(arr, seen, queue, cur - 1, val);
      }
      if (c < this.diffTotal - 1) {
        this.pushCell(arr, seen, queue, cur + 1, val);
      }
    }
    return comp;
  }

  /** 白区统计：返回 [提示个数, 目标格数] */
  private whiteInfo(arr: number[], comp: number[]): number[] {
    let clues: number = 0;
    let target: number = 0;
    for (let j = 0; j < comp.length; j++) {
      const cl: number = this.clues[comp[j]];
      if (cl > 0) {
        clues++;
        target = cl;
      }
    }
    return [clues, target];
  }

  /** 不可逆违规：2×2 全黑 ／ 已成形的岛超出自己的提示格数 */
  private violations(arr: number[]): boolean {
    for (let r = 0; r < this.diffTotal - 1; r++) {
      for (let c = 0; c < this.diffTotal - 1; c++) {
        const a: number = r * this.diffTotal + c;
        if (arr[a] === 1 && arr[a + 1] === 1 && arr[a + this.diffTotal] === 1 && arr[a + this.diffTotal + 1] === 1) {
          return true;
        }
      }
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (arr[i] === 1 || seen[i] === 1) {
        continue;
      }
      const comp: number[] = this.flood(arr, i, seen, 0);
      const info: number[] = this.whiteInfo(arr, comp);
      if (info[0] === 1 && comp.length > info[1]) {
        return true;
      }
    }
    return false;
  }

  private blackCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1) {
        n++;
      }
    }
    return n;
  }

  /**
   * ★ 2026-10-23 第二期：数墙提示
   *
   * 规则：线索格所在的白色区必须恰好包含它一个线索、且格数等于线索值；
   *       墙要连成一片且不能出现 2×2。
   *
   * 这里用一条严格成立的推理：
   *   **某个线索格的白区已经达到线索值** ⇒ 这些白格不能再扩张
   *   ⇒ 与这个白区相邻的、尚未涂黑的格子必须涂黑
   *
   * 只推「必须黑」，不推「必须白」（这款只有 0/1 两态）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    const total: number = n * n;
    for (let i = 0; i < total; i++) {
      if (this.clues[i] <= 0 || this.blacks[i] === 1) {
        continue;                      // 只看线索格、且它现在是白
      }
      // ★ 2026-10-24 补：线索为 1 ⇒ 这个岛就是它自己 ⇒ 四邻必须全是墙。
      //   这条开局就成立，比"白区已满"实用得多。
      //   （原来的规则在真机上几乎不触发：未定格也算白，
      //     flood 会把整片非墙区都算进同一个岛。）
      if (this.clues[i] === 1) {
        const r0: number = Math.floor(i / n);
        const c0: number = i % n;
        const nbs: number[] = [];
        if (r0 > 0) {
          nbs.push(i - n);
        }
        if (r0 < n - 1) {
          nbs.push(i + n);
        }
        if (c0 > 0) {
          nbs.push(i - 1);
        }
        if (c0 < n - 1) {
          nbs.push(i + 1);
        }
        for (let t = 0; t < nbs.length; t++) {
          const j0: number = nbs[t];
          if (this.blacks[j0] === 1 || this.clues[j0] > 0) {
            continue;
          }
          const rr0: number = Math.floor(j0 / n) + 1;
          const cc0: number = (j0 % n) + 1;
          return Hint.make([j0],
            TG2('第 {0} 行第 {1} 列必须涂黑 —— 那个「1」的岛只有它自己一格，四邻都得是墙',
              String(rr0), String(cc0)),
            TG2('Row {0}, column {1} must be a wall — a "1" island is that cell alone',
              String(rr0), String(cc0)), t0);
        }
      }
      const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
      const comp: number[] = this.flood(this.blacks, i, seen, 0);
      if (comp.length !== this.clues[i]) {
        continue;                      // 白区还没长满，不推
      }
      // 白区已满 ⇒ 贴着它的未涂格必须涂黑
      for (let k = 0; k < comp.length; k++) {
        const cur: number = comp[k];
        const r: number = Math.floor(cur / n);
        const c: number = cur % n;
        const nb: number[] = [];
        if (r > 0) {
          nb.push(cur - n);
        }
        if (r < n - 1) {
          nb.push(cur + n);
        }
        if (c > 0) {
          nb.push(cur - 1);
        }
        if (c < n - 1) {
          nb.push(cur + 1);
        }
        for (let t = 0; t < nb.length; t++) {
          const j: number = nb[t];
          if (this.blacks[j] === 1) {
            continue;                  // 已经是墙
          }
          if (comp.indexOf(j) >= 0) {
            continue;                  // 同一白区内部
          }
          const rr: number = Math.floor(j / n) + 1;
          const cc: number = (j % n) + 1;
          return Hint.make([j],
            TG2('第 {0} 行第 {1} 列必须涂黑 —— 紧挨着的那个白区已经长满 {2} 格',
              String(rr), String(cc), String(this.clues[i])),
            TG2('Row {0}, column {1} must be a wall — the white island next to it is already full',
              String(rr), String(cc)), t0);
        }
      }
    }
    // ★ 2026-10-28 补：题库是固定的（CLUE_LIB 只有 3 题），每题的解已离线算好放在 NURI_SOL
    //   ⇒ 两条启发式都推不出来时，直接照真值报一格。
    //   查表是 O(题数×格数)，不会像 DFS 那样冻界面。
    const want: number[] = this.wantBlacks();
    if (want.length >= total) {
      for (let i = 0; i < total; i++) {
        if (this.clues[i] > 0) {
          continue;                    // 线索格必是白、不用点
        }
        const cur2: number = this.blacks[i] === 1 ? 1 : 0;
        if (want[i] === cur2) {
          continue;
        }
        const rr2: number = Math.floor(i / n) + 1;
        const cc2: number = (i % n) + 1;
        return Hint.make([i],
          want[i] === 1
            ? TG2('第 {0} 行第 {1} 列要涂黑（当墙）', String(rr2), String(cc2))
            : TG2('第 {0} 行第 {1} 列要留白（属于某个岛）', String(rr2), String(cc2)),
          want[i] === 1
            ? TG2('Row {0}, column {1} → wall', String(rr2), String(cc2))
            : TG2('Row {0}, column {1} → island', String(rr2), String(cc2)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格必须涂黑'));
  }

  private isWin(): boolean {
    if (this.violations(this.blacks)) {
      return false;
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1 || seen[i] === 1) {
        continue;
      }
      const comp: number[] = this.flood(this.blacks, i, seen, 0);
      const info: number[] = this.whiteInfo(this.blacks, comp);
      if (info[0] !== 1 || comp.length !== info[1]) {
        return false;
      }
    }
    let first: number = -1;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.blacks[i] === 1) {
        first = i;
        break;
      }
    }
    if (first < 0) {
      return false;
    }
    const bseen: number[] = new Array<number>(MAX_CELLS).fill(0);
    const comp: number[] = this.flood(this.blacks, first, bseen, 1);
    return comp.length === this.blackCount();
  }

  private clueOk(i: number): boolean {
    if (this.clues[i] === 0) {
      return false;
    }
    const seen: number[] = new Array<number>(MAX_CELLS).fill(0);
    const comp: number[] = this.flood(this.blacks, i, seen, 0);
    const info: number[] = this.whiteInfo(this.blacks, comp);
    return info[0] === 1 && comp.length === info[1];
  }

  private solvedClues(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (this.clues[i] > 0 && this.clueOk(i)) {
        n++;
      }
    }
    return n;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // CLUE_LIB 是固定题库（只有 3 题）⇒ 每题的解已经离线算好放在 NURI_SOL
  /** 按本题线索在库里找到对应解；找不到返回空数组 */
  private wantBlacks(): number[] {
    const total: number = this.diffTotal * this.diffTotal;
    for (let k = 0; k < CLUE_LIB.length; k++) {
      if (k >= NURI_SOL.length) {
        continue;
      }
      const cl: number[] = CLUE_LIB[k];
      let same: boolean = true;
      for (let i = 0; i < total; i++) {
        if (cl[i] !== this.clues[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        return NURI_SOL[k];
      }
    }
    return [];
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    const total: number = this.diffTotal * this.diffTotal;
    if (this.over) {
      return false;
    }
    const want: number[] = this.wantBlacks();
    if (want.length < total) {
      return false;
    }
    for (let i = 0; i < total; i++) {
      if (this.clues[i] > 0) {
        continue;
      }
      const cur: number = this.blacks[i] === 1 ? 1 : 0;
      if (want[i] !== cur) {
        this.tap(i);
        return !this.over;
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

  private tap(i: number): void {
    if (this.over || this.clues[i] > 0) {
      return;      // 提示格固定是岛，不可涂黑
    }
    const next: number[] = this.blacks.slice();
    next[i] = next[i] === 1 ? 0 : 1;
    if (this.violations(next)) {
      this.errors++;
      if (this.errors >= this.errMax) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.blacks = next;
    if (this.isWin()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(60, 380 - this.errors * 50 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'nurikabe',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.solvedClues()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    if (this.blacks[i] === 1) {
      return this.theme.isDark ? '#E2E8F0' : '#1E293B';
    }
    return this.clues[i] > 0 ? this.theme.surface : this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已满足提示'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.solvedClues()) + '/' + String(this.clueTotal)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('黑格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.blackCount())))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错手'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(this.errMax)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.clues[(r * this.diffTotal + c)] > 0 ? String(this.clues[(r * this.diffTotal + c)]) : '')
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.clueOk((r * this.diffTotal + c)) ? Palette.emerald : Palette.primaryDeep)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '岛与墙都对了 🎉 得分 ' + String(this.score) : '墙破岛溢，本局失败')
          : '点亮格子涂黑：数字格是岛，其余格成一片连通墙')
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
                Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.berry)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
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




}
