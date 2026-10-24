/**
 * 填数拼图（Fillomino）🧩
 *
 * 规则：把空格填上数字，使**同数字的连通块大小恰好等于该数字**
 *       （例如 4 只能出现在由 4 格组成的连通块里）。
 * 胜负：全部填满且每块大小都对 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const MAX_MOVES: number = 150;
const SIZES: number = N + 2;   // 1..8，正好铺满 36 格

interface FilloGen {
  sol: number[];
  given: boolean[];
}

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

function freeDegree(j: number, vis: boolean[]): number {
  const r: number = Math.floor(j / N);
  const c: number = j - r * N;
  let d: number = 0;
  if (c > 0 && !vis[j - 1]) {
    d++;
  }
  if (c < N - 1 && !vis[j + 1]) {
    d++;
  }
  if (r > 0 && !vis[j - N]) {
    d++;
  }
  if (r < N - 1 && !vis[j + N]) {
    d++;
  }
  return d;
}

/** 随机哈密顿路径（Warnsdorff 启发式）—— 沿路径切块，块必然连通 */
function hamDfs(cur: number, cnt: number, vis: boolean[], path: number[]): boolean {
  if (cnt === N * N) {
    return true;
  }
  const r: number = Math.floor(cur / N);
  const c: number = cur - r * N;
  const nbs: number[] = [];
  if (c > 0 && !vis[cur - 1]) {
    nbs.push(cur - 1);
  }
  if (c < N - 1 && !vis[cur + 1]) {
    nbs.push(cur + 1);
  }
  if (r > 0 && !vis[cur - N]) {
    nbs.push(cur - N);
  }
  if (r < N - 1 && !vis[cur + N]) {
    nbs.push(cur + N);
  }
  shuffleArr(nbs);
  for (let i = 1; i < nbs.length; i++) {
    const v: number = nbs[i];
    const d: number = freeDegree(v, vis);
    let j: number = i - 1;
    while (j >= 0 && freeDegree(nbs[j], vis) > d) {
      nbs[j + 1] = nbs[j];
      j--;
    }
    nbs[j + 1] = v;
  }
  for (let k = 0; k < nbs.length; k++) {
    const j: number = nbs[k];
    vis[j] = true;
    path.push(j);
    if (hamDfs(j, cnt + 1, vis, path)) {
      return true;
    }
    path.splice(path.length - 1, 1);
    vis[j] = false;
  }
  return false;
}

function filloGen(): FilloGen {
  let path: number[] = [];
  for (let t = 0; t < 40 && path.length === 0; t++) {
    const vis: boolean[] = new Array<boolean>(N * N).fill(false);
    const p: number[] = [];
    const s: number = Math.floor(Math.random() * N * N);
    vis[s] = true;
    p.push(s);
    if (hamDfs(s, 1, vis, p)) {
      path = p;
    }
  }
  if (path.length !== N * N) {
    path = [];
    for (let r = 0; r < N; r++) {
      for (let k = 0; k < N; k++) {
        const c: number = r % 2 === 0 ? k : N - 1 - k;
        path.push(r * N + c);
      }
    }
  }
  const sizes: number[] = [];
  for (let k = 1; k <= SIZES; k++) {
    sizes.push(k);
  }
  shuffleArr(sizes);
  const sol: number[] = new Array<number>(N * N).fill(0);
  let idx: number = 0;
  for (let s = 0; s < sizes.length; s++) {
    for (let k = 0; k < sizes[s]; k++) {
      sol[path[idx]] = sizes[s];
      idx++;
    }
  }
  const given: boolean[] = new Array<boolean>(N * N).fill(false);
  for (let i = 0; i < N * N; i++) {
    given[i] = Math.random() < 0.5;
  }
  return { sol: sol, given: given };
}

@Component
export struct GFillomino {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private sol: number[] = [];
  @State private given: boolean[] = [];
  @State private vals: number[] = [];
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private sel: number = -1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const g: FilloGen = filloGen();
    this.sol = g.sol;
    this.given = g.given;
    const v: number[] = [];
    for (let i = 0; i < N * N; i++) {
      v.push(g.given[i] ? g.sol[i] : 0);
    }
    this.vals = v;
    this.sel = -1;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.vals.length; i++) {
      if (this.vals[i] > 0) {
        n++;
      }
    }
    return n;
  }

  /** 每块大小是否等于块内数字 */
  private allOk(): boolean {
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] === 0) {
        return false;
      }
    }
    const seen: boolean[] = new Array<boolean>(N * N).fill(false);
    for (let i = 0; i < N * N; i++) {
      if (seen[i]) {
        continue;
      }
      const v: number = this.vals[i];
      const st: number[] = [i];
      seen[i] = true;
      let cnt: number = 0;
      while (st.length > 0) {
        const k: number = st[st.length - 1];
        st.splice(st.length - 1, 1);
        cnt++;
        const r: number = Math.floor(k / N);
        const c: number = k - r * N;
        if (c > 0 && !seen[k - 1] && this.vals[k - 1] === v) {
          seen[k - 1] = true;
          st.push(k - 1);
        }
        if (c < N - 1 && !seen[k + 1] && this.vals[k + 1] === v) {
          seen[k + 1] = true;
          st.push(k + 1);
        }
        if (r > 0 && !seen[k - N] && this.vals[k - N] === v) {
          seen[k - N] = true;
          st.push(k - N);
        }
        if (r < N - 1 && !seen[k + N] && this.vals[k + N] === v) {
          seen[k + N] = true;
          st.push(k + N);
        }
      }
      if (cnt !== v) {
        return false;
      }
    }
    return true;
  }

  // ═══════════ 提示 + 代打（2026-10-24 第三期）═══════════
  private computeHint(): HintResult {
    const t0: number = Date.now();
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] === 0 && this.sol[i] > 0) {
        const r: number = Math.floor(i / N) + 1;
        const c: number = (i % N) + 1;
        return Hint.make([i],
          TG2('第 {0} 行第 {1} 列应该填 {2}', String(r), String(c), String(this.sol[i])),
          TG2('Row {0}, column {1} should be {2}', String(r), String(c), String(this.sol[i])), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一局暂时给不出提示'));
  }

  /** ★ AI 代打：用出题时的完整解，一格一格填 */
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.sol.length < N * N) {
      return false;
    }
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] !== this.sol[i] && !this.given[i]) {
        this.sel = i;
        this.setVal(this.sol[i]);
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

  private setVal(v: number): void {
    if (this.over || this.sel < 0 || this.given[this.sel]) {
      return;
    }
    const n: number[] = this.vals.slice();
    n[this.sel] = v;
    this.vals = n;
    this.moves++;
    if (this.allOk()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
      return;
    }
    let next: number = -1;
    for (let k = this.sel + 1; k < N * N; k++) {
      if (!this.given[k] && this.vals[k] === 0) {
        next = k;
        break;
      }
    }
    if (next < 0) {
      for (let k = 0; k < N * N; k++) {
        if (!this.given[k] && this.vals[k] === 0) {
          next = k;
          break;
        }
      }
    }
    this.sel = next;
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'fillomino',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : this.filledCount() * 25,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filledCount()) + '/36'))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('空格'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(N * N - this.filledCount())))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode))
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
      .width('100%')

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Stack() {
              Text(this.vals[(r * N + c)] > 0 ? String(this.vals[(r * N + c)]) : '')
              .fontSize(FontSize.xl)
              .fontWeight(this.given[(r * N + c)] ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.given[(r * N + c)] ? this.theme.ink : Palette.primary)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.sel === (r * N + c) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
              (this.given[(r * N + c)] ? this.theme.surface : this.theme.surfaceAlt))
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .onClick(() => {
              Haptics.tick();
              if (!this.over && !this.given[(r * N + c)]) {
              this.sel = (r * N + c);
              }
              })
            }, (c: number) => 'fm' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'fmr' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4], (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.setVal((d));
          })
        }, (d: number) => 'fk' + d)
      }
      .width('100%')

      Row({ space: Space.xs }) {
        ForEach([5, 6, 7, 8], (d: number) => {
          Text(String((d)))
          .fontSize(FontSize.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.setVal((d));
          })
        }, (d: number) => 'fk2' + d)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(TG('清除本格'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.setVal(0);
          })
        Button(TG('提示'))
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askAuto();
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
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.over ? (this.won ? '🎉 每块大小都对，通关！' : TG('步数用尽，重开一题吧')) :
        '粗体数字是题目给的提示，浅底格是尚未填的')
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint).animation({ duration: Motion.fast, curve: Motion.snap() })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }






}
