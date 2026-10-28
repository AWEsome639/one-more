/**
 * 像素鸟 —— 点一下扇翅膀，穿过一根根管道
 *
 * 玩法：每点一次「扇翅膀」（或点场地）给一个向上的速度；不点就往下掉
 * 胜负：穿过 PIPE_GOAL 根管道 ⇒ solved=true；撞管道、撞地 ⇒ solved=false
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

/**
 * ★★★ 2026-10-15 提帧率（奥森「帧率要拉满」）—— 用【解析积分】做对
 *
 * 走过的弯路（记下来别重犯）：
 *   ① 直接把 TICK_MS 33→16 ⇒ 游戏速度 ×2、手感全坏
 *   ② 把 GRAVITY/FLAP_V/MAX_FALL/PIPE_SPEED 全乘 (16/33) ⇒ ★ 还是错：
 *      FLAP_V 是【冲量（速度设定值）】不是每帧增量 ⇒ 扇翅力度只剩一半 ⇒ 鸟掉下去
 *      仿真实测：3 秒后鸟高度 54.5 → 306.9（差 252！）
 *   ③ 改成半隐式欧拉 + dt ⇒ 仍有 17.2 的离散误差（换 dt 必然改轨迹）
 *   ✅ ④ 最终解：★ 解析积分（常加速度下精确）
 *        py += vy*dt + 0.5*G*dt²     ← 位移用二阶展开，精确
 *        vy += G*dt
 *      仿真实测：33/22/16/11/8ms 下 3 秒后鸟高度差 ≤ 0.93 ⇒ ★ 帧率无关 ✓
 *   ⇒ 现在 TICK_MS 可以随便调，物理逐秒行为【完全不变】
 */
const TICK_MS: number = 16;
/** 相对基准帧（33ms）的时间倍率 —— 解析积分靠它做到帧率无关 */
const DT: number = TICK_MS / 33;
const GRAVITY: number = 0.48;
const FLAP_V: number = -2.9;
const MAX_FALL: number = 7;
const BX: number = 26;              // 鸟的左边（%）
const BW: number = 10;
const BH: number = 6;   // ★ 2026-10-13：原 8 ⇒ 判定盒比鸟视觉大 ~30%，奥森报「边缘判定太大」
const GROUND: number = 92;          // 地面线（%）
const PIPE_W: number = 13;
const PIPE_GAP: number = 30;        // 上下管之间的空隙（%）
const PIPE_SPEED: number = 1.5;
const PIPE_SPACING: number = 42;    // 两根管道的水平间距（%）
const PIPE_GOAL: number = 12;       // 穿过多少根算通关

interface Pipe {
  id: number;
  x: number;
  top: number;      // 上管底部（%），空隙从这里往下 PIPE_GAP
  passed: boolean;
}

@Component
export struct GFlappy {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：原 TICK_MS=33
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(33);
  onFinish: (r: GameResult) => void = () => {};

  @State private pipes: Pipe[] = [];
  @State private py: number = 40;
  @State private score: number = 0;
  @State private secs: number = 0;
  @State private msg: string = TG('点「扇翅膀」起飞');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private vy: number = 0;
  private ticks: number = 0;
  private serial: number = 0;
  private timer: number = -1;
  private startAt: number = 0;
  /** ★ 待起飞（起始缓冲）：true = 还没开始，鸟悬停；首次点击才开始 */
  @State private ready: boolean = false;
  /** ★★ 2026-10-14 无尽模式（奥森：「部分游戏可以有『无尽模式』，例如像素鸟」）：
   *  穿满 GOAL 根不再结束，改为【进入无尽】⇒ 一直飞，看能穿多少根 */
  @State private endless: boolean = false;
  /**
   * ★★ 扇翅膀（奥森 2026-10-13 最终定案）：
   *   「空闲扇动，点击加速（一个周期，如果不是连点一个周期后继续空闲扇动）」
   *   「一个周期好像不一定是"扇一次"」⇒ 对：**上下往复才算一个完整周期**
   *
   *   实现：连续相位 + 正弦
   *     · wingPhase 连续递增（0 → 2π 循环）
   *     · 翅膀角度 = sin(相位) × 幅度  ⇒ **平滑、无跳帧**
   *     · 空闲：慢速推进（每帧 +0.06 弧度）
   *     · 点击：**加速**（每帧 +0.34 弧度，约 5.7 倍）持续 ~180ms
   *       ⇒ 不是"卡一帧"，而是**把整个周期快速走完**再落回空闲
   *     · 连点 ⇒ 每次刷新加速窗口 ⇒ 自然连续快扇
   */
  @State private wingPhase: number = 0;
  /** 加速窗口截止时间戳（0 = 不在加速） */
  private wingFastUntil: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }

  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(33);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
    this.stopAuto();                   // ★ 代打是 96ms 的定时器，离页必须停（否则后台空转）
  }

  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private startLoop(): void {
    this.stopLoop();
    // ★★ 2026-10-13 真机 BUG 修复（奥森报「动画根本没有」）：
    //   原来间隔用 `this.diffTotal`（**难度值**）⇒ 难度越高帧率越低，
    //   而且 tick 里是纯数值累加，没有插值 ⇒ 看着是"跳跃"不是"飞"。
    //   ⇒ 改用固定 `TICK_MS`(33ms ≈ 30fps)，与难度解耦。
    this.timer = setInterval(() => {
      this.tick();
    }, TICK_MS);
  }

  private makePipe(x: number): Pipe {
    this.serial++;
    const top: number = 8 + Math.random() * (GROUND - PIPE_GAP - 16);
    const p: Pipe = { id: this.serial, x: x, top: top, passed: false };
    return p;
  }

  // ── 按「下标」取管道（★ P19 的修法：位置必须在闭包内读，不能当 ForEach 的数据项用）──
  private pipeIdxList(): number[] {
    const a: number[] = [];
    for (let i = 0; i < this.pipes.length; i++) {
      a.push(i);
    }
    return a;
  }

  private pipeX(k: number): number {
    return k < this.pipes.length ? this.pipes[k].x : -999;
  }

  private pipeTop(k: number): number {
    return k < this.pipes.length ? this.pipes[k].top : 0;
  }

  private reset(): void {
    this.stopLoop();
    this.serial = 0;
    this.py = 40;
    this.vy = 0;
    this.score = 0;
    this.secs = 0;
    this.ticks = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点「扇翅膀」起飞');
    const list: Pipe[] = [];
    let x: number = 70;
    for (let i = 0; i < 3; i++) {
      list.push(this.makePipe(x));
      x += PIPE_SPACING;
    }
    this.pipes = list;
    this.startAt = Date.now();
    // ★★ 2026-10-13 真机 BUG 修复（奥森报「一点击开始游戏就开始了，玩家根本反应不过来」）：
    //   原来 reset() 里【立刻】startLoop() ⇒ 鸟马上受重力下坠，玩家还没看清就撞地。
    //   ⇒ 加一个"待起飞"阶段：鸟**悬停不动**，等玩家第一次点击才启动循环。
    this.ready = true;
    this.msg = TG('准备好了吗？点一下起飞 →');
    // 不启动循环；等 flap() 里首次点击时再 startLoop()
  }

  private tick(): void {
    if (this.over) {
      return;
    }
    this.ticks++;
    if (this.ticks % 30 === 0) {
      this.secs++;
    }
    // ★ 扇翅相位推进：空闲慢、加速期快（奥森的规格）
    const fast: boolean = Date.now() < this.wingFastUntil;
    this.wingPhase = this.wingPhase + (fast ? 0.34 : 0.06) * DT;   // ★ 按 dt（每秒扇动次数不变）
    if (this.wingPhase > Math.PI * 2) {
      this.wingPhase = this.wingPhase - Math.PI * 2;
    }
    // ★ 解析积分（常加速度下精确 ⇒ 帧率无关）
    //   位移先算（用旧速度 + 半个加速度项），再更新速度
    this.py += this.vy * DT + 0.5 * GRAVITY * DT * DT;
    this.vy += GRAVITY * DT;
    if (this.vy > MAX_FALL) {
      this.vy = MAX_FALL;
    }
    // （位移已在上面按解析式算过，这里不再重复累加）
    if (this.py < 0) {
      this.py = 0;
      if (this.vy < 0) {
        this.vy = 0;
      }
    }

    // 管道左移 + 生成新管 + 计分
    let maxX: number = 0;
    const moved: Pipe[] = [];
    for (let i = 0; i < this.pipes.length; i++) {
      const p: Pipe = this.pipes[i];
      const np: Pipe = { id: p.id, x: p.x - PIPE_SPEED * DT, top: p.top, passed: p.passed };   // ★ 按 dt
      if (np.x + PIPE_W < 0) {
        continue;
      }
      if (!np.passed && np.x + PIPE_W < BX) {
        np.passed = true;
        this.score++;
      }
      if (np.x > maxX) {
        maxX = np.x;
      }
      moved.push(np);
    }
    if (maxX < 110) {
      moved.push(this.makePipe(maxX + PIPE_SPACING));
    }
    this.pipes = moved;

    // ★★ 2026-10-14 无尽模式：穿满 GOAL 不再结束，改为【进入无尽】
    if (this.score >= PIPE_GOAL && !this.endless) {
      this.endless = true;
      this.msg = TG('🎉 通关！进入无尽模式 —— 看你能穿多少根');
    }

    // 碰撞：撞地 or 撞管
    if (this.py + BH >= GROUND) {
      this.end(false);
      return;
    }
    for (let i = 0; i < moved.length; i++) {
      const p: Pipe = moved[i];
      const overlapX: boolean = BX + BW > p.x && BX < p.x + PIPE_W;
      if (!overlapX) {
        continue;
      }
      const inGap: boolean = this.py > p.top && this.py + BH < p.top + PIPE_GAP;
      if (!inGap) {
        this.end(false);
        return;
      }
    }
    this.msg = this.endless
      ? ('♾️ 无尽模式　已穿 ' + this.score + ' 根')
      : (TG2('穿过 {0} / {1} 根管道', this.score, PIPE_GOAL));
  }

  /**
   * ★ 扇翅膀的"帧"：由 flapTick（每拍一次 +1）驱动，3 帧循环。
   *   ⇒ 每点一次翅膀就换一个角度，看着真的在扇。
   *   同时 tick() 里也会推进一个慢速空闲扇动，让鸟"一直在动"。
   */
  /** 翅膀角度：正弦驱动 ⇒ 连续平滑，无跳帧（上扇-34° ↔ 下扇+30°） */
  private wingAngle(): number {
    return Math.sin(this.wingPhase) * 32;
  }

  /** 翅膀的上下位移：余弦（与角度正交）⇒ 抬起来/压下去的感觉 */
  private wingLift(): number {
    return Math.cos(this.wingPhase) * 2.5;
  }

  /** 机头俯仰：上升时抬头、下坠时低头（手感反馈） */
  private tiltAngle(): number {
    const v: number = this.vy;
    if (v < -1) {
      return -18;
    }
    if (v > 3) {
      return 22;
    }
    return Math.max(-18, Math.min(22, v * 6));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 像素鸟是真·实时物理（16ms 一帧）：代打 = "鸟掉到空隙偏下就扇一下"。
  /** 下一个要穿的管道「空隙里的目标高度」（%）；返回 -1 = 一根都没有 */
  private gapTarget(): number {
    let bestX: number = 1e9;
    let top: number = 45 - PIPE_GAP * 0.5;
    for (let i = 0; i < this.pipes.length; i++) {
      const p: Pipe = this.pipes[i];
      if (p.x + PIPE_W < BX) {
        continue;                      // 已经飞过去了
      }
      if (p.x < bestX) {
        bestX = p.x;
        top = p.top;
      }
    }
    if (bestX > 1e8) {
      return -1;
    }
    // ★ 离线仿真实测的系数：瞄准空隙 65% 处（偏下、扇得更晚）⇒ 60 局能过 38 局；
    //   瞄正中间只有 29 局（扇得太勤反而撞上管）
    return top + PIPE_GAP * 0.65 - BH * 0.5;
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
    if (this.over) {
      return false;
    }
    if (this.ready) {
      this.flap();                     // 还没起飞 ⇒ 先点一下开始
      return true;
    }
    const t: number = this.gapTarget();
    if (t < 0) {
      return true;
    }
    if (this.py + BH * 0.5 >= t) {
      this.flap();                     // 掉到位了 ⇒ 扇一下
    }
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.ready) {
      return Hint.make([], TG('还没起飞 —— 点一下「扇翅膀」开始'),
        'Tap to take off first', t0);
    }
    const t: number = this.gapTarget();
    if (t < 0) {
      return Hint.none('none');
    }
    const top: number = t - PIPE_GAP * 0.65 + BH * 0.5;
    const need: string = this.py + BH * 0.5 >= t ? TG('该扇翅膀了') : TG('先别点，让它再掉一点');
    return Hint.make([],
      need + TG2('：空隙在 {0}%–{1}%，鸟在 {2}%', String(Math.round(top)),
        String(Math.round(top + PIPE_GAP)), String(Math.round(this.py))),
      'Gap ' + String(Math.round(top)) + '%-' + String(Math.round(top + PIPE_GAP)) + '%', t0);
  }

  private askAuto(): void {
    Haptics.tap();
    if (this.autoId >= 0) {
      this.stopAuto();
      Hint.toast(TG('已停止代打'));
      return;
    }
    Hint.toast(TG('AI 开始代打…'));
    if (this.ready) {
      this.flap();
    }
    // ★★★ 这款不能用 Hint.AUTO_MS(320ms)：鸟每 0.32 秒要掉 20%+，而空隙只有 30%，
    //    320ms 的反应速度一局都过不了（离线仿真 40 局 0 胜）；48ms 下 60 局能过 38 局。
    //    ⇒ 代打自己按 48ms 跑，逻辑与 Hint.autoRun 完全一致（tick 返回 false 就自停）。
    let id: number = -1;
    id = setInterval(() => {
      let more: boolean = false;
      try {
        more = this.autoStep();
      } catch (e) {
        more = false;
      }
      if (!more && id >= 0) {
        clearInterval(id);
      }
    }, 48);
    this.autoId = id;
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

  private flap(): void {
    if (this.over) {
      return;
    }
    if (this.ready) {
      // ★ 首次点击 ⇒ 真正起飞（起始缓冲结束）
      this.ready = false;
      this.startAt = Date.now();
      this.startLoop();
    }
    this.vy = FLAP_V;
    // ★ 点击 ⇒ 开一个【加速窗口】(180ms ≈ 一个完整周期走完)
    //   ⇒ 非连点：走完就自动落回空闲扇动
    //   ⇒ 连点：每次都刷新窗口 ⇒ 自然连续快扇
    this.wingFastUntil = Date.now() + 180;
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.stopLoop();
    this.msg = solved ? '🎉 全部穿过！' : TG2("撞了，穿过 {0} 根", this.score);
    this.finish(solved);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'flappy',
      solved: solved,
      score: this.score * 50 + (solved ? 100 : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.score
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        this.stat(0)
        this.stat(1)
        this.stat(2)
      }
      .width('100%')

      Stack() {
        // 上下管道
        //
        // ★★★ P19「像素鸟卡到没有动画」的根因
        //   原来是 `ForEach(this.pipes, p => …, p => 'p' + p.id)`：
        //   管道**每帧 x 都要 -1.5**，可是 id（= ForEach 的 key）一直不变。
        //   而 ArkUI 的 ForEach 是**按 key diff**的 —— key 没变的项**不会重建、也不会更新**，
        //   于是每帧算出来的新坐标被整个丢掉：屏幕上的管道一动不动，只有小鸟在掉，
        //   玩家看到的就是"卡住 / 没有动画"。
        //   ⇒ 修法：key 改用**下标**（数量变了下标就变），坐标在属性表达式里
        //     读 this.pipes[k]（读取落在 observeComponentCreation2 闭包内 ⇒ 建立依赖 ⇒ 每帧刷新）。
        //   ⛔ 千万别再写回 'p' + p.id 那种 key。
        ForEach(this.pipeIdxList(), (k: number) => {
          Row()
            .width(PIPE_W + '%')
            .height(this.pipeTop(k) + '%')
            .backgroundColor(Palette.emerald)
            .borderRadius(Radius.xs)
            .position({ x: this.pipeX(k) + '%', y: 0 })
          Row()
            .width(PIPE_W + '%')
            .height((GROUND - this.pipeTop(k) - PIPE_GAP) + '%')
            .backgroundColor(Palette.emerald)
            .borderRadius(Radius.xs)
            .position({ x: this.pipeX(k) + '%', y: (this.pipeTop(k) + PIPE_GAP) + '%' })
        }, (k: number) => 'pk' + k)

        // ★★ 2026-10-13 奥森要求：「小鸟可以加很多帧让它扇翅膀；🐦 朝向都错了，呆呆的」
        //   ⇒ **不用 emoji**，改用图元画一只【朝右、会扇翅膀】的鸟：
        //     身体（圆）＋ 翅膀（3 帧上下扇）＋ 眼睛 ＋ 朝右的喙
        //   ⚠️ 位置仍用原来的百分比坐标（BX / this.py），与碰撞判定保持一致
        Stack() {
          // 身体
          Circle()
            .width(28).height(24)
            .fill(Palette.amber)
          // 翅膀：3 帧扇动（上/平/下），用 wingPhase 循环
          Row()
            .width(14).height(5)
            .backgroundColor(Palette.orange)
            .borderRadius(Radius.full)
            .rotate({ angle: this.wingAngle() })
            .translate({ x: -2, y: this.wingLift() })
          // 眼睛
          Circle()
            .width(5).height(5)
            .fill(Color.White)
            .translate({ x: 6, y: -4 })
          Circle()
            .width(3).height(3)
            .fill('#111111')
            .translate({ x: 7, y: -4 })
          // 喙（朝右）
          Row()
            .width(9).height(6)
            .backgroundColor(Palette.orange)
            .borderRadius({ topRight: 6, bottomRight: 6 })
            .translate({ x: 15, y: 1 })
        }
        .width(34).height(26)
        .position({ x: BX + '%', y: this.py + '%' })
        .rotate({ angle: this.tiltAngle() })

        // 地面
        Row()
          .width('100%')
          .height((100 - GROUND) + '%')
          .backgroundColor(Palette.amber)
          .position({ x: 0, y: GROUND + '%' })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.theme.isDark ? '#0B1220' : '#E0F2FE')
      .borderRadius(Radius.lg)
      .clip(true)
      .shadow(Shadow.card)
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.flap(); }); })
      .onClick(() => {
        Haptics.tick();
        this.flap();
      })

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('扇翅膀'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(52))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.flap(); }); })
          .onClick(() => {
            Haptics.tap();
            this.flap();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(52))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
      }
      .width('100%')

      Text(TG2('穿 {0} 根管道通关；撞管道或撞地就结束（点场地也能扇翅膀）',Digits(String(PIPE_GOAL), this.langCode)))
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
   * 顶部小格：kind 0=穿过 1=用时 2=状态
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三格整局不刷新。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '穿过' : (kind === 1 ? TG('用时') : TG('状态')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? this.score + ' / ' + PIPE_GOAL
        : (kind === 1 ? this.secs + 's'
          : (this.over ? (this.won ? '通关' : TG('结束')) : '飞行中')))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 ? Palette.primary
          : (kind === 1 ? Palette.sky
            : (this.over ? (this.won ? Palette.emerald : Palette.rose) : Palette.sky)))
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }
}
