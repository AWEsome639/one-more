/** 倒计时数学（Countdown Math）—— 限时凑数
 *  玩法：点数字 → 点运算符 → 点数字，算出目标数。过关判据：90 秒内解出 ≥ 3 题
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2, TG4 } from '../core/GameI18n';
// ★ 2026-10-23 第二期：通用提示层
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

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

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
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
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
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


  /**
   * ★ 2026-10-23 第二期：倒计时数学提示（真求解器）
   *
   * 4 个数、每次用两个合成一个，最多 3 步 ⇒ 状态空间很小。
   * 直接 DFS 找解，但**只报第一步**：
   *   「先算 3 × 4 = 12」
   * ⇒ 因为这款是交互式的：玩家点两个数、点运算符，结果会顶替旧的数。
   *   报出完整表达式反而不好用 —— 指数会变。
   *
   * 约束与游戏本体一致：结果必须是正整数，且 ≤ 9999。
   */
  private dfsFirst(aVals: number[], aIdx: number[], target: number, first: boolean,
                   out: number[]): boolean {
    // ★ 2026-10-24 修：本游戏的胜利条件是「**任意一步的结果等于目标**」
    //   （见 tapNum 里 `if (r === this.round.target)`），
    //   不是"把 4 个数都合完"。
    //   ⇒ 第一版只认"合到只剩一个"，比游戏严格得多，
    //     会漏掉更浅的解，白报"算不出来"。
    if (aVals.length === 1) {
      return aVals[0] === target;
    }
    const signs: string[] = ['+', '-', 'x', '/'];
    for (let p = 0; p < aVals.length; p++) {
      for (let q = 0; q < aVals.length; q++) {
        if (p === q) {
          continue;
        }
        for (let si = 0; si < signs.length; si++) {
          const sg: string = signs[si];
          const r: number = combine(aVals[p], aVals[q], sg);
          if (r <= 0 || r > 9999) {
            continue;
          }
          if (first && out.length === 0) {
            out.push(aIdx[p]);
            out.push(aIdx[q]);
            out.push(si === 0 ? 0 : (si === 1 ? 1 : (si === 2 ? 2 : 3)));
            out.push(r);
          }
          if (r === target) {
            return true;                 // ★ 直接命中，不用把数用完
          }
          // ★ 2026-10-24 修：这里原来还有一段 `if (first) { out.length = 0; }`
          //   它发生在**递归之前** ⇒ 递归一旦成功，第一步已被清空
          //   ⇒ out.length < 4 ⇒ 白报"算不出来"。
          //   清空只应发生在"递归失败之后"（下面那处），不能有两处。
          const nv: number[] = [];
          const ni: number[] = [];
          for (let k = 0; k < aVals.length; k++) {
            if (k === q) {
              continue;
            }
            if (k === p) {
              nv.push(r);
              ni.push(aIdx[k]);
            } else {
              nv.push(aVals[k]);
              ni.push(aIdx[k]);
            }
          }
          if (this.dfsFirst(nv, ni, target, false, out)) {
            return true;
          }
          if (first) {
            out.length = 0;
          }
        }
      }
    }
    return false;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    const vals: number[] = [];
    const idx: number[] = [];
    for (let i = 0; i < this.round.nums.length; i++) {
      if (!this.used[i]) {
        vals.push(this.round.nums[i]);
        idx.push(i);
      }
    }
    if (vals.length < 2) {
      return Hint.none('none');
    }
    // ★ 2026-10-24 加：先找"一步命中"。
    //   DFS 返回的是任意一条路径，可能是绕远的
    //   （真机实测：2,8,1,1 目标 7，它给了 2+1=3，其实 8-1=7 一步就中）
    //   ⇒ 先扫一遍有没有一步解，有就直接报它。
    {
      const signs0: string[] = ['+', '-', 'x', '/'];
      for (let p = 0; p < vals.length; p++) {
        for (let q = 0; q < vals.length; q++) {
          if (p === q) {
            continue;
          }
          for (let si = 0; si < signs0.length; si++) {
            const r0: number = combine(vals[p], vals[q], signs0[si]);
            if (r0 <= 0 || r0 > 9999) {
              continue;
            }
            if (r0 === this.round.target) {
              const a0: number = vals[p];
              const b0: number = vals[q];
              const sg0: string = signs0[si];
              return Hint.make([],
                TG4('一步就中：{0} {1} {2} = {3}', String(a0), sg0, String(b0), String(r0)),
                TG4('One move wins: {0} {1} {2} = {3}', String(a0), sg0, String(b0), String(r0)), t0);
            }
          }
        }
      }
    }
    const out: number[] = [];
    const ok: boolean = this.dfsFirst(vals, idx, this.round.target, true, out);
    if (!ok || out.length < 4) {
      return Hint.none('none');
    }
    const signs: string[] = ['+', '-', 'x', '/'];
    const a: number = this.round.nums[out[0]];
    const b: number = this.round.nums[out[1]];
    const sg: string = signs[out[2]];
    const r: number = out[3];
    return Hint.make([],
      TG4('先算 {0} {1} {2} = {3}，再继续', String(a), sg, String(b), String(r)),
      TG4('First do {0} {1} {2} = {3}, then keep going', String(a), sg, String(b), String(r)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = Hint.run(() => this.computeHint());
    Hint.toastResult(r, TG('这一步算不出来'));
  }

  private load(): void {
    this.round = makeRound();
    this.used = new Array<boolean>(4).fill(false);
    this.sel = -1;
    this.opSign = '';
  }

  // ═══════════ AI 代打（2026-10-28 第七批）═══════════
  // 复用上面的 dfsFirst（真求解器）：取它给的第一步，照玩家路径点
  /** 下一步 [i, j, 运算符序号]；解不出返回空数组 */
  private nextMove(): number[] {
    const signs: string[] = ['+', '-', 'x', '/'];
    const vals: number[] = [];
    const idx: number[] = [];
    for (let i = 0; i < this.round.nums.length; i++) {
      if (!this.used[i]) {
        vals.push(this.round.nums[i]);
        idx.push(i);
      }
    }
    if (vals.length < 2) {
      return [];
    }
    for (let p = 0; p < vals.length; p++) {
      for (let q = 0; q < vals.length; q++) {
        if (p === q) {
          continue;
        }
        for (let si = 0; si < 4; si++) {
          const r0: number = combine(vals[p], vals[q], signs[si]);
          if (r0 > 0 && r0 <= 9999 && r0 === this.round.target) {
            return [idx[p], idx[q], si];
          }
        }
      }
    }
    const out: number[] = [];
    const ok: boolean = this.dfsFirst(vals, idx, this.round.target, true, out);
    if (!ok || out.length < 4) {
      return [];
    }
    return [out[0], out[1], out[2]];
  }

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
    const mv: number[] = this.nextMove();
    if (mv.length < 3) {
      return false;
    }
    if (this.sel !== mv[0] || this.opSign === '') {
      this.tapNum(mv[0], this.round.nums[mv[0]]);
      if (this.sel === mv[0]) {
        this.opSign = ['+', '-', 'x', '/'][mv[2]];
      }
      return true;
    }
    this.tapNum(mv[1], this.round.nums[mv[1]]);
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
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
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
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapNum((i), this.round.nums[(i)] ?? 0); }); })
          .onClick(() => { Haptics.tick(); this.tapNum((i), this.round.nums[(i)] ?? 0); })
        }, (i: number) => 'n' + i)
      }.width('100%')

      Row({ space: Space.sm }) {
        Button(('+'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.xl).fontColor(this.opSign === ('+') ? '#FFFFFF' : this.theme.ink)
        .backgroundColor(this.opSign === ('+') ? Palette.violet : this.theme.surface).borderRadius(Radius.md)
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.sel < 0) { this.tip = TG('先点一个数字'); return; } this.opSign = ('+'); this.tip = TG2('运算符 {0}，再点一个数字', ('+')); }); }).onClick(() => {
        Haptics.tap();
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
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.sel < 0) { this.tip = TG('先点一个数字'); return; } this.opSign = ('-'); this.tip = TG2('运算符 {0}，再点一个数字', ('-')); }); }).onClick(() => {
        Haptics.tap();
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
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.sel < 0) { this.tip = TG('先点一个数字'); return; } this.opSign = ('x'); this.tip = TG2('运算符 {0}，再点一个数字', ('x')); }); }).onClick(() => {
        Haptics.tap();
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
        .layoutWeight(1).height(Cell.of(52)).enabled(!this.over).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); if (this.sel < 0) { this.tip = TG('先点一个数字'); return; } this.opSign = ('/'); this.tip = TG2('运算符 {0}，再点一个数字', ('/')); }); }).onClick(() => {
        Haptics.tap();
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
        Button(TG('提示'))
          .fontSize(FontSize.sm)
          .fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .layoutWeight(1)
          .height(Cell.of(40))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { this.askHint(); }); })
          .onClick(() => {
            this.askHint();
          })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.sky).borderRadius(Radius.md)
          .width(120).height(Cell.of(44)).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
        Text(TG('除法只在整除时可用')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }






}
