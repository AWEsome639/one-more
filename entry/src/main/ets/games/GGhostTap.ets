/**
 * 幽灵点击 —— 4×4 阵里幽灵一闪即逝，趁它还在时点中它（越到后面越快）
 * 胜负：15 只里抓到 ≥ 12 只 ⇒ 通关；进度：第 n 只 / 抓到 / 溜走
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const SIZE: number = 4;
const CELLS: number = SIZE * SIZE;
const GHOSTS: number = 15;
const WIN_HITS: number = 12;

@Component
export struct GGhostTap {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GHOSTS 按难度换算
  @State private diffTotal: number = GameDiff.sizeNow(GHOSTS);
  onFinish: (r: GameResult) => void = () => {};

  @State private ghostIdx: number = -1;
  @State private flash: number = -1;
  @State private fbOk: boolean = true;
  @State private spawnN: number = 0;
  @State private hitN: number = 0;
  @State private missN: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private lifeTo: number = -1;
  private nextTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GHOSTS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.lifeTo >= 0) { clearTimeout(this.lifeTo); this.lifeTo = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.ghostIdx = -1; this.flash = -1; this.fbOk = true;
    this.spawnN = 0; this.hitN = 0; this.missN = 0;
    this.over = false; this.won = false; this.done = false;
    this.msg = TG('幽灵一现就点它（越到后面越快）');
    this.startAt = Date.now();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.spawn(); }, 700);
  }

  private spawn(): void {
    if (this.over) { return; }
    if (this.spawnN >= this.diffTotal) { this.judge(); return; }
    this.spawnN = this.spawnN + 1;
    let idx: number = Math.floor(Math.random() * CELLS);
    if (idx === this.ghostIdx) { idx = (idx + 1) % CELLS; }
    this.ghostIdx = idx;
    this.flash = -1;
    this.msg = TG('👻 出现了！');
    const life: number = this.spawnN <= 5 ? 820 : (this.spawnN <= 10 ? 620 : 460);
    this.lifeTo = setTimeout(() => { this.lifeTo = -1; this.expire(); }, life);
  }

  private expire(): void {
    if (this.over) { return; }
    if (this.ghostIdx >= 0) {
      this.missN = this.missN + 1;
      this.flash = this.ghostIdx;
      this.fbOk = false;
      this.msg = TG('👻 溜走了');
      this.ghostIdx = -1;
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.flash = -1; this.spawn(); }, 240);
  }

  private tapCell(i: number): void {
    if (this.over) { return; }
    if (this.ghostIdx < 0) { this.msg = TG('❌ 这里空空的'); return; }
    if (i === this.ghostIdx) {
      this.hitN = this.hitN + 1;
      this.flash = i; this.fbOk = true;
      this.msg = TG('✅ 抓住了');
      this.ghostIdx = -1;
      if (this.lifeTo >= 0) { clearTimeout(this.lifeTo); this.lifeTo = -1; }
    } else {
      this.missN = this.missN + 1;      // 点偏了，幽灵仍在，还能再点
      this.flash = i; this.fbOk = false;
      this.msg = TG('❌ 点偏了，它还在！');
      return;
    }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.flash = -1; this.spawn(); }, 240);
  }

  private judge(): void {
    this.clearAll();
    this.ghostIdx = -1; this.over = true; this.won = this.hitN >= WIN_HITS;
    this.msg = TG2(this.won ? '🎉 通关！抓到 {0}/{1}' : '💤 结束，抓到 {0}/{1}',Digits(String(this.hitN), this.langCode),Digits(String(this.diffTotal), this.langCode));
    if (!this.done) {
      this.done = true;
      const r: GameResult = {
        gameId: 'ghost_tap', solved: this.won,
        score: Math.max(0, this.hitN * 80 - this.missN * 20),
        durationMs: Date.now() - this.startAt, levelReached: this.hitN
      };
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish(r);
    }
  }

  private cellColor(i: number): string {
    if (this.flash === i) { return this.fbOk ? Palette.emerald : Palette.rose; }
    if (this.ghostIdx === i) { return Palette.lime; }
    return this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('第几只'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.spawnN) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('抓到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.hitN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('溜走'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.missN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3], (row: number) => {
          Row({ space: Space.xs }) {
            ForEach([0, 1, 2, 3], (col: number) => {
              Stack() {
              Text(this.ghostIdx === (row * SIZE + col) ? '👻' : '').fontSize(FontSize.xxl)
              }.layoutWeight(1).aspectRatio(1)
              .backgroundColor(this.cellColor((row * SIZE + col))).borderRadius(Radius.md)
              .animation({ duration: Motion.fast, curve: Motion.snap() })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
              .onClick(() => { this.tapCell((row * SIZE + col)); })
            }, (col: number) => 'c' + col + this.cellColor(row * SIZE + col))
          }.width('100%')
        }, (row: number) => 'r' + row)
      }.width('100%').aspectRatio(1).padding(Space.sm)
      .backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)

      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .borderRadius(Radius.md).width('100%').height(Space.xxxl)
        .onClick(() => { this.reset(); })

      Text(TG2('判定：{0} 只里抓到 {1} 只即通关，点偏会拖慢节奏',Digits(String(this.diffTotal), this.langCode),Digits(String(WIN_HITS), this.langCode)))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
