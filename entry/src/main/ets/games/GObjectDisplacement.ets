/**
 * 物体位移 —— 6 格里摆 5 个物件，遮罩一闪后其中一个偷偷换了格子，指出是谁动了
 * 胜负：8 轮答对 ≥ 6 ⇒ 通关　｜　进度：轮次 / 答对 / 得分
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const POOL: string[] = ['🍎', '🌙', '⚽', '🎈', '🐟', '🔔', '🍀', '🚀', '🎲', '🧩', '🌻', '🍄'];
const SLOTS: number = 6;
const ROUNDS: number = 8;
const NEED: number = 6;
const PEEK_MS: number = 1600;
const VEIL_MS: number = 700;
const CELLS: number[] = [0, 1, 2, 3, 4, 5];

@Component
export struct GObjectDisplacement {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State first: string[] = []; @State second: string[] = [];
  @State phase: number = 0;        // 0 记忆　1 遮罩　2 作答
  @State roundNo: number = 1; @State right: number = 0; @State score: number = 0;
  @State pick: number = -1; @State msg: string = '';
  @State over: boolean = false; @State won: boolean = false;
  private fromAt: number = -1; private toAt: number = -1;
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll();
    this.roundNo = 1; this.right = 0; this.score = 0; this.pick = -1; this.startAt = Date.now();
    this.over = false; this.won = false; this.done = false;
    this.newRound();
  }

  /** 摆好 5 个物件（留 1 个空格），再让其中一个挪进空格 */
  private newRound(): void {
    const bag: string[] = POOL.slice();
    const rest: string[] = [];
    while (rest.length < SLOTS - 1) {
      const k: number = Math.floor(Math.random() * bag.length);
      rest.push(bag[k]); bag.splice(k, 1);
    }
    const holeAt: number = Math.floor(Math.random() * SLOTS);
    const layout: string[] = rest.slice(0, holeAt).concat(['']).concat(rest.slice(holeAt));
    let srcAt: number = Math.floor(Math.random() * SLOTS);
    while (srcAt === holeAt) { srcAt = Math.floor(Math.random() * SLOTS); }
    const moved: string[] = layout.slice();
    moved[holeAt] = layout[srcAt]; moved[srcAt] = '';
    this.first = layout; this.second = moved; this.fromAt = srcAt; this.toAt = holeAt;
    this.pick = -1; this.phase = 0;
    this.msg = TG2("第 {0} 轮：记住每个物件在哪一格", this.roundNo);
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1; this.msg = TG('遮住了…');
      this.timer = setTimeout(() => {
        this.timer = -1; this.phase = 2; this.msg = TG('哪个物件换了格子？点它');
      }, VEIL_MS);
    }, PEEK_MS);
  }

  private answer(i: number): void {
    if (this.phase !== 2 || this.pick >= 0) { return; }
    this.pick = i;
    if (i === this.toAt || i === this.fromAt) {
      this.right = this.right + 1; this.score = this.score + 100;
      this.msg = i === this.toAt ? '✅ 对！它挪到了这里' : '✅ 对！它从这里挪走了';
    } else {
      this.msg = TG2('❌ 挪走的是 {0}（原本在第 {1} 格）', this.second[this.toAt], (this.fromAt + 1));
    }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, 950);
  }

  private next(): void {
    if (this.roundNo >= this.diffTotal) {
      this.over = true; this.won = this.right >= NEED;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("答对 {0} / {1}", this.right, this.diffTotal);
      this.clearAll(); this.finish(this.won);
      return;
    }
    this.roundNo = this.roundNo + 1;
    this.newRound();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'object_displacement', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.roundNo };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) { Column({ space: Space.xs }) {
      Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text((this.roundNo + ' / ' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card); Column({ space: Space.xs }) {
      Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint); Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
      }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card) }.width('100%')
      Grid() {
        ForEach(CELLS, (i: number) => { GridItem() {
        Stack() {
        if (this.phase === 0) {
        Text(this.first[(i)] === '' ? '·' : this.first[(i)]).fontSize(FontSize.xxl)
        } else if (this.phase === 1) {
        Text('❓').fontSize(FontSize.xl)
          .accessibilityLevel('no')
        } else {
        Text(this.second[(i)] === '' ? '·' : this.second[(i)]).fontSize(FontSize.xxl)
        }
        }.width('100%').aspectRatio(1).backgroundColor(this.pick === (i) ? Palette.lime : this.theme.surfaceAlt).borderRadius(Radius.md).shadow(Shadow.card)
        .scale({ x: this.pick === (i) ? Motion.pressScale : 1, y: this.pick === (i) ? Motion.pressScale : 1 })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
          .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
        .onClick(() => { Haptics.tick(); this.answer((i)); })

        } }, (i: number) => 'od' + i)
      }.columnsTemplate('1fr 1fr 1fr').rowsGap(Space.sm).columnsGap(Space.sm).width('100%').height(260)
      Text(this.msg).fontSize(FontSize.md).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：遮罩后只有一个物件换格，点它（点它原来的位置也算对）')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
