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
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
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

  build() {
    Column({ space: Space.sm }) {
      HintBar({
        showHint: true,
        onHintTap: () => { this.askHint(); },
        onAutoTap: () => { this.askAuto(); },
        demoOn: this.demoId >= 0,
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
          .width('100%')
          .aspectRatio(1)
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
          .width('100%')
          .aspectRatio(1)
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
