/**
 * 拥挤视力（visual_crowding_acuity）—— 只答正中间那个字母：两侧干扰越挤，越难认
 * 胜负：8 题答对 ≥6 ⇒ 通关；进度：题号 / 答对 / 当前间距
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const POOL: string[] = ['E', 'F', 'H', 'N', 'P', 'R', 'T', 'Z'];
const FIVE: number[] = [0, 1, 2, 3, 4];
const ROWS: number[] = [0, 1];
const COLS: number[] = [0, 1];
const TOTAL: number = 8;
const NEED: number = 6;

@Component
export struct GVisualCrowdingAcuity {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State trialNo: number = 1;
  @State right: number = 0;
  @State target: string = 'E';
  @State flank: string = 'H';
  @State opts: string[] = [];
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

  /** 越往后两侧贴得越近 ⇒ 拥挤越强 */
  private gap(): number { return Math.max(0, Space.xxxl - (this.trialNo - 1) * Space.xs); }

  private reset(): void {
    this.clearAll();
    this.trialNo = 1; this.right = 0; this.pick = -1; this.over = false; this.won = false;
    this.done = false; this.msg = TG('只答正中间那个字母，两侧都是干扰');
    this.startAt = Date.now();
    this.newTrial();
  }

  private newTrial(): void {
    const t: string = POOL[Math.floor(Math.random() * POOL.length)];
    let f: string = POOL[Math.floor(Math.random() * POOL.length)];
    while (f === t) { f = POOL[Math.floor(Math.random() * POOL.length)]; }
    const opts: string[] = [t];
    while (opts.length < 4) {
      const x: string = POOL[Math.floor(Math.random() * POOL.length)];
      if (opts.indexOf(x) < 0) { opts.push(x); }
    }
    this.target = t;
    this.flank = f;
    this.opts = opts;
    this.pick = -1;
  }

  private answer(i: number): void {
    if (this.pick >= 0 || this.over) { return; }
    this.pick = i;
    if (this.opts[i] === this.target) { this.right = this.right + 1; this.msg = TG2('✅ 正确，中间是 {0}', this.target); }
    else { this.msg = TG2('❌ 中间是 {0}', this.target); }
    this.to = setTimeout(() => {
      this.to = -1;
      if (this.trialNo >= this.diffTotal) { this.finishUp(); return; }
      this.trialNo = this.trialNo + 1;
      this.newTrial();
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
      gameId: 'visual_crowding_acuity', solved: this.won, score: this.right * 130,
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
        Text((String(this.trialNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('间距'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.gap()))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Row({ space: this.gap() }) {
          ForEach(FIVE, (c: number) => {
            Text(c === 2 ? this.target : this.flank).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(c === 2 ? Palette.berry : this.theme.inkSoft).textAlign(TextAlign.Center)
          }, (c: number) => 'l' + c)
        }.width('100%').justifyContent(FlexAlign.Center)
        Text(TG('两侧越挤，中间越难认')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%').height(148).justifyContent(FlexAlign.Center).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Column({ space: Space.sm }) {
        ForEach(ROWS, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(COLS, (c: number) => {
              Text(this.opts[(r * 2 + c)]).fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
              .fontColor(this.pick === (r * 2 + c) ? '#FFFFFF' : this.theme.ink)
              .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(58))
              .backgroundColor(this.pick === (r * 2 + c) ? Palette.berry : this.theme.surfaceAlt)
              .borderRadius(Radius.md).shadow(Shadow.card)
              .scale({ x: this.pick === (r * 2 + c) ? Motion.pressScale : 1, y: this.pick === (r * 2 + c) ? Motion.pressScale : 1 })
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { this.answer((r * 2 + c)); })
            }, (c: number) => 'o' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(Palette.berry).borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .onClick(() => { this.reset(); })

      Text(TG('提示：越挤越要靠特征辨认，别猜整体轮廓'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
