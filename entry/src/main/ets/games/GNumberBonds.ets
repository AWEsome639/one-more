/**
 * 数字键 —— 拆分成两个数
 *
 * 玩法：目标数拆成两部分，一部分已给出，四选一补上另一部分。共 10 题。
 * 胜负：答对 ≥ 8 题 ⇒ 通关；否则失败。
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

const ROUNDS: number = 10;
const PASS: number = 8;
const PICK: number = 4;
const NEXT_MS: number = 400;

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GNumberBonds {
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
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State private opts: number[] = [];
  @State private ans: number = -1;
  @State private picked: number = -1;
  @State private target: number = 0;
  @State private shown: number = 0;
  @State private hideFirst: boolean = true;
  @State private round: number = 1;
  @State private right: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private nextTo: number = -1;
  private finished: boolean = false;
  private slots: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GNumberBonds')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
    this.reset();
  }

  aboutToDisappear(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
  }

  private reset(): void {
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
      this.nextTo = -1;
    }
    this.round = 1;
    this.right = 0;
    this.score = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG('目标数 = 左半 + 右半，把缺的那半补上');
    this.ask();
  }

  private ask(): void {
    const t: number = randInt(5, 18);
    const a: number = randInt(1, t - 1);
    const b: number = t - a;
    this.target = t;
    this.hideFirst = Math.random() < 0.5;
    this.shown = this.hideFirst ? b : a;
    const truth: number = this.hideFirst ? a : b;
    const pool: number[] = [truth + 1, truth - 1, truth + 2, t - truth, truth + 3, truth - 2];
    const opts: number[] = [truth];
    for (let i = 0; i < pool.length && opts.length < PICK; i++) {
      if (pool[i] >= 1 && pool[i] <= t - 1 && opts.indexOf(pool[i]) < 0) {
        opts.push(pool[i]);
      }
    }
    for (let i = opts.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = opts[i];
      opts[i] = opts[j];
      opts[j] = tmp;
    }
    this.opts = opts;
    this.ans = opts.indexOf(truth);
    this.picked = -1;
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
      TG2('答案是 {0}', String(this.opts[n])),
      TG2('The answer is {0}', String(this.opts[n])), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    if (this.picked >= 0 || this.over) {
      return;
    }
    this.picked = i;
    if (i === this.ans) {
      this.right = this.right + 1;
      this.score = this.score + 100; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = '✅ ' + this.target + ' = ' + this.shown + ' + ' + this.opts[this.ans];
    } else {
      this.msg = TG2("❌ 应该是 {0}", this.opts[this.ans]);
    }
    if (this.nextTo >= 0) {
      clearTimeout(this.nextTo);
    }
    this.nextTo = setTimeout(() => {
      this.nextTo = -1;
      this.advance();
    }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) {
      return;
    }
    if (this.round >= this.diffTotal) {
      const ok: boolean = this.right >= PASS;
      this.msg = ok ? TG('🎉 答对 ') + this.right + '/' + this.diffTotal + ' 题，通关！'
        : TG('答对 ') + this.right + '/' + this.diffTotal + ' 题，还差一点';
      this.finish(ok);
      return;
    }
    this.round = this.round + 1;
    this.ask();
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'number_bonds',
      solved: solved,
      score: this.score,
      durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private optBg(i: number): string {
    if (this.picked < 0) {
      return this.theme.surface;
    }
    if (i === this.ans) {
      return Palette.teal;
    }
    return i === this.picked ? Palette.rose : this.theme.surface;
  }

  private optInk(i: number): string {
    if (this.picked < 0) {
      return this.theme.ink;
    }
    if (i === this.ans) {
      return '#FFFFFF';
    }
    return i === this.picked ? '#FFFFFF' : this.theme.inkFaint;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('第几题'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
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
        Text(Digits(String(this.target), this.langCode)).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text('╱  ╲').fontSize(FontSize.lg).fontColor(this.theme.inkFaint)
        Row({ space: Space.lg }) {
          Text((this.hideFirst) ? '?' : String((this.shown))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor((this.hideFirst) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).width(84).height(Cell.of(64)).backgroundColor((this.hideFirst) ? Palette.teal : this.theme.surfaceAlt).borderRadius(Radius.md)
          Text((!this.hideFirst) ? '?' : String((this.shown))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor((!this.hideFirst) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).width(84).height(Cell.of(64)).backgroundColor((!this.hideFirst) ? Palette.teal : this.theme.surfaceAlt).borderRadius(Radius.md)
        }.width('100%').justifyContent(FlexAlign.Center)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.sm }) {
        ForEach(this.slots, (i: number) => {
          Row({ space: Space.sm }) {
            Text(String(i + 1)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor(this.theme.inkFaint)
            Text(String(this.opts[i])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.optInk(i)).layoutWeight(1)
          }.width('100%').height(Cell.of(50)).padding({ left: Space.md, right: Space.md }).backgroundColor(this.optBg(i)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
            Haptics.tick();
            this.pick(i);
          })
        }, (i: number) => 'nb' + i)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%').animation({ duration: Motion.fast, curve: Motion.snap() })

      HintBar({

        showHint: true,

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        demoOn: this.demoId >= 0,

        autoOn: this.autoId >= 0

      })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.teal).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
