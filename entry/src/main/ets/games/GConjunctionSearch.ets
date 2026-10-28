/**
 * 联合特征 —— 颜色 × 形状的联合搜索
 * 胜负：连过 6 关通关，点错 3 次判负　｜　进度：关卡 / 错误 / 得分
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

const SIZE: number = 5;
const CELLS: number = 25;
const ROUNDS: number = 6;
const MAX_WRONG: number = 3;
const KIND_SQUARE: number = 0;   // 红方块（干扰）
const KIND_CIRCLE: number = 1;   // 蓝圆点（干扰）
const KIND_TARGET: number = 2;   // 红圆点（目标）

function kindColor(k: number): string {
  return k === KIND_CIRCLE ? '#0EA5E9' : '#EF4444';
}

function kindGlyph(k: number): string {
  return k === KIND_CIRCLE ? '●' : '■';
}

@Component
export struct GConjunctionSearch {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State cells: number[] = [];
  @State round: number = 1;
  @State wrong: number = 0;
  @State flashIdx: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }

  private reset(): void {
    this.round = 1; this.wrong = 0; this.flashIdx = -1;
    this.over = false; this.won = false; this.finished = false;
    this.msg = TG('点出唯一的「红圆点」');
    this.startAt = Date.now();
    this.newBoard();
  }

  private newBoard(): void {
    const next: number[] = [];
    for (let i = 0; i < CELLS; i++) { next.push(i % 2 === 0 ? KIND_SQUARE : KIND_CIRCLE); }
    for (let k = CELLS - 1; k > 0; k--) {
      const j: number = Math.floor(Math.random() * (k + 1));
      const tmp: number = next[k];
      next[k] = next[j];
      next[j] = tmp;
    }
    next[Math.floor(Math.random() * CELLS)] = KIND_TARGET;
    this.cells = next;
    this.flashIdx = -1;
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
    if (this.cells.indexOf(KIND_TARGET) < 0) {
      return true;
    }
    this.tap(this.cells.indexOf(KIND_TARGET));
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const i: number = this.cells.indexOf(KIND_TARGET);
    if (i < 0) {
      return Hint.none('none');
    }
    const r: number = Math.floor(i / SIZE) + 1;
    const c: number = (i % SIZE) + 1;
    return Hint.make([i],
      TG2('红圆点在第 {0} 行第 {1} 列', String(r), String(c)),
      TG2('The red dot is at row {0}, column {1}', String(r), String(c)), t0);
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

  private tap(i: number): void {
    if (this.over || i < 0 || i >= CELLS) { return; }
    const k: number = this.cells[i];
    if (k === KIND_TARGET) {
      this.flashIdx = i;
      if (this.round >= this.diffTotal) { this.end(true); return; }
      this.round++;
      this.msg = TG2("✅ 找到！进入第 {0} / {1} 关",Digits(String(this.round), this.langCode),Digits(String(this.diffTotal), this.langCode));
      this.newBoard();
      return;
    }
    this.wrong++;
    this.msg = TG2("❌ 那是{0}", (k === KIND_CIRCLE ? '蓝圆点' : '红方块'));
    if (this.wrong >= MAX_WRONG) { this.end(false); }
  }

  private end(solved: boolean): void {
    this.over = true;
    this.won = solved;
    this.msg = solved ? '🎉 ' + this.diffTotal + ' 关全清，眼力满分'
      : TG2('错 {0} 次，本局结束',Digits(String(this.wrong), this.langCode));
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'conjunction_search', solved: solved, score: this.round * 100 - this.wrong * 40,
      durationMs: Date.now() - this.startAt, levelReached: this.round
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
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('错误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.wrong + ' / ' + MAX_WRONG)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.round * 100 - this.wrong * 40))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4], (r: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3, 4], (c: number) => {
              Stack() {
              Text(kindGlyph(this.cells[(r * SIZE + c)])).fontSize(FontSize.xxl).fontColor(kindColor(this.cells[(r * SIZE + c)]))
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.flashIdx === (r * SIZE + c) ? Palette.amber : this.theme.surface)
              .borderRadius(Radius.sm)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * SIZE + c)); }); })
              .onClick(() => { Haptics.tick(); this.tap((r * SIZE + c)); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm)
        .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.lg)

      Text(this.msg).fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('目标＝红色 □ 与蓝色 ● 的联合：唯一的红 ●'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
