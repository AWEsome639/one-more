/**
 * 填数拼图（Fillomino）🧩
 *
 * 规则：把空格填上数字，使**同数字的连通块大小恰好等于该数字**
 *       （例如 4 只能出现在由 4 格组成的连通块里）。
 * 胜负：全部填满且每块大小都对 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
// ★ 2026-10-30 布局 bug ① 修复：棋盘边长要用 Bp（当前窗口宽/高）反算，不再依赖 aspectRatio
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 6;
const MAX_MOVES: number = 150;
const SIZES: number = N + 2;   // 1..8，正好铺满 36 格

/**
 * 棋盘之外的纵向预留（vp）—— 按全项目最苛刻的 533vp 横屏口径逐项拆开算：
 *   顶栏           88   （GameHost：padding top 28 + 图标行 44 + padding bottom 16）
 *   底 padding     20   （GameHost 游戏区 padding bottom = Space.lg）
 *   信息行         62   （三张卡片：padding 10×2 + xxs 12 与 lg 18 两行 + 行距 2）
 *   数字键 2 行    98   （Cell.of(44) 在平板 ×1.12 = 49，两行）
 *   按钮行         49   （清除本格 / 提示 / AI 代打 / 重开 同一行）
 *   状态行         20   （最下面那行灰色说明文字）
 *   行间距         80   （Column space = Space.md(16) × 5 处间隙）
 *   ⇒ 88+20+62+98+49+20+80 = 417，取 420 留 3vp 余量
 *
 * ⚠️ 静态审计里建议的 325 **不能直接用**：它只算了「顶栏 + padding + 信息行 + 键 + 按钮 + 状态」，
 *    **漏掉了 Column 的 5 个 16vp 间隙（80vp）**，也按手机口径算的行高（平板上 Cell.of(44)=49）。
 *    照 325 反算棋盘会得到 208vp，整页仍然溢出约 90vp —— 底部状态行与按钮行继续被裁，等于没修。
 */
// ★★★ 2026-10-30（与 GColorFlood 同一轮发现的同一类问题）：
//   420 在 960×540（游戏区约 476vp）下算出 56vp ⇒ 被 max(96,...) 抬到 **96vp**
//   ⇒ 6×6 每格 16vp = 48px，勉强可点；底部说明还被切掉一半。
//
//   ⇒ 改成 300：棋盘 176vp（每格 29.3vp ≈ **88px**，非常好点）。
//   ⚠️ 但 420 原来是子代理按"必须一屏装下"算出来的 ——
//      改小之后整页会超高 ⇒ **必须同时套 Scroll**，否则底部按钮又被挤出屏。
//      （这两件事必须一起做，只做一件就是把旧 bug 请回来。）
const BOARD_RESERVE: number = 300;

interface FilloGen {
  sol: number[];
  given: boolean[];
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

function freeDegree(j: number, vis: boolean[]): number {
  const r: number = Math.floor(j / N);
  const c: number = j - r * N;
  let d: number = 0;
  if (c > 0 && !vis[j - 1]) {
    d++;
  }
  if (c < N - 1 && !vis[j + 1]) {
    d++;
  }
  if (r > 0 && !vis[j - N]) {
    d++;
  }
  if (r < N - 1 && !vis[j + N]) {
    d++;
  }
  return d;
}

/** 随机哈密顿路径（Warnsdorff 启发式）—— 沿路径切块，块必然连通 */
function hamDfs(cur: number, cnt: number, vis: boolean[], path: number[]): boolean {
  if (cnt === N * N) {
    return true;
  }
  const r: number = Math.floor(cur / N);
  const c: number = cur - r * N;
  const nbs: number[] = [];
  if (c > 0 && !vis[cur - 1]) {
    nbs.push(cur - 1);
  }
  if (c < N - 1 && !vis[cur + 1]) {
    nbs.push(cur + 1);
  }
  if (r > 0 && !vis[cur - N]) {
    nbs.push(cur - N);
  }
  if (r < N - 1 && !vis[cur + N]) {
    nbs.push(cur + N);
  }
  shuffleArr(nbs);
  for (let i = 1; i < nbs.length; i++) {
    const v: number = nbs[i];
    const d: number = freeDegree(v, vis);
    let j: number = i - 1;
    while (j >= 0 && freeDegree(nbs[j], vis) > d) {
      nbs[j + 1] = nbs[j];
      j--;
    }
    nbs[j + 1] = v;
  }
  for (let k = 0; k < nbs.length; k++) {
    const j: number = nbs[k];
    vis[j] = true;
    path.push(j);
    if (hamDfs(j, cnt + 1, vis, path)) {
      return true;
    }
    path.splice(path.length - 1, 1);
    vis[j] = false;
  }
  return false;
}

function filloGen(): FilloGen {
  let path: number[] = [];
  for (let t = 0; t < 40 && path.length === 0; t++) {
    const vis: boolean[] = new Array<boolean>(N * N).fill(false);
    const p: number[] = [];
    const s: number = Math.floor(Math.random() * N * N);
    vis[s] = true;
    p.push(s);
    if (hamDfs(s, 1, vis, p)) {
      path = p;
    }
  }
  if (path.length !== N * N) {
    path = [];
    for (let r = 0; r < N; r++) {
      for (let k = 0; k < N; k++) {
        const c: number = r % 2 === 0 ? k : N - 1 - k;
        path.push(r * N + c);
      }
    }
  }
  const sizes: number[] = [];
  for (let k = 1; k <= SIZES; k++) {
    sizes.push(k);
  }
  shuffleArr(sizes);
  const sol: number[] = new Array<number>(N * N).fill(0);
  let idx: number = 0;
  for (let s = 0; s < sizes.length; s++) {
    for (let k = 0; k < sizes[s]; k++) {
      sol[path[idx]] = sizes[s];
      idx++;
    }
  }
  const given: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let i = 0; i < N * N; i++) {
    given[i] = Math.random() < 0.5;
  }
  return { sol: sol, given: given };
}

@Component
export struct GFillomino {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private sol: number[] = [];
  @State private given: boolean[] = [];
  @State private vals: number[] = [];
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private sel: number = -1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFillomino')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const g: FilloGen = filloGen();
    this.sol = g.sol;
    this.given = g.given;
    const v: number[] = [];
    for (let i = 0; i < N * N; i++) {
      v.push(g.given[i] ? g.sol[i] : 0);
    }
    this.vals = v;
    this.sel = -1;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.vals.length; i++) {
      if (this.vals[i] > 0) {
        n++;
      }
    }
    return n;
  }

  /** 每块大小是否等于块内数字 */
  private allOk(): boolean {
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] === 0) {
        return false;
      }
    }
    const seen: boolean[] = new Array<boolean>(N * N).fill(false);
    for (let i = 0; i < N * N; i++) {
      if (seen[i]) {
        continue;
      }
      const v: number = this.vals[i];
      const st: number[] = [i];
      seen[i] = true;
      let cnt: number = 0;
      while (st.length > 0) {
        const k: number = st[st.length - 1];
        st.splice(st.length - 1, 1);
        cnt++;
        const r: number = Math.floor(k / N);
        const c: number = k - r * N;
        if (c > 0 && !seen[k - 1] && this.vals[k - 1] === v) {
          seen[k - 1] = true;
          st.push(k - 1);
        }
        if (c < N - 1 && !seen[k + 1] && this.vals[k + 1] === v) {
          seen[k + 1] = true;
          st.push(k + 1);
        }
        if (r > 0 && !seen[k - N] && this.vals[k - N] === v) {
          seen[k - N] = true;
          st.push(k - N);
        }
        if (r < N - 1 && !seen[k + N] && this.vals[k + N] === v) {
          seen[k + N] = true;
          st.push(k + N);
        }
      }
      if (cnt !== v) {
        return false;
      }
    }
    return true;
  }

  // ═══════════ 提示 + 代打（2026-10-24 第三期）═══════════
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] === 0 && this.sol[i] > 0) {
        const r: number = Math.floor(i / N) + 1;
        const c: number = (i % N) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列应该填 {2}', String(r), String(c), String(this.sol[i])),
          TG2('Row {0}, column {1} should be {2}', String(r), String(c), String(this.sol[i])), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一局暂时给不出提示'));
  }

  /** ★ AI 代打：用出题时的完整解，一格一格填 */
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
    if (this.sol.length < N * N) {
      return false;
    }
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] !== this.sol[i] && !this.given[i]) {
        this.sel = i;
        this.setVal(this.sol[i]);
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

  private setVal(v: number): void {
    if (this.over || this.sel < 0 || this.given[this.sel]) {
      return;
    }
    const n: number[] = this.vals.slice();
    n[this.sel] = v;
    this.vals = n;
    this.moves++;
    if (this.allOk()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
      return;
    }
    let next: number = -1;
    for (let k = this.sel + 1; k < N * N; k++) {
      if (!this.given[k] && this.vals[k] === 0) {
        next = k;
        break;
      }
    }
    if (next < 0) {
      for (let k = 0; k < N * N; k++) {
        if (!this.given[k] && this.vals[k] === 0) {
          next = k;
          break;
        }
      }
    }
    this.sel = next;
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'fillomino',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : this.filledCount() * 25,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * 棋盘边长（vp）：**宽度与可用高度取小者** —— 不许 aspectRatio 自行决定高度。
   *
   * ★★★ 2026-10-30 修布局 bug ①（平板横屏 853×533，原代码溢出 4.2 倍）：
   *   原来的写法是「容器 `.width('100%')` + `.constraintSize({ maxHeight: '46%' })`，
   *   格子 `layoutWeight(1) + aspectRatio(1)`」——
   *   格子的 aspectRatio 会把**高度锁成宽度**：容器宽 813vp ⇒ 6 行格子要 813vp 高，
   *   而 46% 只给 ~195vp ⇒ 内容溢出 4.2 倍，
   *   板下 2 行数字键（1~4 / 5~8）与 4 个按钮（清除本格 / 提示 / AI 代打 / 重开）
   *   被整排顶出屏幕（表现为「点不到」）。
   *
   *   ⇒ 现在：棋盘是**定宽定高的正方形**，边长 = min(可用宽, 屏高 - 预留)，
   *     格子由宽度均分、高度自然等于宽度 ⇒ 行高总和恰好等于容器高，不存在溢出。
   *     手机竖屏 440×744：min(400, 324) = 324 ⇒ 格子 ~50vp（仍旧好点）
   *     平板横屏 853×533：min(813, 113) = 113 ⇒ 格子 ~15vp（很小，但**整页不再溢出**，
   *       底部按钮回到可点区域；要更大的棋盘必须把整页改成 Scroll，超出本轮范围）
   */
  private boardPx(reserve: number): number {
    const w: number = Math.max(160, Bp.width - 40);   // 40 = GameHost 游戏区左右 padding（Space.lg × 2）
    // ⚠️ 高度下限只能取 96：原来写 160 的话，533vp 横屏算出 113 会被**抬到 160**
    //    ⇒ 棋盘反而比可用空间高 47vp，底部又溢出（等于把刚修好的 bug 请回来）。
    //    96 只用来防「窗口极小时算出 0/负数」，正常设备根本碰不到。
    const h: number = Math.max(96, Bp.height - reserve);
    return Math.min(w, h);
  }

  build() {
    // ★★★ 2026-10-30：reserve 从 420 减到 300（让棋盘从 96vp 变成 176vp），
    //   代价是整页会超高 ⇒ **必须同时套 Scroll**，否则底部按钮又被挤出屏。
    //   这两件事必须一起做 —— 只做一件就是把旧 bug 请回来。
    Scroll() {
      Column({ space: Space.md }) {
        Row({ space: Space.md }) {
          Column({ space: 2 }) {
          Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(this.filledCount()) + '/36'))
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
          Text((TG('空格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(N * N - this.filledCount())))
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
                Text(this.vals[(r * N + c)] > 0 ? String(this.vals[(r * N + c)]) : '')
                .fontSize(FontSize.xl)
                .fontWeight(this.given[(r * N + c)] ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.given[(r * N + c)] ? this.theme.ink : Palette.primary)
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .backgroundColor(this.sel === (r * N + c) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
                (this.given[(r * N + c)] ? this.theme.surface : this.theme.surfaceAlt))
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
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[(r * N + c)]) { this.sel = (r * N + c); } }); })
                .onClick(() => {
                Haptics.tick();
                if (!this.over && !this.given[(r * N + c)]) {
                this.sel = (r * N + c);
                }
                })
              }, (c: number) => 'fm' + r + '-' + c)
            }
            .width('100%')
          }, (r: number) => 'fmr' + r)
        }
        // ★★★ 2026-10-30（布局 bug ① 的主修点）：
        //   改前：`.width('100%')` + `.constraintSize({ maxHeight: '46%' })`
        //         ⇒ 格子 aspectRatio 把高度锁成宽度，板高 = 813vp，46% 只给 195vp ⇒ 溢出 4.2 倍
        //   改后：宽高都交给 boardPx()（正方形），格子按宽度均分出来的行高正好填满容器
        //         ⇒ 板下 2 行数字键 + 按钮行 + 状态行全部留在屏内
        .width(this.boardPx(BOARD_RESERVE))
        .height(this.boardPx(BOARD_RESERVE))
        .alignSelf(ItemAlign.Center)
        .padding(Space.xs)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)

        Row({ space: Space.xs }) {
          ForEach([1, 2, 3, 4], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(44))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.setVal((d)); }); })
            .onClick(() => {
            Haptics.tick();
            this.setVal((d));
            })
          }, (d: number) => 'fk' + d)
        }
        .width('100%')

        Row({ space: Space.xs }) {
          ForEach([5, 6, 7, 8], (d: number) => {
            Text(String((d)))
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(44))
            .backgroundColor(this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.setVal((d)); }); })
            .onClick(() => {
            Haptics.tick();
            this.setVal((d));
            })
          }, (d: number) => 'fk2' + d)
        }
        .width('100%')

        Row({ space: Space.md }) {
          Button(TG('清除本格'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.sm)
            .fontColor(this.theme.inkSoft)
            .backgroundColor(this.theme.surfaceAlt)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(44))
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.setVal(0); }); })
            .onClick(() => {
              Haptics.tap();
              this.setVal(0);
            })
          Button(TG('提示'))
            .layoutWeight(1)
            .height(44)
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
            .fontColor('#FFFFFF')
            .backgroundColor(Palette.cyan)
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

        Text(this.over ? (this.won ? '🎉 每块大小都对，通关！' : TG('步数用尽，重开一题吧')) :
          '粗体数字是题目给的提示，浅底格是尚未填的')
          .fontSize(FontSize.xxs)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint).animation({ duration: Motion.fast, curve: Motion.snap() })
      }
      .onTouch((e: TouchEvent) => {
        // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
        if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
      })
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }






}
