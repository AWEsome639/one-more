/**
 * 模运算钟 —— 钟面模运算
 * 玩法：钟面指着某点，往前/往后拨若干小时，选出落在哪个钟点上（mod 12）。
 * 胜负：60 秒内答对 10 题 ⇒ 通关；时间归零 ⇒ 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const GOAL: number = 10; const LIMIT: number = 60; const TICK_MS: number = 1000;
const PENALTY: number = 3; const NEXT_MS: number = 420;
const HOURS: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const OPT_IDX: number[] = [0, 1, 2, 3];

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

/** 归到 1..12 */
function wrap12(v: number): number {
  return ((v - 1) % 12 + 12) % 12 + 1;
}

@Component
export struct GModularClockArithmetic {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private start: number = 1;
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  @State private delta: number = 2;
  @State private forward: boolean = true;
  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private right: number = 0;
  @State private combo: number = 0;
  @State private score: number = 0;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1;
  private nextTo: number = -1; private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.stop();
    this.right = 0; this.combo = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.ask();
    this.msg = TG(TG(TG('钟面只有 12 个点：走过头就绕回来（mod 12）')));
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); }
  }

  private ask(): void {
    const base: number = ri(1, 12);
    const step: number = ri(2, 11);
    const goFwd: boolean = Math.random() < 0.5;
    const correct: number = goFwd ? wrap12(base + step) : wrap12(base - step);
    const back: number = goFwd ? wrap12(base - step) : wrap12(base + step);
    const cand: number[] = [back, wrap12(correct + 1), wrap12(correct - 1), wrap12(correct + 2)];
    const opts: number[] = [correct];
    for (let i = 0; i < cand.length && opts.length < 4; i++) {
      if (opts.indexOf(cand[i]) < 0) { opts.push(cand[i]); }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = opts[i]; opts[i] = opts[j]; opts[j] = t;
    }
    this.start = base; this.delta = step; this.forward = goFwd;
    this.opts = opts; this.ans = opts.indexOf(correct); this.picked = -1;
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
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1; this.combo = this.combo + 1;
      this.score = this.score + 55 + this.combo * 10; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.msg = '✅ 答对！' + String(this.start) + (this.forward ? ' + ' : ' − ') + String(this.delta) +
        ' ≡ ' + String(this.opts[this.ans]) + ' (mod 12)';
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 15);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG('❌ 错了，扣 ') + String(PENALTY) + ' 秒 —— 答案是 ' + String(this.opts[this.ans]) + TG(' 点');
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) { return; }
    if (this.right >= GOAL) { this.end(true, TG('🎉 答对 ') + String(GOAL) + TG(' 题，通关！剩 ') + String(this.left) + TG(' 秒')); return; }
    if (this.left <= 0) { this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); return; }
    this.ask();
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'modular_clock_arithmetic', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /** 钟面某点的底色：基准点 / 答对 / 答错 */
  private hourBg(h: number): string {
    if (this.picked >= 0 && h === this.opts[this.ans]) { return Palette.emerald; }
    if (this.picked >= 0 && h === this.opts[this.picked]) { return Palette.rose; }
    return h === this.start ? Palette.berry : this.theme.surfaceAlt;
  }

  private hourInk(h: number): string {
    if (this.picked >= 0 && (h === this.opts[this.ans] || h === this.opts[this.picked])) { return '#FFFFFF'; }
    return h === this.start ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(GOAL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text('🕐 ' + TG2(this.forward ? '顺时针再走 {0}' : '往回倒拨 {0}', String(this.delta)) + ' 小时')
          .fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(TG2('现在指着 {0} 点 —— 之后是几点？', String(this.start)))
          .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(Palette.berry)
        Row({ space: Space.xs }) {
          ForEach(HOURS, (h: number) => {
            Text(String(h))
              .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
              .fontColor(this.hourInk(h))
              .layoutWeight(1).height(Cell.of(32)).borderRadius(Radius.xs)
              .backgroundColor(this.hourBg(h))
              .animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (h: number) => 'hr' + h)
        }.width('100%')
      }
      .width('100%').padding(Space.md).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Row({ space: Space.sm }) {
        ForEach(OPT_IDX, (i: number) => { Text(String(this.opts[(i)]) + TG(' 点'))
        .fontSize(FontSize.lg).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.picked < 0 ? this.theme.ink
        : ((i) === this.ans ? '#FFFFFF' : ((i) === this.picked ? '#FFFFFF' : this.theme.inkFaint)))
        .layoutWeight(1).height(Cell.of(64)).borderRadius(Radius.md).shadow(Shadow.card)
        .backgroundColor(this.picked < 0 ? this.theme.surface
        : ((i) === this.ans ? Palette.emerald : ((i) === this.picked ? Palette.rose : this.theme.surface)))
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.pick((i)); }) }, (i: number) => 'mo' + i)
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
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：12 点之后回到 1 点，模运算只看余数'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
