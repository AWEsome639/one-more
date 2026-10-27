/**
 * 语法分类 —— 把单词分进「名词 / 动词 / 形容词 / 副词」四个桶
 * 胜负：16 个词正确分类 ≥12 通关｜进度：已分类 / 答对 / 剩余秒数
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

const KIND: string[] = ['名词', '动词', '形容词', '副词'];
const KIND_COLOR: string[] = [Palette.sky, Palette.orange, Palette.violet, Palette.emerald];
const TOTAL: number = 16; const PASS: number = 12; const LIMIT_S: number = 45;
const TICK_MS: number = 1000;

interface GW { w: string; k: number }

const BANK: GW[] = [
  { w: 'FREEDOM', k: 0 }, { w: 'JUDGEMENT', k: 0 }, { w: 'CHILDHOOD', k: 0 }, { w: 'KNOWLEDGE', k: 0 },
  { w: 'DECIDE', k: 1 }, { w: 'ANALYZE', k: 1 }, { w: 'FORGIVE', k: 1 }, { w: 'MEASURE', k: 1 },
  { w: 'CAREFUL', k: 2 }, { w: 'ANCIENT', k: 2 }, { w: 'GENUINE', k: 2 }, { w: 'NARROW', k: 2 },
  { w: 'SLOWLY', k: 3 }, { w: 'OFTEN', k: 3 }, { w: 'BARELY', k: 3 }, { w: 'EAGERLY', k: 3 },
  { w: 'SILENCE', k: 0 }, { w: 'PATIENCE', k: 0 }, { w: 'REPEAT', k: 1 }, { w: 'IMAGINE', k: 1 },
  { w: 'HONEST', k: 2 }, { w: 'BITTER', k: 2 }, { w: 'HARDLY', k: 3 }, { w: 'QUIETLY', k: 3 }
];

function shuffleIdx(): number[] {
  const out: number[] = [];
  for (let i = 0; i < BANK.length; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out.slice(0, TOTAL);
}

@Component
export struct GGrammarSort {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State queue: number[] = []; @State step: number = 0;
  @State right: number = 0; @State wrong: number = 0; @State score: number = 0;
  @State leftS: number = LIMIT_S; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }
  private reset(): void {
    this.stop();
    this.queue = shuffleIdx();
    this.step = 0; this.right = 0; this.wrong = 0; this.score = 0; this.leftS = LIMIT_S;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('这个词是哪种词性？');
    this.startAt = Date.now();
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private cur(): GW { return BANK[this.queue[this.step < this.diffTotal ? this.step : this.diffTotal - 1]]; }
  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = TG2('⌛ 时间到 —— 答对 {0} / {1}', this.right, this.diffTotal); this.finish(this.won);
    }
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式直取：语法分类
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.over) {
      return true;
    }
    this.pick(this.cur().k);
    return !this.over;
  }

  /** 提示：直接报正确选项 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const k: number = this.cur().k;
    return Hint.make([k],
      TG2('答案是第 {0} 个', String(k + 1)),
      TG2('The answer is option {0}', String(k + 1)), t0);
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

  private pick(k: number): void {
    if (this.over) { return; }
    if (k === this.cur().k) {
      this.right = this.right + 1;
      this.score = this.score + 80;
      this.msg = TG2('✅ {0} 是{1}', this.cur().w, KIND[k]);
    } else {
      this.wrong = this.wrong + 1;
      this.msg = TG2('❌ {0} 其实是{1}', this.cur().w, KIND[this.cur().k]);
    }
    this.step = this.step + 1;
    if (this.step >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won);
    }
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'grammar_sort', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
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
        Column({ space: Space.xs }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((Math.min(this.step + 1, this.diffTotal) + ' / ' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.cyan))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + ' / ' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答错'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.wrong), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(this.over ? TG('本局结束') : '它是哪种词性？').fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.cur().w).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Button(KIND[(0)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(KIND_COLOR[(0)]).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick((0)); })
          Button(KIND[(1)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(KIND_COLOR[(1)]).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick((1)); })
        }.width('100%')
        Row({ space: Space.sm }) {
          Button(KIND[(2)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(KIND_COLOR[(2)]).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick((2)); })
          Button(KIND[(3)])
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(KIND_COLOR[(3)]).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => { Haptics.tap(); this.pick((3)); })
        }.width('100%')
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG2("{0} 个词，{1} 秒内答对 ≥{2} 通关",Digits(String(this.diffTotal), this.langCode), LIMIT_S, PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
