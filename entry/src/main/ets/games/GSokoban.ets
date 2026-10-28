/**
 * 推箱子 —— 箱子只能推、不能拉，把所有箱子推到目标点
 *
 * 关卡：4 关**手写地图**（字符串画图），难度递进，全部用 BFS 验过有解：
 *   `#`墙  `@`人  `$`箱  `.`目标  `*`箱在目标  `+`人在目标  空格=地板
 *   L1 最优 7 步 / L2 最优 9 步 / L3 最优 16 步 / L4 最优 24 步（步数含走动与推动）
 *
 * 交互：方向键（带按下反馈）+ 棋盘四向滑动；可撤销、可切上一关/下一关
 * 通关：所有箱子都在目标点上 ⇒ 本关过关，可继续下一关
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

/** 一个关卡：名字 + 一句话提示 + 地图 */
interface Level {
  name: string;
  hint: string;
  rows: string[];
}

/** 一步之前的状态快照（撤销用） */
interface Snap {
  player: number;
  boxes: boolean[];
  moves: number;
  pushes: number;
}

/** 滑动判定阈值（vp）：一次滑动至少这么多才认一个方向（P9：慢拖也要能推箱子） */
const DRAG_MIN: number = 18;

const LEVELS: Level[] = [
  {
    name: '第 1 关 · 一步一推',
    hint: '人站到箱子对面，才能把它推过去',
    rows: [
      '########',
      '#      #',
      '# .  $ #',
      '#  @   #',
      '########'
    ]
  },
  {
    name: '第 2 关 · 双子星',
    hint: '两个箱子各归各位，先想好路线再推',
    rows: [
      '#########',
      '#       #',
      '#  $ $  #',
      '#  . .  #',
      '#   @   #',
      '#########'
    ]
  },
  {
    name: '第 3 关 · 隔墙绕行',
    hint: '中间那堵墙挡住了直线，绕开它',
    rows: [
      '###########',
      '#         #',
      '#  $  $   #',
      '#   ##    #',
      '#  .  .   #',
      '#    @    #',
      '###########'
    ]
  },
  {
    name: '第 4 关 · 柱子挡路',
    hint: '箱子正上方是墙 ⇒ 先横推一格，再往下推',
    rows: [
      '##########',
      '#        #',
      '#  #  #  #',
      '#  $  $  #',
      '#  .  .  #',
      '#   @    #',
      '##########'
    ]
  }
];

const MAX_UNDO: number = 300;

@Component
export struct GSokoban {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 MAX_UNDO=300
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(300);
  /** ★★ 2026-10-14 滑行（奥森：部分游戏应该有动态的运动过程）：
   *  玩家与箱子【各自】从「来处」方向滑到新格子 */
  @State private slideP: number = -1;   // 玩家移到的格子
  @State private slideB: number = -1;   // 箱子移到的格子
  @State private slideDX: number = 0;
  @State private slideDY: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State level: number = 0;
  @State walls: boolean[] = [];
  @State goals: boolean[] = [];
  @State boxes: boolean[] = [];
  @State player: number = 0;
  @State w: number = 0;
  @State h: number = 0;
  @State moves: number = 0;
  @State pushes: number = 0;
  @State cleared: boolean[] = [];
  @State solvedNow: boolean = false;
  @State pressed: string = '';
  @State blocked: number = 0;      // 撞墙次数，用于提示
  @State rowList: number[] = [];
  @State colList: number[] = [];

  private history: Snap[] = [];
  private startAt: number = 0;
  /** ★ 滑动起点（vp）：每认一次方向就重置，一次滑动能连着推两格 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    const c: boolean[] = [];
    for (let i = 0; i < LEVELS.length; i++) {
      c.push(false);
    }
    this.cleared = c;
    this.load(0);
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(300);
    this.cleared = this.cleared.map(() => false);
    this.load(0);
  }

  /** 载入第 idx 关 */
  /** ★ 2026-10-29：演示动画需要「演完重来」⇒ 包一个无参 reset()
   *  这款没有"当前关卡"字段（一直是 load(0)），所以重来就是重新载入第 0 关 */
  private reset(): void {
    this.load(0);
  }

  private load(idx: number): void {
    const lv: Level = LEVELS[idx];
    const rows: string[] = lv.rows;
    const w: number = rows[0].length;
    const h: number = rows.length;
    const walls: boolean[] = new Array<boolean>(w * h).fill(false);
    const goals: boolean[] = new Array<boolean>(w * h).fill(false);
    const boxes: boolean[] = new Array<boolean>(w * h).fill(false);
    let player: number = 0;
    for (let y = 0; y < h; y++) {
      const line: string = rows[y];
      for (let x = 0; x < w; x++) {
        const ch: string = line.charAt(x);
        const i: number = y * w + x;
        if (ch === '#') {
          walls[i] = true;
        }
        if (ch === '.' || ch === '*' || ch === '+') {
          goals[i] = true;
        }
        if (ch === '$' || ch === '*') {
          boxes[i] = true;
        }
        if (ch === '@' || ch === '+') {
          player = i;
        }
      }
    }
    this.level = idx;
    this.w = w;
    this.h = h;
    const rs: number[] = [];
    const cs: number[] = [];
    for (let y = 0; y < h; y++) {
      rs.push(y);
    }
    for (let x = 0; x < w; x++) {
      cs.push(x);
    }
    this.rowList = rs;
    this.colList = cs;
    this.walls = walls;
    this.goals = goals;
    this.boxes = boxes;
    this.player = player;
    this.moves = 0;
    this.pushes = 0;
    this.blocked = 0;
    this.solvedNow = false;
    this.pressed = '';
    this.history = [];
    this.startAt = Date.now();
  }

  /** 推一步：dx/dy 是人的移动方向 */
  private step(dx: number, dy: number): void {
    if (this.solvedNow) {
      return;
    }
    const w: number = this.w;
    const h: number = this.h;
    const x: number = this.player % w;
    const y: number = Math.floor(this.player / w);
    const nx: number = x + dx;
    const ny: number = y + dy;
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) {
      return;
    }
    const ni: number = ny * w + nx;
    if (this.walls[ni]) {
      this.blocked++;
      return;
    }

    const boxes: boolean[] = this.boxes.slice();
    let pushed: boolean = false;
    let boxTo: number = -1;   // ★ 箱子移到的格子（bi 是块级作用域，要接出来）
    if (boxes[ni]) {
      const bx: number = nx + dx;
      const by: number = ny + dy;
      if (bx < 0 || by < 0 || bx >= w || by >= h) {
        this.blocked++;
        return;
      }
      const bi: number = by * w + bx;
      boxTo = bi;
      if (this.walls[bi] || boxes[bi]) {
        this.blocked++;     // 箱子后面是墙或另一个箱子 ⇒ 推不动
        return;
      }
      boxes[ni] = false;
      boxes[bi] = true;
      pushed = true;
    }

    // 记快照（撤销用）
    const snap: Snap = {
      player: this.player,
      boxes: this.boxes.slice(),
      moves: this.moves,
      pushes: this.pushes
    };
    this.history.push(snap);
    if (this.history.length > this.diffTotal) {
      this.history.splice(0, 1);
    }

    this.boxes = boxes;
    this.player = ni;
    this.moves++;
    // ★★ 2026-10-14 滑行：玩家与箱子各自从「来处」滑到新格子
    const OFF: number = 12;
    this.slideP = ni;
    this.slideDX = -dx * OFF;
    this.slideDY = -dy * OFF;
    if (pushed) { this.slideB = boxTo; }
    setTimeout(() => { this.slideDX = 0; this.slideDY = 0; }, 16);
    if (pushed) {
      this.pushes++;
    }

    if (this.allOnGoal(boxes)) {
      this.solvedNow = true;
      const done: boolean[] = this.cleared.slice();
      done[this.level] = true;
      this.cleared = done;
      this.finish(true);
    }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 没有"答案字段"—— BFS 搜一条把箱子推上目标的走法，然后一格一格照着走
  private aiPlan: number[] = [];
  private aiPlanKey: string = '';

  /** 局面指纹：人站哪儿 + 哪些格子有箱子（箱子互不区分，不用排序） */
  private aiKeyOf(p: number, bs: boolean[]): string {
    let s: string = String(p) + ':';
    for (let i = 0; i < bs.length; i++) {
      if (bs[i]) {
        s = s + ',' + String(i);
      }
    }
    return s;
  }

  private aiKey(): string {
    return this.aiKeyOf(this.player, this.boxes);
  }

  /** BFS 求一条走法：方向序列（0 上 1 右 2 下 3 左），空数组 = 算不出来 */
  private aiSolve(): number[] {
    const w: number = this.w;
    const h: number = this.h;
    const dxs: number[] = [0, 1, 0, -1];
    const dys: number[] = [-1, 0, 1, 0];
    const qp: number[] = [this.player];
    const qb: boolean[][] = [this.boxes.slice()];
    const par: number[] = [-1];
    const mvs: number[] = [-1];
    const seen: Map<string, number> = new Map<string, number>();
    seen.set(this.aiKey(), 0);
    let head: number = 0;
    let winAt: number = -1;
    while (head < qp.length && winAt < 0 && qp.length < 20000) {
      const p: number = qp[head];
      const bs: boolean[] = qb[head];
      if (this.allOnGoal(bs)) {
        winAt = head;
        break;
      }
      const px: number = p % w;
      const py: number = Math.floor(p / w);
      for (let d = 0; d < 4; d++) {
        const nx: number = px + dxs[d];
        const ny: number = py + dys[d];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) {
          continue;
        }
        const ni: number = ny * w + nx;
        if (this.walls[ni]) {
          continue;
        }
        const nbs: boolean[] = bs.slice();
        if (nbs[ni]) {
          const bx: number = nx + dxs[d];
          const by: number = ny + dys[d];
          if (bx < 0 || by < 0 || bx >= w || by >= h) {
            continue;
          }
          const bi: number = by * w + bx;
          if (this.walls[bi] || nbs[bi]) {
            continue;
          }
          nbs[ni] = false;
          nbs[bi] = true;
        }
        const k: string = this.aiKeyOf(ni, nbs);
        if (seen.has(k)) {
          continue;
        }
        seen.set(k, qp.length);
        qp.push(ni);
        qb.push(nbs);
        par.push(head);
        mvs.push(d);
        if (this.allOnGoal(nbs) && winAt < 0) {
          winAt = qp.length - 1;
        }
      }
      head = head + 1;
    }
    if (winAt < 0) {
      return [];
    }
    const out: number[] = [];
    let at: number = winAt;
    while (at > 0 && par[at] >= 0) {
      out.unshift(mvs[at]);
      at = par[at];
    }
    return out;
  }

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
    if (this.solvedNow) {
      return false;
    }
    if (this.aiKey() !== this.aiPlanKey) {
      this.aiPlan = this.aiSolve();
      this.aiPlanKey = this.aiKey();
    }
    if (this.aiPlan.length === 0) {
      return false;
    }
    const dxs: number[] = [0, 1, 0, -1];
    const dys: number[] = [-1, 0, 1, 0];
    const d: number = this.aiPlan[0];
    this.aiPlan.splice(0, 1);
    this.step(dxs[d], dys[d]);
    this.aiPlanKey = this.aiKey();
    return !this.solvedNow;
  }

  /** 提示：报下一步往哪推、这条解法一共几步 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.solvedNow) {
      return Hint.none('none');
    }
    if (this.aiKey() !== this.aiPlanKey || this.aiPlan.length === 0) {
      this.aiPlan = this.aiSolve();
      this.aiPlanKey = this.aiKey();
    }
    if (this.aiPlan.length === 0) {
      return Hint.none('none');
    }
    const names: string[] = [TG('上'), TG('右'), TG('下'), TG('左')];
    const ens: string[] = ['up', 'right', 'down', 'left'];
    const d: number = this.aiPlan[0];
    return Hint.make([], TG2('往{0}推一步（这条解法还要 {1} 步）', names[d], this.aiPlan.length),
      TG2('Move {0} ({1} steps to solve)', ens[d], this.aiPlan.length), t0);
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

  private undo(): void {
    if (this.history.length === 0) {
      return;
    }
    const snap: Snap = this.history[this.history.length - 1];
    this.history.splice(this.history.length - 1, 1);
    this.boxes = snap.boxes;
    this.player = snap.player;
    this.moves = snap.moves;
    this.pushes = snap.pushes;
    this.solvedNow = false;
  }

  private allOnGoal(boxes: boolean[]): boolean {
    for (let i = 0; i < boxes.length; i++) {
      if (boxes[i] && !this.goals[i]) {
        return false;
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    const base: number = 300 + (this.level + 1) * 80;
    const r: GameResult = {
      gameId: 'sokoban',
      solved: solved,
      score: solved ? Math.max(60, base - this.moves * 3) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.level + 1
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private go(idx: number): void {
    if (idx < 0 || idx >= LEVELS.length) {
      return;
    }
    this.load(idx);
  }

  private clearedCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.cleared.length; i++) {
      if (this.cleared[i]) {
        n++;
      }
    }
    return n;
  }

  private statusText(): string {
    if (this.solvedNow) {
      return this.level < LEVELS.length - 1 ? '🎉 过关！点「下一关」继续' : '🏆 全部关卡通关！';
    }
    if (this.blocked > 0 && this.moves === 0) {
      return TG('那个方向被墙挡住了');
    }
    return LEVELS[this.level].hint;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      // ── 关卡名 + 进度 ──
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
          Text(LEVELS[this.level].name)
            .fontSize(FontSize.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
          Text(TG2("已过 {0} / {1} 关", this.clearedCount(), LEVELS.length))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.stat(0)
        this.stat(1)
      }
      .width('100%')

      // ── 关卡圆点 ──
      Row({ space: Space.xs }) {
        ForEach(LEVELS, (lv: Level, i: number) => {
          Row()
            .width(this.level === i ? Space.md : Space.sm)
            .height(Space.sm)
            .borderRadius(Radius.full)
            .backgroundColor(this.cleared[i] ? Palette.emerald
              : (this.level === i ? Palette.amber : this.theme.line))
            .animation({ duration: Motion.fast, curve: Motion.snap() })
        }, (lv: Level, i: number) => 'dot' + i)
      }
      .width('100%')

      // ── 棋盘 ──
      Column({ space: 0 }) {
        ForEach(this.rowList, (y: number) => {
          Row({ space: 0 }) {
            ForEach(this.colList, (x: number) => {
              // ⚠️ 传 (y,x) 而不是 y*this.w+x：this.w 是 @State，换关会变；
              //    在调用点算下标的话，ForEach 键（'sk'+y+'-'+x）没变 ⇒ 项生成函数不再执行
              //    ⇒ 下标会停在旧 w 上（棋盘错位）。在 builder 内部算才安全。
              this.cell(y, x)
            }, (x: number) => 'sk' + y + '-' + x)
          }
          .width('100%')
        }, (y: number) => 'skr' + y)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)
      .gesture(
        // ★ P9：滑动改口径 —— PanGesture 的 offsetX/offsetY（vp）判方向。
        //   原来用 SwipeGesture 的 e.angle：① 要"甩"够速度才触发，慢拖没反应；
        //   ② 方向判定押在 angle 的正负约定上，机型/版本一偏就会"往上滑往下走"。
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 6 })
          .onActionStart(() => {
            this.dragX = 0;
            this.dragY = 0;
          })
          .onActionUpdate((e: GestureEvent) => {
            const dx: number = e.offsetX - this.dragX;
            const dy: number = e.offsetY - this.dragY;
            if (Math.abs(dx) < DRAG_MIN && Math.abs(dy) < DRAG_MIN) {
              return;
            }
            this.dragX = e.offsetX;
            this.dragY = e.offsetY;
            if (Math.abs(dx) >= Math.abs(dy)) {
              this.step(dx > 0 ? 1 : -1, 0);
            } else {
              this.step(0, dy > 0 ? 1 : -1);
            }
          })
          .onActionEnd(() => {
            this.dragX = 0;
            this.dragY = 0;
          })
      )

      Text(this.statusText())
        .fontSize(FontSize.sm)
        .fontColor(this.solvedNow ? Palette.emerald : this.theme.inkSoft)

      // ── 方向键 ──
      Column({ space: Space.sm }) {
        this.padBtn('▲', 'U', 0, -1)
        Row({ space: Space.sm }) {
          this.padBtn('◀', 'L', -1, 0)
          this.padBtn('▼', 'D', 0, 1)
          this.padBtn('▶', 'R', 1, 0)
        }
      }
      .width('100%')

      // ── 关卡操作 ──
      Row({ space: Space.sm }) {
        Button(TG('上一关'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .enabled(this.level > 0)
          .onClick(() => {
            Haptics.tap();
            this.go(this.level - 1);
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.load(this.level);
          })
        Button(TG('撤销'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .onClick(() => {
            Haptics.tap();
            this.undo();
          })
        Button(TG('下一关'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(Color.White)
          .backgroundColor(this.solvedNow ? Palette.emerald : this.theme.lineSoft)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(48))
          .enabled(this.level < LEVELS.length - 1)
          .onClick(() => {
            Haptics.tap();
            this.go(this.level + 1);
          })
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

  /**
   * 顶部小格：kind 0=步数 1=推动次数
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这两个数不刷新。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('步数') : '推动')
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.moves) : String(this.pushes))
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  @Builder
  padBtn(label: string, key: string, dx: number, dy: number) {
    Button(label)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
      .fontSize(FontSize.lg)
      .fontColor(this.pressed === key ? Color.White : this.theme.ink)
      .backgroundColor(this.pressed === key ? Palette.primary : this.theme.surfaceAlt)
      .borderRadius(Radius.md)
      .width(80)
      .height(Cell.of(48))
      .scale({
        x: this.pressed === key ? Motion.pressScale : 1,
        y: this.pressed === key ? Motion.pressScale : 1
      })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.pressed = key;
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressed = '';
        }
      })
      .onClick(() => {
        Haptics.tap();
        this.step(dx, dy);
      })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  /**
   * 一个格子 —— 收 (y, x) 位置，格子的下标在内部用 this.w 算
   * ⚠️ 不能把 y*this.w+x 当参数传进来（见调用点注释）；
   *    所有 this.walls[…]/this.goals[…]/this.boxes[…]/this.player 的读取都在闭包内 ⇒ 才刷新。
   */
  @Builder
  cell(y: number, x: number) {
    Stack() {
      if (this.walls[y * this.w + x]) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.theme.isDark ? Palette.dLine : Palette.lineSoft)
          .borderRadius(Radius.xs)
      } else {
        if (this.goals[y * this.w + x]) {
          Row()
            .width('34%')
            .aspectRatio(1)
            .borderRadius(Radius.full)
            .backgroundColor(Palette.emerald)
            .opacity(0.55)
        }
        if (this.boxes[y * this.w + x]) {
          Stack() {
            Text('📦').accessibilityLevel('no').fontSize(FontSize.sm)
          }
          .width('78%')
          .aspectRatio(1)
          .borderRadius(Radius.xs)
          .backgroundColor(this.goals[y * this.w + x] ? Palette.emerald : Palette.amber)
          .shadow(Shadow.card)
          // ★ 滑行：只有刚移过来的箱子有位移（原来这里读的属性不变 ⇒ 动画是死的）
          .translate({
            x: (y * this.w + x) === this.slideB ? this.slideDX : 0,
            y: (y * this.w + x) === this.slideB ? this.slideDY : 0
          })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        if (this.player === y * this.w + x) {
          Text('🧍').accessibilityLevel('no')
            .fontSize(FontSize.lg)
            // ★ 滑行（原来这里也是死动画）
            .translate({
              x: (y * this.w + x) === this.slideP ? this.slideDX : 0,
              y: (y * this.w + x) === this.slideP ? this.slideDY : 0
            })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
      }
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(this.theme.surface)
    .border({ width: 1, color: this.theme.line })
  }
}
