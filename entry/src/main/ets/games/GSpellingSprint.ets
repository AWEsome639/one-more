/** 拼写冲刺 —— 60 秒内看着中文释义把英文单词敲出来｜胜负：答对 ≥8 通关，超时或错满 3 次失败 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const TOTAL: number = 12; const PASS: number = 8; const LIVES: number = 3;
const LIMIT_S: number = 60; const TICK_MS: number = 1000; const GAP_MS: number = 600;

interface SPW { zh: string; w: string }

const BANK: SPW[] = [
  { zh: TG('苹果'), w: 'APPLE' }, { zh: TG('桥'), w: 'BRIDGE' }, { zh: '风暴', w: 'STORM' },
  { zh: '沉默', w: 'SILENCE' }, { zh: '勇气', w: 'COURAGE' }, { zh: '森林', w: 'FOREST' },
  { zh: '窗户', w: 'WINDOW' }, { zh: TG('铅笔'), w: 'PENCIL' }, { zh: '海洋', w: 'OCEAN' },
  { zh: '灯笼', w: 'LANTERN' }, { zh: '友谊', w: 'FRIENDSHIP' }, { zh: '影子', w: 'SHADOW' },
  { zh: '旅程', w: 'JOURNEY' }, { zh: '珍珠', w: 'PEARL' }, { zh: '图书馆', w: 'LIBRARY' },
  { zh: '清晨', w: 'MORNING' }
];

function shufIdx(n: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < n; i++) { out.push(i); }
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: number = out[i]; out[i] = out[j]; out[j] = t;
  }
  return out;
}

@Component
export struct GSpellingSprint {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};

  @State plan: number[] = []; @State qi: number = 0; @State right: number = 0;
  @State lives: number = LIVES; @State score: number = 0; @State leftS: number = LIMIT_S;
  @State input: string = ''; @State msg: string = ''; @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0; private timer: number = -1; private feed: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.feed >= 0) { clearTimeout(this.feed); this.feed = -1; }
  }
  private cur(): SPW { return BANK[this.plan[this.qi]]; }

  private reset(): void {
    this.stop();
    this.plan = shufIdx(BANK.length).slice(0, this.diffTotal);
    this.qi = 0; this.right = 0; this.lives = LIVES; this.score = 0;
    this.leftS = LIMIT_S; this.input = '';
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.msg = TG2('拼出「{0}」', this.cur().zh);
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }
  private tick(): void {
    if (this.over) { return; }
    this.leftS = this.leftS - 1;
    if (this.leftS <= 0) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = TG2('⌛ 时间到 —— 答对 {0} / {1}', this.right, this.diffTotal);
      this.finish(this.won);
    }
  }
  private submit(): void {
    if (this.over) { return; }
    const c: SPW = this.cur();
    const typed: string = this.input.trim().toUpperCase();
    if (typed.length === 0) { return; }
    if (typed === c.w) {
      this.right = this.right + 1; this.score = this.score + 100 + this.leftS;
      this.msg = '✅ ' + c.zh + ' = ' + c.w;
    } else {
      this.lives = this.lives - 1; this.msg = TG2('❌ {0} 应是 {1}', c.zh, c.w);
    }
    this.input = '';
    if (this.qi + 1 >= this.diffTotal) {
      this.over = true; this.won = this.right >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.finish(this.won); return;
    }
    if (this.lives <= 0) {
      this.over = true; this.won = false;
      this.msg = TG2('💤 错满 3 次 —— 答对 {0} / {1}',Digits(String(this.right), this.langCode),Digits(String(this.diffTotal), this.langCode));
      this.finish(false); return;
    }
    this.qi = this.qi + 1;
    this.feed = setTimeout(() => { this.feed = -1; this.msg = TG2('拼出「{0}」', this.cur().zh); }, GAP_MS);
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true; this.stop();
    const r: GameResult = { gameId: 'spelling_sprint', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('进度'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(((this.qi + 1) + '/' + this.diffTotal)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.teal))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.right + '/' + PASS)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('生命'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.lives + '/' + LIVES)).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.leftS + 's')).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('📖 看释义拼写')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.over ? TG('本局结束') : this.cur().zh)
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.teal)
        Text(TG2("首字母 {0} · 共 {1} 个字母", this.cur().w.charAt(0), this.cur().w.length))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() })

      Row({ space: Space.sm }) {
        TextInput({ text: this.input, placeholder: '输入英文单词' })
          .placeholderFont({ size: FontSize.sm }).placeholderColor(this.theme.inkFaint)
          .fontSize(FontSize.md).fontColor(this.theme.ink).backgroundColor(this.theme.surface)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46))
          .padding({ left: Space.sm, right: Space.sm }).enabled(!this.over)
          .onChange((v: string) => { this.input = v; })
          .onSubmit(() => { this.submit(); })
        Button(TG('提交'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.teal)
          .borderRadius(Radius.md).width(84).height(Cell.of(46)).enabled(!this.over)
          .onClick(() => { this.submit(); })
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })
      Text(TG2("{0} 秒内答对 ≥{1} 通关",Digits(String(LIMIT_S), this.langCode), PASS)).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

}
