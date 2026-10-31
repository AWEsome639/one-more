/**
 * 生命游戏（康威）—— 细胞自动机 🧬
 *
 * 规则：每个细胞看周围 8 格；活细胞 2~3 个邻居存活，死细胞恰好 3 个邻居则诞生。
 * 胜负：撑满 60 代不灭绝 = 通关；中途全部死光 = 失败（可随时点格子人工干预）
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { DemoBar } from '../components/DemoBar';
import { FontSize, Space, Radius, Palette, Theme, Shadow, Cell } from '../core/Design';
import { Demo } from '../core/Demo';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';
import { Tv } from '../core/Tv';

const G: number = 12;
const GOAL: number = 60;
const TICK: number = 300;

@Component
export struct GLifeGame {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：GOAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(GOAL);
  onFinish: (r: GameResult) => void = () => {};

  @State private cells: boolean[] = [];
  @State private gen: number = 0;
  @State private aliveN: number = 0;
  @State private running: boolean = false;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private k: number = 1;

  private timer: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GLifeGame')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }

  aboutToDisappear(): void {
    this.stop();
  }

  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(GOAL);
    this.reset();
  }

  private stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** ★ 2026-10-14 动画补齐：进度/得分脉冲（本款原来一处 .animation() 都没有） */

  private bumpK(): void {

    this.k = 1.16;

    animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.k = 1; });

  }

  private reset(): void {
    this.stop();
    const c: boolean[] = [];
    let n: number = 0;
    for (let i = 0; i < G * G; i++) {
      const live: boolean = Math.random() < 0.32;
      c.push(live);
      if (live) {
        n++;
      }
    }
    this.cells = c;
    this.gen = 0;
    this.aliveN = n;
    this.running = false;
    this.over = false;
    this.won = false;
    this.startAt = Date.now();
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
    if (this.running) {
      return true;
    }
    if (!this.lifeDone) {
      if (this.lifeAt === 0 && this.lifeTo.length === 0) {
        this.lifeTo = this.lifePlan();
      }
      if (this.lifeAt < this.lifeTo.length) {
        this.tap(this.lifeTo[this.lifeAt]);
        this.lifeAt = this.lifeAt + 1;
        return true;
      }
      this.lifeDone = true;
    }
    this.play();
    return true;
  }

  /** 计划要翻转的格（一次性算好，避免来回改主意） */
  private lifeTo: number[] = [];
  private lifeAt: number = 0;
  private lifeDone: boolean = false;

  /** 代打/提示共用：最省事的 2×2 稳定块（生命游戏里 2×2 方块永生）⇒ 返回要翻转的格 */
  private lifePlan(): number[] {
    let best: number[] = [];
    let bestCost: number = 999;
    for (let r = 1; r < G - 2; r++) {
      for (let c = 1; c < G - 2; c++) {
        const cur: number[] = [];
        for (let dr = -1; dr <= 2; dr++) {
          for (let dc = -1; dc <= 2; dc++) {
            const want: boolean = dr >= 0 && dr <= 1 && dc >= 0 && dc <= 1;
            const i: number = (r + dr) * G + (c + dc);
            if (want !== this.cells[i]) {
              cur.push(i);
            }
          }
        }
        if (cur.length < bestCost) {
          bestCost = cur.length;
          best = cur;
        }
      }
    }
    return best;
  }

  /** 提示：报「该点哪一格布种」或「已经是永生块了，开始吧」 */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.running) {
      return Hint.none(TG('演化中，先暂停再布种'));
    }
    const plan: number[] = this.lifePlan();
    if (plan.length === 0) {
      return Hint.make([], TG('已经是永生的 2×2 方块，按「开始」就行'),
        TG('A stable 2x2 block is ready - just press start'), t0);
    }
    const k: number = plan[0];
    const r: number = Math.floor(k / G) + 1;
    const c: number = k - Math.floor(k / G) * G + 1;
    return Hint.make([k],
      TG2('点第 {0} 行第 {1} 列（2×2 方块能活到最后；布好还差 {2} 格）', String(r), String(c), String(plan.length)),
      TG2('Tap row {0}, column {1} (a 2x2 block survives; {2} taps to go)', String(r), String(c), String(plan.length)), t0);
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
    if (this.over) {
      return;
    }
    const c: boolean[] = this.cells.slice();
    c[i] = !c[i];
    this.cells = c;
    let n: number = 0;
    for (let k = 0; k < c.length; k++) {
      if (c[k]) {
        n++;
      }
    }
    this.aliveN = n;
  }

  private step(): void {
    if (this.over) {
      return;
    }
    const next: boolean[] = [];
    let alive: number = 0;
    for (let r = 0; r < G; r++) {
      for (let c = 0; c < G; c++) {
        let cnt: number = 0;
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            if (dr === 0 && dc === 0) {
              continue;
            }
            const rr: number = r + dr;
            const cc: number = c + dc;
            if (rr >= 0 && rr < G && cc >= 0 && cc < G && this.cells[rr * G + cc]) {
              cnt++;
            }
          }
        }
        const live: boolean = this.cells[r * G + c];
        const nxt: boolean = live ? (cnt === 2 || cnt === 3) : (cnt === 3);
        next.push(nxt);
        if (nxt) {
          alive++;
        }
      }
    }
    this.cells = next;
    this.gen = this.gen + 1;
    this.bumpK();
    this.aliveN = alive;

    if (alive === 0) {
      this.stop();
      this.running = false;
      this.over = true;
      this.finish(false);
      return;
    }
    if (this.gen >= this.diffTotal) {
      this.stop();
      this.running = false;
      this.over = true;
      this.won = true;
      this.finish(true);
    }
  }

  private play(): void {
    if (this.over) {
      return;
    }
    if (this.running) {
      this.stop();
      this.running = false;
      return;
    }
    this.running = true;
    this.stop();
    this.timer = setInterval(() => {
      this.step();
    }, TICK);
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'life_game',
      solved: solved,
      score: solved ? 600 + this.aliveN * 20 : this.gen * 10,
      durationMs: Date.now() - this.startAt,
      levelReached: this.gen
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
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('代数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.gen) + '/' + String(this.diffTotal))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        .scale({ x: this.k, y: this.k })
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('存活'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.aliveN), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (r: number) => {
          Row({ space: 2 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (c: number) => {
              Row()
              .layoutWeight(1)
              .aspectRatio(1)
              .backgroundColor(this.cells[(r * G + c)] ? Palette.violet : this.theme.surface)
              .borderRadius(Radius.xs)
              .focusable(Tv.on())
              .focusBox(Tv.box())
              .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tap((r * G + c)); }); })
              .onClick(() => {
              Haptics.tick();
              this.tap((r * G + c));
              })
            }, (c: number) => 'c' + r + '-' + c)
          }
          .width('100%')
        }, (r: number) => 'r' + r)
      }
      .width('100%')
      .aspectRatio(1)
      // ★ 2026-10-30 平板横屏：正方形场地被宽度锁死（1280vp 宽 ⇒ 1280vp 高），
      //   超出 533vp 的屏高 ⇒ 场地被裁。限高让 aspectRatio 反推能装下的最大正方形。
      .constraintSize({ maxHeight: '70%' })
      .padding(Space.xs)
      .backgroundColor(this.theme.surfaceAlt)
      .borderRadius(Radius.md)

      Text(this.over ? (this.won ? '🎉 存活满 60 代，种群稳定！' : '💀 第 ' + String(this.gen) + ' 代灭绝了') :
        (this.running ? '演化中…点格子可以人工投放生命' : '点格子布种，再按开始'))
        .fontSize(FontSize.sm)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Row({ space: Space.md }) {
        Button(this.running ? TG('暂停') : TG('开始'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.violet).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.play(); }); })
          .onClick(() => {
            Haptics.tap();
            this.play();
          })
        Button(TG('单步'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.ink)
          .backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.running && !this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.step(); }); })
          .onClick(() => {
            Haptics.tap();
            this.step();
          })
      }
      .width('100%')

      Row({ space: Space.md }) {
        Button(TG('随机一局'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(Color.White)
          .backgroundColor(Palette.primary).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
          .onClick(() => {
            Haptics.tap();
            this.reset();
          })
        Button(TG('清空'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
          .fontSize(FontSize.md).fontColor(this.theme.inkSoft)
          .backgroundColor(this.theme.surface).borderRadius(Radius.md)
          .layoutWeight(1).height(Cell.of(44))
          .enabled(!this.over)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.stop(); this.running = false; this.cells = new Array<boolean>(G * G).fill(false); this.aliveN = 0; }); })
          .onClick(() => {
            Haptics.tap();
            this.stop();
            this.running = false;
            this.cells = new Array<boolean>(G * G).fill(false);
            this.aliveN = 0;
          })
      }
      .width('100%')
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%')
    .height('100%')
  }

}
