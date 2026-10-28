/** 算术链（Arithmetic Chain）—— 连续运算达目标
 *  玩法：从起始数出发依次点运算符，≤ 4 步落到目标数。过关判据：5 关过 4 关
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
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
  /** 代打计时器（-1 = 未运行）。必须 @State，按钮文字才会变 */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
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
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GArithmeticChain')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(LEVELS);
     this.reset(); }


  /**
   * ★ 2026-10-23 第二期：算术链提示（真求解器）
   *
   * 4 个运算、最多 4 步 ⇒ 状态空间最多 4⁴ = 256 条路径，
   * 直接 DFS 找一条从当前值走到目标值的路径。
   * ⇒ 提示给出**完整的一串运算**，玩家照着点就能到。
   *
   * 上限：depth ≤ MAXSTEP - this.steps，节点数 ≤ 256，远远低于 500ms 预算。
   */
  private solvePath(v: number, depth: number, acc: Op[]): Op[] | null {
    if (v === this.stage.target) {
      return acc.slice();
    }
    if (depth <= 0) {
      return null;
    }
    for (let i = 0; i < this.stage.palette.length; i++) {
      const o: Op = this.stage.palette[i];
      const nv: number = apply(v, o);
      if (nv < 0 || nv > 999) {
        continue;                   // 越界不探索，避免无意义路径
      }
      acc.push(o);
      const r: Op[] | null = this.solvePath(nv, depth - 1, acc);
      acc.pop();
      if (r !== null) {
        return r;
      }
    }
    return null;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const left: number = MAXSTEP - this.steps;
    if (left <= 0) {
      return Hint.none('none');
    }
    const path: Op[] | null = this.solvePath(this.value, left, []);
    if (path === null || path.length === 0) {
      return Hint.none('none');
    }
    let zh: string = '';
    let en: string = '';
    for (let i = 0; i < path.length; i++) {
      if (i > 0) {
        zh += '，然后 ';
        en += ', then ';
      }
      zh += path[i].label;
      en += path[i].label;
    }
    return Hint.make([],
      TG2('{0} 步就能到：{1}', String(path.length), zh),
      TG2('{0} step(s) to the goal: {1}', String(path.length), en), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

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

  /**
   * ★★ 2026-10-24 第二期：AI 代打（一次走一步）
   */
  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
  private demoFinish(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Hint.autoStop(this.demoId);
      this.demoId = -1;
    }
    this.demoLeft = 0;
  }

  private demoStep(): boolean {
    if (this.demoId < 0) { return false; }
    if (this.demoLeft <= 0) { this.demoFinish(); return false; }
    this.demoLeft = this.demoLeft - 1;
    this.autoStep();
    return true;
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
    const left: number = MAXSTEP - this.steps;
    if (left <= 0) {
      return false;
    }
    const path: Op[] | null = this.solvePath(this.value, left, []);
    if (path === null || path.length === 0) {
      return false;
    }
    // 找到第一步在 palette 里的下标
    const first: Op = path[0];
    let k: number = -1;
    for (let i = 0; i < this.stage.palette.length; i++) {
      const o: Op = this.stage.palette[i];
      if (o.kind === first.kind && o.value === first.value) {
        k = i;
        break;
      }
    }
    if (k < 0) {
      return false;
    }
    this.tap(k);
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
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .width('100%')
          .height(Cell.of(42))
          .onClick(() => {
            this.askHint();
          })
        Button(this.autoId >= 0 ? TG('停代打') : TG('AI 代打'))
          .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md)
          .fontColor('#FFFFFF')
          .backgroundColor(Palette.cyan)
          .borderRadius(Radius.md)
          .width(96)
          .height(Cell.of(44))
          .onClick(() => {
            this.askAuto();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF')
          .backgroundColor(Palette.rose).borderRadius(Radius.md).width(120).height(Cell.of(44)).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG2("步数 {0}/{1}",Digits(String(this.steps), this.langCode),Digits(String(MAXSTEP), this.langCode))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
