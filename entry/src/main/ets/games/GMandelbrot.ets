/**
 * 分形探索 —— 曼德博集合 🌀
 *
 * 每一题随机给一个放大后的局部图，中心点用 ＋ 标出（其实就是画面正中）。
 * 玩法：判断中心那个点属不属于曼德博集合（迭代不逃逸 = 属于）。
 * 胜负：8 题答对 ≥ 5 题 = 通关
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

const GW: number = 16;      // 横向格子
const GH: number = 12;      // 纵向格子
const MAXIT: number = 120;
const ROUNDS: number = 8;
const PASS: number = 5;
const VIEW_H: number = 0.5; // 视野高度（复平面单位）

const RAMP: string[] = [
  '#FDE68A', '#FCD34D', '#FBBF24', '#FB923C', '#F97316', '#EF4444',
  '#EC4899', '#A855F7', '#6366F1', '#0EA5E9', '#0D9488'
];

/** 逃逸迭代次数；等于 MAXIT 表示没逃逸（视为在集合内） */
function escapeIter(cx: number, cy: number): number {
  let zx: number = 0;
  let zy: number = 0;
  let i: number = 0;
  while (i < MAXIT && zx * zx + zy * zy <= 4) {
    const t: number = zx * zx - zy * zy + cx;
    zy = 2 * zx * zy + cy;
    zx = t;
    i++;
  }
  return i;
}

function fracColor(it: number): string {
  if (it >= MAXIT) {
    return '#0B0B14';
  }
  let k: number = Math.floor(it / 6);
  if (k >= RAMP.length) {
    k = RAMP.length - 1;
  }
  return RAMP[k];
}

@Component
export struct GMandelbrot {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: string[] = [];
  @State private round: number = 0;
  @State private correct: number = 0;
  @State private phase: number = 0;      // 0 = 等作答，1 = 已作答
  @State private inside: boolean = false;
  @State private iter: number = 0;
  @State private lastRight: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;

  private cx: number = -0.5;
  private cy: number = 0;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
    this.reset();
  }

  private reset(): void {
    this.round = 0;
    this.correct = 0;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    this.round = this.round + 1;
    const wantInside: boolean = Math.random() < 0.5;
    let sx: number = wantInside ? -0.5 : 1.0;
    let sy: number = wantInside ? 0 : 1.0;
    for (let k = 0; k < 400; k++) {
      const x: number = -1.6 + Math.random() * 2.2;
      const y: number = -1.1 + Math.random() * 2.2;
      const it: number = escapeIter(x, y);
      if (wantInside && it >= MAXIT) {
        sx = x;
        sy = y;
        break;
      }
      if (!wantInside && it >= 6 && it < 70) {
        sx = x;
        sy = y;
        break;
      }
    }
    this.cx = sx;
    this.cy = sy;
    this.iter = escapeIter(sx, sy);
    this.inside = this.iter >= MAXIT;
    this.buildImage();
    this.phase = 0;
  }

  private buildImage(): void {
    const viewW: number = VIEW_H * GW / GH;
    const dx: number = viewW / GW;
    const dy: number = VIEW_H / GH;
    const out: string[] = [];
    for (let r = 0; r < GH; r++) {
      const y: number = this.cy - VIEW_H / 2 + (r + 0.5) * dy;
      for (let c = 0; c < GW; c++) {
        const x: number = this.cx - viewW / 2 + (c + 0.5) * dx;
        out.push(fracColor(escapeIter(x, y)));
      }
    }
    this.cells = out;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔直取：曼德博集合，答案就在 this.inside
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase === 1) {
      this.next();               // 已作答 ⇒ 替玩家按「下一题」
      return !this.over;
    }
    this.answer(this.inside);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.inside) {
      return Hint.make([],
        TG2('中心点在集合内 —— 迭代 {0} 次仍未逃逸', String(this.iter)),
        TG2('The centre is INSIDE the set — still bounded after {0} iterations', String(this.iter)), t0);
    }
    return Hint.make([],
      TG2('中心点在集合外 —— 第 {0} 次迭代就逃逸了', String(this.iter)),
      TG2('The centre is OUTSIDE the set — it escaped at iteration {0}', String(this.iter)), t0);
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

  private answer(sayInside: boolean): void {
    if (this.over || this.phase !== 0) {
      return;
    }
    this.phase = 1;
    this.lastRight = sayInside === this.inside;
    if (this.lastRight) {
      this.correct = this.correct + 1;
    }
  }

  private next(): void {
    if (this.phase !== 1) {
      return;
    }
    if (this.round >= this.diffTotal) {
      this.over = true;
      this.won = this.correct >= PASS;
      this.finish(this.won);
      return;
    }
    this.newRound();
  }

  private msg(): string {
    if (this.phase === 0) {
      return TG('画面正中的那个点，在集合内还是集合外？');
    }
    const head: string = this.lastRight ? '✅ 答对了！' : '❌ 答错了。';
    if (this.inside) {
      return head + TG2('中心点在集合内（迭代 {0} 次仍未逃逸）', String(this.iter));
    }
    return head + TG2('中心点在集合外（第 {0} 次迭代后逃逸）', String(this.iter));
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'mandelbrot',
      solved: solved,
      score: this.correct * 120 + (solved ? 100 : 0),
      durationMs: Date.now() - this.startAt,
      levelReached: this.correct
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('第几题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.correct), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('过关线'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(PASS) + TG(' 题'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 1 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (r: number) => {
          Row({ space: 1 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], (c: number) => {
              Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells.length > (r * GW + c) ? this.cells[(r * GW + c)] : '#0B0B14').animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (c: number) => 'x' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'y' + r)
      }
      .width('100%')
      .padding(Space.xs)
      .backgroundColor('#0B0B14')
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Text(this.msg())
        .fontSize(FontSize.sm)
        .fontColor(this.phase === 1 ? (this.lastRight ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .textAlign(TextAlign.Center)

      if (this.phase === 0) {
        Row({ space: Space.md }) {
          Button(TG('在集合内'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md).fontColor(Color.White)
            .backgroundColor(Palette.violet).borderRadius(Radius.md)
            .layoutWeight(1).height(Cell.of(44))
            .enabled(!this.over)
            .onClick(() => {
              Haptics.tap();
              this.answer(true);
            })
          Button(TG('在集合外'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
            .fontSize(FontSize.md).fontColor(Color.White)
            .backgroundColor(Palette.orange).borderRadius(Radius.md)
            .layoutWeight(1).height(Cell.of(44))
            .enabled(!this.over)
            .onClick(() => {
              Haptics.tap();
              this.answer(false);
            })
        }
        .width('100%')
        // ★ 2026-10-14 动效：作答后按钮淡出（原来是硬切）
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: Motion.fast, curve: Motion.spring() }))
      } else {
        Button(this.round >= this.diffTotal ? '看结果' : '下一题')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.primary).borderRadius(Radius.md)
          .width('100%').height(Cell.of(44))
          .onClick(() => {
            Haptics.tap();
            this.next();
          })
      }

      
      
      
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(this.theme.ink)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
  }




}
