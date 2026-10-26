/** 记忆宫殿 —— 3 件物品摆进 9 个格子，熄灭后凭位置回忆；3 轮 9 问答对 ≥7 通关 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 3;
const CELLS: number = N * N;
const ROUNDS: number = 3;
const PER: number = 3;
const PASS: number = 7;
const MEM_MS: number = 2600;
const ITEMS: string[] = ['🔑', '📕', '🕯️', '🍵', '⌚', '🎩', '🧸', '🪴', '🎈'];

function mix(a: number[]): number[] {
  const out: number[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GMemoryPalace {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private slots: string[] = [];
  @State private order: number[] = [];
  @State private qIdx: number = 0;
  @State private target: number = -1;
  @State private pickCell: number = -1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private asked: number = 0;
  @State private phase: number = 0;   // 0 记忆 / 1 作答 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private memTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.memTo >= 0) { clearTimeout(this.memTo); this.memTo = -1; } if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.right = 0; this.asked = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const cells: number[] = [];
    for (let i = 0; i < CELLS; i++) { cells.push(i); }
    const spot: number[] = mix(cells).slice(0, PER);
    const room: string[] = new Array<string>(CELLS).fill('');
    for (let i = 0; i < PER; i++) { room[spot[i]] = ITEMS[(this.round * PER + i) % ITEMS.length]; }
    this.slots = room;
    this.order = mix(spot);
    this.qIdx = 0; this.target = this.order[0]; this.pickCell = -1; this.phase = 0;
    this.msg = TG('第 ') + String(this.round) + ' 轮：记住 ' + String(PER) + ' 件东西的位置';
    this.memTo = setTimeout(() => {
      this.memTo = -1; this.phase = 1; this.pickCell = -1; this.msg = TG(TG(TG('它放在哪一格？')));
    }, MEM_MS);
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.target],
      TG2('答案是第 {0} 个', String(this.target + 1)),
      TG2('The answer is option {0}', String(this.target + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 字段直取：记忆宫殿，答案就在 this.target
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over || this.phase !== 1) {
      return true;
    }
    this.answer(this.target);
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

  private answer(cell: number): void {
    if (this.over || this.phase !== 1 || this.pickCell >= 0) { return; }
    this.pickCell = cell;
    this.asked = this.asked + 1;
    if (cell === this.target) { this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG(TG(TG('✅ 对了'))); }
    else { this.msg = TG(TG(TG('❌ 它在这里'))); }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.qIdx + 1 < this.order.length) {
        this.qIdx = this.qIdx + 1; this.target = this.order[this.qIdx]; this.pickCell = -1;
        this.msg = TG(TG(TG('它放在哪一格？')));
        return;
      }
      if (this.round >= this.diffTotal) {
        this.phase = 2; this.over = true; this.won = this.right >= PASS;
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) + String(this.right) + '/' + String(this.asked);
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.newRound();
    }, 820);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'memory_palace', solved: solved, score: this.right * 100, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private tint(i: number): string {
    if (this.phase === 0) { return this.slots[i] !== '' ? Palette.berry : this.theme.surfaceAlt; }
    if (this.pickCell < 0) { return this.theme.surfaceAlt; }
    if (i === this.target) { return Palette.emerald; }
    return i === this.pickCell ? Palette.rose : this.theme.surfaceAlt;
  }

  private face(i: number): string {
    if (this.phase === 0) { return this.slots[i]; }
    if (this.pickCell < 0) { return ''; }
    if (i === this.target || i === this.pickCell) { return this.slots[this.target]; }
    return '';
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2("轮次 {0}", (String(this.round) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG('答对 ') + (String(this.right) + '/' + String(this.asked))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG2('进度 {0}', this.phase === 1 ? (String(this.qIdx + 1) + '/' + String(PER)) : TG('记忆'))).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Text(this.phase === 1 ? '找出 ' + this.slots[this.target] + ' 的位置' : '宫殿')
        .fontSize(FontSize.xl).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2], (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.xs)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      HintBar({

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        showHint: true,

        autoOn: this.autoId >= 0

      })

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：把格子想成房间里的固定位置，靠位置记住东西'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text(this.face(i) !== '' ? this.face(i) : String(i + 1))
        .fontSize(this.face(i) !== '' ? FontSize.xxl : FontSize.xs)
        .fontColor(this.face(i) !== '' ? '#FFFFFF' : this.theme.inkFaint)
    }
    .layoutWeight(1).aspectRatio(1).backgroundColor(this.tint(i)).borderRadius(Radius.md)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.answer(i); })
  }
}
