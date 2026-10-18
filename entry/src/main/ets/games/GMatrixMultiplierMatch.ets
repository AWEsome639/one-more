/**
 * 矩阵配对 —— 匹配乘积结果
 * 玩法：左边 3 个「A × B」算式，下边 3 个乱序乘积矩阵；左点一个、右点一个配对。
 * 胜负：90 秒内完成 3 块题板（每块 3 对）⇒ 通关；时间归零 ⇒ 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

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

  aboutToAppear(): void { LanRace.noteStart(); this.startAt = Date.now(); this.reset(); }
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
          .onClick(() => { this.pickL(k); })
        }, (k: number) => 'ml' + k)
      }.width('100%')

      Row({ space: Space.sm }) {
        ForEach(SLOTS, (slot: number) => {
          Text(this.rText(slot))
            .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
            .textAlign(TextAlign.Center)
            .layoutWeight(1).padding(Space.sm).borderRadius(Radius.md).shadow(Shadow.card)
            .backgroundColor(this.theme.surfaceAlt)
            .onClick(() => { this.pickR(slot); })
        }, (slot: number) => 'ms' + slot)
      }.width('100%')

      Text(this.msg).fontSize(FontSize.sm).width('100%')
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)

      Button(this.over ? (this.won ? TG('已通关 🎉') : TG('再来一局')) : TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').borderRadius(Radius.md).width('100%').height(Cell.of(46))
        .backgroundColor(this.over && !this.won ? Palette.rose : Palette.lime)
        .onClick(() => { this.reset(); })

      Text(TG('提示：2×2 乘积 C[r][c] = A[r][0]×B[0][c] + A[r][1]×B[1][c]'))
        .fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
    }.width('100%').height('100%').justifyContent(FlexAlign.Start)
  }


}
