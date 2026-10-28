/**
 * 爱因斯坦谜题 ❓ —— 三栋排屋、三种宠物，谜面给若干线索，推出唯一答案
 * 玩法：点格子循环切宠物（🐱🐟🐦，不能重复），三项都填对即通关
 * 线索每局随机生成（都真实成立），并用穷举求解器保证"有且只有一个解"
 * 胜负：解开 1 题即通关（看提示扣 100 分）　进度：步数 / 线索条数
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 3;
const NATION: string[] = ['🇬🇧', '🇸🇪', '🇩🇰'];
const PETS: string[] = ['🐱', '🐟', '🐦'];
const PETNAME: string = TG(TG(TG('🐱猫  🐟鱼  🐦鸟')));

interface Clue {
  kind: number;   // 0 = 某国养某宠　1 = A 住 B 左边　2 = A 紧挨着 B
  a: number;
  b: number;
}

function ok(p: number[], clues: Clue[]): boolean {
  for (let i = 0; i < clues.length; i++) {
    const c: Clue = clues[i];
    if (c.kind === 0 && p[c.a] !== c.b) { return false; }
    if (c.kind === 1 && p.indexOf(c.a) >= p.indexOf(c.b)) { return false; }
    if (c.kind === 2 && Math.abs(p.indexOf(c.a) - p.indexOf(c.b)) !== 1) { return false; }
  }
  return true;
}

/** 枚举 6 种排法，数出满足全部线索的个数 */
function countSol(clues: Clue[]): number {
  let n: number = 0;
  for (let a = 0; a < N; a++) {
    for (let b = 0; b < N; b++) {
      for (let c = 0; c < N; c++) {
        if (a === b || a === c || b === c) { continue; }
        if (ok([a, b, c], clues)) { n++; }
      }
    }
  }
  return n;
}

function text(c: Clue): string {
  if (c.kind === 0) { return NATION[c.a] + TG2(' 家养 {0}', PETS[c.b]); }
  if (c.kind === 1) { return NATION[c.a] + TG2(' 家的宠物住在 {0} 家左边', NATION[c.b]); }
  return NATION[c.a] + TG2(' 家的宠物紧挨着 {0} 家住', NATION[c.b]);
}

/** 生成一局：随机答案 → 从真实线索里随机抽几条 → 只有唯一解才采用 */
function generate(wantClues: number): Clue[] {
  for (let guard = 0; guard < 800; guard++) {
    const sol: number[] = [0, 1, 2];
    for (let i = sol.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = sol[i]; sol[i] = sol[j]; sol[j] = t;
    }
    const pool: Clue[] = [];
    for (let a = 0; a < N; a++) { pool.push({ kind: 0, a: a, b: sol[a] }); }
    for (let a = 0; a < N; a++) {
      for (let b = 0; b < N; b++) {
        if (a === b) { continue; }
        if (sol[a] < sol[b]) { pool.push({ kind: 1, a: a, b: b }); }
        if (Math.abs(sol[a] - sol[b]) === 1) { pool.push({ kind: 2, a: a, b: b }); }
      }
    }
    const picked: Clue[] = [];
    const used: number[] = [];
    const want: number = wantClues;
    while (picked.length < want && used.length < pool.length) {
      const i: number = Math.floor(Math.random() * pool.length);
      if (used.indexOf(i) >= 0) { continue; }
      used.push(i); picked.push(pool[i]);
    }
    if (picked.length >= 2 && countSol(picked) === 1) { return picked; }
  }
  return [{ kind: 0, a: 0, b: 0 }, { kind: 0, a: 1, b: 1 }, { kind: 0, a: 2, b: 2 }];
}

@Component
export struct GEinsteinRiddle {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=3；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2]，上面已一并改成按尺寸生成
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」：
   *   原来这里是 `GameDiff.sizeNow(3)`，格子数随难度变（2/3/4），
   *   但**整个谜题写死 3 家**（NATION/PETS/generate/countSol 全是 3）：
   *     · 简单档 2 格：sol 有 3 项，`found.length === diffTotal` 永远 false
   *     · 困难档 4 格：只有 3 只宠物，第 4 格永远填不上
   *   ⇒ 游戏在简单档和困难档都是坏的。
   *
   *   修法：**爱因斯坦谜题本质就是 3 家题**，改 2/4 家要另写线索集。
   *   所以格子固定 3，难度改到**线索条数**上（线索越少越难）——
   *   这才是这款游戏真正的难度轴。
   */
  @State private houses: number = 3;
  /** 本局给多少条线索：简单 5 / 普通 4 / 困难 3 */
  @State private clueCount: number = GEinsteinRiddle.clueCountNow();

  private static clueCountNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 5;
    }
    if (d === 2) {
      return 3;
    }
    return 4;
  }

  /** 0..houses-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.houses > 1 ? this.houses : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};

  @State private lines: string[] = [];
  @State private sol: number[] = [];
  @State private grid: number[] = new Array<number>(this.houses).fill(-1);
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private tries: number = 0;
  @State private hintOn: boolean = false;
  @State private note: string = '';
  @State private over: boolean = false;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GEinsteinRiddle')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.clueCount = GEinsteinRiddle.clueCountNow();
     this.reset(); }

  private reset(): void {
    const clues: Clue[] = generate(this.clueCount);
    const lines: string[] = [];
    const sol: number[] = new Array<number>(this.houses).fill(-1);
    for (let i = 0; i < clues.length; i++) {
      lines.push(text(clues[i]));
      if (clues[i].kind === 0) { sol[clues[i].a] = clues[i].b; }
    }
    // 线索里未必直接给全 —— 补一次穷举，把唯一解算出来
    const found: number[] = this.solveUnique(clues);
    this.lines = lines;
    this.sol = found.length === this.houses ? found : sol;
    this.grid = new Array<number>(this.houses).fill(-1);
    this.tries = 0; this.hintOn = false; this.over = false;
    this.note = TG(TG(TG('点格子切换宠物，三项不能重复')));
    this.startAt = Date.now();
  }

  /** 找到唯一解（generate 已保证只有一个） */
  private solveUnique(clues: Clue[]): number[] {
    for (let a = 0; a < this.houses; a++) {
      for (let b = 0; b < this.houses; b++) {
        for (let c = 0; c < this.houses; c++) {
          if (a === b || a === c || b === c) { continue; }
          const p: number[] = [a, b, c];
          if (ok(p, clues)) { return p; }
        }
      }
    }
    return [];
  }

  /** 提示：和代打同一个循环，只把"点"换成"说" */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    for (let i = 0; i < this.houses; i++) {
      if (this.grid[i] !== this.sol[i]) {
        return Hint.make([i],
          TG2('点第 {0} 个', String(i + 1)),
          TG2('Tap number {0}', String(i + 1)), t0);
      }
    }
    return Hint.none('none');
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 这款已经把完整解存在 this.sol 里 ⇒ 一格一格拨到位即可。
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
    for (let i = 0; i < this.houses; i++) {
      if (this.grid[i] !== this.sol[i]) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
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

  private tap(i: number): void {
    if (this.over) { return; }
    const next: number[] = this.grid.slice();
    next[i] = (next[i] + 1) % this.houses;
    this.grid = next; this.tries++;
    for (let k = 0; k < this.houses; k++) {
      if (next[k] < 0) { return; }
    }
    let dup: boolean = false;
    for (let a = 0; a < this.houses; a++) {
      for (let b = a + 1; b < this.houses; b++) {
        if (next[a] === next[b]) { dup = true; }
      }
    }
    if (dup) { this.note = TG(TG(TG('每种宠物只能用一次 ⚠️'))); return; }
    if (next.join(',') === this.sol.join(',')) {
      this.over = true; this.note = TG(TG(TG('解开了 🎉')));
      LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
      this.onFinish({
        gameId: 'einstein_riddle', solved: true,
        score: Math.max(40, 300 - this.tries * 8 - (this.hintOn ? 100 : 0)),
        durationMs: Date.now() - this.startAt, levelReached: 1
      });
    } else {
      this.note = TG(TG(TG('和线索冲突 ❌ 再核对一下')));
    }
  }

  @Builder
  slot(i: number) {
    Stack() {
      Text(this.grid[i] < 0 ? '?' : PETS[this.grid[i]])
        .fontSize(this.grid[i] < 0 ? FontSize.xl : FontSize.xxl)
        .fontColor(this.grid[i] < 0 ? this.theme.inkFaint : '#FFFFFF')
    }
    .layoutWeight(1).height(Cell.of(56))
    .backgroundColor(this.grid[i] < 0 ? this.theme.surfaceAlt : Palette.orange)
    .borderRadius(Radius.md)
    .shadow(Shadow.card)
    .animation({ duration: Motion.fast, curve: Motion.snap() })
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap(i); }); })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Text(TG2("步数 {0}",Digits(String(this.tries), this.langCode))).fontSize(FontSize.md).fontColor(this.theme.ink).layoutWeight(1)
        Text(TG2('线索 {0} 条', this.lines.length)).fontSize(FontSize.md).fontColor(Palette.sky).layoutWeight(1)
        Text(this.over ? '已解开 🎉' : '唯一解').fontSize(FontSize.md).fontColor(Palette.emerald).layoutWeight(1)
      }.width('100%')

      Text(TG('❓ 三栋排屋住着三个国籍的人，各养一种宠物 —— 按线索推出唯一的排法'))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')

      Column({ space: Space.xs }) {
        ForEach(this.lines, (c: string, i: number) => {
          Text((i + 1) + '. ' + c).fontSize(FontSize.sm).fontColor(this.theme.ink).width('100%')
        }, (c: string, i: number) => 'cl' + i)
      }.width('100%')
      .padding(Space.sm)
      .backgroundColor(this.theme.surface)
      .borderRadius(Radius.md)
      .shadow(Shadow.card)

      Row({ space: Space.xs }) {
        ForEach(this.rowIdx(), (i: number) => {
          this.slot(i)
        }, (i: number) => 'sl' + i)
      }.width('100%')

      Row({ space: Space.xs }) {
        ForEach(this.rowIdx(), (i: number) => {
          Text(NATION[i]).fontSize(FontSize.md).textAlign(TextAlign.Center)
            .layoutWeight(1).height(28).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.xs)
        }, (i: number) => 'na' + i)
      }.width('100%')

      Text(this.hintOn ? '宠物代号 🔑 ' + PETNAME : this.note)
        .fontSize(FontSize.xs).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)

      Row({ space: Space.sm }) {
        Button(this.hintOn ? '已看提示' : '提示 −100')
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44))
          .fontSize(FontSize.sm).fontColor(this.theme.ink).backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.hintOn = true; }); })
          .onClick(() => { Haptics.tap(); this.hintOn = true; })
        Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).layoutWeight(1).height(Cell.of(44))
          .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
          .borderRadius(Radius.md)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => { Haptics.tap(); this.reset(); })
      }.width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }
}
