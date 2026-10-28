/** 分数披萨 —— 按分数切披萨；玩法：按题目的分数点亮同样多的披萨片，点「确认」判定；胜负：题数（简单 4/普通 6/困难 8）里答对 ≥ 通关线（3/5/7）⇒ 通关；否则失败 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const ROUNDS: number = 6; const PASS: number = 5; const NEXT_MS: number = 900; const DEN: number[] = [4, 6, 8];
@Component
export struct GFractionalPizza {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private d: number = 4;
  @State private n: number = 1;
  @State private slots: number[] = [];
  @State private sel: boolean[] = [];
  @State private onCount: number = 0;
  @State private checked: boolean = false;
  @State private ok: boolean = false;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private nextTo: number = -1; private finished: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.right = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG2('点亮 {0}/{1} 片，再点确认', String(this.n), String(this.d));
  }
  private ask(): void {
    this.d = DEN[Math.floor(Math.random() * DEN.length)]; this.n = 1 + Math.floor(Math.random() * (this.d - 1));
    const list: number[] = [];
    for (let i = 0; i < this.d; i++) { list.push(i); }
    this.slots = list; this.sel = new Array<boolean>(this.d).fill(false); this.onCount = 0; this.checked = false; this.ok = false;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.checked) {
      return true;               // 判定中，等 900ms 进下一题
    }
    if (this.onCount < this.n) {
      for (let i = 0; i < this.sel.length; i++) {
        if (!this.sel[i]) {
          this.tap(i);
          return true;
        }
      }
      return false;
    }
    if (this.onCount > this.n) {
      for (let i = 0; i < this.sel.length; i++) {
        if (this.sel[i]) {
          this.tap(i);
          return true;
        }
      }
      return false;
    }
    this.submit();               // 正好 n 片 ⇒ 替玩家按「确认」
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([],
      TG2('点亮 {0} 片（一共 {1} 片），再点「确认」', String(this.n), String(this.d)),
      TG2('Light {0} of {1} slices, then tap Confirm', String(this.n), String(this.d)), t0);
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
    if (this.checked || this.over) { return; }
    const next: boolean[] = this.sel.slice(); next[i] = !next[i]; this.sel = next;
    this.onCount = next[i] ? this.onCount + 1 : this.onCount - 1;
  }
  private submit(): void {
    if (this.checked || this.over) { return; }
    this.checked = true; this.ok = this.onCount === this.n;
    if (this.ok) {
      this.right = this.right + 1; this.score += 150; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = '✅ 正好 ' + String(this.n) + '/' + String(this.d) + '，答对 ' + String(this.right) + '/' + this.diffTotal;
    } else {
      this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 你点亮了 {0} 片，应该是 {1} 片', String(this.onCount), String(this.n)); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  /**
   * ★ 2026-10-28 修正：通关线不能是常量 —— 题数按难度变（简单 4 / 普通 6 / 困难 8），
   *   原来固定 PASS=5，简单档只有 4 题 ⇒ 最多答对 4 个，数学上不可能赢。
   *   公式 = min(题数, PASS + (题数 - ROUNDS))：简单 4→3、普通 6→5、困难 8→7。
   *   每题都一定答得对（点亮 n 片再确认），所以「实际能拿到的最大值 = 题数」。
   */
  private passNeed(): number {
    const v: number = PASS + (this.diffTotal - ROUNDS);
    return Math.max(1, Math.min(this.diffTotal, v));
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= this.passNeed();
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + this.diffTotal + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + this.diffTotal + TG('，差 ') + String(this.passNeed() - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask(); this.msg = TG2('点亮 {0}/{1} 片，再点确认', String(this.n), String(this.d));
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'fractional_pizza', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private pieceBg(i: number): string {
    if (!this.sel[i]) { return this.theme.surface; }
    if (!this.checked) { return Palette.amber; }
    return this.ok ? Palette.emerald : Palette.rose;
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
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + this.passNeed())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        Text('🍕').fontSize(FontSize.xxl)
          .accessibilityLevel('no')
        Text(TG2('切出 {0} / {1}', String(this.n), String(this.d)))
          .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.amber)
        Text(TG2('点亮 {0} 片（共 {1} 片）', String(this.n), String(this.d))).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Row({ space: Space.xs }) {
        ForEach(this.slots, (i: number) => {
          Stack() {
          Text(this.sel[(i)] ? '🍕' : '⚪').fontSize(FontSize.lg)
          }.layoutWeight(1).height(Cell.of(64)).backgroundColor(this.pieceBg((i))).borderRadius(Radius.md).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((i)); })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'pz' + i + '_' + this.d + (this.sel[i] ? 'y' : 'n') + (this.checked ? 'c' : ''))
      }.width('100%').height(Cell.of(64))
      Button(this.checked ? (this.ok ? '✅ 对了' : '❌ 应是 ' + String(this.n) + '/' + String(this.d)) : TG('确认'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.checked ? (this.ok ? Palette.emerald : Palette.rose) : Palette.amber)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.submit(); })
      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：分母 = 一共几片，分子 = 取几片')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
