/**
 * 3D 迷宫 —— 立体迷宫导航
 *
 * 玩法：一个 5×5×3 的立体迷宫，用方向键在水平面移动、用 ↑↓ 按钮换层。
 * 从起点走到终点即通关；步数越少得分越高。
 *
 * 原创实现（拾海 2026-10-10）。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const W = 5;          // 宽
const H = 5;          // 深
const L = 3;          // 层
const CELLS = W * H * L;

@Component
export struct GMazeNav3d {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：迷宫层数（简单 2 / 普通 3 / 困难 4）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.pick(2, 3, 4);
  onFinish: (r: GameResult) => void = () => {};

  @State private walls: number[] = [];     // 1 = 墙
  @State private px: number = 0;
  @State private py: number = 0;
  @State private pz: number = 0;
  @State private steps: number = 0;
  @State private done: boolean = false;
  @State private best: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMazeNav3d')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.pick(2, 3, 4);
    this.reset();
  }

  private idx(x: number, y: number, z: number): number {
    return z * W * H + y * W + x;
  }

  /** 用「随机挖通道」生成一个保证连通的迷宫 */
  private reset(): void {
    this.walls = new Array<number>(CELLS).fill(1);
    this.px = 0;
    this.py = 0;
    this.pz = 0;
    this.steps = 0;
    this.done = false;
    this.startAt = Date.now();

    // 每层挖一条随机游走的通路
    const w = this.walls.slice();
    for (let z = 0; z < this.diffTotal; z++) {
      let cx = 0;
      let cy = 0;
      w[this.idx(cx, cy, z)] = 0;
      for (let n = 0; n < 22; n++) {
        const d: number = Math.floor(Math.random() * 4);
        if (d === 0 && cx + 1 < W) {
          cx++;
        } else if (d === 1 && cx > 0) {
          cx--;
        } else if (d === 2 && cy + 1 < H) {
          cy++;
        } else if (d === 3 && cy > 0) {
          cy--;
        }
        w[this.idx(cx, cy, z)] = 0;
      }
      // 保证终点通
      w[this.idx(W - 1, H - 1, z)] = 0;
      w[this.idx(W - 2, H - 1, z)] = 0;
      w[this.idx(W - 1, H - 2, z)] = 0;
      // 层间通道
      if (z + 1 < this.diffTotal) {
        w[this.idx(cx, cy, z)] = 0;
        w[this.idx(cx, cy, z + 1)] = 0;
      }
    }
    this.walls = w;
  }

  private at(x: number, y: number, z: number): number {
    if (x < 0 || x >= W || y < 0 || y >= H || z < 0 || z >= this.diffTotal) {
      return 1;
    }
    return this.walls[this.idx(x, y, z)];
  }

  /** ★ 代打/提示共用：格子是不是墙（越界 / 数组越界都算墙 —— 困难档层数会超过常量 L） */
  private isWallCell(x: number, y: number, z: number): boolean {
    if (x < 0 || x >= W || y < 0 || y >= H || z < 0 || z >= this.diffTotal) {
      return true;
    }
    const i: number = z * W * H + y * W + x;
    if (i < 0 || i >= this.walls.length) {
      return true;
    }
    return this.walls[i] === 1;
  }

  /** 从当前位置到终点的一条最短路，返回首步 [dx, dy, dz]；走不通返回空 */
  private bfsStep(): number[] {
    const w: number = W;
    const h: number = H;
    const l: number = this.diffTotal;
    const total: number = w * h * l;
    if (total <= 0) {
      return [];
    }
    const st: number = this.pz * w * h + this.py * w + this.px;
    const goal: number = (l - 1) * w * h + (h - 1) * w + (w - 1);
    if (st === goal) {
      return [];
    }
    const prev: number[] = new Array<number>(total).fill(-2);
    const q: number[] = [];
    prev[st] = -1;
    q.push(st);
    let head: number = 0;
    while (head < q.length) {
      const cur: number = q[head];
      head = head + 1;
      if (cur === goal) {
        break;
      }
      const cz: number = Math.floor(cur / (w * h));
      const cy: number = Math.floor((cur - cz * w * h) / w);
      const cx: number = cur - cz * w * h - cy * w;
      const nx: number[] = [cx + 1, cx - 1, cx, cx, cx, cx];
      const ny: number[] = [cy, cy, cy + 1, cy - 1, cy, cy];
      const nz: number[] = [cz, cz, cz, cz, cz + 1, cz - 1];
      for (let k = 0; k < 6; k++) {
        if (this.isWallCell(nx[k], ny[k], nz[k])) {
          continue;
        }
        const ni: number = nz[k] * w * h + ny[k] * w + nx[k];
        if (prev[ni] !== -2) {
          continue;
        }
        prev[ni] = cur;
        q.push(ni);
      }
    }
    if (prev[goal] === -2) {
      return [];
    }
    let node: number = goal;
    let guard: number = 0;
    while (prev[node] !== -1 && prev[node] !== st && guard < total + 4) {
      guard = guard + 1;
      node = prev[node];
    }
    if (node === st) {
      return [];
    }
    const nz2: number = Math.floor(node / (w * h));
    const ny2: number = Math.floor((node - nz2 * w * h) / w);
    const nx2: number = node - nz2 * w * h - ny2 * w;
    return [nx2 - this.px, ny2 - this.py, nz2 - this.pz];
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    if (this.done) {
      return false;
    }
    const mv: number[] = this.bfsStep();
    if (mv.length < 3) {
      return false;
    }
    this.tryMove(mv[0], mv[1], mv[2]);
    return !this.done;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done) {
      return Hint.none('none');
    }
    const mv: number[] = this.bfsStep();
    if (mv.length < 3) {
      return Hint.none('none');
    }
    let dir: string = TG('上');
    if (mv[2] === 1) {
      dir = TG('上一层');
    } else if (mv[2] === -1) {
      dir = TG('下一层');
    } else if (mv[0] === 1) {
      dir = TG('右');
    } else if (mv[0] === -1) {
      dir = TG('左');
    } else if (mv[1] === 1) {
      dir = TG('下');
    }
    return Hint.make([],
      TG2('往{0}走一步 —— 终点在最深那层的右上角（共 {1} 层）', dir, this.diffTotal),
      TG2('Move {0} — the exit is on the deepest layer (of {1})', dir, this.diffTotal), t0);
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
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private tryMove(dx: number, dy: number, dz: number): void {
    if (this.done) {
      return;
    }
    const nx: number = this.px + dx;
    const ny: number = this.py + dy;
    const nz: number = this.pz + dz;
    if (this.at(nx, ny, nz) === 1) {
      return;
    }
    this.px = nx;
    this.py = ny;
    this.pz = nz;
    this.steps = this.steps + 1;
    if (nx === W - 1 && ny === H - 1 && nz === this.diffTotal - 1) {
      this.done = true;
      if (this.best === 0 || this.steps < this.best) {
        this.best = this.steps;
      }
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'maze_nav_3d', solved: true,
        score: Math.max(10, 400 - this.steps * 8),
        durationMs: Date.now() - this.startAt
      });
    }
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
      // 状态
      Row({ space: Space.lg }) {
        Column({ space: 2 }) {
        Text(Digits(String(this.steps), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text(((this.pz + 1) + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.violet))
        Text(('层')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text((this.best === 0 ? '—' : String(this.best))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        Text((TG('最好'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
      }
      .width('100%')

      Text(this.done ? '🎉 走通了！' : '走到右下角的 🏁 就算通关')
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)

      // 当前层的平面图
      Column({ space: 6 }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: 6 }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(this.px === (c) && this.py === (r)
              ? '🧍'
              : ((c) === W - 1 && (r) === H - 1
              ? '🏁'
              : (this.at((c), (r), this.pz) === 1 ? '🧱' : '')))
              .fontSize(FontSize.lg)   // ★ 2026-10-14 改用常量（原来硬编码 ⇒ 大字模式下不变）
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.at((c), (r), this.pz) === 1 ? this.theme.surface : this.theme.surfaceAlt)
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
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '70%' })
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      // 层切换
      Row({ space: Space.md }) {
        Button(TG('▼ 下层'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).layoutWeight(1).height(Cell.of(42))
          .backgroundColor(this.theme.surfaceAlt).fontColor(this.theme.ink)
          .borderRadius(Radius.sm)
          .enabled(this.pz > 0)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tryMove(0, 0, -1); }); })
          .onClick(() => {
            Haptics.tap();
            this.tryMove(0, 0, -1);
          })
        Button(TG('▲ 上层'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.sm).layoutWeight(1).height(Cell.of(42))
          .backgroundColor(this.theme.surfaceAlt).fontColor(this.theme.ink)
          .borderRadius(Radius.sm)
          .enabled(this.pz < this.diffTotal - 1)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tryMove(0, 0, 1); }); })
          .onClick(() => {
            Haptics.tap();
            this.tryMove(0, 0, 1);
          })
      }
      .width('100%')

      // 方向键
      Column({ space: Space.xs }) {
        Text(('↑'))
        .fontSize(FontSize.lg)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .width(64).height(Cell.of(40))
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.sm)
        .shadow(Shadow.card)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.tryMove((0), (-1), 0); }); })
        .onClick(() => {
        Haptics.tap();
        this.tryMove((0), (-1), 0);
        })
        Row({ space: Space.xs }) {
          Text(('←'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tryMove((-1), (0), 0); }); })
          .onClick(() => {
          Haptics.tick();
          this.tryMove((-1), (0), 0);
          })
          Text(('↓'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tryMove((0), (1), 0); }); })
          .onClick(() => {
          Haptics.tick();
          this.tryMove((0), (1), 0);
          })
          Text(('→'))
          .fontSize(FontSize.lg)
          .fontColor(this.theme.ink)
          .textAlign(TextAlign.Center)
          .width(64).height(Cell.of(40))
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tryMove((1), (0), 0); }); })
          .onClick(() => {
          Haptics.tick();
          this.tryMove((1), (0), 0);
          })
        }
      }
      .width('100%')

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .padding(Space.md)
  }






}
