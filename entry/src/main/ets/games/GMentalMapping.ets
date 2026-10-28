/**
 * 心理地图 —— 构建空间地图
 *
 * 玩法：屏幕先亮出几个地点（emoji）的位置，记住后它们隐去；
 * 然后按提示「从 A 走到 B 要往哪个方向」，凭记忆在九宫格上点出方向。
 * 答对越多分越高，答错 3 次结束。
 *
 * 原创实现（拾海 2026-10-10）。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N = 3;              // 3×3 地图
const CELLS = N * N;
const SPOTS = 4;          // 记住 4 个地点（难度会覆盖它）
const DIRS = ['↖', '↑', '↗', '←', '', '→', '↙', '↓', '↘'];
const EMOJIS = ['🏠', '🌳', '⛲', '🏫', '🏪', '🚏', '🏥', '🏦', '🎪'];

@Component
export struct GMentalMapping {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：要记住几个地点（简单 3 / 普通 4 / 困难 6）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private spotCount: number = GameDiff.pick(3, 4, 6);
  onFinish: (r: GameResult) => void = () => {};

  @State private spots: string[] = [];     // 每格放什么（'' = 空）
  @State private px: number = 0;
  @State private py: number = 0;
  @State private tx: number = 0;
  @State private ty: number = 0;
  @State private showMap: boolean = true;
  @State private asked: number = 0;
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private over: boolean = false;
  @State private lastOk: number = 0;       // 0 无 1 对 2 错
  private startAt: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GMentalMapping')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.spotCount = GameDiff.pick(3, 4, 6);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  private reset(): void {
    const s: string[] = new Array<string>(CELLS).fill('');
    const pool: string[] = EMOJIS.slice();
    for (let i = 0; i < this.spotCount; i++) {
      const p: number = Math.floor(Math.random() * pool.length);
      const e: string = pool[p];
      pool.splice(p, 1);
      let c: number = Math.floor(Math.random() * CELLS);
      while (s[c] !== '') {
        c = Math.floor(Math.random() * CELLS);
      }
      s[c] = e;
    }
    this.spots = s;
    this.px = 0;
    this.py = 0;
    this.asked = 0;
    this.right = 0;
    this.wrong = 0;
    this.over = false;
    this.lastOk = 0;
    this.startAt = Date.now();
    this.showMap = true;
    this.pickTarget();

    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
    }
    // 3 秒后把地图藏起来
    this.timerId = setTimeout(() => {
      this.showMap = false;
      this.timerId = -1;
    }, 3000);
  }

  /** 随机挑一个目的地（不等于当前位置） */
  private pickTarget(): void {
    let c: number = Math.floor(Math.random() * CELLS);
    let guard: number = 0;
    while ((Math.floor(c / N) === this.py && c % N === this.px) && guard < 40) {
      c = Math.floor(Math.random() * CELLS);
      guard++;
    }
    this.tx = c % N;
    this.ty = Math.floor(c / N);
  }

  /** 当前位置指向目的地的大致方向（八方向） */
  private answerDir(): number {
    const dx: number = this.tx - this.px;
    const dy: number = this.ty - this.py;
    const sx: number = dx === 0 ? 0 : (dx > 0 ? 1 : -1);
    const sy: number = dy === 0 ? 0 : (dy > 0 ? 1 : -1);
    return (sy + 1) * 3 + (sx + 1);
  }

  /** 提示：直接报答案（心象映射，下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.answerDir();
    return Hint.make([k],
      TG2('答案是第 {0} 个', String(k + 1)),
      TG2('The answer is option {0}', String(k + 1)), t0);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案：this.answerDir()   ｜ 守卫取自它自己的 if (...) { return; }
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.over || this.showMap) {
      return true;
    }
    this.answer(this.answerDir());
    return !this.over;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private answer(idx: number): void {
    if (this.over || this.showMap) {
      return;
    }
    this.asked = this.asked + 1;
    if (idx === this.answerDir()) {
      this.right = this.right + 1;
      this.lastOk = 1;
      this.px = this.tx;
      this.py = this.ty;
      this.pickTarget();
      if (this.right >= 8) {
        this.finish(true);
      }
    } else {
      this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.lastOk = 2;
      if (this.wrong >= 3) {
        this.finish(false);
      }
    }
  }

  private finish(solved: boolean): void {
    this.over = true;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'mental_mapping', solved: solved,
      score: this.right * 60 - this.wrong * 20,
      durationMs: Date.now() - this.startAt
    });
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
      Row({ space: Space.lg }) {
        Column({ space: 2 }) {
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text((String(this.wrong) + '/3')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
        Text(Digits(String(this.asked), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        Text((TG('题数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }
        .layoutWeight(1)
      }
      .width('100%')

      Text(this.showMap
        ? '👀 记住这几个地点的位置…'
        : (this.over
          ? (this.right >= 8 ? '🎉 地图全记住了！' : '结束啦，再来一次？')
          : TG2('从当前位置 🧍 到 {0} 该往哪走？', this.spots[this.ty * N + this.tx])))
        .fontSize(FontSize.sm)
        .fontColor(this.showMap ? Palette.amber : this.theme.inkSoft)
        .fontWeight(this.showMap ? FontWeight.Bold : FontWeight.Normal)

      // 地图
      Column({ space: 6 }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: 6 }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Text(this.shown((c), (r))).fontSize(FontSize.xxl)  // ★ 2026-10-14 改用常量（原来硬编码 ⇒ 大字模式下不变）
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.theme.surface)
              .borderRadius(Radius.sm)
              .shadow(Shadow.card)
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
      .padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      // 方向键盘
      Column({ space: Space.xs }) {
        Row({ space: Space.xs }) {
          Text(DIRS[(0)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((0));
          })
          Text(DIRS[(1)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((1));
          })
          Text(DIRS[(2)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((2));
          })
        }
        Row({ space: Space.xs }) {
          Text(DIRS[(3)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((3));
          })
          Text(DIRS[(4)])
          .fontSize(FontSize.lg)
          .fontColor(true ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(true ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((4));
          })
          Text(DIRS[(5)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((5));
          })
        }
        Row({ space: Space.xs }) {
          Text(DIRS[(6)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((6));
          })
          Text(DIRS[(7)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((7));
          })
          Text(DIRS[(8)])
          .fontSize(FontSize.lg)
          .fontColor(false ? this.theme.inkFaint : this.theme.ink)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(Cell.of(44))
          .backgroundColor(false ? this.theme.surfaceAlt : this.theme.surface)
          .borderRadius(Radius.sm)
          .shadow(Shadow.card)
          .onClick(() => {
          Haptics.tick();
          this.answer((8));
          })
        }
      }
      .width('100%')

      if (this.lastOk !== 0) {
        Text(this.lastOk === 1 ? '✅ 对了' : '❌ 错了，它在另一边')
          .fontSize(FontSize.sm)
          .fontColor(this.lastOk === 1 ? Palette.emerald : Palette.rose)
      }


      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
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





  private shown(c: number, r: number): string {
    if (this.px === c && this.py === r) {
      return '🧍';
    }
    if (this.showMap) {
      return this.spots[r * N + c];
    }
    if (this.over) {
      return this.spots[r * N + c];
    }
    return '';
  }


}
