/**
 * 释义冲刺 —— 限时选释义：整局 60 秒，答得越快分越高，答完即换下一题
 * 胜负：答对 ≥8 题通关；错 3 次或时间耗尽即失败　进度：题号 / 答对 / 失误 / 倒计时
 */
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const ROUNDS: number = 10; const PASS: number = 8; const MISS_MAX: number = 3;
const LIMIT_S: number = 60; const TICK_MS: number = 1000;

interface Q { w: string; opts: string[] }

/** opts[0] 恒为正确释义，运行时打乱 */
const POOL: Q[] = [
  { w: 'ephemeral', opts: ['转瞬即逝的', '坚不可摧的', '笨重迟缓的'] }, { w: 'loquacious', opts: ['话多的', '沉默寡言的', '耳背的'] },
  { w: 'zenith', opts: ['顶点；天顶', '深渊', '起点'] }, { w: 'candor', opts: ['坦率', '欺骗', '胆怯'] },
  { w: 'obdurate', opts: ['固执的', '温顺的', '慷慨的'] }, { w: 'salient', opts: ['显著的', '隐蔽的', '潮湿的'] },
  { w: 'verbose', opts: ['冗长的', '精炼的', '晦涩的'] }, { w: 'benign', opts: ['良性的；和善的', '恶性的', '有毒的'] },
  { w: 'taciturn', opts: ['沉默寡言的', '健谈的', '粗鲁的'] }, { w: 'adroit', opts: ['熟练的', '笨拙的', '迟缓的'] },
  { w: 'myriad', opts: ['无数的', '稀少的', '单一的'] }, { w: 'placate', opts: ['安抚', '激怒', '忽视'] },
  { w: 'lucid', opts: ['清晰易懂的', '混乱的', '昏暗的'] }, { w: 'audacious', opts: ['大胆的', '胆怯的', '谦逊的'] }
];

@Component
export struct GDefinitionDash {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};

  @State order: number[] = []; @State qi: number = 0; @State opts: string[] = [];
  @State ans: number = 0; @State correct: number = 0; @State miss: number = 0;
  @State leftS: number = LIMIT_S; @State score: number = 0; @State over: boolean = false;
  @State won: boolean = false; @State msg: string = '';
  @State private k: number = 1;
  private startAt: number = 0; private done: boolean = false; private timer: number = -1;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private cur(): Q { return POOL[this.order[this.qi]]; }

  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */

  private bumpK(): void {

    this.k = 1.16;

    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });

  }


  private reset(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.qi = 0; this.correct = 0; this.miss = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('六十秒，越快分越高'); this.startAt = Date.now();
    const idx: number[] = []; const out: number[] = [];
    for (let i = 0; i < POOL.length; i++) { idx.push(i); }
    for (let i = 0; i < this.diffTotal; i++) {
      const p: number = Math.floor(Math.random() * idx.length);
      out.push(idx[p]); idx.splice(p, 1);
    }
    this.order = out; this.deal();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private deal(): void {
    const arr: string[] = this.cur().opts.slice();
    for (let i = arr.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: string = arr[i]; arr[i] = arr[j]; arr[j] = t;
    }
    this.opts = arr; this.ans = arr.indexOf(this.cur().opts[0]);
  }

  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) { this.end(); }
  }

  /** 答完立刻换下一题，上一题的判定留在提示行里 */
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.ans   ｜ 守卫条件取自它自己的 if (...) { return; }
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ans 里） */
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
    if (this.over) {
      return true;              // 还没到能作答的时刻 / 已经答过，等推进
    }
    this.answer(this.ans);
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

  private answer(i: number): void {
    if (this.over) { return; }
    const q: Q = this.cur();
    if (i === this.ans) {
      const gain: number = 50 + this.leftS;
      this.correct = this.correct + 1;
    this.bumpK(); this.score = this.score + gain;
      this.msg = '✅ ' + q.w + ' = ' + q.opts[0] + '（+' + gain + '）';
    } else {
      this.miss = this.miss + 1;
      this.msg = '❌ ' + q.w + ' = ' + q.opts[0];
      if (this.miss >= MISS_MAX) { this.end(); return; }
    }
    if (this.qi + 1 >= this.diffTotal) { this.end(); return; }
    this.qi = this.qi + 1; this.deal();
  }

  private end(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    this.over = true; this.won = this.correct >= PASS && this.miss < MISS_MAX;
    this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.correct, this.diffTotal);
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'definition_dash', solved: this.won, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.correct };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.qi + 1, this.diffTotal) + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.correct + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        .scale({ x: this.k, y: this.k })
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.miss + '/' + MISS_MAX)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('倒计时'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.over ? 0 : this.leftS) + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: Space.sm }) {
        Text(this.cur().w).fontSize(FontSize.xxxl).fontWeight(FontWeight.Bold)
          .fontColor(Palette.violet)
        Text(TG('它的意思是？')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }
      .width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Text((this.opts.length > 0 ? this.opts[0] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(46))
      .fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).onClick(() => { Haptics.tick(); this.answer((0)); })
      Text((this.opts.length > 1 ? this.opts[1] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(46))
      .fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).onClick(() => { Haptics.tick(); this.answer((1)); })
      Text((this.opts.length > 2 ? this.opts[2] : '')).fontSize(FontSize.md).textAlign(TextAlign.Center).width('100%').height(Cell.of(46))
      .fontColor(this.theme.ink).backgroundColor(this.theme.surface).borderRadius(Radius.md)
      .shadow(Shadow.card).onClick(() => { Haptics.tick(); this.answer((2)); })

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%')
        .textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      HintBar({

        showHint: true,

        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },

        autoOn: this.autoId >= 0

      })

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
