/**
 * 数方 shikaku（5×5）—— 把整盘切成若干矩形，每块矩形里恰有一个数字，且格数等于该数字
 *
 * 契约：@Prop theme ／ @Prop @Watch('onRestart') restartToken ／ onFinish
 * 胜负：25 格全部被合法矩形覆盖 ⇒ solved:true；非法尝试 3 次 ⇒ solved:false
 * 进度：已覆盖格数 ／ 错手 ／ 得分
 *
 * 操作：点第一格 → 点对角格圈出矩形；点已圈好的格子即撤销该矩形
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 5;
const CELLS: number = N * N;
// ★★ 2026-10-13 修复尺寸越界（困难档 ×1.3 ⇒ 7×7 = 49 格，原来只开 25）
const MAX_N: number = 7;
const MAX_CELLS: number = MAX_N * MAX_N;
const ERR_MAX: number = 3;

/** 3 关提示（数字 = 所属矩形面积，0 = 无提示） */
const CLUE_LIB: number[][] = [
  // 第 1 关
  [
    1,0,0,0,0,
    1,0,0,8,0,
    0,0,0,0,0,
    2,0,9,0,3,
    1,0,0,0,0
  ],
  // 第 2 关
  [
    0,0,0,0,0,
    10,0,0,0,0,
    0,5,0,0,0,
    0,5,0,0,0,
    1,1,0,2,1
  ],
  // 第 3 关
  [
    1,5,1,10,0,
    0,0,3,0,0,
    4,0,0,0,0,
    0,0,0,0,0,
    0,0,1,0,0
  ]
];

function tintOf(hex: string, isDark: boolean): string {
  return (isDark ? '#3A' : '#26') + hex.substring(1);
}

@Component
export struct GShikaku {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /**
   * ★ 2026-10-23 修「尺寸陷阱」第 18 个：
   *   CLUE_LIB 是手工画的 5×5 = 25 格，但 diffTotal = sizeNow(5)（4/5/7）
   *   ⇒ 简单档只取前 16 项、困难档 25..48 是 undefined（线索全丢）
   *   修法：棋盘固定 5×5，难度改到**容错次数**上。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  /** ★ 第 1161 轮：焦点框自绘用的当前聚焦元素 id
   *   （`.focusBox()` 从不渲染 ⇒ 改用 `.outline()` 自己画）*/
  @State private tvFocus: string = '';
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  private demoHintText: string = '';   // 演示第 1 轮算出的提示，后续复用
  @State private diffTotal: number = 5;
  /** 本局的容错次数：简单 6 / 普通 3 / 困难 2 */
  @State private errMax: number = GShikaku.errNow();

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

  @State clues: number[] = [];
  @State owner: number[] = [];     // 0 未圈，否则矩形编号
  @State first: number = -1;
  @State covered: number = 0;
  @State errors: number = 0;
  @State over: boolean = false;
  @State won: boolean = false;
  @State score: number = 0;
  /** ★ 提示说的话 */
  @State private hintMsg: string = '';

  private seq: number = 0;
  private startAt: number = 0;
  /**
   * ★★ 2026-11-06（判据 1701/1704）：**本局答案** —— 每块矩形存两个格号（左上角、右下角）压平
   *   reset() 里算一次（空盘 8 个节点），autoCell 直接照它摆，不再每拍重跑搜索。
   *   ⚠️ 不做成 @State：它不参与渲染，做成 @State 只是白白多一次重建。
   */
  private solRect: number[] = [];
  /**
   * ★ 2026-11-06：正在「清盘」——玩家切成了整盘无解时，先把自己/玩家画的矩形一块块撤掉，
   *   撤空后再照答案重来。必须是**粘性**的：一次性撤到底，不能撤一块又去摆一块（会来回打转）。
   */
  private wipe: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GShikaku')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.errMax = GShikaku.errNow();
    this.reset();
  }

  private reset(): void {
    const k: number = Math.floor(Math.random() * CLUE_LIB.length);
    this.clues = CLUE_LIB[k].slice();
    this.owner = new Array<number>(MAX_CELLS).fill(0);
    this.first = -1;
    this.covered = 0;
    this.errors = 0;
    this.over = false;
    this.won = false;
    this.score = 0;
    this.seq = 0;
    this.startAt = Date.now();
    // ★★ 2026-11-06（判据 1701/1704）：开局就把本局答案算好存起来
    //   判据 1701 的原意是「答案在手里就直接照答案」；本作题目只有线索、没有现成答案数组，
    //   等价做法 = 在 reset 里用求解器求出答案存进字段，AI 直接照抄（O(矩形数)，毫秒级）。
    this.solRect = [];
    this.wipe = false;
    const own0: number[] = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
    const out0: number[] = [];
    const b0: number[] = [4000];
    if (this.dfsFill(own0, out0, b0)) {
      this.solRect = out0.slice();
    }
  }

  private removeRect(id: number): void {
    const own: number[] = this.owner.slice();
    let removed: number = 0;
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) {
      if (own[i] === id) {
        own[i] = 0;
        removed++;
      }
    }
    this.owner = own;
    this.covered -= removed;
  }


  /**
   * ★ 2026-10-23 第二期：数方提示
   *
   * 每个线索格必须被一个面积 = 线索值、且只含它一个线索的矩形覆盖。
   * ⇒ 对每个线索格，枚举所有「含它、面积对上、不压已有矩形、不含别的线索」的矩形；
   *    如果**只有一种放法**，那个矩形就是确定的，提示直接报它的两个角。
   * 一条都找不到 ⇒ Hint.none()。
   *
   * ⚠️ 只判"这个线索只有一个合法框"，不做全局搜索：
   *    多个线索互相约束出来的推理不在这一版范围内（宁可少给）。
   */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    const n: number = this.diffTotal;
    for (let k = 0; k < n * n; k++) {
      const want: number = this.clues[k];
      if (want <= 0 || this.owner[k] !== 0) {
        continue;                       // 没线索 / 已经被圈进去了
      }
      const cr: number = Math.floor(k / n);
      const cc: number = k % n;
      let found: number = 0;
      let aR: number = 0;
      let aC: number = 0;
      let bR: number = 0;
      let bC: number = 0;
      // 枚举高 h 与宽 w，使 h*w == want
      for (let h = 1; h <= want; h++) {
        if (want % h !== 0) {
          continue;
        }
        const w: number = want / h;
        if (h > n || w > n) {
          continue;
        }
        // 矩形左上角 (r0,c0) 必须让 cr/cc 落在里面
        for (let r0 = cr - h + 1; r0 <= cr; r0++) {
          for (let c0 = cc - w + 1; c0 <= cc; c0++) {
            const r1: number = r0 + h - 1;
            const c1: number = c0 + w - 1;
            if (r0 < 0 || c0 < 0 || r1 >= n || c1 >= n) {
              continue;
            }
            let ok: boolean = true;
            let clueCnt: number = 0;
            for (let r = r0; r <= r1 && ok; r++) {
              for (let c = c0; c <= c1; c++) {
                const idx: number = r * n + c;
                if (this.owner[idx] !== 0) {
                  ok = false;
                  break;
                }
                if (this.clues[idx] > 0) {
                  clueCnt++;
                }
              }
            }
            if (!ok || clueCnt !== 1) {
              continue;
            }
            found++;
            aR = r0; aC = c0; bR = r1; bC = c1;
            if (found > 1) {
              break;
            }
          }
          if (found > 1) {
            break;
          }
        }
        if (found > 1) {
          break;
        }
      }
      if (found === 1) {
        return Hint.make([aR * n + aC, bR * n + bC],
          TG4('这里只有一个框法：从第 {0} 行第 {1} 列拖到第 {2} 行第 {3} 列',
            String(aR + 1), String(aC + 1), String(bR + 1), String(bC + 1)),
          TG4('Only one rectangle fits: from row {0}, column {1} to row {2}, column {3}',
            String(aR + 1), String(aC + 1), String(bR + 1), String(bC + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    if (r.ok) {
      this.hintMsg = r.zh;
      setTimeout(() => { this.hintMsg = ''; }, 5000);
      return;
    }
    this.hintMsg = TG('这一步看不出哪块是唯一的，先圈几个简单的');
    setTimeout(() => { this.hintMsg = ''; }, 5000);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
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
      // ★★ 2026-11-01：`computeHint()` 在部分游戏里很贵（数独要回溯求解）。
      //   演示 3 轮各调一次 = 3 次昂贵计算，可能把主线程拖到 ANR
      //   （真机上抓到过一次 THREAD_BLOCK_6S）。
      //   ⇒ **只在第 1 轮算一次**，后续轮次复用同一句；算不出来才退回通用文案。
      if (this.demoRound === 0) {
        const hr: HintResult = this.computeHint();
        this.demoHintText = (hr.ok && hr.zh.length > 0) ? hr.zh : '';
      }
      if (this.demoHintText.length > 0) {
        this.demoMsg = TG2('看这里：{0}', this.demoHintText);
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
    // ★★ 2026-11-06（判据 1702）：autoCell 只能算**一次**（旧版一行里调了两遍 = 两倍搜索），
    //   而且算不出来时必须**停**（旧版 `return true` ⇒ AI 空转、按钮却还显示「停代打」）。
    const i: number = this.autoCell();
    if (i < 0) {
      return false;
    }
    this.tap(i);
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
    this.autoId = Hint.autoRun(() => this.autoStep(), () => { this.autoId = -1; });
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

    /**
     * 当前盘面上，格 k 能被哪些矩形盖住（恰含一个线索、面积 = 该线索、不压已圈格）
     * 压平成 [a, b, a, b, ...]，a/b = 左上角/右下角的格号。
     */
    private rectsAt(own: number[], k: number): number[] {
      const n: number = this.diffTotal;
      const kr: number = Math.floor(k / n);
      const kc: number = k - kr * n;
      const out: number[] = [];
      for (let r0 = 0; r0 <= kr; r0++) {
        for (let c0 = 0; c0 <= kc; c0++) {
          for (let r1 = kr; r1 < n; r1++) {
            for (let c1 = kc; c1 < n; c1++) {
              const area: number = (r1 - r0 + 1) * (c1 - c0 + 1);
              let clue: number = 0;
              let bad: boolean = false;
              for (let r = r0; r <= r1 && !bad; r++) {
                for (let c = c0; c <= c1; c++) {
                  const idx: number = r * n + c;
                  if (own[idx] !== 0) {
                    bad = true;
                    break;
                  }
                  if (this.clues[idx] > 0) {
                    if (clue > 0) {
                      bad = true;
                      break;
                    }
                    clue = this.clues[idx];
                  }
                }
              }
              if (bad || clue !== area) {
                continue;
              }
              out.push(r0 * n + c0);
              out.push(r1 * n + c1);
            }
          }
        }
      }
      return out;
    }

    /**
     * 深搜：把还没圈的格子切成合法矩形（每块恰含一个线索、格数 = 线索数）；own 用副本模拟
     *
     * ★★ 2026-11-06 重写（判据 1702）：旧版固定挑「最左上的空格」递归、没有任何剪枝。
     *   实测 5×5 空盘只要 250 个节点就出解 ⇒ **50 万预算其实早就够用，真 bug 不在预算**
     *   （真凶是 tap() 里 1×1 的矩形放不进去，见那边的注释）。
     *   但盘面被切过之后，死胡同全靠试到底 ⇒ 搜索树会膨胀。补两个剪枝，最坏情况也只剩个位数节点
     *   （实测三关各 500 个随机残局，最坏 8 个节点）：
     *     ① MRV —— 每步挑「候选矩形最少」的空格先填（空盘第一步候选只有 1 个）
     *     ② 前向检查 —— 有任何空格一个候选都没有 ⇒ 立刻回溯
     */
    private dfsFill(own: number[], out: number[], budget: number[]): boolean {
      const n: number = this.diffTotal;
      let best: number = -1;
      let bestRects: number[] = [];
      for (let i = 0; i < n * n; i++) {
        if (own[i] !== 0) {
          continue;
        }
        const rs: number[] = this.rectsAt(own, i);
        if (rs.length === 0) {
          return false;                     // ★ 前向检查：这一格再也盖不上 ⇒ 这棵树不用试
        }
        if (best < 0 || rs.length < bestRects.length) {
          best = i;
          bestRects = rs;
          if (rs.length === 1) {
            break;                          // 只剩 1 种放法，已经是最优，不用再比
          }
        }
      }
      if (best < 0) {
        return true;                        // 全盖满 ⇒ 这一支成立
      }
      if (budget[0] <= 0) {
        return false;
      }
      budget[0] = budget[0] - 1;
      for (let q = 0; q + 1 < bestRects.length; q += 2) {
        const a: number = bestRects[q];
        const b: number = bestRects[q + 1];
        const r0: number = Math.floor(a / n);
        const c0: number = a - r0 * n;
        const r1: number = Math.floor(b / n);
        const c1: number = b - r1 * n;
        for (let r = r0; r <= r1; r++) {
          for (let c = c0; c <= c1; c++) {
            own[r * n + c] = 1;
          }
        }
        out.push(a);
        out.push(b);
        if (this.dfsFill(own, out, budget)) {
          return true;
        }
        out.pop();
        out.pop();
        for (let r = r0; r <= r1; r++) {
          for (let c = c0; c <= c1; c++) {
            own[r * n + c] = 0;
          }
        }
        if (budget[0] <= 0) {
          return false;
        }
      }
      return false;
    }

    /** 答案（solRect）里「还没画」的第一个矩形；答案被玩家切坏了就返回空数组 */
    private solNext(): number[] {
      const n: number = this.diffTotal;
      const sol: number[] = this.solRect;
      for (let q = 0; q + 1 < sol.length; q += 2) {
        const a: number = sol[q];
        const b: number = sol[q + 1];
        const r0: number = Math.floor(a / n);
        const c0: number = a - r0 * n;
        const r1: number = Math.floor(b / n);
        const c1: number = b - r1 * n;
        const area: number = (r1 - r0 + 1) * (c1 - c0 + 1);
        let cnt: number = 0;                // 这块里已经圈了几格
        let one: number = 0;                // 用的是同一个矩形编号吗
        let split: boolean = false;
        for (let r = r0; r <= r1; r++) {
          for (let c = c0; c <= c1; c++) {
            const o: number = this.owner[r * n + c];
            if (o > 0) {
              cnt++;
              if (one === 0) {
                one = o;
              } else if (one !== o) {
                split = true;
              }
            }
          }
        }
        if (cnt === 0) {
          return [a, b];                    // 这块还没画 ⇒ 就是这一步要点的两角
        }
        if (cnt < area || split) {
          return [];                        // 被玩家切成了别的块 ⇒ 答案不能照抄了
        }
      }
      return [];                            // 答案全部画好（或本来就没有答案）
    }

    /** 代打：这一步该点哪一格（先点矩形左上角，再点右下角；-1 = 没解） */
    private autoCell(): number {
      const n: number = this.diffTotal;
      // ⓪ 正在清盘：一格一格点（一次 tap 撤掉一整块），撤空后再照答案摆
      //    必须是粘性的，否则「撤一块 → 摆一块 → 又无解 → 再撤」会来回打转（实测 400 拍都出不去）
      if (this.wipe) {
        for (let i = 0; i < n * n; i++) {
          if (this.owner[i] > 0) {
            return i;
          }
        }
        this.wipe = false;                  // 撤空了，接着往下走
      }
      // ① 快路（判据 1701/1704）：reset 时答案已存好 ⇒ 直接照答案摆（O(矩形数)）
      let rect: number[] = this.solNext();
      if (rect.length < 2) {
        // ② 慢路：玩家把盘面切乱了 ⇒ 按当前 owner 重新求解（MRV + 前向检查，节点数是个位数）
        const own: number[] = [];
        for (let i = 0; i < n * n; i++) {
          own.push(this.owner[i] > 0 ? 1 : 0);
        }
        const out: number[] = [];
        const budget: number[] = [4000];
        if (!this.dfsFill(own, out, budget) || out.length < 2) {
          // ③ 整盘已经无解（玩家切错了）⇒ 撤空重来：下一拍开始一块块撤，撤空后再照答案
          this.wipe = true;
          for (let i = 0; i < n * n; i++) {
            if (this.owner[i] > 0) {
              return i;
            }
          }
          this.wipe = false;
          return -1;
        }
        rect = [out[0], out[1]];
      }
      if (this.first < 0) {
        return rect[0];
      }
      if (this.first === rect[0]) {
        return rect[1];
      }
      return this.first;
    }
  private tap(i: number): void {
    if (this.over) {
      return;
    }
    const ownHere: number = this.owner[i];
    if (ownHere > 0) {
      this.removeRect(ownHere);
      this.first = -1;
      return;
    }
    if (this.first < 0) {
      this.first = i;
      return;
    }
    const a: number = this.first;
    this.first = -1;
    // ★★ 2026-11-06 真凶（判据 1710）：两次点的是同一格时，旧版一律当「取消选择」直接返回。
    //   可三关答案里都有「1」（= 1×1 的矩形）⇒ 那块**玩家和 AI 都永远放不进去**
    //   ⇒ 这盘永远切不完；而 AI 又恰好先挑到 1×1 ⇒ 在那一格上「选中→取消→选中」空转，
    //     真机表现就是「已覆盖 0/25 一直不动」（不是搜索预算不够）。
    //   修法：格子里写着 1 ⇒ 这本来就是合法的 1×1 矩形，继续走下面的落子判定。
    if (a === i && this.clues[i] !== 1) {
      return;
    }
    const r0: number = Math.min(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const r1: number = Math.max(Math.floor(a / this.diffTotal), Math.floor(i / this.diffTotal));
    const c0: number = Math.min(a % this.diffTotal, i % this.diffTotal);
    const c1: number = Math.max(a % this.diffTotal, i % this.diffTotal);
    let area: number = 0;
    let clueCnt: number = 0;
    let clueVal: number = 0;
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const k: number = r * this.diffTotal + c;
        if (this.owner[k] !== 0) {
          return;                       // 压到别的矩形上，直接放弃
        }
        area++;
        if (this.clues[k] > 0) {
          clueCnt++;
          clueVal = this.clues[k];
        }
      }
    }
    if (clueCnt !== 1 || clueVal !== area) {
      this.errors++;
      if (this.errors >= this.errMax) {
        this.over = true;
        this.won = false;
        this.score = 0;
        this.finish(false);
      }
      return;
    }
    this.seq++;
    const own: number[] = this.owner.slice();
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        own[r * this.diffTotal + c] = this.seq;
      }
    }
    this.owner = own;
    this.covered += area;
    if (this.covered === CELLS) {
      this.over = true;
      this.won = true;
      const sec: number = Math.floor((Date.now() - this.startAt) / 1000);
      this.score = Math.max(100, 520 - this.errors * 100 - sec * 2);
      this.finish(true);
    }
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'shikaku',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.covered
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellColor(i: number): string {
    const id: number = this.owner[i];
    if (id > 0) {
      return tintOf(Palette.wheel[(id - 1) % Palette.wheel.length], this.theme.isDark);
    }
    return this.theme.surface;
  }

  build() {
    Column({ space: Bp.isShort() ? Space.sm : Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('已覆盖'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.covered) + '/' + String(CELLS)))
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
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).maxLines(1).minFontSize(8).maxFontSize(FontSize.xxs).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(Digits(String(this.score), this.langCode))
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
              Text(this.clues[(r * this.diffTotal + c)] > 0 ? String(this.clues[(r * this.diffTotal + c)]) : '')
              .fontSize(FontSize.md)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.owner[(r * this.diffTotal + c)] > 0 ? Palette.primaryDeep : this.theme.inkSoft)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellColor((r * this.diffTotal + c)))
              .borderRadius(Radius.xs)
              .border({
              width: this.first === (r * this.diffTotal + c) ? 2 : 1,
              color: this.first === (r * this.diffTotal + c) ? Palette.violet : this.theme.line
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .onFocus(() => { this.tvFocus = 'L634'; })
              .onBlur(() => { if (this.tvFocus === 'L634') { this.tvFocus = ''; } })
              .outline(Tv.focusOutline(this.tvFocus === 'L634', Radius.xs))
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.diffTotal + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width(Math.min(Bp.width - 2 * Space.lg, Math.max(200, Bp.height - 360)))
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      // ★★★ 2026-11-08 **横屏棋盘下沿被底部 tab 栏裁掉**（verifier-dev 真机实测）：
      //   本款根容器是 `Column`（无 Scroll），棋盘 `width('100%')` + 内部格子 `aspectRatio(1)`
      //   ⇒ 853 宽时棋盘高 ≈813vp，远超声高 ⇒ 底边压到 y≈1600，被 tab 栏盖住。
      //   ⇒ 判据 1802：**约束加在「棋盘容器」上**（不是格子），横屏按可用高反推；
      //   ★ 模板取自同族的 `GKakuro`（那边 -310，因为按钮行紧贴棋盘正下方；本款按钮在上方 ⇒ 先 -260）。
      //   ★ 手机零回归：`Bp.height >= 600` 走 9999（等于不约束）。
      .constraintSize({ maxHeight: Bp.height < 600 ? Bp.height - 260 : 9999 })
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)

      Row({ space: Space.md }) {
        Text(this.hintMsg.length > 0 ? this.hintMsg : (this.over
          ? (this.won ? TG2('整盘切好 🎉 得分 {0}', this.score) : TG('错手太多，本局失败'))
          : TG('点两格圈矩形：面积要等于里面的数字')))
          .fontSize(FontSize.sm)
          .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint).animation({ duration: Motion.fast, curve: Motion.snap() })
          .layoutWeight(1)
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width(64)
          .height(44)
          .onClick(() => {
            this.askHint();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L664'; })
          .onBlur(() => { if (this.tvFocus === 'L664') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L664'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
                Button(TG('重开'))
      // ★（1880 补漏）矮屏不渲染「重开」（页头 ↻ 同动作，判据 1859/1867）
      .visibility(Bp.isShort() ? Visibility.None : Visibility.Visible)
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.tap(44))
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L679'; })
          .onBlur(() => { if (this.tvFocus === 'L679') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L679'))
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
