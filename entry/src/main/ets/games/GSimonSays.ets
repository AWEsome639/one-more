/**
 * 西蒙说（Simon Says）—— 跟着做动作
 *
 * 玩法：四个色块依次亮起，按同样的顺序点回去；每过一关序列加长一位。
 * 结算：按错 ⇒ 失败；撑到第 12 关 ⇒ 通关。
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

const PADS: number = 4;
const WIN_LEN: number = 12;   // 难度会覆盖它        // 通关长度
const SHOW_TICK: number = 430;     // 演示时每半拍
const FLASH_MS: number = 180;      // 点中时的闪光
const GAP_MS: number = 700;        // 过关后到下一关
const PAD_COLORS: string[] = [Palette.emerald, Palette.rose, Palette.sky, Palette.amber];
const PAD_ICON: string[] = ['🐸', '🍎', '💧', '⭐'];
const IDX: number[] = [0, 1, 2, 3];

@Component
export struct GSimonSays {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  // ★ 难度作用到玩法：通关序列长度（简单 8 步 / 普通 12 / 困难 16）
  private winLen: number = GameDiff.pick(8, 12, 16);

  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private lit: number = -1;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private len: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private phase: string = 'show';    // show | input | over
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private seq: number[] = [];
  private showIdx: number = -1;
  private inputIdx: number = 0;
  private showTimer: number = -1;
  private flashTimer: number = -1;
  private gapTimer: number = -1;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
  }

  /** 宿主点了「换一局」 */
  onRestart(): void {
    this.winLen = GameDiff.pick(8, 12, 16);
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
      this.showTimer = -1;
    }
    if (this.flashTimer >= 0) {
      clearTimeout(this.flashTimer);
      this.flashTimer = -1;
    }
    if (this.gapTimer >= 0) {
      clearTimeout(this.gapTimer);
      this.gapTimer = -1;
    }
  }

  private reset(): void {
    this.clearTimers();
    this.seq = [];
    this.len = 0;
    this.score = 0;
    this.lit = -1;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.nextRound();
  }

  /** 序列加长一位，然后演示 */
  private nextRound(): void {
    this.seq.push(Math.floor(Math.random() * PADS));
    this.len = this.seq.length;
    this.showIdx = -1;
    this.inputIdx = 0;
    this.lit = -1;
    this.phase = 'show';
    this.msg = TG2("看好了… 第 {0} 关",Digits(String(this.len), this.langCode));
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
    }
    this.showTimer = setInterval(() => {
      this.showStep();
    }, SHOW_TICK);
  }

  /** 演示一步：先灭掉上一个，再亮下一个 */
  private showStep(): void {
    if (this.lit >= 0) {
      this.lit = -1;
      return;
    }
    if (this.showIdx + 1 < this.seq.length) {
      this.showIdx++;
      this.lit = this.seq[this.showIdx];
      return;
    }
    if (this.showTimer >= 0) {
      clearInterval(this.showTimer);
      this.showTimer = -1;
    }
    this.lit = -1;
    this.phase = 'input';
    this.inputIdx = 0;
    this.msg = TG2("轮到你了，按顺序点 {0} 下", this.len);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 'input') {
      return true;
    }
    this.tapPad(this.seq[this.inputIdx]);
    return !this.over;
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 真值在 seq 里；phase !== input 是「演示中/过关间隙」⇒ 只能等
  /** 提示：报下一个该点的色块（用它的图标，不报下标） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over || this.phase !== 'input') {
      return Hint.none('none');
    }
    const i: number = this.seq[this.inputIdx];
    return Hint.make([i],
      TG2('下一个按 {0}', PAD_ICON[i]),
      TG2('Next tap: {0}', PAD_ICON[i]), t0);
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

  private tapPad(i: number): void {
    if (this.phase !== 'input' || this.over) {
      return;
    }
    if (this.seq[this.inputIdx] !== i) {
      this.fail();
      return;
    }
    this.flash(i);
    this.inputIdx++;
    if (this.inputIdx < this.seq.length) {
      return;
    }
    // 这一关过了
    this.score += this.len * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    this.phase = 'wait';
    this.msg = TG2("✅ 第 {0} 关通过",Digits(String(this.len), this.langCode));
    if (this.len >= this.winLen) {
      this.won = true;
      this.over = true;
      this.phase = 'over';
      this.msg = TG2('🎉 撑到第 {0} 关，通关！', this.winLen);
      this.clearTimers();
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.gapTimer >= 0) {
      clearTimeout(this.gapTimer);
    }
    this.gapTimer = setTimeout(() => {
      this.gapTimer = -1;
      this.nextRound();
    }, GAP_MS);
  }

  private flash(i: number): void {
    this.lit = i;
    if (this.flashTimer >= 0) {
      clearTimeout(this.flashTimer);
    }
    this.flashTimer = setTimeout(() => {
      this.flashTimer = -1;
      this.lit = -1;
    }, FLASH_MS);
  }

  private fail(): void {
    this.over = true;
    this.won = false;
    this.phase = 'over';
    this.lit = -1;
    this.msg = TG2("❌ 按错了，最长撑到 {0} 关",Digits(String(this.len), this.langCode));
    this.clearTimers();
    this.finish(false);
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'simon_says',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.len
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.len + '/' + this.winLen))
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
        Text((TG('得分'))).fontSize(FontSize.xxs)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode))
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
        Text((TG('状态'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'input' ? '你来' : (this.phase === 'show' ? '演示' : TG('结束'))))
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

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Stack() {
          Text(PAD_ICON[(0)]).fontSize(FontSize.xxxl)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (0) ? Palette.amber : PAD_COLORS[(0)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (0) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (0) ? 1.06 : 1, y: this.lit === (0) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((0));
          })
          Stack() {
          Text(PAD_ICON[(1)]).fontSize(FontSize.xxxl)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (1) ? Palette.amber : PAD_COLORS[(1)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (1) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (1) ? 1.06 : 1, y: this.lit === (1) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((1));
          })
        }
        .width('100%')
        Row({ space: Space.sm }) {
          Stack() {
          Text(PAD_ICON[(2)]).fontSize(FontSize.xxxl)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (2) ? Palette.amber : PAD_COLORS[(2)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (2) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (2) ? 1.06 : 1, y: this.lit === (2) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((2));
          })
          Stack() {
          Text(PAD_ICON[(3)]).fontSize(FontSize.xxxl)
          }
          .layoutWeight(1)
          .aspectRatio(1)
          .backgroundColor(this.lit === (3) ? Palette.amber : PAD_COLORS[(3)])
          .borderRadius(Radius.lg)
          .shadow(this.lit === (3) ? Shadow.lifted : Shadow.card)
          .scale({ x: this.lit === (3) ? 1.06 : 1, y: this.lit === (3) ? 1.06 : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          this.tapPad((3));
          })
        }
        .width('100%')
      }
      .width('100%')

      Text(this.msg)
        .fontSize(FontSize.md)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontWeight(FontWeight.Bold)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重新开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.orange)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
