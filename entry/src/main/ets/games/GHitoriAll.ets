/**
 * 数壹进阶（Hitori 8×8）⬛
 *
 * 规则：涂黑一些格子，使 ——
 *   ① 每行每列的**未涂黑**数字都不重复；
 *   ② 涂黑的格子不能上下左右相邻；
 *   ③ 所有未涂黑的格子要连成一片。
 * 胜负：三条全满足 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { DemoBar } from '../components/DemoBar';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 8;
const MAX_MOVES: number = 150;

interface HitoriGen {
  vals: number[];
  shade: boolean[];
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 循环拉丁方 + 行/列/符号三重打乱 */
function latinSquare(): number[] {
  const rows: number[] = [];
  const cols: number[] = [];
  const syms: number[] = [];
  for (let i = 0; i < N; i++) {
    rows.push(i);
    cols.push(i);
    syms.push(i + 1);
  }
  shuffleArr(rows);
  shuffleArr(cols);
  shuffleArr(syms);
  const out: number[] = new Array<number>(N * N).fill(0);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      out[r * N + c] = syms[(rows[r] + cols[c]) % N];
    }
  }
  return out;
}

/** 白格四邻数（-1 表示越界） */
function nbIdx(i: number, d: number): number {
  const r: number = Math.floor(i / N);
  const c: number = i - r * N;
  if (d === 0) {
    return c > 0 ? i - 1 : -1;
  }
  if (d === 1) {
    return c < N - 1 ? i + 1 : -1;
  }
  if (d === 2) {
    return r > 0 ? i - N : -1;
  }
  return r < N - 1 ? i + N : -1;
}

function whiteCount(shade: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < N * N; i++) {
    if (!shade[i]) {
      n++;
    }
  }
  return n;
}

/** 白格连通：从第一个白格洪水填充，看能否覆盖全部白格 */
function whiteLinked(shade: boolean[]): boolean {
  let start: number = -1;
  for (let i = 0; i < N * N; i++) {
    if (!shade[i]) {
      start = i;
      break;
    }
  }
  if (start < 0) {
    return false;
  }
  const seen: boolean[] = new Array<boolean>(N * N).fill(false);
  const st: number[] = [start];
  seen[start] = true;
  let cnt: number = 0;
  while (st.length > 0) {
    const k: number = st[st.length - 1];
    st.splice(st.length - 1, 1);
    cnt++;
    for (let d = 0; d < 4; d++) {
      const j: number = nbIdx(k, d);
      if (j >= 0 && !shade[j] && !seen[j]) {
        seen[j] = true;
        st.push(j);
      }
    }
  }
  return cnt === whiteCount(shade);
}

/** 行列中去重后仍重复的数字个数 */
function dupCount(vals: number[], shade: boolean[]): number {
  let n: number = 0;
  for (let r = 0; r < N; r++) {
    const sv: boolean[] = new Array<boolean>(N + 1).fill(false);
    for (let c = 0; c < N; c++) {
      const i: number = r * N + c;
      if (shade[i]) {
        continue;
      }
      const v: number = vals[i];
      if (sv[v]) {
        n++;
      } else {
        sv[v] = true;
      }
    }
  }
  for (let c = 0; c < N; c++) {
    const sv: boolean[] = new Array<boolean>(N + 1).fill(false);
    for (let r = 0; r < N; r++) {
      const i: number = r * N + c;
      if (shade[i]) {
        continue;
      }
      const v: number = vals[i];
      if (sv[v]) {
        n++;
      } else {
        sv[v] = true;
      }
    }
  }
  return n;
}

function adjCount(shade: boolean[]): number {
  let n: number = 0;
  for (let i = 0; i < N * N; i++) {
    if (!shade[i]) {
      continue;
    }
    const right: number = nbIdx(i, 1);
    const down: number = nbIdx(i, 3);
    if (right >= 0 && shade[right]) {
      n++;
    }
    if (down >= 0 && shade[down]) {
      n++;
    }
  }
  return n;
}

function hitoriGen(): HitoriGen {
  for (let t = 0; t < 400; t++) {
    const L: number[] = latinSquare();
    const order: number[] = [];
    for (let i = 0; i < N * N; i++) {
      order.push(i);
    }
    shuffleArr(order);
    const want: number = N + Math.floor(Math.random() * (N + 1));
    const shade: boolean[] = new Array<boolean>(N * N).fill(false);
    let cnt: number = 0;
    for (let k = 0; k < order.length && cnt < want; k++) {
      const i: number = order[k];
      let bad: boolean = false;
      for (let d = 0; d < 4; d++) {
        const j: number = nbIdx(i, d);
        if (j >= 0 && shade[j]) {
          bad = true;
        }
      }
      if (bad) {
        continue;
      }
      shade[i] = true;
      cnt++;
    }
    if (cnt === 0 || !whiteLinked(shade)) {
      continue;
    }
    // 黑格数字复制相邻白格 ⇒ 该行/列必然出现重复，必须涂黑
    const vals: number[] = L.slice();
    let ok: boolean = true;
    for (let i = 0; i < N * N; i++) {
      if (!shade[i]) {
        continue;
      }
      const nbs: number[] = [];
      for (let d = 0; d < 4; d++) {
        const j: number = nbIdx(i, d);
        if (j >= 0 && !shade[j]) {
          nbs.push(j);
        }
      }
      if (nbs.length === 0) {
        ok = false;
        break;
      }
      vals[i] = L[nbs[Math.floor(Math.random() * nbs.length)]];
    }
    if (ok && dupCount(vals, shade) === 0) {
      return { vals: vals, shade: shade };
    }
  }
  return { vals: latinSquare(), shade: new Array<boolean>(N * N).fill(false) };
}

@Component
export struct GHitoriAll {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  /** 出题时的完整解（涂黑方案） */

  private solShade: boolean[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */
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

  @State private vals: number[] = [];
  @State private shade: boolean[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GHitoriAll')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const g: HitoriGen = hitoriGen();
    this.vals = g.vals;
    // ★ 2026-10-24 第三期：出题时的完整解留着，代打直接用（同数壹）
    this.solShade = g.shade;
    this.shade = new Array<boolean>(N * N).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private shaded(): number {
    let n: number = 0;
    for (let i = 0; i < this.shade.length; i++) {
      if (this.shade[i]) {
        n++;
      }
    }
    return n;
  }

  private bad(): number {
    return dupCount(this.vals, this.shade) + adjCount(this.shade) + (whiteLinked(this.shade) ? 0 : 1);
  }

  /**
   * ★ 2026-10-23 第二期：数壹提示
   *
   * 数壹有三条规则：① 每行每列剩下的（白）数字不能重复
   *                ② 黑格不能相邻
   *                ③ 白格要连成一片
   * ①② 是**逐行可判**的 ⇒ 可以用数织/数楼那套：
   *   枚举这一行所有"哪些格涂黑"的组合（2^6 = 64），
   *   只留满足 ①② 且与玩家当前标记不矛盾的，
   *   再求交集 —— 在所有候选里都一样的格，就是确定的。
   *
   * ⚠️ 规则③（连通性）是全盘性质，这里**没有**纳入枚举；
   *    只用 ①② 推出来的结论仍然是**正确**的（只是可能少推一些）。
   *    宁可少给，不给错。
   *
   * 都给不出 ⇒ Hint.none()（数壹开局常常确实没有确定步）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < N; k++) {
        // 这一行的数字与玩家当前的涂黑状态
        const vals: number[] = [];
        const marks: number[] = [];      // 0 未定 / 1 已黑 / 2 已白
        for (let i = 0; i < N; i++) {
          const idx: number = horiz === 1 ? k * N + i : i * N + k;
          vals.push(this.vals[idx]);
          marks.push(this.shade[idx] ? 1 : 0);
        }
        let acc: number[] = [];          // 按位累积：1 = 所有候选都黑，0 = 都白，-1 = 不一致
        let cnt: number = 0;
        const total: number = 1 << N;
        for (let mask = 0; mask < total; mask++) {
          // ② 黑格不能相邻
          let ok: boolean = true;
          for (let i = 0; i < N; i++) {
            const isBlack: boolean = ((mask >> i) & 1) === 1;
            if (isBlack && i + 1 < N && ((mask >> (i + 1)) & 1) === 1) {
              ok = false;
              break;
            }
            // 与玩家标记不矛盾（玩家标白的不能黑，标黑的必须黑）
            if (marks[i] === 0 && isBlack) {
              // 玩家还没标，允许
            } else if (marks[i] === 1 && !isBlack) {
              ok = false;
              break;
            }
          }
          if (!ok) {
            continue;
          }
          // ① 白格的数字不能重复
          const seen: number[] = new Array<number>(10).fill(0);
          for (let i = 0; i < N; i++) {
            if (((mask >> i) & 1) === 1) {
              continue;
            }
            const v: number = vals[i];
            if (v <= 0) {
              ok = false;
              break;
            }
            if (seen[v] === 1) {
              ok = false;
              break;
            }
            seen[v] = 1;
          }
          if (!ok) {
            continue;
          }
          if (cnt === 0) {
            acc = [];
            for (let i = 0; i < N; i++) {
              acc.push(((mask >> i) & 1) === 1 ? 1 : 0);
            }
          } else {
            for (let i = 0; i < N; i++) {
              const cur: number = ((mask >> i) & 1) === 1 ? 1 : 0;
              if (acc[i] !== cur) {
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
          if (acc[i] < 0) {
            continue;
          }
          const wantBlack: boolean = acc[i] === 1;
          if (this.shade[horiz === 1 ? k * N + i : i * N + k] === wantBlack) {
            continue;
          }
          const idx: number = horiz === 1 ? k * N + i : i * N + k;
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          if (wantBlack) {
            return Hint.make([idx], TG2('第 {0} 行第 {1} 列必须涂黑', String(r), String(c)),
              TG2('Row {0}, column {1} must be shaded', String(r), String(c)), t0);
          }
          return Hint.make([idx], TG2('第 {0} 行第 {1} 列必须留白', String(r), String(c)),
            TG2('Row {0}, column {1} must stay white', String(r), String(c)), t0);
        }
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第三期：AI 代打（数壹进阶）
   * 用出题时保留的完整解，一格一格摆到位。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01）
  // ★ 旧版 `demoStep()` 一个 tick 直接 `autoStep()`，匀速连发 ⇒ 玩家看不出在演什么。
  // ★ 新版三拍：引导(720) → 执行(280) → 结果(1150)，3 轮 ≈ 6.5 秒。
  // ★ 引导拍的文案用**本游戏自己的 computeHint()** —— 它本来就知道该指哪里。
  // ★ 演示期间按钮置灰（本页 demoId 直传），结束后 reset 回干净开局。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
        this.hintIdx = (hr.ok && hr.cells.length > 0) ? hr.cells[0] : -1;
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
      this.hintIdx = -1;
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
    this.reset();
  }

  private demoStop(): void {
    this.demoFinish();
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
    if (this.solShade.length !== N * N) {
      return false;
    }
    for (let i = 0; i < N * N; i++) {
      if (this.shade[i] !== this.solShade[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }

  private askAuto(): void {
    if (LanRace.isRacing()) { return; }   // 联机禁用（奥森硬约束）
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private askHint(): void {
    // ★★★ 2026-11-01 真机排查抓到（批量改造的残留）：
    //   这 16 款用的是**自绘按钮行**（不是 HintBar），所以 HintBar 那套 `disabled` 保护没轮到它们。
    //   后果：演示期间按「提示」会在正在变化的棋盘上算 computeHint（结果不可靠）；
    //         按「AI 代打」会**再起一个计时器**，和演示计时器同时改棋盘 ⇒ 局面乱套。
    //   ⇒ 这里让「先停演示，再执行」—— 比禁用更符合直觉（用户想操作就给他操作）。
    if (this.demoId >= 0) { this.demoStop(); }
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步从规则推不出来，得先涂一个试试');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const s: boolean[] = this.shade.slice();
    s[i] = !s[i];
    this.shade = s;
    this.moves++;
    if (this.bad() === 0) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true; this.won = false;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'hitori_all',
      solved: solved,
      score: solved ? Math.max(200, 1600 - this.moves * 8) : this.shaded() * 40,
      durationMs: Date.now() - this.startAt,
      levelReached: this.shaded()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      Row({ space: Space.md }) {
        // ★★ 2026-11-07 溢出审计：统一用**短标签**（原来只有极小屏走短支）。
        //   长标签德语 35 / 俄语 37 字符 ≈315vp > 半宽 ~156vp ⇒ 被省略成半句。
        //   ⚠️ Button 没有 `.maxLines()`/`.textOverflow()`，必须用 `.labelStyle({...})`。
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : TG('涂黑 / 取消'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.xs)
          .labelStyle({ maxLines: 2, overflow: TextOverflow.Ellipsis, font: { size: FontSize.xs } })
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(64)
          .height(44)
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L701'; })
          .onBlur(() => { if (this.tvFocus === 'L701') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L701'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(LanRace.isRacing() ? TG('联机禁用')
          : (this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))))
          .layoutWeight(1)
          .height(44)
          // ★★★ 2026-10-31（按 Button 分块修）：这个「AI 代打」按钮**没有 backgroundColor**
          //   ⇒ 用 ArkUI 平台默认蓝，与 HintBar 的 Palette.cyan 不一致。
          .backgroundColor(Palette.cyan)
          .fontColor('#FFFFFF')
                    // ★★★ 2026-11-01 奥森硬约束：**AI 代打在联机对战中不能启用**
          //   这 16 款是自绘按钮行，HintBar 那套保护没走到它们身上
          .enabled(!LanRace.isRacing())
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L718'; })
          .onBlur(() => { if (this.tvFocus === 'L718') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L718'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.tap(44))
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L732'; })
          .onBlur(() => { if (this.tvFocus === 'L732') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L732'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('已涂黑'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.shaded())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('违规'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.bad())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(TG2('步数 {0}/{1}', Digits(String(this.moves), this.langCode), Digits(String(this.diffTotal), this.langCode)))
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
      .width('100%')

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (c: number) => {
              Stack() {
              Text(String(this.vals[(r * N + c)]))
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.shade[(r * N + c)] ? (this.theme.isDark ? '#64748B' : '#94A3B8') : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              // ★ 2026-11-01：hintIdx 原来只设不画 ⇒ 提示/演示在盘面上没有指向。
              .border({ width: this.hintIdx === r * N + c ? 3 : 0, color: Palette.amber })
              .backgroundColor(this.shade[(r * N + c)] ? (this.theme.isDark ? '#0B0B0B' : '#334155') : this.theme.surface)
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .focusable(Tv.on())
              .onFocus(() => { this.tvFocus = 'L667'; })
              .onBlur(() => { if (this.tvFocus === 'L667') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L667', Radius.xs))
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'ha' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'har' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)


      Text(this.hintMsg.length > 0 ? this.hintMsg : TG('8×8 大盘：每行每列剩下的数字不能重复，黑格不相邻，白格连成一片'))
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




}
