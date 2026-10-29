/**
 * 2048 —— ★参考实现★（其余游戏照这个写法）
 *
 * 契约：
 *   @Prop theme: Theme
 *   onFinish: (r: GameResult) => void
 *   build() 自己铺满父容器
 *
 * 交互：四向滑动（SwipeGesture），每次有效移动后随机落一个 2/4
 * 通关判据：拼出 2048
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
// ★★★ 2026-10-23 路线 C：价值网络（提示用）
import { G2048Value, heuristicScore } from '../ai/G2048Value';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Tv } from '../core/Tv';

const N: number = 4;
const WIN: number = 2048;
/**
 * 拖动手势的判定阈值（vp）。
 * ⚠️ 为什么必须有：PanGesture 的 offsetX/offsetY 是**从手指按下算起的累计位移**，
 *    不设阈值的话一次 60vp 的慢拖会被当成几十次移动 ⇒ 棋盘瞬间被推烂。
 *    做法：每认一次方向就把起点重置到当前位置（见 dragX/dragY），于是"再拖 26vp"才算下一次。
 */
const DRAG_MIN: number = 26;

/** 方块配色（数字 → 底色） */
function tileColor(v: number, theme: Theme): string {
  if (v === 0) {
    return theme.isDark ? '#1AFFFFFF' : '#EEE9E0';
  }
  const map: Record<number, string> = {
    2: '#EEE4DA', 4: '#EDE0C8', 8: '#F2B179', 16: '#F59563',
    32: '#F67C5F', 64: '#F65E3B', 128: '#EDCF72', 256: '#EDCC61',
    512: '#EDC850', 1024: '#EDC53F', 2048: '#EDC22E'
  };
  return map[v] ?? '#3C3A32';
}

function tileInk(v: number): string {
  if (v <= 4) { return '#776E65'; }
  // ★ 2026-10-19（对比度实测后改）：
  //   128 以上是黄系底，白字对比度只有 1.53–1.70
  //   （WCAG 大字号要 3:1）⇒ 肉眼就是“糊的”
  //   换成深墨字 #4A3B2A 后对比度 6.34–7.06，全部过线
  //   橙系底（8–64）留白字：那是 2048 的经典样子，且渲染图里确实读得出来
  if (v >= 128) { return '#4A3B2A'; }
  return '#FFFFFF';
}


/**
 * ★★★ 2026-10-23 路线 C：预演一次移动，**不改任何状态**。
 *   原来的 move() 是组件方法、会改 this.cells 并加分 —— 提示功能需要
 *   "只看不落"的版本，所以单独写一个纯函数。
 *   规则与 collapse() 严格一致（左到右、每块最多合一次）。
 */
function previewMove(cells: number[], dir: number): number[] {
  const out: number[] = new Array<number>(16);
  for (let i = 0; i < 16; i++) {
    out[i] = cells[i];
  }
  const collapseLine = (line: number[]): number[] => {
    const t: number[] = [];
    for (let i = 0; i < line.length; i++) {
      if (line[i] !== 0) {
        t.push(line[i]);
      }
    }
    let i: number = 0;
    while (i < t.length - 1) {
      if (t[i] === t[i + 1]) {
        t[i] = t[i] * 2;
        t.splice(i + 1, 1);
      }
      i++;
    }
    while (t.length < N) {
      t.push(0);
    }
    return t;
  };
  // ★★★ 2026-10-29（真机抓到真 BUG）：**这里的"方向"必须和 move() 完全一致**，
  //   否则 bestDir() 评估的是 A 方向、move() 执行的是 B 方向
  //   ⇒ 代打会一直选到"动不了"的方向 ⇒ **棋盘纹丝不动，代打看起来卡死**。
  //
  //   move() 的语义（见它里面的 idx 用法）：
  //     dir 0 (上)：按列，从 row 0 往 row N-1
  //     dir 1 (右)：按行，从 col N-1 往 col 0
  //     dir 2 (下)：按列，从 row N-1 往 row 0
  //     dir 3 (左)：按行，从 col 0 往 col N-1
  //   原来 previewMove 写的是 dir0/1=按行、dir2/3=按列 ⇒ **0 和 2 全错位**。
  if (dir === 0 || dir === 2) {
    // 按列处理
    for (let c = 0; c < N; c++) {
      const line: number[] = [];
      for (let r = 0; r < N; r++) {
        line.push(out[r * N + c]);
      }
      const src: number[] = dir === 0 ? line : line.slice().reverse();
      const res: number[] = collapseLine(src);
      const fin: number[] = dir === 0 ? res : res.slice().reverse();
      for (let r = 0; r < N; r++) {
        out[r * N + c] = fin[r];
      }
    }
  } else {
    // 按行处理
    for (let r = 0; r < N; r++) {
      const line: number[] = [];
      for (let c = 0; c < N; c++) {
        line.push(out[r * N + c]);
      }
      const src: number[] = dir === 3 ? line : line.slice().reverse();
      const res: number[] = collapseLine(src);
      const fin: number[] = dir === 3 ? res : res.slice().reverse();
      for (let c = 0; c < N; c++) {
        out[r * N + c] = fin[c];
      }
    }
  }
  return out;
}

/** 两个盘面是否相同（用来判断"这一方向能不能动"） */
function sameCells(a: number[], b: number[]): boolean {
  for (let i = 0; i < 16; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

@Component
export struct G2048 {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：通关目标（简单 1024 / 普通 2048 / 困难 4096）
  //   ⚠️ 必须用 pick() 给明确值 —— 倍率会算出 1434 这种非法方块，简单档永远赢不了
  private winTile: number = GameDiff.pick(1024, 2048, 4096);
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private cells: number[] = [];
  @State private hintDir: number = -1;
  @State private hintText: string = '';
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private best: number = 0;
  @State private bump: number = 0;   // 每次落子 +1，触发方块入场动画
  /** ★★ 2026-10-14 修复（奥森：「2048 直接呈现静态结果」）：
   *  原来 bump 只递增、渲染里从没读过 ⇒ 入场动画从未发生 ✗
   *  ⇒ 加 pulse：每次落子整盘轻微放大再回弹，做出落子手感 */
  @State private pulse: number = 1;
  /** ★★ 2026-10-14 真滑行（奥森：方块应该滑过去，不是直接呈现静态结果）：
   *  做法：网格不动，但每次落子让所有方块【先从「来处」方向偏移】，
   *        下一帧归零 ⇒ 视觉上就是「滑到新位置」（不用重写渲染）*/
  @State private slideX: number = 0;
  @State private slideY: number = 0;

  private startAt: number = 0;
  /** ★ 拖动起点（vp）：每认一次方向就重置 —— 让「直接拖方块」可以连续拖 */
  private dragX: number = 0;
  private dragY: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('G2048')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.reset();
  }

  private reset(): void {
    this.cells = new Array<number>(N * N).fill(0);
    this.score = 0;
    this.over = false;
    this.won = false;
    this.spawn();
    this.spawn();
    this.startAt = Date.now();
  }

  /** 在随机空格落一个 2（90%）或 4（10%） */
  private spawn(): void {
    const empty: number[] = [];
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === 0) {
        empty.push(i);
      }
    }
    if (empty.length === 0) {
      return;
    }
    const idx: number = empty[Math.floor(Math.random() * empty.length)];
    const next: number[] = this.cells.slice();
    next[idx] = Math.random() < 0.9 ? 2 : 4;
    this.cells = next;
    this.bump++;
    // ★ 落子手感：整盘弹一下（110ms 一个来回）
    this.pulse = 1.045;
    setTimeout(() => { this.pulse = 1; }, 110);
  }

  /** 把一行/一列向左压并合并，返回 [新数组, 得分] */
  private collapse(line: number[]): number[] {
    const out: number[] = line.filter((v: number) => v !== 0);
    let gained: number = 0;
    for (let i = 0; i < out.length - 1; i++) {
      if (out[i] === out[i + 1]) {
        out[i] = out[i] * 2;
        gained += out[i];
        out.splice(i + 1, 1);
      }
    }
    while (out.length < N) {
      out.push(0);
    }
    this.pendingGain += gained;
    return out;
  }

  private pendingGain: number = 0;

  private idx(r: number, c: number): number {
    return r * N + c;
  }

  /** dir: 0=上 1=右 2=下 3=左 */

  /**
   * ★★★ 2026-10-23 路线 C：用价值网络算「最优的一步」。
   *
   * 做法是一步前瞻（不搜树）：
   *   对 4 个方向各预演滑动后的局面 → 喂给价值网络 → 取预测值最大的那个。
   *
   * 为什么一步就够：
   *   2048 的分支因子只有 4，而且滑动后马上会随机生成新块 ⇒ 深搜会引入
   *   大量运气分支，反而稀释信号。学界公认「好评估 + 一步前瞻」性价比最高。
   *
   * 模型不可用 ⇒ 返回 -1，由调用方给出手工提示（绝不卡死）。
   */
  private askHint(): void {
    Haptics.tap();
    const order: number[] = [0, 1, 2, 3];      // 左 右 上 下
    let bestDir: number = -1;
    let bestVal: number = -1e18;
    let anyMoved: boolean = false;
    for (let k = 0; k < order.length; k++) {
      const d: number = order[k];
      const next: number[] = previewMove(this.cells, d);
      if (sameCells(next, this.cells)) {
        continue;                              // 这个方向动不了
      }
      anyMoved = true;
      // ★★★ 2026-10-23 实测修正：**启发式当主评估**，价值网络只做裁决
      //   实测拿价值网络贪婪选方向，100 局均分 10,885 → 919（0 胜 100 负）
      //   根因：模型是在启发式轨迹上训的，用它做决策就走出训练分布
      //   ⇒ 主评估用启发式（实测能到 1 万分），
      //     只有当两手启发式分数几乎一样（差 < 3）时，才让模型裁决
      const hv: number = heuristicScore(next);
      let v: number = hv;
      if (hv > bestVal - 3 && hv < bestVal + 3) {
        const pred: number | null = G2048Value.value(next);
        if (pred !== null) {
          v = hv + pred * 0.001;      // 只当极小权重的水滴，绝不改变量级
        }
      }
      if (v > bestVal) {
        bestVal = v;
        bestDir = d;
      }
    }
    if (!anyMoved) {
      this.hintDir = -1;
      this.hintText = TG('没有可动的方向了');
      return;
    }
    // ★★★ 2026-10-23 修：原来用三处 TG() 拼字符串 —— 跨语言语序会错
    //   （日语"左へスライド"、德语"nach links schieben" 位置都不一样）
    //   ⇒ 改用 TG2 模板：「试试往{0}滑」整句进字典，方向单独查
    const dirCn: string[] = ['左', '右', '上', '下'];
    this.hintDir = bestDir;
    this.hintText = TG2('试试往{0}滑', TG(dirCn[bestDir]));
    // 3 秒后自动清掉，不长期占屏幕
    setTimeout(() => { this.hintDir = -1; this.hintText = ''; }, 3000);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 一手前瞻：四个方向各预演一次（previewMove 纯函数，不改状态）⇒ 取启发式分最高那手
  //   ★ 与上面的 askHint 是同一套评估（都走 heuristicScore）
  private bestDir(): number {
    let bd: number = -1;
    let bv: number = -1e18;
    for (let d = 0; d < 4; d++) {
      const next: number[] = previewMove(this.cells, d);
      if (sameCells(next, this.cells)) {
        continue;                      // 这个方向动不了
      }
      const v: number = heuristicScore(next);
      if (v > bv) {
        bv = v;
        bd = d;
      }
    }
    return bd;
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
    if (this.over || this.won) {
      return false;                    // 死局 / 已拼出目标块 ⇒ 收工
    }
    const d: number = this.bestDir();
    if (d < 0) {
      return false;                    // 四个方向都动不了
    }
    this.move(d);
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

  private move(dir: number): void {
    if (this.over) {
      return;
    }
    const before: string = this.cells.join(',');
    const next: number[] = new Array<number>(N * N).fill(0);
    this.pendingGain = 0;

    for (let i = 0; i < N; i++) {
      const line: number[] = [];
      for (let j = 0; j < N; j++) {
        if (dir === 0) {
          line.push(this.cells[this.idx(j, i)]);
        } else if (dir === 1) {
          line.push(this.cells[this.idx(i, N - 1 - j)]);
        } else if (dir === 2) {
          line.push(this.cells[this.idx(N - 1 - j, i)]);
        } else {
          line.push(this.cells[this.idx(i, j)]);
        }
      }
      const done: number[] = this.collapse(line);
      for (let j = 0; j < N; j++) {
        if (dir === 0) {
          next[this.idx(j, i)] = done[j];
        } else if (dir === 1) {
          next[this.idx(i, N - 1 - j)] = done[j];
        } else if (dir === 2) {
          next[this.idx(N - 1 - j, i)] = done[j];
        } else {
          next[this.idx(i, j)] = done[j];
        }
      }
    }

    if (next.join(',') === before) {
      return;   // 无效移动
    }

    this.score += this.pendingGain; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.score > this.best) {
      this.best = this.score;
    }
    this.cells = next;
    // ★ 滑行感（2026-10-14）：方块先从「来处」偏移 14px，下一帧归零 ⇒ 有中间帧
    const OFF: number = 14;
    this.slideX = dir === 1 ? -OFF : (dir === 3 ? OFF : 0);
    this.slideY = dir === 0 ? OFF : (dir === 2 ? -OFF : 0);
    setTimeout(() => { this.slideX = 0; this.slideY = 0; }, 16);

    if (!this.won && next.indexOf(this.winTile) >= 0) {
      this.won = true;
      this.finish(true);
      return;
    }

    this.spawn();
    if (this.isDead()) {
      this.over = true;
      this.finish(false);
    }
  }

  /** 无空格且四邻都不可合并 ⇒ 死局 */
  private isDead(): boolean {
    for (let i = 0; i < this.cells.length; i++) {
      if (this.cells[i] === 0) {
        return false;
      }
    }
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const v: number = this.cells[this.idx(r, c)];
        if (c + 1 < N && this.cells[this.idx(r, c + 1)] === v) {
          return false;
        }
        if (r + 1 < N && this.cells[this.idx(r + 1, c)] === v) {
          return false;
        }
      }
    }
    return true;
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'g2048',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: Math.max(...this.cells)
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      // 得分条
      // ⚠️ 只传「种类」不传「值」—— 见 scoreBox 的注释（@Builder 按值传参不建立观察）
      Row({ space: Space.md }) {
        this.scoreBox(0)
        this.scoreBox(1)
      }
      .width('100%')

      // 棋盘
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2, 3], (c: number) => {
              this.tile(r, c)
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      .padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#BBADA0')
      .borderRadius(Radius.lg)
      .gesture(
        // ★ 手指直接在方块上拖 = 朝那个方向推一次（P9「要能直接滑动方块」）
        //   用 PanGesture 而不是 SwipeGesture：
        //   ① SwipeGesture 要"甩"够速度才触发，慢拖没反应（手感差）；
        //   ② PanGesture 的 offsetX/offsetY 是 vp 位移，方向判定不依赖 angle 的正负口径。
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
              this.move(dx > 0 ? 1 : 3);
            } else {
              this.move(dy > 0 ? 2 : 0);
            }
          })
          .onActionEnd(() => {
            this.dragX = 0;
            this.dragY = 0;
          })
      )

      // 方向键 —— 比滑动更精确；也保证在没有手势识别的设备/模拟器上一定能玩
      Column({ space: Space.xs }) {
        this.dirBtn('↑', 0)
        Row({ space: Space.xs }) {
          this.dirBtn('←', 3)
          this.dirBtn('↓', 2)
          this.dirBtn('→', 1)
        }
      }
      .width('100%')

      // ★★★ 2026-10-23 路线 C：提示文字
      //   ⚠️ 我第一版只加了 hintText 状态和 askHint() 方法，**忘了在界面上渲染它**
      //      ⇒ 真机点了没反应（状态一直在变，屏幕上什么都看不到）
      //      ⇒ 教训：加状态必须同一次就把「谁读它」也加上，否则等于没加
      if (this.hintText.length > 0) {
        Text(this.hintText)
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.sm)
          .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      // 状态/操作
      Row({ space: Space.md }) {
        Button(this.over ? TG('已结束') : (this.won ? TG('已通关 🎉') : TG('滑动或按方向键')))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.sm)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(44))
          .enabled(false)
        Button(TG('提示'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .height(Cell.of(44))
          .padding({ left: Space.md, right: Space.md })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
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

      Text(TG('提示：已通关还能继续冲更高分；死局才结算'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
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
   * 得分格：kind 0=本局得分，1=最大方块
   *
   * ★★★ 为什么收「种类」而不是收「值」（2026-10-13 真机 P6 的根因）
   * `@Builder` 的**按值传参不建立 ArkUI 观察**：编译后（见
   * `entry/build/.../G2048.ts:343`）`this.scoreBox.bind(this)(TG('得分'), String(this.score))`
   * 里的 `String(this.score)` 在 **initialRender 的函数体**里求值，不在任何
   * `observeComponentCreation2` 闭包内 ⇒ 没有任何 elmtId 登记对 `score` 的依赖；
   * builder 内部的闭包只捕获 `value` 这个局部变量 ⇒ **@State 再变，这个 Text 也永不重新求值**。
   * ⇒ 用户看到的是「滑了、按了，棋盘/得分一动不动」= 「完全动不了」。
   * 改成传 kind、在 builder 内部读状态：读取发生在闭包内 ⇒ 依赖建立 ⇒ 正常刷新。
   */
  @Builder
  scoreBox(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('得分') : TG('最大')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(String(kind === 0 ? this.score : Math.max(...this.cells, 0)))
        .fontSize(FontSize.xl)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() })
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }

  /**
   * 一个方块：收 (r, c) 收「位置」不收「值」
   * ⚠️ 同上：格子内容与底色都必须在闭包内读 this.cells，否则棋盘永远停在初始两张牌。
   */
  @Builder
  tile(r: number, c: number) {
    Stack() {
      Text(this.cells[this.idx(r, c)] === 0 ? '' : String(this.cells[this.idx(r, c)]))
        .fontSize(this.cells[this.idx(r, c)] >= 1024 ? FontSize.lg
          : (this.cells[this.idx(r, c)] >= 128 ? FontSize.xl : FontSize.xxl))
        .fontWeight(FontWeight.Bold)
        .fontColor(tileInk(this.cells[this.idx(r, c)]))
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .backgroundColor(tileColor(this.cells[this.idx(r, c)], this.theme))
    .borderRadius(Radius.md)
    // ★ 读 pulse ⇒ 动画才有会变化的属性（原来读的都不变 ⇒ 白挂）
    .scale({ x: this.pulse, y: this.pulse })
    .translate({ x: this.slideX, y: this.slideY })   // ★ 滑行位移
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }

  /** 方向键：dir 与 move() 同口径（0上 1右 2下 3左） */
  @Builder
  dirBtn(label: string, dir: number) {
    Text(label)
      .fontSize(FontSize.lg)
      .fontColor(this.theme.ink)
      .textAlign(TextAlign.Center)
      .width(64)
      .height(Cell.of(40))
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.sm)
      .shadow(Shadow.card)
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move(dir); }); })
      .onClick(() => {
        Haptics.tick();
        this.move(dir);
      })
  }
}
