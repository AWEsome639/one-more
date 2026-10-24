/**
 * 灯塔（Light Up 变体）—— 5×5 🗼
 *
 * 规则：海面上有礁石 🪨 与船只 🚢；在空水格里放灯塔 💡。
 *   ① 每艘船必须被至少一座灯塔照到（灯光沿上下左右直射，遇礁石被挡）
 *   ② 两座灯塔不能互相照到（中间没有礁石）
 * 玩法：点空格放 / 收灯塔；三条判定每步自动检查。
 * 胜负：船全亮 且 灯塔互不照 ⇒ 通关；步数用尽 ⇒ 失败。
 * 出题：随机撒礁石与船，再用回溯搜索确认这盘一定有解。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const MAX_MOVES: number = 40;
const MAX_NODES: number = 80000;
const DR: number[] = [-1, 1, 0, 0];
const DC: number[] = [0, 0, -1, 1];
/** 兜底棋盘：四角礁石 + 十字五船，中宫一盏灯即可全亮 */
const FB_ROCK: number[] = [0, 4, 20, 24];
const FB_SHIP: number[] = [2, 10, 12, 14, 22];

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GLighthouses {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private rock: boolean[] = new Array<boolean>(CELLS).fill(false);
  @State private ship: boolean[] = new Array<boolean>(CELLS).fill(false);
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private lamp: boolean[] = new Array<boolean>(CELLS).fill(false);
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private tip: string = TG('点空格放灯塔，让每艘船都被照亮');

  private startAt: number = 0;
  private finished: boolean = false;
  private nodes: number = 0;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private rowOf(i: number): number {
    return Math.floor(i / N);
  }

  private colOf(i: number): number {
    return i % N;
  }

  // ── 光的规则 ──

  /** a、b 同一行/列且中间没有礁石 ⇒ 互相看得见 */
  private sees(a: number, b: number, rock: boolean[]): boolean {
    const ra: number = this.rowOf(a);
    const ca: number = this.colOf(a);
    const rb: number = this.rowOf(b);
    const cb: number = this.colOf(b);
    if (ra === rb && ca !== cb) {
      const lo: number = ca < cb ? ca : cb;
      const hi: number = ca < cb ? cb : ca;
      for (let c = lo + 1; c < hi; c++) {
        if (rock[ra * N + c]) {
          return false;
        }
      }
      return true;
    }
    if (ca === cb && ra !== rb) {
      const lo: number = ra < rb ? ra : rb;
      const hi: number = ra < rb ? rb : ra;
      for (let r = lo + 1; r < hi; r++) {
        if (rock[r * N + ca]) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  private lit(i: number, lamp: boolean[], rock: boolean[]): boolean {
    if (lamp[i]) {
      return true;
    }
    const r0: number = this.rowOf(i);
    const c0: number = this.colOf(i);
    for (let d = 0; d < 4; d++) {
      let r: number = r0;
      let c: number = c0;
      while (true) {
        r += DR[d];
        c += DC[d];
        if (r < 0 || r >= N || c < 0 || c >= N) {
          break;
        }
        const j: number = r * N + c;
        if (rock[j]) {
          break;
        }
        if (lamp[j]) {
          return true;
        }
      }
    }
    return false;
  }

  private shipsLit(lamp: boolean[], rock: boolean[], ship: boolean[]): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (ship[i] && this.lit(i, lamp, rock)) {
        n++;
      }
    }
    return n;
  }

  private shipTotal(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.ship[i]) {
        n++;
      }
    }
    return n;
  }

  private lampCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.lamp[i]) {
        n++;
      }
    }
    return n;
  }

  /** 有没有两座灯塔互相照到 */
  private conflict(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (!this.lamp[i]) {
        continue;
      }
      for (let j = i + 1; j < CELLS; j++) {
        if (this.lamp[j] && this.sees(i, j, this.rock)) {
          return true;
        }
      }
    }
    return false;
  }

  // ── 回溯搜索：确认这盘有解 ──

  private anySee(i: number, lamp: boolean[], rock: boolean[]): boolean {
    for (let j = 0; j < CELLS; j++) {
      if (lamp[j] && this.sees(i, j, rock)) {
        return true;
      }
    }
    return false;
  }

  /** 剪枝：已决定的船若没人能再照到 ⇒ 这条分支没戏 */
  private futureOk(i: number, lamp: boolean[], rock: boolean[], ship: boolean[]): boolean {
    for (let j = 0; j <= i; j++) {
      if (!ship[j] || this.lit(j, lamp, rock)) {
        continue;
      }
      let hope: boolean = false;
      for (let k = i + 1; k < CELLS; k++) {
        if (!rock[k] && !ship[k] && !lamp[k] && this.sees(k, j, rock)) {
          hope = true;
          break;
        }
      }
      if (!hope) {
        return false;
      }
    }
    return true;
  }

  private search(i: number, lamp: boolean[], rock: boolean[], ship: boolean[]): boolean {
    this.nodes++;
    if (this.nodes > MAX_NODES) {
      return false;
    }
    if (i === CELLS) {
      return this.shipsLit(lamp, rock, ship) === this.countIn(ship);
    }
    if (rock[i] || ship[i]) {
      return this.search(i + 1, lamp, rock, ship);
    }
    if (!this.anySee(i, lamp, rock)) {
      lamp[i] = true;
      if (this.futureOk(i, lamp, rock, ship) && this.search(i + 1, lamp, rock, ship)) {
        return true;
      }
      lamp[i] = false;
    }
    return this.futureOk(i, lamp, rock, ship) && this.search(i + 1, lamp, rock, ship);
  }

  private countIn(flags: boolean[]): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (flags[i]) {
        n++;
      }
    }
    return n;
  }

  private mkBoard(): boolean {
    let guard: number = 0;
    while (guard < 40) {
      guard++;
      this.nodes = 0;
      const rk: boolean[] = new Array<boolean>(CELLS).fill(false);
      const sp: boolean[] = new Array<boolean>(CELLS).fill(false);
      for (let i = 0; i < CELLS; i++) {
        if (Math.random() < 0.2) {
          rk[i] = true;
        }
      }
      for (let i = 0; i < CELLS; i++) {
        if (!rk[i] && Math.random() < 0.24) {
          sp[i] = true;
        }
      }
      const nr: number = this.countIn(rk);
      const ns: number = this.countIn(sp);
      if (nr < 3 || nr > 7 || ns < 3 || ns > 5) {
        continue;
      }
      const lamp: boolean[] = new Array<boolean>(CELLS).fill(false);
      if (this.search(0, lamp, rk, sp)) {
        this.rock = rk;
        this.ship = sp;
        return true;
      }
    }
    return false;
  }

  private reset(): void {
    const ok: boolean = this.mkBoard();
    if (!ok) {
      const rk: boolean[] = new Array<boolean>(CELLS).fill(false);
      const sp: boolean[] = new Array<boolean>(CELLS).fill(false);
      for (let i = 0; i < FB_ROCK.length; i++) {
        rk[FB_ROCK[i]] = true;
      }
      for (let i = 0; i < FB_SHIP.length; i++) {
        sp[FB_SHIP[i]] = true;
      }
      this.rock = rk;
      this.ship = sp;
    }
    this.lamp = new Array<boolean>(CELLS).fill(false);
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.tip = TG('点空格放灯塔，让每艘船都被照亮');
    this.startAt = Date.now();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'lighthouses',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 20) : this.shipsLit(this.lamp, this.rock, this.ship) * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.shipsLit(this.lamp, this.rock, this.ship)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private check(): void {
    if (this.finished) {
      return;
    }
    const litN: number = this.shipsLit(this.lamp, this.rock, this.ship);
    const total: number = this.shipTotal();
    if (litN === total && !this.conflict() && this.lampCount() > 0) {
      this.over = true;
      this.won = true;
      this.tip = TG('🎉 船全亮、灯不互照，通关！');
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.tip = TG('步数用尽，重开一题吧');
      this.finish(false);
      return;
    }
    if (this.conflict()) {
      this.tip = TG('✗ 有两座灯塔互相照到了');
    } else {
      this.tip = TG2('已照亮 {0}/{1} 艘船', String(litN), String(total));
    }
  }

  // ═══════════ 提示 + 代打（2026-10-24 第三期）═══════════
  // 这款游戏本来就有真求解器 search()（出题时用它验证可解）
  // ⇒ 直接复用它求一组灯位。

  private solveLamps(): boolean[] {
    const lamp: boolean[] = new Array<boolean>(CELLS).fill(false);
    this.nodes = 0;
    if (!this.search(0, lamp, this.rock, this.ship)) {
      return [];
    }
    return lamp;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const sol: boolean[] = this.solveLamps();
    if (sol.length === 0) {
      return Hint.none('none');
    }
    for (let i = 0; i < CELLS; i++) {
      if (sol[i] && !this.lamp[i]) {
        const r: number = this.rowOf(i) + 1;
        const c: number = this.colOf(i) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列放一座灯塔', String(r), String(c)),
          TG2('Put a lighthouse at row {0}, column {1}', String(r), String(c)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步看不出哪格该放灯'));
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const sol: boolean[] = this.solveLamps();
    if (sol.length === 0) {
      return false;
    }
    for (let i = 0; i < CELLS; i++) {
      if (this.lamp[i] !== sol[i] && !this.rock[i] && !this.ship[i]) {
        this.tap(i);
        return !this.over;
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

  private tap(i: number): void {
    if (this.over || this.rock[i] || this.ship[i]) {
      return;
    }
    const nl: boolean[] = this.lamp.slice();
    nl[i] = !nl[i];
    this.lamp = nl;
    this.moves++;
    this.check();
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.moves) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('照亮船'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.shipsLit(this.lamp, this.rock, this.ship)) + '/' + String(this.shipTotal()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('灯塔'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.lampCount()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
              Text(this.rock[(r * N + c)] ? '🪨' : (this.ship[(r * N + c)] ? '🚢' : (this.lamp[(r * N + c)] ? '💡' : '')))
              .fontSize(FontSize.xl)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.ship[(r * N + c)] && !this.lit((r * N + c), this.lamp, this.rock)
              ? '#33F43F5E'
              : (this.lit((r * N + c), this.lamp, this.rock) ? '#22F59E0B' : '#00000000'))
              .borderRadius(Radius.xs)
              .border({ width: 1, color: this.theme.line })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'lc' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'lr' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#0B1220' : '#E6F1FB')
      .borderRadius(Radius.md)

      Text(this.tip)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Text(TG('💡 放在空格；光沿直线走，遇 🪨 被挡；两盏灯不能互相照到'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)


      Row({ space: Space.sm }) {
        Button(this.over ? (this.won ? TG('已通关 🎉') : TG('已结束')) : TG('重开一题'))
        .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('提示'))
          .layoutWeight(1)
          .height(Cell.of(38))
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .layoutWeight(1)
          .height(Cell.of(38))
          .onClick(() => {
            this.askAuto();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
