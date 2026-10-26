/**
 * 齿轮转向 ⚙️
 * 玩法：A 是主动轮（方向已给），B 与 A 之间要么啮合、要么用皮带相连 —— 判断 B 的转向。
 * 口诀：啮合反向、皮带同向。
 * 胜负：8 题全过 = 通关；答错 3 题 = 失败。
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Motion, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 8;
const LIVES: number = 3;

function spinText(cw: boolean): string {
  return cw ? '↻ 顺时针' : '↺ 逆时针';
}

@Component
export struct GGearRotation {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private idx: number = 0;
  @State private aCw: boolean = true;
  @State private meshed: boolean = true;
  @State private score: number = 0;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  /** ★ 2026-10-14 动效：齿轮转角（持续旋转，方向跟着 aCw） */
  @State private gearA: number = 0;
  @State private gearB: number = 0;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private roll(): void {
    this.aCw = Math.random() < 0.5;
    this.meshed = Math.random() < 0.5;
  }

  /** ★ 让两个齿轮转起来（无限循环）—— 方向按啮合/皮带规则 */
  private spinGears(): void {
    const dirA: number = this.aCw ? 1 : -1;
    // 啮合 ⇒ 反向；皮带 ⇒ 同向
    const dirB: number = this.meshed ? -dirA : dirA;
    animateTo({ duration: 2600, curve: Curve.Linear, iterations: -1 }, () => {
      this.gearA = this.gearA + 360 * dirA;
      this.gearB = this.gearB + 360 * dirB;
    });
  }

  private reset(): void {
    this.spinGears();   // ★ 齿轮转起来
    this.idx = 0;
    this.score = 0;
    this.wrong = 0;
    this.over = false;
    this.won = false;
    this.note = TG(TG(TG('看 A 的转向，判断 B ⚙️')));
    this.roll();
    this.startAt = Date.now();
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 布尔现算：mesh ? !drive : drive
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over) {
      return true;
    }
    const drive: boolean = this.aCw;
    const mesh: boolean = this.meshed;
    this.answer(mesh ? !drive : drive);
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

  private answer(userCw: boolean): void {
    if (this.over) { return; }
    const drive: boolean = this.aCw;
    const mesh: boolean = this.meshed;
    const expect: boolean = mesh ? !drive : drive;
    if (userCw === expect) {
      this.score += 10;
      this.note = mesh ? '对！啮合必然反向 ✅' : '对！皮带传动同向 ✅';
    } else {
      this.wrong++;
      this.note = mesh ? '错：啮合的两轮方向相反' : '错：皮带传动的两轮方向相同';
      this.note = this.note + TG2('（失误 {0}/{1}）', this.wrong, LIVES);
    }
    this.idx++;
    if (this.wrong >= LIVES) {
      this.finish(false);
      return;
    }
    if (this.idx >= this.diffTotal) {
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.roll();
  }

  private finish(solved: boolean): void {
    this.over = true;
    this.won = solved;
    if (solved) {
      this.note = TG(TG(TG('八题全过，通关 🎉')));
    } else {
      this.note = TG(TG(TG('失误三次，齿轮停了 😵')));
    }
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'gear_rotation',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.idx + 1
    });
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        onAutoTap: () => { this.askAuto(); },
        showHint: false,
        autoOn: this.autoId >= 0
      })
      Text(TG('第 ') + Math.min(this.idx + 1, this.diffTotal) + '/' + this.diffTotal + ' 题　得分 ' + this.score
        + TG('　失误 ') + this.wrong + '/' + LIVES)
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          Text(TG('A 主动轮')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text('⚙️').accessibilityLevel('no').fontSize(FontSize.xxl)
            // ★ 动效：齿轮真的在转（方向 = aCw）
            .rotate({ angle: this.gearA })
            // ★ 2026-10-15 补动画：没有 .animation() 时 rotate 是【瞬变】= 硬切
            .animation({ duration: Motion.slow, curve: Curve.Linear })
          Text(spinText(this.aCw)).fontSize(FontSize.sm).fontColor(Palette.primary)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          Text(this.meshed ? '⛓' : '🪢').fontSize(FontSize.xl)
          Text(this.meshed ? '啮合' : '皮带').fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        }.width(64)
        Column({ space: Space.xs }) {
          Text(TG('B 从动轮')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Text('⚙️').accessibilityLevel('no').fontSize(FontSize.xxl)
            // ★ 动效：B 轮按【啮合反向 / 皮带同向】转
            .rotate({ angle: this.gearB })
            // ★ 2026-10-15 补动画：同上
            .animation({ duration: Motion.slow, curve: Curve.Linear })
          Text('?').accessibilityText(TG('待求')).fontSize(FontSize.lg).fontColor(Palette.amber)
        }.layoutWeight(1)
      }
      .width('100%').padding(Space.md)
      .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      Text(this.note)
        .fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Button(TG('↻ 顺时针'))
            // ★ 测试 stateStyles（按下反馈）
            .stateStyles({
              pressed: { .scale({ x: 0.95, y: 0.95 }) },
              normal: { .scale({ x: 1, y: 1 }) }
            })
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .onClick(() => { Haptics.tap(); this.answer(true); })
        Button(TG('↺ 逆时针'))
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.violet)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(48))
          .onClick(() => { Haptics.tap(); this.answer(false); })
      }.width('100%')
      Button(TG('重开'))
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('口诀：啮合反向 · 皮带同向'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
