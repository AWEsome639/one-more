/** 算术链（Arithmetic Chain）—— 连续运算达目标
 *  玩法：从起始数出发依次点运算符，≤ 4 步落到目标数。过关判据：5 关过 4 关
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const LEVELS: number = 5;
const PASS: number = 4;
const MAXSTEP: number = 4;

interface Op { kind: number; value: number; label: string }
interface Stage { start: number; target: number; palette: Op[] }

function opPool(): Op[] {
  const base: Op[] = [
    { kind: 0, value: 1, label: '+1' }, { kind: 0, value: 2, label: '+2' },
    { kind: 0, value: 3, label: '+3' }, { kind: 0, value: 4, label: '+4' },
    { kind: 1, value: 1, label: '-1' }, { kind: 1, value: 2, label: '-2' },
    { kind: 1, value: 3, label: '-3' }, { kind: 2, value: 2, label: '×2' },
    { kind: 2, value: 3, label: '×3' }
  ];
  for (let i = base.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const t: Op = base[i];
    base[i] = base[j];
    base[j] = t;
  }
  return [base[0], base[1], base[2], base[3]];
}

function apply(v: number, o: Op): number {
  if (o.kind === 0) { return v + o.value; }
  if (o.kind === 1) { return v - o.value; }
  return v * o.value;
}

function makeStage(): Stage {
  const pal: Op[] = opPool();
  const start: number = 2 + Math.floor(Math.random() * 9);
  for (let attempt = 0; attempt < 40; attempt++) {
    let v: number = start;
    let bad: boolean = false;
    for (let s = 0; s < 3; s++) {
      v = apply(v, pal[Math.floor(Math.random() * pal.length)]);
      if (v < 1 || v > 400) { bad = true; break; }
    }
    if (!bad && v !== start) { return { start: start, target: v, palette: pal }; }
  }
  return { start: 3, target: 24, palette: pal };
}

@Component
export struct GArithmeticChain {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：LEVELS 按难度换算（简单/普通/困难）
  @State private diffTotal: number = GameDiff.sizeNow(LEVELS);
  onFinish: (r: GameResult) => void = () => {};

  @State private stage: Stage = { start: 3, target: 24, palette: [] };
  @State private value: number = 3;
  @State private steps: number = 0;
  @State private level: number = 0;
  @State private clears: number = 0;
  @State private score: number = 0;
  @State private over: boolean = false;
  @State private tip: string = TG(TG(TG('点运算符，凑到目标数')));
  @State private chain: string[] = [];

  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }

  private reset(): void {
    this.startAt = Date.now();
    this.level = 0;
    this.clears = 0;
    this.score = 0;
    this.over = false;
    this.tip = TG(TG(TG('点运算符，凑到目标数')));
    this.load(0);
  }

  private load(lv: number): void {
    this.stage = makeStage();
    this.value = this.stage.start;
    this.steps = 0;
    this.chain = [];
  }

  private tap(k: number): void {
    if (this.over || k >= this.stage.palette.length) { return; }
    const o: Op = this.stage.palette[k];
    const v: number = apply(this.value, o);
    if (v < -999 || v > 999) {
      this.tip = TG(TG(TG('数值太大，换一步试试')));
      return;
    }
    this.value = v;
    this.steps++;
    const step: string[] = this.chain.slice();
    step.push(o.label);
    this.chain = step;
    if (v === this.stage.target) {
      this.clears++;
      this.score += 10;
      this.next(TG2('✓ 第 {0} 关达成', String(this.level + 1)));
      return;
    }
    if (this.steps >= MAXSTEP) {
      this.next(TG2('✗ 第 {0} 关步数用尽', String(this.level + 1)));
      return;
    }
    if (v > this.stage.target) {
      this.tip = TG2('现在 {0}，比目标大了', String(v));
    } else {
      this.tip = TG2('现在 {0}，还差 {1}', String(v), String(this.stage.target - v));
    }
  }

  private next(msg: string): void {
    this.level++;
    if (this.level >= this.diffTotal) {
      this.over = true;
      this.tip = msg + '｜共过 ' + String(this.clears) + '/' + String(this.diffTotal) + TG(' 关');
      this.finish(this.clears >= PASS);
      return;
    }
    this.load(this.level);
    this.tip = msg + '，继续第 ' + String(this.level + 1) + TG(' 关');
  }

  private finish(solved: boolean): void {
    const res: GameResult = {
      gameId: 'arithmetic_chain', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.clears
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(res);
  }

  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('关卡'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(Math.min(this.level + 1, this.diffTotal)) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG(TG('已过')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.clears), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG(TG('起点')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.stage.start))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor((this.theme.surface))
        }.layoutWeight(1).padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        Column({ space: 2 }) {
        Text((TG(TG('现在')))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.value), this.langCode)).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor((Palette.rose))
        }.layoutWeight(1).padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.stage.target))).fontSize(FontSize.xxl).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.md).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        .animation({ duration: Motion.fast, curve: Motion.snap() })
      }.width('100%')

      Text(this.chain.length > 0 ? this.chain.join('  →  ') : '还没有任何运算')
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Text(this.tip).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)

      Column({ space: Space.sm }) {
        Row({ space: Space.sm }) {
          Button((0) < this.stage.palette.length ? this.stage.palette[(0)].label : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl)
          .fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(56)).enabled(!this.over && (0) < this.stage.palette.length).onClick(() => { Haptics.tap(); this.tap((0)); })
          Button((1) < this.stage.palette.length ? this.stage.palette[(1)].label : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl)
          .fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(56)).enabled(!this.over && (1) < this.stage.palette.length).onClick(() => { Haptics.tap(); this.tap((1)); })
        }.width('100%')
        Row({ space: Space.sm }) {
          Button((2) < this.stage.palette.length ? this.stage.palette[(2)].label : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl)
          .fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(56)).enabled(!this.over && (2) < this.stage.palette.length).onClick(() => { Haptics.tap(); this.tap((2)); })
          Button((3) < this.stage.palette.length ? this.stage.palette[(3)].label : '—')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl)
          .fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(56)).enabled(!this.over && (3) < this.stage.palette.length).onClick(() => { Haptics.tap(); this.tap((3)); })
        }.width('100%')
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.rose).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG2("步数 {0}/{1}",Digits(String(this.steps), this.langCode),Digits(String(MAXSTEP), this.langCode))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
