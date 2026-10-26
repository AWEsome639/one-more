/**
 * 对称广度 —— 图案左右对称，先记住 4 格亮块，再凭记忆复原
 * 胜负：6 题复原对 ≥ 4 ⇒ 通关　｜　进度：题号 / 复对 / 已点
 */

import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';

const N: number = 4; const SPAN: number = 4; const ROUNDS: number = 6; const PASS: number = 4;
const SHOW_MS: number = 1600; const FEED_MS: number = 1000;

@Component
export struct GSymmetrySpan {
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  // ★ 难度作用到玩法：棋盘边长（原 N=4；简单 ×0.7 / 普通 ×1 / 困难 ×1.3）
  //   ⚠️ 光改常量没用 —— 渲染原本用的是写死的 [0, 1, 2, 3]，上面已一并改成按尺寸生成
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private diffTotal: number = GameDiff.sizeNow(4);

  /** 0..diffTotal-1（读 @State 建依赖，ArkUI 才追踪得到） */
  private rowIdx(): number[] {
    const n2: number = this.diffTotal > 1 ? this.diffTotal : 2;
    const a2: number[] = [];
    for (let i2 = 0; i2 < n2; i2++) { a2.push(i2); }
    return a2;
  }
  onFinish: (r: GameResult) => void = () => {};
  @State target: number[] = []; @State chosen: number[] = [];
  @State phase: number = 0;      // 0 记忆　1 复原　2 反馈
  @State round: number = 1; @State hits: number = 0; @State score: number = 0;
  @State over: boolean = false; @State won: boolean = false; @State msg: string = '';
  private startAt: number = 0; private timer: number = -1; private done: boolean = false;

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
  onRestart(): void {
    this.diffTotal = GameDiff.sizeNow(4);
     this.reset(); }
  aboutToDisappear(): void { this.clearAll(); }
  private clearAll(): void { if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; } }

  private reset(): void {
    this.clearAll(); this.round = 1; this.hits = 0; this.score = 0;
    this.over = false; this.won = false; this.done = false; this.startAt = Date.now();
    this.makeRound();
  }

  /** 左半边随机 2 格镜像到右半边 ⇒ 左右对称的 4 格图案 */
  private makeRound(): void {
    const half: number[] = [];
    for (let r = 0; r < this.diffTotal; r++) {
      for (let c = 0; c < this.diffTotal / 2; c++) { half.push(r * this.diffTotal + c); }
    }
    const g: number[] = new Array<number>(this.diffTotal * this.diffTotal).fill(0);
    let put: number = 0; let guard: number = 0;
    while (put < SPAN / 2 && guard < 80) {
      const p: number = half[Math.floor(Math.random() * half.length)];
      if (g[p] === 0) {
        g[p] = 1; g[Math.floor(p / this.diffTotal) * this.diffTotal + (this.diffTotal - 1 - (p % this.diffTotal))] = 1; put = put + 1;
      }
      guard = guard + 1;
    }
    this.target = g; this.chosen = []; this.phase = 0;
    this.msg = TG2("第 {0} / {1} 题：记住这 {2} 格（左右对称）", this.round, ROUNDS, SPAN);
    this.timer = setTimeout(() => {
      this.timer = -1; this.phase = 1;
      this.msg = TG2('点出刚才的 {0} 格（再点一下可取消）', SPAN);
    }, SHOW_MS);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // ★ 变体⑦：照真值数组走
  // target[i] === 1 表示这一格要选中；只在 phase 1 能点
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.phase !== 1) {
      return true;              // 还没进入选择阶段，等它
    }
    for (let i = 0; i < this.target.length; i++) {
      if (this.target[i] === 1 && this.chosen.indexOf(i) < 0) {
        this.tap(i);
        return !this.over;
      }
    }
    return false;
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
    if (this.phase !== 1 || this.over) { return; }
    const cur: number[] = this.chosen.slice();
    const hit: number = cur.indexOf(i);
    if (hit >= 0) { cur.splice(hit, 1); this.chosen = cur; return; }
    if (cur.length >= SPAN) { return; }
    cur.push(i); this.chosen = cur;
    if (cur.length === SPAN) { this.check(); }
  }

  private check(): void {
    this.phase = 2;
    let ok: boolean = true;
    for (let i = 0; i < this.target.length; i++) {
      const want: number = this.target[i];
      const got: number = this.chosen.indexOf(i) >= 0 ? 1 : 0;
      if (want !== got) { ok = false; }
    }
    if (ok) { this.hits = this.hits + 1; this.score = this.score + 20; this.msg = TG('✅ 完全复原'); } else { this.msg = TG('❌ 绿色的是正确位置'); }
    this.timer = setTimeout(() => { this.timer = -1; this.next(); }, FEED_MS);
  }

  private next(): void {
    if (this.round >= ROUNDS) {
      this.over = true; this.won = this.hits >= PASS;
      this.msg = (this.won ? TG('🎉 通关：') : TG('💤 结束：')) +TG2("复原 {0} / {1}", this.hits, ROUNDS);
      this.finish(this.won); return;
    }
    this.round = this.round + 1; this.makeRound();
  }

  private finish(solved: boolean): void {
    if (this.done) { return; }
    this.done = true;
    const r: GameResult = { gameId: 'symmetry_span', solved: solved, score: this.score, durationMs: Date.now() - this.startAt, levelReached: this.round };
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish(r);
  }

  private cellBg(i: number): string {
    if (this.phase === 0) { return this.target[i] === 1 ? Palette.violet : this.theme.surfaceAlt; }
    if (this.phase === 1) { return this.chosen.indexOf(i) >= 0 ? Palette.amber : this.theme.surfaceAlt; }
    if (this.target[i] === 1) { return Palette.emerald; }
    return this.chosen.indexOf(i) >= 0 ? Palette.rose : this.theme.surfaceAlt;
  }

  build() {
    Column({ space: Space.md }) {
      HintBar({
        showHint: false,
        onAutoTap: () => { this.askAuto(); },
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.sm }) {
        Column({ space: Space.xs }) {
        Text((TG('题号'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.round + ' / ' + ROUNDS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.primaryDeep))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('复对'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.hits + ' / ' + PASS)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.emerald))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: Space.xs }) {
        Text((TG('已点'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.chosen.length + ' / ' + SPAN)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor((Palette.amber))
        }.layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')
      Column({ space: Space.xs }) {
        ForEach(this.rowIdx(), (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(this.rowIdx(), (c: number) => {
              Stack() {
              Text('').fontSize(FontSize.md)
              }.layoutWeight(1).aspectRatio(1).backgroundColor(this.cellBg((r * this.diffTotal + c))).borderRadius(Radius.xs)
              .animation({ duration: Motion.fast, curve: Motion.snap() }).onClick(() => { Haptics.tick(); this.tap((r * this.diffTotal + c)); })
              // ★ 2026-10-15 补动画：ForEach 重建的元素加 transition（否则是硬切）
              .transition(TransitionEffect.OPACITY.animation({ duration: Motion.fast, curve: Motion.snap() })
                .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
            }, (c: number) => 'c' + r + '_' + c)
          }.width('100%').layoutWeight(1)
        }, (r: number) => 'r' + r)
      }.width('100%').aspectRatio(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.lg).shadow(Shadow.card)
      Text(this.msg).fontSize(FontSize.sm).width('100%').textAlign(TextAlign.Center)
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } }).fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(46)).onClick(() => { Haptics.tap(); this.reset(); })
      Text(TG('记忆阶段结束后亮块会全部藏起来，凭印象点回来')).fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint).width('100%').textAlign(TextAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }




}
