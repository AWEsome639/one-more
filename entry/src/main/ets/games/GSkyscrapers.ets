/**
 * 数楼 skyscrapers（4×4）—— 每行每列 1~4 各一次；盘外数字是从那个方向能看见的楼数
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：拉丁方成立且四边提示全对 ⇒ solved:true；错手 5 次 ⇒ solved:false
 * 进度：已填格数 ／ 错手 ／ 当前选中的数字
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 4;
const CELLS: number = N * N;
const SIDE: number = N + 2;
const ERR_MAX: number = 5;

/** 3 关提示：[上 4][右 4][下 4][左 4]，都是唯一解的盘面 */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    2,3,2,1,
    1,2,3,3,
    1,2,3,3,
    2,3,2,1
  ],
  // 第 2 关
  [
    2,1,2,2,
    2,3,2,1,
    3,4,2,1,
    2,1,2,3
  ],
  // 第 3 关
  [
    3,3,2,1,
    1,2,3,2,
    1,2,3,2,
    3,3,2,1
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GSkyscrapers {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：原 ERR_MAX=5
  @State private diffTotal: number = GameDiff.livesNow(5);
  onFinish: (r: GameResult) => void = () => {};

  @State clues: number[] = [];
  @State grid: number[] = [];      // 0 = 空格
  /** ★ 2026-10-23 第二期：提示说的话（空 = 没提示） */
  @State hintMsg: string = '';
  @State hintIdx: number = -1;
  @State pick: number = 1;
  @State errors: number = 0;
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
    this.diffTotal = GameDiff.livesNow(5);
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.grid = new Array<number>(CELLS).fill(0);
    this.pick = 1;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private filledCount(): number {
    let n: number = 0;
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] > 0) {
        n++;
      }
    }
    return n;
  }

  /** 同行或同列已经有同样的数字 */
  private conflict(arr: number[], i: number): boolean {
    const r: number = Math.floor(i / N);
    const c: number = i % N;
    const v: number = arr[i];
    for (let k = 0; k < N; k++) {
      if (k !== c && arr[r * N + k] === v) {
        return true;
      }
      if (k !== r && arr[k * N + c] === v) {
        return true;
      }
    }
    return false;
  }

  private latinOk(): boolean {
    for (let i = 0; i < CELLS; i++) {
      if (this.grid[i] === 0) {
        return false;
      }
    }
    for (let r = 0; r < N; r++) {
      const seen: number[] = new Array<number>(N + 1).fill(0);
      for (let c = 0; c < N; c++) {
        const v: number = this.grid[r * N + c];
        if (seen[v] === 1) {
          return false;
        }
        seen[v] = 1;
      }
    }
    for (let c = 0; c < N; c++) {
      const seen: number[] = new Array<number>(N + 1).fill(0);
      for (let r = 0; r < N; r++) {
        const v: number = this.grid[r * N + c];
        if (seen[v] === 1) {
          return false;
        }
        seen[v] = 1;
      }
    }
    return true;
  }

  private seeCol(c: number, bottomUp: boolean): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < N; k++) {
      const r: number = bottomUp ? N - 1 - k : k;
      const v: number = this.grid[r * N + c];
      if (v === 0) {
        return 0;
      }
      if (v > mx) {
        mx = v;
        n++;
      }
    }
    return n;
  }

  private seeRow(r: number, rightToLeft: boolean): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < N; k++) {
      const c: number = rightToLeft ? N - 1 - k : k;
      const v: number = this.grid[r * N + c];
      if (v === 0) {
        return 0;
      }
      if (v > mx) {
        mx = v;
        n++;
      }
    }
    return n;
  }

  private cluesOk(): boolean {
    for (let c = 0; c < N; c++) {
      if (this.seeCol(c, false) !== this.clues[c]) {
        return false;
      }
      if (this.seeCol(c, true) !== this.clues[N * 2 + c]) {
        return false;
      }
    }
    for (let r = 0; r < N; r++) {
      if (this.seeRow(r, false) !== this.clues[N * 3 + r]) {
        return false;
      }
      if (this.seeRow(r, true) !== this.clues[N + r]) {
        return false;
      }
    }
    return true;
  }


  /** 视野数：给一条线（长度 N），从前往后看能看见几栋楼 */
  private sightOf(line: number[]): number {
    let mx: number = 0;
    let n: number = 0;
    for (let k = 0; k < line.length; k++) {
      if (line[k] > mx) {
        mx = line[k];
        n++;
      }
    }
    return n;
  }

  /** 生成 1..N 的全部排列（N=4 时 24 个） */
  private allPerms(): number[][] {
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
   * ★ 2026-10-23 第二期：数楼提示
   *
   * 规则：每行每列是 1..N 的一个排列，且两端线索 = 从那一端看过去的视野数。
   * ⇒ 可以逐行/逐列做「枚举所有符合线索与已填数字的排列，再求交集」：
   *    某格在所有候选里都相同的，就是确定的。
   *   N=4 时每行只有 24 个排列，毫秒级。
   *
   * ⚠️ 判断依据只用「线索 + 玩家已填」，不看题目答案。
   * 全部推不出 ⇒ Hint.none()（数楼确实有需要猜的局面）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const perms: number[][] = this.allPerms();
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < N; k++) {
        const marks: number[] = [];
        for (let i = 0; i < N; i++) {
          marks.push(horiz === 1 ? this.grid[k * N + i] : this.grid[i * N + k]);
        }
        const cA: number = horiz === 1 ? this.clues[N * 3 + k] : this.clues[k];
        const cB: number = horiz === 1 ? this.clues[N + k] : this.clues[N * 2 + k];
        let acc: number[] = [];
        let cnt: number = 0;
        for (let pi = 0; pi < perms.length; pi++) {
          const cand: number[] = perms[pi];
          // 与线索比
          if (this.sightOf(cand) !== cA) {
            continue;
          }
          const rev: number[] = [];
          for (let i = N - 1; i >= 0; i--) {
            rev.push(cand[i]);
          }
          if (this.sightOf(rev) !== cB) {
            continue;
          }
          // 与玩家已填比
          let ok: boolean = true;
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
    this.hintMsg = TG('这一步从线索推不出来，得试一个数看看');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const next: number[] = this.grid.slice();
    if (next[i] === this.pick) {
      next[i] = 0;                       // 同数字再点一次 = 清空
    } else {
      next[i] = this.pick;
      if (this.conflict(next, i)) {
        this.errors++;
      }
    }
    this.grid = next;
    if (this.errors >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
      return;
    }
    if (this.latinOk() && this.cluesOk()) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(100, 500 - this.errors * 60 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'skyscrapers',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.filledCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private isPlay(gr: number, gc: number): boolean {
    return gr >= 1 && gr <= N && gc >= 1 && gc <= N;
  }

  private skyText(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? '' : String(v);
    }
    if (gr === 0 && gc >= 1 && gc <= N) {
      return String(this.clues[gc - 1]);
    }
    if (gr === N + 1 && gc >= 1 && gc <= N) {
      return String(this.clues[N * 2 + gc - 1]);
    }
    if (gc === 0 && gr >= 1 && gr <= N) {
      return String(this.clues[N * 3 + gr - 1]);
    }
    if (gc === N + 1 && gr >= 1 && gr <= N) {
      return String(this.clues[N + gr - 1]);
    }
    return '';
  }

  private skyInk(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? this.theme.inkFaint : Palette.primaryDeep;
    }
    return Palette.sky;
  }

  private skyBg(gr: number, gc: number): string {
    if (this.isPlay(gr, gc)) {
      const v: number = this.grid[(gr - 1) * N + (gc - 1)];
      return v === 0 ? this.theme.surface : tintOf(Palette.primary, this.theme.isDark);
    }
    return this.theme.surfaceAlt;
  }

  private skyTap(gr: number, gc: number): void {
    if (this.isPlay(gr, gc)) {
      this.tap((gr - 1) * N + (gc - 1));
    }
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已填'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.filledCount()) + '/' + String(CELLS)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错手'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(this.diffTotal)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.xs)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('选中'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.pick), this.langCode))
        .fontSize(FontSize.md)
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

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5], (gr: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5], (gc: number) => {
              Stack() {
              Text(this.skyText((gr), (gc)))
              .fontSize(this.isPlay((gr), (gc)) ? FontSize.lg : FontSize.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.skyInk((gr), (gc)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.skyBg((gr), (gc)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.skyTap((gr), (gc));
              })
            }, (gc: number) => 'g' + gc)
          }
          .width('100%')
        }, (gr: number) => 'gr' + gr)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.sm }) {
        ForEach([1, 2, 3, 4], (v: number) => {
          Text(String(v))
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.pick === v ? '#FFFFFF' : this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(Cell.of(44))
            .backgroundColor(this.pick === v ? Palette.sky : this.theme.surface)
            .borderRadius(Radius.sm)
            .shadow(Shadow.card)
            .onClick(() => {
              Haptics.tick();
              this.pick = v;
            })
        }, (v: number) => 'p' + v)
      }
      .width('100%')

      Row({ space: Space.md }) {
        Text(this.over
          ? (this.won ? '楼数全对 🎉 得分 ' + String(this.score) : '错手太多，本局失败')
          : (this.hintMsg.length > 0 ? this.hintMsg : '先选数字，再点格子；同一个数字点两次即清空'))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
          .layoutWeight(1)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(Cell.of(44))
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.sky)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
