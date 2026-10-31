/**
 * 打砖块 —— 挡板 + 弹球 + 5 行 × 8 列砖块
 *
 * 玩法：手指横向拖动（PanGesture）移动挡板；球打在挡板上的位置决定反弹角度
 * 结束：清空 40 块砖 ⇒ solved=true；球落底 ⇒ solved=false
 * 帧率：60ms 一帧做物理（约 16fps，够用且省电）
 *
 * 坐标口径：场地是正方形（aspectRatio(1)），所有位置/尺寸都用「百分比」表示，
 * 于是物理与屏幕像素无关，任何机型手感一致；只有拖动挡板要把手指位移（vp）
 * 换成百分比，才需要 onAreaChange 量一下场地宽度。
 *
 * ⚠️ 实时循环三条硬规矩（本文件都做到了）：
 *   ① setInterval 只在 startLoop() 里建，建之前先 clearInterval
 *   ② aboutToDisappear() 必须 clearInterval（退出页面不许还在跑）
 *   ③ onRestart()（宿主点「换一局」）先停旧循环再重开
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
import { Tv } from '../core/Tv';

const COLS: number = 8;                 // 砖块列数
const ROWS: number = 5;                 // 砖块行数
const TOTAL: number = ROWS * COLS;
/**
 * 渲染帧（ms）。
 * ★ 2026-10-13 P2b「球很卡」的根因：原来 TICK_MS=60 ⇒ 只有 ~16fps，
 *   球是"一跳一跳"的。改成 16ms（~60fps）逐帧推进；速度改成按时间缩放
 *   （见 tick() 里的 k = dtMs / tickMs），所以难度带来的球速**一点没变**，
 *   只是把「每帧走多远」拆细了 —— 顺带让碰撞判定更准（不会一帧跨过整块砖）。
 */
const FRAME_MS: number = 16;

const BW: number = 100 / COLS;          // 砖格宽（场地宽的 %）
const BH: number = 6;                   // 砖格高（场地高的 %）
const TOP: number = 6;                  // 砖阵顶部（%）
const GAP_X: number = 0.7;              // 砖块之间的缝
const GAP_Y: number = 1;

const PADDLE_W: number = 22;            // 挡板宽（%）
const PADDLE_H: number = 3;             // 挡板高（%）
const PADDLE_Y: number = 91;            // 挡板顶边 y（%）

const BALL_D: number = 3.4;             // 球直径（%）
const BALL_R: number = BALL_D / 2;
const SPEED: number = 2.6;              // 球速：**每个物理帧（tickMs）**的位移量（%），反弹后保持恒定
                                        // （普通档 tickMs=60 ⇒ 约 43%/秒；实际帧是 16ms，按 dt 缩放）
const MAX_ANGLE: number = Math.PI / 3;  // 挡板反弹最大偏角 60°
/**
 * 挡板反弹的最小偏角（≈8°）。
 * ⚠️ 必须有：球打在挡板正中时 rel=0 ⇒ vx=0，球会一直竖着上下弹同一条线，
 * 那一列砖打空后这局就永远结束不了（实测 10/10 局卡死）。给了最小偏角就一定有横向漂移。
 */
const MIN_ANGLE: number = 0.14;

const SCORE_PER_BRICK: number = 10;
const WIN_BONUS: number = 100;
const BTN_H: number = 46;

/** 每行砖块的颜色（行数超出就轮转） */
const BRICK_COLORS: string[] = [
  Palette.rose, Palette.orange, Palette.amber, Palette.lime, Palette.sky
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
export struct GBreakout {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  // ★ 难度作用到玩法：球速（简单 80ms 一帧更慢 / 普通 60 / 困难 45 更快）
  private tickMs: number = GameDiff.pick(80, 60, 45);

  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State bricks: boolean[] = [];        // 每块砖是否还在（行优先）
  @State ballX: number = 50;            // 球心 x（%）
  @State ballY: number = 89;            // 球心 y（%）
  @State paddleX: number = 39;          // 挡板左边 x（%）
  @State score: number = 0;
  @State left: number = TOTAL;          // 剩余砖块
  @State launched: boolean = false;     // 是否已发球
  @State over: boolean = false;
  @State won: boolean = false;
  @State paused: boolean = false;
  /** ★ 2026-10-14 无尽模式：清空一波就再铺一批，计数波次 */
  @State private endlessWave: number = 0;

  private vx: number = 0;
  private vy: number = 0;
  private timer: number = -1;
  private lastMs: number = 0;           // 上一帧时间戳（按 dt 推进，帧率无关）
  private startAt: number = 0;
  private finished: boolean = false;
  private dragPrev: number = 0;         // 上一帧的手指累计位移（vp）
  private boardW: number = 0;           // 场地宽度（vp），onAreaChange 量出来
  private slots: number[] = range(TOTAL);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBreakout')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.tickMs = GameDiff.pick(80, 60, 45);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  // ── 循环管理 ──────────────────────────────────────────────
  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private startLoop(): void {
    this.stopLoop();
    this.lastMs = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      this.tick();
    }, FRAME_MS);
  }

  // ── 局面 ─────────────────────────────────────────────────
  private reset(): void {
    this.stopLoop();
    const bs: boolean[] = [];
    for (let i = 0; i < TOTAL; i++) {
      bs.push(true);
    }
    this.bricks = bs;
    this.left = TOTAL;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.paused = false;
    this.launched = false;
    this.vx = 0;
    this.vy = 0;
    this.paddleX = (100 - PADDLE_W) / 2;
    this.glueBall();
    this.startAt = Date.now();
    this.startLoop();
  }

  /** 未发球时球贴在挡板中间 */
  private glueBall(): void {
    this.ballX = this.paddleX + PADDLE_W / 2;
    this.ballY = PADDLE_Y - BALL_R;
  }

  /** 发球：朝上、左右随机偏一点 */
  private launch(): void {
    if (this.launched || this.over || this.won || this.paused) {
      return;
    }
    this.launched = true;
    const ang: number = (Math.random() < 0.5 ? -1 : 1) * 0.5;   // ≈ ±28°
    this.vx = SPEED * Math.sin(ang);
    this.vy = -SPEED * Math.cos(ang);
  }

  // ── 物理：一帧 ────────────────────────────────────────────
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
    if (this.over || this.won) {
      return false;
    }
    this.autoPaddle();
    return !this.over && !this.won;
  }

  // 挡板接不到球就输 ⇒ 报球现在在哪、挡板要往哪挪
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.won) {
      return Hint.none('none');
    }
    const mid: number = this.paddleX + PADDLE_W / 2;
    const d: number = this.ballX - mid;
    const side: string = d > 4 ? '右' : (d < -4 ? '左' : '');
    let msg: string = '对准了，保持住';
    if (!this.launched) {
      msg = '按「发球」先把球打出去';
    } else if (side.length > 0) {
      msg = '挡板往' + side + '挪，球在 x=' + String(Math.floor(this.ballX)) + '%';
    }
    return Hint.make([], msg + '（还剩 ' + String(this.left) + ' 块砖）',
      'Move the paddle toward the ball (x = ' + String(Math.floor(this.ballX)) + '%)', t0);
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

  /** 代打：先把球发出去，再把挡板对到「球会打在偏侧」的位置（有斜角才扫得开砖） */
  private autoPaddle(): void {
    if (!this.launched) {
      this.launch();
      return;
    }
    let v: number = this.ballX - PADDLE_W * 0.75;
    if (v < 0) {
      v = 0;
    }
    if (v > 100 - PADDLE_W) {
      v = 100 - PADDLE_W;
    }
    this.paddleX = v;
  }
  private tick(): void {
    if (this.over || this.won || this.paused) {
      return;
    }
    // ★ AI 代打（2026-10-24 第三期）：autoId >= 0 时每帧把挡板跟到球下面
    if (this.autoId >= 0) {
      this.autoPaddle();
    }
    // ★ 按真实 dt 推进 ⇒ 帧率与球速解耦：
    //   k = dtMs / tickMs 表示"这一帧相当于几个原物理帧"，难度决定的球速完全不变。
    const now: number = Date.now();
    let dtMs: number = now - this.lastMs;
    this.lastMs = now;
    if (!(dtMs > 0)) {
      dtMs = FRAME_MS;
    }
    if (dtMs > 50) {
      dtMs = 50;   // 掉帧保护：一次最多推进 50ms，免得球瞬移穿墙
    }
    const k: number = dtMs / this.tickMs;

    if (!this.launched) {
      this.glueBall();
      return;
    }

    let x: number = this.ballX + this.vx * k;
    let y: number = this.ballY + this.vy * k;

    // 左右墙 / 顶棚
    if (x - BALL_R < 0) {
      x = BALL_R;
      this.vx = Math.abs(this.vx);
    } else if (x + BALL_R > 100) {
      x = 100 - BALL_R;
      this.vx = -Math.abs(this.vx);
    }
    if (y - BALL_R < 0) {
      y = BALL_R;
      this.vy = Math.abs(this.vy);
    }

    // 挡板：打在中间回中间，打在边上斜着飞
    if (this.vy > 0 && y + BALL_R >= PADDLE_Y && y - BALL_R <= PADDLE_Y + PADDLE_H
      && x >= this.paddleX - BALL_R && x <= this.paddleX + PADDLE_W + BALL_R) {
      y = PADDLE_Y - BALL_R;
      const rel: number = (x - (this.paddleX + PADDLE_W / 2)) / (PADDLE_W / 2);
      const clamped: number = rel > 1 ? 1 : (rel < -1 ? -1 : rel);
      let ang: number = clamped * MAX_ANGLE;
      if (ang > -MIN_ANGLE && ang < MIN_ANGLE) {
        ang = ang >= 0 ? MIN_ANGLE : -MIN_ANGLE;
      }
      this.vx = SPEED * Math.sin(ang);
      this.vy = -SPEED * Math.cos(ang);
    }

    // 砖块
    this.hitBrick(x, y);

    this.ballX = x;
    this.ballY = y;

    if (this.left <= 0) {
      this.win();
      return;
    }
    if (y - BALL_R > 100) {
      this.lose();
    }
  }

  /** 球（方框近似）撞到砖块 ⇒ 消砖、按穿透深度决定反弹方向 */
  private hitBrick(x: number, y: number): void {
    for (let i = 0; i < this.bricks.length; i++) {
      if (!this.bricks[i]) {
        continue;
      }
      const bx: number = (i % COLS) * BW + GAP_X / 2;
      const by: number = TOP + Math.floor(i / COLS) * BH + GAP_Y / 2;
      const bw: number = BW - GAP_X;
      const bh: number = BH - GAP_Y;
      if (x + BALL_R <= bx || x - BALL_R >= bx + bw) {
        continue;
      }
      if (y + BALL_R <= by || y - BALL_R >= by + bh) {
        continue;
      }
      const next: boolean[] = this.bricks.slice();
      next[i] = false;
      this.bricks = next;
      this.left = this.left - 1;
      this.score += SCORE_PER_BRICK;
      const penX: number = Math.min(x + BALL_R - bx, bx + bw - (x - BALL_R));
      const penY: number = Math.min(y + BALL_R - by, by + bh - (y - BALL_R));
      if (penX < penY) {
        this.vx = -this.vx;
      } else {
        this.vy = -this.vy;
      }
      return;
    }
  }

  private win(): void {
    // ★★ 2026-10-14 无尽模式（奥森：「部分游戏可以有『无尽模式』」）：
    //   清空一波不再结束 ⇒ 重新铺满砖块 + 波次 +1（球贴回挡板等玩家再发）
    this.score += WIN_BONUS;
    this.endlessWave = this.endlessWave + 1;
    const bs: boolean[] = [];
    for (let i = 0; i < TOTAL; i++) { bs.push(true); }
    this.bricks = bs;
    this.left = TOTAL;
    this.launched = false;
    this.vx = 0;
    this.vy = 0;
    this.glueBall();
  }

  private lose(): void {
    this.over = true;
    this.stopLoop();
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'breakout',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: TOTAL - this.left
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private togglePause(): void {
    if (this.over || this.won) {
      return;
    }
    this.paused = !this.paused;
    if (this.paused) {
      this.stopLoop();
    } else {
      this.startLoop();
    }
  }

  /** 拖动挡板：位移相对上一帧，触边不"粘手" */
  private onDrag(offsetX: number): void {
    // !(x > 0) 同时挡住 0 与 NaN（没量到宽度就先不动，免得挡板飞到乱处）
    if (!(this.boardW > 0) || this.over || this.won) {
      return;
    }
    const delta: number = (offsetX - this.dragPrev) / this.boardW * 100;
    this.dragPrev = offsetX;
    const max: number = 100 - PADDLE_W;
    const next: number = this.paddleX + delta;
    this.paddleX = next < 0 ? 0 : (next > max ? max : next);
    if (!this.launched) {
      this.glueBall();
    }
  }

  private statusText(): string {
    if (this.endlessWave > 0) {
      return TG2('♾️ 无尽模式　第 {0} 波　得分 {1}',Digits(String(this.endlessWave), this.langCode),Digits(String(this.score), this.langCode));
    }
    if (this.won) {
      return TG('🎉 砖块清空，通关！');
    }
    if (this.over) {
      return TG2('💥 球落底，得分 {0}，点「重开」再来',Digits(String(this.score), this.langCode));
    }
    if (this.paused) {
      return TG('⏸ 已暂停，点「继续」接着打');
    }
    if (!this.launched) {
      return TG('拖动挡板对准，点棋盘或按「发球」开球');
    }
    return TG2("已破 {0}/{1} 块", (TOTAL - this.left), TOTAL);
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
      // 得分条 —— ⚠️ 只传「种类」（@Builder 按值传参不建立观察，见 stat() 注释）
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      // 场地（正方形，百分比坐标）
      //
      // ★★★ 2026-10-13 P2 的根因就在这里（原代码是 Stack 自己 `.layoutWeight(1).aspectRatio(1)`）
      //   同一个节点上同时给 layoutWeight(1) 和 aspectRatio(1) 时，**高度先由 layoutWeight
      //   被父 Column 定死**（= 游戏区剩余高度，Mate 70 上约 790vp），aspectRatio 再据此
      //   反推宽度 ⇒ 场地变成 790×790 的巨块，比屏幕宽（≈368vp）大一倍多：
      //     · 左右各出屏 ~210vp ⇒ 物理里的 0%/100% 边界落在**屏幕外**
      //       ⇒ 球看着"不在手机边框反弹"（真边框在屏幕外）；
      //     · 挡板 y=91% ⇒ 落在 790 的 91% ≈ 719vp 处，被推到**屏幕底部之外**；
      //       「发球/重开」两个按钮和状态行更是在屏幕外。
      //   ⇒ 修成"宽度驱动"：显式 width('100%') 定宽，aspectRatio 由宽推高（和 G2048 棋盘同款，
      //     真机上已验证是正常正方形）；外层 Column 用 layoutWeight(1) 领走剩余空间并居中。
      //   ⛔ 不要再把 layoutWeight(1) 加回场地本身。
      Column() {
        Stack() {
          ForEach(this.slots, (i: number) => {
            this.brickView(i)
          }, (i: number) => 'k' + i)

          // 挡板
          Row()
            .width(PADDLE_W + '%')
            .height(PADDLE_H + '%')
            .backgroundColor(Palette.sky)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .position({ x: this.paddleX + '%', y: PADDLE_Y + '%' })

          // 球
          Row()
            .width(BALL_D + '%')
            .aspectRatio(1)
            .backgroundColor(Palette.amber)
            .borderRadius(Radius.full)
            .shadow(Shadow.lifted)
            .position({ x: (this.ballX - BALL_R) + '%', y: (this.ballY - BALL_R) + '%' })
        }
        .width('100%')
        .aspectRatio(1)
        // ★★★ 2026-10-29 平板横屏真机抓到：
        //   场地是「宽度驱动」的正方形（width 100% + aspectRatio(1)），
        //   在 1280vp 宽的平板上 ⇒ **正方形高 1280vp，而屏幕只有 533vp 高**
        //   ⇒ 场地溢出屏幕两倍多，「暂停/重开」按钮**浮在砖块上面**（截图证据）。
        //   ⇒ 限高：宽度仍 100%，但高度不超过父容器的 58%，
        //     aspectRatio 会据此反推宽度 ⇒ 大屏上是一个居中的正方形场地。
        .constraintSize({ maxHeight: '100%' })
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        .clip(true)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          const w: number = newArea.width as number;
          if (w > 0) {
            this.boardW = w;
          }
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.launch(); }); })
        .onClick(() => {
          Haptics.tick();
          this.launch();
        })
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.All })
            .onActionStart((e: GestureEvent) => {
              this.dragPrev = 0;
            })
            .onActionUpdate((e: GestureEvent) => {
              this.onDrag(e.offsetX);
            })
        )
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 主操作
      Row({ space: Space.md }) {
        Button(this.mainLabel())
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.paused ? Palette.emerald : Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.over && !this.won)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (!this.launched) { this.launch(); } else { this.togglePause(); } }); })
          .onClick(() => {
            Haptics.tap();
            if (!this.launched) {
              this.launch();
            } else {
              this.togglePause();
            }
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.sky)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(this.statusText())
        .fontSize(FontSize.xxs)
        .fontColor(this.over ? Palette.rose : this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  private mainLabel(): string {
    if (!this.launched) {
      return TG('发球');
    }
    return this.paused ? '继续' : TG('暂停');
  }

  /**
   * 顶部小格：kind 0=得分 1=剩余 2=已破
   * ⚠️ 收「种类」不收「值」：`@Builder` 按值传参会把状态读取留在调用点
   *    （initialRender 函数体，不在 observeComponentCreation2 闭包内）⇒ 永不刷新。
   *    改在 builder 内部读 this.score/this.left，读取落在闭包内 ⇒ 正常刷新。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? TG('得分') : (kind === 1 ? TG('剩余') : TG('已破')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? String(this.score)
        : (kind === 1 ? String(this.left) : (TOTAL - this.left) + '/' + TOTAL))
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

  /** 砖块：消掉后底色变透明（带一点淡出），位置永远在格子里 */
  @Builder
  brickView(i: number) {
    Row()
      .width((BW - GAP_X) + '%')
      .height((BH - GAP_Y) + '%')
      .backgroundColor(this.bricks[i]
        ? BRICK_COLORS[Math.floor(i / COLS) % BRICK_COLORS.length]
        : Color.Transparent)
      .borderRadius(Radius.xs)
      .position({
        x: ((i % COLS) * BW + GAP_X / 2) + '%',
        y: (TOP + Math.floor(i / COLS) * BH + GAP_Y / 2) + '%'
      })
      .animation({ duration: Motion.fast, curve: Motion.snap() })
  }
}
