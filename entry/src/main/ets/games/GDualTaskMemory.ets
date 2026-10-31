/**
 * 双任务记忆 —— 先记 4 位数字，中途插入心算，最后回忆数字
 *
 * 胜负：3 轮共 12 位，答对 ≥9 位 ⇒ 通关
 * 进度：轮次 / 已答位数 / 心算正确数
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
const ROUNDS: number = 3; const SPAN: number = 4; const QS: number = 3; const NEED: number = 9;
interface MathQ {
  text: string;
  ans: number;
  opts: number[];
}
@Component
export struct GDualTaskMemory {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};
  @State private phase: number = 0;      // 0 记忆 1 心算 2 回忆 3 结束
  @State private digits: number[] = [];
  @State private typed: number[] = [];
  @State private qs: MathQ[] = [];
  @State private qIdx: number = 0;
  @State private pick: number = -1;
  @State private mathRight: number = 0;
  @State private totalRight: number = 0;
  @State private roundNo: number = 1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private to1: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDualTaskMemory')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
  }
  private reset(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
    this.phase = 0; this.typed = []; this.qIdx = 0; this.pick = -1; this.mathRight = 0;
    this.totalRight = 0; this.roundNo = 1; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.newRound();
  }
  private newRound(): void {
    const list: number[] = [];
    for (let i = 0; i < SPAN; i++) {
      list.push(1 + Math.floor(Math.random() * 9));
    }
    const made: MathQ[] = [];
    for (let i = 0; i < QS; i++) {
      made.push(this.makeQ());
    }
    this.digits = list; this.qs = made; this.qIdx = 0; this.typed = []; this.pick = -1; this.phase = 0;
    this.msg = TG('第 ') + String(this.roundNo) + ' 轮：记住这 4 个数字';
    this.to1 = setTimeout(() => { this.to1 = -1; this.toMath(); }, 2400);
  }
  private makeQ(): MathQ {
    const a: number = 11 + Math.floor(Math.random() * 38);
    const b: number = 1 + Math.floor(Math.random() * 9); const plus: boolean = Math.random() < 0.5;
    const ans: number = plus ? a + b : a - b; const pool: number[] = [ans];
    while (pool.length < 3) {
      const d: number = ans + Math.floor(Math.random() * 21) - 10;
      if (d !== ans && pool.indexOf(d) < 0) { pool.push(d); }
    }
    const opts: number[] = [];
    while (pool.length > 0) {
      opts.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
    }
    const q: MathQ = { text: String(a) + (plus ? ' + ' : ' − ') + String(b) + ' = ?', ans: ans, opts: opts };
    return q;
  }
  private toMath(): void {
    this.phase = 1; this.qIdx = 0; this.pick = -1; this.msg = TG(TG(TG('边算边记：数字别忘了')));
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
    if (this.over) {
      return false;
    }
    if (this.phase === 1 && this.pick < 0) {
      if (this.qIdx >= this.qs.length) {
        return false;
      }
      const q: MathQ = this.qs[this.qIdx];
      this.answerMath(q.opts.indexOf(q.ans));
      return !this.over;
    }
    if (this.phase === 2 && this.typed.length < SPAN) {
      this.tapDigit(this.digits[this.typed.length]);
      return !this.over;
    }
    return true;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 1 && this.qIdx < this.qs.length) {
      const q: MathQ = this.qs[this.qIdx];
      return Hint.make([],
        TG2('心算：{0} 的答案是 {1}', q.text, q.ans),
        TG2('{0} = {1}', q.text, q.ans), t0);
    }
    if (this.phase === 2) {
      return Hint.make([],
        TG2('要回忆的 {0} 位数字是 {1}', this.digits.length, this.digits.join(' ')),
        TG2('The digits were {0}', this.digits.join(' ')), t0);
    }
    return Hint.make([],
      TG2('先把这 {0} 个数字记牢：{1}', this.digits.length, this.digits.join(' ')),
      TG2('Memorise these digits: {0}', this.digits.join(' ')), t0);
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

  private answerMath(i: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = i;
    if (this.qs[this.qIdx].opts[i] === this.qs[this.qIdx].ans) {
      this.mathRight = this.mathRight + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
    }
    this.to1 = setTimeout(() => {
      this.to1 = -1;
      if (this.qIdx >= QS - 1) {
        this.phase = 2; this.pick = -1; this.msg = TG(TG(TG('刚才那 4 个数字是什么？按顺序点出来')));
        return;
      }
      this.qIdx = this.qIdx + 1; this.pick = -1;
    }, 520);
  }
  private tapDigit(d: number): void {
    if (this.over || this.phase !== 2) { return; }
    const next: number[] = this.typed.slice();
    next.push(d);
    this.typed = next;
    if (next.length < SPAN) { return; }
    let hit: number = 0;
    for (let i = 0; i < SPAN; i++) {
      if (next[i] === this.digits[i]) { hit = hit + 1; }
    }
    this.totalRight = this.totalRight + hit; this.phase = 3;
    this.msg = TG2('本轮记住 {0}/{1}（正确答案 {2}）', String(hit), String(SPAN), this.digits.join(' '));
    this.to1 = setTimeout(() => {
      this.to1 = -1;
      if (this.roundNo >= this.diffTotal) {
        this.finish();
        return;
      }
      this.roundNo = this.roundNo + 1; this.newRound();
    }, 1200);
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.totalRight >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG2('记住 {0}/{1}', String(this.totalRight), String(this.diffTotal * SPAN))
      + TG2(' · 心算对 {0}/{1}', String(this.mathRight), String(this.diffTotal * QS));
    const r: GameResult = {
      gameId: 'dual_task_memory', solved: this.won,
      score: this.totalRight * 100 + this.mathRight * 25,
      durationMs: Date.now() - this.startAt, levelReached: this.roundNo
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
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text((String(this.roundNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('记住')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.totalRight) + '/' + String(this.diffTotal * SPAN))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('心算')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.mathRight), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Stack() {
        if (this.phase === 0) {
          Text(this.digits.join(' ')).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
        } else if (this.phase === 1) {
          Column({ space: Space.xs }) {
            Text(this.qs.length > 0 ? this.qs[this.qIdx].text : '').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            Text(TG2("第 {0}/{1}", String(this.qIdx + 1), String(QS))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          }
        } else {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (k: number) => {
              Text((k) < this.typed.length ? String(this.typed[(k)]) : '_').fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
              .fontColor((k) < this.typed.length ? Palette.primaryDeep : this.theme.inkFaint)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(60)).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.sm)
            }, (k: number) => 'sl' + k)
          }.width('100%').padding(Space.md)
        }
      }.width('100%').height(104).backgroundColor(this.theme.surface).borderRadius(Radius.lg)
      .shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      if (this.phase === 1) {
        Row({ space: Space.sm }) {
          ForEach([0, 1, 2], (i: number) => {
            Text(this.qs.length > 0 && (i) < this.qs[this.qIdx].opts.length ? String(this.qs[this.qIdx].opts[(i)]) : '')
            .fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.pick === (i) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center)
            .layoutWeight(1).height(Cell.of(56)).backgroundColor(this.pick === (i) ? Palette.primaryDeep : this.theme.surfaceAlt)
            .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.answerMath((i)); }); }).onClick(() => { Haptics.tick(); this.answerMath((i)); })
          }, (i: number) => 'mb' + i)
        }.width('100%')
      } else if (this.phase === 2) {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.xs }) {
              ForEach([0, 1, 2], (c: number) => {
                Text(String((r * 3 + c + 1))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
                .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(46)).backgroundColor(this.theme.surfaceAlt)
                .borderRadius(Radius.sm).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapDigit((r * 3 + c + 1)); }); }).onClick(() => { Haptics.tick(); this.tapDigit((r * 3 + c + 1)); })
              }, (c: number) => 'dc' + c)
            }.width('100%')
          }, (r: number) => 'dr' + r)
        }.width('100%')
      } else {
        Text(' ').fontSize(FontSize.md).width('100%').height(Cell.of(52))
      }
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
