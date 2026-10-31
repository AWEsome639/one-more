/**
 * 舒尔特方格 —— 专注力训练
 * 规则：按 1→25 顺序点数字，计时；点错会闪红
 * 通关：点完最后一个数
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const SIZE: number = 5;

@Component
export struct GSchulte {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 SIZE=5；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(5);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private nums: number[] = [];
  @State private next: number = 1;
  @State private elapsed: number = 0;
  @State private wrongIdx: number = -1;
  @State private done: boolean = false;

  private startAt: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GSchulte')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(5);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  private reset(): void {
    const a: number[] = [];
    for (let i = 1; i <= this.diffTotal * this.diffTotal; i++) {
      a.push(i);
    }
    // Fisher–Yates 洗牌
    for (let i = a.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    this.nums = a;
    this.next = 1;
    this.elapsed = 0;
    this.wrongIdx = -1;
    this.done = false;
    this.startAt = Date.now();
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.timer = setInterval(() => {
      if (!this.done) {
        this.elapsed = Date.now() - this.startAt;
      }
    }, 100);
  }

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
    if (this.done) {
      return false;
    }
    const p: number = this.nums.indexOf(this.next);
    if (p < 0) {
      return false;
    }
    this.tap(this.next, p);
    return !this.done;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.done) {
      return Hint.none('none');
    }
    const p: number = this.nums.indexOf(this.next);
    if (p < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(p / this.diffTotal) + 1;
    const c: number = p % this.diffTotal + 1;
    return Hint.make([p],
      TG2('下一个该点 {0}：在第 {1} 行第 {2} 列', this.next, r, c),
      TG2('Next is {0} — row {1}, column {2}', this.next, r, c), t0);
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

  private tap(v: number, i: number): void {
    if (this.done) {
      return;
    }
    if (v === this.next) {
      this.next++;
      this.wrongIdx = -1;
      if (this.next > this.diffTotal * this.diffTotal) {
        this.done = true;
        if (this.timer >= 0) {
          clearInterval(this.timer);
        }
        this.elapsed = Date.now() - this.startAt;
        const sec: number = this.elapsed / 1000;
        // 越快分越高：20 秒满分 1000，线性递减，下限 100
        const sc: number = Math.max(100, Math.round(1000 - (sec - 20) * 20));
        const r: GameResult = {
          gameId: 'schulte',
          solved: true,
          score: sc,
          durationMs: this.elapsed
        };
        LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
        this.onFinish(r);
      }
    } else {
      this.wrongIdx = i;
    }
  }

  build() {
    Column({ space: Space.lg }) {
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
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.next), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('用时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.elapsed / 1000).toFixed(1) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.next - 1 + '/' + this.diffTotal * this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.sm }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text((this.nums[r * this.diffTotal + c]) === undefined ? '' : String((this.nums[r * this.diffTotal + c])))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor((this.nums[r * this.diffTotal + c]) < this.next ? Palette.emerald : this.theme.ink)
              }
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.wrongIdx === (r * this.diffTotal + c) ? '#33EF4444' : this.theme.surface)
              .borderRadius(Radius.md)
              .shadow(Shadow.card)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              .onClick(() => {
              Haptics.tick();
              this.tap((this.nums[r * this.diffTotal + c]), (r * this.diffTotal + c));
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((this.nums[r * this.diffTotal + c]), (r * this.diffTotal + c)); }); })
            }, (c: number) => 'c' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.done ? '🎉 完成！' : '按顺序点：' + this.next)
        .fontSize(FontSize.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.done ? Palette.emerald : Palette.primary)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.primary).borderRadius(Radius.md)
        .width('100%').height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%')
  }




}
