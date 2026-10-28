/**
 * 解缠 tangle_fix —— 六个节点排成一行，连线之间的交叉数必须降到 0
 *
 * 交叉判据（纯组合，不需要画线）：两条边 (a,b)、(c,d) 在序列上「互相穿插」即交叉
 * 操作：点两个节点交换位置；步数用完仍交叉 ⇒ 失败
 * 进度：交叉数 ／ 剩余交换 ／ 得分
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const NODES: number = 6;
const LIMIT: number = 26;
const LABELS: string[] = ['A', 'B', 'C', 'D', 'E', 'F'];

/** 三套边表（每条 6 条边，扁平存放：a0,b0,a1,b1...） */
const EDGE_LIB: number[][] = [
  [0, 4, 1, 5, 2, 3, 0, 2, 1, 4, 3, 5],
  [0, 3, 1, 4, 2, 5, 0, 5, 1, 3, 2, 4],
  [0, 2, 1, 5, 2, 4, 0, 4, 1, 3, 3, 5]
];

function tint(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GTangleFix {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：LIMIT 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.timeNow(LIMIT);
  onFinish: (r: GameResult) => void = () => {};

  @State order: number[] = [];
  @State edges: number[] = [];
  @State sel: number = -1;
  @State swaps: number = 0;
  @State ticks: number = 0;          // 每步 +1，驱动重绘
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(LIMIT);
    this.reset();
  }

  private posOf(node: number): number {
    return this.order.indexOf(node);
  }

  private cross(a: number, b: number, c: number, d: number): boolean {
    const p1: number = this.posOf(a);
    const p2: number = this.posOf(b);
    const p3: number = this.posOf(c);
    const p4: number = this.posOf(d);
    const l1: number = Math.min(p1, p2);
    const r1: number = Math.max(p1, p2);
    const l2: number = Math.min(p3, p4);
    const r2: number = Math.max(p3, p4);
    const in12: boolean = l1 < l2 && l2 < r1 && r1 < r2;
    const in21: boolean = l2 < l1 && l1 < r2 && r2 < r1;
    return in12 || in21;
  }

  private crossCount(): number {
    let n: number = 0;
    const cnt: number = this.edges.length / 2;
    for (let i = 0; i < cnt; i++) {
      for (let j = i + 1; j < cnt; j++) {
        if (this.cross(this.edges[i * 2], this.edges[i * 2 + 1],
          this.edges[j * 2], this.edges[j * 2 + 1])) {
          n++;
        }
      }
    }
    return n;
  }

  private edgeBad(k: number): boolean {
    const cnt: number = this.edges.length / 2;
    for (let j = 0; j < cnt; j++) {
      if (j === k) {
        continue;
      }
      if (this.cross(this.edges[k * 2], this.edges[k * 2 + 1],
        this.edges[j * 2], this.edges[j * 2 + 1])) {
        return true;
      }
    }
    return false;
  }

  private edgeLo(k: number): number {
    const a: number = this.posOf(this.edges[k * 2]);
    const b: number = this.posOf(this.edges[k * 2 + 1]);
    return Math.min(a, b);
  }

  private edgeHi(k: number): number {
    const a: number = this.posOf(this.edges[k * 2]);
    const b: number = this.posOf(this.edges[k * 2 + 1]);
    return Math.max(a, b);
  }

  /** 第一处交叉的说明文字，没有交叉就返回空串 */
  private crossText(): string {
    const cnt: number = this.edges.length / 2;
    for (let i = 0; i < cnt; i++) {
      for (let j = i + 1; j < cnt; j++) {
        const c1: boolean = this.cross(this.edges[i * 2], this.edges[i * 2 + 1],
          this.edges[j * 2], this.edges[j * 2 + 1]);
        if (c1) {
          return LABELS[this.edges[i * 2]] + LABELS[this.edges[i * 2 + 1]]
            + TG(' 与 ') + LABELS[this.edges[j * 2]] + LABELS[this.edges[j * 2 + 1]] + ' 交叉';
        }
      }
    }
    return '';
  }

  private reset(): void {
    let bestOrd: number[] = [];
    let bestEdges: number[] = [];
    let bestCross: number = -1;
    for (let attempt = 0; attempt < 60; attempt++) {
      const ord: number[] = [];
      for (let i = 0; i < NODES; i++) {
        ord.push(i);
      }
      for (let i = NODES - 1; i > 0; i--) {
        const j: number = Math.floor(Math.random() * (i + 1));
        const t: number = ord[i];
        ord[i] = ord[j];
        ord[j] = t;
      }
      const lib: number = Math.floor(Math.random() * EDGE_LIB.length);
      this.order = ord;
      this.edges = EDGE_LIB[lib].slice();
      const c: number = this.crossCount();
      if (c > bestCross) {
        bestCross = c;
        bestOrd = ord.slice();
        bestEdges = EDGE_LIB[lib].slice();
      }
      if (c >= 5) {
        break;
      }
    }
    this.order = bestOrd;
    this.edges = bestEdges;
    this.sel = -1;
    this.swaps = 0;
    this.ticks = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 只有 6 个节点 ⇒ 6! = 720 种摆法全枚举一遍，找一个"交叉数 = 0"的摆法，
  // 再按位置一步步换过去。交叉数只跟摆法有关（组合判定），所以这一步是精确解，不是启发式。
  /** 按给定摆法数交叉（纯函数：用传入的 ord，不动 this.order） */
  private crossOf(ord: number[], edges: number[]): number {
    const pos: number[] = [];
    for (let i = 0; i < NODES; i++) {
      pos.push(0);
    }
    for (let i = 0; i < ord.length; i++) {
      pos[ord[i]] = i;
    }
    let n: number = 0;
    const cnt: number = edges.length / 2;
    for (let i = 0; i < cnt; i++) {
      const a: number = pos[edges[i * 2]];
      const b: number = pos[edges[i * 2 + 1]];
      const l1: number = Math.min(a, b);
      const r1: number = Math.max(a, b);
      for (let j = i + 1; j < cnt; j++) {
        const c: number = pos[edges[j * 2]];
        const d: number = pos[edges[j * 2 + 1]];
        const l2: number = Math.min(c, d);
        const r2: number = Math.max(c, d);
        if ((l1 < l2 && l2 < r1 && r1 < r2) || (l2 < l1 && l1 < r2 && r2 < r1)) {
          n++;
        }
      }
    }
    return n;
  }

  /** 枚举 720 种摆法，返回第一个交叉数为 0 的（找不到返回空数组） */
  private solveTarget(): number[] {
    const out: number[] = [];
    const cur: number[] = [];
    const used: boolean[] = [];
    for (let i = 0; i < NODES; i++) {
      used.push(false);
    }
    const rec = (): void => {
      if (out.length > 0) {
        return;
      }
      if (cur.length === NODES) {
        if (this.crossOf(cur, this.edges) === 0) {
          for (let i = 0; i < NODES; i++) {
            out.push(cur[i]);
          }
        }
        return;
      }
      for (let v = 0; v < NODES; v++) {
        if (used[v]) {
          continue;
        }
        used[v] = true;
        cur.push(v);
        rec();
        cur.pop();
        used[v] = false;
        if (out.length > 0) {
          return;
        }
      }
    };
    rec();
    return out;
  }

  /** 下一对要交换的位置（空数组 = 已经解开 / 解不了） */
  private planSwap(): number[] {
    const tgt: number[] = this.solveTarget();
    if (tgt.length !== NODES) {
      return [];
    }
    let i: number = -1;
    for (let k = 0; k < NODES; k++) {
      if (this.order[k] !== tgt[k]) {
        i = k;
        break;
      }
    }
    if (i < 0) {
      return [];
    }
    for (let k = 0; k < NODES; k++) {
      if (this.order[k] === tgt[i]) {
        return [i, k];
      }
    }
    return [];
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.crossCount() === 0) {
      return false;
    }
    const pr: number[] = this.planSwap();
    if (pr.length !== 2) {
      return false;
    }
    if (this.sel >= 0) {
      this.tap(this.sel);             // 清掉残留的选中，免得下一次点击变成"交换"
    }
    this.tap(pr[0]);
    this.tap(pr[1]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.crossCount() === 0) {
      return Hint.none('none');
    }
    const pr: number[] = this.planSwap();
    if (pr.length !== 2) {
      return Hint.none('none');
    }
    const a: string = LABELS[this.order[pr[0]]];
    const b: string = LABELS[this.order[pr[1]]];
    return Hint.make([pr[0], pr[1]],
      TG2('把 {0} 和 {1} 换个位置（换完交叉会少）', a, b),
      'Swap ' + a + ' and ' + b, t0);
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

  private tap(p: number): void {
    if (this.over) {
      return;
    }
    if (this.sel < 0) {
      this.sel = p;
      return;
    }
    if (this.sel === p) {
      this.sel = -1;
      return;
    }
    const ord: number[] = this.order.slice();
    const t: number = ord[this.sel];
    ord[this.sel] = ord[p];
    ord[p] = t;
    this.order = ord;
    this.sel = -1;
    this.swaps++;
    this.ticks++;
    if (this.crossCount() === 0) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(80, 500 - this.swaps * 12 - sec * 2);
      this.finish(true);
      return;
    }
    if (this.swaps >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'tangle_fix',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.diffTotal - this.swaps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("全部解开了 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '交换次数用完，还缠着';
    }
    return this.sel < 0 ? '点一个节点，再点另一个换位' : TG2("已选中 {0}，点谁与它换？", LABELS[this.order[this.sel]]);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('交叉'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.crossCount())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余交换'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.diffTotal - this.swaps)))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
      }
      .width('100%')

      // 节点行
      Row({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (p: number) => {
          Stack() {
          Text(LABELS[this.order[(p)]])
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.primaryDeep)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(tint(Palette.wheel[this.order[(p)] % Palette.wheel.length], this.theme.isDark))
          .borderRadius(Radius.full)
          .border({
          width: this.sel === (p) ? 3 : 1,
          color: this.sel === (p) ? Palette.amber : this.theme.line
          })
          .scale({ x: this.sel === (p) ? Motion.pressScale : 1, y: this.sel === (p) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tap((p));
          })
        }, (p: number) => 'p' + p)
      }
      .width('100%')

      // 每条线一行「公交图」，重叠 = 交叉
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (k: number) => {
          Row({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4, 5], (p: number) => {
          Text(this.edgeMark(((k)), (p)))
          .fontSize(FontSize.xxs)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.edgeBad(((k))) ? Palette.rose : Palette.primaryDeep)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .backgroundColor(this.edgeFill(((k)), (p)))
          .borderRadius(Radius.xs)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (p: number) => 't' + p)
          }
          .width('100%')
          .height(FontSize.lg)
        }, (k: number) => 'e' + k)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.tip())
        .fontSize(FontSize.sm)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%')

      Text(this.over || this.crossCount() === 0 ? '' : '🔴 ' + this.crossText())
        .fontSize(FontSize.xs)
        .fontColor(Palette.rose)
        .width('100%')

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.primaryDeep)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG('两条线端点在序列里互相穿插，就是交叉；把交叉降到 0 即通关'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }









  /** 该位置在这条线上画什么 */
  private edgeMark(k: number, p: number): string {
    const lo: number = this.edgeLo(k);
    const hi: number = this.edgeHi(k);
    if (p === lo) {
      return LABELS[this.edges[k * 2]];
    }
    if (p === hi) {
      return LABELS[this.edges[k * 2 + 1]];
    }
    return (p > lo && p < hi) ? '━━' : '';
  }

  private edgeFill(k: number, p: number): string {
    const lo: number = this.edgeLo(k);
    const hi: number = this.edgeHi(k);
    if (p < lo || p > hi) {
      return this.theme.surface;
    }
    return this.edgeBad(k) ? tint(Palette.rose, this.theme.isDark) : tint(Palette.primary, this.theme.isDark);
  }
}
