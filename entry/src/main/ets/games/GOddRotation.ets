/**
 * 旋转异类（id: odd_rotation）—— 只有一格转了 90°，其余都停在同一角度 🔄
 * 10 题，答对 ≥ 8 通关；进度：题号 / 答对 / 点错次数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 3;
const ROUNDS: number = 10;
const WIN: number = 8;

/** 顺时针转 90° × times */
function turn(m: boolean[], times: number): boolean[] {
  let o: boolean[] = m.slice();
  for (let t = 0; t < times; t++) {
    const n2: boolean[] = new Array<boolean>(N * N).fill(false);
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        n2[c * N + (N - 1 - r)] = o[r * N + c];
      }
    }
    o = n2;
  }
  return o;
}

/** 六个不对称小图案（哨兵形，转 90° 一定看得出差别） */
function glyphs(): boolean[][] {
  const g = (s: string): boolean[] => s.split('').map((ch: string) => ch === '1');
  return [
    g('100111001'),
    g('010111001'),
    g('110010011'),
    g('001111001'),
    g('100110101'),
    g('010110101')
  ];
}

@Component
export struct GOddRotation {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light(); @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：原 ROUNDS=10
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(10);
  onFinish: (r: GameResult) => void = () => {};
  @State private shapes: number[] = []; @State private odd: number = -1; @State private baseTurn: number = 0;
  @State private round: number = 1; @State private right: number = 0; @State private wrong: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private picked: number = -1; @State private revealed: boolean = false; @State private msg: string = '';
  @State private over: boolean = false; @State private won: boolean = false; private startAt: number = 0;
  private nextTo: number = -1; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GOddRotation')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(10);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    this.clearNext();
    this.round = 1;
    this.right = 0;
    this.wrong = 0;
    this.picked = -1;
    this.revealed = false;
    this.over = false;
    this.won = false;
    this.done = false;
    this.startAt = Date.now();
    this.nextRound();
  }
  private nextRound(): void {
    const pool: boolean[][] = glyphs();
    const a: number = Math.floor(Math.random() * pool.length);
    let b: number = Math.floor(Math.random() * pool.length);
    if (b === a) {
      b = (a + 1) % pool.length;
    }
    const n: number = this.round <= 3 ? 4 : (this.round <= 7 ? 6 : 9);
    const idx: number[] = [];
    for (let i = 0; i < n; i++) {
      idx.push(a);
    }
    const oi: number = Math.floor(Math.random() * n);
    idx[oi] = b;
    this.shapes = idx;
    this.odd = oi;
    this.baseTurn = Math.floor(Math.random() * 4);
    this.picked = -1;
    this.revealed = false;
    this.msg = TG('只有一格转了 90°，点它 👆');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 变体⑤：守卫是布尔值 this.revealed（不是 picked >= 0）
  /** 提示：报答案（字段 this.odd） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.odd],
      TG2('答案是第 {0} 个', String(this.odd + 1)),
      TG2('The answer is option {0}', String(this.odd + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    if (this.revealed) {
      return true;              // 这题已经揭示过答案，等定时器进下一题
    }
    this.tap(this.odd);
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
    this.autoId = Hint.autoRun(() => this.autoStep());
  }

  private stopAuto(): void {
    if (this.autoId >= 0) {
      Hint.autoStop(this.autoId);
      this.autoId = -1;
    }
  }

  private tap(i: number): void {
    if (this.over || this.revealed) { return; }
    this.picked = i;
    this.revealed = true;
    if (i === this.odd) {
      this.right = this.right + 1;
      this.msg = TG2('✅ 就是它 · 答对 {0}/{1}', String(this.right), String(this.diffTotal));
    } else {
      this.wrong = this.wrong + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
      this.msg = TG('❌ 不是这格，再比一比方向');
    }
    this.clearNext();
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.over = true;
        this.done = true;
        this.won = this.right >= WIN;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
        this.finish();
        return;
      }
      this.round = this.round + 1;
      this.nextRound();
    }, 720);
  }
  private finish(): void {
    const r: GameResult = {
      gameId: 'odd_rotation', solved: this.won,
      score: this.right * 100 + (this.won ? 200 : 0) - this.wrong * 30,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
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
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('点错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.sm }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.sm }) {
            ForEach([0, 1, 2], (c: number) => {
              Stack() {
              Column({ space: 2 }) {
              ForEach([0, 1, 2], (r: number) => {
              Row({ space: 2 }) {
              ForEach([0, 1, 2], (c: number) => {
              Stack()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.on(((r * 3 + c)), (r * N + c), ((r * 3 + c < this.shapes.length))) ? this.colorOf(((r * 3 + c))) : this.theme.surfaceAlt).animation({ duration: Motion.fast, curve: Motion.snap() })
              .borderRadius(2)
              }, (c: number) => 'c' + c)
              }
              }, (r: number) => 'r' + r)
              }
              .width('70%')
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.bgOf((r * 3 + c)))
              .borderRadius(Radius.md)
              .borderWidth(this.revealed && (r * 3 + c) === this.odd ? 2 : 0)
              .borderColor(Palette.orange)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => { Haptics.tick(); this.tap((r * 3 + c)); })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * 3 + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      Text(this.msg)
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .width('100%')
        .textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.orange)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => { Haptics.tap(); this.reset(); })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
      Text(TG('判定：10 题答对 ≥ 8 题 · 图案角度每轮随机，别看错基准'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }



  /** 第 i 格第 j 个小方块是否点亮（异类那格多转 90°） */
  private on(i: number, j: number, usable: boolean): boolean {
    if (!usable) {
      return false;
    }
    const pool: boolean[][] = glyphs();
    const which: number = i < this.shapes.length ? this.shapes[i] : 0;
    const extra: number = i === this.odd ? 1 : 0;
    const m: boolean[] = turn(pool[which], this.baseTurn + extra);
    return m[j];
  }
  private colorOf(i: number): string {
    if (!this.revealed) {
      return this.theme.ink;
    }
    if (i === this.odd) {
      return Palette.orange;
    }
    return this.picked === i ? Palette.rose : this.theme.inkFaint;
  }
  private bgOf(i: number): string {
    if (this.revealed && i === this.odd) {
      return this.theme.isDark ? '#2A1C08' : '#FEF3C7';
    }
    return this.theme.surface;
  }
}
