/**
 * 倒水排序 water_sort —— 试管里的颜色分层，倒来倒去让每管只剩一种颜色
 *
 * 操作：点一根试管选中，再点另一根倒过去（同色或空管才收）
 * 胜负：每根试管都单色 ⇒ 通关；一步都走不动 ⇒ 失败
 * 进度：归位管数 ／ 步数 ／ 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const CAP: number = 4;          // 每管容量
/**
 * ★★★ 2026-10-23 修「尺寸陷阱」第 15 个：
 *   颜色数由难度决定（diffTotal = sizeNow(4) → 3/4/5），
 *   管子数应该 = 颜色数 + 2（5/6/7）。
 *   但原来 TUBES = COLORS + 2 里的 COLORS 是**常量 4** ⇒ 恒为 6：
 *     · 简单（3 色）：6 根管子里有 3 根是空的（应该 2 根）⇒ 太容易
 *     · 困难（5 色）：6 根里只剩 1 根空的（应该 2 根）⇒ 可能无解
 *     · 而且 5 色时该是 7 根 × 4 格 = 28 格，原来只分配 24 ⇒ 越界
 *   ⇒ 修法：颜色数仍走 diffTotal，管子数按「颜色数 + 2」现算，
 *     分配按**最大可能**（5 色 + 2 = 7 根）来。
 */
const MAX_TUBES: number = 7;    // 最多 5 色 + 2 根空管

function tubeColor(c: number): string {
  const wheel: number[] = [0, 3, 1, 5, 7, 9];
  return Palette.wheel[wheel[c % wheel.length]];
}

function shuffled(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  for (let i = n - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

@Component
export struct GWaterSort {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 COLORS=4，按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(4);
  onFinish: (r: GameResult) => void = () => {};

  @State flat: number[] = [];
  @State sel: number = -1;
  @State moves: number = 0;
  @State done: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;

  private startAt: number = 0;
  /** 本局的管子数 = 颜色数 + 2（颜色数已按难度换算） */
  private tubeCount(): number {
    return this.diffTotal + 2;
  }

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
    this.reset();
  }

  private at(st: number[], t: number, k: number): number {
    return st[t * CAP + k];
  }

  private topOf(st: number[], t: number): number {
    for (let k = CAP - 1; k >= 0; k--) {
      if (this.at(st, t, k) >= 0) {
        return this.at(st, t, k);
      }
    }
    return -1;
  }

  private freeOf(st: number[], t: number): number {
    let n: number = 0;
    for (let k = 0; k < CAP; k++) {
      if (this.at(st, t, k) < 0) {
        n++;
      }
    }
    return n;
  }

  private runTop(st: number[], t: number): number {
    const c: number = this.topOf(st, t);
    if (c < 0) {
      return 0;
    }
    let n: number = 0;
    for (let k = CAP - 1; k >= 0; k--) {
      if (this.at(st, t, k) === c) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /** 非空的格子是否同色（用来禁止「整管搬去空管」这种原地打转） */
  private sameAll(st: number[], t: number): boolean {
    const c: number = this.topOf(st, t);
    if (c < 0) {
      return false;
    }
    for (let k = 0; k < CAP; k++) {
      const v: number = this.at(st, t, k);
      if (v >= 0 && v !== c) {
        return false;
      }
    }
    return true;
  }

  private legal(st: number[], a: number, b: number): boolean {
    if (a === b) {
      return false;
    }
    const ca: number = this.topOf(st, a);
    if (ca < 0) {
      return false;
    }
    if (this.freeOf(st, b) === 0) {
      return false;
    }
    const cb: number = this.topOf(st, b);
    if (cb < 0) {
      return !this.sameAll(st, a);
    }
    return cb === ca;
  }

  private poured(st: number[], a: number, b: number): number[] {
    const out: number[] = st.slice();
    const c: number = this.topOf(out, a);
    const n: number = this.runTop(out, a);
    const space: number = this.freeOf(out, b);
    const move: number = n < space ? n : space;
    for (let i = 0; i < move; i++) {
      for (let k = CAP - 1; k >= 0; k--) {
        if (this.at(out, a, k) === c) {
          out[a * CAP + k] = -1;
          break;
        }
      }
    }
    for (let i = 0; i < move; i++) {
      for (let k = 0; k < CAP; k++) {
        if (this.at(out, b, k) < 0) {
          out[b * CAP + k] = c;
          break;
        }
      }
    }
    return out;
  }

  private isDone(st: number[]): boolean {
    for (let t = 0; t < this.tubeCount(); t++) {
      if (this.topOf(st, t) >= 0 && !this.sameAll(st, t)) {
        return false;
      }
    }
    return true;
  }

  private anyMove(st: number[]): boolean {
    for (let a = 0; a < this.tubeCount(); a++) {
      for (let b = 0; b < this.tubeCount(); b++) {
        if (this.legal(st, a, b)) {
          return true;
        }
      }
    }
    return false;
  }

  /** 贪心求解器：能解出来的牌面才发给玩家 */
  private pickMove(st: number[]): number {
    let best: number = -1;
    const cand: number[] = [];
    for (let a = 0; a < this.tubeCount(); a++) {
      for (let b = 0; b < this.tubeCount(); b++) {
        if (!this.legal(st, a, b)) {
          continue;
        }
        const n: number = this.runTop(st, a);
        const space: number = this.freeOf(st, b);
        let sc: number = this.topOf(st, b) >= 0 ? 2 : 1;
        if (n <= space && this.freeOf(st, a) + n === CAP) {
          sc += 2;                      // 倒完能清空源管
        }
        if (n <= space && space === n) {
          sc += 1;                      // 正好接满
        }
        if (sc > best) {
          best = sc;
          cand.length = 0;
          cand.push(a * 100 + b);
        } else if (sc === best) {
          cand.push(a * 100 + b);
        }
      }
    }
    if (cand.length === 0) {
      return -1;
    }
    return cand[Math.floor(Math.random() * cand.length)];
  }

  private solvable(start: number[]): boolean {
    for (let attempt = 0; attempt < 16; attempt++) {
      let st: number[] = start.slice();
      let steps: number = 0;
      while (!this.isDone(st) && steps < 160) {
        steps++;
        const mv: number = this.pickMove(st);
        if (mv < 0) {
          break;
        }
        st = this.poured(st, Math.floor(mv / 100), mv % 100);
      }
      if (this.isDone(st)) {
        return true;
      }
    }
    return false;
  }

  private freshDeal(): number[] {
    let last: number[] = [];
    for (let attempt = 0; attempt < 60; attempt++) {
      const pool: number[] = [];
      for (let c = 0; c < this.diffTotal; c++) {
        for (let k = 0; k < CAP; k++) {
          pool.push(c);
        }
      }
      for (let i = pool.length - 1; i > 0; i--) {
        const j: number = Math.floor(Math.random() * (i + 1));
        const t: number = pool[i];
        pool[i] = pool[j];
        pool[j] = t;
      }
      const st: number[] = new Array<number>(MAX_TUBES * CAP).fill(-1);
      for (let t = 0; t < this.diffTotal; t++) {
        for (let k = 0; k < CAP; k++) {
          st[t * CAP + k] = pool[t * CAP + k];
        }
      }
      last = st.slice();
      if (!this.isDone(st) && this.solvable(st)) {
        return st;
      }
    }
    return last;
  }

  private reset(): void {
    this.flat = this.freshDeal();
    this.sel = -1;
    this.moves = 0;
    this.done = this.doneCount(this.flat);
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private doneCount(st: number[]): number {
    let n: number = 0;
    for (let t = 0; t < this.tubeCount(); t++) {
      if (this.topOf(st, t) >= 0 && this.sameAll(st, t)) {
        n++;
      }
    }
    return n;
  }

  private tapTube(t: number): void {
    if (this.over) {
      return;
    }
    if (this.sel < 0) {
      if (this.topOf(this.flat, t) >= 0) {
        this.sel = t;
      }
      return;
    }
    if (this.sel === t) {
      this.sel = -1;
      return;
    }
    const a: number = this.sel;
    if (!this.legal(this.flat, a, t)) {
      this.sel = this.topOf(this.flat, t) >= 0 ? t : -1;
      return;
    }
    const next: number[] = this.poured(this.flat, a, t);
    this.flat = next;
    this.sel = -1;
    this.moves++;
    this.done = this.doneCount(next);
    if (this.isDone(next)) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(60, 520 - this.moves * 8 - sec);
      this.finish(true);
      return;
    }
    if (!this.anyMove(next)) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'water_sort',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.done
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tip(): string {
    if (this.over) {
      return this.won ? TG2("全部单色 🎉 得分 {0}",Digits(String(this.score), this.langCode)) : '倒不动了，本局失败';
    }
    return this.sel < 0 ? '点一根试管选中，再点另一根倒过去' : TG2("已选中第 {0} 管", String(this.sel + 1));
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('归位'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.done) + '/' + String(this.diffTotal)))
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
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode))
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

      Row({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (t: number) => {
          Column({ space: Space.xs }) {
          ForEach([3, 2, 1, 0], (k: number) => {
          Stack() {
          Text('')
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor(this.at(this.flat, ((t)), (k)) < 0
          ? (this.theme.isDark ? '#10FFFFFF' : '#08000000')
          : tubeColor(this.at(this.flat, ((t)), (k))))
          .borderRadius(Radius.xs)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (k: number) => 'l' + k)
          }
          .layoutWeight(1)
          .height('100%')
          .padding(Space.xs)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .border({
          width: this.sel === (t) ? 2 : 1,
          color: this.sel === (t) ? Palette.amber : this.theme.line
          })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapTube((t));
          })
        }, (t: number) => 't' + t)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.tip())
        .fontSize(FontSize.sm)
        .fontColor(this.over
          ? (this.won ? Palette.emerald : Palette.rose)
          : this.theme.inkSoft)
        .width('100%')

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(Palette.amber)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('倒水规则：只有颜色相同、或目标管是空的才能倒；倒的量受目标管剩余空间限制'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }






}
