/**
 * 宝石迷阵 —— 交换相邻宝石，凑出三个以上同色即消除
 *
 * 玩法：点一颗宝石 → 点它上下左右相邻的一颗 ⇒ 交换；换出三连就消，消完上面的会掉下来接着连消
 * 胜负：MOVE_LIMIT 步内达到 TARGET 分 ⇒ solved=true；步数用完没到 ⇒ solved=false
 * 坐标口径：整盘在 7×7 网格里，格子用 layoutWeight(1) 均分，视觉与机型无关
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 7;               // 盘面边长
const KINDS: number = 5;           // 宝石种类
const MOVE_LIMIT: number = 20;     // 步数上限
const TARGET: number = 600;        // 通关分数线
const PER_GEM: number = 10;        // 每消一颗的分

const GEMS: string[] = ['💎', '🔥', '🍀', '🔮', '💧'];
const GEM_COLORS: string[] = [
  Palette.sky, Palette.orange, Palette.emerald, Palette.violet, Palette.primary
];

/** 0..n-1 下标数组（给 ForEach 用，只建一次） */
function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GBejeweled {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-10-31 演示动画改造：三拍节拍 + 强视觉引导
  //   奥森原话：「我认为的'演示'不是这样的呀！应该就是一段演示动画」
  //   旧实现一个 tick 内 tap(a);tap(b) 全做完 ⇒ 玩家只看到格子瞬间变了。
  @State private demoGuideA: number = -1;   // 第 1 拍要高亮的格（交换源）
  @State private demoGuideB: number = -1;   // 第 1 拍要高亮的格（交换目标）
  @State private demoRound: number = 0;     // 演到第几轮
  @State private demoPhase: number = 0;     // 0=引导 1=执行 2=结果
  // ★★ 2026-10-31 奥森要求：**演示不该让玩家得分** —— 它是一段动画，不是一局游戏。
  //   ⇒ 演示前把（棋盘/得分/剩余步数）快照下来，演示结束后**原样恢复**。
  //     演示期间屏上看到的是"预演"，玩家的真实对局状态从头到尾没被动过。
  private demoSnapBoard: number[] = [];
  private demoSnapScore: number = 0;
  private demoSnapLeft: number = 0;
  @State private demoScored: number = 0;    // 演示期间"假的"得分（只显示，不进记录）
  @State private board: number[] = [];
  @State private sel: number = -1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(MOVE_LIMIT);
  @State private left: number = 0;
  @State private msg: string = TG('点一颗宝石，再点它相邻的一颗');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBejeweled')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.timeNow(MOVE_LIMIT);
    this.reset();
  }

  private idx(r: number, c: number): number {
    return r * N + c;
  }

  private reset(): void {
    this.board = this.fill();
    this.sel = -1;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点一颗宝石，再点它相邻的一颗');
    this.startAt = Date.now();
  }

  /** 开局盘面：随机填，且保证开局没有现成三连 */
  private fill(): number[] {
    let b: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < b.length; i++) {
      b[i] = Math.floor(Math.random() * KINDS);
    }
    for (let t = 0; t < 80; t++) {
      const m: number[] = this.mark(b);
      let again: boolean = false;
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = Math.floor(Math.random() * KINDS);
          again = true;
        }
      }
      if (!again) {
        break;
      }
    }
    return b;
  }

  /** 标记所有已成三连及以上的格子（1 = 要消） */
  private mark(b: number[]): number[] {
    const m: number[] = new Array<number>(N * N).fill(0);
    for (let r = 0; r < N; r++) {
      let run: number = 1;
      for (let c = 1; c <= N; c++) {
        const same: boolean = c < N && b[this.idx(r, c)] === b[this.idx(r, c - 1)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = c - run; k < c; k++) {
              m[this.idx(r, k)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    for (let c = 0; c < N; c++) {
      let run: number = 1;
      for (let r = 1; r <= N; r++) {
        const same: boolean = r < N && b[this.idx(r, c)] === b[this.idx(r - 1, c)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = r - run; k < r; k++) {
              m[this.idx(k, c)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    return m;
  }

  private hasMark(b: number[]): boolean {
    const m: number[] = this.mark(b);
    for (let i = 0; i < m.length; i++) {
      if (m[i] === 1) {
        return true;
      }
    }
    return false;
  }

  /** 消掉空格后向下压实，顶上补新宝石（原地改 b） */
  private settle(b: number[]): void {
    for (let c = 0; c < N; c++) {
      let write: number = N - 1;
      for (let r = N - 1; r >= 0; r--) {
        const v: number = b[this.idx(r, c)];
        if (v >= 0) {
          b[this.idx(write, c)] = v;
          if (write !== r) {
            b[this.idx(r, c)] = -1;
          }
          write--;
        }
      }
      for (let r = write; r >= 0; r--) {
        b[this.idx(r, c)] = Math.floor(Math.random() * KINDS);
      }
    }
  }

  /** 反复消除直到没有三连；返回本次连消总分（含 combo 加成） */
  private resolve(): number {
    let gained: number = 0;
    let combo: number = 1;
    while (combo <= 30) {          // 上限兜底：连消不会无限，但绝不让自己卡死
      const b: number[] = this.board.slice();
      const m: number[] = this.mark(b);
      let cnt: number = 0;
      for (let i = 0; i < m.length; i++) {
        if (m[i] === 1) {
          cnt++;
        }
      }
      if (cnt === 0) {
        break;
      }
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = -1;
        }
      }
      this.settle(b);
      this.board = b;
      gained += cnt * PER_GEM * combo;
      combo++;
    }
    return gained;
  }

  private adjacent(a: number, b: number): boolean {
    const ar: number = Math.floor(a / N);
    const ac: number = a % N;
    const br: number = Math.floor(b / N);
    const bc: number = b % N;
    return Math.abs(ar - br) + Math.abs(ac - bc) === 1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这盘没有"答案字段"—— 现搜一对能换出三连的相邻格（判据就是游戏自己的 hasMark）
  private aiSwapOk(a: number, b: number): boolean {
    const t: number[] = this.board.slice();
    const tmp: number = t[a];
    t[a] = t[b];
    t[b] = tmp;
    return this.hasMark(t);
  }

  /** 返回 a * 100 + b（一对可换的相邻格），-1 = 没有可换的 */
  private aiFindPair(): number {
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const a: number = r * N + c;
        if (c + 1 < N && this.aiSwapOk(a, a + 1)) {
          return a * 100 + (a + 1);
        }
        if (r + 1 < N && this.aiSwapOk(a, a + N)) {
          return a * 100 + (a + N);
        }
      }
    }
    return -1;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  /** 演示：**三拍**（引导 → 执行 → 结果），演 2 轮 ≈ 4.6 秒
   *  ★ 为什么改：旧版一个 tick 内做完交换，玩家看不到"在指哪、做了什么"。
   *    新版第 1 拍先把两颗要交换的宝石**圈出来并放大**，配一句"看这两颗"；
   *    第 2 拍才真正交换（280ms 短促）；第 3 拍留 1.15 秒让你看清"消掉了"。
   */
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }
    if (this.over) { this.demoFinish(); return -1; }

    // ── 第 1 拍：引导 ──
    if (this.demoPhase === 0) {
      this.sel = -1;
      const m: number = this.aiFindPair();
      if (m < 0 || this.demoRound >= 2) { this.demoFinish(); return -1; }
      this.demoGuideA = Math.floor(m / 100);
      this.demoGuideB = m % 100;
      this.msg = TG('看这两颗：交换它们，三个同色就消掉');
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    // ── 第 2 拍：执行 ──
    if (this.demoPhase === 1) {
      const a: number = this.demoGuideA;
      const b: number = this.demoGuideB;
      this.demoGuideA = -1;
      this.demoGuideB = -1;
      if (a >= 0 && b >= 0) {
        this.tap(a);
        this.tap(b);
      }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    // ── 第 3 拍：结果 ──
    this.demoRound = this.demoRound + 1;
    this.demoScored = this.score - this.demoSnapScore;
    this.msg = this.demoRound >= 2
      ? TG('就这样连。这就是全部玩法 —— 碰一下屏幕，换你来')
      : TG2('消掉了！这一下能拿 +{0} 分（演示不计分）', String(this.demoScored));
    this.demoPhase = 0;
    if (this.demoRound >= 2) {
      this.demoFinish();
      return Demo.RESULT_MS;
    }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoGuideA = -1;
    this.demoGuideB = -1;
    this.demoPhase = 0;
    this.demoRound = 0;
    // 原样恢复 —— 演示期间的一切改动都被抹掉
    if (this.demoSnapBoard.length === this.board.length) {
      this.board = this.demoSnapBoard;
    }
    this.score = this.demoSnapScore;
    this.left = this.demoSnapLeft;
    this.demoScored = 0;
    this.demoSnapBoard = [];
    this.over = false;
    this.won = false;
    this.sel = -1;
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
    // 演示前快照：演完原样恢复 ⇒ **玩家不可能因为看演示而得分/失分**
    this.demoSnapBoard = this.board.slice();
    this.demoSnapScore = this.score;
    this.demoSnapLeft = this.left;
    this.demoScored = 0;
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.sel = -1;
    const m: number = this.aiFindPair();
    if (m < 0) {
      return false;
    }
    this.tap(Math.floor(m / 100));
    this.tap(m % 100);
    return !this.over;
  }

  /** 提示：报这一对可换的宝石（报行列，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const m: number = this.aiFindPair();
    if (m < 0) {
      return Hint.none('none');
    }
    const a: number = Math.floor(m / 100);
    const b: number = m % 100;
    const pa: string = (Math.floor(a / N) + 1) + '排' + (a % N + 1) + '列';
    const pb: string = (Math.floor(b / N) + 1) + '排' + (b % N + 1) + '列';
    return Hint.make([a, b], TG2('换 {0} 与 {1} 这两颗能消', pa, pb),
      TG2('Swap {0} with {1} to clear', pa, pb), t0);
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

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.sel < 0) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    if (!this.adjacent(this.sel, i)) {
      this.sel = i;
      return;
    }

    const a: number = this.sel;
    const nb: number[] = this.board.slice();
    const t: number = nb[a];
    nb[a] = nb[i];
    nb[i] = t;

    if (!this.hasMark(nb)) {
      this.sel = i;
      this.msg = TG('这样换不出三连，换一颗试试');
      return;
    }

    this.board = nb;
    this.sel = -1;
    this.left--;
    const gained: number = this.resolve();
    this.score += gained; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.msg = TG2("消除 +{0} 分", gained);
    if (this.left <= 0) {
      this.end();
    }
  }

  private end(): void {
    this.over = true;
    this.won = this.score >= TARGET;
    this.msg = this.won ? '🎉 达标！' : '步数用完，差一点';
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'bejeweled',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: MOVE_LIMIT - this.left
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 棋盘边长（vp）：按「可用宽 / 可用高」取小值
   *  ★★★ 2026-10-30：百分比（70% / 45%）在横竖屏下不可能同时最优
   *    ⇒ 按真实可用空间算。
   */
    private boardPx(): number {
    // ★★★ 2026-10-31 · 第四版（前三版都错，完整记录）：
    //   ① `Bp.height * 0.55`          ⇒ 横屏 293vp，把「重开」挤出屏幕
    //   ② `(Bp.height - 260) * 0.85`  ⇒ 横屏 232vp，**仍然超 27vp**
    //      （实测：棋盘 232vp 时「重开」y=1562px，安全上限 1480px）
    //   ③ 错误原因：**固定部分是绝对值**（顶栏/HintBar/三信息卡/状态/按钮），
    //      不是比例；且我两次都把固定部分估小了。
    //   ④ 用实测数据反推：需要棋盘 ≤ 205vp ⇒ 比例取 **0.70**。
    //      横屏 (533-260)*0.70 = 191vp ⇒ 「重开」约 480vp（安全）
    //      竖屏 (1280-260)*0.70 = 714vp（受宽度限，仍比旧 704 大）
    const FIXED: number = 300;   // ★ 第五版：实测黑白棋固定部分更大，取 300 覆盖所有款
    const w: number = Math.max(160, Bp.width - 40);
    const h: number = Math.max(120, (Bp.height - FIXED) * 0.70);
    return Math.min(w, h);
  }

  build() {
    // ★★★ 2026-10-30：横屏 853×533 下「其余部分就有 368vp」，
    //   棋盘 maxHeight 即便降到 45%（240vp），总计仍有 608vp > 533vp。
    //   ⇒ **必须套 Scroll 兜底**，让玩家能滚到「重开 / 提示 / AI 代打」。
    //   这是本项目第 4 款用同一个 Scroll 模板修好的游戏（前 3 款：
    //   GColorFlood / GFillomino / GBlockEscape 系列）。
    Scroll() {
      Column({ space: Space.sm }) {
        HintBar({
          showHint: true,
          onHintTap: () => { this.askHint(); },
          onAutoTap: () => { this.askAuto(); },
          demoOn: this.demoId >= 0,
          autoOn: this.autoId >= 0
        })
        Row({ space: Space.sm }) {
          Column({ space: 2 }) {
          Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((this.demoId >= 0 ? '—' : Digits(String(this.score), this.langCode))).fontSize(FontSize.lg)
          // ★ 得分跳动
          .scale({ x: this.scorePulse, y: this.scorePulse })
          .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text(Digits(String(TARGET), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
          Column({ space: 2 }) {
          Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text((this.demoId >= 0 ? '—' : Digits(String(this.left), this.langCode))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
          }
          .layoutWeight(1)
          .padding(Space.sm)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .width('100%')

        Column({ space: Space.xs }) {
          ForEach(this.rows, (r: number) => {
            Row({ space: Space.xs }) {
              ForEach(this.rows, (c: number) => {
                Stack() {
                Text(GEMS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
                .fontSize(FontSize.xl)
                }
                .layoutWeight(1)
                .aspectRatio(1)
                .backgroundColor(GEM_COLORS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
                .borderRadius(Radius.sm)
                .scale({
                x: (this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? 1.24 : (this.sel === (this.idx(r, c)) ? 1.14 : 1),
                y: (this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? 1.24 : (this.sel === (this.idx(r, c)) ? 1.14 : 1)
                })
                // ★ 演示引导：被指到的两颗加描边 + 光晕，玩家一眼知道"看这里"
                .border({
                  width: (this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c))) ? 3 : 0,
                  color: Palette.amber
                })
                .shadow((this.demoGuideA === (this.idx(r, c)) || this.demoGuideB === (this.idx(r, c)))
                  ? { radius: 18, color: '#99FFFFFF', offsetX: 0, offsetY: 0 }
                  : Shadow.card)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
                // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
                .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                  .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
                .focusable(Tv.on())
                .focusBox(Tv.box())
                .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((this.idx(r, c))); }); })
                .onClick(() => {
                Haptics.tick();
                this.tap((this.idx(r, c)));
                })
              }, (c: number) => 'c' + c)
            }
            .width('100%')
            .layoutWeight(1)
          }, (r: number) => 'r' + r)
        }
      // ★★★ 2026-10-30 · 用「算出来的边长」，不用百分比
      //   百分比是相对父容器，而父容器横竖屏差一倍多 ⇒ 一个数不可能两头都好：
      //     70%  ⇒ 横屏 373vp 溢出（底部按钮被切）
      //     45%  ⇒ 横屏好了，但**竖屏 1280vp 下只剩 576vp，下方大片空白**（回归）
      //   ⇒ 改成 min(可用宽, 可用高)，两种比例都尽量大、又一定装得下。
      .width(this.boardPx())
      .height(this.boardPx())
        .padding(Space.xs)
        .backgroundColor(this.theme.surfaceAlt)
        .borderRadius(Radius.lg)
        .shadow(Shadow.card)

        Text(this.msg)
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

        Row({ space: Space.md }) {
          Button(TG('重开'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md)
            .fontColor(Color.White)
            .backgroundColor(Palette.primary)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(46))
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
            .onClick(() => {
              Haptics.tap();
              this.reset();
            })
          Button(TG('取消选择'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md)
            .fontColor(this.theme.inkSoft)
            .backgroundColor(this.theme.surfaceAlt)
            .borderRadius(Radius.md)
            .layoutWeight(1)
            .height(Cell.of(46))
            .enabled(!this.over)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.sel = -1; }); })
            .onClick(() => {
              Haptics.tap();
              this.sel = -1;
            })
        }
        .width('100%')

        Text(TG2('每消一颗 +{0}，连消翻倍；{1} 步内拿到 {2} 分算通关',Digits(String(PER_GEM), this.langCode),Digits(String(MOVE_LIMIT), this.langCode),Digits(String(TARGET), this.langCode)))
          .fontSize(FontSize.xxs)
          .fontColor(this.theme.inkFaint)
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
