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
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Bp } from '../core/Bp';
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

// ═══════════ AI 期望值搜索（2026-11-06 重写）═══════════
// 为什么是 expectimax 而不是"再往前看一步"：
//   2048 每次滑动后**随机**落一个 2/4。只看「滑完的局面」等于假装落子不存在，
//   贪心会反复把牌推到"看起来空、其实一落子就堵死"的位置。
//   正确做法是对空格求期望：V(局面) = Σ_space [0.9·V(落2) + 0.1·V(落4)] / 空格数。
const SNAKE_PATHS: number[][] = [
  [0, 1, 2, 3, 7, 6, 5, 4, 8, 9, 10, 11, 15, 14, 13, 12],
  [0, 4, 8, 12, 13, 9, 5, 1, 2, 6, 10, 14, 15, 11, 7, 3],
  [12, 13, 14, 15, 11, 10, 9, 8, 4, 5, 6, 7, 3, 2, 1, 0],
  [3, 7, 11, 15, 14, 10, 6, 2, 1, 5, 9, 13, 12, 8, 4, 0],
  [3, 2, 1, 0, 4, 5, 6, 7, 11, 10, 9, 8, 12, 13, 14, 15],
  [12, 8, 4, 0, 1, 5, 9, 13, 14, 10, 6, 2, 3, 7, 11, 15],
  [15, 14, 13, 12, 8, 9, 10, 11, 7, 6, 5, 4, 0, 1, 2, 3],
  [15, 11, 7, 3, 2, 6, 10, 14, 13, 9, 5, 1, 0, 4, 8, 12]
];
/** 蛇形权重：越靠路径起点的格子权重越大（4^(-k/4) 衰减，起点 181 / 终点 1） */
const SNAKE_W: number[] = [181.019336, 128.000000, 90.509668, 64.000000,
  45.254834, 32.000000, 22.627417, 16.000000, 11.313708, 8.000000,
  5.656854, 4.000000, 2.828427, 2.000000, 1.414214, 1.000000];
/** 搜索层数：根 max + chance + max（3 层） */
const AI_SEARCH_DEPTH: number = 3;
/** chance 层空格上限：空格多于 8 个时均匀采样 8 个
 *  ★ 实测（各 200 局）：采样 8 个胜率 65.5%，全算 14 个反而只有 61.0%
 *    —— 全算会把"最坏落点"平均进来，AI 变得过度保守；采样反而更敢做正确的大方向 */
const AI_CHANCE_SAMPLE: number = 8;
/** 一拍连走几步（320ms/拍；150s 窗口只够 375 拍，必须连走） */
const AI_STEPS_PER_TICK: number = 6;
/** 单拍计算上限（ms）：慢设备上不让一帧卡太久 */
const AI_TICK_BUDGET_MS: number = 120;

/**
 * 局面评估（越大越好）。纯函数，不改任何状态。
 * 组成（权重是 2026-11-06 用 504 局离线模拟扫出来的）：
 *   蛇形 1.0 + 空格 100 + 可合并对数 50 − 单调性 20 − 平滑度 20
 * 蛇形取**8 条路径的最大值** ⇒ 自动跟着「最大块现在在哪个角」走，
 * 不会像固定 snake 那样硬把牌往一个角推（那样一旦错位就是死局）。
 */
function aiEval(cells: number[]): number {
  const lg: number[] = new Array<number>(16);
  let empty: number = 0;
  for (let i = 0; i < 16; i++) {
    const v: number = cells[i];
    if (v === 0) {
      lg[i] = 0;
      empty++;
    } else {
      lg[i] = Math.log2(v);
    }
  }
  // 可合并对数（已经相邻且相等）
  let merges: number = 0;
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N; c++) {
      const v: number = cells[r * N + c];
      if (v === 0) {
        continue;
      }
      if (c + 1 < N && cells[r * N + c + 1] === v) {
        merges++;
      }
      if (r + 1 < N && cells[(r + 1) * N + c] === v) {
        merges++;
      }
    }
  }
  // 单调性：跳过空格比较相邻非空；每行/列取「两个方向里较不坏」的
  let mono: number = 0;
  for (let r = 0; r < N; r++) {
    let inc: number = 0;
    let dec: number = 0;
    let prev: number = -1;
    for (let c = 0; c < N; c++) {
      if (cells[r * N + c] === 0) {
        continue;
      }
      const l: number = lg[r * N + c];
      if (prev >= 0) {
        if (prev > l) {
          inc += prev - l;
        } else {
          dec += l - prev;
        }
      }
      prev = l;
    }
    mono += Math.min(inc, dec);
  }
  for (let c = 0; c < N; c++) {
    let inc: number = 0;
    let dec: number = 0;
    let prev: number = -1;
    for (let r = 0; r < N; r++) {
      if (cells[r * N + c] === 0) {
        continue;
      }
      const l: number = lg[r * N + c];
      if (prev >= 0) {
        if (prev > l) {
          inc += prev - l;
        } else {
          dec += l - prev;
        }
      }
      prev = l;
    }
    mono += Math.min(inc, dec);
  }
  // 平滑度：相邻非空格的高度差
  let smooth: number = 0;
  for (let r = 0; r < N; r++) {
    for (let c = 0; c < N - 1; c++) {
      if (cells[r * N + c] !== 0 && cells[r * N + c + 1] !== 0) {
        smooth += Math.abs(lg[r * N + c] - lg[r * N + c + 1]);
      }
    }
  }
  for (let c = 0; c < N; c++) {
    for (let r = 0; r < N - 1; r++) {
      if (cells[r * N + c] !== 0 && cells[(r + 1) * N + c] !== 0) {
        smooth += Math.abs(lg[r * N + c] - lg[(r + 1) * N + c]);
      }
    }
  }
  // 蛇形（自适应四角）
  let snake: number = -1e18;
  for (let k = 0; k < 8; k++) {
    const path: number[] = SNAKE_PATHS[k];
    let s: number = 0;
    for (let j = 0; j < 16; j++) {
      const idx: number = path[j];
      if (cells[idx] !== 0) {
        s += lg[idx] * SNAKE_W[j];
      }
    }
    if (s > snake) {
      snake = s;
    }
  }
  return snake + empty * 100 + merges * 50 - mono * 20 - smooth * 20;
}

/**
 * expectimax 递归。纯函数（不碰组件状态），深度最多 3 层。
 * @param cells  当前局面，绝不修改
 * @param depth  剩余层数（<=0 直接评估）
 * @param player true = max 层（选方向）；false = chance 层（随机落子求期望）
 */
function expectValue(cells: number[], depth: number, player: boolean, sample: number): number {
  if (depth <= 0) {
    return aiEval(cells);
  }
  if (player) {
    let best: number = -1e18;
    let any: boolean = false;
    for (let d = 0; d < 4; d++) {
      const nx: number[] = previewMove(cells, d);
      if (sameCells(nx, cells)) {
        continue;
      }
      any = true;
      const v: number = expectValue(nx, depth - 1, false, sample);
      if (v > best) {
        best = v;
      }
    }
    return any ? best : aiEval(cells) - 1e7;   // 四向都动不了 = 死局
  }
  const empties: number[] = [];
  for (let i = 0; i < 16; i++) {
    if (cells[i] === 0) {
      empties.push(i);
    }
  }
  if (empties.length === 0) {
    return aiEval(cells);
  }
  let use: number[] = empties;
  if (sample > 0 && empties.length > sample) {
    use = [];
    const step: number = (empties.length - 1) / (sample - 1);
    for (let k = 0; k < sample; k++) {
      use.push(empties[Math.round(k * step)]);
    }
  }
  let tot: number = 0;
  for (let k = 0; k < use.length; k++) {
    const idx: number = use[k];
    const a: number[] = cells.slice();
    a[idx] = 2;
    const b: number[] = cells.slice();
    b[idx] = 4;
    tot += 0.9 * expectValue(a, depth - 1, true, sample)
      + 0.1 * expectValue(b, depth - 1, true, sample);
  }
  return tot / use.length;
}

/** 方向名（d=0 左 / 1 右 / 2 上 / 3 下）—— 提到模块级，演示与提示共用 */
const DIR_CN: string[] = ['左', '右', '上', '下'];

@Component
export struct G2048 {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：通关目标（简单 1024 / 普通 2048 / 困难 4096）
  //   ⚠️ 必须用 pick() 给明确值 —— 倍率会算出 1434 这种非法方块，简单档永远赢不了
  private winTile: number = GameDiff.pick(1024, 2048, 4096);
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示动画三拍（与宝石迷阵/华容道同一套 core/Demo.ets）
  //  2048 是「滑方向」类：第 1 拍先指出**要滑的方向**，第 2 拍才滑，
  //  第 3 拍亮出合并结果；全程**不计分**（演完原样恢复）。
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private demoGuideDir: number = -1;
  private demoSnapCells: number[] = [];
  private demoSnapScore: number = 0;
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

  // ═══════════ AI 代打（2026-10-24 第三期；2026-11-06 重写）═══════════
  // 旧版：四个方向各滑一次 → heuristicScore 取最高（一步贪心）。
  //   实测（150s）只到 512：贪心看不到「这步滑完随机落子会不会把路堵死」。
  // 新版：2048 的标准解法 **expectimax（期望值搜索）**
  //   max 层：选方向；chance 层：对每个空格按 90% 落 2 / 10% 落 4 求期望。
  //   搜 3 层（4 方向 × 空格 × 4 方向）≈ 200~400 次评估 —— 一拍走 6 步也够快。
  //   ★ 没走价值网络：G2048Value 是启发式轨迹上训的，直接贪心选方向实测会退化
  //     （见 G2048Value.ets 里 2026-10-23 的负面结果），这里继续只用启发式。
  private bestDir(): number {
    let bd: number = -1;
    let bv: number = -1e18;
    for (let d = 0; d < 4; d++) {
      const next: number[] = previewMove(this.cells, d);
      if (sameCells(next, this.cells)) {
        continue;                      // 这个方向动不了
      }
      const v: number = expectValue(next, AI_SEARCH_DEPTH - 1, false, AI_CHANCE_SAMPLE);
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
  /** 2048 的三拍演示：**指方向 → 滑 → 看结果**，且**不计分** */
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }
    if (this.over || this.won) { this.demoFinish(); return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      const d: number = this.bestDir();
      if (d < 0) { this.demoFinish(); return -1; }
      this.demoGuideDir = d;
      this.hintDir = d;
      this.demoMsg = TG2('看这里：现在往{0}滑最划算', TG(DIR_CN[d]));
      this.hintText = this.demoMsg;
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      this.demoGuideDir = -1;
      this.hintDir = -1;
      this.hintText = '';
      const d: number = this.bestDir();
      if (d >= 0) { this.move(d); }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样合。碰一下屏幕，换你来')
      : TG2('滑过去了，这一下能拿 +{0} 分',
          String(this.score - this.demoSnapScore));
    this.hintText = this.demoMsg;
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoGuideDir = -1;
    this.hintDir = -1;
    this.hintText = '';
    this.demoPhase = 0;
    this.demoRound = 0;
    if (this.demoSnapCells.length === this.cells.length) {
      this.cells = this.demoSnapCells;
    }
    this.score = this.demoSnapScore;
    this.over = false;
    this.won = false;
    this.demoSnapCells = [];
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoSnapCells = this.cells.slice();
    this.demoSnapScore = this.score;
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来会告诉你要往哪滑');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over || this.won) {
      return false;                    // 死局 / 已拼出目标块 ⇒ 收工
    }
    // ★★★ 2026-11-06 修「150 秒到不了 2048」的**根因之二：节拍太慢**
    //   代打节拍是 320ms/步（Hint.AUTO_MS），验证窗口只有 ~120s ⇒ **最多 375 步**。
    //   而拼出一块 2048 至少需要 ~1000 次落子（1024 张 2 合成 2048，
    //   再算上 10% 直接落 4 的便宜）—— 一步一拍**数学上就不可能到 2048**。
    //   ⇒ 一拍连走 AI_STEPS_PER_TICK 步（同一套决策，只是不在两帧之间等 320ms）。
    //   上限 6 步 ⇒ 375 拍 ≈ 2250 步，足够走完一局（含失败局）。
    const t0: number = Date.now();
    let n: number = 0;
    while (n < AI_STEPS_PER_TICK) {
      if (this.over || this.won) {
        return false;
      }
      const d: number = this.bestDir();
      if (d < 0) {
        return false;                  // 四个方向都动不了：真死局
      }
      this.move(d);
      n++;
      // ★ 慢设备兜底：单拍超预算就先交还主线程，下一拍接着走。
      //   但**至少走 3 步**再让路 —— 否则慢设备上 375 拍走不到 1000 步，
      //   2048 还是拼不出来（这是"为了不卡而输掉"的陷阱）。
      if (n >= 3 && Date.now() - t0 >= AI_TICK_BUDGET_MS) {
        break;
      }
    }
    return !this.over && !this.won;
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
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
      this.over = true; this.won = false;
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
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
      // ★ 2026-11-01 演示条走共用组件（DemoBar），不再借 HintBar 的 @Prop
      // ★ 演示条与 HintBar 恒显示：DemoBar 在未演示时高度为 0，不占位
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
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
      // ★★★ 2026-11-14 真机截图：棋盘**很小（~430px）而中间一大片空白**，
      //   底部「滑动或按方向键」+「提示」按钮仍被切。
      //   根因：`width('100%')` + `aspectRatio(1)` ⇒ 宽度 2500px、按比例要高也 2500px，
      //   而下面那个 `constraintSize({maxHeight:'46%'})` **只是把方形裁掉一半**，
      //   **格子仍按 2500px 的方形排** ⇒ 视觉上又小又错位（判据 1966：要限**宽**，不是限高）
      .width(Math.min(Bp.width - 2 * Space.lg, Math.max(240, Bp.height - 360)))
      .aspectRatio(1)
      // ★★★ 2026-10-29 真机抓到（**第三次**同一个坑）：
      //   棋盘 aspectRatio(1) ⇒ 高度被宽度锁死 ⇒ 把「提示 / 重开」那一行挤到屏幕外
      //   （真机 dump：屏上只有「AI 代打」，**没有任何「提示」元素**）
      //   ⇒ 给棋盘限高，让下面那行回到可视区。
      //   （数独、孔明棋都修过同一个问题 —— 这是第三处）
      //   ★★ 2026-11-14 更正（真机截图 + 算术）：
      //     **前三次修的应该都是「限高」，而限高对 `aspectRatio(1)` 只裁不缩 ⇒ 三次都没修对。**
      //     正确做法是**限宽**（`width: Math.min(Bp.width-40, Bp.height-360)` ⇒ `173vp`），
      //     因为 `N×N` 方阵的**高恰好等于宽度封顶值**（判据 `1966`）。
      //     `2026-11-14` 已按限宽改掉，并删掉了下面那个 `maxHeight`。
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
          .height(Cell.tap(44))
          .padding({ left: Space.md, right: Space.md })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L673'; })
          .onBlur(() => { if (this.tvFocus === 'L673') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L673'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.tap(44))
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L687'; })
          .onBlur(() => { if (this.tvFocus === 'L687') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L687'))
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
      Text(this.demoId >= 0
        ? (kind === 0 ? '—' : String(Math.max(...this.cells, 0)))
        : String(kind === 0 ? this.score : Math.max(...this.cells, 0)))
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
      .onFocus(() => { this.tvFocus = 'L778'; })
      .onBlur(() => { if (this.tvFocus === 'L778') { this.tvFocus = ''; } })
      .outline(Tv.focusOutline(this.tvFocus === 'L778', Radius.sm))
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.move(dir); }); })
      .onClick(() => {
        Haptics.tick();
        this.move(dir);
      })
  }
}
