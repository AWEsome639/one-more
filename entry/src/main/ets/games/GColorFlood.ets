/**
 * 色彩洪水（Flood-It）🎨
 *
 * 规则：棋盘左上角是"洪水"起点，每步选一种颜色，把与左上角连通的一整块染成该色。
 * 胜负：步数上限内整盘同色 = 通关；步数用尽仍未统一 = 失败。
 */

import { A11y } from '../core/A11y';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
// ★ 2026-10-30 布局 bug ② 修复：棋盘边长要用 Bp（当前窗口宽/高）反算，不再依赖 aspectRatio
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 12;
const MAX_MOVES: number = 25;
const COLORS: string[] = ['#EF4444', '#F59E0B', '#10B981', '#0EA5E9', '#8B5CF6', '#EC4899'];

/**
 * 棋盘之外的纵向预留（vp）—— 按全项目最苛刻的 533vp 横屏口径逐项拆开算：
 *   顶栏           88   （GameHost：padding top 28 + 图标行 44 + padding bottom 16）
 *   底 padding     20   （GameHost 游戏区 padding bottom = Space.lg）
 *   HintBar        38   （顶部「提示 / AI 代打」条，barHeight 默认 38）
 *   信息行         64   （两张卡片：padding 10×2 + xxs 12 与 xl 20 两行 + 行距 2）
 *   颜色行         54   （6 个色块 Cell.of(48) 在平板 ×1.12）
 *   按钮行         49   （说明 / 提示 / 重开）
 *   行间距         64   （Column space = Space.md(16) × 4 处间隙）
 *   ⇒ 88+20+38+64+54+49+64 = 377，取 380 留 3vp 余量
 *
 * ⚠️ 静态审计里建议的 280 **不能直接用**：它漏了 HintBar(38) 与 Column 的 4 个 16vp 间隙(64)，
 *    照 280 反算棋盘会得到 253vp，整页仍溢出约 100vp —— 颜色行仍会被棋盘压住，等于没修。
 */
// ★★★ 2026-10-30（第 9 次修「底部覆盖」之后的新发现）：
//   套了 Scroll 之后，"必须一屏装下"这个约束**已经不存在了**。
//   reserve=380 在 533vp 高的游戏区（实际约 476vp）里只给棋盘留下 96vp
//   ⇒ 12×12 每格 8vp ≈ 24px，小到不好点（真机量出来的，不是估的）。
//
//   ⇒ 改成 300：棋盘可得约 176vp（每格 14.7vp ≈ 44px，正好是推荐的最小可点尺寸），
//     整页仍可滚动，底部按钮照样够得着 —— **两个目标不再互相打架**。
//
//   为什么不是更小（如 240）：
//     240 ⇒ 棋盘 236vp（每格 20vp），但一屏只装得下棋盘，
//     颜色行和按钮全在下一屏 ⇒ **每次点颜色都要滚，手感极差**。
//   300 是"棋盘够大"与"颜色行同屏可见"的平衡点。
const BOARD_RESERVE: number = 300;

/** 把与 0 号格连通且同色的一整块染成 to，返回新数组 */
function floodTo(cells: number[], to: number): number[] {
  const out: number[] = cells.slice();
  const src: number = out[0];
  if (src === to) {
    return out;
  }
  const st: number[] = [0];
  out[0] = to;
  while (st.length > 0) {
    const i: number = st[st.length - 1];
    st.splice(st.length - 1, 1);
    const r: number = Math.floor(i / N);
    const c: number = i - r * N;
    if (c > 0 && out[i - 1] === src) {
      out[i - 1] = to;
      st.push(i - 1);
    }
    if (c < N - 1 && out[i + 1] === src) {
      out[i + 1] = to;
      st.push(i + 1);
    }
    if (r > 0 && out[i - N] === src) {
      out[i - N] = to;
      st.push(i - N);
    }
    if (r < N - 1 && out[i + N] === src) {
      out[i + N] = to;
      st.push(i + N);
    }
  }
  return out;
}

@Component
export struct GColorFlood {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: number[] = [];
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GColorFlood')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const c: number[] = [];
    for (let i = 0; i < N * N; i++) {
      c.push(Math.floor(Math.random() * COLORS.length));
    }
    this.cells = c;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  /** 与起点同色的格子数 —— 进度条口径 */
  private filled(): number {
    let n: number = 0;
    const head: number = this.cells.length > 0 ? this.cells[0] : 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === head) {
        n++;
      }
    }
    return n;
  }

  private pick(color: number): void {
    if (this.over || this.cells.length === 0) {
      return;
    }
    const head: number = this.cells[0];
    if (head === color) {
      return;   // 同色无效果，不记步
    }
    this.cells = floodTo(this.cells, color);
    this.moves++;
    if (this.filled() === N * N) {
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


  /**
   * ★ 2026-10-23 修：这里必须算**从左上角连通的区域大小**，
   *   不能算「全盘同色格数」。
   *   原来写错成后者：base = 31（连通区），而各颜色的全盘同色格只有 ~24，
   *   ⇒ 24 <= 31 ⇒ 每一种颜色都被「必须有收益」的检查跳过 ⇒ bestC = -1
   *   ⇒ 提示永远返回「算不出来」。这是真机验证抓出来的。
   */
  private floodFilled(arr: number[]): number {
    if (arr.length === 0) {
      return 0;
    }
    const head: number = arr[0];
    const seen: boolean[] = new Array<boolean>(arr.length).fill(false);
    const st: number[] = [0];
    seen[0] = true;
    let n: number = 0;
    while (st.length > 0) {
      const i: number = st[st.length - 1];
      st.splice(st.length - 1, 1);
      if (arr[i] !== head) {
        continue;
      }
      n++;
      const r: number = Math.floor(i / N);
      const c: number = i - r * N;
      if (c > 0 && !seen[i - 1]) {
        seen[i - 1] = true;
        st.push(i - 1);
      }
      if (c < N - 1 && !seen[i + 1]) {
        seen[i + 1] = true;
        st.push(i + 1);
      }
      if (r > 0 && !seen[i - N]) {
        seen[i - N] = true;
        st.push(i - N);
      }
      if (r < N - 1 && !seen[i + N]) {
        seen[i + N] = true;
        st.push(i + N);
      }
    }
    return n;
  }

  /**
   * 贪心跑到底：每步选能吞掉最多格的颜色，返回剩余步数（跑不完返回 999）
   * 只用于评估首步好坏，不是最优求解器。
   */
  private rollout(first: number): number {
    let cur: number[] = floodTo(this.cells, first);
    let steps: number = 1;
    for (let k = 0; k < 40; k++) {
      const filled: number = this.floodFilled(cur);
      if (filled === N * N) {
        return steps;
      }
      let bestC: number = -1;
      let bestGain: number = -1;
      const head: number = cur[0];
      for (let c = 0; c < COLORS.length; c++) {
        if (c === head) {
          continue;
        }
        const g: number = this.floodFilled(floodTo(cur, c));
        if (g > bestGain) {
          bestGain = g;
          bestC = c;
        }
      }
      if (bestC < 0 || bestGain <= filled) {
        return 999;
      }
      cur = floodTo(cur, bestC);
      steps++;
    }
    return 999;
  }

  /**
   * ★ 2026-10-23 第二期：色彩洪水提示
   *
   * 对 6 种颜色各跑一次「贪心到底」的 rollout，选总步数最少的那种当首步。
   * 相当于一层前瞻 + 贪心收尾，比纯贪心稳，又不用做全搜索。
   * ⚠️ 不是最优解 —— 文案只说「大约再 N 步」，不说「最优」。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.cells.length === 0) {
      return Hint.none('none');
    }
    const head: number = this.cells[0];
    const base: number = this.floodFilled(this.cells);
    let bestC: number = -1;
    let bestSteps: number = 1000;
    for (let c = 0; c < COLORS.length; c++) {
      if (c === head) {
        continue;
      }
      // ★ 2026-10-23 修：先要求**这一步真的有收益**。
      //   原来直接比 rollout 步数，可能选中一个和当前区域根本不沾边的颜色
      //   （换了色但一格没吞，等于白走一步）。测试抓到 20 个随机盘里 11 个这样。
      if (this.floodFilled(floodTo(this.cells, c)) <= base) {
        continue;
      }
      const st: number = this.rollout(c);
      if (st < bestSteps) {
        bestSteps = st;
        bestC = c;
      }
    }
    if (bestC < 0) {
      return Hint.none('none');
    }
    const name: string = TG2('第 {0} 种颜色', String(bestC + 1));
    if (bestSteps >= 999) {
      return Hint.make([bestC],
        TG2('试试{0}（这一路走下去可能还有更优的）', name),
        TG2('Try {0} — there may be a better line further on', name), t0);
    }
    return Hint.make([bestC],
      TG2('用{0}，大约再 {1} 步就能连成一片', name, String(bestSteps)),
      TG2('Pick {0}: about {1} more moves to finish', name, String(bestSteps)), t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // computeHint 用 rollout 选出"下一个该选的颜色"，永远不会给出空（除非无收益）
  // ⇒ 代打就是反复 pick 它。
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length === 0) {
      return false;
    }
    this.pick(r.cells[0]);
    return !this.over;
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
    // ★ 改用框架的 toast：这款的底部按钮行很挤，加 Text 会压到按钮上
    Hint.toastResult(r, TG('这一步算不出来，重开一局试试'));
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'color_flood',
      solved: solved,
      score: solved ? Math.max(200, 1200 - this.moves * 40) : this.filled() * 12,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * 棋盘边长（vp）：**宽度与可用高度取小者** —— 不许 aspectRatio 自行决定高度。
   *
   * ★★★ 2026-10-30 修布局 bug ②（12×12 棋盘尺寸与容器约束自相矛盾）：
   *   改前同时存在三样东西：
   *     ① 格子 `layoutWeight(1) + aspectRatio(1)`  ⇒ 12 行高度被 12 列宽度锁死
   *     ② 容器 `.aspectRatio(1)`                    ⇒ 容器自己又按宽度定高
   *     ③ 容器 `.constraintSize({ maxHeight: '46%' })` ⇒ 再把容器压到 46%
   *   三者互相打架：容器被压到 342vp，格子仍要按宽度撑到 418vp
   *   ⇒ **内容溢出到下方颜色行，棋盘最后 2~3 行被按钮盖住**
   *   （上一轮注释写"已回退 aspectRatio"，但代码里它一直在，注释与代码矛盾 —— 一并删掉。）
   *
   *   ⇒ 现在只留一个口径：棋盘是**定宽定高的正方形**，
   *     边长 = min(可用宽, 屏高 - 预留)，格子由宽度均分、高度自然等于宽度
   *     ⇒ 12 行行高总和恰好等于容器高，既不会溢出、也不会被压扁。
   *     手机竖屏 440×744：min(400, 364) = 364 ⇒ 格子 ~27vp（比改前更好看）
   *     平板横屏 853×533：min(813, 153) = 153 ⇒ 格子 ~10vp（很小，但**整页不再溢出**；
   *       12×12 要在 533vp 横屏上放大，只能把整页改成 Scroll，超出本轮范围）
   */
  private boardPx(reserve: number): number {
    const w: number = Math.max(160, Bp.width - 40);   // 40 = GameHost 游戏区左右 padding（Space.lg × 2）
    // ⚠️ 高度下限只能取 96：原来写 160 的话，533vp 横屏算出 153 会被**抬到 160**
    //    ⇒ 棋盘反而比可用空间高 7vp，底部又溢出（等于把刚修好的 bug 请回来）。
    //    96 只用来防「窗口极小时算出 0/负数」，正常设备根本碰不到。
    const h: number = Math.max(96, Bp.height - reserve);
    return Math.min(w, h);
  }

  build() {
    // ★★★ 2026-10-30：**色彩洪水底部按钮覆盖棋盘** 的结构修复
    //   之前试过 8 次"调约束"（限高 / aspectRatio / 限宽）全失败：
    //     只限高      ⇒ 容器变矮、内容溢出 ⇒ 按钮被盖（原问题）
    //     限高+aspectRatio ⇒ 两者打架，容器被压成小块
    //     限高+限宽   ⇒ vh 在 maxWidth 里语义不明，仍是小块
    //   ⇒ 真解不是"调约束"，是**改结构**：整页套 Scroll，
    //     内容自然超高时可滚，而不是硬塞进一屏。
    //   ★ 同一套结构已在 GBlockEscape / GNavonHierarchical / GMirrorTracing
    //     上真机验过（第 511 轮），三款都成立。
    Scroll() {
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
        Row({ space: Space.md }) {
          Column({ space: 2 }) {
          Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(this.moves) + '/' + String(this.diffTotal)))
          .fontSize(FontSize.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text((TG('统一度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((String(this.filled()) + '/' + String(N * N)))
          .fontSize(FontSize.xl)
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
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (r: number) => {
            Row({ space: 2 }) {
              ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (c: number) => {
                Stack() {
                  // ★ 色盲辅助（项目 D ③）：12×12 太密，字形用小号粗体 + 阴影保证可读
                  Text(A11y.glyph(this.cells[(r * N + c)]))
                    .fontSize(9).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    .textShadow({ radius: 2, color: '#000000B3', offsetX: 0, offsetY: 1 })
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .backgroundColor(COLORS[this.cells[(r * N + c)]])
                .borderRadius(Radius.xs)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'cf' + r + '-' + c)
            }
            .width('100%')
          }, (r: number) => 'cfr' + r)
        }
        // ★★★ 2026-10-30（布局 bug ② 的主修点）：
        //   改前：`.width('100%')` + `.aspectRatio(1)` + `.constraintSize({ maxHeight: '46%' })`
        //         —— 容器与格子都用 aspectRatio 定高，再叠一个 46% 上限，三者互相打架：
        //         容器被压到 342vp、格子仍要 418vp ⇒ **棋盘最后 2~3 行溢出到颜色行上面**。
        //   改后：删掉 aspectRatio 与 maxHeight 百分比，宽高都由 boardPx() 给定（正方形），
        //         格子按宽度均分出来的行高正好填满容器 ⇒ 棋盘完整、颜色行不再被压住。
        .width(this.boardPx(BOARD_RESERVE))
        .height(this.boardPx(BOARD_RESERVE))
        .alignSelf(ItemAlign.Center)
        .padding(Space.xs)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.md)

        Row({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
            Stack() {
            Text(this.cells.length > 0 && this.cells[0] === (i) ? '起点' : '')
            .fontSize(FontSize.xxs)
            .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .height(Cell.of(48))
            .backgroundColor(COLORS[(i)])
            .borderRadius(Radius.md)
            .scale({
            x: this.pressed === (i) ? Motion.pressScale : 1,
            y: this.pressed === (i) ? Motion.pressScale : 1
            })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => {
            if (e.type === TouchType.Down) {
            this.pressed = (i);
            } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressed = -1;
            }
            })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((i)); }); })
            .onClick(() => {
            Haptics.tick();
            this.pick((i));
            })
          }, (i: number) => 'cfp' + i)
        }
        .width('100%')

        Row({ space: Space.md }) {
          Button(this.over ? (this.won ? TG('🎉 已通关') : TG('已结束')) : '点色块染左上角连通区')
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
            .layoutWeight(1)
            .height(44)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
            .onClick(() => {
              this.askHint();
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
