/**
 * 矩阵秩进阶 —— 6×6 的 0/1 矩阵，求它在模 2 下的秩；点一行选中、再点另一行 = 后者异或前者
 * （秩不变；同样两行再点一遍即复原）　胜负：6 题答对 ≥4 通关　进度：题号 / 答对 / 得分
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
const N: number = 6; const CELLS: number = N * N; const TOTAL: number = 6; const PASS: number = 4; const NEXT_MS: number = 820;
@Component
export struct GBinaryMatrixRankAll {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=6；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3, 4, 5]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  /** 演示动画（项目 C）：-1 = 未运行 */
  @State private demoId: number = -1;
  @State private demoLeft: number = 0;
  // ★ 2026-11-01 演示三拍（共用组件 DemoBar 承载展示）
  @State private demoMsg: string = '';
  @State private demoPhase: number = 0;
  @State private demoRound: number = 0;
  @State private diffTotal: number = GameDiff.sizeNow(6);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State m: number[] = []; @State sel: number = -1; @State picked: number = -1;
  @State round: number = 1; @State rightN: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private finished: boolean = false; private nextTo: number = -1; private realRank: number = 0;
  private rows: number[] = [0, 1, 2, 3, 4, 5]; private ranks: number[] = [0, 1, 2, 3, 4, 5, 6];
  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    if (Hint.demoOnce('GBinaryMatrixRankAll')) {
      setTimeout(() => { this.demoStart(); }, 3000);
    }
  }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(6);
     this.reset(); }
  aboutToDisappear(): void { this.clearNext(); }
  private clearNext(): void { if (this.nextTo >= 0) { clearTimeout(this.nextTo); this.nextTo = -1; } }
  private reset(): void {
    this.clearNext(); this.round = 1; this.rightN = 0; this.score = 0; this.over = false;
    this.won = false; this.finished = false; this.sel = -1; this.startAt = Date.now(); this.ask();
  }
  /** 模 2 高斯消元（按位异或）求秩 */
  private rank(src: number[]): number {
    const a: number[] = src.slice();
    let r: number = 0;
    for (let c = 0; c < this.diffTotal; c++) {
      if (r >= this.diffTotal) { break; }
      let piv: number = -1;
      for (let i = r; i < this.diffTotal; i++) { if (a[i * this.diffTotal + c] === 1) { piv = i; break; } }
      if (piv < 0) { continue; }
      if (piv !== r) { for (let k = 0; k < this.diffTotal; k++) { const t: number = a[r * this.diffTotal + k]; a[r * this.diffTotal + k] = a[piv * this.diffTotal + k]; a[piv * this.diffTotal + k] = t; } }
      for (let i = 0; i < this.diffTotal; i++) {
        if (i !== r && a[i * this.diffTotal + c] === 1) { for (let k = 0; k < this.diffTotal; k++) { a[i * this.diffTotal + k] = a[i * this.diffTotal + k] ^ a[r * this.diffTotal + k]; } }
      }
      r = r + 1;
    }
    return r;
  }
  private ask(): void {
    const m: number[] = [];
    for (let i = 0; i < this.diffTotal * this.diffTotal; i++) { m.push(Math.random() < 0.5 ? 0 : 1); }
    this.m = m; this.realRank = this.rank(m); this.sel = -1; this.picked = -1;
    this.msg = TG('点一行选中，再点另一行 → 后者异或前者，把它消成行阶梯');
  }
  /** 行变换：先点的行当主元，后点的行 ^= 它（异或两次即还原） */
  private tapRow(r: number): void {
    if (this.over || this.picked >= 0) { return; }
    const s: number = this.sel;
    if (s < 0) { this.sel = r; this.msg = TG2('已选中第 {0} 行 —— 再点一行让它异或这行', (r + 1)); return; }
    if (s === r) { this.sel = -1; this.msg = TG('取消选中'); return; }
    const a: number[] = this.m.slice();
    for (let k = 0; k < this.diffTotal; k++) { a[r * this.diffTotal + k] = a[r * this.diffTotal + k] ^ a[s * this.diffTotal + k]; }
    this.m = a; this.sel = -1;
    this.msg = TG2("第 {0} 行 ← 第 {1} 行 ⊕ 第 {2} 行（秩不变）", (r + 1), (r + 1), (s + 1));
  }
  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.realRank],
      TG2('答案是第 {0} 个', String(this.realRank + 1)),
      TG2('The answer is option {0}', String(this.realRank + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 判定式：i === this.realRank  ｜ 守卫取自它自己的 if (...) { return; }
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
    if (this.picked >= 0 || this.over) {
      return true;
    }
    this.pick(this.realRank);
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
    if (i === this.realRank) { this.rightN = this.rightN + 1; this.score = this.score + 160; this.msg = TG2('✅ 秩就是 {0}', this.realRank); }
    else { this.score = Math.max(0, this.score - 20); this.msg = TG2('❌ 正确答案是 {0} —— 阶梯里非零行有几行就是几', this.realRank); }
    this.clearNext();
    this.nextTo = setTimeout(() => { this.nextTo = -1; this.next(); }, NEXT_MS);
  }
  private next(): void {
    if (this.over) { return; }
    if (this.round < TOTAL) { this.round = this.round + 1; this.ask(); return; }
    this.over = true; this.won = this.rightN >= PASS;
    this.msg = this.won ? TG2("🎉 答对 {0}/{1}，通关！",Digits(String(this.rightN), this.langCode), TOTAL) : TG2("😵 只答对 {0}/{1}，差 {2} 题", this.rightN, TOTAL, (PASS - this.rightN));
    this.finish(this.won);
  }
  private finish(solved: boolean): void {
    if (this.finished) { return; }
    this.finished = true;
    const r: GameResult = { gameId: 'binary_matrix_rank_all', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.rightN };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }
  build() {
    Column({ space: Space.md }) {
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + '/' + TOTAL)).fontSize(FontSize.md).fontWeight(FontWeight.Bold).fontColor((Palette.sky))
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
      Column({ space: 2 }) {
        ForEach(this.rows, (r: number) => {
          Row({ space: Space.xs }) {
          ForEach(this.rows, (c: number) => {
          Text(String(this.m[((r)) * this.diffTotal + (c)])).fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center).layoutWeight(1).height(Cell.of(30))
          .fontColor(this.m[((r)) * this.diffTotal + (c)] === 1 ? '#FFFFFF' : this.theme.inkFaint)
          .backgroundColor(this.m[((r)) * this.diffTotal + (c)] === 1 ? Palette.amber : this.theme.surface)
          .borderRadius(Radius.xs).animation({ duration: Motion.fast, curve: Motion.snap() })
          }, (c: number) => 'mc' + (r) + '-' + c)
          }
          .width('100%').borderRadius(Radius.xs)
          .borderWidth(this.sel === (r) ? 2 : 0).borderColor(Palette.amber)
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.tapRow((r)); }); })
          .onClick(() => { Haptics.tick(); this.tapRow((r)); })
        }, (r: number) => 'mr' + r)
      }
      .width('100%').padding(Space.xs).backgroundColor(this.theme.surfaceAlt).borderRadius(Radius.md)
      Row({ space: Space.xs }) {
        ForEach(this.ranks, (v: number) => {
          Text(String((v))).fontSize(FontSize.md).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
          .fontColor(this.picked >= 0 && ((v) === this.realRank || (v) === this.picked) ? '#FFFFFF' : this.theme.ink)
          .layoutWeight(1).height(Cell.of(48))
          .backgroundColor(this.picked < 0 ? this.theme.surface
          : ((v) === this.realRank ? Palette.emerald : ((v) === this.picked ? Palette.rose : this.theme.surface)))
          .borderRadius(Radius.sm).shadow(Shadow.card)
          .animation({ duration: Motion.fast, curve: Motion.snap() }).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pick((v)); }); }).onClick(() => { Haptics.tick(); this.pick((v)); })
        }, (v: number) => 'op' + v)
      }
      .width('100%')
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      // ★ 演示条（共用组件；未演示时高度为 0，不占位）
      DemoBar({ on: this.demoId >= 0, msg: this.demoMsg })
      HintBar({
              onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        demoOn: false,
        disabled: this.demoId >= 0,
        autoOn: this.autoId >= 0
      })
      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.primary).focusable(Tv.on()).focusBox(Tv.box()).onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); }).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('提示：秩 = 行阶梯里非零行的行数；异或两次等于没做，点错就再点一遍那两行'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    })
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
