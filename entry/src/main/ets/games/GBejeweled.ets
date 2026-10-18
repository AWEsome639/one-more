/**
 * 宝石迷阵 —— 交换相邻宝石，凑出三个以上同色即消除
 *
 * 玩法：点一颗宝石 → 点它上下左右相邻的一颗 ⇒ 交换；换出三连就消，消完上面的会掉下来接着连消
 * 胜负：MOVE_LIMIT 步内达到 TARGET 分 ⇒ solved=true；步数用完没到 ⇒ solved=false
 * 坐标口径：整盘在 7×7 网格里，格子用 layoutWeight(1) 均分，视觉与机型无关
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 7;               // 盘面边长
const KINDS: number = 5;           // 宝石种类
const MOVE_LIMIT: number = 20;     // 步数上限
const TARGET: number = 600;        // 通关分数线
const PER_GEM: number = 10;        // 每消一颗的分

const GEMS: string[] = ['💎', '🔥', '🍀', '🔮', '💧'];
const GEM_COLORS: string[] = [
  Palette.sky, Palette.orange, Palette.emerald, Palette.violet, Palette.primary
];

/** 0..n-1 下标数组（给 ForEach 用，只建一次） */
function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GBejeweled {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private board: number[] = [];
  @State private sel: number = -1;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(MOVE_LIMIT);
  @State private left: number = 0;
  @State private msg: string = TG('点一颗宝石，再点它相邻的一颗');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.total = GameDiff.timeNow(MOVE_LIMIT);
    this.reset();
  }

  private idx(r: number, c: number): number {
    return r * N + c;
  }

  private reset(): void {
    this.board = this.fill();
    this.sel = -1;
    this.score = 0;
    this.left = this.total;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点一颗宝石，再点它相邻的一颗');
    this.startAt = Date.now();
  }

  /** 开局盘面：随机填，且保证开局没有现成三连 */
  private fill(): number[] {
    let b: number[] = new Array<number>(N * N).fill(0);
    for (let i = 0; i < b.length; i++) {
      b[i] = Math.floor(Math.random() * KINDS);
    }
    for (let t = 0; t < 80; t++) {
      const m: number[] = this.mark(b);
      let again: boolean = false;
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = Math.floor(Math.random() * KINDS);
          again = true;
        }
      }
      if (!again) {
        break;
      }
    }
    return b;
  }

  /** 标记所有已成三连及以上的格子（1 = 要消） */
  private mark(b: number[]): number[] {
    const m: number[] = new Array<number>(N * N).fill(0);
    for (let r = 0; r < N; r++) {
      let run: number = 1;
      for (let c = 1; c <= N; c++) {
        const same: boolean = c < N && b[this.idx(r, c)] === b[this.idx(r, c - 1)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = c - run; k < c; k++) {
              m[this.idx(r, k)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    for (let c = 0; c < N; c++) {
      let run: number = 1;
      for (let r = 1; r <= N; r++) {
        const same: boolean = r < N && b[this.idx(r, c)] === b[this.idx(r - 1, c)];
        if (same) {
          run++;
        } else {
          if (run >= 3) {
            for (let k = r - run; k < r; k++) {
              m[this.idx(k, c)] = 1;
            }
          }
          run = 1;
        }
      }
    }
    return m;
  }

  private hasMark(b: number[]): boolean {
    const m: number[] = this.mark(b);
    for (let i = 0; i < m.length; i++) {
      if (m[i] === 1) {
        return true;
      }
    }
    return false;
  }

  /** 消掉空格后向下压实，顶上补新宝石（原地改 b） */
  private settle(b: number[]): void {
    for (let c = 0; c < N; c++) {
      let write: number = N - 1;
      for (let r = N - 1; r >= 0; r--) {
        const v: number = b[this.idx(r, c)];
        if (v >= 0) {
          b[this.idx(write, c)] = v;
          if (write !== r) {
            b[this.idx(r, c)] = -1;
          }
          write--;
        }
      }
      for (let r = write; r >= 0; r--) {
        b[this.idx(r, c)] = Math.floor(Math.random() * KINDS);
      }
    }
  }

  /** 反复消除直到没有三连；返回本次连消总分（含 combo 加成） */
  private resolve(): number {
    let gained: number = 0;
    let combo: number = 1;
    while (combo <= 30) {          // 上限兜底：连消不会无限，但绝不让自己卡死
      const b: number[] = this.board.slice();
      const m: number[] = this.mark(b);
      let cnt: number = 0;
      for (let i = 0; i < m.length; i++) {
        if (m[i] === 1) {
          cnt++;
        }
      }
      if (cnt === 0) {
        break;
      }
      for (let i = 0; i < b.length; i++) {
        if (m[i] === 1) {
          b[i] = -1;
        }
      }
      this.settle(b);
      this.board = b;
      gained += cnt * PER_GEM * combo;
      combo++;
    }
    return gained;
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
    if (this.sel < 0) {
      this.sel = i;
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      return;
    }
    if (!this.adjacent(this.sel, i)) {
      this.sel = i;
      return;
    }

    const a: number = this.sel;
    const nb: number[] = this.board.slice();
    const t: number = nb[a];
    nb[a] = nb[i];
    nb[i] = t;

    if (!this.hasMark(nb)) {
      this.sel = i;
      this.msg = TG('这样换不出三连，换一颗试试');
      return;
    }

    this.board = nb;
    this.sel = -1;
    this.left--;
    const gained: number = this.resolve();
    this.score += gained; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.msg = TG2("消除 +{0} 分", gained);
    if (this.left <= 0) {
      this.end();
    }
  }

  private end(): void {
    this.over = true;
    this.won = this.score >= TARGET;
    this.msg = this.won ? '🎉 达标！' : '步数用完，差一点';
    this.finish(this.won);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'bejeweled',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: MOVE_LIMIT - this.left
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(TARGET), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.left), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
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
              Text(GEMS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
              .fontSize(FontSize.xl)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(GEM_COLORS[this.board.length > (this.idx(r, c)) ? this.board[(this.idx(r, c))] : 0])
              .borderRadius(Radius.sm)
              .scale({
              x: this.sel === (this.idx(r, c)) ? 1.14 : 1,
              y: this.sel === (this.idx(r, c)) ? 1.14 : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
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
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .onClick(() => {
            this.reset();
          })
        Button(TG('取消选择'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(46))
          .enabled(!this.over)
          .onClick(() => {
            this.sel = -1;
          })
      }
      .width('100%')

      Text(TG2('每消一颗 +{0}，连消翻倍；{1} 步内拿到 {2} 分算通关',Digits(String(PER_GEM), this.langCode),Digits(String(MOVE_LIMIT), this.langCode),Digits(String(TARGET), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
