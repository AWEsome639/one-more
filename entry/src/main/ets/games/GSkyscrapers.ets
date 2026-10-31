/**
 * 数楼 skyscrapers（4×4）—— 每行每列 1~4 各一次；盘外数字是从那个方向能看见的楼数
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：拉丁方成立且四边提示全对 ⇒ solved:true；错手 5 次 ⇒ solved:false
 * 进度：已填格数 ／ 错手 ／ 当前选中的数字
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const CELLS: number = N * N;
const SIDE: number = N + 2;
const ERR_MAX: number = 5;

/** 3 关提示：[上 4][右 4][下 4][左 4]，都是唯一解的盘面 */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    2,3,2,1,
    1,2,3,3,
    1,2,3,3,
    2,3,2,1
  ],
  // 第 2 关
  [
    2,1,2,2,
    2,3,2,1,
    3,4,2,1,
    2,1,2,3
  ],
  // 第 3 关
  [
    3,3,2,1,
    1,2,3,2,
    1,2,3,2,
    3,3,2,1
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GSkyscrapers {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 ERR_MAX=5
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(5);
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State grid: number[] = [];      // 0 = 空格
  /** ★ 2026-10-23 第二期：提示说的话（空 = 没提示） */
  @State hintMsg: string = '';
  @State hintIdx: number = -1;
  @State pick: number = 1;
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
    if (Hint.demoOnce('GSkyscrapers')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(5);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.grid = new Array<number>(CELLS).fill(0);
    this.pick = 1;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] > 0) {
        n++;
      }
    }
    return n;
  }

  /** 同行或同列已经有同样的数字 */
  private conflict(arr: number[], i: number): boolean {
    const r: number = Math.floor(i / N);
    const c: number = i % N;
    const v: number = arr[i];
    for (let k = 0; k < N; k++) {
      if (k !== c && arr[r * N + k] === v) {
        return true;
      }
      if (k !== r && arr[k * N + c] === v) {
        return true;
      }
    }
    return false;
  }

  private latinOk(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] === 0) {
        return false;
      }
    }
    for (let r = 0; r < N; r++) {
      const seen: number[] = new Array<number>(N + 1).fill(0);
      for (let c = 0; c < N; c++) {
        const v: number = this.grid[r * N + c];
        if (seen[v] === 1) {
          return false;
        }
        seen[v] = 1;
      }
    }
    for (let c = 0; c < N; c++) {
      const seen: number[] = new Array<number>(N + 1).fill(0);
      for (let r = 0; r < N; r++) {
        const v: number = this.grid[r * N + c];
        if (seen[v] === 1) {
          return false;
        }
        seen[v] = 1;
      }
    }
    return true;
  }

  private seeCol(c: number, bottomUp: boolean): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < N; k++) {
      const r: number = bottomUp ? N - 1 - k : k;
      const v: number = this.grid[r * N + c];
      if (v === 0) {
        return 0;
      }
      if (v > mx) {
        mx = v;
        n++;
      }
    }
    return n;
  }

  private seeRow(r: number, rightToLeft: boolean): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < N; k++) {
      const c: number = rightToLeft ? N - 1 - k : k;
      const v: number = this.grid[r * N + c];
      if (v === 0) {
        return 0;
      }
      if (v > mx) {
        mx = v;
        n++;
      }
    }
    return n;
  }

  private cluesOk(): boolean {
    for (let c = 0; c < N; c++) {
      if (this.seeCol(c, false) !== this.clues[c]) {
        return false;
      }
      if (this.seeCol(c, true) !== this.clues[N * 2 + c]) {
        return false;
      }
    }
    for (let r = 0; r < N; r++) {
      if (this.seeRow(r, false) !== this.clues[N * 3 + r]) {
        return false;
      }
      if (this.seeRow(r, true) !== this.clues[N + r]) {
        return false;
      }
    }
    return true;
  }


  /** 视野数：给一条线（长度 N），从前往后看能看见几栋楼 */
  private sightOf(line: number[]): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < line.length; k++) {
      if (line[k] > mx) {
        mx = line[k];
        n++;
      }
    }
    return n;
  }

  /** 生成 1..N 的全部排列（N=4 时 24 个） */
  private allPerms(): number[][] {
    const out: number[][] = [];
    const cur: number[] = [];
    const used: boolean[] = new Array<boolean>(N + 1).fill(false);
    const rec = (): void => {
      if (cur.length === N) {
        out.push(cur.slice());
        return;
      }
      for (let v = 1; v <= N; v++) {
        if (used[v]) {
          continue;
        }
        used[v] = true;
        cur.push(v);
        rec();
        cur.pop();
        used[v] = false;
      }
    };
    rec();
    return out;
  }

  /**
   * ★ 2026-10-23 第二期：数楼提示
   *
   * 规则：每行每列是 1..N 的一个排列，且两端线索 = 从那一端看过去的视野数。
   * ⇒ 可以逐行/逐列做「枚举所有符合线索与已填数字的排列，再求交集」：
   *    某格在所有候选里都相同的，就是确定的。
   *   N=4 时每行只有 24 个排列，毫秒级。
   *
   * ⚠️ 判断依据只用「线索 + 玩家已填」，不看题目答案。
   * 全部推不出 ⇒ Hint.none()（数楼确实有需要猜的局面）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const perms: number[][] = this.allPerms();
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < N; k++) {
        const marks: number[] = [];
        for (let i = 0; i < N; i++) {
          marks.push(horiz === 1 ? this.grid[k * N + i] : this.grid[i * N + k]);
        }
        const cA: number = horiz === 1 ? this.clues[N * 3 + k] : this.clues[k];
        const cB: number = horiz === 1 ? this.clues[N + k] : this.clues[N * 2 + k];
        let acc: number[] = [];
        let cnt: number = 0;
        for (let pi = 0; pi < perms.length; pi++) {
          const cand: number[] = perms[pi];
          // 与线索比
          if (this.sightOf(cand) !== cA) {
            continue;
          }
          const rev: number[] = [];
          for (let i = N - 1; i >= 0; i--) {
            rev.push(cand[i]);
          }
          if (this.sightOf(rev) !== cB) {
            continue;
          }
          // 与玩家已填比
          let ok: boolean = true;
          for (let i = 0; i < N; i++) {
            if (marks[i] !== 0 && marks[i] !== cand[i]) {
              ok = false;
              break;
            }
          }
          if (!ok) {
            continue;
          }
          if (cnt === 0) {
            acc = cand.slice();
          } else {
            for (let i = 0; i < N; i++) {
              if (acc[i] !== cand[i]) {
                acc[i] = -1;
              }
            }
          }
          cnt++;
        }
        if (cnt <= 1) {
          continue;
        }
        for (let i = 0; i < N; i++) {
          if (acc[i] < 0 || marks[i] === acc[i]) {
            continue;
          }
          const idx: number = horiz === 1 ? k * N + i : i * N + k;
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          return Hint.make([idx],
            TG2('第 {0} 行第 {1} 列一定是 {2}', String(r), String(c), String(acc[i])),
            TG2('Row {0}, column {1} must be {2}', String(r), String(c), String(acc[i])), t0);
        }
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步从线索推不出来，得试一个数看看');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // N=4、线索表只有 3 套（每套唯一解）⇒ 直接解：逐行枚举候选排列（24 个，按左右线索筛），
  // 回溯保证列不重复，最后校四边列线索。解出来必然满足 latinOk() + cluesOk()。
  /** 一条线上的视野数（纯函数） */
  private sightLine(vals: number[]): number {
    let mx: number = 0;
    let n: number = 0;
    for (let i = 0; i < vals.length; i++) {
      if (vals[i] > mx) {
        mx = vals[i];
        n++;
      }
    }
    return n;
  }

  /** 求这一盘的解（长度 = CELLS；空数组 = 没解出来） */
  private solveGrid(): number[] {
    const perms: number[][] = this.allPerms();
    const cands: number[][][] = [];
    for (let r = 0; r < N; r++) {
      const list: number[][] = [];
      for (let pi = 0; pi < perms.length; pi++) {
        const p: number[] = perms[pi];
        const rev: number[] = [];
        for (let i = N - 1; i >= 0; i--) {
          rev.push(p[i]);
        }
        if (this.sightLine(p) === this.clues[N * 3 + r] &&
          this.sightLine(rev) === this.clues[N + r]) {
          list.push(p);
        }
      }
      cands.push(list);
    }
    const grid: number[] = new Array<number>(CELLS).fill(0);
    const sol: number[] = [];
    const rec = (r: number): boolean => {
      if (r === N) {
        for (let c = 0; c < N; c++) {
          const col: number[] = [];
          for (let rr = 0; rr < N; rr++) {
            col.push(grid[rr * N + c]);
          }
          const rev2: number[] = [];
          for (let i = N - 1; i >= 0; i--) {
            rev2.push(col[i]);
          }
          if (this.sightLine(col) !== this.clues[c] ||
            this.sightLine(rev2) !== this.clues[N * 2 + c]) {
            return false;
          }
        }
        for (let i = 0; i < CELLS; i++) {
          sol.push(grid[i]);
        }
        return true;
      }
      const list: number[][] = cands[r];
      for (let k = 0; k < list.length; k++) {
        const p: number[] = list[k];
        let ok: boolean = true;
        for (let c = 0; c < N; c++) {
          for (let rr = 0; rr < r; rr++) {
            if (grid[rr * N + c] === p[c]) {
              ok = false;
              break;
            }
          }
          if (!ok) {
            break;
          }
        }
        if (!ok) {
          continue;
        }
        for (let c = 0; c < N; c++) {
          grid[r * N + c] = p[c];
        }
        if (rec(r + 1)) {
          return true;
        }
      }
      return false;
    };
    if (!rec(0)) {
      return [];
    }
    return sol;
  }

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
    if (this.over) {
      return false;
    }
    const sol: number[] = this.solveGrid();
    if (sol.length !== CELLS) {
      return false;
    }
    // ① 先清掉玩家填错的格子（pick = 那一格的数字再点 = 清空，不记错手）
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] !== 0 && this.grid[i] !== sol[i]) {
        this.pick = this.grid[i];
        this.tap(i);
        return !this.over;
      }
    }
    // ② 再照解填空（tap 落的是 this.pick，所以每次要先拨好 pick）
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] === sol[i]) {
        continue;
      }
      this.pick = sol[i];
      this.tap(i);
      return !this.over;
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
    if (this.over) {
      return;
    }
    const next: number[] = this.grid.slice();
    if (next[i] === this.pick) {
      next[i] = 0;                       // 同数字再点一次 = 清空
    } else {
      next[i] = this.pick;
      if (this.conflict(next, i)) {
        this.errors++;
      }
    }
    this.grid = next;
    if (this.errors >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
      return;
    }
    if (this.latinOk() && this.cluesOk()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(100, 500 - this.errors * 60 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'skyscrapers',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private isPlay(gr: number, gc: number): boolean {
    return gr >= 1 && gr <= N && gc >= 1 && gc <= N;
  }

  private skyText(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? '' : String(v);
    }
    if (gr === 0 && gc >= 1 && gc <= N) {
      return String(this.clues[gc - 1]);
    }
    if (gr === N + 1 && gc >= 1 && gc <= N) {
      return String(this.clues[N * 2 + gc - 1]);
    }
    if (gc === 0 && gr >= 1 && gr <= N) {
      return String(this.clues[N * 3 + gr - 1]);
    }
    if (gc === N + 1 && gr >= 1 && gr <= N) {
      return String(this.clues[N + gr - 1]);
    }
    return '';
  }

  private skyInk(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? this.theme.inkFaint : Palette.primaryDeep;
    }
    return Palette.sky;
  }

  private skyBg(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? this.theme.surface : tintOf(Palette.primary, this.theme.isDark);
    }
    return this.theme.surfaceAlt;
  }

  private skyTap(gr: number, gc: number): void {
    if (this.isPlay(gr, gc)) {
      this.tap((gr - 1) * N + (gc - 1));
    }
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filledCount()) + '/' + String(CELLS)))
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
        Text((String(this.errors) + '/' + String(this.diffTotal)))
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
        Text((TG('选中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.pick), this.langCode))
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

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5], (gr: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5], (gc: number) => {
              Stack() {
              Text(this.skyText((gr), (gc)))
              .fontSize(this.isPlay((gr), (gc)) ? FontSize.lg : FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.skyInk((gr), (gc)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.skyBg((gr), (gc)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.skyTap((gr), (gc));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.skyTap((gr), (gc)); }); })
            }, (gc: number) => 'g' + gc)
          }
          .width('100%')
        }, (gr: number) => 'gr' + gr)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        ForEach([1, 2, 3, 4], (v: number) => {
          Text(String(v))
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pick === v ? '#FFFFFF' : this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(44))
            .backgroundColor(this.pick === v ? Palette.sky : this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
              Haptics.tick();
              this.pick = v;
            })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick = v; }); })
        }, (v: number) => 'p' + v)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '楼数全对 🎉 得分 ' + String(this.score) : '错手太多，本局失败')
          : (this.hintMsg.length > 0 ? this.hintMsg : '先选数字，再点格子；同一个数字点两次即清空'))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(Cell.of(44))
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
          .backgroundColor(Palette.sky)
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
