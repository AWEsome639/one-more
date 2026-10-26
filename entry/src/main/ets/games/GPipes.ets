/**
 * 管道 pipes（5×5）—— 点格子把管道转 90°，让所有接口对接、水不漏
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：所有开口两两对接 ⇒ solved:true；步数用完 ⇒ solved:false
 * 进度：已对接接口 ／ 已用步数 ／ 剩余步数
 *
 * 位掩码：1 上 ／ 2 右 ／ 4 下 ／ 8 左
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const STEP_BUDGET: number = 70;

/** 3 关初始状态（每格都是某个合法管件的一个旋转，必定可复原） */
const PIPE_LIB: number[][] = [
  // 第 1 关
  [
    1,2,10,7,2,
    10,8,12,15,12,
    11,7,7,2,4,
    2,2,15,10,4,
    8,10,14,10,8
  ],
  // 第 2 关
  [
    2,12,2,8,4,
    6,7,7,12,5,
    14,14,4,12,9,
    10,3,7,15,12,
    2,1,3,8,1
  ],
  // 第 3 关
  [
    1,8,3,6,2,
    12,11,15,11,8,
    9,9,10,3,14,
    10,3,15,1,10,
    4,2,1,2,3
  ]
];

/** 掩码(0~15) → 制表符画出的管件：下标即位掩码 1上 2右 4下 8左 */
const GLYPHS: string[] = [
  '·', '╵', '╶', '╰', '╷', '│', '╭', '├',
  '╴', '╯', '─', '┴', '╮', '┤', '┬', '┼'
];

@Component
export struct GPipes {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★ 2026-10-23 修「尺寸陷阱」第 17 个：
   *   PIPE_LIB 是手工画的 5×5 = 25 格，但 diffTotal = sizeNow(5)（4/5/7）
   *   ⇒ 简单档只取前 16 项、困难档 25..48 是 undefined（管道形状全乱）
   *   修法：棋盘固定 5×5，难度改到**步数预算**上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = 5;
  /** 本局的步数上限：简单 8 / 普通 5 / 困难 3 */
  @State private errMax: number = GPipes.errNow();

  private static errNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 8;
    }
    if (d === 2) {
      return 3;
    }
    return 5;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State pipeMask: number[] = [];
  @State steps: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';
  @State private hintIdx: number = -1;

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.errMax = GPipes.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * PIPE_LIB.length);
    this.pipeMask = PIPE_LIB[k].slice();
    this.steps = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  private ports(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      const m: number = this.pipeMask[i];
      if ((m & 1) !== 0) {
        n++;
      }
      if ((m & 2) !== 0) {
        n++;
      }
      if ((m & 4) !== 0) {
        n++;
      }
      if ((m & 8) !== 0) {
        n++;
      }
    }
    return n;
  }

  /** 某一侧的开口是否与邻居对接 */
  private sideOk(i: number, bit: number): boolean {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    if (bit === 1) {
      return r > 0 && (this.pipeMask[i - this.diffTotal] & 4) !== 0;
    }
    if (bit === 2) {
      return c < this.diffTotal - 1 && (this.pipeMask[i + 1] & 8) !== 0;
    }
    if (bit === 4) {
      return r < this.diffTotal - 1 && (this.pipeMask[i + this.diffTotal] & 1) !== 0;
    }
    return c > 0 && (this.pipeMask[i - 1] & 2) !== 0;
  }

  private matched(): number {
    let n: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      const m: number = this.pipeMask[i];
      if ((m & 1) !== 0 && this.sideOk(i, 1)) {
        n++;
      }
      if ((m & 2) !== 0 && this.sideOk(i, 2)) {
        n++;
      }
      if ((m & 4) !== 0 && this.sideOk(i, 4)) {
        n++;
      }
      if ((m & 8) !== 0 && this.sideOk(i, 8)) {
        n++;
      }
    }
    return n;
  }

  private cellOk(i: number): boolean {
    const m: number = this.pipeMask[i];
    if ((m & 1) !== 0 && !this.sideOk(i, 1)) {
      return false;
    }
    if ((m & 2) !== 0 && !this.sideOk(i, 2)) {
      return false;
    }
    if ((m & 4) !== 0 && !this.sideOk(i, 4)) {
      return false;
    }
    if ((m & 8) !== 0 && !this.sideOk(i, 8)) {
      return false;
    }
    return true;
  }


  /** 某个朝向（mask）下，这个格子的所有开孔是否都与邻居对接 */
  private maskAllOk(i: number, mask: number): boolean {
    const r: number = Math.floor(i / this.diffTotal);
    const c: number = i % this.diffTotal;
    if ((mask & 1) !== 0) {
      if (!(r > 0 && (this.pipeMask[i - this.diffTotal] & 4) !== 0)) {
        return false;
      }
    }
    if ((mask & 2) !== 0) {
      if (!(c < this.diffTotal - 1 && (this.pipeMask[i + 1] & 8) !== 0)) {
        return false;
      }
    }
    if ((mask & 4) !== 0) {
      if (!(r < this.diffTotal - 1 && (this.pipeMask[i + this.diffTotal] & 1) !== 0)) {
        return false;
      }
    }
    if ((mask & 8) !== 0) {
      if (!(c > 0 && (this.pipeMask[i - 1] & 2) !== 0)) {
        return false;
      }
    }
    return true;
  }

  /**
   * ★ 2026-10-23 第二期：管道提示
   *
   * 每个格子有 4 个朝向（旋转 90° 一次 = mask 循环左移一位）。
   * 如果某个格子**只有一种朝向能让它的所有开孔都对接**，
   * 那它就该转成那个朝向 —— 这就是一个确定步。
   *
   * ⚠️ 只做单格判定，不做全盘搜索：
   *    邻居也错时，这个格子可能 0 种朝向可行 ⇒ 跳过。
   *    **宁可少给，不给错。**
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const total: number = this.diffTotal * this.diffTotal;
    for (let i = 0; i < total; i++) {
      const cur: number = this.pipeMask[i];
      // 当前已经全对接 ⇒ 不用提示这一格
      if (this.maskAllOk(i, cur)) {
        continue;
      }
      let goodMask: number = -1;
      let goodCnt: number = 0;
      let m: number = cur;
      for (let k = 0; k < 4; k++) {
        if (this.maskAllOk(i, m)) {
          goodCnt++;
          goodMask = m;
        }
        m = ((m << 1) | (m >> 3)) & 15;
      }
      if (goodCnt !== 1 || goodMask === cur) {
        continue;
      }
      // 需要转几次
      let turns: number = 0;
      let t2: number = cur;
      for (let k = 0; k < 4; k++) {
        if (t2 === goodMask) {
          turns = k;
          break;
        }
        t2 = ((t2 << 1) | (t2 >> 3)) & 15;
      }
      if (turns === 0) {
        continue;
      }
      const r: number = Math.floor(i / this.diffTotal) + 1;
      const c: number = (i % this.diffTotal) + 1;
      return Hint.make([i],
        TG2('第 {0} 行第 {1} 列再转 {2} 次就对了', String(r), String(c), String(turns)),
        TG2('Row {0}, column {1}: rotate {2} more time(s)', String(r), String(c), String(turns)),
        t0);
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
    this.hintMsg = TG('这一步看不出来哪格是确定的，先转几个试试');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // computeHint 返回"该转哪一个水管"，转到没得转就说明通了
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const r: HintResult = this.computeHint();
    if (!r.ok || r.cells.length === 0) {
      return false;
    }
    this.tap(r.cells[0]);
    return !this.over;
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
    if (this.over) {
      return;
    }
    const next: number[] = this.pipeMask.slice();
    next[i] = ((next[i] << 1) | (next[i] >> 3)) & 15;   // 顺时针 90°
    this.pipeMask = next;
    this.steps++;
    if (this.matched() === this.ports()) {
      this.over = true;
      this.won = true;
      this.score = Math.max(80, 520 - this.steps * 4);
      this.finish(true);
      return;
    }
    if (this.steps >= this.errMax) {
      this.over = true;
      this.won = false;
      this.score = 0;
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'pipes',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.matched()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已对接'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.matched()) + '/' + String(this.ports())))
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
        Text((TG('已用步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.steps) + '/' + String(this.errMax)))
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
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.max(0, this.errMax - this.steps))))
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

      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(GLYPHS[this.pipeMask[(r * this.diffTotal + c)]])
              .fontSize(FontSize.xxl)
              .fontColor(this.cellOk((r * this.diffTotal + c)) ? Palette.emerald : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellOk((r * this.diffTotal + c)) ? (this.theme.isDark ? '#0E2A22' : '#ECFDF5') : this.theme.surface)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.hintMsg.length > 0 ? this.hintMsg : (this.over
          ? (this.won ? '水路全通 🎉 得分 ' + String(this.score) : TG('步数用尽，本局失败'))
          : '点格子旋转管道，绿色表示这一格接口都接上了'))
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
          .backgroundColor(Palette.teal)
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
