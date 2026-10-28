/**
 * 矩阵配对 —— 匹配乘积结果
 * 玩法：左边 3 个「A × B」算式，下边 3 个乱序乘积矩阵；左点一个、右点一个配对。
 * 胜负：90 秒内完成 3 块题板（每块 3 对）⇒ 通关；时间归零 ⇒ 失败。
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

const PAIRS: number = 3; const BOARDS: number = 3;
const LIMIT: number = 90; const TICK_MS: number = 1000; const PENALTY: number = 5;
const SLOTS: number[] = [0, 1, 2];
const HIT: string = '#2210B981';

function ri(lo: number, hi: number): number {
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

@Component
export struct GMatrixMultiplierMatch {
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
  @State private mats: number[] = [];
  @State private prods: number[] = [];
  @State private order: number[] = [];
  @State private done: boolean[] = [];
  @State private selL: number = -1;
  @State private board: number = 1;
  @State private errs: number = 0;
  @State private score: number = 0;
  /** ★ 2026-10-15 得分跳动 */
  @State private scorePulse: number = 1;
  // ★ 难度作用到玩法：本局时限 = 基础 × 难度倍率（简单 1.5× / 普通 1× / 困难 0.7×）
  private total: number = GameDiff.timeNow(LIMIT);
  @State private left: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = '';
  private startAt: number = 0; private timer: number = -1; private finished: boolean = false;

  aboutToAppear(): void {
    LanRace.noteStart(); this.startAt = Date.now(); this.reset();
    // ★ 演示：进来 3 秒内没人动就开始演（一碰就停，见根容器 .onTouch）
    setTimeout(() => { this.demoStart(); }, 3000);
  }
  onRestart(): void {
    this.total = GameDiff.timeNow(LIMIT);   // 难度可能刚变过，必须重算
     this.reset(); }
  aboutToDisappear(): void { this.stop(); }

  private stop(): void { if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; } }

  private reset(): void {
    this.stop();
    this.board = 1; this.errs = 0; this.score = 0; this.left = this.total;
    this.over = false; this.won = false; this.finished = false; this.startAt = Date.now();
    this.newBoard();
    this.msg = TG('先点左边算式，再点下边它的积');
    this.timer = setInterval(() => { this.tick(); }, TICK_MS);
  }

  private tick(): void {
    if (this.over) { return; }
    this.left = this.left - 1;
    if (this.left <= 0) { this.left = 0; this.end(false, TG('⏰ 时间到')); }
  }

  /** 3 对 2×2 乘法题，乘积互不相同，右侧乱序 */
  private newBoard(): void {
    const mats: number[] = [];
    const prods: number[] = [];
    const seen: string[] = [];
    for (let k = 0; k < PAIRS; k++) {
      let ok: boolean = false;
      while (!ok) {
        const a0: number = ri(1, 6); const a1: number = ri(1, 6);
        const a2: number = ri(1, 6); const a3: number = ri(1, 6);
        const b0: number = ri(1, 6); const b1: number = ri(1, 6);
        const b2: number = ri(1, 6); const b3: number = ri(1, 6);
        const p: number[] = [
          a0 * b0 + a1 * b2, a0 * b1 + a1 * b3,
          a2 * b0 + a3 * b2, a2 * b1 + a3 * b3
        ];
        const tag: string = p.join(',');
        if (seen.indexOf(tag) < 0) {
          seen.push(tag);
          mats.push(a0, a1, a2, a3, b0, b1, b2, b3);
          prods.push(p[0], p[1], p[2], p[3]);
          ok = true;
        }
      }
    }
    const order: number[] = [0, 1, 2];
    for (let i = order.length - 1; i > 0; i--) {
      const j: number = Math.floor(Math.random() * (i + 1));
      const t: number = order[i]; order[i] = order[j]; order[j] = t;
    }
    this.mats = mats; this.prods = prods; this.order = order;
    this.done = [false, false, false]; this.selL = -1;
  }

  private mText(base: number, off: number): string {
    return String(this.mats[base + off]) + ' ' + String(this.mats[base + off + 1]) + '\n' +
      String(this.mats[base + off + 2]) + ' ' + String(this.mats[base + off + 3]);
  }

  private rText(slot: number): string {
    const b: number = this.order[slot] * 4;
    return String(this.prods[b]) + ' ' + String(this.prods[b + 1]) + '\n' +
      String(this.prods[b + 2]) + ' ' + String(this.prods[b + 3]);
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 两步一手：先 pickL(算式) 再 pickR(积)。真值就在 order[] 里：order[slot] === 算式号
  /** 还没配对的左边算式（-1 = 全配完了） */
  private nextLeft(): number {
    for (let k = 0; k < PAIRS; k++) {
      if (!this.done[k]) {
        return k;
      }
    }
    return -1;
  }

  /** 左边第 k 个算式的积在下边第几个（-1 = 找不到） */
  private slotOf(k: number): number {
    for (let s = 0; s < PAIRS; s++) {
      if (this.order[s] === k) {
        return s;
      }
    }
    return -1;
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
    if (this.selL < 0) {
      const k: number = this.nextLeft();
      if (k < 0) {
        return true;                   // 这一块全配完了，等它换下一块
      }
      this.pickL(k);
      return !this.over;
    }
    const slot: number = this.slotOf(this.selL);
    if (slot < 0) {
      return true;
    }
    this.pickR(slot);
    return !this.over;
  }

  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    let k: number = this.selL;
    if (k < 0) {
      k = this.nextLeft();
    }
    if (k < 0) {
      return Hint.none('none');
    }
    const slot: number = this.slotOf(k);
    if (slot < 0) {
      return Hint.none('none');
    }
    if (this.selL < 0) {
      return Hint.make([k],
        TG2('先点左边第 {0} 个算式，它的积在下边第 {1} 个', String(k + 1), String(slot + 1)),
        'Pick left #' + String(k + 1) + ', its product is bottom #' + String(slot + 1), t0);
    }
    return Hint.make([slot],
      TG2('现在点下边第 {0} 个矩阵（它就是左边第 {1} 个算式的积）', String(slot + 1), String(k + 1)),
      'Now tap bottom #' + String(slot + 1), t0);
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

  private pickL(k: number): void {
    if (this.over || this.done[k]) { return; }
    this.selL = k;
    this.msg = TG2('已选左边第 {0} 个算式，去下边点它的积', String(k + 1));
  }

  private pickR(slot: number): void {
    if (this.over) { return; }
    if (this.selL < 0) { this.msg = TG('先点左边的算式，再点下边的积'); return; }
    if (this.order[slot] !== this.selL) {
      this.errs = this.errs + 1; this.selL = -1;
      this.score = Math.max(0, this.score - 20); this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
      this.left = Math.max(0, this.left - PENALTY);
      this.msg = TG2("❌ 配错了，扣 {0} 秒", String(PENALTY));
      if (this.left <= 0) { this.end(false, TG('⏰ 时间到')); }
      return;
    }
    const d: boolean[] = this.done.slice();
    d[this.selL] = true;
    this.done = d; this.selL = -1; this.score = this.score + 120; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    let everyDone: boolean = true;
    for (let i = 0; i < PAIRS; i++) { if (!d[i]) { everyDone = false; } }
    if (!everyDone) { this.msg = TG('✅ 配对成功'); return; }
    this.score = this.score + 100; this.scorePulse = 1.3; setTimeout(() => { this.scorePulse = 1; }, 140);
    if (this.board >= BOARDS) {
      this.end(true, '🎉 三块题板全对，错 ' + String(this.errs) + TG(' 次'));
      return;
    }
    this.board = this.board + 1;
    this.newBoard();
    this.msg = TG2('🎯 第 {0} 块题板完成，进入下一块', String(this.board - 1));
  }

  private end(solved: boolean, why: string): void {
    if (this.finished) { return; }
    this.finished = true;
    this.over = true; this.won = solved; this.msg = why;
    this.stop();
    const r: GameResult = {
      gameId: 'matrix_multiplier_match', solved: solved, score: this.score,
      durationMs: Date.now() - this.startAt, levelReached: this.board
    };
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
      Row({ space: Space.sm }) {
        Column({ space: 2 }) {
        Text((TG('题板'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.board) + '/' + String(BOARDS))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('剩余'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.left) + 's')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('得分'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.score), this.langCode)).fontSize(FontSize.lg)
        // ★ 得分跳动
        .scale({ x: this.scorePulse, y: this.scorePulse })
        .animation({ duration: Motion.fast, curve: Motion.spring() }).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm).backgroundColor(this.theme.surface)
        .borderRadius(Radius.md).shadow(Shadow.card)
      }.width('100%')

      Column({ space: Space.sm }) {
        ForEach(SLOTS, (k: number) => {
          Row({ space: Space.sm }) {
            Text(this.mText(k * 8, 0)).fontSize(FontSize.xxs).fontColor(this.theme.ink).layoutWeight(1)
            Text('×').accessibilityText(TG('乘')).fontSize(FontSize.sm).fontColor(this.theme.inkFaint)
              .accessibilityLevel('no')
            Text(this.mText(k * 8, 4)).fontSize(FontSize.xxs).fontColor(this.theme.ink).layoutWeight(1)
            Text(this.done[k] ? '✅' : (this.selL === k ? '👈' : '·')).fontSize(FontSize.sm)
          }
          .width('100%').padding(Space.sm).borderRadius(Radius.md).shadow(Shadow.card)
          .backgroundColor(this.done[k] ? HIT : (this.selL === k ? Palette.lime : this.theme.surface))
          .animation({ duration: Motion.fast, curve: Motion.snap() })
          .focusable(Tv.on())
          .focusBox(Tv.box())
          .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pickL(k); }); })
          .onClick(() => { Haptics.tick(); this.pickL(k); })
        }, (k: number) => 'ml' + k)
      }.width('100%')

      Row({ space: Space.sm }) {
        ForEach(SLOTS, (slot: number) => {
          Text(this.rText(slot))
            .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1).padding(Space.sm).borderRadius(Radius.md).shadow(Shadow.card)
            .backgroundColor(this.theme.surfaceAlt)
            .focusable(Tv.on())
            .focusBox(Tv.box())
            .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tick(); this.pickR(slot); }); })
            .onClick(() => { Haptics.tick(); this.pickR(slot); })
        }, (slot: number) => 'ms' + slot)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .focusable(Tv.on())
        .focusBox(Tv.box())
        .onKeyEvent((e: KeyEvent) => { Tv.handleKey(e, () => { Haptics.tap(); this.reset(); }); })
        .onClick(() => { Haptics.tap(); this.reset(); })

      Text(TG('提示：2×2 乘积 C[r][c] = A[r][0]×B[0][c] + A[r][1]×B[1][c]'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }
    .onTouch((e: TouchEvent) => {
      // ★ 演示：玩家一碰就停（不吞掉这次点击，事件照常往下传）
      if (this.demoId >= 0 && e.type === TouchType.Down) { this.demoStop(); }
    }).width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
