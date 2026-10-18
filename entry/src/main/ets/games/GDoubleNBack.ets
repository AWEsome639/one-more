/**
 * 双 N-back —— 位置与字母两条通道同时跟，各自和 N 步前比
 *
 * 胜负：N=2，20 个判断里正确 ≥15 ⇒ 通关
 * 进度：题号 / 正确数 / 判断数 / 当前 N
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const TOTAL: number = 12; const N: number = 2; const NEED: number = 15;
const LETTERS: string[] = ['A', 'B', 'D', 'E', 'F', 'H', 'K', 'L', 'M', 'P', 'R', 'S', 'T', 'X'];
const SLOTS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
@Component
export struct GDoubleNBack {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State private idx: number = 0;
  @State private selPos: boolean = false;
  @State private selLetter: boolean = false;
  @State private right: number = 0;
  @State private wrong: number = 0;
  /** ★ 2026-10-15 错误抖动 */
  @State private shakeX: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private posSeq: number[] = [];
  private letSeq: string[] = [];
  private startAt: number = 0;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  private buildSeq(): void {
    const ps: number[] = []; const ls: string[] = [];
    for (let i = 0; i < this.diffTotal; i++) {
      let p: number = Math.floor(Math.random() * 9);
      if (i >= N && Math.random() < 0.3) { p = ps[i - N]; }
      let ch: string = LETTERS[Math.floor(Math.random() * LETTERS.length)];
      if (i >= N && Math.random() < 0.3) { ch = ls[i - N]; }
      ps.push(p);
      ls.push(ch);
    }
    this.posSeq = ps; this.letSeq = ls;
  }
  private reset(): void {
    this.buildSeq(); this.idx = 0; this.selPos = false; this.selLetter = false; this.right = 0;
    this.wrong = 0; this.over = false; this.won = false; this.done = false;
    this.msg = TG('N = 2：和两步前的比，分别判断位置与字母'); this.startAt = Date.now();
  }
  private submit(): void {
    if (this.over) { return; }
    if (this.idx >= N) {
      const pMatch: boolean = this.posSeq[this.idx] === this.posSeq[this.idx - N];
      const lMatch: boolean = this.letSeq[this.idx] === this.letSeq[this.idx - N];
      let r: number = this.right; let w: number = this.wrong;
      if (this.selPos === pMatch) { r = r + 1; } else { w = w + 1; }
      if (this.selLetter === lMatch) { r = r + 1; } else { w = w + 1; }
      this.right = r; this.wrong = w; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    }
    if (this.idx >= this.diffTotal - 1) {
      this.finish();
      return;
    }
    this.idx = this.idx + 1; this.selPos = false; this.selLetter = false;
    this.msg = this.idx < N ? '前两题没有可比对象，直接下一题' : '位置与字母各判断一次，再进入下一题';
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG2('正确 {0} · 错误 {1}', String(this.right), String(this.wrong));
    const raw: number = this.right * 60 - this.wrong * 20; const r: GameResult = {
      gameId: 'double_n_back', solved: this.won,
      score: raw > 0 ? raw : 0, durationMs: Date.now() - this.startAt,
      levelReached: N
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.idx + 1) + '/' + String(this.diffTotal))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('正确'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('判断'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right + this.wrong))).fontSize(FontSize.md)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text(('N')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(N))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Row({ space: Space.md }) {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.xs }) {
              ForEach([0, 1, 2], (c: number) => {
                Stack() {
                Text(this.posSeq.length > 0 && (r * 3 + c) === this.posSeq[this.idx] ? '●' : '').fontSize(FontSize.lg).fontColor('#FFFFFF')
                }.layoutWeight(1).aspectRatio(1).backgroundColor(this.posSeq.length > 0 && (r * 3 + c) === this.posSeq[this.idx] ? Palette.orange : this.theme.surfaceAlt)
                .borderRadius(Radius.sm).animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'nc' + c)
            }.width('100%')
          }, (r: number) => 'nr' + r)
        }.layoutWeight(2)
        Text(this.letSeq.length > 0 ? this.letSeq[this.idx] : '·').fontSize(FontSize.hero)
          .fontWeight(FontWeight.Bold).fontColor(Palette.orange).textAlign(TextAlign.Center).layoutWeight(1)
          .height(120).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)
      }.width('100%')
      Text(this.msg).fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        Text((true ? this.selPos : this.selLetter) ? '✔ ' + (TG('位置 = 2-back')) : (TG('位置 = 2-back'))).fontSize(FontSize.sm)
        .fontColor((true ? this.selPos : this.selLetter) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(44))
        .backgroundColor((true ? this.selPos : this.selLetter) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.idx >= N ? 1 : 0.45).enabled(this.idx >= N)
        .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
        if (true) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; }
        })
        Text((false ? this.selPos : this.selLetter) ? '✔ ' + (TG('字母 = 2-back')) : (TG('字母 = 2-back'))).fontSize(FontSize.sm)
        .fontColor((false ? this.selPos : this.selLetter) ? '#FFFFFF' : this.theme.ink).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(44))
        .backgroundColor((false ? this.selPos : this.selLetter) ? Palette.primaryDeep : this.theme.surfaceAlt)
        .borderRadius(Radius.md).opacity(this.idx >= N ? 1 : 0.45).enabled(this.idx >= N)
        .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
        if (false) { this.selPos = !this.selPos; } else { this.selLetter = !this.selLetter; }
        })
      }.width('100%')
      Row({ space: Space.sm }) {
        Button(this.idx >= this.diffTotal - 1 ? '提交结算' : '下一题 ▶')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.orange).borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { this.submit(); })
        Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md).width(96).height(Cell.of(46)).onClick(() => { this.reset(); })
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
