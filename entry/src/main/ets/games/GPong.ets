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
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
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
  private startAt: number = 0;
  private finished: boolean = false;
  private fieldH: number = 0;
  private dragPrev: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GPong')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(40);
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
  }

  /** 从中间发球，方向随机 */
  private launch(): void {
    const dir: number = Math.random() < 0.5 ? -1 : 1;
    const tilt: number = (Math.random() - 0.5) * 1.2;
    this.vx = SPEED * dir * Math.cos(tilt);
    this.vy = SPEED * Math.sin(tilt);
  }

  private tick(): void {
    if (this.over || !this.running) {
      return;
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
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
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
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
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

  private onDrag(offsetY: number): void {
    if (!(this.fieldH > 0) || this.over) {
      return;
    }
    const delta: number = (offsetY - this.dragPrev) / this.fieldH * 100;
    this.dragPrev = offsetY;
    const max: number = 100 - PADDLE_H;
    const next: number = this.px + delta;
    this.px = next < 0 ? 0 : (next > max ? max : next);
  }

  private status(): string {
    if (this.over) {
      return this.won ? '🎉 你赢了！' : '😵 电脑赢了，再来一局';
    }
    if (!this.running) {
      return TG('⏸ 已暂停，点「继续」接着打');
    }
    return this.wait > 0 ? '准备发球…' : '拖动球场上下移动你的拍子';
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text(('你')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
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

      Stack({ alignContent: Alignment.TopStart }) {
        // 中线
        ForEach(NET, (i: number) => {
          Row()
            .width('1%')
            .height('4%')
            .backgroundColor(this.theme.line)
            .borderRadius(Radius.full)
            .position({ x: '49.5%', y: (2 + i * 10) + '%' })
        }, (i: number) => 'n' + i)

        // 左拍
        Row()
          .width(PADDLE_W + '%')
          .height(PADDLE_H + '%')
          .backgroundColor(Palette.violet)
          .borderRadius(Radius.full)
          .shadow(Shadow.card)
          .position({ x: PADDLE_X + '%', y: this.px + '%' })

        // 右拍
        Row()
          .width(PADDLE_W + '%')
          .height(PADDLE_H + '%')
          .backgroundColor(Palette.sky)
          .borderRadius(Radius.full)
          .shadow(Shadow.card)
          .position({ x: AI_X + '%', y: this.ay + '%' })

        // 球
        Row()
          .width(BALL_D + '%')
          .aspectRatio(1)
          .backgroundColor(Palette.amber)
          .borderRadius(Radius.full)
          .shadow(Shadow.lifted)
          .position({ x: (this.bx - BALL_R) + '%', y: (this.by - BALL_R) + '%' })
      }
      .width('100%')
      .layoutWeight(1)
      .aspectRatio(0.7)
      .backgroundColor(this.theme.isDark ? '#0B0B0B' : '#0F172A')
      .borderRadius(Radius.md)
      .shadow(Shadow.card)
      .clip(true)
      .onAreaChange((oldArea: Area, newArea: Area) => {
        const h: number = newArea.height as number;
        if (h > 0) {
          this.fieldH = h;
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

      Row({ space: Space.md }) {
        Button(this.running ? TG('暂停') : '继续')
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
          .focusBox(Tv.box())
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
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      }
      .width('100%')

      Text(this.status())
        .fontSize(FontSize.xxs)
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
