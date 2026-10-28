/**
 * 事实绑定 📐
 * 玩法：左栏 5 条事实、右栏 5 个答案（已打乱）；左右各点一个即成对绑定，配对成功变绿。
 * 胜负：5 组全部绑定 = 通关；失误满 3 次 = 失败。
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

interface FactPair { ask: string; ans: string; }

const PAIRS: FactPair[] = [
  { ask: '🇨🇳 中国', ans: '北京' }, { ask: '🇯🇵 日本', ans: '东京' },
  { ask: '🇫🇷 法国', ans: '巴黎' }, { ask: '🇪🇬 埃及', ans: '开罗' },
  { ask: '🇦🇺 澳大利亚', ans: '堪培拉' }
];
const IDX: number[] = [0, 1, 2, 3, 4];
const LIVES: number = 3;

@Component
export struct GFactBinder {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private order: number[] = [];
  @State private done: boolean[] = [];
  @State private pickL: number = -1;
  @State private pickR: number = -1;
  @State private wrong: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
     this.reset(); }

  private reset(): void {
    const order: number[] = IDX.slice();
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    const flags: boolean[] = [];
    for (let i = 0; i < IDX.length; i++) { flags.push(false); }
    this.order = order; this.done = flags; this.pickL = -1; this.pickR = -1;
    this.wrong = 0; this.over = false; this.won = false;
    this.note = TG(TG(TG('左右各点一个，把事实与答案绑起来 🔗')));
    this.startAt = Date.now();
  }

  private bound(): number {
    let n: number = 0;
    for (let i = 0; i < this.done.length; i++) { if (this.done[i]) { n++; } }
    return n;
  }

  private tryBind(): void {
    const li: number = this.pickL;
    const ri: number = this.pickR;
    if (li < 0 || ri < 0) { return; }
    if (li === ri) {
      const flags: boolean[] = this.done.slice();
      flags[li] = true;
      this.done = flags; this.pickL = -1; this.pickR = -1;
      this.note = TG2('绑上了：{0} → {1} ✅', PAIRS[li].ask, PAIRS[li].ans);
      if (this.bound() >= IDX.length) { this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); }
      return;
    }
    this.wrong++; this.pickL = -1; this.pickR = -1;
    this.note = TG2('对不上，再想想 🤔（失误 {0}/{1}）', this.wrong, this.diffTotal);
    if (this.wrong >= this.diffTotal) { this.finish(false); }
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    const li: number = this.pickL;
    if (li >= 0 && !this.done[li]) {
      this.tapR(li);
      return !this.over;
    }
    let next: number = -1;
    for (let i = 0; i < IDX.length; i++) {
      if (!this.done[i]) {
        next = i;
        break;
      }
    }
    if (next < 0) {
      return false;
    }
    this.tapL(next);
    return !this.over;
  }

  /** 提示：报「哪条事实配哪个答案」（左边 i 与右边同 i 才绑得上） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    let li: number = this.pickL;
    if (li < 0) {
      for (let i = 0; i < IDX.length; i++) {
        if (!this.done[i]) {
          li = i;
          break;
        }
      }
    }
    if (li < 0) {
      return Hint.none('none');
    }
    return Hint.make([li],
      TG2('「{0}」配「{1}」', PAIRS[li].ask, PAIRS[li].ans),
      TG2('"{0}" goes with "{1}"', PAIRS[li].ask, PAIRS[li].ans), t0);
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

  private tapL(i: number): void {
    if (this.over || this.done[i]) { return; }
    this.pickL = i;
    this.tryBind();
  }

  private tapR(i: number): void {
    if (this.over || this.done[i]) { return; }
    this.pickR = i;
    this.tryBind();
  }

  private finish(solved: boolean): void {
    this.over = true; this.won = solved;
    this.note = solved ? '五组全部绑定，通关 🎉' : '失误太多，这局没绑完 😵';
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'fact_binder', solved: solved,
      score: solved ? 60 + (IDX.length - this.wrong) * 10 : this.bound() * 12,
      durationMs: Date.now() - this.startAt, levelReached: this.bound() + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Text(TG2("已绑定 {0}/{1}", this.bound(), IDX.length))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          ForEach(IDX, (i: number) => { this.tileL(i); }, (i: number) => 'L' + i)
        }.layoutWeight(1)
        Column({ space: Space.xs }) {
          ForEach(this.order, (i: number) => { this.tileR(i); }, (i: number) => 'R' + i)
        }.layoutWeight(1)
      }.width('100%')
      Text(this.note).fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  tileL(i: number) {
    Stack() {
      Text(this.done[i] ? '✅ ' + PAIRS[i].ans : PAIRS[i].ask)
        .fontSize(FontSize.sm).maxLines(1)
        .fontColor(this.done[i] ? '#FFFFFF' : this.theme.ink)
    }
    .width('100%').height(Space.xxxl)
    .backgroundColor(this.done[i] ? Palette.emerald : (this.pickL === i ? Palette.primary : this.theme.surface))
    .borderRadius(Radius.sm).shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tapL(i); })
  }

  @Builder
  tileR(i: number) {
    Stack() {
      Text(this.done[i] ? '✅ ' + PAIRS[i].ans : PAIRS[i].ans)
        .fontSize(FontSize.sm).maxLines(1)
        .fontColor(this.done[i] ? '#FFFFFF' : this.theme.ink)
    }
    .width('100%').height(Space.xxxl)
    .backgroundColor(this.done[i] ? Palette.emerald : (this.pickR === i ? Palette.primary : this.theme.surface))
    .borderRadius(Radius.sm).shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tapR(i); })
  }
}
