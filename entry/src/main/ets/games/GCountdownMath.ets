/** 倒计时数学（Countdown Math）—— 限时凑数
 *  玩法：点数字 → 点运算符 → 点数字，算出目标数。过关判据：90 秒内解出 ≥ 3 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LIMIT: number = 90;
const NEED: number = 3;

interface Round { nums: number[]; target: number }

function combine(a: number, b: number, sign: string): number {
  if (sign === '+') { return a + b; }
  if (sign === '-') { return a - b; }
  if (sign === 'x') { return a * b; }
  if (b === 0 || a % b !== 0) { return -99999; }
  return a / b;
}

function makeRound(): Round {
  const signs: string[] = ['+', '-', 'x', '/'];
  for (let attempt = 0; attempt < 60; attempt++) {
    const nums: number[] = [];
    for (let k = 0; k < 4; k++) { nums.push(1 + Math.floor(Math.random() * 10)); }
    const i: number = Math.floor(Math.random() * 4);
    let j: number = Math.floor(Math.random() * 4);
    let m: number = Math.floor(Math.random() * 4);
    if (j === i) { j = (j + 1) % 4; }
    if (m === i || m === j) { m = (m + 1) % 4; if (m === i || m === j) { m = (m + 1) % 4; } }
    const s1: string = signs[Math.floor(Math.random() * 4)];
    const s2: string = signs[Math.floor(Math.random() * 4)];
    const r1: number = combine(nums[i], nums[j], s1);
    if (r1 <= 0 || r1 > 400) { continue; }
    const goal: number = combine(r1, nums[m], s2);
    if (goal <= 0 || goal > 300) { continue; }
    let clash: boolean = false;
    for (let k = 0; k < 4; k++) { if (nums[k] === goal) { clash = true; } }
    if (!clash) { return { nums: nums, target: goal }; }
  }
  return { nums: [2, 3, 4, 5], target: 14 };
}

@Component
export struct GCountdownMath {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  @State private round: Round = { nums: [], target: 0 };
  @State private used: boolean[] = [];
  @State private sel: number = -1;
  @State private opSign: string = '';
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private clears: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  @State private over: boolean = false;
  @State private tip: string = TG('点数字 → 点运算符 → 点数字');

  private startAt: number = 0;
  private tick: number = -1;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    this.tick = setInterval(() => {
      if (this.over) { return; }
      this.left--;
      if (this.left <= 0) {
        this.left = 0;
        this.over = true;
        this.tip = TG2('时间到｜共解出 {0} 题', this.clears);
        this.finish(this.clears >= NEED);
      }
    }, 1000);
  }

  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }

  aboutToDisappear(): void {
    if (this.tick >= 0) { clearInterval(this.tick); this.tick = -1; }
  }

  private reset(): void {
    this.startAt = Date.now();
    this.left = this.total;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.tip = TG('点数字 → 点运算符 → 点数字');
    this.load();
  }

  private load(): void {
    this.round = makeRound();
    this.used = new Array<boolean>(4).fill(false);
    this.sel = -1;
    this.opSign = '';
  }

  private tapNum(i: number, real: number): void {
    if (this.over || this.used[i]) { return; }
    if (this.sel < 0) {
      this.sel = i;
      this.tip = TG2('选 {0}，再点运算符', String(real));
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      this.opSign = '';
      this.tip = TG('已取消选择');
      return;
    }
    if (this.opSign === '') {
      this.sel = i;
      this.tip = TG2('选 {0}，再点运算符', String(real));
      return;
    }
    const a: number = this.round.nums[this.sel];
    const r: number = combine(a, real, this.opSign);
    if (r === -99999) {
      this.tip = TG('除不尽，换一步试试');
      return;
    }
    if (r <= 0 || r > 9999) {
      this.tip = TG('结果要保持正整数');
      return;
    }
    const nums: number[] = this.round.nums.slice();
    const flags: boolean[] = this.used.slice();
    nums[this.sel] = r;
    flags[i] = true;
    const nextRound: Round = { nums: nums, target: this.round.target };
    this.round = nextRound;
    this.used = flags;
    this.sel = -1;
    this.opSign = '';
    if (r === this.round.target) {
      this.clears++;
      this.score += 10; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.load();
      this.tip = TG('✓ 命中目标，继续下一题');
    } else {
      this.tip = TG2('现在得到 {0}', r);
    }
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'countdown_math', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.clears
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已解'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.clears) + '/' + String(NEED))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.xs }) {
        Text(TG('🎯 目标')).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(String(this.round.target)).fontSize(FontSize.hero).fontWeight(FontWeight.Bold).fontColor(Palette.rose)
      }.width('100%').padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.lg).shadow(Shadow.card)

      Row({ space: Space.sm }) {
        ForEach([0, 1, 2, 3], (i: number) => {
          Stack() {
          Text(this.used[(i)] ? '·' : String(this.round.nums[(i)] ?? 0)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold)
          .fontColor(this.used[(i)] ? this.theme.inkFaint : (this.sel === (i) ? '#FFFFFF' : this.theme.ink))
          }.layoutWeight(1).aspectRatio(1).backgroundColor(this.sel === (i) ? Palette.sky : this.theme.surfaceAlt)
          .borderRadius(Radius.md).animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => { this.tapNum((i), this.round.nums[(i)] ?? 0); })
        }, (i: number) => 'n' + i)
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(('+'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.opSign === ('+') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.opSign === ('+') ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => {
        if (this.sel < 0) {
        this.tip = TG('先点一个数字');
        return;
        }
        this.opSign = ('+');
        this.tip = TG2('运算符 {0}，再点一个数字', ('+'));
        })
        Button(('-'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.opSign === ('-') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.opSign === ('-') ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => {
        if (this.sel < 0) {
        this.tip = TG('先点一个数字');
        return;
        }
        this.opSign = ('-');
        this.tip = TG2('运算符 {0}，再点一个数字', ('-'));
        })
        Button(('x'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.opSign === ('x') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.opSign === ('x') ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => {
        if (this.sel < 0) {
        this.tip = TG('先点一个数字');
        return;
        }
        this.opSign = ('x');
        this.tip = TG2('运算符 {0}，再点一个数字', ('x'));
        })
        Button(('/'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.opSign === ('/') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.opSign === ('/') ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).onClick(() => {
        if (this.sel < 0) {
        this.tip = TG('先点一个数字');
        return;
        }
        this.opSign = ('/');
        this.tip = TG2('运算符 {0}，再点一个数字', ('/'));
        })
      }.width('100%')

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkSoft).height(20)

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.sky).borderRadius(Radius.md)
          .width(120).height(Cell.of(44)).onClick(() => { this.reset(); })
        Text(TG('除法只在整除时可用')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
