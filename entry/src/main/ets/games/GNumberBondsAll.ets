/**
 * 数字拆分 —— 拆数练习
 *
 * 玩法：目标数 n，棋盘上每个 1..n 各出现两次；每次点两块，点中两块之和 = n
 *       即拆出一组（两块随即作废），把所有拆法找齐。
 * 胜负：拆齐 ⌊n/2⌋ 组 ⇒ 通关；点错 3 次 ⇒ 失败。
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const COLS: number = 4;
const LIVES: number = 3;

function randInt(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GNumberBondsAll {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：LIVES 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(LIVES);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private tiles: number[] = [];
  @State private used: boolean[] = [];
  @State private target: number = 0;
  @State private sel: number = -1;
  @State private found: string[] = [];
  @State private err: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private rows: number[] = [];
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';

  private startAt: number = 0;
  private finished: boolean = false;
  private cols: number[] = [0, 1, 2, 3];

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.startAt = Date.now();
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GNumberBondsAll')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(LIVES);
    this.reset();
  }

  private reset(): void {
    const t: number = randInt(6, 12);
    const bag: number[] = [];
    for (let i = 1; i <= t; i++) {
      bag.push(i);
      bag.push(i);
    }
    for (let i = bag.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const tmp: number = bag[i];
      bag[i] = bag[j];
      bag[j] = tmp;
    }
    this.target = t;
    this.tiles = bag;
    this.used = new Array<boolean>(bag.length).fill(false);
    this.sel = -1;
    this.found = [];
    this.err = 0;
    const r: number[] = [];
    for (let i = 0; i < Math.ceil(bag.length / COLS); i++) {
      r.push(i);
    }
    this.rows = r;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.startAt = Date.now();
    this.msg = TG2('点两块，凑出 {0}（每个数各两块，用完就不能再点）', t);
  }

  private total(): number {
    return Math.floor(this.target / 2);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案 = 两块数之和等于 this.target；一套一套配，配对了就消
  /** 返回 i * 100 + j（一对能凑出 target 的未用格），-1 = 没有了 */
  private aiFindPair(): number {
    for (let i = 0; i < this.tiles.length; i++) {
      if (this.used[i]) {
        continue;
      }
      for (let j = i + 1; j < this.tiles.length; j++) {
        if (this.used[j]) {
          continue;
        }
        if (this.tiles[i] + this.tiles[j] === this.target) {
          return i * 100 + j;
        }
      }
    }
    return -1;
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // 沙盒规则：跑 Hint.DEMO_STEPS 步或一旦 over 就立刻停，然后 reset()
  //   ⇒ 演完就是干净开局，成绩/记录不可能被污染
  // ═══════════ 演示动画 · 三拍（2026-11-01 批量铺）
  // ★ 为什么改：旧版是 `demoStep()` 里一个 tick 直接 `autoStep()`，
  //   匀速连发 ⇒ 玩家看到的是"格子自己在变"，不知道在演什么。
  //   新版分三拍：引导(720ms) → 执行(280ms) → 结果(1150ms)，3 轮 ≈ 6.5 秒。
  // ★ 不计分：演示前快照，结束或一碰屏幕时原样恢复。
  private demoBeat(): number {
    if (this.demoId < 0) { return -1; }

    if (this.demoPhase === 0) {
      if (this.demoRound >= 3) { this.demoFinish(); return -1; }
      this.demoMsg = TG2('看清楚：这是第 {0} 步', String(this.demoRound + 1));
      Haptics.tick();
      this.demoPhase = 1;
      return Demo.GUIDE_MS;
    }

    if (this.demoPhase === 1) {
      const more: boolean = this.autoStep();
      if (!more) { this.demoFinish(); return -1; }
      Haptics.tap();
      this.demoPhase = 2;
      return Demo.ACT_MS;
    }

    this.demoRound = this.demoRound + 1;
    this.demoMsg = this.demoRound >= 3
      ? TG('就是这样玩。碰一下屏幕，换你来')
      : TG('看到了吗？再看一遍');
    this.demoPhase = 0;
    if (this.demoRound >= 3) { this.demoFinish(); }
    return Demo.RESULT_MS;
  }

  private demoFinish(): void {
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = '';
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    const wasOn: boolean = this.demoPhase > 0 || this.demoRound > 0;
    this.demoFinish();
    if (wasOn) { this.reset(); }
  }

  private demoStart(): void {
    if (this.demoId >= 0) { return; }
    this.demoPhase = 0;
    this.demoRound = 0;
    this.demoMsg = TG('看清楚：接下来演示给你看');
    this.demoId = Demo.run((_p: number) => this.demoBeat());
  }

  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    this.sel = -1;
    const m: number = this.aiFindPair();
    if (m < 0) {
      return false;
    }
    this.tap(Math.floor(m / 100));
    this.tap(m % 100);
    return !this.over;
  }

  /** 提示：报哪两个数能凑成目标数 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const m: number = this.aiFindPair();
    if (m < 0) {
      return Hint.none('none');
    }
    const a: number = Math.floor(m / 100);
    const b: number = m % 100;
    return Hint.make([a, b], TG2('{0} + {1} = {2}', this.tiles[a], this.tiles[b], this.target),
      TG2('{0} + {1} = {2}', this.tiles[a], this.tiles[b], this.target), t0);
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

  private tap(i: number): void {
    if (this.over || this.used[i]) {
      return;
    }
    if (this.sel < 0) {
      this.sel = i;
      this.msg = TG2("选中 {0}，再点一块凑 {1}", this.tiles[i], this.target);
      return;
    }
    if (this.sel === i) {
      this.sel = -1;
      this.msg = TG('取消选择');
      return;
    }
    const a: number = this.tiles[this.sel];
    const b: number = this.tiles[i];
    if (a + b === this.target) {
      const nextUsed: boolean[] = this.used.slice();
      nextUsed[this.sel] = true;
      nextUsed[i] = true;
      this.used = nextUsed;
      const lo: number = a < b ? a : b;
      const hi: number = a < b ? b : a;
      const list: string[] = this.found.slice();
      list.push(lo + '+' + hi);
      this.found = list;
      this.sel = -1;
      this.msg = '✅ ' + lo + ' + ' + hi + ' = ' + this.target;
      if (this.found.length >= this.total()) {
        this.msg = TG2('🎉 {0} 的 {1} 种拆法全找齐！', this.target, this.total());
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      }
      return;
    }
    this.sel = -1;
    this.err = this.err + 1; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    if (this.err >= this.diffTotal) {
      this.msg = TG2('❌ 点错 {0} 次，休息一下',Digits(String(this.diffTotal), this.langCode));
      this.finish(false);
      return;
    }
    this.msg = '❌ ' + a + ' + ' + b + ' = ' + (a + b) + '，不是 ' + this.target;
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.over = true;
    this.won = solved;
    const r: GameResult = {
      gameId: 'number_bonds_all',
      solved: solved,
      score: solved ? Math.max(100, 900 - this.err * 200) : this.found.length * 150,
      durationMs: Date.now() - this.startAt,
      levelReached: this.found.length
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  build() {
    Column({ space: Space.md }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('目标'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.target), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('已拆'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.found.length + '/' + this.total())).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('失误'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.err + '/' + this.diffTotal)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            ForEach(this.cols, (c: number) => {
              Stack() {
              if ((r * COLS + c) < this.tiles.length) {
              Text(String(this.tiles[(r * COLS + c)])).fontSize(FontSize.xl).fontWeight(FontWeight.Bold).fontColor(this.used[(r * COLS + c)] ? this.theme.inkFaint : (this.sel === (r * COLS + c) ? '#FFFFFF' : this.theme.ink)).animation({ duration: Motion.fast, curve: Motion.snap() })
              }
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.used[(r * COLS + c)] ? this.theme.surfaceAlt
              : (this.sel === (r * COLS + c) ? Palette.violet : this.theme.surface)).borderRadius(Radius.md).shadow(Shadow.card).animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => {
              Haptics.tick();
              if ((r * COLS + c) < this.tiles.length) {
              this.tap((r * COLS + c));
              }
              })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if ((r * COLS + c) < this.tiles.length) { this.tap((r * COLS + c)); } }); })
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%').layoutWeight(1)

      Text(this.found.length > 0 ? '已拆出：' + this.found.join('  ') : '还没拆出任何一组').fontSize(FontSize.xs).fontColor(Palette.violet).width('100%')

      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft).width('100%')

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor(Color.White).backgroundColor(Palette.violet).borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => {
          Haptics.tap();
          this.reset();
        })
      .focusable(Tv.on())
      .focusBox(Tv.box())
      .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
