/**
 * 扫雷 —— 9×9 雷区 / 10 颗雷
 *
 * 玩法：
 *   · 点格子翻开（**首点必安全**：第一下一定不是雷，且周围自动留白）
 *   · 长按插旗；或切到「插旗模式」后单击即插旗
 * 判据：
 *   · 踩雷 ⇒ 本局失败
 *   · 把 10 颗雷之外的 71 格全部翻开 ⇒ 通关
 *
 * 契约：@Prop theme / @Prop @Watch('onRestart') restartToken / onFinish(r)
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const SIDE: number = 9;                        // 9×9
const MINES: number = 10;                      // 10 颗雷
const SAFE: number = SIDE * SIDE - MINES;      // 非雷格总数 71
const IDX9: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];

const LONG_PRESS_MS: number = 350;             // 长按判定时长
const TICK_MS: number = 1000;                  // 计时器步长

/** 棋盘专属配色（浅/深两套）—— 与设计系统的色板同族，棋盘不用图片资源 */
const BOARD_LIGHT: string = '#C9D4E8';
const BOARD_DARK: string = '#0E1116';
const DOWN_LIGHT: string = '#DEE6F6';
const DOWN_DARK: string = '#1B2233';
const OPEN_LIGHT: string = '#F5F8FD';
const OPEN_DARK: string = '#0A0A0A';
const MINE_LIGHT: string = '#FDE2E7';
const MINE_DARK: string = '#3A1219';

interface MineCell {
  mine: boolean;
  open: boolean;
  flag: boolean;
  adj: number;   // 周围雷数 0..8
}

/** 数字 1..8 的配色 —— 全部取自设计系统色板 */
function numColor(n: number): string {
  if (n === 1) {
    return Palette.sky;
  }
  if (n === 2) {
    return Palette.emerald;
  }
  if (n === 3) {
    return Palette.rose;
  }
  if (n === 4) {
    return Palette.violet;
  }
  if (n === 5) {
    return Palette.orange;
  }
  if (n === 6) {
    return Palette.teal;
  }
  if (n === 7) {
    return Palette.amber;
  }
  return Palette.primary;
}

@Component
export struct GMinesweeper {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：雷数按难度（简单 7 / 普通 10 / 困难 13）
  //   MINES 是模块常量，加载时就算死了 ⇒ 必须用运行时的 this.minesTotal
  private minesTotal: number = GameDiff.sizeNow(MINES);
  private safeTotal: number = SIDE * SIDE - GameDiff.sizeNow(MINES);
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
  @State private cells: MineCell[] = [];
  @State private flagMode: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private seconds: number = 0;
  @State private opened: number = 0;
  @State private flags: number = 0;
  @State private pressed: number = -1;
  @State private boom: number = -1;
  /** ★ 第二期：提示说的话（空 = 没提示） */
  @State private hintMsg: string = '';
  /** 提示指向的格子（-1 = 无） */
  @State private hintIdx: number = -1;

  private seeded: boolean = false;      // 是否已经布雷（首点之后才布）
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;
  private longHandled: boolean = false; // 本次触摸是否已按长按处理
  private swallowClick: boolean = false; // 长按抬手后随之而来的 click 要吞掉

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMinesweeper')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.minesTotal = GameDiff.sizeNow(MINES);
    this.safeTotal = SIDE * SIDE - this.minesTotal;
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  // ────────────────────────── 生命周期 / 计时 ──────────────────────────

  private reset(): void {
    this.stopTimer();
    const cs: MineCell[] = [];
    for (let i = 0; i < SIDE * SIDE; i++) {
      const c: MineCell = { mine: false, open: false, flag: false, adj: 0 };
      cs.push(c);
    }
    this.cells = cs;
    this.flagMode = false;
    this.over = false;
    this.won = false;
    this.seconds = 0;
    this.opened = 0;
    this.flags = 0;
    this.pressed = -1;
    this.boom = -1;
    this.seeded = false;
    this.finished = false;
    this.longHandled = false;
    this.swallowClick = false;
    this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (!this.over && !this.finished) {
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

  // ────────────────────────── 数据工具 ──────────────────────────

  private cellAt(i: number): MineCell {
    if (i >= 0 && i < this.cells.length) {
      return this.cells[i];
    }
    const blank: MineCell = { mine: false, open: false, flag: false, adj: 0 };
    return blank;
  }

  private copyCells(): MineCell[] {
    return this.cells.map((c: MineCell) => {
      const n: MineCell = { mine: c.mine, open: c.open, flag: c.flag, adj: c.adj };
      return n;
    });
  }

  /** 第 i 格的 8 邻域（越界自动剔除） */
  private neighbors(i: number): number[] {
    const r: number = Math.floor(i / SIDE);
    const c: number = i % SIDE;
    const out: number[] = [];
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) {
          continue;
        }
        const nr: number = r + dr;
        const nc: number = c + dc;
        if (nr >= 0 && nr < SIDE && nc >= 0 && nc < SIDE) {
          out.push(nr * SIDE + nc);
        }
      }
    }
    return out;
  }

  /** 首点之后才布雷：首格 + 其 8 邻域留空，保证开局必能开出一片 */
  private seed(safeIdx: number): void {
    const cs: MineCell[] = this.copyCells();
    const banned: number[] = this.neighbors(safeIdx).concat([safeIdx]);
    const pool: number[] = [];
    for (let i = 0; i < cs.length; i++) {
      if (banned.indexOf(i) < 0) {
        pool.push(i);
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {   // 洗牌
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    const take: number = pool.length < this.minesTotal ? pool.length : this.minesTotal;
    for (let k = 0; k < take; k++) {
      cs[pool[k]].mine = true;
    }
    for (let i = 0; i < cs.length; i++) {
      if (cs[i].mine) {
        cs[i].adj = 0;
        continue;
      }
      const nb: number[] = this.neighbors(i);
      let a: number = 0;
      for (let k = 0; k < nb.length; k++) {
        if (cs[nb[k]].mine) {
          a++;
        }
      }
      cs[i].adj = a;
    }
    this.cells = cs;
    this.seeded = true;
  }

  private recount(): void {
    let o: number = 0;
    let f: number = 0;
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i].open) {
        o++;
      }
      if (this.cells[i].flag) {
        f++;
      }
    }
    this.opened = o;
    this.flags = f;
  }

  // ────────────────────────── 玩法 ──────────────────────────

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // computeHint 会给两种答案：安全的格（翻开）、是雷的格（插旗）
  // 这游戏自己的 MineCell.mine 就知道是哪一种 ⇒ 按类型分派
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
    // ★ 扫雷靠"提示"走不通：提示遇到"逻辑推不出、得猜"的局面就返回空。
    //   但这款游戏的 MineCell 里有 mine 字段（它自己知道哪格是雷）
    //   ⇒ 代打直接照雷区扫：翻开所有非雷格、给所有雷插旗。
    for (let i = 0; i < this.cells.length; i++) {
      const c: MineCell = this.cellAt(i);
      if (c.mine) {
        if (!c.flag) {
          this.toggleFlag(i);
          return !this.over;
        }
      } else {
        if (!c.open) {
          this.reveal(i);
          return !this.over;
        }
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

  private onCellTap(i: number): void {
    if (this.swallowClick) {
      return;
    }
    if (this.flagMode) {
      this.toggleFlag(i);
    } else {
      this.reveal(i);
    }
  }

  private onCellLongPress(i: number): void {
    this.longHandled = true;
    this.toggleFlag(i);
  }

  /** 翻开：0 邻雷格自动泛洪展开（迭代实现，不用递归） */

  /** 第 i 格的相邻格（纯函数，不依赖组件状态以外的任何东西） */
  private nbOf(i: number, size: number): number[] {
    const r: number = Math.floor(i / size);
    const c: number = i % size;
    const out: number[] = [];
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) {
          continue;
        }
        const rr: number = r + dr;
        const cc: number = c + dc;
        if (rr >= 0 && rr < size && cc >= 0 && cc < size) {
          out.push(rr * size + cc);
        }
      }
    }
    return out;
  }

  /**
   * ★★★ 2026-10-23 第二期：扫雷提示
   *
   * 用两条**纯逻辑**规则（不猜、不作弊看雷）：
   *   A「某已开格的数字 = 周围旗数」⇒ 它其余未开邻格都是**安全的**
   *   B「某已开格的数字 = 周围未开格数 + 旗数」⇒ 它其余未开邻格**全是雷**
   *
   * ⚠️ 绝不去读 cell.mine 来判断（那是作弊）——
   *    玩家要的是"从已知信息能推出什么"，不是"答案是什么"。
   *    这条边界很重要：提示若作弊，游戏的推理乐趣就没了。
   *
   * 都给不出 ⇒ Hint.none()，界面直说「这一步看不出来，得猜」。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const size: number = SIDE;
    // 规则 B 优先（标雷比翻开更"值钱"，因为它防止踩雷）
    for (let i = 0; i < this.cells.length; i++) {
      const c: MineCell = this.cells[i];
      if (!c.open || c.adj <= 0) {
        continue;
      }
      const nbs: number[] = this.nbOf(i, size);
      let flags: number = 0;
      let closed: number = 0;
      for (let k = 0; k < nbs.length; k++) {
        const n: MineCell = this.cells[nbs[k]];
        if (n.flag) {
          flags++;
        } else if (!n.open) {
          closed++;
        }
      }
      // B：已确定的雷数正好填满，其余全开
      if (c.adj === flags && closed > 0) {
        for (let k = 0; k < nbs.length; k++) {
          const j: number = nbs[k];
          if (!this.cells[j].open && !this.cells[j].flag) {
            return Hint.make([j], TG('这一格是安全的，可以翻开'),
              TG('This cell is safe — open it'), t0);
          }
        }
      }
      // A：数字 = 旗 + 未开 ⇒ 未开的全是雷
      if (c.adj === flags + closed && closed > 0) {
        for (let k = 0; k < nbs.length; k++) {
          const j: number = nbs[k];
          if (!this.cells[j].open && !this.cells[j].flag) {
            return Hint.make([j], TG('这一格是雷，插旗吧'),
              TG('This cell is a mine — flag it'), t0);
          }
        }
      }
    }
    return Hint.none('none');
  }

  /** 点「提示」 */
  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4000);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步从已知信息推不出来，得猜一格');
    setTimeout(() => { this.hintMsg = ''; }, 4000);
  }

  private reveal(i: number): void {
    if (this.over || this.finished) {
      return;
    }
    if (!this.seeded) {
      this.seed(i);
    }
    const cs: MineCell[] = this.copyCells();
    if (cs[i].open || cs[i].flag) {
      return;
    }
    if (cs[i].mine) {
      this.boom = i;
      cs[i].open = true;
      for (let k = 0; k < cs.length; k++) {
        if (cs[k].mine) {
          cs[k].open = true;
        }
      }
      this.cells = cs;
      this.over = true;
      this.won = false;
      this.recount();
      this.finish(false);
      return;
    }

    const queue: number[] = [i];
    let qi: number = 0;
    while (qi < queue.length) {
      const k: number = queue[qi];
      qi++;
      if (cs[k].open || cs[k].flag || cs[k].mine) {
        continue;
      }
      cs[k].open = true;
      if (cs[k].adj === 0) {
        const nb: number[] = this.neighbors(k);
        for (let t = 0; t < nb.length; t++) {
          if (!cs[nb[t]].open && !cs[nb[t]].flag) {
            queue.push(nb[t]);
          }
        }
      }
    }
    this.cells = cs;
    this.recount();

    if (this.opened >= this.safeTotal) {
      const done: MineCell[] = this.copyCells();
      for (let k = 0; k < done.length; k++) {
        if (done[k].mine) {
          done[k].flag = true;    // 通关时把剩下的雷自动插旗，看得清爽
        }
      }
      this.cells = done;
      this.recount();
      this.won = true;
      this.over = true;
      this.finish(true);
    }
  }

  private toggleFlag(i: number): void {
    if (this.over || this.finished) {
      return;
    }
    const cs: MineCell[] = this.copyCells();
    if (cs[i].open) {
      return;
    }
    cs[i].flag = !cs[i].flag;
    this.cells = cs;
    this.recount();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.stopTimer();
    const usedMs: number = Date.now() - this.startAt;
    const usedSec: number = Math.floor(usedMs / TICK_MS);
    const r: GameResult = {
      gameId: 'minesweeper',
      solved: solved,
      score: solved ? Math.max(100, 1000 - usedSec * 4) : Math.max(0, this.opened * 8),
      durationMs: usedMs,
      levelReached: this.opened
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  // ────────────────────────── 渲染 ──────────────────────────

  private cellBg(i: number): string {
    const c: MineCell = this.cellAt(i);
    if (c.open) {
      if (c.mine) {
        if (this.boom === i) {
          return Palette.rose;
        }
        return this.theme.isDark ? MINE_DARK : MINE_LIGHT;
      }
      return this.theme.isDark ? OPEN_DARK : OPEN_LIGHT;
    }
    if (c.flag) {
      return this.theme.isDark ? '#33F43F5E' : '#26F43F5E';
    }
    return this.theme.isDark ? DOWN_DARK : DOWN_LIGHT;
  }

  private statusText(): string {
    if (this.hintMsg.length > 0) {
      return this.hintMsg;              // ★ 提示优先占状态栏
    }
    if (this.won) {
      return TG2("🎉 全部扫清！用时 {0} 秒",Digits(String(this.seconds), this.langCode));
    }
    if (this.over) {
      return TG('💥 踩到雷了 —— 再来一局');
    }
    if (this.flagMode) {
      return TG('插旗模式：点格子插旗 · 长按也可以插旗');
    }
    return TG('点格子翻开 · 长按插旗（首点必安全）');
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
      // 数据条
      Row({ space: Space.sm }) {
        this.infoBox(0)
        this.infoBox(1)
        this.infoBox(2)
      }
      .width('100%')

      // 雷区
      Column({ space: Space.xs }) {
        ForEach(IDX9, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(IDX9, (c: number) => {
              this.cellView(r * SIDE + c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.isDark ? BOARD_DARK : BOARD_LIGHT)
      .borderRadius(Radius.lg)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Text(this.statusText())
        .fontSize(FontSize.sm)
        .fontColor(this.won ? Palette.emerald : (this.over ? Palette.rose : this.theme.inkFaint))

      // 操作
      Row({ space: Space.md }) {
        Button(this.flagMode ? '🚩 插旗模式：开' : '🚩 插旗模式：关')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.flagMode ? Color.White : this.theme.ink)
          .backgroundColor(this.flagMode ? Palette.berry : this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.flagMode = !this.flagMode;
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.flagMode = !this.flagMode; }); })
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
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
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

  /** kind: 0=剩余雷 1=已翻开 2=用时（值在 Builder 内部读状态，保证刷新） */
  @Builder
  infoBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '剩余雷' : (kind === 1 ? '已翻开' : TG('用时')))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.minesTotal - this.flags)
        : (kind === 1 ? this.opened + '/' + this.safeTotal : this.seconds + 's'))
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
      if (this.cellAt(i).open) {
        if (this.cellAt(i).mine) {
          Text('💣').accessibilityLevel('no').fontSize(FontSize.sm)
        } else if (this.cellAt(i).adj > 0) {
          Text(String(this.cellAt(i).adj))
            .fontSize(FontSize.sm)
            .fontWeight(FontWeight.Bold)
            .fontColor(numColor(this.cellAt(i).adj))
        }
      } else if (this.cellAt(i).flag) {
        Text('🚩').accessibilityLevel('no').fontSize(FontSize.xs)
      }
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.cellBg(i))
    .borderRadius(Radius.xs)
    .scale({
      x: this.pressed === i ? Motion.pressScale : 1,
      y: this.pressed === i ? Motion.pressScale : 1
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = i;
        this.swallowClick = false;
        this.longHandled = false;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        if (this.longHandled) {
          this.swallowClick = true;   // 长按已处理，抬手别再把 click 当一次点击
          this.longHandled = false;
        }
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: LONG_PRESS_MS })
        .onAction(() => {
          this.onCellLongPress(i);
        })
    )
    .onClick(() => {
      Haptics.tick();
      this.onCellTap(i);
    })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.onCellTap(i); }); })
  }
}
