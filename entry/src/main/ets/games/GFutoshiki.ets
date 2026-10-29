/**
 * 不等式（Futoshiki）🧩
 *
 * 规则：5×5 每行每列都填 1~5 且不重复，同时满足格与格之间的不等号。
 * 胜负：填满且行列不重复、所有不等号成立 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5;
const MAX_MOVES: number = 120;
const SIGN_W: number = 18;

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 循环拉丁方 + 行/列/符号三重打乱 ⇒ 必然是合法拉丁方 */
function latinSquare(): number[] {
  const rows: number[] = [0, 1, 2, 3, 4];
  const cols: number[] = [0, 1, 2, 3, 4];
  const syms: number[] = [1, 2, 3, 4, 5];
  shuffleArr(rows);
  shuffleArr(cols);
  shuffleArr(syms);
  const out: number[] = new Array<number>(N * N).fill(0);
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      const base: number = (rows[r] + cols[c]) % N;
      out[r * N + c] = syms[base];
    }
  }
  return out;
}

@Component
export struct GFutoshiki {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  /** 出题时的完整解 */

  private solVals: number[] = [];

  /** 代打计时器（-1 = 未运行）。必须 @State */

  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;

  @State private vals: number[] = [];
  @State private given: boolean[] = [];
  @State private hSign: number[] = [];   // 水平：(r,c)-(r,c+1)，1 = <，2 = >
  @State private vSign: number[] = [];   // 垂直：(r,c)-(r+1,c)，1 = <，2 = >
  @State private sel: number = -1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 2026-10-29（lead 补）：之前手工接漏了这一步 ⇒ 演示方法写了却从没被调用
    //   进来 3 秒内没人动就开始演示（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GFutoshiki')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const sol: number[] = latinSquare();
    const given: boolean[] = new Array<boolean>(N * N).fill(false);
    const order: number[] = [];
    for (let i = 0; i < N * N; i++) {
      order.push(i);
    }
    shuffleArr(order);
    for (let k = 0; k < 8; k++) {
      given[order[k]] = true;
    }
    const h: number[] = new Array<number>(N * (N - 1)).fill(0);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N - 1; c++) {
        if (Math.random() < 0.45) {
          h[r * (N - 1) + c] = sol[r * N + c] < sol[r * N + c + 1] ? 1 : 2;
        }
      }
    }
    const v: number[] = new Array<number>((N - 1) * N).fill(0);
    for (let r = 0; r < N - 1; r++) {
      for (let c = 0; c < N; c++) {
        if (Math.random() < 0.45) {
          v[r * N + c] = sol[r * N + c] < sol[(r + 1) * N + c] ? 1 : 2;
        }
      }
    }
    const vv: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < N * N; i++) {
      vv[i] = given[i] ? sol[i] : 0;
    }
    this.vals = vv;
    // ★ 2026-10-24 第三期：出题时的完整解留着（同数壹的做法）
    this.solVals = sol.slice();
    this.given = given;
    this.hSign = h;
    this.vSign = v;
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


  /** 1..N 的全部排列（N=5 时 120 个） */
  private allPerms5(): number[][] {
    const out: number[][] = [];
    const cur: number[] = [];
    const used: boolean[] = new Array<boolean>(N + 1).fill(false);
    const rec = (): void => {
      if (cur.length === N) {
        out.push(cur.slice());
        return;
      }
      for (let v = 1; v <= N; v++) {
        if (used[v]) {
          continue;
        }
        used[v] = true;
        cur.push(v);
        rec();
        cur.pop();
        used[v] = false;
      }
    };
    rec();
    return out;
  }

  /**
   * ★ 2026-10-23 第二期：不等式提示
   *
   * 规则：每行每列是 1..N 的排列，相邻格要满足给的不等号。
   * ⇒ 逐行/逐列「枚举所有符合不等号与已填数字的排列（N=5 时 120 个）→ 求交集」，
   *    所有候选都一致的格就是确定的。
   *
   * ⚠️ 只做行内/列内推理，不做全盘搜索 —— 宁可少给。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const perms: number[][] = this.allPerms5();
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < N; k++) {
        const marks: number[] = [];
        const signs: number[] = [];
        for (let i = 0; i < N; i++) {
          marks.push(horiz === 1 ? this.vals[k * N + i] : this.vals[i * N + k]);
        }
        for (let i = 0; i < N - 1; i++) {
          if (horiz === 1) {
            signs.push(this.hSign[k * (N - 1) + i]);
          } else {
            signs.push(this.vSign[i * N + k]);
          }
        }
        let acc: number[] = [];
        let cnt: number = 0;
        for (let pi = 0; pi < perms.length; pi++) {
          const cand: number[] = perms[pi];
          let ok: boolean = true;
          for (let i = 0; i < N - 1; i++) {
            const sg: number = signs[i];
            if (sg === 1 && !(cand[i] < cand[i + 1])) {
              ok = false;
              break;
            }
            if (sg === 2 && !(cand[i] > cand[i + 1])) {
              ok = false;
              break;
            }
          }
          if (!ok) {
            continue;
          }
          for (let i = 0; i < N; i++) {
            if (marks[i] !== 0 && marks[i] !== cand[i]) {
              ok = false;
              break;
            }
          }
          if (!ok) {
            continue;
          }
          if (cnt === 0) {
            acc = cand.slice();
          } else {
            for (let i = 0; i < N; i++) {
              if (acc[i] !== cand[i]) {
                acc[i] = -1;
              }
            }
          }
          cnt++;
        }
        if (cnt <= 1) {
          continue;
        }
        for (let i = 0; i < N; i++) {
          if (acc[i] < 0 || marks[i] === acc[i]) {
            continue;
          }
          const idx: number = horiz === 1 ? k * N + i : i * N + k;
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          return Hint.make([idx],
            TG2('第 {0} 行第 {1} 列一定是 {2}', String(r), String(c), String(acc[i])),
            TG2('Row {0}, column {1} must be {2}', String(r), String(c), String(acc[i])), t0);
        }
      }
    }
    return Hint.none('none');
  }

  /**
   * ★★ 2026-10-24 第三期：AI 代打（不等号）
   * 用出题时保留的完整解，一格一格填到位。
   */
  // ═══════════ 演示动画（项目 C）═══════════
  private demoFinish(): void {
    if (this.demoId >= 0) { Hint.autoStop(this.demoId); this.demoId = -1; }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) { Hint.autoStop(this.demoId); this.demoId = -1; }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.solVals.length !== N * N) {
      return false;
    }
    for (let i = 0; i < N * N; i++) {
      if (this.vals[i] !== this.solVals[i] && !this.given[i]) {
        this.sel = i;
        this.put(this.solVals[i]);
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

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok && r.cells.length > 0) {
      this.hintIdx = r.cells[0];
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintIdx = -1; this.hintMsg = ''; }, 4500);
      return;
    }
    this.hintIdx = -1;
    this.hintMsg = TG('这一步从不等号推不出来，得先试一个数');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  private signTotal(): number {
    let n: number = 0;
    for (let i = 0; i < this.hSign.length; i++) {
      if (this.hSign[i] > 0) {
        n++;
      }
    }
    for (let i = 0; i < this.vSign.length; i++) {
      if (this.vSign[i] > 0) {
        n++;
      }
    }
    return n;
  }

  private signOk(): number {
    let n: number = 0;
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N - 1; c++) {
        const s: number = this.hSign[r * (N - 1) + c];
        const a: number = this.vals[r * N + c];
        const b: number = this.vals[r * N + c + 1];
        if (s > 0 && a > 0 && b > 0 && ((s === 1 && a < b) || (s === 2 && a > b))) {
          n++;
        }
      }
    }
    for (let r = 0; r < N - 1; r++) {
      for (let c = 0; c < N; c++) {
        const s: number = this.vSign[r * N + c];
        const a: number = this.vals[r * N + c];
        const b: number = this.vals[(r + 1) * N + c];
        if (s > 0 && a > 0 && b > 0 && ((s === 1 && a < b) || (s === 2 && a > b))) {
          n++;
        }
      }
    }
    return n;
  }

  private latinOk(): boolean {
    for (let r = 0; r < N; r++) {
      const seen: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let c = 0; c < N; c++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen[v]) {
          return false;
        }
        seen[v] = true;
      }
    }
    for (let c = 0; c < N; c++) {
      const seen: boolean[] = new Array<boolean>(N + 1).fill(false);
      for (let r = 0; r < N; r++) {
        const v: number = this.vals[r * N + c];
        if (v === 0 || seen[v]) {
          return false;
        }
        seen[v] = true;
      }
    }
    return true;
  }

  private put(d: number): void {
    if (this.over || this.sel < 0 || this.given[this.sel]) {
      return;
    }
    const n: number[] = this.vals.slice();
    n[this.sel] = d;
    this.vals = n;
    this.moves++;
    if (this.latinOk() && this.signOk() === this.signTotal()) {
      this.over = true;
      this.won = true;
      this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'futoshiki',
      solved: solved,
      score: solved ? Math.max(200, 1500 - this.moves * 10) : this.filledCount() * 20,
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
        Text((String(this.filledCount()) + '/25'))
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
        Text((TG('不等式'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.signOk()) + '/' + String(this.signTotal())))
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
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((0) * N + 0)] > 0 ? String(this.vals[((0) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((0) * N + 0)]) { this.sel = ((0) * N + 0); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 0)]) {
        this.sel = ((0) * N + 0);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 1)] > 0 ? String(this.vals[((0) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((0) * N + 1)]) { this.sel = ((0) * N + 1); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 1)]) {
        this.sel = ((0) * N + 1);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 2)] > 0 ? String(this.vals[((0) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((0) * N + 2)]) { this.sel = ((0) * N + 2); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 2)]) {
        this.sel = ((0) * N + 2);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 3)] > 0 ? String(this.vals[((0) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((0) * N + 3)]) { this.sel = ((0) * N + 3); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 3)]) {
        this.sel = ((0) * N + 3);
        }
        })
        Text(this.hSign[((0)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((0)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((0)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((0) * N + 4)] > 0 ? String(this.vals[((0) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((0) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((0) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((0) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((0) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((0) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((0) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((0) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((0) * N + 4)]) { this.sel = ((0) * N + 4); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((0) * N + 4)]) {
        this.sel = ((0) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((0)) * N + (0)] === 1 ? 'v' : (this.vSign[((0)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (1)] === 1 ? 'v' : (this.vSign[((0)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (2)] === 1 ? 'v' : (this.vSign[((0)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (3)] === 1 ? 'v' : (this.vSign[((0)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((0)) * N + (4)] === 1 ? 'v' : (this.vSign[((0)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((0)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((1) * N + 0)] > 0 ? String(this.vals[((1) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((1) * N + 0)]) { this.sel = ((1) * N + 0); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 0)]) {
        this.sel = ((1) * N + 0);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 1)] > 0 ? String(this.vals[((1) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((1) * N + 1)]) { this.sel = ((1) * N + 1); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 1)]) {
        this.sel = ((1) * N + 1);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 2)] > 0 ? String(this.vals[((1) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((1) * N + 2)]) { this.sel = ((1) * N + 2); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 2)]) {
        this.sel = ((1) * N + 2);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 3)] > 0 ? String(this.vals[((1) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((1) * N + 3)]) { this.sel = ((1) * N + 3); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 3)]) {
        this.sel = ((1) * N + 3);
        }
        })
        Text(this.hSign[((1)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((1)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((1)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((1) * N + 4)] > 0 ? String(this.vals[((1) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((1) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((1) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((1) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((1) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((1) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((1) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((1) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((1) * N + 4)]) { this.sel = ((1) * N + 4); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((1) * N + 4)]) {
        this.sel = ((1) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((1)) * N + (0)] === 1 ? 'v' : (this.vSign[((1)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (1)] === 1 ? 'v' : (this.vSign[((1)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (2)] === 1 ? 'v' : (this.vSign[((1)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (3)] === 1 ? 'v' : (this.vSign[((1)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((1)) * N + (4)] === 1 ? 'v' : (this.vSign[((1)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((1)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((2) * N + 0)] > 0 ? String(this.vals[((2) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((2) * N + 0)]) { this.sel = ((2) * N + 0); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 0)]) {
        this.sel = ((2) * N + 0);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 1)] > 0 ? String(this.vals[((2) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((2) * N + 1)]) { this.sel = ((2) * N + 1); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 1)]) {
        this.sel = ((2) * N + 1);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 2)] > 0 ? String(this.vals[((2) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((2) * N + 2)]) { this.sel = ((2) * N + 2); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 2)]) {
        this.sel = ((2) * N + 2);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 3)] > 0 ? String(this.vals[((2) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((2) * N + 3)]) { this.sel = ((2) * N + 3); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 3)]) {
        this.sel = ((2) * N + 3);
        }
        })
        Text(this.hSign[((2)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((2)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((2)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((2) * N + 4)] > 0 ? String(this.vals[((2) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((2) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((2) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((2) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((2) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((2) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((2) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((2) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((2) * N + 4)]) { this.sel = ((2) * N + 4); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((2) * N + 4)]) {
        this.sel = ((2) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((2)) * N + (0)] === 1 ? 'v' : (this.vSign[((2)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (1)] === 1 ? 'v' : (this.vSign[((2)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (2)] === 1 ? 'v' : (this.vSign[((2)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (3)] === 1 ? 'v' : (this.vSign[((2)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((2)) * N + (4)] === 1 ? 'v' : (this.vSign[((2)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((2)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((3) * N + 0)] > 0 ? String(this.vals[((3) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((3) * N + 0)]) { this.sel = ((3) * N + 0); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 0)]) {
        this.sel = ((3) * N + 0);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 1)] > 0 ? String(this.vals[((3) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((3) * N + 1)]) { this.sel = ((3) * N + 1); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 1)]) {
        this.sel = ((3) * N + 1);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 2)] > 0 ? String(this.vals[((3) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((3) * N + 2)]) { this.sel = ((3) * N + 2); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 2)]) {
        this.sel = ((3) * N + 2);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 3)] > 0 ? String(this.vals[((3) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((3) * N + 3)]) { this.sel = ((3) * N + 3); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 3)]) {
        this.sel = ((3) * N + 3);
        }
        })
        Text(this.hSign[((3)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((3)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((3)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((3) * N + 4)] > 0 ? String(this.vals[((3) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((3) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((3) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((3) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((3) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((3) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((3) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((3) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((3) * N + 4)]) { this.sel = ((3) * N + 4); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((3) * N + 4)]) {
        this.sel = ((3) * N + 4);
        }
        })
        }
        .width('100%')
        Row({ space: Space.xs }) {
        Text(this.vSign[((3)) * N + (0)] === 1 ? 'v' : (this.vSign[((3)) * N + (0)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (1)] === 1 ? 'v' : (this.vSign[((3)) * N + (1)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (2)] === 1 ? 'v' : (this.vSign[((3)) * N + (2)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (3)] === 1 ? 'v' : (this.vSign[((3)) * N + (3)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        this.gapBox()
        Text(this.vSign[((3)) * N + (4)] === 1 ? 'v' : (this.vSign[((3)) * N + (4)] === 2 ? '^' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.vSign[((3)) * N + (4)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        }
        .width('100%')
        .height(SIGN_W)
        Row({ space: Space.xs }) {
        Stack() {
        Text(this.vals[((4) * N + 0)] > 0 ? String(this.vals[((4) * N + 0)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 0)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 0)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 0) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 0)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 0) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 0) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 0);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((4) * N + 0)]) { this.sel = ((4) * N + 0); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 0)]) {
        this.sel = ((4) * N + 0);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (0)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (0)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (0)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 1)] > 0 ? String(this.vals[((4) * N + 1)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 1)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 1)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 1) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 1)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 1) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 1) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 1);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((4) * N + 1)]) { this.sel = ((4) * N + 1); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 1)]) {
        this.sel = ((4) * N + 1);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (1)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (1)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (1)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 2)] > 0 ? String(this.vals[((4) * N + 2)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 2)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 2)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 2) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 2)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 2) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 2) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 2);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((4) * N + 2)]) { this.sel = ((4) * N + 2); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 2)]) {
        this.sel = ((4) * N + 2);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (2)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (2)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (2)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 3)] > 0 ? String(this.vals[((4) * N + 3)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 3)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 3)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 3) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 3)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 3) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 3) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 3);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((4) * N + 3)]) { this.sel = ((4) * N + 3); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 3)]) {
        this.sel = ((4) * N + 3);
        }
        })
        Text(this.hSign[((4)) * (N - 1) + (3)] === 1 ? '<' : (this.hSign[((4)) * (N - 1) + (3)] === 2 ? '>' : ''))
        .fontSize(FontSize.md)
        .fontColor(this.hSign[((4)) * (N - 1) + (3)] === 2 ? Palette.rose : Palette.emerald)
        .textAlign(TextAlign.Center)
        .width(SIGN_W)
        Stack() {
        Text(this.vals[((4) * N + 4)] > 0 ? String(this.vals[((4) * N + 4)]) : '')
        .fontSize(FontSize.xl)
        .fontWeight(this.given[((4) * N + 4)] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.given[((4) * N + 4)] ? this.theme.ink : Palette.primary)
        }
        .layoutWeight(1)
        .aspectRatio(1)
        .backgroundColor(this.sel === ((4) * N + 4) ? (this.theme.isDark ? '#2A2A44' : '#E0E7FF') :
        (this.given[((4) * N + 4)] ? this.theme.surface : this.theme.surfaceAlt))
        .borderRadius(Radius.xs)
        .scale({
        x: this.pressed === ((4) * N + 4) ? Motion.pressScale : 1,
        y: this.pressed === ((4) * N + 4) ? Motion.pressScale : 1
        })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
        this.pressed = ((4) * N + 4);
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = -1;
        }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (!this.over && !this.given[((4) * N + 4)]) { this.sel = ((4) * N + 4); } }); })
        .onClick(() => {
        Haptics.tick();
        if (!this.over && !this.given[((4) * N + 4)]) {
        this.sel = ((4) * N + 4);
        }
        })
        }
        .width('100%')
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4, 5], (d: number) => {
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.put((d)); }); })
          .onClick(() => {
          Haptics.tick();
          this.put((d));
          })
        }, (d: number) => 'fk' + d)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Text(this.hintMsg.length > 0 ? this.hintMsg : '')
          .fontSize(FontSize.xs)
          .fontColor(this.theme.inkSoft)
          .layoutWeight(2)
          .maxLines(2)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        // ★ 2026-10-29（lead 补）：演示时这个按钮显示「演示中…」
        //   它原来只认 autoId，演示跑起来界面上什么都看不见（14 款同类都有这层）
        Button(this.demoId >= 0 ? TG('演示中…') : (this.autoId >= 0 ? TG('停代打') : TG('AI 代打')))
          .layoutWeight(1)
          .height(44)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askAuto(); }); })
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.over ? (this.won ? '🎉 行列不重复且不等号全满足，通关！' : TG('步数用尽，重开一题吧')) :
        '点格子选中，再点下面数字填入；粗黑数字是题目提示')
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }





  @Builder
  gapBox() {
    Row() {
    }
    .width(SIGN_W)
  }










}
