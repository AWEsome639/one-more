/**
 * 双编码 —— 词与图一起记（言语 + 视觉两条通道），再按词找图
 *
 * 胜负：6 题答对 5 题以上 ⇒ 通关
 * 进度：记忆倒计时 / 题号 / 答对数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { AppClock } from '../core/AppClock';
const KEEP: number = 6;      // 要记的词图对
const NEED: number = 5; const SECONDS: number = 8;
interface Pair {
  word: string;
  icon: string;
}
const PAIRS: Pair[] = [
  { word: TG('苹果'), icon: '🍎' }, { word: '汽车', icon: '🚗' },
  { word: '火箭', icon: '🚀' }, { word: '小猫', icon: '🐱' },
  { word: '雨伞', icon: '☂️' }, { word: '钢琴', icon: '🎹' },
  { word: '相机', icon: '📷' }, { word: '闹钟', icon: '⏰' },
  { word: '足球', icon: '⚽' }, { word: '蛋糕', icon: '🍰' },
  { word: '灯泡', icon: '💡' }, { word: '钥匙', icon: '🔑' }
];
@Component
export struct GDualCoding {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};
  @State private pairs: Pair[] = [];
  @State private quiz: Pair[] = [];
  @State private phase: number = 0;        // 0 记忆 1 答题
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(SECONDS);
  @State private left: number = 0;
  @State private qNo: number = 0;
  @State private right: number = 0;
  @State private opts: string[] = [];
  @State private pick: number = -1;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private timer: number = -1;
  private to1: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(SECONDS);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }
  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
  }
  private reset(): void {
    this.stop();
    const bag: Pair[] = PAIRS.slice(); const kept: Pair[] = [];
    while (kept.length < KEEP) {
      kept.push(bag.splice(Math.floor(Math.random() * bag.length), 1)[0]);
    }
    const order: Pair[] = kept.slice(); const mixed: Pair[] = [];
    while (order.length > 0) {
      mixed.push(order.splice(Math.floor(Math.random() * order.length), 1)[0]);
    }
    this.pairs = kept; this.quiz = mixed; this.phase = 0; this.left = this.total; this.qNo = 0;
    this.right = 0; this.pick = -1; this.opts = []; this.over = false; this.won = false;
    this.done = false; this.msg = TG('看图记词，两条通道一起用'); this.startAt = Date.now();
    this.timer = setInterval(() => {
      if (AppClock.isPaused()) { return; }
      if (this.phase !== 0) { return; }
      this.left = this.left - 1;
      if (this.left <= 0) { this.startQuiz(); }
    }, 1000);
  }
  private startQuiz(): void {
    this.stop(); this.phase = 1; this.qNo = 0; this.pick = -1; this.buildOpts();
  }
  private buildOpts(): void {
    const target: Pair = this.quiz[this.qNo]; const others: string[] = [];
    for (let i = 0; i < this.pairs.length; i++) {
      if (this.pairs[i].icon !== target.icon) { others.push(this.pairs[i].icon); }
    }
    const list: string[] = [target.icon];
    while (list.length < 4 && others.length > 0) {
      list.push(others.splice(Math.floor(Math.random() * others.length), 1)[0]);
    }
    const mixed: string[] = [];
    while (list.length > 0) {
      mixed.push(list.splice(Math.floor(Math.random() * list.length), 1)[0]);
    }
    this.opts = mixed; this.msg = TG2("第 {0} 题：这个词配哪张图？", String(this.qNo + 1));
  }
  private answer(i: number): void {
    if (this.over || this.phase !== 1 || this.pick >= 0) { return; }
    this.pick = i;
    if (this.opts[i] === this.quiz[this.qNo].icon) {
      this.right = this.right + 1; this.msg = TG('✅ 对！');
    } else {
      this.msg = TG2("❌ 应该是 {0}", this.quiz[this.qNo].icon);
    }
    this.to1 = setTimeout(() => {
      this.to1 = -1;
      if (this.qNo >= this.quiz.length - 1) {
        this.finish();
        return;
      }
      this.qNo = this.qNo + 1; this.pick = -1; this.buildOpts();
    }, 850);
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + TG('答对 ') + String(this.right) + '/' + String(KEEP);
    const r: GameResult = {
      gameId: 'dual_coding', solved: this.won,
      score: this.right * 150, durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('阶段'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? TG('记忆') : '答题')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((this.phase === 0 ? '倒计时' : TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.phase === 0 ? String(this.left) + 's' : String(this.qNo + 1) + '/' + String(KEEP))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      if (this.phase === 0) {
        Column({ space: Space.sm }) {
          ForEach([0, 1, 2], (r: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1], (c: number) => {
                Column({ space: 2 }) {
                Text((r * 2 + c) < this.pairs.length ? this.pairs[(r * 2 + c)].icon : '').fontSize(FontSize.xxl)
                Text((r * 2 + c) < this.pairs.length ? this.pairs[(r * 2 + c)].word : '').fontSize(FontSize.xs).fontColor(this.theme.inkSoft)
                }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
                .animation({ duration: Motion.fast, curve: Motion.snap() })
              }, (c: number) => 'mc' + c)
            }.width('100%')
          }, (r: number) => 'mr' + r)
        }.width('100%')
      } else {
        Column({ space: Space.sm }) {
          Text(this.quiz.length > 0 ? this.quiz[this.qNo].word : '').fontSize(FontSize.xxl)
            .fontWeight(FontWeight.Bold).fontColor(Palette.cyan).textAlign(TextAlign.Center).width('100%')
            .height(Cell.of(56)).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
          ForEach([0, 1], (r: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1], (c: number) => {
                Text((r * 2 + c) < this.opts.length ? this.opts[(r * 2 + c)] : '·').fontSize(FontSize.xxl).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(64))
                .backgroundColor(this.pick === (r * 2 + c) ? Palette.primaryDeep : this.theme.surfaceAlt)
                .borderRadius(Radius.md).opacity(this.pick >= 0 && this.pick !== (r * 2 + c) ? 0.5 : 1)
                .scale({ x: this.pick === (r * 2 + c) ? Motion.pressScale : 1, y: this.pick === (r * 2 + c) ? Motion.pressScale : 1 })
                .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.answer((r * 2 + c)); })
              }, (c: number) => 'qc' + c)
            }.width('100%')
          }, (r: number) => 'qr' + r)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        if (this.phase === 0) {
          Button(TG('我记住了 ▶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.cyan)
            .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.startQuiz(); })
        }
        Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.phase === 0 ? '#FFFFFF' : this.theme.ink)
          .backgroundColor(this.phase === 0 ? Palette.primary : this.theme.surfaceAlt)
          .borderRadius(Radius.md).layoutWeight(1).height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
