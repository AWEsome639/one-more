/**
 * 万年历 —— 推算日期星期
 * 玩法：给出任意日期（1995–2035），从七个星期里选出它真实是星期几。
 * 胜负：90 秒内答对 6 题 ⇒ 通关；时间归零 ⇒ 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const GOAL: number = 6; const LIMIT: number = 90; const TICK_MS: number = 1000;
const PENALTY: number = 4; const NEXT_MS: number = 480;
const WEEK: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const W1: number[] = [0, 1, 2, 3];
const W2: number[] = [4, 5, 6];
const MONTH_DAYS: number[] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

function daysIn(mon: number, yr: number): number {
  if (mon === 2) {
    const leap: boolean = (yr % 4 === 0 && yr % 100 !== 0) || yr % 400 === 0;
    return leap ? 29 : 28;
  }
  return MONTH_DAYS[mon - 1];
}

/** Zeller 同余 → 0=周一 … 6=周日 */
function weekdayOf(yr: number, mon: number, day: number): number {
  let y: number = yr;
  let m: number = mon;
  if (m < 3) { m = m + 12; y = y - 1; }
  const k: number = y % 100;
  const j: number = Math.floor(y / 100);
  const h: number = (day + Math.floor(13 * (m + 1) / 5) + k + Math.floor(k / 4) + Math.floor(j / 4) + 5 * j) % 7;
  return (h + 5) % 7;
}

@Component
export struct GMentalCalendar {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private yr: number = 2000;
  @State private mon: number = 1;
  @State private day: number = 1;
  @State private ansW: number = 0;
  @State private pickedW: number = -1;
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
    this.msg = TG('先记住当年 1 月 1 日是星期几，再往后数天数');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); }
  }

  private ask(): void {
    const yr: number = ri(1995, 2035);
    const mon: number = ri(1, 12);
    const day: number = ri(1, daysIn(mon, yr));
    this.yr = yr; this.mon = mon; this.day = day;
    this.ansW = weekdayOf(yr, mon, day);
    this.pickedW = -1;
  }

  private pick(w: number): void {
    if (this.pickedW >= 0 || this.over) { return; }
    this.pickedW = w;
    const slot: string = String(this.yr) + TG2(' 年 {0} 月 {1} 日', String(this.mon), String(this.day));
    if (w === this.ansW) {
      this.right = this.right + 1; this.combo = this.combo + 1;
      this.score = this.score + 80 + this.combo * 15; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.msg = TG2('✅ 答对！{0}确实是{1}', slot, TG(WEEK[this.ansW]));
    } else {
      this.combo = 0; this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 错了，扣 {0} 秒 —— 正确答案是{1}",Digits(String(PENALTY), this.langCode), TG(WEEK[this.ansW]));
    }
    if (this.nextTo >= 0) { clearTimeout(this.nextTo); }
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.advance(); }, NEXT_MS);
  }

  private advance(): void {
    if (this.over) { return; }
    if (this.right >= GOAL) { this.end(true, TG('🎉 答对 ') + String(GOAL) + ' 个日期，通关！剩 ' + String(this.left) + TG(' 秒')); return; }
    if (this.left <= 0) { this.end(false, TG('⏰ 时间到，答对 ') + String(this.right) + TG(' 题')); return; }
    this.ask();
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'mental_calendar', solved: solved, score: this.score,
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

      Column({ space: Space.xs }) {
        Text(TG('📅 这一天是星期几？')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(String(this.yr) + TG2(' 年 {0} 月 {1} 日', String(this.mon), String(this.day)))
          .fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor(Palette.primaryDeep)
      }
      .width('100%').padding(Space.lg).backgroundColor(this.theme.surface)
      .borderRadius(Radius.lg).shadow(Shadow.card)

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          ForEach(W1, (w: number) => { Text(TG(WEEK[(w)]))
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.pickedW < 0 ? this.theme.ink
          : ((w) === this.ansW ? '#FFFFFF' : ((w) === this.pickedW ? '#FFFFFF' : this.theme.inkFaint)))
          .layoutWeight(1).height(Cell.of(52)).borderRadius(Radius.md).shadow(Shadow.card)
          .backgroundColor(this.pickedW < 0 ? this.theme.surface
          : ((w) === this.ansW ? Palette.emerald : ((w) === this.pickedW ? Palette.rose : this.theme.surface)))
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { this.pick((w)); }) }, (w: number) => 'cw1' + w)
        }.width('100%')
        Row({ space: Space.sm }) {
          ForEach(W2, (w: number) => { Text(TG(WEEK[(w)]))
          .fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.pickedW < 0 ? this.theme.ink
          : ((w) === this.ansW ? '#FFFFFF' : ((w) === this.pickedW ? '#FFFFFF' : this.theme.inkFaint)))
          .layoutWeight(1).height(Cell.of(52)).borderRadius(Radius.md).shadow(Shadow.card)
          .backgroundColor(this.pickedW < 0 ? this.theme.surface
          : ((w) === this.ansW ? Palette.emerald : ((w) === this.pickedW ? Palette.rose : this.theme.surface)))
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { this.pick((w)); }) }, (w: number) => 'cw2' + w)
        }.width('100%')
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primaryDeep)
        .onClick(() => { this.reset(); })

      Text(TG('提示：一三五七八十腊，三十一天永不差；闰年二月二十九天'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
