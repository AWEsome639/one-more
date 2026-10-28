/**
 * 舒尔特方格 —— 专注力训练
 * 规则：按 1→25 顺序点数字，计时；点错会闪红
 * 通关：点完最后一个数
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
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
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
    }
    .width('100%').height('100%')
  }




}
