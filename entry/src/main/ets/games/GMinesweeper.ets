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
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

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

  @State private cells: MineCell[] = [];
  @State private flagMode: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private seconds: number = 0;
  @State private opened: number = 0;
  @State private flags: number = 0;
  @State private pressed: number = -1;
  @State private boom: number = -1;

  private seeded: boolean = false;      // 是否已经布雷（首点之后才布）
  private startAt: number = 0;
  private timer: number = -1;
  private finished: boolean = false;
  private longHandled: boolean = false; // 本次触摸是否已按长按处理
  private swallowClick: boolean = false; // 长按抬手后随之而来的 click 要吞掉

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
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
            this.flagMode = !this.flagMode;
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')
    }
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
      this.onCellTap(i);
    })
  }
}
