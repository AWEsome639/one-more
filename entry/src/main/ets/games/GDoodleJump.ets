/**
 * 跳一跳 —— 踩平台往上跳，掉下去就结束
 *
 * 玩法：落点自动弹起（踩到平台就弹）；用 ◀ ▶ 左右平移找下一个平台；镜头随高度上移
 * 胜负：爬到 GOAL 米 ⇒ solved=true；掉出屏幕底部 ⇒ solved=false
 * 坐标口径：整个场地用「百分比」表示（x% 横向、y% 纵向），物理与机型像素无关
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
 * ★★★ 2026-10-15 提帧率（同 GFlappy 的解法）：30fps → 60fps
 *   ★ 关键：用【解析积分】+【DT 缩放】，而不是缩放物理常量
 *     （缩放常量对"冲量"类数值 JUMP_V 是错的 ⇒ 会改手感）
 *   仿真复核：不同帧率下 3 秒后状态差 < 1 单位 ⇒ 帧率无关 ✓
 */
const TICK_MS: number = 16;
/** 相对基准帧（33ms）的时间倍率 */
const DT: number = TICK_MS / 33;
const GRAVITY: number = 0.42;
const JUMP_V: number = -3.9;        // 弹起初速（apex ≈ 18 格，必须大于 GAP_MAX）
const MAX_FALL: number = 8;
const MOVE_X: number = 11;
const CAM_Y: number = 52;           // 镜头把玩家按在这个高度（%）
const P_W: number = 10;             // 玩家宽（%）
const P_H: number = 9;              // 玩家高（%）
const PLAT_H: number = 2.6;         // 平台高（%）
const PLAT_MIN: number = 15;        // 平台最小宽（%）
const PLAT_MAX: number = 26;        // 平台最大宽（%）
const GAP_MIN: number = 10;         // 平台纵向间距
const GAP_MAX: number = 16;
const GOAL_M: number = 500;         // 通关高度（虚拟米）
/** 左右滑动判定阈值（vp） */
const DRAG_MIN: number = 18;

interface Platform {
  id: number;
  x: number;
  y: number;
  w: number;
}

@Component
export struct GDoodleJump {
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

  @State private plats: Platform[] = [];
  @State private px: number = 50;
  @State private py: number = 70;
  @State private climbed: number = 0;
  @State private msg: string = TG('踩平台往上跳，用 ◀ ▶ 移动');
  @State private over: boolean = false;
  /** ★ 待操作（起始缓冲）：true = 角色静止，等第一次滑动才开始 */
  @State private ready: boolean = false;
  /** ★ 2026-10-14 无尽模式：爬到 GOAL 后继续，看能爬多高 */
  @State private endless: boolean = false;
  @State private won: boolean = false;
  @State private running: boolean = false;

  private vy: number = 0;
  private serial: number = 0;
  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;
  /** ★ 拖动起点（vp）：滑动一次走一步，连续拖就连续走 */
  private dragX: number = 0;

  // ── 按「下标」取平台（★ P20 的修法：坐标必须在闭包内读，不能当 ForEach 数据项用）──
  private platIdxList(): number[] {
    const a: number[] = [];
    for (let i = 0; i < this.plats.length; i++) {
      a.push(i);
    }
    return a;
  }

  private platX(k: number): number {
    return k < this.plats.length ? this.plats[k].x : -999;
  }

  private platY(k: number): number {
    return k < this.plats.length ? this.plats[k].y : -999;
  }

  private platW(k: number): number {
    return k < this.plats.length ? this.plats[k].w : 0;
  }

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDoodleJump')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(33);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stopLoop();
  }

  private stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private startLoop(): void {
    this.stopLoop();
    this.timer = setInterval(() => {
      this.tick();
    }, this.diffTotal);
  }

  private makePlat(x: number, y: number): Platform {
    this.serial++;
    const w: number = PLAT_MIN + Math.random() * (PLAT_MAX - PLAT_MIN);
    const p: Platform = { id: this.serial, x: x, y: y, w: w };
    return p;
  }

  private reset(): void {
    this.stopLoop();
    this.serial = 0;
    this.px = 50;
    this.py = 70;
    this.vy = 0;
    this.climbed = 0;
    this.over = false;
    this.won = false;
    this.running = true;
    this.finished = false;
    this.msg = TG('踩平台往上跳，用 ◀ ▶ 移动');
    const list: Platform[] = [];
    const first: Platform = this.makePlat(30, 85);
    first.w = 40;                     // 开局那块要够宽，保证一定踩得到
    list.push(first);
    let y: number = 85;
    while (y > -20) {
      y -= GAP_MIN + Math.random() * (GAP_MAX - GAP_MIN);
      list.push(this.makePlat(Math.random() * 84, y));
    }
    this.plats = list;
    // ★★ 2026-10-13 真机体验修复（和像素鸟/贪吃蛇同一个病）：
    //   原来 reset() 里【立刻】startLoop() ⇒ 角色马上开始跳，玩家还没看清平台。
    //   ⇒ 改成「待操作」：角色静止，等第一次左右滑动才开始。
    this.ready = true;
    this.startAt = Date.now();
    // 不启动循环；等 move() 里首次操作时再 startLoop()
  }

  private tick(): void {
    if (this.over || !this.running) {
      return;
    }
    // ★ AI 代打（2026-10-24 第三期）：autoId >= 0 时每帧自动往平台挪一下
    if (this.autoId >= 0) {
      this.move(this.autoDir());
    }
    const prevBottom: number = this.py + P_H;
    // ★ 解析积分（精确 ⇒ 帧率无关）
    this.py += this.vy * DT + 0.5 * GRAVITY * DT * DT;
    this.vy += GRAVITY * DT;
    if (this.vy > MAX_FALL) {
      this.vy = MAX_FALL;
    }
    // （位移已按解析式算过）
    const bottom: number = this.py + P_H;

    // 下落时穿过平台顶面 ⇒ 弹起
    if (this.vy > 0) {
      const list: Platform[] = this.plats;
      for (let i = 0; i < list.length; i++) {
        const p: Platform = list[i];
        const hitX: boolean = this.px + P_W / 2 > p.x && this.px - P_W / 2 < p.x + p.w;
        const cross: boolean = prevBottom <= p.y && bottom >= p.y;
        if (hitX && cross) {
          this.py = p.y - P_H;
          this.vy = JUMP_V;
          break;
        }
      }
    }

    // 镜头跟着往上推
    if (this.py < CAM_Y) {
      const d: number = CAM_Y - this.py;
      this.py = CAM_Y;
      this.climbed += d;
      const moved: Platform[] = [];
      for (let i = 0; i < this.plats.length; i++) {
        const p: Platform = this.plats[i];
        const np: Platform = { id: p.id, x: p.x, y: p.y + d, w: p.w };
        if (np.y < 112) {
          moved.push(np);
        }
      }
      // 顶部补新平台
      let top: number = 200;
      for (let i = 0; i < moved.length; i++) {
        if (moved[i].y < top) {
          top = moved[i].y;
        }
      }
      while (top > -20) {
        top -= GAP_MIN + Math.random() * (GAP_MAX - GAP_MIN);
        moved.push(this.makePlat(Math.random() * 84, top));
      }
      this.plats = moved;
    }

    // ★★ 2026-10-14 无尽模式：爬到 GOAL 不再结束，改为【进入无尽】
    if (this.climbed >= GOAL_M && !this.endless) {
      this.endless = true;
      this.msg = TG2('🎉 爬到 {0} 米！进入无尽模式 —— 看你能爬多高', GOAL_M);
    }
    if (this.py > 104) {
      this.over = true;
      this.won = false;
      this.running = false;
      this.stopLoop();
      this.msg = TG2('掉下去了，高度 {0} 米', Math.floor(this.climbed));
      this.finish(false);
    }
  }

  /** 代打：下一步该往哪边挪（1 右 / -1 左 / 0 不动）—— 盯最近那块能踩到的平台 */
  private autoDir(): number {
    const feet: number = this.py + P_H;
    let best: number = -1;
    let bestDy: number = 999;
    for (let i = 0; i < this.plats.length; i++) {
      const dy: number = feet - this.plats[i].y;
      if (dy <= 0 || dy > 17) {
        continue;
      }
      if (dy < bestDy) {
        bestDy = dy;
        best = i;
      }
    }
    if (best < 0) {
      bestDy = 999;
      for (let i = 0; i < this.plats.length; i++) {
        const dy: number = feet - this.plats[i].y;
        if (dy <= 0) {
          continue;
        }
        if (dy < bestDy) {
          bestDy = dy;
          best = i;
        }
      }
    }
    if (best < 0) {
      return 0;
    }
    const cx: number = this.plats[best].x + this.plats[best].w / 2;
    const d: number = cx - this.px;
    if (d > 3) {
      return 1;
    }
    if (d < -3) {
      return -1;
    }
    return 0;
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
    if (this.over) {
      return false;
    }
    if (this.over || this.won) {
      return true;
    }
    this.move(this.autoDir());
    return !this.over;
  }

  // 踩到平台就弹起 ⇒ 报「往哪边挪、去踩哪块平台」
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.won) {
      return Hint.none('none');
    }
    const d: number = this.autoDir();
    const where: string = d > 0 ? '右' : (d < 0 ? '左' : '');
    const msg: string = where.length > 0 ? '往' + where + '挪，对准上面那块平台' : '位置正好，等它弹上去';
    return Hint.make([], msg + '（已爬 ' + String(Math.floor(this.climbed)) + ' 米）',
      'Move ' + (where.length > 0 ? where : 'to stay centered') + ' to land on the platform above', t0);
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

  private move(dir: number): void {
    // ★ 首次操作 ⇒ 真正开始（起始缓冲结束）
    if (this.ready) {
      this.ready = false;
      this.startAt = Date.now();
      this.startLoop();
    }
    if (this.over) {
      return;
    }
    this.px += dir * MOVE_X * DT;   // ★ 按 dt
    if (this.px < 2) {
      this.px = 98;
    } else if (this.px > 98) {
      this.px = 2;
    }
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'doodle_jump',
      solved: solved,
      score: Math.floor(this.climbed),
      durationMs: Date.now() - this.startAt,
      levelReached: Math.floor(this.climbed)
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
        // ★★★ P20「跳一跳也很卡」的根因（和 P19 像素鸟同一个坑）
        //   原来 `ForEach(this.plats, p => …, p => 'p' + p.id)`：平台每帧都要往上移动，
        //   但 id（= ForEach 的 key）不变 ⇒ ArkUI 按 key diff，**key 没变的项不更新** ⇒
        //   平台在屏幕上**完全不移动**，只有青蛙在动 —— 看着就是"卡住了"。
        //   ⇒ 改成 key = 下标，坐标在属性表达式里读 this.plats[k]（读取落在观察闭包内）。
        ForEach(this.platIdxList(), (k: number) => {
          Row()
            .width(this.platW(k) + '%')
            .height(PLAT_H + '%')
            .backgroundColor(this.theme.isDark ? Palette.violet : Palette.teal)
            .borderRadius(Radius.xs)
            .shadow(Shadow.card)
            .position({ x: this.platX(k) + '%', y: this.platY(k) + '%' })
        }, (k: number) => 'pk' + k)

        // ★★ 2026-10-13 奥森：「很多地方你都可以画噢～」
        //   ⇒ 把 🐸 emoji 换成【图元画的小青蛙】：
        //     身体（椭圆）+ 两只眼（白底黑瞳）+ 腮红 + 两条后腿
        //   ⚠️ 位置/尺寸仍用原来的 px / py / P_W / P_H，与碰撞判定保持一致
        Stack() {
          // 后腿（两条）
          Row().width(5).height(4).backgroundColor(Palette.emerald)
            .borderRadius(Radius.full).translate({ x: -6, y: 6 })
          Row().width(5).height(4).backgroundColor(Palette.emerald)
            .borderRadius(Radius.full).translate({ x: 6, y: 6 })
          // 身体
          Circle().width(20).height(18).fill(Palette.emerald)
          // 眼睛（白底）
          Circle().width(7).height(7).fill(Color.White).translate({ x: -4, y: -6 })
          Circle().width(7).height(7).fill(Color.White).translate({ x: 4, y: -6 })
          // 瞳孔
          Circle().width(3).height(3).fill('#111111').translate({ x: -4, y: -6 })
          Circle().width(3).height(3).fill('#111111').translate({ x: 4, y: -6 })
          // 腮红
          Circle().width(4).height(3).fill(Palette.rose).translate({ x: -8, y: 2 })
          Circle().width(4).height(3).fill(Palette.rose).translate({ x: 8, y: 2 })
        }
        .width(24).height(20)
        .position({ x: (this.px - P_W / 2) + '%', y: this.py + '%' })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.lg)
      .clip(true)
      .shadow(Shadow.card)
      // ★ P9 同类：手指在场地里左右拖 = 青蛙左右走（不用去够下面两个按钮）
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 6 })
          .onActionStart(() => {
            this.dragX = 0;
          })
          .onActionUpdate((e: GestureEvent) => {
            const dx: number = e.offsetX - this.dragX;
            if (Math.abs(dx) < DRAG_MIN) {
              return;
            }
            this.dragX = e.offsetX;
            this.move(dx > 0 ? 1 : -1);
          })
          .onActionEnd(() => {
            this.dragX = 0;
          })
      )

      Row({ space: Space.md }) {
        Button(TG('◀ 左'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(52))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move(-1); }); })
          .onClick(() => {
            Haptics.tap();
            this.move(-1);
          })
        Button(TG('▶ 右'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surface)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(52))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.move(1); }); })
          .onClick(() => {
            Haptics.tap();
            this.move(1);
          })
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('踩到平台自动弹起，爬到 {0} 米通关；掉出底部就结束',Digits(String(GOAL_M), this.langCode)))
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
   * 顶部小格：kind 0=高度 1=目标 2=状态
   * ⚠️ 收「种类」不收「值」：@Builder 按值传参不建立 ArkUI 观察 ⇒ 传值这三格整局不刷新。
   */
  @Builder
  stat(kind: number) {
    Column({ space: 2 }) {
      Text(kind === 0 ? '高度' : (kind === 1 ? TG('目标') : TG('状态')))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      Text(kind === 0 ? Math.floor(this.climbed) + ' 米'
        : (kind === 1 ? GOAL_M + ' 米'
          : (this.over ? (this.won ? '通关' : TG('结束')) : '进行中')))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold)
        .fontColor(kind === 0 ? Palette.primary
          : (kind === 1 ? Palette.emerald
            : (this.over ? (this.won ? Palette.emerald : Palette.rose) : Palette.sky)))
    }
    .layoutWeight(1)
    .padding(Space.sm)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
  }
}
