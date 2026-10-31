/**
 * 筛法可视化（埃拉托斯特尼筛）—— 看素数筛出来
 *
 * 玩法：自动/单步演示筛法 —— 找到最小的未划掉数 p（它就是素数），
 *       把 p² 起的倍数一个个划掉；p² 超过 100 就收工。
 * 结算：筛完 ⇒ 通关，积分按找出的素数个数给。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 100;
const COLS: number = 10;
const COLS_IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const ROW_IDX: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const TICK_MS: number = 240;
const PRIMES: number = 25;       // 100 以内的素数个数
const BTN_H: number = 44;

@Component
export struct GSieveVisualizer {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（time）：原 TICK_MS=240
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.timeNow(240);
  onFinish: (r: GameResult) => void = () => {};

  @State private comp: boolean[] = [];
  @State private p: number = 0;          // 当前素数（0 = 还没开始）
  @State private k: number = 0;          // 正在划掉的倍数
  @State private found: number = 0;
  @State private crossed: number = 0;
  @State private steps: number = 0;
  @State private done: boolean = false;
  @State private running: boolean = false;

  private timer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSieveVisualizer')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.timeNow(240);
    this.reset();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.running = false;
  }

  private reset(): void {
    this.stop();
    const a: boolean[] = [];
    for (let i = 0; i <= N; i++) {
      a.push(false);
    }
    this.comp = a;
    this.p = 0;
    this.k = 0;
    this.found = 0;
    this.crossed = 0;
    this.steps = 0;
    this.done = false;
    this.finished = false;
    this.startAt = Date.now();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款没有"答错"—— 筛法自己走到底就通关，AI 只负责一下一下点「单步」
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
    if (this.done) {
      return false;
    }
    this.step();
    return !this.done;
  }

  /** 提示：报现在划到哪个素数、划到哪个倍数 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done) {
      return Hint.none('none');
    }
    if (this.p === 0) {
      return Hint.make([], TG('下一个素数是 2，从它的平方 4 开始划'),
        TG('Next prime is 2 — start crossing at 4'), t0);
    }
    if (this.k > N) {
      return Hint.make([], TG2('{0} 的倍数划完了，下一步换下一个素数', this.p),
        TG2('Done with {0} — next prime', this.p), t0);
    }
    return Hint.make([this.k], TG2('正在划 {0} 的倍数：下一个是 {1}', this.p, this.k),
      TG2('Crossing multiples of {0}: next {1}', this.p, this.k), t0);
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

  private play(): void {
    if (this.done) {
      return;
    }
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.running = true;
    this.timer = setInterval(() => {
      this.step();
    }, this.diffTotal);
  }

  private pause(): void {
    this.stop();
  }

  /** 走一步：先定素数，再一个个划倍数 */
  private step(): void {
    if (this.done) {
      return;
    }
    if (this.p === 0) {
      this.p = 2;
      this.k = 4;
      this.found = 1;
      this.steps++;
      return;
    }
    if (this.k <= N) {
      if (!this.comp[this.k]) {
        const next: boolean[] = this.comp.slice();
        next[this.k] = true;
        this.comp = next;
        this.crossed++;
      }
      this.k += this.p;
      this.steps++;
      return;
    }
    // 这个素数划完了，找下一个未划掉的数
    let q: number = this.p + 1;
    while (q <= N && this.comp[q]) {
      q++;
    }
    if (q > N || q * q > N) {
      let cnt: number = 0;
      for (let i = 2; i <= N; i++) {
        if (!this.comp[i]) {
          cnt++;
        }
      }
      this.found = cnt;
      this.done = true;
      this.stop();
      this.finish(true);
      return;
    }
    this.p = q;
    this.found++;
    this.k = q * q;
    this.steps++;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'sieve_visualizer',
      solved: solved,
      score: 100 + this.found * 30,
      durationMs: Date.now() - this.startAt,
      levelReached: this.found
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private numColor(n: number): string {
    if (n < 2) {
      return this.theme.inkFaint;
    }
    if (this.comp[n]) {
      return this.theme.inkFaint;
    }
    return this.theme.isDark ? Palette.lime : Palette.emerald;
  }

  private cellBg(n: number): string {
    if (this.done && !this.comp[n] && n >= 2) {
      return this.theme.isDark ? '#1B3A1B' : '#E7F8EE';
    }
    if (n === this.p) {
      return this.theme.isDark ? '#4A3606' : '#FEF3C7';
    }
    if (this.comp[n]) {
      return this.theme.surfaceAlt;
    }
    return this.theme.surface;
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
        Column({ space: 2 }) {
        Text((TG('已找到素数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found + ' / ' + PRIMES))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('当前 p'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.p === 0 ? '—' : String(this.p)))
        .fontSize(FontSize.md)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.ink)
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已划掉'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.crossed), this.langCode))
        .fontSize(FontSize.md)
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

      Column({ space: 2 }) {
        ForEach(ROW_IDX, (r: number) => {
          Row({ space: 2 }) {
            ForEach(COLS_IDX, (c: number) => {
              Stack() {
              Text(String((r * COLS + c + 1)))
              .fontSize(FontSize.xxs)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.numColor((r * COLS + c + 1)))
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cellBg((r * COLS + c + 1)))
              .borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      // ★★★ 2026-10-30（平板横屏 853×533 真机实测，dump 量的 重开 y=1590）：
      //   70% × 533 = 373vp 棋盘 + 固定部分（标题+HintBar+信息+按钮）
      //   ⇒ 底部按钮超出安全区 1480，**被导航栏遮住点不到**。
      //   ⇒ 改成 45%，与 GBejeweled / GCheckers / GReversi / GCompoundConnect 同一口径。
      .constraintSize({ maxHeight: '45%' })

      Text(this.done
        ? '🎉 筛完！100 以内共 ' + this.found + ' 个素数'
        : (this.p === 0 ? '点「开始」看筛法怎么划掉合数' : '用 ' + this.p + ' 划倍数：' + this.p + '×' + this.p + ' 起'))
        .fontSize(FontSize.sm)
        .fontColor(this.done ? Palette.emerald : this.theme.inkSoft)

      Row({ space: Space.sm }) {
        Button(this.running ? TG('暂停') : TG('开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(this.running ? Palette.amber : Palette.primary)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.done)
          .onClick(() => {
            Haptics.tap();
            if (this.running) {
              this.pause();
            } else {
              this.play();
            }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.running) { this.pause(); } else { this.play(); } }); })
        Button(TG('单步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.teal)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(BTN_H)
          .enabled(!this.done)
          .onClick(() => {
            Haptics.tap();
            this.pause();
            this.step();
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.pause(); this.step(); }); })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor(Color.White)
          .backgroundColor(Palette.lime)
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

      Text(TG2("步数 {0} · 绿字 = 素数，灰底 = 被划掉的合数",Digits(String(this.steps), this.langCode)))
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




}
