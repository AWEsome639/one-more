/**
 * 数字路径（Math Path）—— 4×4 🧩
 *
 * 规则：棋盘格子里是数字或运算符（＋ － ×）；从任意格出发，依次点**相邻**的格子
 *       拼出一条路径，必须「数字 → 运算符 → 数字 → … → 数字」这样交替。
 *       算式**从左往右依次计算（不区分优先级）**，结果要正好等于目标数。
 * 胜负：算式结果 = 目标（路径至少 3 格）⇒ 通关；结果跑飞 / 步数用尽 ⇒ 失败。
 * 出题：先在棋盘上随机开一条 5 格通路，放一条算好的算式，反推出目标 ⇒ 一定有解。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 6×6 = 36 格，原来只开 16）
const MAX_N: number = 6;
const MAX_CELLS: number = MAX_N * MAX_N;
const MAX_TAPS: number = 30;
const PATH_LEN: number = 5;         // 出题通路：数字 运算符 数字 运算符 数字
const V_MIN: number = 1;            // 出题时中间结果允许范围
const V_MAX: number = 60;
const RANGE_MIN: number = -50;      // 玩家算式允许范围，超出即失败
const RANGE_MAX: number = 200;
const OP_PLUS: string = '+';
const OP_MINUS: string = '−';
const OP_TIMES: string = '×';
const OPS: string[] = [OP_PLUS, OP_MINUS, OP_TIMES];
const DIGIT_RATE: number = 0.68;    // 填空时放数字的比例

interface Tile {
  op: boolean;     // true = 运算符
  num: number;     // op=false 时的数字 1~9
  sym: string;     // op=true 时的符号
}

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

function shuffled(n: number): number[] {
  const a: number[] = range(n);
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

function apply(v: number, op: string, d: number): number {
  if (op === OP_PLUS) {
    return v + d;
  }
  if (op === OP_MINUS) {
    return v - d;
  }
  return v * d;
}

function digitTile(n: number): Tile {
  const t: Tile = { op: false, num: n, sym: '' };
  return t;
}

function opTile(s: string): Tile {
  const t: Tile = { op: true, num: 0, sym: s };
  return t;
}

@Component
export struct GMathPath {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4）
  //   ⚠️ 渲染原本用 ForEach(this.rows)，已改成 ForEach(this.rowIdx())
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private tiles: Tile[] = [];
  @State private target: number = 0;
  @State private path: number[] = [];
  @State private taps: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG(TG(TG('先点一个数字格，再点相邻的运算符格')));

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(this.diffTotal);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private rowOf(i: number): number {
    return Math.floor(i / this.diffTotal);
  }

  private colOf(i: number): number {
    return i % this.diffTotal;
  }

  private nbrs(i: number): number[] {
    const out: number[] = [];
    const r: number = this.rowOf(i);
    const c: number = this.colOf(i);
    if (r > 0) {
      out.push(i - this.diffTotal);
    }
    if (r < this.diffTotal - 1) {
      out.push(i + this.diffTotal);
    }
    if (c > 0) {
      out.push(i - 1);
    }
    if (c < this.diffTotal - 1) {
      out.push(i + 1);
    }
    return out;
  }

  private isOp(i: number): boolean {
    return this.tiles[i].op;
  }

  private label(i: number): string {
    const t: Tile = this.tiles[i];
    return t.op ? t.sym : String(t.num);
  }

  // ── 出题 ──

  /** 随机开一条 PATH_LEN 格的自避通路 */
  private genPath(): number[] {
    for (let attempt = 0; attempt < 200; attempt++) {
      const start: number = Math.floor(Math.random() * CELLS);
      const path: number[] = [start];
      let ok: boolean = true;
      while (path.length < PATH_LEN && ok) {
        const cur: number = path[path.length - 1];
        const ns: number[] = this.nbrs(cur);
        const perm: number[] = shuffled(ns.length);
        let moved: boolean = false;
        for (let t = 0; t < perm.length; t++) {
          const nx: number = ns[perm[t]];
          if (path.indexOf(nx) < 0) {
            path.push(nx);
            moved = true;
            break;
          }
        }
        if (!moved) {
          ok = false;
        }
      }
      if (ok && path.length === PATH_LEN) {
        return path;
      }
    }
    return [0, 1, 2, 3, 4];   // 兜底：第一行
  }

  /** 造一条中间结果都好看的算式，返回目标值；算式写进 out */
  private makeExpr(out: Tile[]): number {
    for (let attempt = 0; attempt < 500; attempt++) {
      const d0: number = 1 + Math.floor(Math.random() * 9);
      const o1: string = OPS[Math.floor(Math.random() * OPS.length)];
      const d1: number = 1 + Math.floor(Math.random() * 9);
      const v1: number = apply(d0, o1, d1);
      if (v1 < V_MIN || v1 > V_MAX) {
        continue;
      }
      const o2: string = OPS[Math.floor(Math.random() * OPS.length)];
      const d2: number = 1 + Math.floor(Math.random() * 9);
      const v2: number = apply(v1, o2, d2);
      if (v2 < V_MIN || v2 > V_MAX) {
        continue;
      }
      out.push(digitTile(d0));
      out.push(opTile(o1));
      out.push(digitTile(d1));
      out.push(opTile(o2));
      out.push(digitTile(d2));
      return v2;
    }
    out.push(digitTile(1));
    out.push(opTile(OP_PLUS));
    out.push(digitTile(1));
    out.push(opTile(OP_PLUS));
    out.push(digitTile(1));
    return 3;
  }

  private reset(): void {
    const path: number[] = this.genPath();
    const expr: Tile[] = [];
    const target: number = this.makeExpr(expr);

    const tiles: Tile[] = [];
    const filled: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      tiles.push(digitTile(1));
    }
    for (let i = 0; i < path.length; i++) {
      tiles[path[i]] = expr[i];
      filled[path[i]] = true;
    }
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (filled[i]) {
        continue;
      }
      if (Math.random() < DIGIT_RATE) {
        tiles[i] = digitTile(1 + Math.floor(Math.random() * 9));
      } else {
        tiles[i] = opTile(OPS[Math.floor(Math.random() * OPS.length)]);
      }
    }

    this.tiles = tiles;
    this.target = target;
    this.path = [];
    this.taps = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG(TG(TG('先点一个数字格，再点相邻的运算符格')));
    this.startAt = Date.now();
  }

  // ── 算式求值（左到右，不区分优先级）──

  private value(): number {
    if (this.path.length === 0) {
      return 0;
    }
    let v: number = this.tiles[this.path[0]].num;
    let k: number = 1;
    while (k + 1 < this.path.length) {
      v = apply(v, this.tiles[this.path[k]].sym, this.tiles[this.path[k + 1]].num);
      k += 2;
    }
    return v;
  }

  private exprText(): string {
    let s: string = '';
    for (let i = 0; i < this.path.length; i++) {
      s += this.label(this.path[i]);
    }
    return s === '' ? '空' : s;
  }

  private complete(): boolean {
    return this.path.length >= 3 && (this.path.length % 2) === 1;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'math_path',
      solved: solved,
      score: solved ? Math.max(150, 1000 - this.taps * 25) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.path.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private lose(why: string): void {
    if (this.finished) {
      return;
    }
    this.over = true;
    this.tip = why;
    this.finish(false);
  }

  // ── 输入 ──

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.path.length === 0) {
      if (this.isOp(i)) {
        this.tip = TG(TG(TG('开头必须是数字格')));
        return;
      }
      this.path = [i];
      this.taps++;
      this.tip = TG(TG(TG('接着点相邻的运算符格')));
      return;
    }
    if (this.path.indexOf(i) >= 0) {
      this.tip = TG(TG(TG('这一格已经用过了')));
      return;
    }
    const last: number = this.path[this.path.length - 1];
    if (this.nbrs(last).indexOf(i) < 0) {
      this.tip = TG(TG(TG('只能接相邻的格子')));
      return;
    }
    const lastIsOp: boolean = this.isOp(last);
    const nowIsOp: boolean = this.isOp(i);
    if (lastIsOp === nowIsOp) {
      this.tip = lastIsOp ? '运算符后面要接数字' : '数字后面要接运算符';
      return;
    }
    const np: number[] = this.path.slice();
    np.push(i);
    this.path = np;
    this.taps++;

    const v: number = this.value();
    if (v < RANGE_MIN || v > RANGE_MAX) {
      this.lose(TG2('算式跑飞了（{0}），重开一题吧', String(v)));
      return;
    }
    if (this.complete() && v === this.target) {
      this.over = true;
      this.won = true;
      this.tip = '🎉 ' + this.exprText() + ' = ' + String(this.target) + TG('，通关！');
      this.finish(true);
      return;
    }
    if (this.taps >= MAX_TAPS) {
      this.lose(TG('步数用尽，重开一题吧'));
      return;
    }
    this.tip = this.exprText() + TG2(' = {0}（目标 {1}）', String(v), String(this.target));
  }

  private undo(): void {
    if (this.over || this.path.length === 0) {
      return;
    }
    const np: number[] = this.path.slice();
    np.pop();
    this.path = np;
    this.tip = this.path.length === 0 ? '已清空算式' : TG2("当前：{0}", this.exprText());
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.target), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('算式')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.exprText())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('结果')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.value()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.label((r * this.diffTotal + c)))
              .fontSize(FontSize.xxl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isOp((r * this.diffTotal + c)) ? Palette.orange : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.path.indexOf((r * this.diffTotal + c)) >= 0 ? '#336366F1' : this.theme.surface)
              .borderRadius(Radius.sm)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'pc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'pr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('退一步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            this.undo();
          })
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')

      Text(TG2("步数 {0}/{1} · 相邻成路、数字与运算符交替、从左往右算（不区分优先级）",Digits(String(this.taps), this.langCode),Digits(String(MAX_TAPS), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
