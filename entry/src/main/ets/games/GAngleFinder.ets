/**
 * 找角度 —— 多边形内角和减去已知角，求最后一个角的度数；n 边形内角和 = (n−2)×180°
 * 胜负：8 题答对 ≥6 通关　进度：题号 / 答对 / 得分
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
const TOTAL: number = 8; const PASS: number = 6; const NEXT_MS: number = 820;
const LETTERS: string[] = ['A', 'B', 'C', 'D'];
const OFFS: number[] = [-30, -20, -10, 10, 20, 30, 40];
@Component
export struct GAngleFinder {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法（size）：TOTAL 按难度换算（简单/普通/困难）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(TOTAL);
  onFinish: (r: GameResult) => void = () => {};
  @State n: number = 3; @State sum: number = 180; @State known: number[] = [];
  @State opts: number[] = []; @State ansIdx: number = -1; @State picked: number = -1;
  @State round: number = 1; @State rightN: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private nextTo: number = -1;
  private rows: number[] = [0, 1];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GAngleFinder')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(TOTAL);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    this.clearNext(); this.round = 1; this.rightN = 0; this.score = 0; this.over = false;
    this.won = false; this.finished = false; this.startAt = Date.now(); this.ask();
    this.msg = TG2('已知 {0} 个角，求最后一个角', (this.n - 1));
  }
  private shuffle(a: number[]): number[] {
    for (let i = a.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }
  /** 把一个内角和随机切成 n 份（每份 ≥20°），最后一份就是答案 */
  private ask(): void {
    const n: number = 3 + Math.floor(Math.random() * 4);
    const sum: number = (n - 2) * 180;
    let rest: number = sum - 20 * n;
    const known: number[] = [];
    for (let i = 0; i < n - 1; i++) {
      const take: number = i === n - 2 ? rest : Math.floor(Math.random() * (rest + 1));
      known.push(20 + take); rest = rest - take;
    }
    const ans: number = 20 + rest;
    const pool: number[] = [];
    for (let i = 0; i < OFFS.length; i++) { if (ans + OFFS[i] > 10) { pool.push(ans + OFFS[i]); } }
    this.shuffle(pool);
    const opts: number[] = this.shuffle([ans, pool[0], pool[1], pool[2]]);
    this.n = n; this.sum = sum; this.known = known; this.opts = opts;
    this.ansIdx = opts.indexOf(ans); this.picked = -1;
  }
  private sumOf(a: number[]): number {
    let s: number = 0;
    for (let i = 0; i < a.length; i++) { s = s + a[i]; }
    return s;
  }
  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 答案就在状态里（this.ansIdx）+ 有"已答"守卫
  /** 提示：直接报正确的那个选项（这款的答案就存在 this.ansIdx 里） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    const n: number = this.ansIdx;
    return Hint.make([n],
      TG2('答案是 {0}', String(this.opts[n])),
      TG2('The answer is {0}', String(this.opts[n])), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ 演示动画（项目 C）═══════════
  // ★ 两条退出路径：
  //   ① 演完 6 步（demoFinish）⇒ **必须 reset()**：成绩/记录回到干净开局
  //   ② 玩家碰了（demoStop）  ⇒ **不 reset**：他们那一下就是要开始玩
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
    if (this.picked >= 0) {
      return true;              // 这题答过了，等 setTimeout 进下一题
    }
    this.pick(this.ansIdx);
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

  private pick(i: number): void {
    if (this.picked >= 0 || this.over) { return; }
    this.picked = i;
    if (i === this.ansIdx) { this.rightN = this.rightN + 1; this.score = this.score + 130; this.msg = TG2('✅ 就是 {0}°', this.opts[this.ansIdx]); }
    else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 错了 —— {0}° 减去已知的 {1}°', this.sum, this.sumOf(this.known)); }
    this.clearNext();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round < this.diffTotal) {
      this.round = this.round + 1; this.ask();
      this.msg = TG2('已知 {0} 个角，求最后一个角', (this.n - 1)); return;
    }
    this.over = true; this.won = this.rightN >= PASS;
    this.msg = this.won ? TG2("🎉 答对 {0}/{1}，通关！",Digits(String(this.rightN), this.langCode),Digits(String(this.diffTotal), this.langCode)) : TG2("😵 只答对 {0}/{1}，差 {2} 题", this.rightN, this.diffTotal, (PASS - this.rightN));
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'angle_finder', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rightN };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + this.diffTotal)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('答对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.rightN + '/' + PASS)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }
        .layoutWeight(1).padding(Space.xs).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')
      Column({ space: Space.xs }) {
        Text(TG2('📐  {0} 边形', this.n)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        Text(TG2('内角和 = ({0} − 2) × 180° = {1}°', this.n, this.sum)).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Row({ space: Space.xs }) {
          ForEach(this.known, (a: number, i: number) => {
            Text('∠' + LETTERS[(i)] + ' = ' + (a) + '°').fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink).layoutWeight(1).padding(Space.xs)
            .backgroundColor(this.theme.surface).borderRadius(Radius.xs)
          }, (a: number, i: number) => 'k' + i)
        }
        .width('100%')
      }
      .width('100%').padding(Space.sm).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Column({ space: Space.sm }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.sm }) {
            Text(LETTERS[(r * 2)] + '. ' + this.opts[(r * 2)] + '°').fontSize(FontSize.md).fontWeight(FontWeight.Bold)
            .fontColor(this.picked >= 0 && ((r * 2) === this.ansIdx || (r * 2) === this.picked) ? '#FFFFFF' : this.theme.ink)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(56))
            .backgroundColor(this.picked < 0 ? this.theme.surface
            : ((r * 2) === this.ansIdx ? Palette.emerald : ((r * 2) === this.picked ? Palette.rose : this.theme.surface)))
            .borderRadius(Radius.md).shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((r * 2)); }); }).onClick(() => { Haptics.tick(); this.pick((r * 2)); })
            Text(LETTERS[(r * 2 + 1)] + '. ' + this.opts[(r * 2 + 1)] + '°').fontSize(FontSize.md).fontWeight(FontWeight.Bold)
            .fontColor(this.picked >= 0 && ((r * 2 + 1) === this.ansIdx || (r * 2 + 1) === this.picked) ? '#FFFFFF' : this.theme.ink)
            .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(56))
            .backgroundColor(this.picked < 0 ? this.theme.surface
            : ((r * 2 + 1) === this.ansIdx ? Palette.emerald : ((r * 2 + 1) === this.picked ? Palette.rose : this.theme.surface)))
            .borderRadius(Radius.md).shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((r * 2 + 1)); }); }).onClick(() => { Haptics.tick(); this.pick((r * 2 + 1)); })
          }
          .width('100%')
        }, (r: number) => 'or' + r)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
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
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：先把已知角加起来，再用内角和去减')).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }



}
