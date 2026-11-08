/**
 * 乒乓（Pong）—— 对打小球
 *
 * 玩法：手指在球场上上下拖动移动左拍；右拍由电脑跟着球走。先得 5 分者胜。
 * 结算：你到 5 分 ⇒ 通关；电脑先到 5 分 ⇒ 失败。
 *
 * 坐标口径与打砖块一致：场地内所有位置都用「百分比」（x 是场宽 %，y 是场高 %），
 * 于是物理与屏幕像素无关。只有拖动球拍要把手指位移（vp）换成百分比，才量一下场高。
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * ★★★ 2026-10-15 提帧率：40ms → 16ms（25fps → 60fps）
 *   乒乓是【纯线性运动】（没有重力）⇒ 只要把每帧位移按 DT 缩放即可，无需积分改造
 *   ★ 注意：基准是 40ms（不是 33）⇒ DT = TICK_MS / 40
 */
const TICK_MS: number = 16;
/** 相对基准帧（40ms）的时间倍率 */
const DT: number = TICK_MS / 40;
const WIN_PTS: number = 5;
const MARGIN: number = 3;      // ★ 无尽模式的领先分差

const BALL_D: number = 3.2;
const BALL_R: number = BALL_D / 2;
const SPEED: number = 1.9;          // 球速（%/帧）
const MAX_TILT: number = 0.95;      // 打到拍边最大偏折角（弧度）

const PADDLE_W: number = 2.6;
const PADDLE_H: number = 18;
const PADDLE_X: number = 4;         // 左拍左边（%）
const AI_X: number = 93.4;          // 右拍左边（%）
const AI_SPEED: number = 1.15;      // 电脑每帧最大移动量

const WAIT_TICKS: number = 14;      // 得分后停顿几帧再发球
const BTN_H: number = 46;
const NET: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

@Component
export struct GPong {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：原 TICK_MS=40
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
  @State private diffTotal: number = GameDiff.timeNow(40);
  onFinish: (r: GameResult) => void = () => {};

  @State private bx: number = 50;
  @State private by: number = 50;
  @State private px: number = 41;      // 左拍顶边 y（%）
  @State private ay: number = 41;      // 右拍顶边 y（%）
  @State private ps: number = 0;       // 你的分
  @State private as: number = 0;       // 电脑的分
  @State private over: boolean = false;
  /** ★ 2026-10-14 无尽模式：到 5 分后不结束，改成【领先 3 分】才分胜负 */
  @State private endless: boolean = false;
  @State private won: boolean = false;
  @State private running: boolean = false;

  private vx: number = 0;
  private vy: number = 0;
  private wait: number = 0;
  private timer: number = -1;
  /** ★ 2026-11-08 看门狗：定时检查 tick 是否在推进（防"interval 建了但回调不执行"） */
  private dog: number = -1;
  private lastTickAt: number = 0;
  private lastTickN: number = 0;
  /** ★ 2026-11-08 定位用：tick 计数（日志限频） */
  private tickN: number = 0;
  private startAt: number = 0;
  private finished: boolean = false;
  @State private fieldH: number = 0;
  /** ★ 2026-11-08 判据级发现：`position({ x: '50%' })` 的**百分比字符串不生效**
   *  （`Length` 在 position 里不认 `%`，只认数值/资源）⇒ 必须用 onAreaChange 量到的
   *  球场宽高把百分比**换算成 vp 数值**再摆。`fieldH` 早就有（拖拽用），这里补 `fieldW`。 */
  @State private fieldW: number = 0;
  /**
   * ★★★ 2026-11-08（判据 1819，产品缺陷）**改用 Canvas 画球场**：
   *   真机复验：`position({ x: 数值 })` 也**没落到布局上** —— 两根球拍始终贴在球场中线
   *   （`cx≈1279`）、球连节点都没有；而 `bx` 在 10.7→90.4 往返、屏幕比分 0:0→0:2→0:4 实时变
   *   ⇒ 逻辑与 @State 重绘都正常，**是 `Stack` 内的绝对定位不生效**。
   *   ⇒ 球场是纯几何（中线/两拍/一个圆），**直接上 Canvas**，不依赖布局引擎。
   *   坐标一律用 `ctx.width/height`（vp）换算，与物理层共用同一套百分比。
   */
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private drawN: number = 0;
  /** Canvas 未 attach 前调 ctx 可能报错 ⇒ onReady 后才允许画 */
  private canvasReady: boolean = false;
  private dragPrev: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPong')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
    // ★ 2026-11-08 看门狗：每 700ms 看一次「tick 还在推进吗」。
    //   真机现象：`reset()` 明明跑过（status 显示「准备发球…」而不是「已暂停」⇒ running=true、wait>0），
    //   但 `wait` 永远不减 ⇒ **interval 回调根本没执行**。这里兜底：1.5s 没心跳就重建循环。
    if (this.dog < 0) {
      this.dog = setInterval(() => {
        if (this.over || !this.running) {
          return;
        }
        const gap: number = this.lastTickN === this.tickN ? Date.now() - this.lastTickAt : 0;
        this.lastTickN = this.tickN;
        if (gap > 1500) {
          hilog.info(0x0000, 'GPong', '看门狗：1.5s 无心跳（timer=' + String(this.timer) + '）⇒ 重建循环');
          this.startLoop();
        }
      }, 700);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(40);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
    if (this.dog >= 0) {
      clearInterval(this.dog);
      this.dog = -1;
    }
  }

  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private startLoop(): void {
    this.stopLoop();
    // ★ 2026-11-08 定位用（verifier-dev：进 GPong 后 status 一直「准备发球…」、画面 0 变化）
    const ms: number = (this.diffTotal >= 10 && this.diffTotal <= 500) ? this.diffTotal : TICK_MS;
    hilog.info(0x0000, 'GPong',
      'startLoop diffTotal=' + String(this.diffTotal) + ' ms=' + String(ms) + ' timer=' + String(this.timer) + ' running=' + String(this.running));
    this.timer = setInterval(() => {
      this.tick();
    }, ms);
    hilog.info(0x0000, 'GPong', 'startLoop → timer=' + String(this.timer));
  }

  private reset(): void {
    this.stopLoop();
    this.bx = 50;
    this.by = 50;
    this.px = (100 - PADDLE_H) / 2;
    this.ay = (100 - PADDLE_H) / 2;
    this.ps = 0;
    this.as = 0;
    this.vx = 0;
    this.vy = 0;
    this.over = false;
    this.won = false;
    this.running = true;
    this.finished = false;
    this.wait = WAIT_TICKS;
    this.startAt = Date.now();
    this.startLoop();
    this.drawField();        // ★ 先画一帧（Canvas 不随 @State 自动重绘）
  }

  /** 从中间发球，方向随机 */
  private launch(): void {
    const dir: number = Math.random() < 0.5 ? -1 : 1;
    const tilt: number = (Math.random() - 0.5) * 1.2;
    this.vx = SPEED * dir * Math.cos(tilt);
    this.vy = SPEED * Math.sin(tilt);
  }

  /** 把整个球场画一遍（中线 / 左拍 / 右拍 / 球） */
  private drawField(): void {
    if (!this.canvasReady) {
      return;                  // onReady 之前不碰 ctx
    }
    const w: number = this.ctx.width > 0 ? this.ctx.width : this.fieldW;
    const h: number = this.ctx.height > 0 ? this.ctx.height : this.fieldH;
    if (!(w > 0) || !(h > 0)) {
      return;
    }
    const c: CanvasRenderingContext2D = this.ctx;
    const lx: number = PADDLE_X / 100 * w;
    const rx: number = AI_X / 100 * w;
    const cx: number = this.bx / 100 * w;      // bx 是球心百分比
    const cy: number = this.by / 100 * h;
    this.drawN = this.drawN + 1;
    // ★ 定位用日志（限频：每 120 次画一条）
    if (this.drawN % 120 === 1) {
      hilog.info(0x0000, 'GPong',
        'draw#' + String(this.drawN) + ' canvas=' + String(w) + 'x' + String(h)
          + ' field=' + String(this.fieldW) + 'x' + String(this.fieldH)
          + ' 左拍x=' + String(lx) + ' 右拍x=' + String(rx) + ' 球=' + String(cx) + ',' + String(cy));
    }
    c.clearRect(0, 0, w, h);
    c.fillStyle = this.theme.isDark ? '#0B0B0B' : '#0F172A';
    c.fillRect(0, 0, w, h);
    // 中线（10 段）
    c.fillStyle = this.theme.line;
    const netW: number = Math.max(1, 0.01 * w);
    for (let i = 0; i < NET.length; i++) {
      c.fillRect(0.495 * w, (2 + i * 10) / 100 * h, netW, 0.04 * h);
    }
    // 左拍（你）
    c.fillStyle = Palette.violet;
    c.fillRect(lx, this.px / 100 * h, PADDLE_W / 100 * w, PADDLE_H / 100 * h);
    // 右拍（电脑）
    c.fillStyle = Palette.sky;
    c.fillRect(rx, this.ay / 100 * h, PADDLE_W / 100 * w, PADDLE_H / 100 * h);
    // 球
    c.fillStyle = Palette.amber;
    c.beginPath();
    c.arc(cx, cy, Math.max(2, BALL_R / 100 * w), 0, Math.PI * 2);
    c.fill();
  }

  private tick(): void {
    this.tickN = this.tickN + 1;
    this.lastTickAt = Date.now();
    if (this.tickN % 25 === 1) {
      hilog.info(0x0000, 'GPong',
        'tick#' + String(this.tickN) + ' wait=' + String(this.wait) + ' bx=' + String(this.bx) + ' by=' + String(this.by)
          + ' over=' + String(this.over) + ' running=' + String(this.running) + ' vx=' + String(this.vx));
    }
    if (this.over || !this.running) {
      return;
    }
    // ★ 判据 1732：AI 挡板必须在**帧级**跟随（tick 16ms 一帧），
    //   而 autoStep 是 Hint.autoRun 的 320ms 节奏 —— 320ms 内挡板不动，球早就飞过去了。
    //   ⇒ 在 tick 里补一次「跟随」（autoId >= 0 表示 AI 正在代打）
    if (this.autoId >= 0 && this.vx < 0) {
      const max2: number = 100 - PADDLE_H;
      let v2: number = this.predictY() - PADDLE_H / 2;
      if (v2 < 0) { v2 = 0; }
      if (v2 > max2) { v2 = max2; }
      this.px = v2;
    }
    if (this.wait > 0) {
      this.wait--;
      if (this.wait === 0) {
        this.launch();
      }
      return;
    }

    // ★ 位置按 DT 缩放（vx/vy 是【基准帧】的速度 ⇒ 帧率变了也不会变快）
    let x: number = this.bx + this.vx * DT;
    let y: number = this.by + this.vy * DT;

    // 上下墙
    if (y - BALL_R < 0) {
      y = BALL_R;
      this.vy = Math.abs(this.vy);
    } else if (y + BALL_R > 100) {
      y = 100 - BALL_R;
      this.vy = -Math.abs(this.vy);
    }

    // 左拍（你的）
    if (this.vx < 0 && x - BALL_R <= PADDLE_X + PADDLE_W && x + BALL_R >= PADDLE_X
      && y >= this.px - BALL_R && y <= this.px + PADDLE_H + BALL_R) {
      x = PADDLE_X + PADDLE_W + BALL_R;
      const rel: number = (y - (this.px + PADDLE_H / 2)) / (PADDLE_H / 2);
      const ang: number = (rel > 1 ? 1 : (rel < -1 ? -1 : rel)) * MAX_TILT;
      this.vx = SPEED * Math.cos(ang);
      this.vy = SPEED * Math.sin(ang);
    }

    // 右拍（电脑的）
    if (this.vx > 0 && x + BALL_R >= AI_X && x - BALL_R <= AI_X + PADDLE_W
      && y >= this.ay - BALL_R && y <= this.ay + PADDLE_H + BALL_R) {
      x = AI_X - BALL_R;
      const rel2: number = (y - (this.ay + PADDLE_H / 2)) / (PADDLE_H / 2);
      const ang2: number = (rel2 > 1 ? 1 : (rel2 < -1 ? -1 : rel2)) * MAX_TILT;
      this.vx = -SPEED * Math.cos(ang2);
      this.vy = SPEED * Math.sin(ang2);
    }

    this.bx = x;
    this.by = y;
    this.aiMove();

    if (x + BALL_R < 0) {
      this.as++;
      this.serveAgain();
    } else if (x - BALL_R > 100) {
      this.ps++;
      this.serveAgain();
    }
    this.drawField();          // ★ 每帧重画（Canvas 是命令式，不随 @State 自动重绘）
  }

  /** 电脑跟球：球朝它来时追球，否则回中间 */
  private aiMove(): void {
    const center: number = this.ay + PADDLE_H / 2;
    const target: number = this.vx > 0 ? this.by : 50;
    let d: number = target - center;
    // ★ 球拍每帧最多移动 AI_SPEED（基准帧）⇒ 按 DT 缩放，否则 60fps 下快一倍
    const lim: number = AI_SPEED * DT;
    if (d > lim) {
      d = lim;
    } else if (d < -lim) {
      d = -lim;
    }
    const next: number = this.ay + d;
    const max: number = 100 - PADDLE_H;
    this.ay = next < 0 ? 0 : (next > max ? max : next);
  }

  private serveAgain(): void {
    this.bx = 50;
    this.by = 50;
    this.vx = 0;
    this.vy = 0;
    this.wait = WAIT_TICKS;
    // ★★ 2026-10-14 无尽模式：任一方向到 WIN_PTS ⇒ 进入无尽（不结束）
    if ((this.ps >= WIN_PTS || this.as >= WIN_PTS) && !this.endless) {
      this.endless = true;
    }
    // 无尽里：领先 MARGIN 分才分胜负（否则一直打）
    const lead: number = this.ps - this.as;
    if (this.endless && lead < MARGIN && -lead < MARGIN) {
      this.wait = WAIT_TICKS;   // 继续打，重新发球
    } else if (this.endless ? lead >= MARGIN : this.ps >= WIN_PTS) {
      this.over = true;
      this.won = true;
      this.stopLoop();
      this.finish(true);
    } else if (this.endless ? -lead >= MARGIN : this.as >= WIN_PTS) {
      this.over = true;
      this.won = false;
      this.stopLoop();
      this.finish(false);
    }
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const raw: number = this.ps * 100 - this.as * 20 + (solved ? 200 : 0);
    const r: GameResult = {
      gameId: 'pong',
      solved: solved,
      score: raw > 0 ? raw : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.ps
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private togglePause(): void {
    if (this.over) {
      return;
    }
    this.running = !this.running;
    this.drawField();
   }

  /** 拖动左拍：按上一帧位移走，触边不粘手 */
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
    // ★ 判据 1733：AI 代打开启时如果游戏处于**暂停态**（running=false），球根本不动
    //   —— 直接恢复（等同点「继续」），否则代打永远 0 分
    if (!this.running) {
      this.running = true;
    }
    const max: number = 100 - PADDLE_H;
    // ★ 2026-10-28 修：predictY 给的是**球心**，px 是**拍顶边** ⇒ 要减掉半个拍高，
    //   否则球永远擦着拍子上沿过（提示说"摆到 v"，代打却把拍顶摆到球心，差 9%）
    let v: number = this.vx < 0 ? this.predictY() - PADDLE_H / 2 : 50;
    if (v < 0) {
      v = 0;
    }
    if (v > max) {
      v = max;
    }
    this.px = v;
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 球是纯线性运动 ⇒ 一路模拟到拍面，得到精确落点；打拍边让球拐大角，电脑跟不上
  private predictY(): number {
    let x: number = this.bx;
    let y: number = this.by;
    let vy: number = this.vy;
    const vx: number = this.vx;
    if (vx >= 0) {
      return 50;
    }
    const plane: number = PADDLE_X + PADDLE_W + BALL_R;
    let guard: number = 0;
    while (x > plane && guard < 400) {
      guard++;
      x = x + vx * DT;
      y = y + vy * DT;
      if (y - BALL_R < 0) {
        y = BALL_R;
        vy = Math.abs(vy);
      } else if (y + BALL_R > 100) {
        y = 100 - BALL_R;
        vy = -Math.abs(vy);
      }
    }
    return y;
  }

  /** 提示：报球会落在哪个高度、拍子该摆到哪 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const max: number = 100 - PADDLE_H;
    let v: number = this.predictY() - PADDLE_H / 2;
    if (v < 0) {
      v = 0;
    }
    if (v > max) {
      v = max;
    }
    return Hint.make([],
      TG2('把球拍摆到从上往下 {0}% 的位置（球会落在这儿）', String(Math.round(v))),
      TG2('Put the paddle at {0}% from the top', String(Math.round(v))), t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    // ★ 2026-11-07：实时游戏必须按帧追（球每 16ms 动一次，320ms 一拍追不上 —— 判据 1731）
    this.autoId = Hint.autoRunMs(() => this.autoStep(), TICK_MS, () => { this.autoId = -1; });
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

  private onDrag(offsetY: number): void {
    if (!(this.fieldH > 0) || this.over) {
      return;
    }
    const delta: number = (offsetY - this.dragPrev) / this.fieldH * 100;
    this.dragPrev = offsetY;
    const max: number = 100 - PADDLE_H;
    const next: number = this.px + delta;
    this.px = next < 0 ? 0 : (next > max ? max : next);
    this.drawField();          // ★ 拖拽是手势回调，@State 变了也要自己重画
  }

  private status(): string {
    if (this.over) {
      return this.won ? TG('🎉 你赢了！') : TG('😵 电脑赢了，再来一局');
    }
    if (!this.running) {
      return TG('⏸ 已暂停，点「继续」接着打');
    }
    return this.wait > 0 ? TG('准备发球…') : TG('拖动球场上下移动你的拍子');
  }

  build() {
    Column({ space: Space.sm }) {
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
        Text((TG('你'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.ps), this.langCode))
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
        Text((TG('电脑'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.as), this.langCode))
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
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((WIN_PTS + TG(' 分')))
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

      // ★★★ 2026-11-08（判据 1819，**产品缺陷**不是「命令假阳性」）
      //   `verifier-dev` 真机 dump 里**没有**「暂停/继续、重新开始、状态文本」节点：
      //   球场是 `layoutWeight(1)`，会把 `870→1600` 的剩余高度**全部吃光**，
      //   原先放在球场**之后**的控制行 + 状态文本就被顶出视口（玩家点不到、验证器也读不到）。
      //   ⇒ 修法①（改动最小）：**控制行移到球场之前** —— 球场 `layoutWeight(1)` 会自动占满
      //     "剩余空间"，前面放什么都不会被它挤走；不动底栏（避免和现有 HintBar 冲突）。
      Row({ space: Space.md }) {
        Button(this.running ? TG('暂停') : TG('继续'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.running ? Palette.sky : Palette.emerald)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over)
          .onClick(() => {
            Haptics.tap();
            this.togglePause();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L599'; })
          .onBlur(() => { if (this.tvFocus === 'L599') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L599'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.togglePause(); }); })
        Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
          .focusable(Tv.on())
          .onFocus(() => { this.tvFocus = 'L614'; })
          .onBlur(() => { if (this.tvFocus === 'L614') { this.tvFocus = ''; } })
          .outline(Tv.focusOutline(this.tvFocus === 'L614'))
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(this.status())
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkFaint)
      // ★★★ 2026-11-08（判据 1819）**Stack + position 整体换成 Canvas**：
      //   真机复验证明 `position`（连数值 vp 都不行）在这个 Stack 里没落到布局上
      //   —— 两拍永远贴中线、球无节点；而逻辑与 @State 重绘正常（比分实时 0:0→0:2→0:4）。
      //   球场只有「中线 / 两个矩形 / 一个圆」⇒ Canvas 最稳，且完全不依赖布局引擎。
      Canvas(this.ctx)
        .onReady(() => {
          this.canvasReady = true;
          this.drawField();      // 首帧
        })
        .width('100%')
      .layoutWeight(1)
      .aspectRatio(0.7)
      .backgroundColor(this.theme.isDark ? '#0B0B0B' : '#0F172A')
      .borderRadius(Radius.md)
      .shadow(Shadow.card)
      .clip(true)
      // ★ 2026-11-08 RTL（判据：「按位置摆的不能镜像，按顺序排的必须镜像」）：
      //   球场由 Canvas 用**绝对坐标**绘制（不再经过布局引擎的 position），而 `direction`
      //   只会镜像流式布局 ⇒ 页面切 RTL 后 HUD 会镜像到右边、球台仍该留在左边。
      //   ⇒ 只把**球场**钉成 Ltr（文字 chrome 在父级 Column 里，仍然正常镜像）。
      .direction(Direction.Ltr)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const h: number = newArea.height as number;
        const w: number = newArea.width as number;
        if (h > 0) {
          this.fieldH = h;
        }
        if (w > 0) {
          this.fieldW = w;
        }
        // ★ 尺寸变了（旋转/分屏）立刻按新尺寸重画
        this.drawField();
        // ★ 2026-11-08 自愈：球场已上屏但循环没建起来（timer<0 且没结算）⇒ 补一次启动
        if (this.timer < 0 && !this.over && this.running) {
          hilog.info(0x0000, 'GPong', 'onAreaChange 发现循环丢失 ⇒ 补启动');
          this.startLoop();
        }
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Vertical })
          .onActionStart((e: GestureEvent) => {
            this.dragPrev = 0;
          })
          .onActionUpdate((e: GestureEvent) => {
            this.onDrag(e.offsetY);
          })
      )

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
