/**
 * 复合连线 —— 从左上角连到右下角，但要同时满足两个条件：数字和 = 目标、步数 ≤ 上限
 *
 * 玩法：点相邻格把线接长（只能上下左右接在当前末端）；点末端那格可回退一步；
 *       接到右下角时自动判定：和与步数都对 ⇒ 通关，否则算一次失败（最多 5 次）
 * 关卡：每局随机生成 6×6 数字盘 + 障碍格，目标与步数上限由一条真实存在的通路反推 ⇒ 一定有解
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const START: number = 0;
const GOAL: number = N * N - 1;
const MAX_FAIL: number = 5;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GCompoundConnect {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_FAIL 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_FAIL);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private board: number[] = [];
  @State private path: number[] = [];
  @State private target: number = 0;
  @State private maxSteps: number = 0;
  @State private fails: number = 0;
  @State private msg: string = TG('从左上角出发，接到右下角');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_FAIL);
    this.reset();
  }

  private idx(r: number, c: number): number {
    return r * N + c;
  }

  private reset(): void {
    const b: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < b.length; i++) {
      b[i] = 1 + Math.floor(Math.random() * 5);
    }
    let blocked: number = 0;
    for (let i = 0; i < b.length; i++) {
      if (i !== START && i !== GOAL && Math.random() < 0.12) {
        b[i] = 0;
        blocked++;
      }
    }
    let path: number[] = this.walk(b, START, GOAL);
    if (path.length < 7 || blocked < 3) {
      // 生成失败（极少见）：退化成一条单调通路，保证一定有解
      const p: number[] = [START];
      let r: number = 0;
      let c: number = 0;
      while (r < N - 1 || c < N - 1) {
        if (r >= N - 1) {
          c++;
        } else if (c >= N - 1) {
          r++;
        } else if (Math.random() < 0.5) {
          r++;
        } else {
          c++;
        }
        p.push(this.idx(r, c));
      }
      path = p;
      for (let i = 0; i < path.length; i++) {
        b[path[i]] = 1 + Math.floor(Math.random() * 5);
      }
    }
    let sum: number = 0;
    for (let i = 0; i < path.length; i++) {
      sum += b[path[i]];
    }
    this.board = b;
    this.target = sum;
    this.maxSteps = path.length;
    this.path = [];
    this.fails = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('从左上角出发，接到右下角');
    this.startAt = Date.now();
  }

  /** 随机 DFS 找一条从 start 到 goal 的通路（绕开障碍） */
  private walk(b: number[], start: number, goal: number): number[] {
    const visited: boolean[] = new Array<boolean>(N * N).fill(false);
    const path: number[] = [];
    const ok: boolean = this.dfs(b, visited, path, start, goal);
    return ok ? path : [];
  }

  private dfs(b: number[], visited: boolean[], path: number[], cur: number, goal: number): boolean {
    visited[cur] = true;
    path.push(cur);
    if (cur === goal) {
      if (path.length >= 7) {
        return true;
      }
      visited[cur] = false;
      path.pop();
      return false;
    }
    if (path.length >= 16) {
      visited[cur] = false;
      path.pop();
      return false;
    }
    const nb: number[] = this.neighbors(b, cur, visited);
    for (let i = 0; i < nb.length; i++) {
      if (this.dfs(b, visited, path, nb[i], goal)) {
        return true;
      }
    }
    visited[cur] = false;
    path.pop();
    return false;
  }

  /** 可走的邻格（在界内、非障碍、没走过），顺序打乱 */
  private neighbors(b: number[], i: number, visited: boolean[]): number[] {
    const r: number = Math.floor(i / N);
    const c: number = i % N;
    const out: number[] = [];
    if (r > 0) {
      out.push(this.idx(r - 1, c));
    }
    if (r < N - 1) {
      out.push(this.idx(r + 1, c));
    }
    if (c > 0) {
      out.push(this.idx(r, c - 1));
    }
    if (c < N - 1) {
      out.push(this.idx(r, c + 1));
    }
    const keep: number[] = [];
    for (let k = 0; k < out.length; k++) {
      const n: number = out[k];
      if (b[n] > 0 && !visited[n]) {
        keep.push(n);
      }
    }
    for (let k = keep.length - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const t: number = keep[k];
      keep[k] = keep[j];
      keep[j] = t;
    }
    return keep;
  }

  private pathSum(): number {
    let s: number = 0;
    for (let i = 0; i < this.path.length; i++) {
      s += this.board[this.path[i]];
    }
    return s;
  }

  private adjacent(a: number, b: number): boolean {
    const ar: number = Math.floor(a / N);
    const ac: number = a % N;
    const br: number = Math.floor(b / N);
    const bc: number = b % N;
    return Math.abs(ar - br) + Math.abs(ac - bc) === 1;
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    if (this.path.length === 0) {
      if (i !== START) {
        this.msg = TG('要从左上角那一格起步');
        return;
      }
      this.path = [START];
      this.msg = TG2('接着点相邻的格子，和要刚好等于 {0}', this.target);
      return;
    }
    const last: number = this.path[this.path.length - 1];
    if (i === last) {
      const p: number[] = this.path.slice();
      p.pop();
      this.path = p;
      this.msg = TG('退回一步');
      return;
    }
    if (this.path.indexOf(i) >= 0) {
      this.msg = TG('这条线不能重复走同一格');
      return;
    }
    if (this.board[i] === 0) {
      this.msg = TG('障碍格不能走');
      return;
    }
    if (!this.adjacent(last, i)) {
      this.msg = TG('只能接在当前末端旁边');
      return;
    }
    const p: number[] = this.path.concat([i]);
    this.path = p;
    if (i === GOAL) {
      const s: number = this.pathSum();
      if (s === this.target && p.length <= this.maxSteps) {
        this.over = true;
        this.won = true;
        this.msg = TG('🎉 和与步数都刚好！');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      } else {
        this.fails++;
        if (this.fails >= this.diffTotal) {
          this.over = true;
          this.won = false;
          this.msg = TG('失败次数用完了');
          this.finish(false);
        } else {
          this.msg = (s === this.target ? TG('步数超了') : TG2('和是 {0}，不是 {1}', String(s), String(this.target)))
            + TG2('（点末端那格可回退）失败 {0}/{1}', this.fails, this.diffTotal);
        }
      }
    } else {
      this.msg = TG2("和 {0} · 已走 {1} 格", this.pathSum(), p.length);
    }
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const steps: number = this.path.length;
    const r: GameResult = {
      gameId: 'compound_connect',
      solved: solved,
      score: solved ? 300 + Math.max(0, this.maxSteps - steps) * 30 : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: steps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('数字和'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.pathSum() + ' / ' + this.target)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((this.pathSum() === this.target ? Palette.emerald : Palette.primary)).animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.path.length + ' / ' + this.maxSteps)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((this.path.length <= this.maxSteps ? Palette.sky : Palette.rose))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失败'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.fails + ' / ' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rows, (c: number) => {
              Stack() {
              if (this.board.length > (this.idx(r, c))) {
              Text(this.board[(this.idx(r, c))] === 0 ? '🧱' : String(this.board[(this.idx(r, c))]))
              .fontSize(this.board[(this.idx(r, c))] === 0 ? FontSize.md : FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.path.indexOf((this.idx(r, c))) >= 0 ? '#FFFFFF' : this.theme.ink)
              }
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.path.indexOf((this.idx(r, c))) >= 0
              ? Palette.primary
              : (this.board.length > (this.idx(r, c)) && this.board[(this.idx(r, c))] === 0 ? this.theme.line : this.theme.surface))
              .borderRadius(Radius.sm)
              .border({
              width: (this.idx(r, c)) === GOAL ? 2 : 0,
              color: Palette.emerald
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              this.tap((this.idx(r, c)));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
          .layoutWeight(1)
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('回退一步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .enabled(!this.over && this.path.length > 0)
          .onClick(() => {
            const p: number[] = this.path.slice();
            p.pop();
            this.path = p;
            this.msg = TG('退回一步');
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .enabled(!this.over)
          .onClick(() => {
            this.path = [];
            this.msg = TG('从左上角重新起步');
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .onClick(() => {
            this.reset();
          })
      }
      .width('100%')

      Text(TG2('两条硬条件：路径数字和 = {0}，且步数 ≤ {1}（0 是障碍）',Digits(String(this.target), this.langCode),Digits(String(this.maxSteps), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
