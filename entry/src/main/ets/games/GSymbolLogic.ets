/**
 * 符号逻辑（symbol_logic）—— 符号代数：由两条线索推出第一个符号是几（加/减题型）
 * 胜负：8 题答对 ≥6 ⇒ 通关；进度：题号 / 答对 / 题型
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SYMS: string[] = ['●', '▲', '■', '★', '◆', '✚'];
const OPT4: number[] = [0, 1, 2, 3];
const TOTAL: number = 8;
const NEED: number = 6;

@Component
export struct GSymbolLogic {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State no: number = 1;
  @State right: number = 0;
  @State s1: string = '●';
  @State s2: string = '▲';
  @State kind: number = 0;          // 0=加 1=减
  @State rhs: number = 0;
  @State bVal: number = 0;
  @State ans: number = 0;
  @State opts: number[] = [];
  @State pick: number = -1;
  @State msg: string = '';
  @State over: boolean = false;
  @State won: boolean = false;
  private startAt: number = 0;
  private to: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.to >= 0) { clearTimeout(this.to); this.to = -1; } }

  private reset(): void {
    this.clearAll();
    this.no = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.msg = TG('看点线索，推出第一个符号是几');
    this.startAt = Date.now();
    this.newPuzzle();
  }

  private newPuzzle(): void {
    const b: number = 1 + Math.floor(Math.random() * 5);
    const a: number = b + 1 + Math.floor(Math.random() * 5);
    let i1: number = Math.floor(Math.random() * SYMS.length);
    let i2: number = Math.floor(Math.random() * SYMS.length);
    if (i2 === i1) { i2 = (i2 + 1) % SYMS.length; }
    const opts: number[] = [a];
    while (opts.length < 4) {
      const off: number = 1 + Math.floor(Math.random() * 4);
      const cand: number = Math.random() < 0.5 ? a + off : a - off;
      if (cand > 0 && opts.indexOf(cand) < 0) { opts.push(cand); }
    }
    this.kind = Math.random() < 0.5 ? 0 : 1;
    this.s1 = SYMS[i1];
    this.s2 = SYMS[i2];
    this.rhs = this.kind === 0 ? a + b : a - b;
    this.bVal = b;
    this.ans = a;
    this.opts = opts;
    this.pick = -1;
    this.msg = TG2("题型：{0}", (this.kind === 0 ? '加法' : '减法'));
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    if (this.opts[i] === this.ans) { this.right = this.right + 1; this.msg = TG('✅ 正确'); }
    else { this.msg = TG2('❌ 应该是 {0}', String(this.ans)); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.no >= this.diffTotal) { this.finishUp(); return; }
      this.no = this.no + 1;
      this.newPuzzle();
    }, 700);
  }

  private finishUp(): void {
    if (this.done) { return; }
    this.done = true;
    this.over = true;
    this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关 ') : TG('💤 结束 ')) +TG2("答对 {0}/{1}", String(this.right), String(this.diffTotal));
    this.clearAll();
    const r: GameResult = {
      gameId: 'symbol_logic', solved: this.won, score: this.right * 130,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.no + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('题型'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.kind === 0 ? '加法' : '减法')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text((this.s1 + (this.kind === 0 ? ' + ' : ' − ') + this.s2 + ' = ' + String(this.rhs))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
        Text((this.s2 + ' = ' + String(this.bVal))).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
        Text((this.s1 + ' = ?')).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.theme.ink).width('100%').textAlign(TextAlign.Center)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        ForEach(OPT4, (i: number) => {
          Text(String(this.opts[(i)])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
          .fontColor(this.pick === (i) ? '#FFFFFF' : this.theme.ink)
          .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(60)).backgroundColor(this.pick === (i) ? Palette.lime : this.theme.surfaceAlt)
          .borderRadius(Radius.md).shadow(Shadow.card).scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 })
          .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { this.answer((i)); })
          // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
          .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        }, (i: number) => 'o' + i)
      }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.lime).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { this.reset(); })

      Text(TG('提示：先算第二个符号，再回代求第一个'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
