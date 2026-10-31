/**
 * 数织 nonogram（5×5）—— 按行/列数字涂格，涂出图案即通关
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：行列线索全部满足 ⇒ solved:true；错涂 3 次 ⇒ solved:false
 * 进度：错涂次数 ／ 已完成行 ／ 已完成列
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 5;
const ERR_MAX: number = 3;
const CLUE_W: number = 42;

/** 4 张 5×5 图案（1 = 涂黑）：心 / 菱形 / 箭 / 星 */
const NONO_ART: number[][] = [
  // 第 1 关
  [
    0,1,0,1,0,
    1,1,1,1,1,
    1,1,1,1,1,
    0,1,1,1,0,
    0,0,1,0,0
  ],
  // 第 2 关
  [
    0,0,1,0,0,
    0,1,1,1,0,
    1,1,1,1,1,
    0,1,1,1,0,
    0,0,1,0,0
  ],
  // 第 3 关
  [
    0,0,1,0,0,
    0,1,1,1,0,
    1,1,1,1,1,
    0,0,1,0,0,
    0,0,1,0,0
  ],
  // 第 4 关
  [
    0,0,1,0,0,
    0,1,0,1,0,
    1,1,1,1,1,
    1,1,1,1,1,
    0,1,0,1,0
  ]
];

/** 一行/一列的线索串（如 "1 2"）；整行全空记 "0" */
function clueOf(line: number[]): string {
  const parts: number[] = [];
  let run: number = 0;
  for (let i = 0; i < line.length; i++) {
    if (line[i] === 1) {
      run++;
    } else if (run > 0) {
      parts.push(run);
      run = 0;
    }
  }
  if (run > 0) {
    parts.push(run);
  }
  return parts.length === 0 ? '0' : parts.join(' ');
}

@Component
export struct GNonogram {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★ 2026-10-23 修「尺寸陷阱」第 19 个：
   *   NONO_ART 是手工画的 5×5 = 25 格，但 diffTotal = sizeNow(5)（4/5/7）
   *   ⇒ 简单档只取前 16 项、困难档 25..48 是 undefined（图案全丢）
   *   修法：棋盘固定 5×5，难度改到**容错次数**上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = 5;
  /** 本局的容错次数：简单 6 / 普通 3 / 困难 2 */
  @State private errMax: number = GNonogram.errNow();

  private static errNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 6;
    }
    if (d === 2) {
      return 2;
    }
    return 3;
  }

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State art: number[] = [];
  @State cells: number[] = [];   // 0 空 1 涂黑 2 打叉
  @State errors: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;
  /** ★ 第二期：提示指向的格子（-1 = 无） */
  @State private hintIdx: number = -1;
  /** ★ 提示说了什么（空 = 没提示） */
  @State private hintMsg: string = '';

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GNonogram')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.errMax = GNonogram.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * NONO_ART.length);
    this.art = NONO_ART[k].slice();
    this.cells = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.startAt = Date.now();
  }

  /** 取第 k 行/列的当前涂黑情况（horiz=true 为行） */
  private line(horiz: boolean, k: number): number[] {
    const out: number[] = [];
    for (let j = 0; j < this.diffTotal; j++) {
      const i: number = horiz ? k * this.diffTotal + j : j * this.diffTotal + k;
      out.push(this.cells[i] === 1 ? 1 : 0);
    }
    return out;
  }

  private artLine(horiz: boolean, k: number): number[] {
    const out: number[] = [];
    for (let j = 0; j < this.diffTotal; j++) {
      const i: number = horiz ? k * this.diffTotal + j : j * this.diffTotal + k;
      out.push(this.art[i]);
    }
    return out;
  }

  private lineOk(horiz: boolean, k: number): boolean {
    return clueOf(this.line(horiz, k)) === clueOf(this.artLine(horiz, k));
  }

  private doneCount(horiz: boolean): number {
    let n: number = 0;
    for (let k = 0; k < this.diffTotal; k++) {
      if (this.lineOk(horiz, k)) {
        n++;
      }
    }
    return n;
  }


  /** 线索数组（与 clueOf 同一个规则，只是返回数字） */
  private clueNums(line: number[]): number[] {
    const out: number[] = [];
    let run: number = 0;
    for (let i = 0; i < line.length; i++) {
      if (line[i] === 1) {
        run++;
      } else if (run > 0) {
        out.push(run);
        run = 0;
      }
    }
    if (run > 0) {
      out.push(run);
    }
    return out;
  }

  /** 一条线（长度 n）的线索串是否与实际涂黑情况一致 */
  private fitsClue(bits: number[], clues: number[]): boolean {
    const got: number[] = this.clueNums(bits);
    if (got.length !== clues.length) {
      return false;
    }
    for (let i = 0; i < got.length; i++) {
      if (got[i] !== clues[i]) {
        return false;
      }
    }
    return true;
  }

  /** 这个候选与玩家当前的标记是否矛盾（涂黑格必须涂黑；打叉格必须空） */
  private fitsMarks(bits: number[], marks: number[]): boolean {
    for (let i = 0; i < bits.length; i++) {
      if (marks[i] === 1 && bits[i] !== 1) {
        return false;
      }
      if (marks[i] === 2 && bits[i] !== 0) {
        return false;
      }
    }
    return true;
  }

  /**
   * ★★★ 2026-10-23 第二期：数织提示（严格逻辑，不猜）
   *
   * 原理：一条线的线索 + 玩家已经涂/叉的格子，往往能把某些格**唯一确定**：
   *   枚举这条线所有与线索相符、又不与玩家标记矛盾的排列；
   *   如果某一格在**每一个排列里**状态都一样，那它就是确定的。
   *   ⇒ 这就是人手玩数织时用的"这一格非涂不可"推理，只是算得比人快。
   *
   * ⚠️ 关键：**判断依据只用「线索 + 玩家标记」**，
   *    绝不用 art 直接看答案是 0 还是 1（那是作弊）。
   *    线索本身是从 art 算出来并显示给玩家的，所以用它是正当的。
   *
   * 线长 n ≤ 9 ⇒ 每行最多 2^9 = 512 个候选，18 条线也就几千次判断，毫秒级。
   * 所有线都推不出 ⇒ Hint.none()（数织确实有需要猜的情况）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    // 先看行，再看列（行的线索在人眼里更直观）
    for (let horiz = 1; horiz >= 0; horiz--) {
      for (let k = 0; k < n; k++) {
        const marks: number[] = this.line(horiz === 1, k);
        const clues: number[] = this.clueNums(this.artLine(horiz === 1, k));
        // 枚举 2^n 种候选
        const total: number = 1 << n;
        let acc: number[] = [];           // 所有合法候选的按位累积
        let cnt: number = 0;
        for (let mask = 0; mask < total; mask++) {
          const bits: number[] = [];
          for (let i = 0; i < n; i++) {
            bits.push((mask & (1 << i)) !== 0 ? 1 : 0);
          }
          if (!this.fitsClue(bits, clues) || !this.fitsMarks(bits, marks)) {
            continue;
          }
          if (cnt === 0) {
            acc = bits.slice();
          } else {
            for (let i = 0; i < n; i++) {
              if (acc[i] !== bits[i]) {
                acc[i] = -1;              // 该格在不同候选里不一致
              }
            }
          }
          cnt++;
        }
        if (cnt <= 1) {
          continue;                       // 没有候选或已唯一，没什么可推的
        }
        // 找第一个"确定但玩家还没正确标记"的格
        for (let i = 0; i < n; i++) {
          if (acc[i] < 0) {
            continue;
          }
          const want: number = acc[i] === 1 ? 1 : 2;   // 确定涂黑 → 1；确定空 → 2（打叉）
          if (marks[i] === want) {
            continue;                     // 玩家已经标对了
          }
          const idx: number = horiz === 1 ? k * n + i : i * n + k;
          const r: number = horiz === 1 ? k + 1 : i + 1;
          const c: number = horiz === 1 ? i + 1 : k + 1;
          if (want === 1) {
            return Hint.make([idx], TG2('第 {0} 行第 {1} 列一定涂黑', String(r), String(c)),
              TG2('Row {0}, column {1} must be filled', String(r), String(c)), t0);
          }
          return Hint.make([idx], TG2('第 {0} 行第 {1} 列一定留空', String(r), String(c)),
            TG2('Row {0}, column {1} must stay empty', String(r), String(c)), t0);
        }
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 提示驱动：computeHint 每次给出"下一格" ⇒ 照它点
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      // ★★ 2026-11-01：演示文案改用**游戏自己算出来的提示**（computeHint 的 zh）。
      //   原来这里写的是通用的「看清楚：这是第 N 步」，等于什么都没说；
      //   而每款游戏本来就知道"这一步该指哪里"，它的 zh 就是最好的演示文案。
      //   算不出来（预算超时/无解）时才退回通用文案。
      const hr: HintResult = this.computeHint();
      if (hr.ok && hr.zh.length > 0) {
        this.demoMsg = TG2('看这里：{0}', hr.zh);
      } else {
        this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      }
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

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
    this.hintMsg = TG('这一步纯靠线索推不出来，只能猜一格了');
    setTimeout(() => { this.hintMsg = ''; }, 4500);
  }

  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const next: number[] = this.cells.slice();
    next[i] = (next[i] + 1) % 3;      // 空 → 涂黑 → 打叉 → 空
    this.cells = next;
    const v: number = next[i];
    if (v === 1 && this.art[i] === 0) {
      this.errors++;
      const undo: number[] = this.cells.slice();
      undo[i] = 0;
      this.cells = undo;
      if (this.errors >= this.errMax) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    if (this.doneCount(true) === this.diffTotal && this.doneCount(false) === this.diffTotal) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(50, 320 - this.errors * 60 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'nonogram',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.doneCount(true) + this.doneCount(false)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('错涂'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.errors) + '/' + String(this.errMax)))
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
        Text((TG('已完成行'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneCount(true)) + '/' + String(this.diffTotal)))
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
        Text((TG('已完成列'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.doneCount(false)) + '/' + String(this.diffTotal)))
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
        // 列线索
        Row({ space: Space.xs }) {
          Text('').width(CLUE_W)
          ForEach(this.rowIdx(), (c: number) => {
            Text(clueOf(this.artLine(false, c)))
              .fontSize(FontSize.xxs)
              .fontColor(this.lineOk(false, c) ? Palette.emerald : this.theme.inkSoft)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
          }, (c: number) => 'tc' + c)
        }
        .width('100%')

        // 行线索 + 格子
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            Text(clueOf(this.artLine(true, r)))
              .fontSize(FontSize.xxs)
              .fontColor(this.lineOk(true, r) ? Palette.emerald : this.theme.inkSoft)
              .width(CLUE_W)
              .textAlign(TextAlign.Center)
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text(this.cells[(r * this.diffTotal + c)] === 2 ? '×' : '')
              .fontSize(FontSize.md)
              .fontColor(this.theme.inkFaint)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells[(r * this.diffTotal + c)] === 1 ? Palette.primaryDeep : this.theme.surface)
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
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
        Text(this.over
          ? (this.won ? '图案复原 🎉 得分 ' + String(this.score) : '错涂太多，本局失败')
          : (this.hintMsg.length > 0 ? this.hintMsg : '点格子：涂黑 → 打叉 → 清空'))
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.primaryDeep)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
