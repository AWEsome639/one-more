/**
 * 七巧板 —— 用 4 块砖严丝合缝铺满阴影；点已铺的砖可取回重放
 * 胜负：铺满 ⇒ 通关；次数用尽（12 次）⇒ 失败　｜　进度：铺对 / 次数
 */
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4; const LIMIT: number = 12;

interface Piece { cells: number[]; icon: string; name: string; }
interface Slot { p: number; r: number; c: number; }

const PIECES: Piece[] = [
  { cells: [0, 1], icon: '▬', name: '短条2' },
  { cells: [0, 1, 4], icon: '◤', name: '直角3' },
  { cells: [0, 1, 4, 5], icon: '■', name: '方块4' },
  { cells: [0, 4, 8], icon: '▮', name: '竖条3' }
];

const LAYOUTS: Slot[][] = [
  [{ p: 2, r: 0, c: 0 }, { p: 1, r: 0, c: 2 }, { p: 0, r: 2, c: 0 }, { p: 3, r: 1, c: 3 }],
  [{ p: 2, r: 0, c: 0 }, { p: 3, r: 0, c: 2 }, { p: 1, r: 2, c: 0 }, { p: 0, r: 3, c: 2 }],
  [{ p: 1, r: 0, c: 0 }, { p: 0, r: 0, c: 2 }, { p: 2, r: 1, c: 1 }, { p: 3, r: 1, c: 3 }],
  [{ p: 3, r: 0, c: 0 }, { p: 1, r: 0, c: 1 }, { p: 2, r: 1, c: 2 }, { p: 0, r: 3, c: 0 }]
];

function shadowOf(layout: Slot[]): number[] {
  const g: number[] = new Array<number>(N * N).fill(0);
  for (let s = 0; s < layout.length; s++) {
    const cells: number[] = PIECES[layout[s].p].cells;
    for (let m = 0; m < cells.length; m++) {
      g[(layout[s].r + Math.floor(cells[m] / N)) * N + (layout[s].c + cells[m] % N)] = 1;
    }
  }
  return g;
}
@Component
export struct GTangram {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  /**
   * ★★★ 2026-10-23 修「尺寸陷阱」：
   *   原来 diffTotal = sizeNow(4)（3/4/5），但**四套拼图布局是手工为 4×4 画的**，
   *   shadowOf() 也固定返回 4×4 的投影：
   *     渲染却用 this.target[r * diffTotal + c] —— 拿 diffTotal 当步长索引 4×4 的数组
   *     ⇒ 困难档 5×5 时下标越界读到 undefined，简单档 3×3 时读错格
   *   ⇒ 简单档与困难档都是坏的。
   *
   *   修法：**拼图几何就是 4×4**，棋盘固定下来；
   *   难度改到**步数上限**上（上限越少越难）—— 这本来就是这款游戏的压力来源。
   */
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  @State private boardN: number = 4;
  /** 本局允许的步数上限：简单 18 / 普通 12 / 困难 8 */
  @State private moveLimit: number = GTangram.limitNow();

  private static limitNow(): number {
    const d: number = GameDiff.now();
    if (d === 0) {
      return 18;
    }
    if (d === 2) {
      return 8;
    }
    return 12;
  }
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.boardN > 1 ? this.boardN : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State target: number[] = []; @State pieceAt: number[] = []; @State sel: number = -1;
  @State moves: number = 0; @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private done: boolean = false;
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GTangram')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.moveLimit = GTangram.limitNow();
     this.reset(); }
  private reset(): void {
    const li: number = Math.floor(Math.random() * LAYOUTS.length);
    this.target = shadowOf(LAYOUTS[li]); this.pieceAt = new Array<number>(this.boardN * this.boardN).fill(-1);
    this.sel = -1; this.moves = 0; this.over = false; this.won = false; this.done = false;
    this.startAt = Date.now(); this.msg = TG('选一块砖，再点棋盘落点铺上去');
  }
  /** [铺对格数, 阴影总格数] */
  private scan(): number[] {
    let ok: number = 0; let all: number = 0;
    for (let i = 0; i < this.target.length; i++) {
      if (this.target[i] === 1) { all = all + 1; if (this.pieceAt[i] >= 0) { ok = ok + 1; } }
    }
    return [ok, all];
  }
  /** ★ AI 代打/提示共用：本局阴影出自哪一套布局（4 套都是严丝合缝的铺法） */
  private solIdx(): number {
    for (let i = 0; i < LAYOUTS.length; i++) {
      const sh: number[] = shadowOf(LAYOUTS[i]);
      let same: boolean = true;
      for (let k = 0; k < this.target.length; k++) {
        if (sh[k] !== this.target[k]) {
          same = false;
        }
      }
      if (same) {
        return i;
      }
    }
    return -1;
  }

  /** 下一块该放的砖：返回 [砖号, 落点格号]，都放好了返回空 */
  private nextSlot(): number[] {
    const li: number = this.solIdx();
    if (li < 0) {
      return [];
    }
    const slots: Slot[] = LAYOUTS[li];
    for (let i = 0; i < slots.length; i++) {
      const at: number = slots[i].r * this.boardN + slots[i].c;
      if (this.pieceAt[at] !== slots[i].p) {
        return [slots[i].p, at];
      }
    }
    return [];
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
    const li: number = this.solIdx();
    if (li < 0) {
      return false;
    }
    const slots: Slot[] = LAYOUTS[li];
    for (let i = 0; i < slots.length; i++) {
      const at: number = slots[i].r * this.boardN + slots[i].c;
      if (this.pieceAt[at] === slots[i].p) {
        continue;
      }
      if (this.pieceAt[at] >= 0) {
        return false;
      }
      this.sel = slots[i].p;
      this.tap(at);
      return !this.over;
    }
    return false;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const nx: number[] = this.nextSlot();
    if (nx.length < 2) {
      return Hint.none('none');
    }
    const r: number = Math.floor(nx[1] / this.boardN) + 1;
    const c: number = nx[1] % this.boardN + 1;
    return Hint.make([nx[1]],
      TG2('把「{0}」铺在第 {1} 行第 {2} 列', PIECES[nx[0]].icon + PIECES[nx[0]].name, r, c),
      TG2('Place piece {0} at row {1}, column {2}', PIECES[nx[0]].icon, r, c), t0);
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
    if (this.over) { return; }
    if (this.pieceAt[i] >= 0) {
      const back: number[] = this.pieceAt.slice();
      const which: number = this.pieceAt[i];
      for (let k = 0; k < back.length; k++) { if (back[k] === which) { back[k] = -1; } }
      this.pieceAt = back; this.sel = -1; this.msg = TG2("{0} 已取回", PIECES[which].name);
      return;
    }
    if (this.sel < 0) { this.msg = TG('先在上方选一块砖'); return; }
    const cells: number[] = PIECES[this.sel].cells;
    const r: number = Math.floor(i / this.boardN); const c: number = i % this.boardN;
    for (let m = 0; m < cells.length; m++) {
      const rr: number = r + Math.floor(cells[m] / this.boardN); const cc: number = c + cells[m] % this.boardN;
      if (rr >= this.boardN || cc >= this.boardN || this.pieceAt[rr * this.boardN + cc] >= 0) { this.msg = TG('❌ 放不下：出界或压住别的砖'); return; }
    }
    const at: number[] = this.pieceAt.slice();
    for (let m = 0; m < cells.length; m++) {
      at[(r + Math.floor(cells[m] / this.boardN)) * this.boardN + (c + cells[m] % this.boardN)] = this.sel;
    }
    this.pieceAt = at; this.sel = -1; this.moves = this.moves + 1;
    let exact: boolean = true;
    for (let k = 0; k < this.boardN * this.boardN; k++) {
      if ((this.target[k] === 1) !== (this.pieceAt[k] >= 0)) { exact = false; }
    }
    const now: number[] = this.scan();
    if (exact) {
      this.over = true; this.won = true; this.msg = TG2("🎉 严丝合缝！用了 {0} 次",Digits(String(this.moves), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true); return;
    }
    if (this.moves >= this.moveLimit) {
      this.over = true; this.won = false;
      this.msg = TG2("💤 次数用尽，只铺对 {0} / {1} 格", now[0], now[1]);
      this.finish(false); return;
    }
    this.msg = TG2("铺对 {0} / {1} 格　剩 {2} 次", now[0], now[1], (this.moveLimit - this.moves));
  }
  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const sc: number = solved ? 40 + (this.moveLimit - this.moves) * 5 : this.scan()[0] * 5;
    const r: GameResult = { gameId: 'tangram', solved: solved, score: sc, durationMs: Date.now() - this.startAt, levelReached: this.scan()[0] };
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
      Text(TG2('铺对 {0} / {1}　次数 {2}', String(this.scan()[0]), String(this.scan()[1]),Digits(String(this.moves), this.langCode)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%').textAlign(TextAlign.Center)
      Row({ space: Space.sm }) {
        ForEach(this.rowIdx(), (p: number) => {
          Text((this.pieceAt.indexOf((p)) >= 0 ? '· ' : PIECES[(p)].icon + ' ') + PIECES[(p)].name)
          .fontSize(FontSize.xs).textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(50))
          .fontColor(this.pieceAt.indexOf((p)) >= 0 ? this.theme.inkFaint : this.theme.inkSoft)
          .backgroundColor(this.sel === (p) ? '#336366F1' : this.theme.surfaceAlt).borderRadius(Radius.md)
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .onClick(() => {
          Haptics.tick();
          if (this.pieceAt.indexOf((p)) < 0 && !this.over) { this.sel = this.sel === (p) ? -1 : (p); }
          })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); if (this.pieceAt.indexOf((p)) < 0 && !this.over) { this.sel = this.sel === (p) ? -1 : (p); } }); })
        }, (p: number) => 'p' + p)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text('').fontSize(FontSize.md)
              }.layoutWeight(1).aspectRatio(1).borderRadius(Radius.xs)
              .backgroundColor(this.pieceAt[(r * this.boardN + c)] >= 0 ? (this.target[(r * this.boardN + c)] === 1 ? Palette.sky : Palette.rose)
              : (this.target[(r * this.boardN + c)] === 1 ? (this.theme.isDark ? '#220EA5E9' : '#330EA5E9') : this.theme.surfaceAlt))
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * this.boardN + c)); })
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * this.boardN + c)); }); })
            }, (c: number) => 'c' + r + '_' + c)
          }.width('100%').layoutWeight(1)
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm).backgroundColor(this.theme.surface)
      // ★ 2026-10-31 真机（横屏 853×533）：宽驱动 aspectRatio 无上限 ⇒ 棋盘撑到 813vp 高，
      //   而游戏区可用只有 377vp（屏高 533 − 顶栏 156）⇒ 下方按钮与说明整体在窗外。限高让 aspectRatio 反推宽度。
      .constraintSize({ maxHeight: Math.max(140, Bp.height - 360) })
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开（换一题）'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
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
