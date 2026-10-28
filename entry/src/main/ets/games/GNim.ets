/**
 * 尼姆博弈（反着玩）—— 拿走最后一颗就输 🎲
 *
 * 规则：三堆石子（3 / 5 / 7）。轮流从任意一堆拿走任意多颗，
 *      谁拿走最后一颗谁就输。点第 k 颗石子 = 从这一堆拿走 k 颗。
 * 胜负：让 AI 拿走最后一颗 = 通关；自己拿了最后一颗 = 失败
 */

import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { LanMatch } from '../core/LanMatch';
import { TG, TG2 } from '../core/GameI18n';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

@Component
export struct GNim {
  /** ★★★ 2026-10-16 BUG #24：HUD 数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;

  /** 按难度给出初始堆 */
  private static startPiles(): number[] {
    const d: number = GameDiff.now();
    if (d === 0) { return [2, 3, 4]; }
    if (d === 2) { return [4, 7, 10]; }
    return [3, 5, 7];
  }
  onFinish: (r: GameResult) => void = () => {};

  // ★ 难度作用到玩法：每堆的豆子数（简单 [2,3,4] / 普通 [3,5,7] / 困难 [4,7,10]）
  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private piles: number[] = GNim.startPiles();
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private turn: number = 0;      // 0 = 你，1 = AI
  @State private moves: number = 0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private msg: string = TG('点某堆的第 k 颗石子 = 从这堆拿走 k 颗');

  private aiTimer: number = -1;
  private startAt: number = 0;

  aboutToAppear(): void {
    LanRace.noteStart();  // ★ 竞速模式：本局开始计时
    // ★ 联机对局：对方走 AI 那一方 —— 收到「堆:颗数」就当成 AI 的那一步应用
    LanMatch.setHandler((d: string) => {
      const p: string[] = d.split(':');
      if (p.length < 2) {
        return;
      }
      const i: number = Number.parseInt(p[0], 10);
      const t: number = Number.parseInt(p[1], 10);
      if (isNaN(i) || isNaN(t) || this.over || t > this.piles[i]) {
        return;
      }
      const n: number[] = this.piles.slice();
      n[i] = n[i] - t;
      this.piles = n;
      this.moves = this.moves + 1;
      this.turn = 0;
      if (this.total(n) === 0) {
        this.over = true;
        this.won = true;          // 对手拿了最后一颗 ⇒ 我赢
        this.msg = TG('对手拿走了最后一颗…这局你赢了');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.msg = TG('轮到你拿');
    });
    this.reset();
  }

  aboutToDisappear(): void {
    this.clearAi();
  }

  onRestart(): void {
    this.piles = GNim.startPiles();
    this.reset();
  }

  private clearAi(): void {
    if (this.aiTimer !== -1) {
      clearTimeout(this.aiTimer);
      this.aiTimer = -1;
    }
  }

  private reset(): void {
    this.clearAi();
    this.piles = [3, 5, 7];
    this.turn = 0;
    this.moves = 0;
    this.over = false;
    this.won = false;
    this.msg = TG('点某堆的第 k 颗石子 = 从这堆拿走 k 颗');
    this.startAt = Date.now();
  }

  private total(p: number[]): number {
    let s: number = 0;
    for (let i = 0; i < p.length; i++) {
      s += p[i];
    }
    return s;
  }

  private stones(n: number): string {
    let s: string = '';
    for (let i = 0; i < n; i++) {
      s += '●';
    }
    return s;
  }

  /** 反尼姆：把「留给对手的局面」判成必败局 */
  private losingFor(h: number[]): boolean {
    let big: number = 0;
    let ones: number = 0;
    let x: number = 0;
    for (let i = 0; i < h.length; i++) {
      if (h[i] > 1) {
        big++;
      }
      if (h[i] === 1) {
        ones++;
      }
      x = x ^ h[i];
    }
    if (big === 0) {
      return ones % 2 === 1;
    }
    return x === 0;
  }

  /** 暴力找一步最优：拿完后对手必败 */
  private aiPick(): number[] {
    for (let i = 0; i < this.piles.length; i++) {
      for (let t = 1; t <= this.piles[i]; t++) {
        const n: number[] = this.piles.slice();
        n[i] = n[i] - t;
        if (this.total(n) === 0) {
          continue;   // 拿最后一颗 = 自己输
        }
        if (this.losingFor(n)) {
          const out: number[] = [i, t];
          return out;
        }
      }
    }
    let big: number = 0;
    for (let i = 0; i < this.piles.length; i++) {
      if (this.piles[i] > this.piles[big]) {
        big = i;
      }
    }
    const out2: number[] = [big, 1];
    return out2;
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    if (this.turn !== 0) {
      return true;
    }
    const mv: number[] = this.aiPick();
    if (mv.length < 2) {
      return false;
    }
    this.take(mv[0], mv[1]);
    return !this.over;
  }

  /** 提示：反尼姆的最优一步（走完把必败局留给对手） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    if (this.turn !== 0) {
      return Hint.none(TG('等对手拿完再提示'));
    }
    const mv: number[] = this.aiPick();
    if (mv.length < 2) {
      return Hint.none('none');
    }
    const i: number = mv[0];
    const t: number = mv[1];
    return Hint.make([i],
      TG2('从第 {0} 堆拿走 {1} 颗（这堆还剩 {2} 颗）', String(i + 1), String(t), String(this.piles[i] - t)),
      TG2('Take {1} from pile {0} ({2} left)', String(i + 1), String(t), String(this.piles[i] - t)), t0);
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

  private take(i: number, t: number): void {
    if (this.over || this.turn !== 0 || t > this.piles[i]) {
      return;
    }
    // ★ 联机时：不是我的回合就不接受操作
    if (LanMatch.isActive() && !LanMatch.myTurn()) {
      this.msg = TG('等对手拿…');
      return;
    }
    const n: number[] = this.piles.slice();
    n[i] = n[i] - t;
    this.piles = n;
    this.moves = this.moves + 1;
    // ★ 联机时：把「哪一堆、拿几颗」发给对方，然后**不跑 AI**
    if (LanMatch.isActive()) {
      LanMatch.record(String(i) + ':' + String(t));
      if (this.total(n) === 0) {
        this.over = true;
        this.won = false;
        this.msg = TG('你拿走了最后一颗…按规矩这局你输了');
        this.finish(false);
        return;
      }
      this.msg = TG('等对手拿…');
      return;
    }
    if (this.total(n) === 0) {
      this.over = true;
      this.won = false;
      this.msg = TG('你拿走了最后一颗…按规矩这局你输了');
      this.finish(false);
      return;
    }
    this.turn = 1;
    this.msg = TG('AI 正在想…');
    this.clearAi();
    this.aiTimer = setTimeout(() => {
      this.aiTimer = -1;
      this.aiTurn();
    }, 650);
  }

  private aiTurn(): void {
    if (this.over || this.turn !== 1) {
      return;
    }
    const pick: number[] = this.aiPick();
    const n: number[] = this.piles.slice();
    n[pick[0]] = n[pick[0]] - pick[1];
    this.piles = n;
    if (this.total(n) === 0) {
      this.over = true;
      this.won = true;
      this.msg = TG('AI 拿走了最后一颗，你赢了！');
      this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
      return;
    }
    this.turn = 0;
    this.msg = TG2('AI 从第 {0} 堆拿走 {1} 颗，轮到你了', String(pick[0] + 1), String(pick[1]));
  }

  private finish(solved: boolean): void {
    const r: GameResult = {
      gameId: 'nim',
      solved: solved,
      score: solved ? Math.max(100, 1000 - this.moves * 30) : 0,
      durationMs: Date.now() - this.startAt,
      levelReached: this.moves
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
        autoOn: this.autoId >= 0
      })
      Row({ space: Space.md }) {
        Column({ space: 2 }) {
        Text((TG('剩余石子'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((String(this.total(this.piles)))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('你的步数'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text(Digits(String(this.moves), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
        Column({ space: 2 }) {
        Text((TG('轮到'))).fontSize(FontSize.xxs).fontColor(this.theme.inkFaint)
        Text((this.over ? '—' : (this.turn === 0 ? '你' : 'AI'))).fontSize(FontSize.lg).fontWeight(FontWeight.Bold).fontColor(this.theme.ink)
        }
        .layoutWeight(1).padding(Space.sm)
        .backgroundColor(this.theme.surface).borderRadius(Radius.md).shadow(Shadow.card)
      }
      .width('100%')

      ForEach([0, 1, 2], (i: number) => {
        Column({ space: Space.xs }) {
        Row() {
        Text(TG2("第 {0} 堆", String((i) + 1))).fontSize(FontSize.xs).fontColor(this.theme.inkFaint)
        Text(this.stones(this.piles[(i)]))
        .fontSize(FontSize.md)
        .fontColor(this.piles[(i)] > 0 ? Palette.emerald : this.theme.lineSoft)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        // ★ 2026-10-13 动效（奥森：「动画要拉满」）：
        //   石子数变化时缩放弹一下 —— 拿走后"少了一截"看得见
        .scale({ x: this.piles[(i)] > 0 ? 1 : 0.92, y: this.piles[(i)] > 0 ? 1 : 0.92 })
        .animation({ duration: Motion.fast, curve: Motion.spring() })
        }
        .width('100%')

        Row({ space: Space.xs }) {
        ForEach([1, 2, 3, 4, 5, 6, 7], (k: number) => {
        if (k <= this.piles[(i)]) {
        Text(String(k))
        .fontSize(FontSize.xs)
        .fontColor(this.theme.ink)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)
        .height(Cell.of(40))
        .backgroundColor(this.turn === 0 && !this.over ? '#1A10B981' : this.theme.surfaceAlt)
        .borderRadius(Radius.sm)
        .border({ width: 1, color: this.theme.line })
        // ★ 2026-10-13 动效：被拿走的按钮【缩放淡出】，留下的【缩放淡入】
        //   （原来 if 一收一放是硬切，看不出"少了哪几颗"）
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.75, y: 0.75 }))
          .animation({ duration: Motion.fast, curve: Motion.spring() }))
        .onClick(() => {
        Haptics.tick();
        this.take((i), k);
        })
        }
        }, (k: number) => 'p' + (i) + '-' + k)
        }
        .width('100%')
        }
        .width('100%')
        .padding(Space.sm)
        .backgroundColor(this.theme.surface)
        .borderRadius(Radius.md)
        .shadow(Shadow.card)
        // ★ 2026-10-13 动效：整堆卡片的尺寸变化走弹簧，不会"跳"
        .animation({ duration: Motion.base, curve: Motion.spring() })
      }, (i: number) => 'pile' + i)

      Text(this.over ? this.msg : (this.turn === 0 ? this.msg : 'AI 思考中…'))
        .fontSize(FontSize.sm)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() })
        .fontColor(this.over ? (this.won ? Palette.emerald : Palette.rose) : this.theme.inkSoft)
        .textAlign(TextAlign.Center)
        .width('100%')

      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor(Color.White)
        .backgroundColor(Palette.emerald).borderRadius(Radius.md)
        .width('100%').height(Cell.of(44))
        .onClick(() => {
          Haptics.tap();
          this.reset();
        })

      Text(TG('小提示：三堆都只剩 1 颗时，谁先动手谁输'))
        .fontSize(FontSize.xxs)
        .fontColor(this.theme.inkFaint)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }




}
