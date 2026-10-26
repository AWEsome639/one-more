/**
 * 缺运算符 —— 填入正确运算符
 * 玩法：等式里缺一个 + − × ÷，选出能让等式成立的那一个。
 * 胜负：60 秒内答对 10 题 ⇒ 通关；时间归零 ⇒ 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const GOAL: number = 10; const LIMIT: number = 60; const TICK_MS: number = 1000;
const PENALTY: number = 3; const NEXT_MS: number = 400;
const OPS: string[] = ['＋', '−', '×', '÷'];
const OPT_IDX: number[] = [0, 1, 2, 3];

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GMissingOperator {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private a: number = 0;
  @State private b: number = 0;
  @State private c: number = 0;
  @State private ansKind: number = 0;
  @State private picked: number = -1;
  @State private right: number = 0;
  @State private combo: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private press: number = -1;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1;
  private nextTo: number = -1; private finished: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void {
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; }
  }

  private reset(): void {
    this.stop();
    this.right = 0; this.combo = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.ask();
    this.msg = TG('把问号换成一个运算符，让等式成立');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); }
  }

  private ask(): void {
    const kind: number = ri(0, 3);
    let a: number = 0;
    let b: number = 0;
    let c: number = 0;
    if (kind === 0) {
      a = ri(11, 89); b = ri(11, 89); c = a + b;
    } else if (kind === 1) {
      a = ri(40, 99); b = ri(11, a - 11); c = a - b;
    } else if (kind === 2) {
      a = ri(3, 12); b = ri(3, 12); c = a * b;
    } else {
      b = ri(3, 12); c = ri(3, 12); a = b * c;
    }
    this.a = a; this.b = b; this.c = c; this.ansKind = kind; this.picked = -1;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 字段直取：缺失运算符，答案就在 this.ansKind
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.picked >= 0 || this.over) {
      return true;
    }
    this.pick(this.ansKind);
    return !this.over;
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

  private pick(kind: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = kind;
    if (kind === this.ansKind) {
      this.right = this.right + 1; this.combo = this.combo + 1;
      this.score = this.score + 50 + this.combo * 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = '✅ 答对！' + String(this.a) + ' ' + OPS[this.ansKind] + ' ' + String(this.b) + ' = ' + String(this.c);
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 15); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒 —— 应该是 {1}",Digits(String(PENALTY), this.langCode), OPS[this.ansKind]);
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) { return; }
    if (this.right >= GOAL) { this.end(true, TG('🎉 答对 ') + String(GOAL) + TG(' 题，通关！剩 ') + String(this.left) + TG(' 秒')); return; }
    if (this.left <= 0) { this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); return; }
    this.ask();
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'missing_operator', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.right
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.right) + '/' + String(GOAL))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        Text(String(this.a) + '  ' + (this.picked < 0 ? '?' : OPS[this.picked]) + '  ' +
          String(this.b) + ' = ' + String(this.c))
          .fontSize(FontSize.hero).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).width('100%')
          .fontColor(this.picked < 0 ? Palette.primary
            : (this.picked === this.ansKind ? Palette.emerald : Palette.rose))
          .animation({ duration: Motion.fast, curve: Motion.snap() })
        Text(TG2("第 {0} 题 · 连击 ×{1}", String(this.right + 1), String(this.combo)))
          .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }
      .width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Row({ space: Space.sm }) {
        ForEach(OPT_IDX, (kind: number) => {
          Text(OPS[kind])
            .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
            .fontColor(this.picked < 0 ? this.theme.ink
              : (kind === this.ansKind ? '#FFFFFF' : (kind === this.picked ? '#FFFFFF' : this.theme.inkFaint)))
            .layoutWeight(1).height(Cell.of(64)).borderRadius(Radius.md).shadow(Shadow.card)
            .backgroundColor(this.picked < 0 ? this.theme.surface
              : (kind === this.ansKind ? Palette.emerald : (kind === this.picked ? Palette.rose : this.theme.surface)))
            .scale({
              x: this.press === kind ? Motion.pressScale : 1,
              y: this.press === kind ? Motion.pressScale : 1
            })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => { this.press = e.type === TouchType.Down ? kind : -1; })
            .onClick(() => { Haptics.tick(); this.pick(kind); })
        }, (kind: number) => 'op' + kind)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      HintBar({

        onAutoTap: () => { this.askAuto(); },

        showHint: false,

        autoOn: this.autoId >= 0

      })

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary)
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：先估大小 —— 比两个数都大很多，多半是乘'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
