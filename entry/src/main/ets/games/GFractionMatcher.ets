/** 分数匹配 —— 找相等分数；玩法：给出一个分数，从四个分数里选出与它等值的那个；胜负：8 题答对 ≥6 ⇒ 通关；否则失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 780; const LETTERS: string[] = ['A', 'B', 'C', 'D'];
@Component
export struct GFractionMatcher {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private a: number = 1;
  @State private b: number = 2;
  @State private opts: string[] = [];
  @State private ans: number = 0;
  @State private picked: number = -1;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private nextTo: number = -1; private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3];
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }
  private reset(): void {
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
    this.round = 1; this.right = 0; this.score = 0; this.over = false; this.won = false; this.finished = false;
    this.startAt = Date.now(); this.ask(); this.msg = TG('选出与它等值的分数（同乘同一个数）');
  }
  /** 出题：正确项 = 同乘 k；三个干扰项都与原分数不等值 */
  private ask(): void {
    this.a = 1 + Math.floor(Math.random() * 5);                     // 1 ~ 5
    this.b = this.a + 1 + Math.floor(Math.random() * 5);            // 比 a 大
    const k: number = 2 + Math.floor(Math.random() * 3);            // 2 ~ 4
    const good: string = String(this.a * k) + '/' + String(this.b * k);
    const pool: string[] = [
      String(this.a + 1) + '/' + String(this.b),
      String(this.a) + '/' + String(this.b + 1),
      String(this.a * k) + '/' + String(this.b * k + 1),
      String(this.a * k + 1) + '/' + String(this.b * k),
      String(this.a + 2) + '/' + String(this.b)
    ]; const list: string[] = [good];
    for (let i = 0; i < pool.length && list.length < 4; i++) {
      if (list.indexOf(pool[i]) < 0) { list.push(pool[i]); }
    }
    for (let i = list.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1)); const t: string = list[i]; list[i] = list[j]; list[j] = t;
    }
    this.opts = list; this.ans = list.indexOf(good); this.picked = -1;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ans）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ans;
    return Hint.make([n],
      TG2('答案是第 {0} 个', String(n + 1)),
      TG2('The answer is option {0}', String(n + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ans);
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i; const good: string = this.opts[this.ans];
    if (i === this.ans) {
      this.right = this.right + 1; this.score += 130; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ {0}/{1} = {2}（上下同乘）', String(this.a), String(this.b), good);
    } else {
      this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ {0} 不等值，正确是 {1}', this.opts[i], good); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = this.won
        ? TG('🎉 答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，通关！')
        : TG('😵 只答对 ') + String(this.right) + '/' + String(this.diffTotal) + TG('，差 ') + String(PASS - this.right) + TG(' 题');
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.ask();
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = {
      gameId: 'fraction_matcher', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    }; LanRace.noteDone(); this.onFinish(r);
  }
  private optBg(i: number): string {
    if (this.picked < 0) { return this.theme.surface; }
    if (i === this.ans) { return Palette.emerald; }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }
  private optInk(i: number): string {
    if (this.picked < 0) { return this.theme.ink; }
    if (i === this.ans) { return '#FFFFFF'; }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
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
        Text('½').fontSize(FontSize.xxl)
        Row({ space: Space.sm }) {
          Column({ space: 2 }) {
            Text(Digits(String(this.a), this.langCode)).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
            Row().width(48).height(2).backgroundColor(this.theme.lineSoft)
            Text(Digits(String(this.b), this.langCode)).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold).fontColor(Palette.emerald)
          }.alignItems(HorizontalAlign.Center)
          Text('= ?').fontSize(FontSize.xl).fontColor(this.theme.inkFaint)
        }.alignItems(VerticalAlign.Center)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      Column({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[i]).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
            Text(this.opts[i]).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1)
          }.width('100%').height(Cell.of(48)).padding({ left: Space.md, right: Space.md })
          .backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.pick(i); })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'fmat' + i + '_' + this.opts[i])
      }.width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.emerald)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：分子分母同乘（同除）一个非零数，分数的值不变')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
