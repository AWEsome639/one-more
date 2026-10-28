/**
 * 数壹（Hitori）⬛
 *
 * 规则：涂黑一些格子，使 ——
 *   ① 每行每列的**未涂黑**数字都不重复；
 *   ② 涂黑的格子不能上下左右相邻；
 *   ③ 所有未涂黑的格子要连成一片。
 * 胜负：三条全满足 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const MAX_MOVES: number = 120;

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

/** 循环拉丁方 + 三重打乱 */
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
      const r: number = Math.floor(i / N);
      const c: number = i - r * N;
      let bad: boolean = false;
      if (c > 0 && shade[i - 1]) {
        bad = true;
      }
      if (c < N - 1 && shade[i + 1]) {
        bad = true;
      }
      if (r > 0 && shade[i - N]) {
        bad = true;
      }
      if (r < N - 1 && shade[i + N]) {
        bad = true;
      }
      if (bad) {
        continue;
      }
      shade[i] = true;
      cnt++;
    }
    if (cnt === 0) {
      continue;
    }
    // 白格连通
    let start: number = -1;
    let whites: number = 0;
    for (let i = 0; i < N * N; i++) {
      if (!shade[i]) {
        if (start < 0) {
          start = i;
        }
        whites++;
      }
    }
    if (start < 0) {
      continue;
    }
    const seen: boolean[] = new Array<boolean>(N * N).fill(false);
    const st: number[] = [start];
    seen[start] = true;
    let vis: number = 0;
    while (st.length > 0) {
      const k: number = st[st.length - 1];
      st.splice(st.length - 1, 1);
      vis++;
      const r: number = Math.floor(k / N);
      const c: number = k - r * N;
      if (c > 0 && !shade[k - 1] && !seen[k - 1]) {
        seen[k - 1] = true;
        st.push(k - 1);
      }
      if (c < N - 1 && !shade[k + 1] && !seen[k + 1]) {
        seen[k + 1] = true;
        st.push(k + 1);
      }
      if (r > 0 && !shade[k - N] && !seen[k - N]) {
        seen[k - N] = true;
        st.push(k - N);
      }
      if (r < N - 1 && !shade[k + N] && !seen[k + N]) {
        seen[k + N] = true;
        st.push(k + N);
      }
    }
    if (vis !== whites) {
      continue;
    }
    // 黑格数字取自相邻白格 ⇒ 每行每列必然出现重复，必须涂黑
    const vals: number[] = L.slice();
    let ok: boolean = true;
    for (let i = 0; i < N * N; i++) {
      if (!shade[i]) {
        continue;
      }
      const r: number = Math.floor(i / N);
      const c: number = i - r * N;
      const nbs: number[] = [];
      if (c > 0 && !shade[i - 1]) {
        nbs.push(i - 1);
      }
      if (c < N - 1 && !shade[i + 1]) {
        nbs.push(i + 1);
      }
      if (r > 0 && !shade[i - N]) {
        nbs.push(i - N);
      }
      if (r < N - 1 && !shade[i + N]) {
        nbs.push(i + N);
      }
      if (nbs.length === 0) {
        ok = false;
        break;
      }
      vals[i] = L[nbs[Math.floor(Math.random() * nbs.length)]];
    }
    if (!ok) {
      continue;
    }
    // 校验：白格数字在行列内不重复
    for (let r = 0; r < N; r++) {
      const sv: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let c = 0; c < N; c++) {
        if (shade[r * N + c]) {
          continue;
        }
        const v: number = vals[r * N + c];
        if (sv[v]) {
          ok = false;
          break;
        }
        sv[v] = true;
      }
    }
    for (let c = 0; c < N; c++) {
      const sv: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let r = 0; r < N; r++) {
        if (shade[r * N + c]) {
          continue;
        }
        const v: number = vals[r * N + c];
        if (sv[v]) {
          ok = false;
          break;
        }
        sv[v] = true;
      }
    }
    if (ok) {
      return { vals: vals, shade: shade };
    }
  }
  const vals: number[] = latinSquare();
  return { vals: vals, shade: new Array<boolean>(N * N).fill(false) };
}

@Component
export struct GHitori {
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

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private vals: number[] = [];
  @State private shade: boolean[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;
  /** ★ 提示说的话（空 = 没提示） */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GHitori')) {
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
    // ★ 2026-10-24 第三期：出题时就已经生成了一个完整解，以前丢掉了。
    //   留着它 ⇒ 提示能兜底、代打能走完全程，不用另写求解器。
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

  private dupCount(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      const sv: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let c = 0; c < N; c++) {
        if (this.shade[r * N + c]) {
          continue;
        }
        const v: number = this.vals[r * N + c];
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
        if (this.shade[r * N + c]) {
          continue;
        }
        const v: number = this.vals[r * N + c];
        if (sv[v]) {
          n++;
        } else {
          sv[v] = true;
        }
      }
    }
    return n;
  }

  private adjCount(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        if (!this.shade[r * N + c]) {
          continue;
        }
        if (c + 1 < N && this.shade[r * N + c + 1]) {
          n++;
        }
        if (r + 1 < N && this.shade[(r + 1) * N + c]) {
          n++;
        }
      }
    }
    return n;
  }

  private whiteLinked(): boolean {
    let start: number = -1;
    let whites: number = 0;
    for (let i = 0; i < N * N; i++) {
      if (!this.shade[i]) {
        if (start < 0) {
          start = i;
        }
        whites++;
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
      const r: number = Math.floor(k / N);
      const c: number = k - r * N;
      if (c > 0 && !this.shade[k - 1] && !seen[k - 1]) {
        seen[k - 1] = true;
        st.push(k - 1);
      }
      if (c < N - 1 && !this.shade[k + 1] && !seen[k + 1]) {
        seen[k + 1] = true;
        st.push(k + 1);
      }
      if (r > 0 && !this.shade[k - N] && !seen[k - N]) {
        seen[k - N] = true;
        st.push(k - N);
      }
      if (r < N - 1 && !this.shade[k + N] && !seen[k + N]) {
        seen[k + N] = true;
        st.push(k + N);
      }
    }
    return cnt === whites;
  }

  private isSolved(): boolean {
    return this.dupCount() === 0 && this.adjCount() === 0 && this.whiteLinked();
  }

  private flat(): number {
    const n: number = this.dupCount() + this.adjCount();
    return this.whiteLinked() ? n : n + 1;
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
   * ★★ 2026-10-24 第三期：AI 代打（数壹）
   *
   * 出题时 generator 已经给了一个完整解（g.shade），以前直接丢掉了。
   * 留着它 ⇒ 代打只要把每一格摆成解的样子即可，一步一步点。
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
    if (this.isSolved()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'hitori',
      solved: solved,
      score: solved ? Math.max(200, 1300 - this.moves * 10) : this.shaded() * 50,
      durationMs: Date.now() - this.startAt,
      levelReached: this.shaded()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
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
        Text((String(this.flat())))
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
        Text(Digits(String(this.moves), this.langCode))
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
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Stack() {
              Text(String(this.vals[(r * N + c)]))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.shade[(r * N + c)] ? (this.theme.isDark ? '#64748B' : '#94A3B8') : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
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
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * N + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'ht' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'htr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.md }) {
        Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点格子涂黑 / 取消')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打')))
          .layoutWeight(1)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.hintMsg.length > 0 ? this.hintMsg : TG('涂黑的格子仍显示数字；每行每列剩下的数字不能重复，白格要连成一片'))
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
