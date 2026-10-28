/**
 * 皇冠（Star Battle）👑
 *
 * 规则：每行、每列、每个同色分区里各放**恰好一个**皇冠；
 *       任意两个皇冠不能相邻（上下左右与斜角都不行）。
 * 胜负：皇冠放满且所有约束满足 = 通关；步数用尽 = 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
// ★ 提示用 toast 显示 —— 这款没有状态栏，加 Text 会挤坏布局
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 6;
const MAX_MOVES: number = 120;
const TINTS: string[] = ['#FEF3C7', '#DBEAFE', '#DCFCE7', '#FCE7F3', '#EDE9FE', '#CFFAFE'];
const TINTS_DARK: string[] = ['#3F3417', '#16304D', '#14361F', '#43172C', '#2A1F4D', '#0E3A42'];

function shuffleArr(a: number[]): void {
  for (let i = a.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = a[i];
    a[i] = a[j];
    a[j] = t;
  }
}

/** 解：每行一个列号，相邻两行的列号至少差 2（避免斜角相邻） */
function crownPlace(r: number, used: boolean[], cur: number[]): boolean {
  if (r === N) {
    return true;
  }
  const cand: number[] = [];
  for (let c = 0; c < N; c++) {
    if (used[c]) {
      continue;
    }
    if (r > 0 && Math.abs(c - cur[r - 1]) < 2) {
      continue;
    }
    cand.push(c);
  }
  shuffleArr(cand);
  for (let k = 0; k < cand.length; k++) {
    const c: number = cand[k];
    used[c] = true;
    cur.push(c);
    if (crownPlace(r + 1, used, cur)) {
      return true;
    }
    cur.splice(cur.length - 1, 1);
    used[c] = false;
  }
  return false;
}

/** 从 6 个解格出发随机长分区，保证每个分区恰好含一个解格 */
function crownRegions(perm: number[]): number[] {
  const reg: number[] = new Array<number>(N * N).fill(-1);
  for (let r = 0; r < N; r++) {
    reg[r * N + perm[r]] = r;
  }
  let left: number = N * N - N;
  let guard: number = 0;
  while (left > 0 && guard < 600) {
    guard++;
    const order: number[] = [0, 1, 2, 3, 4, 5];
    shuffleArr(order);
    let grew: boolean = false;
    for (let k = 0; k < N; k++) {
      const id: number = order[k];
      const nb: number[] = [];
      for (let i = 0; i < N * N; i++) {
        if (reg[i] !== id) {
          continue;
        }
        const r: number = Math.floor(i / N);
        const c: number = i - r * N;
        if (c > 0 && reg[i - 1] === -1) {
          nb.push(i - 1);
        }
        if (c < N - 1 && reg[i + 1] === -1) {
          nb.push(i + 1);
        }
        if (r > 0 && reg[i - N] === -1) {
          nb.push(i - N);
        }
        if (r < N - 1 && reg[i + N] === -1) {
          nb.push(i + N);
        }
      }
      if (nb.length > 0) {
        const pick: number = nb[Math.floor(Math.random() * nb.length)];
        reg[pick] = id;
        left--;
        grew = true;
      }
    }
    if (!grew) {
      break;
    }
  }
  return reg;
}

@Component
export struct GCrown {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MAX_MOVES 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MAX_MOVES);
  onFinish: (r: GameResult) => void = () => {};

  @State private reg: number[] = [];
  @State private marks: number[] = [];   // 0 空 / 1 皇冠 / 2 排除
  @State private mode: number = 1;
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private pressed: number = -1;

  private startAt: number = 0;
  /** 生成时用的解：每行一个列号（reset() 里存下来，代打照它放） */
  private sol: number[] = [];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MAX_MOVES);
    this.reset();
  }

  private reset(): void {
    const used: boolean[] = new Array<boolean>(N).fill(false);
    const perm: number[] = [];
    if (!crownPlace(0, used, perm)) {
      perm.splice(0, perm.length, 0, 2, 4, 1, 3, 5);
    }
    this.reg = crownRegions(perm);
    this.sol = perm.slice();
    for (let i = 0; i < N * N; i++) {
      if (this.reg[i] < 0 || this.reg[i] >= N) {
        this.reg[i] = 0;   // 兜底：BFS 万一没铺满也不至于取到非法下标
      }
    }
    this.marks = new Array<number>(N * N).fill(0);
    this.mode = 1;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.pressed = -1;
    this.startAt = Date.now();
  }

  private crownCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.marks.length; i++) {
      if (this.marks[i] === 1) {
        n++;
      }
    }
    return n;
  }

  /** 冲突计数：同一行/列/分区多放的，以及相邻的皇冠 */
  private conflicts(): number {
    let bad: number = 0;
    for (let r = 0; r < N; r++) {
      let n: number = 0;
      for (let c = 0; c < N; c++) {
        if (this.marks[r * N + c] === 1) {
          n++;
        }
      }
      if (n > 1) {
        bad += n - 1;
      }
    }
    for (let c = 0; c < N; c++) {
      let n: number = 0;
      for (let r = 0; r < N; r++) {
        if (this.marks[r * N + c] === 1) {
          n++;
        }
      }
      if (n > 1) {
        bad += n - 1;
      }
    }
    for (let g = 0; g < N; g++) {
      let n: number = 0;
      for (let i = 0; i < N * N; i++) {
        if (this.reg[i] === g && this.marks[i] === 1) {
          n++;
        }
      }
      if (n > 1) {
        bad += n - 1;
      }
    }
    for (let i = 0; i < N * N; i++) {
      if (this.marks[i] !== 1) {
        continue;
      }
      const r: number = Math.floor(i / N);
      const c: number = i - r * N;
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          if (dr === 0 && dc === 0) {
            continue;
          }
          const r2: number = r + dr;
          const c2: number = c + dc;
          if (r2 >= 0 && r2 < N && c2 >= 0 && c2 < N && this.marks[r2 * N + c2] === 1) {
            bad++;
          }
        }
      }
    }
    return Math.floor(bad / 2);
  }

  private isSolved(): boolean {
    if (this.crownCount() !== N || this.conflicts() !== 0) {
      return false;
    }
    for (let r = 0; r < N; r++) {
      let n: number = 0;
      for (let c = 0; c < N; c++) {
        if (this.marks[r * N + c] === 1) {
          n++;
        }
      }
      if (n !== 1) {
        return false;
      }
    }
    for (let c = 0; c < N; c++) {
      let n: number = 0;
      for (let r = 0; r < N; r++) {
        if (this.marks[r * N + c] === 1) {
          n++;
        }
      }
      if (n !== 1) {
        return false;
      }
    }
    for (let g = 0; g < N; g++) {
      let n: number = 0;
      for (let i = 0; i < N * N; i++) {
        if (this.reg[i] === g && this.marks[i] === 1) {
          n++;
        }
      }
      if (n !== 1) {
        return false;
      }
    }
    return true;
  }


  /**
   * ★ 2026-10-23 第二期：皇冠提示
   *
   * 规则：每一行 / 每一列 / 每个色区各一个皇冠，且皇冠不能相邻（含斜向）。
   * 用的局部规则：
   *   某个色区里**只有一个格子还没被排除** ⇒ 那一格必须是皇冠。
   *  （这个推理不依赖相邻约束，所以永远成立；宁可少给。）
   *
   * ⚠️ 这款没有状态栏。提示走 **toast** 显示 ——
   *    上一轮的教训：往已有 Row 里插 width('100%') 的 Text 会把按钮挤没。
   *    toast 完全不动布局，最安全。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    // 统计每个色区：还剩几个"可能放皇冠"的格（marks === 0）
    const regions: number = N;
    for (let rg = 0; rg < regions; rg++) {
      let free: number = 0;
      let freeIdx: number = -1;
      let hasCrown: boolean = false;
      for (let i = 0; i < N * N; i++) {
        if (this.reg[i] !== rg) {
          continue;
        }
        if (this.marks[i] === 1) {
          hasCrown = true;
        } else if (this.marks[i] === 0) {
          free++;
          freeIdx = i;
        }
      }
      if (hasCrown || free !== 1 || freeIdx < 0) {
        continue;
      }
      const r: number = Math.floor(freeIdx / N) + 1;
      const c: number = (freeIdx % N) + 1;
      return Hint.make([freeIdx],
        TG2('第 {0} 行第 {1} 列是这个色区唯一还没排除的格子 ⇒ 必须是皇冠', String(r), String(c)),
        TG2('Row {0}, column {1} is the only cell left in its region — it must be a crown',
          String(r), String(c)), t0);
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    // ★ 2026-10-23：改用框架里的 Hint.toast —— 不再每个游戏各写一份 try/catch
    Hint.toastResult(r, TG('这一步看不出哪格必须放皇冠，先把明显的排除掉'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：reset() 生成分区时就把「每行一个列号」的解存进了 this.sol
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
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
    if (this.sol.length !== N) {
      return false;
    }
    const keep: number = this.mode;      // tap 按 mode 取反 ⇒ 强制用「放皇冠」模式
    for (let r = 0; r < N; r++) {
      const i: number = r * N + this.sol[r];
      for (let c = 0; c < N; c++) {
        const j: number = r * N + c;
        if (this.marks[j] === 1 && j !== i) {
          this.mode = 1;
          this.tap(j);                   // 先清掉玩家放错的皇冠
          this.mode = keep;
          return !this.over;
        }
      }
    }
    for (let r = 0; r < N; r++) {
      const i: number = r * N + this.sol[r];
      if (this.marks[i] !== 1) {
        this.mode = 1;
        this.tap(i);
        this.mode = keep;
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
    if (this.over) {
      return;
    }
    const m: number[] = this.marks.slice();
    m[i] = m[i] === this.mode ? 0 : this.mode;
    this.marks = m;
    this.moves++;
    if (this.isSolved()) {
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
      gameId: 'crown',
      solved: solved,
      score: solved ? Math.max(200, 1400 - this.moves * 10) : this.crownCount() * 60,
      durationMs: Date.now() - this.startAt,
      levelReached: this.crownCount()
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('皇冠'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.crownCount()) + '/' + String(N)))
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
        Text((TG('冲突'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.conflicts())))
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

      Column({ space: 1 }) {
        ForEach([0, 1, 2, 3, 4, 5], (r: number) => {
          Row({ space: 1 }) {
            ForEach([0, 1, 2, 3, 4, 5], (c: number) => {
              Stack() {
              Text(this.marks[(r * N + c)] === 1 ? '👑' : (this.marks[(r * N + c)] === 2 ? '✕' : ''))
              .fontSize(FontSize.lg)
              .fontColor(this.theme.inkSoft)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.theme.isDark ? TINTS_DARK[this.reg[(r * N + c)]] : TINTS[this.reg[(r * N + c)]])
              .borderRadius(Radius.xs)
              .scale({
              x: this.pressed === (r * N + c) ? Motion.pressScale : 1,
              y: this.pressed === (r * N + c) ? Motion.pressScale : 1
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onTouch((e: TouchEvent) => {
              if (e.type === TouchType.Down) {
              this.pressed = (r * N + c);
              } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
              this.pressed = -1;
              }
              })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * N + c));
              })
            }, (c: number) => 'cr' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'crw' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Row({ space: Space.sm }) {
        Text((TG('👑 放皇冠')))
        .fontSize(FontSize.sm)
        .fontColor(this.mode === (1) ? '#FFFFFF' : this.theme.inkSoft)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(44))
        .backgroundColor(this.mode === (1) ? Palette.teal : this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.mode = (1);
        })
        Text((TG('✕ 标排除')))
        .fontSize(FontSize.sm)
        .fontColor(this.mode === (2) ? '#FFFFFF' : this.theme.inkSoft)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(44))
        .backgroundColor(this.mode === (2) ? Palette.teal : this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        .onClick(() => {
        Haptics.tick();
        this.mode = (2);
        })
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(88)
          .height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.over ? (this.won ? '🎉 每行每列每区各一冠，通关！' : TG('步数用尽，重开一题吧')) :
        '同色 = 同一分区；行/列/分区各一个皇冠，且互不相邻')
        .fontSize(FontSize.xs)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
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
