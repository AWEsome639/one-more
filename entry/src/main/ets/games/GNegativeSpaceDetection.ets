/** 负空间 —— 满屏色块里留白拼出一个形状，认出它是哪一个；关数（简单 4/普通 6/困难 8）里答对 ≥ 通关线（3/5/7）通关 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 5;
const CELLS: number = N * N;
const ROUNDS: number = 6;
const PASS: number = 5;
const ROWS: number[] = [0, 1, 2, 3, 4];

interface Fig { icon: string; name: string; cells: number[] }

/** 5×5 里的留白形状（其余格子都是实心块） */
const FIGS: Fig[] = [
  { icon: '➕', name: '十字', cells: [7, 11, 12, 13, 17] },
  { icon: '⬜', name: '方框', cells: [6, 7, 8, 11, 13, 16, 17, 18] },
  { icon: '⬛', name: '实心块', cells: [6, 7, 8, 11, 12, 13, 16, 17, 18] },
  { icon: '✖️', name: TG(TG('交叉')), cells: [6, 8, 12, 16, 18] },
  { icon: '🔶', name: '菱形', cells: [7, 11, 13, 17] }
];

function mixFig(a: Fig[]): Fig[] {
  const out: Fig[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: Fig = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GNegativeSpaceDetection {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private hole: number[] = [];
  @State private opts: Fig[] = [];
  @State private rightName: string = '';
  @State private round: number = 1;
  @State private right: number = 0;
  @State private asked: number = 0;
  @State private pick: number = -1;
  @State private phase: number = 0;   // 0 作答 / 1 揭晓 / 2 结束
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.round = 1; this.right = 0; this.asked = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.newRound();
  }

  private newRound(): void {
    const k: number = Math.floor(Math.random() * FIGS.length);
    const target: Fig = FIGS[k];
    const rest: Fig[] = [];
    for (let i = 0; i < FIGS.length; i++) { if (i !== k) { rest.push(FIGS[i]); } }
    const group: Fig[] = [target];
    const shuffled: Fig[] = mixFig(rest);
    for (let i = 0; i < 3 && i < shuffled.length; i++) { group.push(shuffled[i]); }
    this.hole = target.cells;
    this.rightName = target.name;
    this.opts = mixFig(group);
    this.pick = -1;
    this.phase = 0;
    this.msg = TG('第 ') + String(this.round) + ' 关：空白处拼出了什么形状？';
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
    if (wasOn) { this.reset(); }
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
    if (this.pick >= 0) {
      return true;
    }
    this.answer(this.opts.map((f: Fig, i: number) => f.name === this.rightName ? i : -1).filter((v: number) => v >= 0)[0]);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('留白拼出来的是「{0}」', this.rightName),
      TG2('The negative space forms "{0}"', this.rightName), t0);
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

  /**
   * ★ 2026-10-28 修正：通关线不能是常量 —— 关数按难度变（简单 4 / 普通 6 / 困难 8），
   *   原来固定 PASS=5，简单档只有 4 关 ⇒ 最多答对 4 关，数学上不可能赢。
   *   公式 = min(关数, PASS + (关数 - ROUNDS))：简单 4→3、普通 6→5、困难 8→7。
   *   每题都有正确选项，所以「实际能拿到的最大值 = 关数」。
   */
  private passNeed(): number {
    const v: number = PASS + (this.diffTotal - ROUNDS);
    return Math.max(1, Math.min(this.diffTotal, v));
  }

  private answer(i: number): void {
    if (this.over || this.phase !== 0 || this.pick >= 0) { return; }
    const ok: boolean = this.opts[i].name === this.rightName;
    this.pick = i;
    this.asked = this.asked + 1;
    if (ok) { this.right = this.right + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110); this.msg = TG2('✅ 就是{0}', this.rightName); }
    else { this.msg = TG2('❌ 留白是「{0}」', this.rightName); }
    this.phase = 1;
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      if (this.round >= this.diffTotal) {
        this.phase = 2; this.over = true; this.won = this.right >= this.passNeed();
        this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) + String(this.right) + '/' + String(this.asked);
        this.finish(this.won);
        return;
      }
      this.round = this.round + 1;
      this.newRound();
    }, 1100);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'negative_space_detection', solved: solved, score: this.right * 100, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private isHole(i: number): boolean { return this.hole.indexOf(i) >= 0; }

  private tint(i: number): string {
    if (this.isHole(i)) { return this.phase >= 1 ? Palette.violet : this.theme.surface; }
    return this.theme.isDark ? '#3A3A3A' : '#334155';
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row() {
        Text(TG2('关卡 {0}', (String(this.round) + '/' + String(this.diffTotal)))).fontSize(FontSize.xs).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2("答对 {0}", (String(this.right) + '/' + String(this.asked)))).fontSize(FontSize.xs).fontColor(this.theme.ink)
        Text(TG('得分 ') + String(this.right * 100)).fontSize(FontSize.xs).fontColor(this.theme.ink)
      }.width('100%').padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)

      Column({ space: Space.xs }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(ROWS, (c: number) => { this.cellView(r * N + c) }, (c: number) => 'c' + c)
          }.width('100%').layoutWeight(1)
        }, (r: number) => 'r' + r)
      }
      .width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) { this.optBtn(0); this.optBtn(1) }.width('100%')
      Row({ space: Space.sm }) { this.optBtn(2); this.optBtn(3) }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.violet)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：别盯着色块，看它们中间空出来的那一块'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  cellView(i: number) {
    Stack() {
      Text('')
    }
    .layoutWeight(1).height('100%').backgroundColor(this.tint(i)).borderRadius(Radius.xs)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
  }
  @Builder
  optBtn(k: number) {
    Text(this.opts.length > k ? this.opts[k].icon + ' ' + this.opts[k].name : '')
      .fontSize(FontSize.md).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(48))
      .fontColor(this.pick === k ? '#FFFFFF' : this.theme.ink)
      .backgroundColor(this.pick === k ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
      .opacity(this.pick >= 0 && this.pick !== k ? 0.45 : 1).shadow(Shadow.card)
      .animation({ duration: Motion.fast, curve: Motion.snap() })
      .onClick(() => { Haptics.tick(); this.answer(k); })
  }
}
