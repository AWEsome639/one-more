/**
 * 聚焦隧道 📐
 * 玩法：5×5 暗场，只有中央「隧道」半径内的格子是亮的 —— 目标 🎯 一定藏在亮区里。
 * 每找到一次，隧道就收窄一圈（周边干扰项越来越暗）。
 * 胜负：找到 6 个目标 = 通关；点错 3 次 = 失败。
 */
import { FontSize, Space, Radius, Palette, Motion, Theme, Cell } from '../core/Design';
import { Haptics } from '../core/Haptics';
import { GameDiff } from '../core/GameDiff';
import { TG, TG2 } from '../core/GameI18n';
import { Hint, HintResult } from '../ai/Hint';
import { HintBar } from '../components/HintBar';
import { GameResult } from '../core/GameRegistry';
import { LanRace } from '../core/LanRace';
import { Digits } from '../core/I18n';

const N: number = 5;
const NEED: number = 6;
const LIVES: number = 3;
const R0: number = 2.4;
const STEP: number = 0.2;
const RC: number[] = [0, 1, 2, 3, 4];
const CELL: number = 48;

@Component
export struct GFocusTunnel {
  /** ★★★ 2026-10-16 BUG #24：数字要走 Digits ⇒ 必须自己观察 lang（ArkUI 只认 @State/@Prop/@StorageProp 的读取） */
  @StorageProp('lang') langCode: string = 'zh';
  @Prop theme: Theme = Theme.light();
  @Prop @Watch('onRestart') restartToken: number = 0;
  onFinish: (r: GameResult) => void = () => {};

  /** 代打计时器（-1 = 未运行）。必须 @State */
  @State private autoId: number = -1;
  @State private target: number = 0;
  /** ★ 2026-10-16 通关庆祝 */
  @State private winK: number = 1;
  @State private found: number = 0;
  // ★ 难度作用到玩法：本局「容错次数/起始量」按难度换算（简单更多 / 困难更少）
  private total: number = GameDiff.livesNow(LIVES);
  @State private lives: number = 0;
  /** ★ 错误抖动 */
  @State private shakeX: number = 0;
  @State private radius: number = R0;
  @State private over: boolean = false;
  @State private won: boolean = false;
  @State private note: string = '';

  private startAt: number = 0;

  aboutToAppear(): void { LanRace.noteStart(); this.reset(); }
  onRestart(): void {
    this.total = GameDiff.livesNow(LIVES);   // 难度可能刚变过，必须重算
     this.reset(); }

  private inTunnel(i: number): boolean {
    const r: number = Math.floor(i / N) - (N - 1) / 2;
    const c: number = (i % N) - (N - 1) / 2;
    const r2: number = this.radius * this.radius;
    return r * r + c * c <= r2;
  }

  private place(): void {
    const cand: number[] = [];
    for (let i = 0; i < N * N; i++) {
      if (this.inTunnel(i)) { cand.push(i); }
    }
    const pick: number = cand[Math.floor(Math.random() * cand.length)];
    this.target = pick;
  }

  private reset(): void {
    this.radius = R0;
    this.found = 0;
    this.lives = this.total; this.shakeX = 8; setTimeout(() => { this.shakeX = -8; }, 60); setTimeout(() => { this.shakeX = 0; }, 120);
    this.over = false;
    this.won = false;
    this.note = TG('亮区里只有一个 🎯，点它 🔦');
    this.place();
    this.startAt = Date.now();
  }

  /** 提示：直接报答案（代打用的就是这个字段） */
  private computeHint(): HintResult {
    const t0: number = Date.now();
    if (this.over) {
      return Hint.none('none');
    }
    return Hint.make([this.target],
      TG2('答案是第 {0} 个', String(this.target + 1)),
      TG2('The answer is option {0}', String(this.target + 1)), t0);
  }

  private askHint(): void {
    Haptics.tap();
    const r: HintResult = this.computeHint();
    Hint.toastResult(r, TG('这一步看不出答案'));
  }

  // ═══════════ AI 代打（2026-10-24 第三期）═══════════
  // 真值直取：target 就是当前该点的格（点完会换）
  private autoStep(): boolean {
    if (this.over) {
      return false;
    }
    // 真值直取：target 就是当前该点的格
    this.tap(this.target);
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

  private tap(i: number): void {
    if (this.over) { return; }
    const hit: number = this.target;
    if (i === hit) {
      this.found++;
      if (this.found >= NEED) {
        this.note = TG('六个目标全找到，通关 🎉');
        this.winK = 1.18; setTimeout(() => { this.winK = 1; }, 320); this.finish(true);
        return;
      }
      this.radius = R0 - this.found * STEP;
      this.note = TG2('找到了！隧道收窄到 {0} 🔦', this.radius.toFixed(1));
      this.place();
      return;
    }
    this.lives--;
    if (this.lives <= 0) {
      this.note = TG('眼神涣散，隧道关了 😵');
      this.finish(false);
      return;
    }
    this.note = TG2('点错了，那是干扰项 🌀（余命 {0}/{1}）',Digits(String(this.lives), this.langCode),Digits(String(LIVES), this.langCode));
  }

  private finish(solved: boolean): void {
    this.over = true;
    this.won = solved;
    LanRace.noteDone();  // ★ 竞速模式：上报用时（没在竞速时是空操作）
    this.onFinish({
      gameId: 'focus_tunnel',
      solved: solved,
      score: solved ? 50 + this.lives * 10 : this.found * 10,
      durationMs: Date.now() - this.startAt,
      levelReached: this.found + 1
    });
  }

  build() {
    Column({ space: Space.sm }) {
      Text(TG2('目标 {0}/{1}　余命 {2}',Digits(String(this.found), this.langCode),Digits(String(NEED), this.langCode),Digits(String(this.lives), this.langCode))
        + TG2('/{0}　隧道 {1}', String(LIVES), this.radius.toFixed(1)))
        .fontSize(FontSize.sm).fontColor(this.theme.inkSoft).width('100%')
        // ★ 错误抖动
        .translate({ x: this.shakeX })
        .animation({ duration: Motion.fast, curve: Motion.snap() })
      Column({ space: Space.xs }) {
        ForEach(RC, (r: number) => {
          Row({ space: Space.xs }) {
            ForEach(RC, (c: number) => {
              this.tile(r * N + c)
            }, (c: number) => 'c' + c)
          }.width('100%')
        }, (r: number) => 'r' + r)
      }.width('100%')
      Text(this.note)
        .fontSize(FontSize.xs)
        // ★ 通关庆祝
        .scale({ x: this.winK, y: this.winK })
        .animation({ duration: Motion.slow, curve: Motion.spring() }).fontColor(this.theme.inkFaint)
        .width('100%').textAlign(TextAlign.Center)
      HintBar({
        onHintTap: () => { this.askHint(); },
  onAutoTap: () => { this.askAuto(); },
        showHint: true,
        autoOn: this.autoId >= 0
      })
      Button(TG('重开'))
      .stateStyles({ pressed: { .scale({ x: 0.96, y: 0.96 }) }, normal: { .scale({ x: 1, y: 1 }) } })
        .fontSize(FontSize.md).fontColor('#FFFFFF').backgroundColor(Palette.primary)
        .borderRadius(Radius.md).width('100%').height(Cell.of(44))
        .onClick(() => { Haptics.tap(); this.reset(); })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
  }

  @Builder
  tile(i: number) {
    Stack() {
      Text(i === this.target ? '🎯' : '🌀').fontSize(FontSize.xl)
    }
    .layoutWeight(1).height(CELL)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.sm)
    .opacity(this.inTunnel(i) ? 1 : 0.2).animation({ duration: Motion.fast, curve: Motion.snap() })
    .animation({ duration: Motion.base, curve: Motion.snap() })
    .onClick(() => { Haptics.tick(); this.tap(i); })
  }
}
