/**
 * 时间线记忆 —— 事件按顺序逐个登场，打乱后照原顺序点回来
 *
 * 胜负：3 轮答对 2 轮以上 ⇒ 通关（一轮 4 个事件全对才算对）
 * 进度：轮次 / 答对轮数 / 本轮已点
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
const ROUNDS: number = 3; const NEED: number = 2; const LEN: number = 4; const REVEAL: number = 900;
interface Ev {
  k: number;
  icon: string;
  label: string;
}
const POOL: Ev[] = [
  { k: 0, icon: '🌅', label: '起床' }, { k: 1, icon: '☕', label: '早餐' },
  { k: 2, icon: '🚌', label: '通勤' }, { k: 3, icon: '💻', label: '工作' },
  { k: 4, icon: '🍜', label: '午餐' }, { k: 5, icon: '📞', label: '开会' },
  { k: 6, icon: '🏃', label: '运动' }, { k: 7, icon: '🍽️', label: '晚餐' },
  { k: 8, icon: '📖', label: '阅读' }, { k: 9, icon: '🌙', label: '睡觉' }
];
@Component
export struct GEventTimelineMemory {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：ROUNDS 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(ROUNDS);
  onFinish: (r: GameResult) => void = () => {};
  @State private evs: Ev[] = [];        // 真实顺序
  @State private cards: Ev[] = [];      // 打乱后的牌面
  @State private shown: number = 0;     // 已登场几个
  @State private picks: number[] = [];
  @State private phase: number = 0;     // 0 登场 1 作答
  @State private roundNo: number = 1;
  @State private right: number = 0;
  @State private totalHit: number = 0;
  @State private msg: string = '';
  @State private over: boolean = false;
  @State private won: boolean = false;
  private startAt: number = 0;
  private to1: number = -1;
  private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(ROUNDS);
     this.reset(); }
  aboutToDisappear(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
  }
  private reset(): void {
    if (this.to1 >= 0) { clearTimeout(this.to1); this.to1 = -1; }
    this.roundNo = 1; this.right = 0; this.totalHit = 0; this.over = false; this.won = false;
    this.done = false; this.startAt = Date.now(); this.newRound();
  }
  private newRound(): void {
    const bag: Ev[] = POOL.slice(); const picked: Ev[] = [];
    while (picked.length < LEN) {
      picked.push(bag.splice(Math.floor(Math.random() * bag.length), 1)[0]);
    }
    this.evs = picked; this.cards = []; this.picks = []; this.shown = 0; this.phase = 0;
    this.msg = TG2("第 {0} 轮：记住登场顺序", String(this.roundNo)); this.reveal(0);
  }
  private reveal(k: number): void {
    if (k >= LEN) {
      this.msg = TG('记住顺序了？点「打乱作答」');
      return;
    }
    this.shown = k + 1; this.to1 = setTimeout(() => { this.to1 = -1; this.reveal(k + 1); }, REVEAL);
  }
  private shuffleIn(): void {
    if (this.phase !== 0 || this.over) { return; }
    const bag: Ev[] = this.evs.slice(); const mixed: Ev[] = [];
    while (bag.length > 0) {
      mixed.push(bag.splice(Math.floor(Math.random() * bag.length), 1)[0]);
    }
    this.cards = mixed; this.picks = []; this.phase = 1; this.msg = TG('按刚才的顺序依次点这 4 张牌');
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoStop(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoLeft > 0;
    this.demoLeft = 0;
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoLeft = Hint.DEMO_STEPS;
    this.demoId = Hint.demoRun(() => this.demoStep());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase === 0) {
      if (this.to1 >= 0) {
        return true;             // 还在逐个登场，等它演完
      }
      this.shuffleIn();          // 演完了 ⇒ 替玩家按「打乱作答」
      return true;
    }
    if (this.phase !== 1) {
      return true;               // 2 = 结算中，等 1300ms 换下一轮
    }
    const want: number = this.evs[this.picks.length].k;
    for (let i = 0; i < this.cards.length; i++) {
      if (this.cards[i].k === want) {
        this.tapCard(i);
        return !this.over;
      }
    }
    return false;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.phase === 0) {
      const seq: string[] = [];
      for (let i = 0; i < this.evs.length; i++) {
        seq.push(this.evs[i].icon + this.evs[i].label);
      }
      return Hint.make([],
        TG2('登场顺序：{0}', seq.join(' → ')),
        TG2('The order was: {0}', seq.join(' -> ')), t0);
    }
    if (this.phase !== 1) {
      return Hint.none('none');
    }
    const want: Ev = this.evs[this.picks.length];
    return Hint.make([],
      TG2('下一个点「{0}」', want.icon + want.label),
      TG2('Tap {0} next', want.icon + want.label), t0);
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

  private tapCard(i: number): void {
    if (this.over || this.phase !== 1 || this.picks.indexOf(i) >= 0) { return; }
    const next: number[] = this.picks.slice();
    next.push(i);
    this.picks = next;
    if (next.length < LEN) { return; }
    let hit: number = 0;
    for (let j = 0; j < LEN; j++) {
      if (this.cards[next[j]].k === this.evs[j].k) { hit = hit + 1; }
    }
    this.totalHit = this.totalHit + hit;
    if (hit === LEN) {
      this.right = this.right + 1; this.msg = TG('✅ 完全正确！');
    } else {
      this.msg = TG2('❌ 顺序对了 {0}/{1}：', String(hit), String(LEN))
        + this.evs[0].icon + this.evs[1].icon + this.evs[2].icon + this.evs[3].icon;
    }
    this.phase = 2; this.to1 = setTimeout(() => {
      this.to1 = -1;
      if (this.roundNo >= this.diffTotal) {
        this.finish();
        return;
      }
      this.roundNo = this.roundNo + 1; this.newRound();
    }, 1300);
  }
  private finish(): void {
    if (this.done) { return; }
    this.done = true; this.over = true; this.won = this.right >= NEED;
    this.msg = (this.won ? TG('🎉 通关！') : TG('💤 本局结束：'))
      + '全对 ' + String(this.right) + '/' + String(this.diffTotal) + TG(' 轮');
    const r: GameResult = {
      gameId: 'event_timeline_memory', solved: this.won,
      score: this.totalHit * 60, durationMs: Date.now() - this.startAt,
      levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('轮次'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.roundNo) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('全对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.right), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.picks.length) + '/' + String(LEN))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      if (this.phase === 0) {
        Column({ space: Space.xs }) {
          ForEach([0, 1, 2, 3], (i: number) => {
            Row({ space: Space.sm }) {
            Text(this.evs.length > (i) ? this.evs[(i)].icon : '·').fontSize(FontSize.xl)
            Text(this.evs.length > (i) ? this.evs[(i)].label : '').fontSize(FontSize.sm).fontColor(this.theme.inkSoft).layoutWeight(1)
            Text((i) < this.shown ? '✔' : '…').fontSize(FontSize.sm).fontColor((i) < this.shown ? Palette.success : this.theme.inkFaint)
            }.width('100%').padding(Space.sm).backgroundColor((i) < this.shown ? this.theme.surfaceAlt : this.theme.surface).borderRadius(Radius.md)
            .opacity((i) < this.shown ? 1 : 0.4).animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (i: number) => 'ev' + i)
        }.width('100%')
      } else {
        Column({ space: Space.sm }) {
          ForEach([0, 1], (r: number) => {
            Row({ space: Space.sm }) {
              ForEach([0, 1], (c: number) => {
                Column({ space: 2 }) {
                Text(this.cards.length > (r * 2 + c) ? this.cards[(r * 2 + c)].icon : '·').fontSize(FontSize.xxl)
                Text(this.cards.length > (r * 2 + c) ? this.cards[(r * 2 + c)].label : '').fontSize(FontSize.xs).fontColor(this.theme.inkSoft)
                Text(this.picks.indexOf((r * 2 + c)) >= 0 ? TG('第 ') + String(this.picks.indexOf((r * 2 + c)) + 1) + ' 位' : ' ')
                .fontSize(FontSize.xxs).fontColor(this.picks.indexOf((r * 2 + c)) >= 0 ? Palette.berry : this.theme.inkFaint)
                }.layoutWeight(1).padding(Space.sm).backgroundColor(this.picks.indexOf((r * 2 + c)) >= 0 ? '#22EC4899' : this.theme.surfaceAlt)
                .borderRadius(Radius.md).borderWidth(2).borderColor(this.picks.indexOf((r * 2 + c)) >= 0 ? Palette.berry : this.theme.line)
                .scale({ x: this.picks.indexOf((r * 2 + c)) >= 0 ? Motion.pressScale : 1, y: this.picks.indexOf((r * 2 + c)) >= 0 ? Motion.pressScale : 1 })
                .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tapCard((r * 2 + c)); })
              }, (c: number) => 'cc' + c)
            }.width('100%')
          }, (r: number) => 'cr' + r)
        }.width('100%')
      }
      Text(this.msg).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      if (this.phase === 0) {
        Button(TG('打乱作答 ▶'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.berry)
          .borderRadius(Radius.md).width('100%').height(Cell.of(46)).enabled(this.shown >= LEN)
          .opacity(this.shown >= LEN ? 1 : 0.5).onClick(() => { Haptics.tap(); this.shuffleIn(); })
      }
      Button(this.over ? TG('再来一局') : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(this.phase === 0 ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.phase === 0 ? Palette.primary : this.theme.surfaceAlt)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
