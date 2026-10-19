/**
 * 关系记忆 —— 🃏 先记住 6 组配对，再凭记忆点出正确的那一半（id: relational_memory）
 * 胜负：6 题答对 ≥ 5 ⇒ 通关；进度：答对/6 · 题号 · 记忆倒计时
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const PAIRS: number = 6;
const STUDY_MS: number = 5000;
const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐳', '🔑', '🍀', '🎸', '🚀', '🍄', '🧊', '🪁'];
function shuffled(a: string[]): string[] {
  const out: string[] = a.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: string = out[i];
    out[i] = out[j];
    out[j] = t;
  }
  return out;
}
@Component
export struct GRelationalMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：PAIRS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(PAIRS);
  onFinish: (r: GameResult) => void = () => {};
  @State private sideA: string[] = [];
  @State private sideB: string[] = [];
  @State private options: string[] = [];
  @State private phase: string = 'study';
  @State private qIdx: number = 0;
  @State private hits: number = 0;
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private toId: number = -1;
  private done: boolean = false;
  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(PAIRS);
     this.reset(); }
  aboutToDisappear(): void { this.clearTo(); }
  private clearTo(): void {
    if (this.toId >= 0) { clearTimeout(this.toId); this.toId = -1; }
  }
  private reset(): void {
    this.clearTo();
    const pool: string[] = shuffled(POOL);
    this.sideA = pool.slice(0, this.diffTotal);
    this.sideB = pool.slice(this.diffTotal, this.diffTotal * 2);
    this.options = [];
    this.phase = 'study'; this.qIdx = 0; this.hits = 0; this.pick = -1;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.msg = TG2("记住这 {0} 组配对", String(this.diffTotal));
    this.toId = setTimeout(() => { this.toId = -1; this.ask(0); }, STUDY_MS);
  }
  /** 出第 k 题：给出左半，四选一右半 */
  private ask(k: number): void {
    this.phase = 'quiz'; this.qIdx = k; this.pick = -1; this.msg = TG('它的另一半是？');
    const others: string[] = [];
    for (let i = 0; i < this.sideB.length; i++) {
      if (i !== k) { others.push(this.sideB[i]); }
    }
    const mixed: string[] = shuffled(others);
    const ans: string = this.sideB[k];
    this.options = shuffled([ans, mixed[0], mixed[1], mixed[2]]);
  }
  private answer(o: string): void {
    if (this.phase !== 'quiz' || this.pick >= 0 || this.over) { return; }
    const k: number = this.qIdx;
    const ans: string = this.sideB[k];
    const ok: boolean = o === ans;
    this.pick = ok ? 1 : 0;
    if (ok) { this.hits = this.hits + 1; }
    this.msg = ok ? '✅ 对了' : TG2("❌ 应该是 {0}", ans);
    const last: boolean = k + 1 >= this.diffTotal;
    this.toId = setTimeout(() => {
      this.toId = -1;
      if (last) { this.end(); return; }
      this.ask(k + 1);
    }, 720);
  }
  private end(): void {
    if (this.done) { return; }
    this.clearTo();
    this.done = true; this.over = true; this.phase = 'done'; this.won = this.hits >= 5;
    this.msg = TG2(this.won ? '🎉 通关 · 答对 {0}/{1}' : '💤 结束 · 答对 {0}/{1}',Digits(String(this.hits), this.langCode),Digits(String(this.diffTotal), this.langCode));
    const r: GameResult = {
      gameId: 'relational_memory', solved: this.won, score: this.hits * 100,
      durationMs: Date.now() - this.startAt, levelReached: this.hits
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.hits) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 'study' ? '记忆 5 秒' : String(this.qIdx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      if (this.phase === 'study') {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
            Row({ space: Space.sm }) {
            Text(this.sideA[(i)]).fontSize(FontSize.lg).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(42))
            .backgroundColor(this.theme.surface).borderRadius(Radius.sm)
            Text('↔').accessibilityText(TG('对应')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
            Text(this.sideB[(i)]).fontSize(FontSize.lg).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(42))
            .backgroundColor(this.theme.surface).borderRadius(Radius.sm)
            }.width('100%')
          }, (i: number) => 'p' + i)
        }.width('100%')
      } else {
        Column({ space: Space.md }) {
          Text(this.sideA[this.qIdx]).fontSize(FontSize.hero).textAlign(TextAlign.Center)
            .width('100%').height(110).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
          ForEach(this.options, (o: string) => {
            Text((o)).fontSize(FontSize.xxl).textAlign(TextAlign.Center).width('100%').height(Cell.of(52))
            .backgroundColor(this.pick >= 0 && (o) === this.sideB[this.qIdx] ? Palette.emerald : this.theme.surface)
            .borderRadius(Radius.md).shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
            .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
              .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            .onClick(() => { Haptics.tick(); this.answer((o)); })
          }, (o: string) => o)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).textAlign(TextAlign.Center).width('100%')
        .fontColor(this.over && !this.won ? Palette.rose : this.theme.inkSoft)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.amber)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('判定：6 题答对 ≥ 5 通关；看 5 秒后开始答题'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).textAlign(TextAlign.Center).width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
