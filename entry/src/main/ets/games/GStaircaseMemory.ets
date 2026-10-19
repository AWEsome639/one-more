/**
 * 阶梯记忆 —— 六级台阶逐级点亮成一段升序路线，暗下后照着顺序点回来
 * 胜负：4 关从 3 级加到 6 级，全过通关，错一级即失败
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const STEPS: number = 6;
const LEVELS: number = 4;
const STEP_MS: number = 620;

@Component
export struct GStaircaseMemory {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  @State private pulse: number = 1;   // ★ 2026-10-16 得分跳动
  onFinish: (r: GameResult) => void = () => {};

  @State private order: number[] = [];   // 本关要走的台阶
  @State private cursor: number = 0;      // 演示到第几级（-1 = 演示结束 / 0 = 还没开始）
  @State private cur: number = 0;         // 轮到玩家点第几级
  @State private level: number = 1;
  @State private phase: number = 0;       // 0 演示 1 作答 2 判错
  @State private score: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private flashId: number = -1;
  private stepTo: number = -1;
  private wrongTo: number = -1;
  private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }

  private clearAll(): void {
    if (this.flashId >= 0) { clearInterval(this.flashId); this.flashId = -1; }
    if (this.stepTo >= 0) { clearTimeout(this.stepTo); this.stepTo = -1; }
    if (this.wrongTo >= 0) { clearTimeout(this.wrongTo); this.wrongTo = -1; }
  }

  private reset(): void {
    this.clearAll();
    this.order = []; this.cursor = 0; this.cur = 0; this.level = 1; this.phase = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now();
    this.newLevel();
  }

  /** 本关台阶数 = 2 + 关数；从底级往上一级一级亮 */
  private newLevel(): void {
    const n: number = 2 + this.level;
    const pick: number[] = [];
    for (let i = 0; i < n; i++) { pick.push(i); }
    this.order = pick;
    this.cur = 0;
    this.cursor = 0;
    this.phase = 0;
    this.msg = TG('第 ') + String(this.level) + '/' + String(this.diffTotal) + ' 关 · 看它亮 ' + String(n) + ' 级';
    this.flashId = setInterval(() => {
      if (this.cursor >= this.order.length - 1) {
        if (this.flashId >= 0) { clearInterval(this.flashId); this.flashId = -1; }
        this.phase = 1;
        this.cursor = -1;
        this.msg = TG(TG(TG('照着顺序点回来（从最低一级起）')));
        return;
      }
      this.cursor = this.cursor + 1;
    }, STEP_MS);
  }

  private tap(i: number): void {
    if (this.over || this.phase !== 1) { return; }
    if (this.order[this.cur] !== i) {
      this.phase = 2;
      this.msg = TG2('❌ 错在第 {0} 级', String(this.cur + 1));
      this.wrongTo = setTimeout(() => { this.wrongTo = -1; this.stop(false); }, 900);
      return;
    }
    this.cur = this.cur + 1;
    if (this.cur < this.order.length) {
      this.msg = TG('还差 ') + String(this.order.length - this.cur) + ' 级';
      return;
    }
    this.score = this.score + this.order.length * 60;
    if (this.level >= this.diffTotal) { this.stop(true); return; }
    this.phase = 3;
    this.msg = TG('✅ 第 ') + String(this.level) + ' 关走通，下一关更陡';
    this.stepTo = setTimeout(() => {
      this.stepTo = -1;
      this.level = this.level + 1; this.pulse = 1.045; setTimeout(() => { this.pulse = 1; }, 110);
      this.newLevel();
    }, 800);
  }

  private stop(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    this.clearAll();
    this.over = true; this.won = solved;
    this.msg = (solved ? TG('🎉 通关 ') : TG('💤 失败 ')) +TG2("走到第 {0} 关 · 得分 {1}",Digits(String(this.level), this.langCode),Digits(String(this.score), this.langCode));
    const res: GameResult = {
      gameId: 'staircase_memory', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.level
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  /** 演示阶段：亮到第 cursor 级之前都算走过；作答阶段显示台阶号 */
  private lit(i: number): boolean {
    return this.phase === 0 && i < this.cursor;
  }

  private face(i: number): string {
    if (this.phase === 2 && i === this.order[this.cur]) { return '❌'; }
    return this.lit(i) ? '✔' : String(i + 1);
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        Text(TG2('关卡 {0}/{1}',Digits(String(this.level), this.langCode),Digits(String(this.diffTotal), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink).scale({ x: this.pulse, y: this.pulse }).animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2('级数 {0}', String(this.order.length))).fontSize(FontSize.sm).fontColor(Palette.berry)
        Text(TG2("得分 {0}",Digits(String(this.score), this.langCode))).fontSize(FontSize.sm).fontColor(this.theme.ink)
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surface)
      .borderRadius(Radius.md).shadow(Shadow.card).justifyContent(FlexAlign.SpaceBetween)
      Column({ space: Space.xs }) {
        ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
          this.stepRow(i)
        }, (i: number) => 's' + i)
      }
      .width('100%').padding(Space.sm)
      .backgroundColor(this.theme.isDark ? '#141414' : '#E2E8F0').borderRadius(Radius.lg)
      Text(this.msg)
        .fontSize(FontSize.sm).fontColor(this.phase === 2 ? Palette.rose : this.theme.inkSoft)
        .width('100%').textAlign(TextAlign.Center)
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF')
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.berry)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  /** 台阶越高越窄 —— 形状本身就在提示"只能往上走" */
  @Builder
  stepRow(i: number) {
    Row() {
      Blank()
      Text(this.face(i))
        .fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .fontColor(this.lit(i) ? '#FFFFFF' : this.theme.ink)
        .width(48 + (STEPS - i) * 26).height(Cell.of(34))
        .backgroundColor(this.lit(i) ? Palette.berry : this.theme.surface)
        .borderRadius(Radius.sm)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        .onClick(() => { Haptics.tick(); this.tap(i); })
    }.width('100%')
  }
}
