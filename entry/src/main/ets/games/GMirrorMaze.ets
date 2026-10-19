/**
 * 镜像迷宫（id: mirror_maze）—— 屏幕是镜中的世界：按「左」其实往右走 🌀
 * 胜负：走到 🏁 通关；步数耗尽 ⇒ 失败。进度：步数 / 剩余 / 最短路径
 * 出题：随机摆墙 + BFS 保证一定连通（最短路径同时作为步数上限）
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 8×8 = 64 格，
//   而数组原来按 CELLS = 36 开 ⇒【困难档必越界】✗）
const MAX_N: number = 8;
const MAX_CELLS: number = MAX_N * MAX_N;
const WALL_P: number = 0.26;
const PERFECT: number = 11;

interface Board {
  wall: boolean[];
  goal: number;
  start: number;
}

/** 最短路径：起点到终点；到不了返回 -1 */
// ★★ 2026-10-13 修复（困难档 ×1.3 ⇒ 棋盘更大，原来只处理前 36 格）
function bfs(wall: boolean[], goalIdx: number, startIdx: number, n: number): number {
  const dist: number[] = new Array<number>(MAX_CELLS).fill(-1);
  dist[goalIdx] = 0;
  const q: number[] = [goalIdx];
  let head: number = 0;
  const dx: number[] = [0, 1, 0, -1];
  const dy: number[] = [-1, 0, 1, 0];
  while (head < q.length) {
    const cur: number = q[head];
    head++;
    const cx: number = cur % n;
    const cy: number = Math.floor(cur / n);
    for (let d = 0; d < 4; d++) {
      const nx: number = cx + dx[d];
      const ny: number = cy + dy[d];
      if (nx < 0 || nx >= n || ny < 0 || ny >= n) {
        continue;
      }
      const ni: number = ny * n + nx;
      if (wall[ni] || dist[ni] >= 0) {
        continue;
      }
      dist[ni] = dist[cur] + 1;
      q.push(ni);
    }
  }
  return dist[startIdx];
}

function makeBoard(n: number): Board {
  let best: Board | null = null;
  for (let attempt = 0; attempt < 60; attempt++) {
    const wall: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
    for (let i = 0; i < n * n; i++) {
      wall[i] = Math.random() < WALL_P;
    }
    const start: number = 0;
    const goal: number = n * n - 1;
    wall[start] = false;
    wall[goal] = false;
    const d: number = bfs(wall, goal, start, n);
    if (d >= 6 && d <= 14) {
      const ok: Board = { wall: wall, goal: goal, start: start };
      return ok;
    }
    if (d > 0 && best === null) {
      best = { wall: wall, goal: goal, start: start };
    }
  }
  if (best !== null) {
    return best;
  }
  const empty: boolean[] = new Array<boolean>(MAX_CELLS).fill(false);
  empty[7] = true;
  empty[8] = true;
  const out: Board = { wall: empty, goal: n * n - 1, start: 0 };
  return out;
}

@Component
export struct GMirrorMaze {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6）
  @State private diffTotal: number = GameDiff.sizeNow(6);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State private wall: boolean[] = []; @State private goal: number = CELLS - 1; @State private pos: number = 0;
  @State private steps: number = 0; @State private limit: number = 18; @State private short: number = 0;
  @State private msg: string = ''; @State private over: boolean = false; @State private won: boolean = false;
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  private reset(): void {
    const b: Board = makeBoard(this.diffTotal);
    this.wall = b.wall;
    this.goal = b.goal;
    this.pos = b.start;
    this.short = bfs(b.wall, b.goal, b.start, this.diffTotal);
    if (this.short < 6) {
      this.short = 8;
    }
    this.limit = this.short + 7;
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.done = false;
    this.msg = TG('🌀 镜中世界：按「左」会往右走，按「右」往左走');
    this.startAt = Date.now();
  }
  private tap(dir: number): void {
    if (this.over || this.done) { return; }
    const dx: number[] = [0, 1, 0, -1];
    const dy: number[] = [-1, 0, 1, 0];
    const cx: number = this.pos % this.diffTotal;
    const cy: number = Math.floor(this.pos / this.diffTotal);
    const nx: number = cx + dx[dir];
    const ny: number = cy + dy[dir];
    if (nx < 0 || nx >= this.diffTotal || ny < 0 || ny >= this.diffTotal) {
      this.msg = TG('🧱 撞到镜框了');
      return;
    }
    const ni: number = ny * this.diffTotal + nx;
    if (this.wall[ni]) {
      this.msg = TG('🧱 前面是墙');
      return;
    }
    this.pos = ni;
    this.steps = this.steps + 1;
    if (ni === this.goal) {
      this.done = true;
      this.over = true;
      this.won = true;
      this.msg = TG2('🎉 抵达 🏁 · 走了 {0} 步（最短 {1}）',Digits(String(this.steps), this.langCode),Digits(String(this.short), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.steps >= this.limit) {
      this.done = true;
      this.over = true;
      this.won = false;
      this.msg = TG('💤 步数用完了，没能走出镜子');
      this.finish(false);
      return;
    }
    this.msg = TG2("已走 {0} 步 · 还能走 {1} 步",Digits(String(this.steps), this.langCode), String(this.limit - this.steps));
  }
  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mirror_maze', solved: solved,
      score: solved ? Math.max(120, 700 - (this.steps - this.short) * 60) : 0,
      durationMs: Date.now() - this.startAt, levelReached: this.steps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(this.limit))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, this.limit - this.steps)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('最短'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.short), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: 2 }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: 2 }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.face((r * this.diffTotal + c)))
              .fontSize(FontSize.lg)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Text(('◀'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((3)); })
        Text(('▲'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((0)); })
        Text(('▼'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((2)); })
        Text(('▶'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(48))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .onClick(() => { Haptics.tick(); this.tap((1)); })
      }
      .width('100%')
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.teal)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：走到 🏁 通关 · 步数上限 = 最短路径 + 7'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }


  private face(i: number): string {
    if (this.wall[i]) {
      return '';
    }
    if (i === this.pos) {
      return '🌀';
    }
    if (i === this.goal) {
      return '🏁';
    }
    return '';
  }
  private cellBg(i: number): string {
    if (this.wall[i]) {
      return this.theme.isDark ? '#2B2B33' : '#3F3F46';
    }
    if (i === this.pos) {
      return Palette.teal;
    }
    if (i === this.goal) {
      return Palette.emerald;
    }
    return this.theme.surface;
  }

}
