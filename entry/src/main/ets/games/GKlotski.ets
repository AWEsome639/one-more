/**
 * 华容道 —— 「横刀立马」4×5 🧊
 *
 * 布局：曹操 2×2 在上中，四员大将竖着分列两侧，关羽横在中间，四卒守底，底部中央两格空。
 * 玩法：点一个方块选中它，再点方向键把它推进相邻空格（一次一格）。
 * 胜负：曹操左上角走到 (1,3)（即底部出口那一块）⇒ 通关；步数超过上限 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const COLS: number = 4;
const ROWS: number = 5;
/** 「横刀立马」一格一格走的最短解是 116 步（BFS 实测）⇒ 上限必须留够余量，否则永远赢不了 */
const MAX_MOVES: number = 160;
const CAO: number = 1;          // 曹操在方块数组里的下标（layout() 里第二个 push）
const CAO_TX: number = 1;       // 出口：曹操左上角目标列
const CAO_TY: number = 3;       // 出口：曹操左上角目标行
const GAP: number = Space.xs / 2;
/** 拖动判定阈值（vp）：一次拖动至少这么多才认一个方向 */
const DRAG_MIN: number = 18;

interface Blk {
  x: number;      // 列
  y: number;      // 行
  w: number;      // 占几列
  h: number;      // 占几行
  label: string;
  color: string;
}

@Component
export struct GKlotski {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private blocks: Blk[] = [];
  @State private sel: number = CAO;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点方块选中，再点方向键移动');

  private startAt: number = 0;
  private finished: boolean = false;
  /** ★ 拖动起点（vp）：一次拖动可以连着推好几格，每认一格就把起点重置 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  /** 「横刀立马」开局 */
  private layout(): Blk[] {
    const bs: Blk[] = [];
    const zhang: Blk = { x: 0, y: 0, w: 1, h: 2, label: '张飞', color: Palette.sky };
    const cao: Blk = { x: 1, y: 0, w: 2, h: 2, label: '曹操', color: Palette.rose };
    const zhao: Blk = { x: 3, y: 0, w: 1, h: 2, label: '赵云', color: Palette.teal };
    const ma: Blk = { x: 0, y: 2, w: 1, h: 2, label: '马超', color: Palette.violet };
    const guan: Blk = { x: 1, y: 2, w: 2, h: 1, label: '关羽', color: Palette.amber };
    const huang: Blk = { x: 3, y: 2, w: 1, h: 2, label: '黄忠', color: Palette.orange };
    const z1: Blk = { x: 1, y: 3, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z2: Blk = { x: 2, y: 3, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z3: Blk = { x: 0, y: 4, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    const z4: Blk = { x: 3, y: 4, w: 1, h: 1, label: '卒', color: Palette.inkFaint };
    // push 顺序即下标：0 张飞 · 1 曹操（= CAO）· 2 赵云 · 3 马超 · 4 关羽 · 5 黄忠 · 6~9 四卒
    bs.push(zhang);
    bs.push(cao);
    bs.push(zhao);
    bs.push(ma);
    bs.push(guan);
    bs.push(huang);
    bs.push(z1);
    bs.push(z2);
    bs.push(z3);
    bs.push(z4);
    return bs;
  }

  private reset(): void {
    this.blocks = this.layout();
    this.sel = CAO;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点方块选中，再点方向键移动');
    this.startAt = Date.now();
  }

  private hit(a: Blk, b: Blk): boolean {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
  }

  private tryMove(dx: number, dy: number): void {
    if (this.over) {
      return;
    }
    const i: number = this.sel;
    const b: Blk = this.blocks[i];
    const nx: number = b.x + dx;
    const ny: number = b.y + dy;
    if (nx < 0 || ny < 0 || nx + b.w > COLS || ny + b.h > ROWS) {
      return;   // 撞墙
    }
    const probe: Blk = { x: nx, y: ny, w: b.w, h: b.h, label: b.label, color: b.color };
    for (let k = 0; k < this.blocks.length; k++) {
      if (k === i) {
        continue;
      }
      if (this.hit(probe, this.blocks[k])) {
        return;   // 被别的方块挡住
      }
    }
    const nb: Blk[] = [];
    for (let k = 0; k < this.blocks.length; k++) {
      const o: Blk = this.blocks[k];
      if (k === i) {
        const moved: Blk = { x: nx, y: ny, w: o.w, h: o.h, label: o.label, color: o.color };
        nb.push(moved);
      } else {
        nb.push(o);
      }
    }
    this.blocks = nb;
    this.moves++;
    this.check();
  }

  private away(): number {
    const b: Blk = this.blocks.length > CAO ? this.blocks[CAO] : this.blocks[0];
    return Math.abs(b.x - CAO_TX) + Math.abs(b.y - CAO_TY);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'klotski',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : Math.max(0, 300 - this.away() * 40),
      durationMs: Date.now() - this.startAt,
      levelReached: Math.max(0, ROWS - 1 - this.blocks[CAO].y)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const b: Blk = this.blocks[CAO];
    if (b.x === CAO_TX && b.y === CAO_TY) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 曹操出关，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，曹操没能出关');
      this.finish(false);
      return;
    }
    this.tip = TG2("曹操距出口还差 {0} 格", String(this.away()));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        this.head(0)
        this.head(1)
        this.head(2)
      }
      .width('100%')

      Stack() {
        // 出口高亮：底部中央 2×2
        Row()
          .width((2 * 100 / COLS) + '%')
          .height((2 * 100 / ROWS) + '%')
          .position({ x: (CAO_TX * 100 / COLS) + '%', y: (CAO_TY * 100 / ROWS) + '%' })
          .border({ width: 2, color: Palette.emerald, style: BorderStyle.Dashed })
          .borderRadius(Radius.md)
          .opacity(0.6)

        ForEach(this.blocks, (b: Blk, i: number) => {
          this.block(i)
        }, (b: Blk, i: number) => 'kb' + i)
      }
      .width('100%')
      .aspectRatio(COLS / ROWS)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).animation({ duration: Motion.fast, curve: Motion.snap() })

      Column({ space: Space.xs }) {
        this.moveBtn('↑', 0, -1)
        Row({ space: Space.xs }) {
          this.moveBtn('←', -1, 0)
          this.moveBtn('↓', 0, 1)
          this.moveBtn('→', 1, 0)
        }
      }
      .width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  /**
   * 顶部小格：kind 0=步数 1=距出口 2=已选
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三个数整局不刷新。
   */
  @Builder
  head(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : (kind === 1 ? '距出口' : TG('已选')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves) + '/' + String(this.diffTotal)
        : (kind === 1 ? String(this.away()) + TG(' 格')
          : (this.blocks.length > 0 ? this.blocks[this.sel].label : '-')))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  block(i: number) {
    Row() {
      Column() {
        Text(this.blocks[i].label)
          .fontSize(this.blocks[i].w > 1 ? FontSize.lg : FontSize.md)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.blocks[i].color)
      .borderRadius(Radius.sm)
      .border({ width: this.sel === i ? 3 : 0, color: '#FFFFFF' })
      .shadow(this.sel === i ? Shadow.lifted : Shadow.card)
    }
    .width((this.blocks[i].w * 100 / COLS) + '%')
    .height((this.blocks[i].h * 100 / ROWS) + '%')
    .padding(GAP)
    .position({
      x: (this.blocks[i].x * 100 / COLS) + '%',
      y: (this.blocks[i].y * 100 / ROWS) + '%'
    })
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => {
      this.sel = i;
      this.tip = TG2("{0} 已选中，点方向键移动", this.blocks[i].label);
    })
    // ★ P9：手指直接在方块上朝想去的方向一拖 = 推它一格（不用先选中、再点下面的方向键）
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 6 })
        .onActionStart(() => {
          this.sel = i;
          this.dragX = 0;
          this.dragY = 0;
        })
        .onActionUpdate((e: GestureEvent) => {
          const dx: number = e.offsetX - this.dragX;
          const dy: number = e.offsetY - this.dragY;
          if (Math.abs(dx) < DRAG_MIN && Math.abs(dy) < DRAG_MIN) {
            return;
          }
          this.dragX = e.offsetX;
          this.dragY = e.offsetY;
          if (Math.abs(dx) >= Math.abs(dy)) {
            this.tryMove(dx > 0 ? 1 : -1, 0);
          } else {
            this.tryMove(0, dy > 0 ? 1 : -1);
          }
        })
        .onActionEnd(() => {
          this.dragX = 0;
          this.dragY = 0;
        })
    )
  }

  @Builder
  moveBtn(label: string, dx: number, dy: number) {
    Text(label)
      .fontSize(FontSize.lg)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .width(64)
      .height(Cell.of(40))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .onClick(() => {
        this.tryMove(dx, dy);
      })
  }
}
