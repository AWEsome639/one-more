/**
 * 图案锁 —— 一笔连出图案 🎮
 *
 * 规则：3×3 九个点，系统先闪一遍图案，再按同样顺序点出来。
 * 胜负：连对 5 关（图案从 3 个点加到 7 个点）= 通关；点错一个 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const DOTS: number = 9;
const MAXLVL: number = 5;
const PREVIEW_MS: number = 450;

@Component
export struct GLockPattern {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：DOTS 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(DOTS);
  onFinish: (r: GameResult) => void = () => {};

  @State private target: number[] = [];
  @State private input: number[] = [];
  @State private lit: number = -1;      // 预览时点亮的点
  @State private phase: number = 0;     // 0=预览 1=作答 2=结束
  @State private lvl: number = 1;
  @State private peeks: number = 0;
  @State private won: boolean = false;
  /** ★ 结束标记（AI 代打的 autoStep 要认这个；本款原来只有 phase === 2） */
  @State private over: boolean = false;

  private timer: number = -1;
  private delay: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.newGame();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GLockPattern')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  aboutToDisappear(): void {
    this.stopAll();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(DOTS);
    this.newGame();
  }

  private stopAll(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.delay !== -1) {
      clearTimeout(this.delay);
      this.delay = -1;
    }
  }

  private newGame(): void {
    this.stopAll();
    this.lvl = 1;
    this.peeks = 0;
    this.won = false;
    this.over = false;
    this.startAt = Date.now();
    this.startLevel();
  }

  private startLevel(): void {
    this.stopAll();
    const pool: number[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      pool.push(i);
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    this.target = pool.slice(0, 2 + this.lvl);
    this.input = [];
    this.preview();
  }

  /** 依次闪一遍图案，然后进入作答 */
  private preview(): void {
    this.stopAll();
    this.phase = 0;
    this.lit = -1;
    let k: number = 0;
    this.timer = setInterval(() => {
      if (k < this.target.length) {
        this.lit = this.target[k];
        k++;
      } else {
        this.stopAll();
        this.lit = -1;
        this.input = [];
        this.phase = 1;
      }
    }, PREVIEW_MS);
  }

  private peek(): void {
    if (this.phase !== 1) {
      return;
    }
    this.peeks++;
    this.preview();
  }

  /** 代打：下一个该点的点（preview 出来的顺序就存在 this.target 里） */
  private autoCell(): number {
    if (this.phase !== 1 || this.input.length >= this.target.length) {
      return -1;
    }
    return this.target[this.input.length];
  }

  /** 点号 → 「第 r 行第 c 列」（提示用） */
  private dotText(i: number): string {
    return '第' + String(Math.floor(i / 3) + 1) + '行第' + String(i % 3 + 1) + '列';
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
    if (wasOn) { this.newGame(); }
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
    if (this.over || this.autoCell() < 0) {
      return true;
    }
    this.tapDot(this.autoCell());
    return !this.over;
  }

  // 真值就在 this.target（tapDot 比的就是 target[k] !== i）
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 1) {
      return Hint.none('none');
    }
    const cells: number[] = [];
    const parts: string[] = [];
    for (let k = this.input.length; k < this.target.length; k++) {
      cells.push(this.target[k]);
      parts.push(this.dotText(this.target[k]));
    }
    if (cells.length === 0) {
      return Hint.none('none');
    }
    return Hint.make(cells, '按顺序点：' + parts.join(' → '), 'Tap in order: ' + parts.join(' -> '), t0);
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

  private tapDot(i: number): void {
    if (this.phase !== 1) {
      return;
    }
    const k: number = this.input.length;
    if (this.target[k] !== i) {
      this.phase = 2;
      this.stopAll();
      this.finish(false);
      return;
    }
    const ni: number[] = this.input.slice();
    ni.push(i);
    this.input = ni;
    if (ni.length === this.target.length) {
      if (this.lvl >= MAXLVL) {
        this.phase = 2;
        this.won = true;
        this.finish(true);
      } else {
        this.phase = 0;
        this.delay = setTimeout(() => {
          this.delay = -1;
          this.lvl = this.lvl + 1;
          this.startLevel();
        }, 600);
      }
    }
  }

  private finish(solved: boolean): void {
    this.over = true;
    const r: GameResult = {
      gameId: 'lock_pattern',
      solved: solved,
      score: solved ? Math.max(200, 1000 - this.peeks * 50) : (this.lvl - 1) * 150,
      durationMs: Date.now() - this.startAt,
      levelReached: this.lvl
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private dotColor(i: number): string {
    if (this.lit === i) {
      return Palette.sky;
    }
    if (this.input.indexOf(i) >= 0) {
      return Palette.emerald;
    }
    return this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.lg }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0,
        demoOn: this.demoId >= 0
      })

          Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.lvl) + '/' + String(MAXLVL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('图案'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.target.length) + TG(' 点'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已连'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.input.length) + '/' + String(this.target.length))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.md }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.md }) {
            ForEach([0, 1, 2], (c: number) => {
              Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.dotColor((r * 3 + c)))
              .borderRadius(Radius.full)
              .border({
              width: 2,
              color: this.lit === (r * 3 + c) ? Palette.sky : (this.input.indexOf((r * 3 + c)) >= 0 ? Palette.emerald : this.theme.line)
              })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapDot((r * 3 + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tapDot((r * 3 + c));
              })
            }, (c: number) => 'd' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'pr' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '70%' })
      .padding(Space.lg)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg)
      .shadow(Shadow.card)

      Text(this.phase === 0 ? '👀 记住顺序…' :
        (this.phase === 1 ? '按顺序点出来（已连 ' + String(this.input.length) + TG(' 个）')
          : (this.won ? '🎉 五关全过！' : '❌ 点错了，重开一局')))
        .fontSize(FontSize.md)
        .fontColor(this.phase === 2 ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(TG('再看一次'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(this.phase === 1)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.peek(); }); })
          .onClick(() => {
            Haptics.tap();
            this.peek();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.sky).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.newGame(); }); })
          .onClick(() => {
            Haptics.tap();
            this.newGame();
          })
      }
      .width('100%')

      Text(TG2('偷看 {0} 次（每次扣 50 分）',Digits(String(this.peeks), this.langCode)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }




}
