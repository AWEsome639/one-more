/**
 * 双镜像 —— 两块 4×4 灯板，一次点击**两块同时变**，且左右是镜像位置
 *
 * 玩法：点左板 (r,c) ⇒ 左板 (r,c) 与右板 (r,3-c) 同时翻转；点右板同理。
 *       目标：把两块板的灯全部熄灭。
 * 胜负：全灭 ⇒ solved=true；步数超过 MOVE_LIMIT 还没灭 ⇒ solved=false
 * 保证有解：开局就是把「全灭」状态用同一套镜像操作随机翻几下得到的，倒着点回去即可复原
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
// ★ 2026-10-30 布局 bug ③ 修复：两块灯板的边长要用 Bp（当前窗口宽/高）反算
import { Bp } from '../core/Bp';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const N: number = 4;
const MOVE_LIMIT: number = 20;
const SCRAMBLE_MIN: number = 4;
const SCRAMBLE_MAX: number = 6;

/**
 * 两块灯板之外的纵向预留（vp）—— 按全项目最苛刻的 533vp 横屏口径逐项拆开算：
 *   顶栏           88   （GameHost：padding top 28 + 图标行 44 + padding bottom 16）
 *   底 padding     20   （GameHost 游戏区 padding bottom = Space.lg）
 *   HintBar        38   （顶部「提示 / AI 代打」条）
 *   信息行         59   （三张卡片：padding 10×2 + xxs 12 与 md 16 两行 + 行距 2）
 *   消息行         18   （this.msg）
 *   重开按钮       52   （Cell.of(46) 在平板 ×1.12）
 *   底部说明       24   （最下面那行规则文字，最长一句，窄屏可能两行）
 *   行间距         50   （Column space = Space.sm(10) × 5 处间隙）
 *   ⇒ 88+20+38+59+18+52+24+50 = 349
 *
 * 235 这个数的意义在**宽度**上（两盘并排 ⇒ 边长受棋盘外的东西限制）：
 *   533 - 235 = 298 = 两盘总宽（减去中间 Space.sm(10) 后各 144vp）
 *   ⇒ 每盘那块 Column 高 = 标题 16 + 行距 6 + 棋盘 144 = 166
 *   ⇒ 整页总高 = 349 + 166 = 515 ≤ 533，**留 18vp 余量**（不再溢出）
 * 手机竖屏 440×744：min(400, 509) = 400 ⇒ 每盘 195vp —— 与改前完全一致（零回归）
 */
const BOARD_RESERVE: number = 235;

function range(n: number): number[] {
  const a: number[] = [];
  for (let i = 0; i < n; i++) {
    a.push(i);
  }
  return a;
}

@Component
export struct GDualMirror {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（lives）：MOVE_LIMIT 按难度换算
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.livesNow(MOVE_LIMIT);
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  onFinish: (r: GameResult) => void = () => {};

  @State private left: number[] = [];
  @State private right: number[] = [];
  @State private moves: number = 0;
  @State private msg: string = TG('点任意一格格子，两块板会同时镜像翻转');
  @State private over: boolean = false;
  @State private won: boolean = false;

  private startAt: number = 0;
  private finished: boolean = false;
  private rows: number[] = range(N);

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GDualMirror')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  onRestart(): void {
    this.diffTotal = GameDiff.livesNow(MOVE_LIMIT);
    this.reset();
  }

  private reset(): void {
    let l: number[] = [];
    let r: number[] = [];
    for (let t = 0; t < 12; t++) {
      l = new Array<number>(N * N).fill(0);
      r = new Array<number>(N * N).fill(0);
      const times: number = SCRAMBLE_MIN + Math.floor(Math.random() * (SCRAMBLE_MAX - SCRAMBLE_MIN + 1));
      for (let k = 0; k < times; k++) {
        const cell: number = Math.floor(Math.random() * N * N);
        this.flip(l, r, cell);
      }
      if (this.lit(l) + this.lit(r) > 0) {
        break;
      }
    }
    this.left = l;
    this.right = r;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.finished = false;
    this.msg = TG('点任意一格格子，两块板会同时镜像翻转');
    this.startAt = Date.now();
  }

  /** 一次镜像翻转：同板 (r,c) + 另一板 (r, N-1-c) */
  private flip(l: number[], r: number[], cell: number): void {
    const row: number = Math.floor(cell / N);
    const col: number = cell % N;
    const other: number = row * N + (N - 1 - col);
    l[cell] = l[cell] === 0 ? 1 : 0;
    r[other] = r[other] === 0 ? 1 : 0;
  }

  private lit(board: number[]): number {
    let n: number = 0;
    for (let i = 0; i < board.length; i++) {
      if (board[i] === 1) {
        n++;
      }
    }
    return n;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
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
    // ★★ 2026-11-01 修回归：演示**自然结束**时也必须 reset。
    //   否则棋盘停在"演示玩过的状态"、分数是演示加的分 —— 玩家一进来就是残局。
    //   （第一版模板漏了这一句，333 款全部中招；真机"步数 1/25"就是它。）
    this.reset();
  }

  private demoStop(): void {
    if (this.demoId >= 0) {
      Demo.stop(this.demoId);
      this.demoId = -1;
    }
    this.demoFinish();   // 里面已 reset，不再重复
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
    if (false) {
      return true;
    }
    this.tap(0, this.mirrorNext());
    return !this.over;
  }

  /** 提示：把左板还亮着的格子各点一次，两块板会同时灭 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) { return Hint.none('none'); }
    for (let i = 0; i < this.left.length; i++) {
      if (this.left[i] === 1) {
        const row: number = Math.floor(i / N) + 1;
        const col: number = i % N + 1;
        return Hint.make([i],
          TG2('点左板第 {0} 行第 {1} 列（左板还剩 {2} 盏灯）', String(row), String(col), String(this.lit(this.left))),
          'Tap left board row ' + String(row), t0);
      }
    }
    return Hint.none('none');
  }

  /** 辅助：左板第一盏还亮着的灯（点它 ⇔ 两块板各灭一盏） */
  private mirrorNext(): number {
    for (let i = 0; i < this.left.length; i++) {
      if (this.left[i] === 1) { return i; }
    }
    return 0;
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

  private tap(side: number, cell: number): void {
    if (this.over) {
      return;
    }
    const l: number[] = this.left.slice();
    const r: number[] = this.right.slice();
    if (side === 1) {
      this.flip(r, l, cell);
    } else {
      this.flip(l, r, cell);
    }
    this.left = l;
    this.right = r;
    this.moves++;

    if (this.lit(l) + this.lit(r) === 0) {
      this.over = true;
      this.won = true;
      this.msg = TG2("🎉 两块板全灭了，用了 {0} 步",Digits(String(this.moves), this.langCode));
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    if (this.moves >= this.diffTotal) {
      this.over = true;
      this.won = false;
      this.msg = TG2('步数用完，还剩 {0} 盏灯', (this.lit(l) + this.lit(r)));
      this.finish(false);
      return;
    }
    this.msg = TG2("已走 {0} 步 · 还剩 {1} 盏灯",Digits(String(this.moves), this.langCode), (this.lit(l) + this.lit(r)));
  }

  private finish(solved: boolean): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const r: GameResult = {
      gameId: 'dual_mirror',
      solved: solved,
      score: solved ? Math.max(80, 400 - this.moves * 15) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
    };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  /**
   * 两块灯板的**可用总边长**（vp）：宽度与可用高度取小者 —— 不许 aspectRatio 自行决定高度。
   *
   * ★★★ 2026-10-30 修布局 bug ③（两块板一高一矮 + 右盘溢出）：
   *   改前左右两盘用的是同一段代码，但只有**左盘**多了
   *   `.constraintSize({ maxHeight: '70%' })`，右盘只有 `.width('100%').aspectRatio(1)`：
   *     · 左盘：被限高 70%，aspectRatio 反推宽度 ⇒ 比格子实际需要的小
   *     · 右盘：完全没有高度约束 ⇒ 宽 401vp ⇒ 高 401vp
   *   ⇒ 两盘**不等高**，右盘还把 533vp 的屏撑爆（板下消息行、重开按钮被顶出屏幕）。
   *
   *   ⇒ 修：两盘走**同一个函数**取边长（各占一半，减去中间 Space.sm 间距），
   *     左右必然等高等宽，且宽高都是确定值 ⇒ 谁也不会再撑爆页面。
   *     手机竖屏 440×744：min(400, 509) = 400 ⇒ 每盘 195vp（与改前一致）
   *     平板横屏 853×533：min(813, 298) = 298 ⇒ 每盘 144vp（改前右盘 401vp、溢出 4/5 屏）
   */
  private boardPx(reserve: number): number {
    const w: number = Math.max(160, Bp.width - 40);   // 40 = GameHost 游戏区左右 padding（Space.lg × 2）
    // ⚠️ 高度下限只能取 96：取 160 这类大数会在矮屏（533vp 横屏）上把算出来的值**顶高**，
    //    棋盘比可用空间还大 ⇒ 底部又溢出。96 只用来防「窗口极小时算出 0/负数」。
    const h: number = Math.max(96, Bp.height - reserve);
    return Math.min(w, h);
  }

  /** 单块灯板边长（vp）：两盘并排 ⇒ 总边长减去中间 Space.sm 间距后对半分 */
  private sidePx(): number {
    return (this.boardPx(BOARD_RESERVE) - Space.sm) / 2;
  }

  build() {
    Column({ space: Space.sm }) {
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.moves + ' / ' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.primary))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余灯'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.lit(this.left) + this.lit(this.right)))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('状态'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.over ? (this.won ? '通关' : TG('结束')) : '进行中')).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((this.over ? (this.won ? Palette.emerald : Palette.rose) : Palette.sky))
        }
        .layoutWeight(1)
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
      }
      .width('100%')

      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
          Text(TG('左板')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Column({ space: 2 }) {
            ForEach(this.rows, (r: number) => {
              Row({ space: 2 }) {
                ForEach(this.rows, (c: number) => {
                  Stack() {
                  if (this.on((0), (r * N + c))) {
                  Row()
                  .width('70%')
                  .aspectRatio(1)
                  .backgroundColor(Palette.amber)
                  .borderRadius(Radius.full)
                  .shadow(Shadow.card)
                  }
                  }
                  .layoutWeight(1)
                  .aspectRatio(1)
                  .backgroundColor(this.on((0), (r * N + c)) ? '#33F59E0B' : this.theme.surface)
                  .borderRadius(Radius.xs)
                  .animation({ duration: Motion.fast, curve: Motion.snap() })
                  .focusable(Tv.on())
                  .focusBox(Tv.box())
                  .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((0), (r * N + c)); }); })
                  .onClick(() => {
                  Haptics.tick();
                  this.tap((0), (r * N + c));
                  })
                }, (c: number) => 'lc' + c)
              }
              .width('100%')
              .layoutWeight(1)
            }, (r: number) => 'lr' + r)
          }
          // ★★★ 2026-10-30（布局 bug ③ 主修点 · 左盘）：
          //   改前：`.width('100%')` + `.aspectRatio(1)` + `.constraintSize({ maxHeight: '70%' })`
          //         ⇒ 宽度把高度锁死，只靠 70% 上限"事后补救"，两盘各算各的 ⇒ 一高一矮。
          //   改后：宽高都由 sidePx() 给定（与右盘同一个值）⇒ 左右必然等大。
          .width(this.sidePx())
          .height(this.sidePx())
          .alignSelf(ItemAlign.Center)
          .padding(Space.xs)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .layoutWeight(1)

        Column({ space: Space.xs }) {
          Text(TG('右板（镜像）')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
          Column({ space: 2 }) {
            ForEach(this.rows, (r: number) => {
              Row({ space: 2 }) {
                ForEach(this.rows, (c: number) => {
                  Stack() {
                  if (this.on((1), (r * N + c))) {
                  Row()
                  .width('70%')
                  .aspectRatio(1)
                  .backgroundColor(Palette.amber)
                  .borderRadius(Radius.full)
                  .shadow(Shadow.card)
                  }
                  }
                  .layoutWeight(1)
                  .aspectRatio(1)
                  .backgroundColor(this.on((1), (r * N + c)) ? '#33F59E0B' : this.theme.surface)
                  .borderRadius(Radius.xs)
                  .animation({ duration: Motion.fast, curve: Motion.snap() })
                  .focusable(Tv.on())
                  .focusBox(Tv.box())
                  .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((1), (r * N + c)); }); })
                  .onClick(() => {
                  Haptics.tick();
                  this.tap((1), (r * N + c));
                  })
                }, (c: number) => 'rc' + c)
              }
              .width('100%')
              .layoutWeight(1)
            }, (r: number) => 'rr' + r)
          }
          // ★★★ 2026-10-30（布局 bug ③ 主修点 · 右盘）：
          //   改前：`.width('100%')` + `.aspectRatio(1)`，**完全没有高度约束**
          //         ⇒ 宽 401vp 就撑出 401vp 高，右盘比左盘高一截，并且把 533vp 的屏撑爆。
          //   改后：与左盘同一个 sidePx() ⇒ 两盘等高等宽，整页不再溢出。
          .width(this.sidePx())
          .height(this.sidePx())
          .alignSelf(ItemAlign.Center)
          .padding(Space.xs)
          .backgroundColor(this.theme.surfaceAlt)
          .borderRadius(Radius.md)
          .shadow(Shadow.card)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(this.msg)
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md)
        .fontColor(Color.White)
        .backgroundColor(Palette.primary)
        .borderRadius(Radius.md)
        .width('100%')
        .height(Cell.of(46))
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG2('点左板 (r,c) ⇒ 左 (r,c) 与右 (r,{0}-c) 同时翻转；点右板同理。把两块板都熄掉通关', (N - 1)))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }





  /** 该格是否亮着（side 0 = 左板，1 = 右板） */
  private on(side: number, cell: number): boolean {
    const b: number[] = side === 0 ? this.left : this.right;
    return b.length > cell && b[cell] === 1;
  }
}
