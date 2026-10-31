/**
 * 幻方 —— 行列对角线和相等
 * 玩法：3×3 幻方挖 4 格，从托盘选数字填回；填满即校验八条线。
 * 胜负：120 秒内过 3 关 ⇒ 通关；超时或错满 4 次 ⇒ 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const SIDE: number = 3; const CELLS: number = 9; const BLANKS: number = 4; const MAGIC: number = 15;
const ROUNDS: number = 3; const MAX_ERR: number = 4; const LIMIT: number = 120; const TICK_MS: number = 1000;
const IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const ROWS: number[] = [0, 1, 2];
const LINES: number[][] = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
const BASE: number[] = [2, 7, 6, 9, 5, 1, 4, 3, 8];

function shuffled(src: number[]): number[] {
  const out: number[] = src.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

/** 随机取一个幻方形态（旋转 × 镜像仍是幻方） */
function magicSquare(): number[] {
  let v: number[] = BASE.slice();
  const turns: number = Math.floor(Math.random() * 4);
  for (let t = 0; t < turns; t++) {
    const rot: number[] = new Array<number>(CELLS).fill(0);
    for (let i = 0; i < CELLS; i++) {
      const row: number = Math.floor(i / SIDE); const col: number = i % SIDE;
      rot[col * SIDE + (SIDE - 1 - row)] = v[i];
    }
    v = rot;
  }
  if (Math.random() < 0.5) { return v; }
  const mir: number[] = new Array<number>(CELLS).fill(0);
  for (let i = 0; i < CELLS; i++) {
    const row: number = Math.floor(i / SIDE); const col: number = i % SIDE;
    mir[row * SIDE + (SIDE - 1 - col)] = v[i];
  }
  return mir;
}

@Component
export struct GMagicSquares {
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
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private board: number[] = [];
  @State private fixed: boolean[] = [];
  @State private pool: number[] = [];
  @State private sel: number = -1;
  @State private round: number = 1;
  @State private errors: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1; private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMagicSquares')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private reset(): void {
    this.stop();
    this.round = 1; this.errors = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.newRound();
    this.msg = TG2('让每行、每列、两条对角线的和都等于 {0}', String(MAGIC));
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到')); }
  }

  private newRound(): void {
    const solved9: number[] = magicSquare();
    const holes: number[] = shuffled(IDX).slice(0, BLANKS);
    const board: number[] = solved9.slice();
    const fixed: boolean[] = [];
    const pool: number[] = [];
    for (let i = 0; i < CELLS; i++) { fixed.push(true); }
    for (let k = 0; k < holes.length; k++) {
      const at: number = holes[k];
      pool.push(solved9[at]); board[at] = 0; fixed[at] = false;
    }
    this.board = board; this.fixed = fixed; this.pool = shuffled(pool); this.sel = -1;
  }

  private pickNum(i: number): void {
    if (this.over) { return; }
    this.sel = i;
    this.msg = TG2('已选 {0} —— 点棋盘上的空格放进去', String(this.pool[i]));
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
    const nf: number[] = this.nextFill();
    if (nf[0] < 0 || nf[1] < 0) {
      return false;
    }
    const pi: number = this.pool.indexOf(nf[1]);
    if (pi < 0) {
      return false;
    }
    if (this.sel !== pi) {
      this.pickNum(pi);
      return true;
    }
    this.tapCell(nf[0]);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值没直接存（题目是挖洞挖出来的）⇒ 现场解：全排列 + 八线校验（最多 4! = 24 种）
  /** 递归填空格，八线全对时返回 blanks[0] 该填的数，无解返回 -1 */
  private fillBlanks(blanks: number[], k: number, bd: number[], used: boolean[]): number {
    if (k >= blanks.length) {
      for (let q = 0; q < LINES.length; q++) {
        const ln: number[] = LINES[q];
        if (bd[ln[0]] + bd[ln[1]] + bd[ln[2]] !== MAGIC) {
          return -1;
        }
      }
      return bd[blanks[0]];
    }
    for (let p = 0; p < this.pool.length; p++) {
      if (used[p]) {
        continue;
      }
      used[p] = true;
      const nb: number[] = bd.slice();
      nb[blanks[k]] = this.pool[p];
      const got: number = this.fillBlanks(blanks, k + 1, nb, used);
      if (got >= 0) {
        return got;
      }
      used[p] = false;
    }
    return -1;
  }

  /** 第一个空着的格子；返回 [格子, 该填的数]，没有返回 [-1, -1] */
  private nextFill(): number[] {
    const blanks: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (!this.fixed[i] && this.board[i] === 0) {
        blanks.push(i);
      }
    }
    if (blanks.length === 0) {
      return [-1, -1];
    }
    const used: boolean[] = new Array<boolean>(this.pool.length).fill(false);
    const want: number = this.fillBlanks(blanks, 0, this.board.slice(), used);
    return [blanks[0], want];
  }

  /** 提示：报哪个空格填几 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const nf: number[] = this.nextFill();
    if (nf[0] < 0 || nf[1] < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(nf[0] / SIDE) + 1;
    const c: number = (nf[0] % SIDE) + 1;
    return Hint.make([nf[0]],
      TG2('第 {0} 行第 {1} 列填 {2}', String(r), String(c), String(nf[1])),
      TG2('Row {0}, column {1} takes {2}', String(r), String(c), String(nf[1])), t0);
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

  private tapCell(i: number): void {
    if (this.over) { return; }
    if (this.fixed[i]) { this.msg = TG('这格是题目给的，不能动'); return; }
    if (this.board[i] !== 0) {                       // 取回托盘
      const b2: number[] = this.board.slice();
      const back: number = b2[i];
      b2[i] = 0;
      const p2: number[] = this.pool.slice();
      p2.push(back);
      this.board = b2; this.pool = p2; this.sel = -1;
      this.msg = TG2('已取回 {0}', String(back));
      return;
    }
    if (this.sel < 0) { this.msg = TG('先在下面托盘里选一个数字'); return; }
    const put: number = this.pool[this.sel];
    const b3: number[] = this.board.slice();
    const p3: number[] = this.pool.slice();
    b3[i] = put; p3.splice(this.sel, 1);
    this.board = b3; this.pool = p3; this.sel = -1;
    if (p3.length === 0) { this.check(); } else { this.msg = TG('还差 ') + String(p3.length) + ' 个数字'; }
  }

  private check(): void {
    let ok: boolean = true;
    for (let k = 0; k < LINES.length; k++) {
      const ln: number[] = LINES[k];
      if (this.board[ln[0]] + this.board[ln[1]] + this.board[ln[2]] !== MAGIC) { ok = false; }
    }
    if (ok) {
      this.score = this.score + 120 + this.left; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      if (this.round >= ROUNDS) { this.end(true, TG('🎉 三关全过')); return; }
      this.round = this.round + 1;
      this.newRound();
      this.msg = TG2("✅ 幻方成立！进入第 {0} 关",Digits(String(this.round), this.langCode));
      return;
    }
    this.errors = this.errors + 1;
    this.score = Math.max(0, this.score - 15); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.errors >= MAX_ERR) { this.end(false, '❌ 错了 ' + String(MAX_ERR) + TG(' 次')); return; }
    this.clearBlanks();
    this.msg = TG2('❌ 有线不对（错 {0}/{1}），已清空重来', String(this.errors), String(MAX_ERR));
  }

  private clearBlanks(): void {
    const board: number[] = this.board.slice();
    const back: number[] = [];
    for (let i = 0; i < CELLS; i++) {
      if (!this.fixed[i] && board[i] !== 0) { back.push(board[i]); board[i] = 0; }
    }
    this.board = board; this.pool = shuffled(back); this.sel = -1;
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'magic_squares', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.round
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(ROUNDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(ROWS, (c: number) => { Text(this.board[(r * SIDE + c)] === 0 ? '' : String(this.board[(r * SIDE + c)]))
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor(this.fixed[(r * SIDE + c)] ? this.theme.ink : Palette.sky)
            .layoutWeight(1).aspectRatio(1).borderRadius(Radius.md)
            .backgroundColor(this.fixed[(r * SIDE + c)] ? this.theme.surface : (this.theme.isDark ? '#16283A' : '#E0F2FE'))
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapCell((r * SIDE + c)); }); })
            .onClick(() => { Haptics.tick(); this.tapCell((r * SIDE + c)); }) }, (c: number) => 'mc' + c)
          }.width('100%')
        }, (r: number) => 'mr' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.sm }) {
        ForEach(this.pool, (v: number, i: number) => { Text(String((v)))
        .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.sel === (i) ? '#FFFFFF' : this.theme.ink)
        .layoutWeight(1).height(Cell.of(56)).borderRadius(Radius.md).shadow(Shadow.card)
        .backgroundColor(this.sel === (i) ? Palette.sky : this.theme.surface)
        .scale({ x: this.sel === (i) ? 1.06 : 1, y: this.sel === (i) ? 1.06 : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pickNum((i)); }); })
        .onClick(() => { Haptics.tick(); this.pickNum((i)); }) }, (v: number) => 'mp' + v)
      }.width('100%').height(Cell.of(64))

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.sky)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：点已填的格子可以把数字取回托盘'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
